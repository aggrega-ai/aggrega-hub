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
# ONE NAME FOR THE MARKER. Which tag marks where the last successful publish left
# the catalog is PUBLISH_MARKER_TAG in scripts/lib/published-branch.sh, the
# constant scripts/publish-diff.sh defaults its marker from, so the guard and the
# publisher cannot hold different tags. --help prints the name from it too. The
# marker is read through published_marker_read in the same library, the seam
# scripts/publish-diff.sh reads and moves it through, so a marker kept some other
# way than as a git tag is changed in one place for both.
#
# A RELEASED VERSION DIRECTORY NEEDS ONLY GIT. Which version directories the tag
# holds is read from the tag's tree, and a staged path's version directory from its
# path: the first directory below the kind named as a version, which is the layout
# the catalog conventions give every kind. No binary is asked, so this half judges
# every kind, a Plugin entity included, and judges it where the dry run cannot run.
#
# Which entity a staged path belongs to is answered by walking up from the path to
# the nearest directory holding an entity document in the index — the per-version
# directory every published entity lives in, with every file it carries beneath it.
# The entity is then rebuilt from the index alone in a scratch directory, so what is
# judged is what the commit carries, never the working tree.
#
# SEVERAL AT ONCE, THE SAME FINDINGS. --jobs N runs up to N of the dry runs at once
# (default 1, one at a time), because each mostly waits on start-up and on any source
# it fetches. Every dry run's output is read back in the order the entities were
# queued (scripts/lib/bounded-jobs.sh), so the findings, their order and the exit
# status are the ones a run one at a time gives. Concurrent dry runs fetch into a
# scratch workspace each, which the guard can give them only when it made the
# scratch workspace itself; with a workspace given to it, it judges one at a time.

