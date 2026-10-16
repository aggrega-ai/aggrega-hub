#!/usr/bin/env bash
# Differential catalog publish: push only the entities that changed since the
# last publish, instead of reconciling the whole catalog every time.
#
# The default (differential) mode enumerates the catalog entity files that a
# git diff between a MARKER commit and HEAD touched, peeks each YAML's top-level
# `kind:`, and pushes only the publishable ones. On a fully successful publish
# the marker advances to HEAD, so the next run diffs from where this one
# finished. --full reconciles the entire catalog (push's idempotent
# "Already published" no-ops the unchanged), which is also how the marker is
# first established.
#
# The marker is a git tag on this repository (default `catalog-published`).
# Reading and advancing it are isolated behind a single function pair
# (marker_read / marker_advance) so the mechanism can later be swapped for a
# remote object without touching the selection logic.
#
# Enumeration is entity-files-only, by peeking each YAML's top-level `kind:`.
# Co-located non-entity files (recipe fragments, source/ trees) are never
# pushed standalone — `aggrega push` of a Recipe / FeatureRecipe bundles them
# into the recipe artifact. This script publishes ENTITIES ONLY: the Plugin
# kind (provider .wasm) is deliberately excluded.
#
# Immutability is owned by the CLI, not this script: `aggrega push` HEADs the
# target tag and refuses to overwrite an existing version whose bytes differ
# (there is no --force). A body edited without a version bump therefore fails
# loudly at push time and this script exits non-zero. The fix is a version
# bump, which lands under a new version directory and publishes cleanly.
#
# Before anything is pushed, the selected entities go through
# scripts/published-version-guard.sh --files, which compares each against the
# version-to-digest record on the published branch, offline, and warns or refuses
# as the committed .published-version-guard switch says — so an entity edited in
# place at a recorded version is named before the first push of a run rather than
# at its own push, part-way through. A dry run runs the guard too.
#
# With --record-out FILE, every reference a real run pushed or found already
# published is written to FILE as reference, version and digest, tab-separated,
# exactly as `aggrega push` printed them — the rows scripts/record-published.sh
# records on the published branch. A dry run writes nothing to it.
#
# With --sign, each successfully-pushed reference is collected and, after the
# push loop, batch-signed with one `aggrega sign <ref>...` invocation (a single
# authentication for the whole batch). Signing is NON-INTERACTIVE ONLY in the
# keyless path: the identity token comes from --identity-token or the
# AGGREGA_IDENTITY_TOKEN / SIGSTORE_ID_TOKEN environment variable; the script
# never opens a browser and refuses to sign when no token source is present.
# --key selects offline keyed signing, which needs no token.
#
# Usage:
#   ./publish-diff.sh [--registry <host:port>] [--catalog <dir>]
#                     [--marker <tag>] [--full] [--yes] [--dry-run] [--no-advance]
#                     [--sign [--key <path>] [--identity-token <token>]]
#                     [--record-out <file>]
#
# Modes:
#   (default)     differential — publish entities changed since the marker.
#   --full        reconcile — enumerate and push every catalog entity. A real
#                 --full run is a full re-push and prompts for confirmation;
#                 --yes bypasses the prompt (CI) and a non-interactive stdin
#                 without --yes refuses rather than hanging.
#   --dry-run     print the selected references and the sign command (token
#                 redacted); no network, no OIDC, no marker advance.
#
# Env: AGGREGA_BIN overrides the `aggrega` binary (e.g. a freshly-built one).
set -euo pipefail

DIR="$(cd "$(dirname "$0")" && pwd)"
HUB_ROOT="$(cd "$DIR/.." && pwd)"

REGISTRY="127.0.0.1:5000"
CATALOG="$HUB_ROOT/aggrega-catalog"
MARKER="catalog-published"
MODE="diff"
DRYRUN=""
NO_ADVANCE=""
SIGN=""
KEY=""
IDTOKEN=""
YES=""
RECORD_OUT=""
AGGREGA="${AGGREGA_BIN:-aggrega}"

usage() {
  echo "usage: $0 [--registry <host:port>] [--catalog <dir>] [--marker <tag>] [--full] [--yes] [--dry-run] [--no-advance] [--sign [--key <path>] [--identity-token <token>]] [--record-out <file>]" >&2
}

