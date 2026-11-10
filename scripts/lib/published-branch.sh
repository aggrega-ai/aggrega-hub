# shellcheck shell=bash
# scripts/lib/published-branch.sh — the published branch's contract, read and
# written the one way every script in this repository reads and writes it.
# Sourced by scripts/record-published.sh, scripts/published-version-guard.sh and
# scripts/publish-diff.sh in this repository, and by the readers outside it that
# take the branch's contract from here rather than restating it — the release
# publisher's step that records the core plugins, and the workspace's annotation
# drift check; it defines functions and constants and runs nothing.
#
# THE BRANCH. `published` is written only by the publish workflows, each after a
# real publish succeeded, and only through scripts/record-published.sh. It holds:
#
#   .ci-published-digests   one row per version the registry holds from this
#                           workspace's publishers: the reference as `aggrega push`
#                           names it, the version, and the digest exactly as
#                           `aggrega push` computed and published it, separated by
#                           a tab, in byte order. Lines starting with # are notes.
#   .ci-owned-paths         the paths the publishers own, one repository-relative
#                           path a line, a directory meaning everything under it;
#                           blank lines and lines starting with # are ignored. It
#                           lists itself and the digests file, and every tree a
#                           publisher wrote onto the branch.
#   the owned trees         what a publisher generated and published, at the path
#                           it occupies on the main branch.
#
# The ownership list is the ONE list of what the publishers own: the sync that
# takes the branch into a checkout, the published-version guard and the commit
# refusal all read it from the branch, and nothing else names an owned path.
#
# THE MARKER. The tag the catalog publisher moves to what it published after every
# successful real publish, so it marks where the last successful publish left the
# catalog. scripts/publish-diff.sh diffs from it and moves it; the
# published-version guard holds every version directory it holds as released.
#
# THE SWITCH. .published-version-guard, committed and owned by no publisher, holds
# one word: warn or block. It selects whether the published-version guard warns
# about its findings or refuses them — an entity edited in place at a published
# version, and a change under a version directory the marker holds. A switch that
# is absent, or holds anything else, is read as block and says so, so removing it
# never quietly weakens the guard.

# Every constant, and every variable a function here sets, is read by the scripts
# that source this file, which a lint of this file alone cannot see. Placed before
# the first command, the directive covers the whole file.
# shellcheck disable=SC2034
PUBLISHED_BRANCH="published"
OWNED_PATHS_FILE=".ci-owned-paths"
DIGESTS_FILE=".ci-published-digests"
GUARD_SWITCH_FILE=".published-version-guard"
PUBLISH_MARKER_TAG="catalog-published"

# published_remote DIR — the remote DIR's checked-out branch tracks, else origin.
published_remote() {
  local branch remote=""
  branch="$(git -C "$1" symbolic-ref -q --short HEAD)" || branch=""
  if [ -n "$branch" ]; then
    remote="$(git -C "$1" for-each-ref --format='%(upstream:remotename)' "refs/heads/$branch")"
  fi
  case "$remote" in "" | .) remote=origin ;; esac
  printf '%s\n' "$remote"
}