usage() {
  # The delimiter is not a word the text uses on a line of its own. The text is
  # held quoted, so nothing in it expands, and @MARKER@ is then replaced by the
  # marker tag's name from its one constant.
  local text
  text="$(cat <<'END_OF_HELP'
published-version-guard.sh — hold every published version of a catalog entity to
the digest the registry holds for it, and every path the publish workflows own to
what they published.

USAGE
  scripts/published-version-guard.sh [--jobs N] --staged
  scripts/published-version-guard.sh [--jobs N] --files ENTITY-FILE...
  scripts/published-version-guard.sh -h | --help

  --staged   judge the commit being made, as the index holds it, by all three
             rules below. The pre-commit hook runs this form.
  --files    judge the entity documents named, as they are on disk, by A
             PUBLISHED VERSION CHANGED IN PLACE only. The catalog publisher runs
             this form over the entities it is about to push, before it pushes
             any, with its push bound as --jobs.
  --jobs N   judge up to N entities at once, N a whole number of at least 1;
             default 1, one at a time. At any bound the findings are the ones a
             run one at a time gives, in the same order. Above 1 each dry run
             fetches into a workspace of its own (THE RECORD, below), so with a
             workspace given to the guard — one AGGREGA_WORKSPACE_ROOT names, or
             one the repository is in — it judges one at a time and says so
             once. More than one at once needs bash 5.1 or later.

  It judges the repository it belongs to, wherever it is run from; relative
  paths are read from where it is run. AGGREGA_BIN names the aggrega
  binary (default: aggrega on PATH). PUBLISHED_REMOTE names the remote whose
  published branch is read (default: the remote the checked-out branch tracks,
  else origin).

THE RECORD
  The guard reads .ci-published-digests from <remote>/published as last fetched,
  and the publish marker tag as this clone holds it, and contacts no git remote;
  the dry run it runs contacts no registry. The
  one fetch a run can make is the dry run's own: for a Recipe or FeatureRecipe
  whose remote source is written out in full, aggrega push --dry-run fetches that
  source to compare its pin, into the cache of the Aggrega workspace the dry run
  uses: the one AGGREGA_WORKSPACE_ROOT names, else the one aggrega finds. With
  that variable unset, a repository that is in no workspace — a checkout on its
  own — gets a scratch workspace in the run's temporary directory, removed when
  the run exits; with --jobs above 1 each dry run gets a scratch workspace of its
  own there instead, because two fetches of one source into one workspace's
  artifact cache at once can read each other's partly written copy. With no
  published branch fetched, nothing is
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
  passes. A Plugin entity is not judged by this comparison: its digest covers its
  .wasm, which this repository does not carry, and the plugin entities are owned
  paths (below). A removed version directory is not judged by it either. With
  --staged, both are judged by A RELEASED VERSION DIRECTORY CHANGED, below.

  The switch: .published-version-guard, committed, holds warn or block, and it
  decides this finding and the next one alike. With warn, a finding is printed
  as a warning and the run passes; with block, the run refuses. A switch that is
  absent, or holds anything else, blocks and says so. It is read from the
  committed HEAD, never from what is staged, so a commit cannot loosen the guard
  for itself.

  What the guard cannot judge for a recorded version — no binary, a binary whose
  dry run prints no digest, an entity the dry run refuses — is reported with the
  reason: a warning with warn, a refusal with block.

A RELEASED VERSION DIRECTORY CHANGED (--staged)
  The catalog is released where the last successful publish left it: the tag
  @MARKER@, the marker scripts/publish-diff.sh diffs from and moves to
  what it published after every successful real publish. The guard judges
  every staged addition, change or removal under aggrega-catalog/ against that
  tag's tree: a file under a version directory that exists at the tag is part
  of a released version, whatever the entity's kind, so a Plugin entity's
  version directory, a removal and a file added beside the entity are held as
  an edit is. For each such version directory it
  names the entity, the version, the tag and the files the commit adds, changes
  or removes, and says to copy the entity into a new version directory — patch,
  minor or major, as "Choosing a new version" in
  docs/catalog-conventions-and-patches.md says — and change it there.

  A version directory is the first directory below aggrega-catalog/<kind>/ whose
  name is a version (1.0.0, 0.9.0-rc.2), the layout every kind follows. One the
  tag does not hold — a new version directory — passes. This rule asks no
  binary and no registry: git alone answers it. A path the publish workflows own
  (below) staged exactly as <remote>/published holds it — the sync commit — is
  what the publishers wrote, and this rule does not judge it. The switch above
  decides a finding here as it decides one there: warn prints it, block refuses.

  A clone that holds no tag @MARKER@ cannot be judged by this
  rule: a commit there that changes a file under a version directory draws a
  finding saying so, under the same switch — a warning with warn, a refusal
  with block. Fetch the tag (git fetch origin tag @MARKER@) and
  commit again.

  What it does not reach:
    - a commit made with the hook bypassed (git commit --no-verify), and a
      commit in a clone outside the workspace, where no hook runs;
    - a tag fetched before the latest publish: it holds what that publish held.
      A fetch does not move a tag the clone already has;
      git fetch --force origin tag @MARKER@ moves it;
    - a publish whose push of the tag failed: the tag stays where the publish
      before it left the catalog until the next successful publish moves it.

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
)"
  printf '%s\n' "${text//@MARKER@/$PUBLISH_MARKER_TAG}"
}

HERE="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)" || exit 2
# shellcheck source=lib/bounded-jobs.sh
. "$HERE/lib/bounded-jobs.sh" || exit 2
# Sourced before the arguments are read, because --help prints the marker tag's
# name from it.
# shellcheck source=lib/published-branch.sh
. "$HERE/lib/published-branch.sh" || exit 2

MODE=""
ARGS=()
JOBS=1
while [ "$#" -gt 0 ]; do
  case "$1" in
    -h | --help) usage; exit 0 ;;
    --jobs)
      [ "$#" -ge 2 ] || { echo "published-version-guard: --jobs needs a value: a whole number of at least 1 (see --help)" >&2; exit 2; }
      bounded_jobs_bound_ok "$2" || { echo "published-version-guard: --jobs takes a whole number of at least 1, not '$2' (see --help)" >&2; exit 2; }
      JOBS="$2"; shift 2 ;;
    --staged) [ -z "$MODE" ] || { echo "published-version-guard: one of --staged or --files (see --help)" >&2; exit 2; }; MODE=staged; shift ;;
    --files) [ -z "$MODE" ] || { echo "published-version-guard: one of --staged or --files (see --help)" >&2; exit 2; }; MODE=files; shift; ARGS=("$@"); break ;;
    *) echo "published-version-guard: unknown argument '$1' (see --help)" >&2; exit 2 ;;
  esac
