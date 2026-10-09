#!/usr/bin/env bash
# scripts/published-version-guard.sh — hold every published version of a catalog
# entity to the digest the registry holds for it, and every path the publish
# workflows own to what they published.
#
# --help is the contract: both forms, what each judges, the switch, and every exit
# code. This header carries the reasoning behind the shape.
#
# ONE COMPUTATION OF THE DIGEST. The digest an entity would publish under is not
# computed here: `aggrega push --dry-run` computes it, offline, by the computation
# `aggrega push` publishes with, and this script reads it from the line the dry run
# prints. A second implementation would agree with the publisher until either moved.
#
# ONE OWNERSHIP LIST. Which paths the publishers own is read from the published
# branch's own list, the list the workspace's sync takes paths by, so the refusal
# and the sync cannot disagree about a path.
#
# THE COMMITTED SWITCH, NOT THE STAGED ONE. A commit is judged under the switch as
# it stood before that commit, so no commit can loosen the guard for itself.
#
# Which entity a staged path belongs to is answered by walking up from the path to
# the nearest directory holding an entity document in the index — the per-version
# directory every published entity lives in, with every file it carries beneath it.
# The entity is then rebuilt from the index alone in a scratch directory, so what is
# judged is what the commit carries, never the working tree.

usage() {
  # The delimiter is not a word the text uses on a line of its own.
  cat <<'END_OF_HELP'
published-version-guard.sh — hold every published version of a catalog entity to
the digest the registry holds for it, and every path the publish workflows own to
what they published.

USAGE
  scripts/published-version-guard.sh --staged
  scripts/published-version-guard.sh --files ENTITY-FILE...
  scripts/published-version-guard.sh -h | --help

  --staged   judge the commit being made, as the index holds it. The pre-commit
             hook runs this form.
  --files    judge the entity documents named, as they are on disk. The catalog
             publisher runs this form over the entities it is about to push,
             before it pushes any.

  It judges the repository it belongs to, wherever it is run from; relative
  paths are read from where it is run. AGGREGA_BIN names the aggrega
  binary (default: aggrega on PATH). PUBLISHED_REMOTE names the remote whose
  published branch is read (default: the remote the checked-out branch tracks,
  else origin).

THE RECORD
  The guard reads .ci-published-digests from <remote>/published as last fetched
  and contacts no git remote, and the dry run it runs contacts no registry. The
  one fetch a run can make is the dry run's own: for a Recipe or FeatureRecipe
  whose remote source is written out in full, aggrega push --dry-run fetches that
  source to compare its pin. With no published branch fetched, nothing is
  recorded and nothing is judged. A record fetched before a publish
  misses only the versions published since, which aggrega push still refuses to
  overwrite when they are published again.

A PUBLISHED VERSION CHANGED IN PLACE
  The guard judges, with --staged, every entity whose version directory holds a
  staged change — an addition, an edit or a removal of any file the entity
  carries — read as the index holds it; with --files, each entity named. For
  each it runs
      aggrega push --dry-run --pin-sources=false --registry guard.invalid <entity>
  which computes, without contacting any registry, the reference, the version
  and the digest aggrega push would publish, by the computation aggrega push
  publishes with. When the record holds that reference at that version and none
  of its digests is that digest, the entity was changed in place at a version
  already published: the guard names the entity, the version and the published
  digest, and says to copy the entity into a new version directory and change it
  there.

  An entity at a version the record does not hold — a new version directory —
  passes. A Plugin entity is not judged here: its digest covers its .wasm, which
  this repository does not carry, and the plugin entities are owned paths
  (below). A removed version directory is not judged: the registry keeps what it
  holds.

  The switch: .published-version-guard, committed, holds warn or block. With
  warn, a finding is printed as a warning and the run passes; with block, the
  run refuses. A switch that is absent, or holds anything else, blocks and says
  so. It is read from the committed HEAD, never from what is staged, so a commit
  cannot loosen the guard for itself.

  What the guard cannot judge for a recorded version — no binary, a binary whose
  dry run prints no digest, an entity the dry run refuses — is reported with the
  reason: a warning with warn, a refusal with block.

A PATH THE PUBLISH WORKFLOWS OWN (--staged)
  .ci-owned-paths on <remote>/published names the paths the publish workflows
  own; a directory means everything under it. A commit that changes an owned
  path is refused unless what it stages there is exactly what <remote>/published
  holds there — the sync commit, which takes exactly those paths from the
  published branch, is such a commit. This refusal is not under the switch. With
  no published branch fetched, no path is owned.

EXIT CODES
  0  nothing refused; warnings, if any, are printed
  1  refused; each finding is named
  2  a usage error, or the guard could not run — the published branch's list
     unreadable, a git command failing — and nothing was judged
END_OF_HELP
}

MODE=""
ARGS=()
while [ "$#" -gt 0 ]; do
  case "$1" in
    -h | --help) usage; exit 0 ;;
    --staged) [ -z "$MODE" ] || { echo "published-version-guard: one of --staged or --files (see --help)" >&2; exit 2; }; MODE=staged; shift ;;
    --files) [ -z "$MODE" ] || { echo "published-version-guard: one of --staged or --files (see --help)" >&2; exit 2; }; MODE=files; shift; ARGS=("$@"); break ;;
    *) echo "published-version-guard: unknown argument '$1' (see --help)" >&2; exit 2 ;;
  esac
