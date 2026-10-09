#!/usr/bin/env bash
# scripts/record-published.sh — record what a publish workflow published on the
# published branch: one commit on top of what that branch holds, pushed only as a
# fast-forward of it.
#
# --help is the contract: every option, what a commit carries, and every exit
# code. This header carries the reasoning behind the shape.
#
# COMPARE AND SWAP, NEVER FORCE. Two publish workflows write this branch and may
# finish together. Each reads the branch, builds its commit on the tip it read, and
# pushes that commit as a fast-forward, which the remote accepts only while the
# branch still points at that tip — so a push that would drop the other's record
# is refused rather than made. A refused run reads the branch again and rebuilds on
# the new tip; both records survive, and no run ever forces.
#
# A SCRATCH INDEX. The commit is built from the branch's own tree in an index of
# its own, so the checkout it runs in — its working tree, its index, its branches —
# is never read or changed, and nothing but the published branch is ever written.
#
# WHAT THE BRANCH OWNS IS CARRIED FORWARD. The ownership list keeps every path the
# branch already owned, so one workflow's run never disowns a tree another wrote,
# and a tree is owned only once it is on the branch — so a sync never takes the
# absence of a tree no publisher has written yet as a removal.

usage() {
  # The delimiter is not a word the text uses on a line of its own.
  cat <<'END_OF_HELP'
record-published.sh — record what a publish workflow published on the published
branch.

USAGE
  scripts/record-published.sh --rows FILE [--tree PATH=DIR]... [--message TEXT]
                              [--remote NAME] [--attempts N] [--dry-run]
  scripts/record-published.sh -h | --help

  --rows FILE       the versions the publish placed in the registry, one a
                    line: the reference as aggrega push names it, the version
                    and the digest aggrega push printed, tab-separated. An empty
                    file adds no version.
  --tree PATH=DIR   the branch's content under PATH becomes exactly the files
                    under DIR, at the same relative paths, removals included,
                    and PATH becomes owned. PATH is where those files sit on
                    the main branch. May be given more than once.
  --message TEXT    the commit's message
                    (default: chore(catalog): record what was published)
  --remote NAME     the remote to write (default: the remote the checked-out
                    branch tracks, else origin)
  --attempts N      how many times a run reads the branch and pushes, when the
                    branch moves between the two (default: 5)
  --dry-run         read the branch, build the commit and print what it would
                    change; push nothing

  It writes for the repository it belongs to, wherever it is run from; relative
  paths are read from where it is run. It needs a committer identity —
  git's user.name and user.email, or the GIT_COMMITTER_* and GIT_AUTHOR_*
  variables — and write access to the remote.

WHAT A RUN DOES
  1. Reads the published branch as the remote holds it now, by a fetch; a remote
     with no such branch is read as an empty one.
  2. Builds one commit whose parent is what step 1 read, in an index of its own,
     never touching this checkout's working tree, index or branches:
       .ci-published-digests  the rows the branch held and the rows given, one
                              per reference and version — a row given replaces
                              the one held for the same reference and version,
                              since it states what the registry holds now — in
                              byte order, below a note naming the file's shape;
       each --tree PATH       exactly DIR's files;
       .ci-owned-paths        every path the branch already owned, itself,
                              .ci-published-digests and each --tree PATH, in
                              byte order, below a note.
  3. When that commit changes nothing, pushes nothing and says so. Otherwise it
     pushes the commit to the remote's published branch as a fast-forward of what
     step 1 read. It never forces: when the branch moved in between — another
     publish recorded first — the remote refuses, and the run goes back to step
     1, at most --attempts times in all.

  It writes no branch but published, and to no remote but the one named.

EXIT CODES
  0  recorded, or nothing new to record; with --dry-run, the commit was built and
     shown and nothing was pushed
  1  the remote could not be read or written for a reason other than the branch
     moving, or the branch moved through every attempt
  2  a usage error or an input this refuses: a row that is not three fields, a
     PATH that is not a plain path inside the repository, a DIR holding anything
     but files and directories, or the branch's own list unreadable
END_OF_HELP
}