done
[ -n "$MODE" ] || { echo "published-version-guard: name --staged or --files (see --help)" >&2; exit 2; }
if [ "$JOBS" -gt 1 ] && ! bounded_jobs_concurrency_available; then
  echo "published-version-guard: judging more than one entity at once needs bash 5.1 or later, and this is bash $BASH_VERSION; run with --jobs 1" >&2
  exit 2
fi

set -uo pipefail
# shellcheck source=lib/catalog-entities.sh
. "$HERE/lib/catalog-entities.sh" || exit 2
# shellcheck source=lib/scratch-workspace.sh
. "$HERE/lib/scratch-workspace.sh" || exit 2

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
# SYNCED: the owned paths this commit changes to exactly what the published branch
# holds there — what the publishers wrote, which the released-version rule leaves
# alone.
SYNCED=()
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
    if [ "$rc" -eq 0 ]; then SYNCED+=("$p"); continue; fi
    refuse "$p is owned by the publish workflows ($REMOTE/$PUBLISHED_BRANCH:$OWNED_PATHS_FILE), and this commit stages content there that $REMOTE/$PUBLISHED_BRANCH does not hold. Only the publish workflows change it; take what they published with the sync commit, or unstage the change: git restore --staged --worktree --source=HEAD -- $p"
  done
fi

# --- a released version directory changed ---------------------------------------
# version_dir PATH — prints the version directory PATH lies under: the first
# directory below aggrega-catalog/<kind>/ whose name is a version. Returns 1 when
# PATH lies under none.
version_dir() {
  local rest="${1#"$CATALOG_ROOT"/}" dir="$CATALOG_ROOT" seg
  local -a segs=()
  IFS=/ read -r -a segs <<<"$rest"
  # The last segment is the file itself and the first is the kind; a version
  # directory is one of the directories between them.
  [ "${#segs[@]}" -ge 3 ] || return 1
  dir="$dir/${segs[0]}"
  for seg in "${segs[@]:1:${#segs[@]}-2}"; do
    dir="$dir/$seg"
    if [[ $seg =~ ^[0-9]+\.[0-9]+\.[0-9]+([-+][0-9A-Za-z.+-]+)?$ ]]; then
      printf '%s\n' "$dir"
      return 0
    fi
  done
  return 1
}