while [ $# -gt 0 ]; do
  case "$1" in
    --registry)       REGISTRY="$2"; shift 2 ;;
    --catalog)        CATALOG="$2";  shift 2 ;;
    --marker)         MARKER="$2";   shift 2 ;;
    --full)           MODE="full";   shift ;;
    --dry-run)        DRYRUN="--dry-run"; shift ;;
    --no-advance)     NO_ADVANCE="1"; shift ;;
    --sign)           SIGN="1"; shift ;;
    --key)            KEY="$2"; shift 2 ;;
    --identity-token) IDTOKEN="$2"; shift 2 ;;
    --yes)            YES="1"; shift ;;
    --record-out)     RECORD_OUT="$2"; shift 2 ;;
    -h|--help)        usage; exit 0 ;;
    *) usage; exit 2 ;;
  esac
done

[ -d "$CATALOG" ] || { echo "publish-diff: catalog dir not found: $CATALOG" >&2; exit 1; }

# --- The entity kinds this publisher pushes -----------------------------------
# Read from the binary that does the pushing, through the one reader every script
# here shares (scripts/lib/catalog-entities.sh, which carries why the set is asked
# for rather than written down, and the plausibility floor that refuses a broken
# answer).
#
# Minus one kind, named here with its reason: Plugin. This is an entities-only
# publisher — a Plugin's .wasm is a separate artifact with its own mediatype and
# its own publish path. The exclusion is declared in the publisher that applies it,
# deliberately. What a publisher declines to push is its own call, and one shared
# exclusion list would let a widening made for a single publisher take effect
# silently in the others.
PUBLISHABLE_EXCLUDE="Plugin"
# shellcheck source=lib/catalog-entities.sh
. "$DIR/lib/catalog-entities.sh" || exit 1

# Ask before the destructive-op confirm below, so a binary that cannot answer
# refuses up front rather than after the operator has authorized a full re-push.
load_publishable_kinds "$PUBLISHABLE_EXCLUDE" || exit 1

# --- Destructive-op confirm (full reconcile) ---------------------------------
# A real --full reconcile re-pushes every catalog entity. Guard it: --yes
# bypasses (CI), an interactive terminal prompts [y/N], and a non-interactive
# stdin without --yes refuses rather than hanging. The confirm is inlined so the
# script runs from a checkout of this repository alone.
confirm_destructive() {
  local summary="$1"
  if [ -n "$YES" ]; then
    return 0
  fi
  if [ ! -t 0 ]; then
    echo "publish-diff: refusing a destructive full re-push on non-interactive stdin without --yes." >&2
    echo "  Pass --yes to proceed (CI), or --dry-run to preview safely." >&2
    return 1
  fi
  printf '%s\n' "$summary" >&2
  printf 'Proceed with the full re-push? [y/N] ' >&2
  local reply=""
  read -r reply || reply=""
  case "$reply" in
    [yY]|[yY][eE][sS]) return 0 ;;
    *) echo "publish-diff: aborted." >&2; return 1 ;;
  esac
}

if [ "$MODE" = "full" ] && [ -z "$DRYRUN" ]; then
  if ! confirm_destructive \
      "publish-diff: about to reconcile EVERY catalog entity to $REGISTRY (a full re-push)."; then
    exit 1
  fi
fi

# --- Marker seam --------------------------------------------------------------
# The ONLY two places the marker mechanism is touched. Default mechanism is a
# git tag on this repo: read = the commit the tag points at; advance = move the
# tag to HEAD. To back the marker with a remote object instead, replace the
# bodies of these two functions and nothing else.

# marker_read prints the marker commit on stdout and returns 0 when the marker
# exists, or prints nothing and returns 1 when it does not.
marker_read() {
  git -C "$HUB_ROOT" rev-parse --verify --quiet "refs/tags/${MARKER}^{commit}" 2>/dev/null
}

# marker_advance moves the marker to the current HEAD commit.
marker_advance() {
  git -C "$HUB_ROOT" tag -f "$MARKER" HEAD >/dev/null
}
# -----------------------------------------------------------------------------