done
[ -n "$MODE" ] || { echo "published-version-guard: name --staged or --files (see --help)" >&2; exit 2; }

set -uo pipefail
HERE="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)" || exit 2
# shellcheck source=lib/published-branch.sh
. "$HERE/lib/published-branch.sh" || exit 2
# shellcheck source=lib/catalog-entities.sh
. "$HERE/lib/catalog-entities.sh" || exit 2

# Paths given relative to where the guard was started — the binary and the entity
# files — are made absolute before it moves, so they name the same files from the
# repository's top and from the scratch directory each staged entity is judged in.
AGGREGA="${AGGREGA_BIN:-aggrega}"
case "$AGGREGA" in
  /*) ;;
  */*) AGGREGA="$PWD/$AGGREGA" ;;
esac
for i in "${!ARGS[@]}"; do
  case "${ARGS[i]}" in /*) ;; *) ARGS[i]="$PWD/${ARGS[i]}" ;; esac
done
# The repository judged is the one this script belongs to, wherever it is run from.
TOP="$(git -C "$HERE/.." rev-parse --show-toplevel 2>/dev/null)" || { echo "published-version-guard: $HERE/.. is not inside a git repository" >&2; exit 2; }
cd "$TOP" || exit 2
export GIT_OPTIONAL_LOCKS=0
REMOTE="${PUBLISHED_REMOTE:-$(published_remote .)}"
PUB="refs/remotes/$REMOTE/$PUBLISHED_BRANCH"
CATALOG_ROOT="aggrega-catalog"
# A registry name that resolves nowhere: the dry run composes the reference under
# it and contacts nothing, and the guard compares what follows it.
GUARD_REGISTRY="guard.invalid"
TMP="$(mktemp -d)" || exit 2
trap 'rm -rf "$TMP"' EXIT

REFUSED=0
FINDINGS=()

broken() { echo "published-version-guard: $1 — nothing was judged" >&2; exit 2; }
refuse() { REFUSED=1; printf '✗ %s\n' "$1"; }
# finding TEXT — a published-version finding, which the switch decides.
finding() { FINDINGS+=("$1"); }

if git rev-parse -q --verify "$PUB^{commit}" >/dev/null; then HAVE_PUB=1; else HAVE_PUB=0; fi
if [ "$MODE" = staged ]; then
  if git rev-parse -q --verify 'HEAD^{commit}' >/dev/null; then
    BASE=HEAD
  else
    BASE="$(git hash-object -t tree /dev/null)" || broken "git cannot name the empty tree"
  fi
fi

# --- the paths the publish workflows own --------------------------------------
if [ "$MODE" = staged ] && [ "$HAVE_PUB" = 1 ]; then
  git show "$PUB:$OWNED_PATHS_FILE" >"$TMP/owned" 2>/dev/null ||
    broken "$REMOTE/$PUBLISHED_BRANCH carries no $OWNED_PATHS_FILE, so the paths the publish workflows own are unknown"
  published_read_owned "$TMP/owned" ||
    broken "$REMOTE/$PUBLISHED_BRANCH:$OWNED_PATHS_FILE names '$BAD_ENTRY', which is not a plain path inside the repository"
  for p in "${OWNED[@]}"; do
    rc=0
    git --literal-pathspecs diff --cached --quiet "$BASE" -- "$p" || rc=$?
    [ "$rc" -le 1 ] || broken "git cannot compare what is staged under $p with $BASE"
    [ "$rc" -eq 1 ] || continue
    rc=0
    git --literal-pathspecs diff --cached --quiet "$PUB" -- "$p" || rc=$?
    [ "$rc" -le 1 ] || broken "git cannot compare what is staged under $p with $REMOTE/$PUBLISHED_BRANCH"
    [ "$rc" -eq 1 ] || continue
    refuse "$p is owned by the publish workflows ($REMOTE/$PUBLISHED_BRANCH:$OWNED_PATHS_FILE), and this commit stages content there that $REMOTE/$PUBLISHED_BRANCH does not hold. Only the publish workflows change it; take what they published with the sync commit, or unstage the change: git restore --staged --worktree --source=HEAD -- $p"
  done
fi

# --- a published version changed in place ---------------------------------------
# The rows the record holds; with none, there is nothing to judge.
ROWS=""
if [ "$HAVE_PUB" = 1 ] && git cat-file -e "$PUB:$DIGESTS_FILE" 2>/dev/null; then
  ROWS="$(git show "$PUB:$DIGESTS_FILE" | published_rows)" || broken "git cannot read $REMOTE/$PUBLISHED_BRANCH:$DIGESTS_FILE"
fi

# recorded_digests PATH VERSION — the digests the record holds for the reference
# ending in /PATH at VERSION, one a line.
recorded_digests() {
  printf '%s\n' "$ROWS" | awk -F'\t' -v p="/$1" -v v="$2" '
    $2 == v && ($1 == substr(p, 2) || (length($1) > length(p) && substr($1, length($1) - length(p) + 1) == p)) { print $3 }'
}

# judge LABEL ROOT DOC — run the dry run over DOC (relative to ROOT) and judge what
# it prints against the record. LABEL names the entity in a finding.
judge() {
  local label="$1" root="$2" doc="$3" out rc=0 line reftag ref tag digest path published d
  out="$(cd "$root" && "$AGGREGA" push --dry-run --pin-sources=false --registry "$GUARD_REGISTRY" "$doc" 2>&1)" || rc=$?
  line="$(printf '%s\n' "$out" | awk '/^aggrega push \(dry-run\): /{ print; exit }')"
  if [ "$rc" -ne 0 ] || [ -z "$line" ]; then
    # Unjudged, and whether its version is recorded cannot be read without the
    # dry run's answer, so it is reported for every such entity.
    finding "$label: not judged — '$AGGREGA push --dry-run' refused it (exit $rc): $(printf '%s' "$out" | tail -n 3 | tr '\n' ' ')"
    return
  fi
  # aggrega push (dry-run): <registry>/<path>:<version> (<digest>)
  reftag="$(printf '%s\n' "$line" | awk '{ print $4 }')"
  digest="$(printf '%s\n' "$line" | awk '{ d = $5; gsub(/^\(|\)$/, "", d); print d }')"
  ref="${reftag%:*}"
  tag="${reftag##*:}"
  path="${ref#"$GUARD_REGISTRY"/}"
  published="$(recorded_digests "$path" "$tag")"
  [ -n "$published" ] || return 0
  if [ -z "$digest" ]; then
    finding "$label: not judged — $path $tag is published, and '$AGGREGA push --dry-run' prints no digest to compare. Point AGGREGA_BIN at a binary whose dry run prints one."
    return
  fi
  while IFS= read -r d; do
    [ "$d" = "$digest" ] && return 0
  done <<<"$published"
  finding "$label: $path $tag is already published, as $(printf '%s' "$published" | tr '\n' ' ' | sed 's/ $//'), and what is here now digests to $digest. A published version is final: copy the entity into a new version directory, change it there, and leave $tag as it was published."
}

if [ -n "$ROWS" ]; then
  DOCS=()
  if [ "$MODE" = files ]; then
    if [ "${#ARGS[@]}" -gt 0 ]; then
      if load_publishable_kinds Plugin; then
        for f in "${ARGS[@]}"; do
          [ -f "$f" ] || { finding "$f: not judged — no such file"; continue; }
          kind="$(peek_kind "$f")"
          is_publishable "$kind" && DOCS+=("$f")
        done
        for f in ${DOCS[@]+"${DOCS[@]}"}; do judge "$f" "$TOP" "$f"; done
      else
        finding "the entities named: not judged — the entity kinds could not be read from $AGGREGA (above)"
      fi
    fi
  else
    mapfile -d '' -t CHANGED < <(git diff --cached --name-only -z --no-renames "$BASE" -- "$CATALOG_ROOT/")
    if [ "${#CHANGED[@]}" -gt 0 ]; then
      if load_publishable_kinds Plugin; then
        declare -A SEEN=()
        for f in "${CHANGED[@]}"; do
          d="$(dirname -- "$f")"
          while [ "$d" != "$CATALOG_ROOT" ] && [ "$d" != "." ] && [ "$d" != "/" ]; do
            doc=""
            while IFS= read -r -d '' y; do
              kind="$(git show ":$y" | peek_kind -)"
              if is_publishable "$kind"; then doc="$y"; break; fi
            done < <(git ls-files -z -- ":(glob)$d/*.yaml")
            if [ -n "$doc" ]; then
              [ -n "${SEEN[$doc]:-}" ] || { SEEN[$doc]=1; DOCS+=("$doc"); }
              break
            fi
            d="$(dirname -- "$d")"
          done
        done
        for doc in ${DOCS[@]+"${DOCS[@]}"}; do
          root="$TMP/entity-$RANDOM$RANDOM"
          mkdir -p "$root" || broken "cannot make a scratch directory"
          git ls-files -z -- "$(dirname -- "$doc")/" | git checkout-index -z --stdin --prefix="$root/" ||
            broken "git cannot write the staged $(dirname -- "$doc") into a scratch directory"
          judge "$doc" "$root" "$doc"
        done
      else
        finding "the staged catalog changes: not judged — the entity kinds could not be read from $AGGREGA (above)"
      fi
    fi
  fi
fi

if [ "${#FINDINGS[@]}" -gt 0 ]; then
  published_switch .
  if [ "$SWITCH" = warn ]; then
    for f in "${FINDINGS[@]}"; do printf '⚠ published version (%s is warn): %s\n' "$GUARD_SWITCH_FILE" "$f"; done
  else
    for f in "${FINDINGS[@]}"; do refuse "$f"; done
    [ -z "$SWITCH_NOTE" ] || printf '  (%s)\n' "$SWITCH_NOTE"
  fi
fi

[ "$REFUSED" -eq 0 ] || exit 1
exit 0