# published_read_owned FILE — OWNED gets the paths FILE names, in its order, a
# trailing slash dropped. An entry that is not a plain path inside the repository —
# empty, absolute, a leading ":", a glob character, or a "", ".", ".." or ".git"
# segment — sets BAD_ENTRY to it and returns 1. These are the rules the workspace's
# sync applies to the same file.
published_read_owned() {
  local raw p seg
  local -a segs=()
  OWNED=()
  BAD_ENTRY=""
  while IFS= read -r raw || [ -n "$raw" ]; do
    p="${raw%$'\r'}"
    p="${p#"${p%%[![:space:]]*}"}"
    p="${p%"${p##*[![:space:]]}"}"
    case "$p" in '' | '#'*) continue ;; esac
    p="${p%/}"
    case "$p" in
      '' | /* | :* | *'*'* | *'?'* | *'['* | *\\*) BAD_ENTRY="$raw"; return 1 ;;
    esac
    IFS=/ read -r -a segs <<<"$p"
    for seg in "${segs[@]}"; do
      case "$seg" in '' | . | .. | .git) BAD_ENTRY="$raw"; return 1 ;; esac
    done
    OWNED+=("$p")
  done <"$1"
}

# published_switch DIR — sets SWITCH to warn or block: the word DIR's committed
# HEAD holds in the switch file. Read from HEAD rather than from what is staged, so
# a commit is judged under the switch as it stood before that commit and cannot
# loosen the guard for itself. SWITCH_NOTE says why when SWITCH is block for want
# of a readable word, and is empty otherwise.
published_switch() {
  local raw word=""
  SWITCH="block"
  SWITCH_NOTE=""
  if ! raw="$(git -C "$1" show "HEAD:$GUARD_SWITCH_FILE" 2>/dev/null)"; then
    SWITCH_NOTE="$GUARD_SWITCH_FILE is not committed, so the guard blocks"
    return 0
  fi
  word="$(printf '%s\n' "$raw" | awk '{ sub(/\r$/, "") } /^[[:space:]]*(#|$)/ { next } { gsub(/^[[:space:]]+|[[:space:]]+$/, ""); print; exit }')"
  case "$word" in
    warn | block) SWITCH="$word" ;;
    *) SWITCH_NOTE="$GUARD_SWITCH_FILE holds '${word}', which is neither warn nor block, so the guard blocks" ;;
  esac
}

# --- The marker seam ------------------------------------------------------------
# The ONLY two places the marker mechanism is touched, for every script that reads
# or moves it — scripts/publish-diff.sh and the published-version guard. The
# mechanism is a git tag on the repository: read = the commit the tag points at;
# advance = move the tag to HEAD. To back the marker with a remote object instead,
# replace the bodies of these two functions and nothing else. TAG defaults to
# PUBLISH_MARKER_TAG only when it is not given at all, so a caller passing its own
# value — an empty one included — reads and moves exactly that.

# published_marker_read DIR [TAG] — prints the commit the marker names in the
# repository at DIR and returns 0, or prints nothing and returns 1 when there is
# no such marker.
published_marker_read() {
  git -C "$1" rev-parse --verify --quiet "refs/tags/${2-$PUBLISH_MARKER_TAG}^{commit}" 2>/dev/null
}

# published_marker_advance DIR [TAG] — moves the marker in the repository at DIR
# to its current HEAD commit.
published_marker_advance() {
  git -C "$1" tag -f "${2-$PUBLISH_MARKER_TAG}" HEAD >/dev/null
}

# published_rows < RECORD — the record's rows, the note lines and blank lines
# dropped, a carriage return removed: reference, version and digest, tab-separated.
published_rows() {
  awk -F'\t' '{ sub(/\r$/, "") } /^#/ || NF == 0 { next } NF == 3 { print }'
}

# published_rows_from_push < OUTPUT — the rows a publish adds to the record, read
# from what `aggrega push` printed: for each reference it pushed or found already
# published, the reference, the version and the digest, tab-separated. Those are the
# lines `Push complete: <reference>:<version> (<digest>)` and `Already published:
# <reference>:<version> (<digest>)`; every other line is ignored. Both publish
# workflows read their rows through this one reader — the catalog publisher's, and
# the release publisher's for the core plugins.
published_rows_from_push() {
  awk '
    { sub(/\r$/, "") }
    /^Push complete: / || /^Already published: / {
      reftag = $3; digest = $4; gsub(/^\(|\)$/, "", digest)
      i = match(reftag, /:[^:]*$/)
      if (i > 0 && digest != "") print substr(reftag, 1, i - 1) "\t" substr(reftag, i + 1) "\t" digest
    }'
}