# extract_reference reads captured `aggrega push` stdout and prints the
# resolved <registry>/<path>:<tag> reference — exactly the string `aggrega
# sign` consumes. "Push complete:" and "Already published:" carry it as the
# third field; the "aggrega push (dry-run):" line carries it as the fourth.
extract_reference() {
  awk '
    /^Push complete: /            { print $3; exit }
    /^Already published: /        { print $3; exit }
    /^aggrega push \(dry-run\): / { print $4; exit }
  '
}

# --- Select the candidate entity files ---------------------------------------
FILES=()
if [ "$MODE" = "full" ]; then
  # Reconcile: every catalog entity file. find is zero-count safe — absent kind
  # dirs simply contribute no matches.
  while IFS= read -r f; do
    FILES+=("$f")
  done < <(find "$CATALOG" -name '*.yaml' | sort)
else
  # Differential: files a git diff from the marker to HEAD touched, restricted
  # to the catalog subtree. --diff-filter=ACMR keeps added/copied/modified/
  # renamed (present-on-disk) files and drops deletions — a removed entity has
  # nothing to push and retirement is a separate concern.
  if ! base="$(marker_read)"; then
    echo "publish-diff: marker tag '$MARKER' not found, so a differential run has no commit to diff from." >&2
    echo "  The first publish into an empty registry, including one emptied since the catalog was" >&2
    echo "  last published, is an explicit full run: it publishes the whole catalog and" >&2
    echo "  establishes the marker." >&2
    if [ "${GITHUB_ACTIONS:-}" = "true" ]; then
      echo "  Start one by dispatching the catalog publish workflow in full mode:" >&2
      echo "    gh workflow run catalog-publish-sign.yml${GITHUB_REPOSITORY:+ --repo $GITHUB_REPOSITORY} -f mode=full -f dry_run=false" >&2
    else
      echo "  Start one by running this script again with --full added to its options, for example:" >&2
      echo "    $0 --full --registry $REGISTRY" >&2
    fi
    echo "  Create the marker tag by hand only when the registry already holds the catalog as of" >&2
    echo "  the commit you tag, because a diff from that tag publishes only what changed after it:" >&2
    echo "    git -C '$HUB_ROOT' tag $MARKER <commit-the-registry-holds>" >&2
    exit 1
  fi
  # git diff emits repo-relative paths; make them absolute for push + peeking.
  rel_catalog="${CATALOG#"$HUB_ROOT"/}"
  while IFS= read -r rel; do
    [ -n "$rel" ] || continue
    FILES+=("$HUB_ROOT/$rel")
  done < <(git -C "$HUB_ROOT" diff --name-only --diff-filter=ACMR "$base..HEAD" -- "$rel_catalog" | sort)
fi

# --- The entities among the candidates ---------------------------------------
ENTITIES=()
for f in ${FILES[@]+"${FILES[@]}"}; do
  [ -f "$f" ] || continue
  kind="$(peek_kind "$f")"
  [ -n "$kind" ] || continue          # non-entity YAML (no kind:) — skip
  is_publishable "$kind" || continue  # Plugin / deployment-side / unknown — skip
  ENTITIES+=("$f")
done

# --- The published-version guard, before anything is pushed --------------------
# Every entity this run would push is held to the version-to-digest record on the
# published branch, offline; the committed switch decides whether a version changed
# in place is a warning or a refusal. A refusal stops the run here, with nothing
# pushed, signed or marked.
if [ "${#ENTITIES[@]}" -gt 0 ]; then
  if ! AGGREGA_BIN="$AGGREGA" "$DIR/published-version-guard.sh" --files "${ENTITIES[@]}"; then
    echo "publish-diff: the published-version guard refused this run (above); nothing was pushed." >&2
    exit 1
  fi
fi

# The rows a real run records are read from each push's output by the one row
# reader both publish workflows share, published_rows_from_push.
# shellcheck source=lib/published-branch.sh
. "$DIR/lib/published-branch.sh" || exit 1
if [ -n "$RECORD_OUT" ]; then
  : >"$RECORD_OUT" || { echo "publish-diff: cannot write $RECORD_OUT" >&2; exit 1; }