# synced PATH — whether PATH lies under an owned path this commit stages exactly as
# the published branch holds it.
synced() {
  local p
  for p in ${SYNCED[@]+"${SYNCED[@]}"}; do
    case "$1" in "$p" | "$p"/*) return 0 ;; esac
  done
  return 1
}

if [ "$MODE" = staged ]; then
  MARKER="${PUBLISH_MARKER_TAG:-}"
  [ -n "$MARKER" ] || broken "scripts/lib/published-branch.sh sets no PUBLISH_MARKER_TAG, so the publish marker is unknown"
  git diff --cached --name-status -z --no-renames "$BASE" -- "$CATALOG_ROOT/" >"$TMP/catalog-changes" ||
    broken "git cannot list what is staged under $CATALOG_ROOT/"
  # The staged changes under a version directory, the sync's own excepted: the
  # status, the path and its version directory, three to an entry.
  CANDIDATES=()
  mapfile -d '' -t STAGED < "$TMP/catalog-changes"
  for ((i = 0; i + 1 < ${#STAGED[@]}; i += 2)); do
    f="${STAGED[i + 1]}"
    synced "$f" && continue
    vdir="$(version_dir "$f")" || continue
    CANDIDATES+=("${STAGED[i]}" "$f" "$vdir")
  done
  if [ "${#CANDIDATES[@]}" -gt 0 ]; then
    # Read through the marker seam the publisher reads it through
    # (scripts/lib/published-branch.sh), the one place the mechanism lives.
    if ! MARKER_SHA="$(published_marker_read "$TOP" "$MARKER")"; then
      # Unjudged is a finding, as an unjudged recorded version is: a missing tag
      # never passes a commit at block.
      finding "$CATALOG_ROOT: not judged — this commit changes files under a version directory, and this clone holds no tag $MARKER, so which version directories are released cannot be read. Fetch it, then commit again: git fetch origin tag $MARKER"
    else
      HELD_DIRS=()
      declare -A HELD_FILES=() HELD_COUNT=()
      for ((i = 0; i + 2 < ${#CANDIDATES[@]}; i += 3)); do
        st="${CANDIDATES[i]}"
        f="${CANDIDATES[i + 1]}"
        vdir="${CANDIDATES[i + 2]}"
        git cat-file -e "$MARKER_SHA:$vdir" 2>/dev/null || continue
        case "$st" in
          A*) verb="adds" ;;
          D*) verb="removes" ;;
          *) verb="changes" ;;
        esac
        if [ -z "${HELD_FILES[$vdir]+set}" ]; then
          HELD_DIRS+=("$vdir")
          HELD_COUNT[$vdir]=0
        fi
        n="${HELD_COUNT[$vdir]}"
        HELD_COUNT[$vdir]=$((n + 1))
        # The first few files are named; the rest are counted.
        if [ "$n" -lt 5 ]; then
          HELD_FILES[$vdir]="${HELD_FILES[$vdir]:+${HELD_FILES[$vdir]}, }$verb ${f#"$vdir"/}"
        fi
      done
      for vdir in ${HELD_DIRS[@]+"${HELD_DIRS[@]}"}; do
        entity="${vdir#"$CATALOG_ROOT"/}"
        entity="${entity%/*}"
        version="${vdir##*/}"
        if [ -z "$(git ls-files -- "$vdir/")" ]; then
          what="removes the whole version directory"
        else
          what="${HELD_FILES[$vdir]}"
          n="${HELD_COUNT[$vdir]}"
          [ "$n" -le 5 ] || what="$what, and $((n - 5)) more file(s)"
        fi
        finding "$vdir: $entity $version is released — the version directory is in the catalog where the last successful publish left it (tag $MARKER, at ${MARKER_SHA:0:12}) — and this commit $what. A released version is final: copy the entity into a new version directory, choosing patch, minor or major as \"Choosing a new version\" in docs/catalog-conventions-and-patches.md says, change it there, and leave $version as it was released."
      done
    fi
  fi
fi

# --- a published version changed in place ---------------------------------------
# The rows the record holds; with none, there is nothing to judge.
ROWS=""
if [ "$HAVE_PUB" = 1 ] && git cat-file -e "$PUB:$DIGESTS_FILE" 2>/dev/null; then
  ROWS="$(git show "$PUB:$DIGESTS_FILE" | published_rows)" || broken "git cannot read $REMOTE/$PUBLISHED_BRANCH:$DIGESTS_FILE"
fi

# recorded_digests PATH VERSION — the digests the record holds for the reference
# ending in /PATH at VERSION, one a line.
# shellcheck disable=SC2329 # called from judge, which bounded_jobs reaches by name
recorded_digests() {
  printf '%s\n' "$ROWS" | awk -F'\t' -v p="/$1" -v v="$2" '
    $2 == v && ($1 == substr(p, 2) || (length($1) > length(p) && substr($1, length($1) - length(p) + 1) == p)) { print $3 }'
}

# settle_workspace — names the workspace the dry runs use
# (scripts/lib/scratch-workspace.sh), and decides how they share it: above a bound
# of 1, a workspace of their own each when the guard made the scratch one, and one
# at a time, said once, when a workspace was given to it.
JUDGE_WORKSPACES=0
settle_workspace() {
  local given="${AGGREGA_WORKSPACE_ROOT:-}"
  scratch_workspace_root "$TMP" "$TOP" || broken "cannot make a scratch workspace in $TMP"
  [ "$JOBS" -gt 1 ] || return 0
  if [ -z "$given" ] && [ -n "${AGGREGA_WORKSPACE_ROOT:-}" ]; then
    JUDGE_WORKSPACES=1
  else
    echo "published-version-guard: entities are judged one at a time, not $JOBS at once: the guard uses a workspace it did not make, and two fetches of one source into one workspace's artifact cache at once can read each other's partly written copy. With AGGREGA_WORKSPACE_ROOT unset, a repository outside any workspace gives each concurrent dry run a workspace of its own." >&2
    JOBS=1
  fi
}