die_usage() { echo "record-published: $1 (see --help)" >&2; exit 2; }

ROWS_FILE=""
MESSAGE="chore(catalog): record what was published"
REMOTE_ARG=""
ATTEMPTS=5
DRY_RUN=0
TREES=()
while [ "$#" -gt 0 ]; do
  case "$1" in
    -h | --help) usage; exit 0 ;;
    --rows) [ "$#" -ge 2 ] || die_usage "--rows needs a FILE"; ROWS_FILE="$2"; shift 2 ;;
    --tree) [ "$#" -ge 2 ] || die_usage "--tree needs PATH=DIR"; TREES+=("$2"); shift 2 ;;
    --message) [ "$#" -ge 2 ] || die_usage "--message needs TEXT"; MESSAGE="$2"; shift 2 ;;
    --remote) [ "$#" -ge 2 ] || die_usage "--remote needs a NAME"; REMOTE_ARG="$2"; shift 2 ;;
    --attempts) [ "$#" -ge 2 ] || die_usage "--attempts needs N"; ATTEMPTS="$2"; shift 2 ;;
    --dry-run) DRY_RUN=1; shift ;;
    *) die_usage "unknown argument '$1'" ;;
  esac
done
[ -n "$ROWS_FILE" ] || die_usage "--rows FILE is required"
[ -f "$ROWS_FILE" ] || die_usage "--rows names no file: $ROWS_FILE"
case "$ATTEMPTS" in '' | *[!0-9]* | 0) die_usage "--attempts takes a positive number" ;; esac

set -uo pipefail
HERE="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)" || exit 2
# shellcheck source=lib/published-branch.sh
. "$HERE/lib/published-branch.sh" || exit 2