fi

# --- Push loop ---------------------------------------------------------------
pushed=0; failed=0
REFS=()
for f in ${ENTITIES[@]+"${ENTITIES[@]}"}; do
  # Capture stdout to recover the resolved reference, then echo it so the push
  # output is still visible. The `if` guards the command substitution against
  # set -e while testing push's exit status.
  if out="$("$AGGREGA" push "$f" --registry "$REGISTRY" $DRYRUN)"; then
    printf '%s\n' "$out"
    pushed=$((pushed + 1))
    ref="$(printf '%s\n' "$out" | extract_reference)"
    [ -n "$ref" ] && REFS+=("$ref")
    if [ -n "$RECORD_OUT" ] && [ -z "$DRYRUN" ]; then
      printf '%s\n' "$out" | published_rows_from_push >>"$RECORD_OUT"
    fi
  else
    printf '%s\n' "$out"
    echo "publish-diff: PUSH FAILED: $f" >&2
    failed=$((failed + 1))
  fi
done

if [ "$MODE" = "full" ]; then
  echo "publish-diff: full reconcile: $pushed pushed, $failed failed -> $REGISTRY"
else
  echo "publish-diff: differential: $pushed pushed, $failed failed -> $REGISTRY"
fi

# --- Sign (opt-in) -----------------------------------------------------------
sign_failed=0
if [ -n "$SIGN" ]; then
  if [ "${#REFS[@]}" -eq 0 ]; then
    echo "publish-diff: --sign: no references to sign"
  elif [ -n "$DRYRUN" ]; then
    # Print the sign command that WOULD run (token value redacted); execute
    # nothing. No network or OIDC contact occurs in dry-run.
    printf 'publish-diff: --sign --dry-run: would run:\n '
    printf ' %q' "$AGGREGA" sign
    [ -n "$KEY" ]     && printf ' %q %q' --key "$KEY"
    [ -n "$IDTOKEN" ] && printf ' %q %q' --identity-token '<redacted>'
    printf ' %q' "${REFS[@]}"
    printf '\n'
  elif [ -n "$KEY" ]; then
    # Offline keyed signing needs no identity token.
    if "$AGGREGA" sign --key "$KEY" "${REFS[@]}"; then
      echo "publish-diff: signed ${#REFS[@]} reference(s) with key -> $REGISTRY"
    else
      echo "publish-diff: SIGN FAILED" >&2
      sign_failed=1
    fi
  else
    # Keyless path is non-interactive only: refuse to sign without a token
    # source so the flow can never fall back to an interactive browser prompt.
    if [ -z "$IDTOKEN" ] && [ -z "${AGGREGA_IDENTITY_TOKEN:-}" ] && [ -z "${SIGSTORE_ID_TOKEN:-}" ]; then
      echo "publish-diff: --sign: no identity token; pass --identity-token or export AGGREGA_IDENTITY_TOKEN / SIGSTORE_ID_TOKEN (non-interactive signing only), or use --key for offline keyed signing" >&2
      sign_failed=1
    else
      sign_cmd=("$AGGREGA" sign)
      [ -n "$IDTOKEN" ] && sign_cmd+=(--identity-token "$IDTOKEN")
      sign_cmd+=("${REFS[@]}")
      if "${sign_cmd[@]}"; then
        echo "publish-diff: signed ${#REFS[@]} reference(s) -> $REGISTRY"
      else
        echo "publish-diff: SIGN FAILED" >&2
        sign_failed=1
      fi
    fi
  fi
fi

# --- Advance the marker on a fully successful, real publish ------------------
if [ "$failed" -eq 0 ] && [ "$sign_failed" -eq 0 ]; then
  if [ -n "$DRYRUN" ]; then
    :  # dry-run mutates nothing, including the marker.
  elif [ -n "$NO_ADVANCE" ]; then
    echo "publish-diff: --no-advance: marker '$MARKER' left unchanged"
  else
    marker_advance
    echo "publish-diff: marker '$MARKER' advanced to $(git -C "$HUB_ROOT" rev-parse --short HEAD)"
  fi
fi

[ "$failed" -eq 0 ] && [ "$sign_failed" -eq 0 ]