# The entities to judge, by position: the label a finding names each by, the folder
# its dry run runs in, and its document relative to that folder.
JUDGE_LABEL=()
JUDGE_ROOT=()
JUDGE_DOC=()

# judge_run INDEX — run the dry run over the entity at INDEX, its standard error
# with its standard output. Above a bound of 1 it fetches into a workspace of its
# own when the guard made the scratch one, removed when the dry run ends.
# shellcheck disable=SC2329 # called by name, through bounded_jobs
judge_run() {
  local rc=0
  if [ "$JUDGE_WORKSPACES" = 1 ]; then
    AGGREGA_WORKSPACE_ROOT="$TMP/judge/workspace-$1"
    mkdir "$AGGREGA_WORKSPACE_ROOT" || { echo "cannot make a workspace in $TMP/judge"; return 1; }
    export AGGREGA_WORKSPACE_ROOT
  fi
  (cd "${JUDGE_ROOT[$1]}" && "$AGGREGA" push --dry-run --pin-sources=false --registry "$GUARD_REGISTRY" "${JUDGE_DOC[$1]}" 2>&1) || rc=$?
  if [ "$JUDGE_WORKSPACES" = 1 ]; then
    rm -rf "$AGGREGA_WORKSPACE_ROOT"
  fi
  return "$rc"
}

# judge_read INDEX ITEM STATUS OUTFILE — judge what the dry run at INDEX printed,
# and how it exited, against the record. ITEM is INDEX again: the queue is handed
# to bounded_jobs by position.
# shellcheck disable=SC2329 # called by name, through bounded_jobs
judge_read() {
  judge "${JUDGE_LABEL[$1]}" "$3" "$(cat "$4")"
}

# judge_all — judge every entity queued in JUDGE_*, up to JOBS at once, the
# findings added in queue order.
judge_all() {
  [ "${#JUDGE_LABEL[@]}" -gt 0 ] || return 0
  mkdir -p "$TMP/judge" || broken "cannot make a scratch directory"
  bounded_jobs "$JOBS" "$TMP/judge" judge_run judge_read "${!JUDGE_LABEL[@]}"
}

# judge LABEL RC OUT — judge what one dry run printed (OUT), and the status it
# exited with (RC), against the record. LABEL names the entity in a finding.
# shellcheck disable=SC2329 # called from judge_read, which bounded_jobs calls by name
judge() {
  local label="$1" rc="$2" out="$3" line reftag ref tag digest path published d
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
      # The workspace the dry runs use (scripts/lib/scratch-workspace.sh), settled
      # here rather than at the top, so a run with nothing to judge never calls the
      # binary.
      settle_workspace
      if load_publishable_kinds Plugin; then
        for f in "${ARGS[@]}"; do
          [ -f "$f" ] || { finding "$f: not judged — no such file"; continue; }
          kind="$(peek_kind "$f")"
          is_publishable "$kind" && DOCS+=("$f")
        done
        for f in ${DOCS[@]+"${DOCS[@]}"}; do
          JUDGE_LABEL+=("$f"); JUDGE_ROOT+=("$TOP"); JUDGE_DOC+=("$f")
        done
        judge_all
      else
        finding "the entities named: not judged — the entity kinds could not be read from $AGGREGA (above)"
      fi
    fi
  else
    mapfile -d '' -t CHANGED < <(git diff --cached --name-only -z --no-renames "$BASE" -- "$CATALOG_ROOT/")
    if [ "${#CHANGED[@]}" -gt 0 ]; then
      settle_workspace
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
          JUDGE_LABEL+=("$doc"); JUDGE_ROOT+=("$root"); JUDGE_DOC+=("$doc")
        done
        judge_all
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