# Inputs named relative to where the run started are made absolute before it moves.
case "$ROWS_FILE" in /*) ;; *) ROWS_FILE="$PWD/$ROWS_FILE" ;; esac
TREE_PATHS=()
TREE_DIRS=()
for t in ${TREES[@]+"${TREES[@]}"}; do
  case "$t" in *=*) ;; *) die_usage "--tree '$t' is not PATH=DIR" ;; esac
  p="${t%%=*}"
  d="${t#*=}"
  case "$d" in /*) ;; *) d="$PWD/$d" ;; esac
  [ -d "$d" ] || die_usage "--tree $p: $d is not a directory"
  TREE_PATHS+=("$p")
  TREE_DIRS+=("$d")
done

# The repository written is the one this script belongs to, wherever it is run from.
TOP="$(git -C "$HERE/.." rev-parse --show-toplevel 2>/dev/null)" || { echo "record-published: $HERE/.. is not inside a git repository" >&2; exit 2; }
cd "$TOP" || exit 2
REMOTE="${REMOTE_ARG:-$(published_remote .)}"
TRACKING="refs/remotes/$REMOTE/$PUBLISHED_BRANCH"
TMP="$(mktemp -d)" || exit 2
trap 'rm -rf "$TMP"' EXIT

# Every PATH is held to the rules the ownership list is read by, through the one
# reader, so a path this writes is always one the readers accept.
if [ "${#TREE_PATHS[@]}" -gt 0 ]; then
  printf '%s\n' "${TREE_PATHS[@]}" >"$TMP/tree-paths"
  published_read_owned "$TMP/tree-paths" || die_usage "--tree names '$BAD_ENTRY', which is not a plain path inside the repository"
  TREE_PATHS=("${OWNED[@]}")
fi
for d in ${TREE_DIRS[@]+"${TREE_DIRS[@]}"}; do
  odd="$(find "$d" -mindepth 1 ! -type f ! -type d -print -quit)"
  [ -z "$odd" ] || die_usage "--tree: $odd is neither a file nor a directory"
done

# The rows given, held to their shape before anything is read from the remote.
published_rows <"$ROWS_FILE" >"$TMP/given.tsv"
awk -F'\t' '{ sub(/\r$/, "") } /^#/ || NF == 0 { next } NF != 3 { print NR": "$0; exit 1 }' "$ROWS_FILE" >"$TMP/bad-row" ||
  die_usage "--rows: line $(cat "$TMP/bad-row") is not three tab-separated fields"
awk -F'\t' '$1 ~ /[[:space:]]/ || $1 == "" || $2 == "" || $3 !~ /^[a-z0-9]+:[0-9a-f]+$/ { print; exit 1 }' "$TMP/given.tsv" >"$TMP/bad-row" ||
  die_usage "--rows: '$(cat "$TMP/bad-row")' is not a reference, a version and a digest"

DIGESTS_NOTE='# Every version the registry holds from the publish workflows: the reference,
# the version and the digest, tab-separated, one a line, in byte order. Written on
# the published branch by the publish workflows, never by hand.'
OWNED_NOTE='# The paths the publish workflows own, one a line; a directory means everything
# under it. Written on the published branch by the publish workflows, never by hand.'

gi() { GIT_INDEX_FILE="$TMP/index" git "$@"; }

# read_branch — BASE gets the commit the remote's published branch holds now, or
# nothing when the remote has no such branch. Returns 1 when the remote cannot be
# read.
read_branch() {
  local rc=0
  BASE=""
  git ls-remote --exit-code --heads "$REMOTE" "refs/heads/$PUBLISHED_BRANCH" >"$TMP/ls-remote" 2>"$TMP/ls-remote.err" || rc=$?
  case "$rc" in
    0)
      git fetch -q --no-tags "$REMOTE" "+refs/heads/$PUBLISHED_BRANCH:$TRACKING" 2>"$TMP/fetch.err" || {
        echo "record-published: cannot fetch $PUBLISHED_BRANCH from $REMOTE: $(tr '\n' ' ' <"$TMP/fetch.err")" >&2
        return 1
      }
      BASE="$(git rev-parse -q --verify "$TRACKING^{commit}")" || return 1
      ;;
    2) ;;
    *)
      echo "record-published: cannot read $REMOTE: $(tr '\n' ' ' <"$TMP/ls-remote.err")" >&2
      return 1
      ;;
  esac
}

# remote_tip — the commit the remote's published branch holds now, or nothing.
remote_tip() {
  git ls-remote --heads "$REMOTE" "refs/heads/$PUBLISHED_BRANCH" 2>/dev/null | awk '{ print $1; exit }'
}

# build — TREE gets the tree of the commit this run records on top of BASE.
# Returns 2 on input it refuses, 1 when git fails.
build() {
  local i p d f rel mode blob
  rm -f "$TMP/index"
  if [ -n "$BASE" ]; then gi read-tree "$BASE" || return 1; else gi read-tree --empty || return 1; fi

  # The record: the rows the branch holds, with the rows given replacing any for
  # the same reference and version, in byte order.
  : >"$TMP/held.tsv"
  if [ -n "$BASE" ] && git cat-file -e "$BASE:$DIGESTS_FILE" 2>/dev/null; then
    git show "$BASE:$DIGESTS_FILE" | published_rows >"$TMP/held.tsv" || return 1
  fi
  # A reference and version given twice keeps the later row, so the file never
  # carries two digests for one version from a single run.
  { printf '%s\n' "$DIGESTS_NOTE"
    awk -F'\t' '
      NR == FNR { k = $1 FS $2; if (!(k in row)) order[++n] = k; row[k] = $0; next }
      !(($1 FS $2) in row) { print }
      END { for (i = 1; i <= n; i++) print row[order[i]] }' \
      "$TMP/given.tsv" "$TMP/held.tsv" | LC_ALL=C sort -u
  } >"$TMP/digests" || return 1
  blob="$(git hash-object -w -- "$TMP/digests")" || return 1
  gi update-index --add --cacheinfo "100644,$blob,$DIGESTS_FILE" || return 1

  # Each tree: what the branch held under PATH removed, DIR's files added.
  for i in "${!TREE_PATHS[@]}"; do
    p="${TREE_PATHS[$i]}"
    d="${TREE_DIRS[$i]}"
    gi --literal-pathspecs ls-files -z -- "$p" | gi update-index -z --force-remove --stdin || return 1
    while IFS= read -r -d '' f; do
      rel="${f#./}"
      mode=100644
      [ -x "$d/$rel" ] && mode=100755
      blob="$(git hash-object -w -- "$d/$rel")" || return 1
      gi update-index --add --cacheinfo "$mode,$blob,$p/$rel" || return 1
    done < <(cd "$d" && find . -type f -print0 | LC_ALL=C sort -z)
  done

  # The ownership list: what the branch owned, the two files, and each tree.
  OWNED=()
  if [ -n "$BASE" ] && git cat-file -e "$BASE:$OWNED_PATHS_FILE" 2>/dev/null; then
    git show "$BASE:$OWNED_PATHS_FILE" >"$TMP/owned.held" || return 1
    if ! published_read_owned "$TMP/owned.held"; then
      echo "record-published: $REMOTE/$PUBLISHED_BRANCH:$OWNED_PATHS_FILE names '$BAD_ENTRY', which is not a plain path inside the repository" >&2
      return 2
    fi
  fi
  { printf '%s\n' "$OWNED_NOTE"
    printf '%s\n' ${OWNED[@]+"${OWNED[@]}"} "$OWNED_PATHS_FILE" "$DIGESTS_FILE" ${TREE_PATHS[@]+"${TREE_PATHS[@]}"} | LC_ALL=C sort -u
  } >"$TMP/owned" || return 1
  blob="$(git hash-object -w -- "$TMP/owned")" || return 1
  gi update-index --add --cacheinfo "100644,$blob,$OWNED_PATHS_FILE" || return 1

  TREE="$(gi write-tree)" || return 1
}

attempt=1
while :; do
  read_branch || exit 1
  rc=0
  build || rc=$?
  [ "$rc" -eq 0 ] || { [ "$rc" -eq 2 ] && exit 2; echo "record-published: building the commit failed" >&2; exit 1; }

  if [ -n "$BASE" ] && [ "$TREE" = "$(git rev-parse "$BASE^{tree}")" ]; then
    echo "record-published: $REMOTE/$PUBLISHED_BRANCH already holds all of it; nothing to record"
    exit 0
  fi
  if [ "$DRY_RUN" = 1 ]; then
    echo "record-published (dry run): would record on $REMOTE/$PUBLISHED_BRANCH, on top of ${BASE:-nothing (the branch would be created)}:"
    git diff --stat --no-renames "${BASE:-$(git hash-object -t tree /dev/null)}" "$TREE" | sed 's/^/  /'
    exit 0
  fi

  COMMIT="$(git commit-tree "$TREE" ${BASE:+-p "$BASE"} -m "$MESSAGE")" || {
    echo "record-published: git could not make the commit (is a committer identity set?)" >&2
    exit 1
  }
  if git push -q "$REMOTE" "$COMMIT:refs/heads/$PUBLISHED_BRANCH" 2>"$TMP/push.err"; then
    echo "record-published: recorded ${COMMIT:0:12} on $REMOTE/$PUBLISHED_BRANCH, on top of ${BASE:0:12}"
    exit 0
  fi
  # Refused. Only a branch that moved since it was read is worth another attempt;
  # anything else — a refused credential, a protected branch, an unreachable
  # remote — would be refused again.
  if [ "$(remote_tip)" = "$BASE" ]; then
    echo "record-published: the remote refused the push: $(tr '\n' ' ' <"$TMP/push.err")" >&2
    exit 1
  fi
  if [ "$attempt" -ge "$ATTEMPTS" ]; then
    echo "record-published: $REMOTE/$PUBLISHED_BRANCH moved under each of $ATTEMPTS attempts; nothing was recorded" >&2
    exit 1
  fi
  echo "record-published: $REMOTE/$PUBLISHED_BRANCH moved since it was read; reading it again (attempt $((attempt + 1)) of $ATTEMPTS)"
  sleep "$attempt"
  attempt=$((attempt + 1))
done
