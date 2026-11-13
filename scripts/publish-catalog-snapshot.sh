#!/usr/bin/env bash
# SPDX-License-Identifier: Apache-2.0
#
# publish-catalog-snapshot.sh — publish the whole catalog tree, as one publish left
# it, as one signed artifact: the catalog snapshot an `aggrega import` reads when the
# workspace it runs in names no catalog folder.
#
# The snapshot is the catalog tree at one commit — every file the repository holds
# under aggrega-catalog/ at that commit, and nothing else — written as one gzipped tar
# by the layout the CLI states for it (its writer is catalog.WriteSnapshotTar in
# aggrega-cli; the rule is restated under "THE ARCHIVE" below, and a test there
# holds the CLI's writer to this script's output for a fixture tree). It is pushed
# with curl over the OCI distribution API to <registry>/catalog/snapshot, tagged with
# the commit it was built from, signed by reference with `aggrega sign`, and only
# then tagged `latest`, so `latest` never names a snapshot that is not signed.
#
# A real run publishes a commit only where the publish marker names it, because the
# marker moves to a commit only once a publish of that commit succeeded: so every
# entity the snapshot carries is one the registry already holds. A commit the marker
# does not name is refused before anything is pushed.
#
# --dry-run builds the archive, prints the reference, the tags and the digest the
# push would land, and the sign command, and pushes, signs and checks nothing. It
# needs no credential and reaches no network, so it runs over any checkout:
#
#   scripts/publish-catalog-snapshot.sh --dry-run --registry hub.aggrega.ai \
#     --archive-out /tmp/catalog.tar.gz
#
# THE ARCHIVE. Every regular file under the catalog path at the commit is one entry,
# named by its path relative to the catalog path; a link or a submodule there is
# refused, and so is a name holding anything but printable ASCII. Entries are in
# ascending byte order of their names. Each is a ustar header — the name split into
# prefix and name at the last "/" that leaves both fields large enough where it is
# longer than 100 bytes, mode 0644, owner and group 0 with no names, the size, a
# modification time of 0, type 0, the ustar checksum — followed by the content,
# padded with zero bytes to a 512-byte block. Two zero blocks end the tar, which is
# gzipped with no name and no time. The same commit always gives the same tar bytes,
# and, with one gzip, the same archive.
#
# Run with --help for the options.

set -euo pipefail
# The credential must never reach the log, so tracing stays off even when the
# caller turned it on.
set +x
export LC_ALL=C

DIR="$(cd "$(dirname "$0")" && pwd)"
HUB_ROOT="$(cd "$DIR/.." && pwd)"

# The marker's name and the one way it is read.
# shellcheck source=lib/published-branch.sh
. "$DIR/lib/published-branch.sh" || exit 1

usage() {
  cat <<'EOF'
usage:
  publish-catalog-snapshot.sh --registry <host[/path]> [--commit <rev>] [--marker <tag>]
      [--repository <dir>] [--catalog-path <path>] [--dry-run]
      [--archive-out <file>] [--tar-out <file>]
      [--sign [--key <path>] [--identity-token <token>]]
  publish-catalog-snapshot.sh --help

Builds the catalog snapshot of the catalog tree at a commit and publishes it to
<registry>/catalog/snapshot, tagged <commit> and latest.

  --registry        the registry the catalog is published to, as its host, with
                    the repository path it publishes under, if any; a loopback
                    host is reached over plain HTTP
  --commit          the commit whose catalog tree is published (default HEAD)
  --marker          the publish marker a real run's commit must be named by
                    (default catalog-published)
  --repository      the git repository to read (default: the checkout holding
                    this script)
  --catalog-path    the catalog tree's path in that repository
                    (default aggrega-catalog)
  --dry-run         build the archive and print what would be published; push,
                    sign and check nothing, and reach no network
  --archive-out     also write the archive, the gzipped tar, to this file
  --tar-out         also write the tar stream, before compression, to this file
  --sign            sign the pushed snapshot with `aggrega sign` before tagging
                    it latest; keyless unless --key is given, with the identity
                    token from --identity-token, AGGREGA_IDENTITY_TOKEN or
                    SIGSTORE_ID_TOKEN, never interactively
  --key             sign with this private key instead
  --identity-token  the identity token for keyless signing

A real run reads the registry credential from the environment: the username from
REGISTRY_USERNAME and the password from REGISTRY_PASSWORD, or else from
AGGREGA_REGISTRY_PASSWORD. Neither is printed or placed on a command line. A
registry that needs no credential is reached with none when both are unset.
AGGREGA_BIN overrides the aggrega binary the signing runs.

Exit status: 0 when the snapshot is published (or, under --dry-run, built), 1 when
anything fails, 2 for a usage error.
EOF
}

fail() {
  echo "publish-catalog-snapshot: $*" >&2
  exit 1
}

usage_error() {
  echo "publish-catalog-snapshot: $*" >&2
  echo "publish-catalog-snapshot: run with --help for the options" >&2
  exit 2
}

REGISTRY=""
COMMIT="HEAD"
MARKER="$PUBLISH_MARKER_TAG"
REPOSITORY="$HUB_ROOT"
CATALOG_PATH="aggrega-catalog"
DRYRUN=""
ARCHIVE_OUT=""
TAR_OUT=""
SIGN=""
KEY=""
IDTOKEN=""
AGGREGA="${AGGREGA_BIN:-aggrega}"

while [ "$#" -gt 0 ]; do
  case "$1" in
    -h|--help) usage; exit 0 ;;
    --dry-run) DRYRUN=1; shift ;;
    --sign) SIGN=1; shift ;;
    --registry|--commit|--marker|--repository|--catalog-path|--archive-out|--tar-out|--key|--identity-token)
      [ "$#" -ge 2 ] || usage_error "$1 needs a value"
      case "$1" in
        --registry) REGISTRY="$2" ;;
        --commit) COMMIT="$2" ;;
        --marker) MARKER="$2" ;;
        --repository) REPOSITORY="$2" ;;
        --catalog-path) CATALOG_PATH="$2" ;;
        --archive-out) ARCHIVE_OUT="$2" ;;
        --tar-out) TAR_OUT="$2" ;;
        --key) KEY="$2" ;;
        --identity-token) IDTOKEN="$2" ;;
      esac
      shift 2
      ;;
    *) usage_error "unknown argument '$1'" ;;
  esac
done

[ -n "$REGISTRY" ] || usage_error "name the registry with --registry"
REGISTRY="${REGISTRY%/}"
CATALOG_PATH="${CATALOG_PATH%/}"
[ -n "$CATALOG_PATH" ] || usage_error "--catalog-path names no path"
if [ -n "$KEY" ] || [ -n "$IDTOKEN" ]; then
  [ -n "$SIGN" ] || usage_error "--key and --identity-token sign, so they need --sign"
fi

REVISION="$(git -C "$REPOSITORY" rev-parse --verify --quiet "${COMMIT}^{commit}")" ||
  fail "no commit '$COMMIT' in the repository at $REPOSITORY"

REGISTRY_HOST="${REGISTRY%%/*}"
REGISTRY_PATH=""
case "$REGISTRY" in */*) REGISTRY_PATH="${REGISTRY#*/}/" ;; esac
REPO_PATH="${REGISTRY_PATH}catalog/snapshot"
REFERENCE="$REGISTRY_HOST/$REPO_PATH"
case "$REGISTRY_HOST" in
  localhost|localhost:*|127.*|\[::1\]|\[::1\]:*) BASE_URL="http://$REGISTRY_HOST" ;;
  *) BASE_URL="https://$REGISTRY_HOST" ;;
esac

MEDIA_TYPE="application/vnd.aggrega.catalogsnapshot.v1beta1+tar+gz"
EMPTY_MEDIA_TYPE="application/vnd.oci.empty.v1+json"
MANIFEST_MEDIA_TYPE="application/vnd.oci.image.manifest.v1+json"

RUN_TMP="$(mktemp -d "${RUNNER_TEMP:-${TMPDIR:-/tmp}}/publish-catalog-snapshot.XXXXXX")" ||
  fail "cannot make a temporary directory"
trap 'rm -rf "$RUN_TMP"' EXIT

# --- The archive -----------------------------------------------------------------

# Z holds 512 NUL escapes for printf's format, two characters each, so zeros writes
# a run of zero bytes with no process of its own.
# shellcheck disable=SC2046 # one argument per escape is the point
Z="$(printf '\\0%.0s' $(seq 1 512))"

# zeros N — writes N zero bytes, N at most 512.
zeros() {
  [ "$1" -gt 0 ] || return 0
  # shellcheck disable=SC2059 # the format is a run of NUL escapes by construction
  printf "${Z:0:$((2 * $1))}"
}

# asum S — sets ASUM to the sum of the bytes of S.
asum() {
  local s="$1" i c
  ASUM=0
  for ((i = 0; i < ${#s}; i++)); do
    printf -v c '%d' "'${s:i:1}"
    ASUM=$((ASUM + c))
  done
}

# header NAME SIZE — writes the ustar header of a regular file NAME of SIZE bytes.
header() {
  local name="$1" size="$2" nm="$1" prefix="" length head i sizef sum chk
  if [ "${#name}" -gt 100 ]; then
    length="${#name}"
    [ "$length" -le 156 ] || length=156
    head="${name:0:length}"
    case "$head" in */*) ;; *) fail "the catalog file $name has a name a snapshot cannot carry" ;; esac
    head="${head%/*}"
    i="${#head}"
    prefix="${name:0:i}"
    nm="${name:i+1}"
    if [ "$i" -le 0 ] || [ "${#nm}" -gt 100 ] || [ "${#nm}" -eq 0 ] || [ "$i" -gt 155 ]; then
      fail "the catalog file $name has a name a snapshot cannot carry"
    fi
  fi
  printf -v sizef '%011o' "$size"
  # Every byte of the header, the checksum field read as eight spaces.
  sum=$((256 + 48))
  for field in "$nm" 0000644 0000000 0000000 "$sizef" 00000000000 ustar 00 0000000 0000000 "$prefix"; do
    asum "$field"
    sum=$((sum + ASUM))
  done
  printf -v chk '%06o' "$sum"
  printf '%s' "$nm"
  zeros $((100 - ${#nm}))
  printf '%s\0%s\0%s\0%s\0%s\0%s\0 0' 0000644 0000000 0000000 "$sizef" 00000000000 "$chk"
  zeros 100
  printf 'ustar\0'
  printf '00'
  zeros 64
  printf '%s\0%s\0' 0000000 0000000
  printf '%s' "$prefix"
  zeros $((155 - ${#prefix}))
  zeros 12
}

# The catalog tree's files at the commit, each with its blob and size, sorted by the
# name the archive gives it.
declare -A OID SIZE
NAMES=()
while IFS= read -r -d '' entry; do
  meta="${entry%%$'\t'*}"
  path="${entry#*$'\t'}"
  read -r mode type oid size <<<"$meta"
  rel="${path#"$CATALOG_PATH"/}"
  case "$mode" in
    100644|100755) ;;
    *) fail "the catalog tree holds $path, which is not a regular file (git mode $mode), and a snapshot carries regular files only" ;;
  esac
  [ "$type" = "blob" ] || fail "the catalog tree holds $path, which is not a file"
  case "$rel" in *[![:print:]]*) fail "the catalog file $path has a name holding a character other than printable ASCII" ;; esac
  OID["$rel"]="$oid"
  SIZE["$rel"]="$size"
  NAMES+=("$rel")
done < <(git -C "$REPOSITORY" ls-tree -r -l -z --full-tree "$REVISION" -- "$CATALOG_PATH/")
[ "${#NAMES[@]}" -gt 0 ] || fail "the commit $REVISION holds no catalog tree at $CATALOG_PATH"
SORTED=()
while IFS= read -r -d '' rel; do
  SORTED+=("$rel")
done < <(printf '%s\0' "${NAMES[@]}" | sort -z)

TAR="$RUN_TMP/catalog.tar"
ARCHIVE="$RUN_TMP/catalog.tar.gz"
{
  for rel in "${SORTED[@]}"; do
    size="${SIZE[$rel]}"
    header "$rel" "$size"
    git -C "$REPOSITORY" cat-file blob "${OID[$rel]}"
    pad=$(((512 - size % 512) % 512))
    zeros "$pad"
  done
  zeros 512
  zeros 512
} >"$TAR"
gzip -n -9 -c "$TAR" >"$ARCHIVE"
[ -z "$TAR_OUT" ] || cp "$TAR" "$TAR_OUT"
[ -z "$ARCHIVE_OUT" ] || cp "$ARCHIVE" "$ARCHIVE_OUT"

# --- The manifest ----------------------------------------------------------------

digest_of() {
  printf 'sha256:%s' "$(sha256sum "$1" | cut -d' ' -f1)"
}
size_of() {
  wc -c <"$1" | tr -d ' '
}

CONFIG="$RUN_TMP/config.json"
printf '{}' >"$CONFIG"
CONFIG_DIGEST="$(digest_of "$CONFIG")"
ARCHIVE_DIGEST="$(digest_of "$ARCHIVE")"
ARCHIVE_SIZE="$(size_of "$ARCHIVE")"
MANIFEST="$RUN_TMP/manifest.json"
printf '{"schemaVersion":2,"mediaType":"%s","artifactType":"%s","config":{"mediaType":"%s","digest":"%s","size":2,"data":"e30="},"layers":[{"mediaType":"%s","digest":"%s","size":%s,"annotations":{"org.opencontainers.image.title":"catalog.tar.gz"}}],"annotations":{"org.opencontainers.image.created":"1970-01-01T00:00:00Z"}}' \
  "$MANIFEST_MEDIA_TYPE" "$MEDIA_TYPE" "$EMPTY_MEDIA_TYPE" "$CONFIG_DIGEST" "$MEDIA_TYPE" "$ARCHIVE_DIGEST" "$ARCHIVE_SIZE" >"$MANIFEST"
MANIFEST_DIGEST="$(digest_of "$MANIFEST")"

SIGN_CMD=("$AGGREGA" sign)
[ -z "$KEY" ] || SIGN_CMD+=(--key "$KEY")
SIGN_REF="$REFERENCE:$REVISION"

echo "publish-catalog-snapshot: $REFERENCE:$REVISION and $REFERENCE:latest ($MANIFEST_DIGEST)"
echo "  archive $ARCHIVE_DIGEST, $ARCHIVE_SIZE bytes, ${#SORTED[@]} files of $CATALOG_PATH at $REVISION"
echo "  repository $REPO_PATH, media type $MEDIA_TYPE"

if [ -n "$DRYRUN" ]; then
  if [ -n "$SIGN" ]; then
    printf 'publish-catalog-snapshot: --dry-run: would sign with:\n '
    printf ' %q' "${SIGN_CMD[@]}"
    [ -z "$IDTOKEN" ] || printf ' %q %q' --identity-token '<redacted>'
    printf ' %q\n' "$SIGN_REF"
  fi
  echo "publish-catalog-snapshot: --dry-run: nothing was pushed, signed or tagged"
  exit 0
fi

# --- A real run ------------------------------------------------------------------

MARKED="$(published_marker_read "$REPOSITORY" "$MARKER")" ||
  fail "the publish marker '$MARKER' names no commit, so no publish is known to have published the catalog at $REVISION; nothing was pushed"
[ "$MARKED" = "$REVISION" ] ||
  fail "the publish marker '$MARKER' names $MARKED, not $REVISION: the snapshot is published only for the commit the last successful publish published, so every entity it carries is one the registry holds; nothing was pushed"

if [ -n "$SIGN" ] && [ -z "$KEY" ] && [ -z "$IDTOKEN" ] &&
  [ -z "${AGGREGA_IDENTITY_TOKEN:-}" ] && [ -z "${SIGSTORE_ID_TOKEN:-}" ]; then
  fail "--sign: no identity token; pass --identity-token or export AGGREGA_IDENTITY_TOKEN or SIGSTORE_ID_TOKEN, or sign with --key; nothing was pushed"
fi

# The Authorization header is built here and handed to curl on its standard input,
# so it never appears on a command line.
REG_USER="${REGISTRY_USERNAME:-}"
REG_PASS="${REGISTRY_PASSWORD:-${AGGREGA_REGISTRY_PASSWORD:-}}"
AUTH_HEADER="X-Publish-Catalog-Snapshot: 1"
if [ -n "$REG_USER" ] || [ -n "$REG_PASS" ]; then
  [ -n "$REG_USER" ] && [ -n "$REG_PASS" ] ||
    fail "only one of the registry username and password is set; set REGISTRY_USERNAME and REGISTRY_PASSWORD (or AGGREGA_REGISTRY_PASSWORD) together"
  basic="$(printf '%s:%s' "$REG_USER" "$REG_PASS" | base64 | tr -d '\n')"
  if [ "${GITHUB_ACTIONS:-}" = "true" ]; then
    echo "::add-mask::$basic"
  fi
  AUTH_HEADER="Authorization: Basic $basic"
fi

# request METHOD URL HEADERS-OUT [curl arguments...] — prints the HTTP status, 000
# where no answer arrived, writing the answer's headers to HEADERS-OUT.
request() {
  local method="$1" url="$2" headers="$3" status
  local -a method_args=(--request "$method")
  shift 3
  # A HEAD is asked as one, so curl does not wait for a body that never comes.
  [ "$method" != "HEAD" ] || method_args=(--head)
  if status="$(printf '%s\n' "$AUTH_HEADER" |
    curl --silent --show-error --output /dev/null --dump-header "$headers" --write-out '%{http_code}' \
      --connect-timeout 15 --max-time 600 "${method_args[@]}" --header @- "$@" "$url")"; then
    printf '%s\n' "$status"
  else
    printf '%s\n' "${status:-000}"
  fi
}

# header_value FILE NAME — prints the last value of the header NAME in FILE.
header_value() {
  awk -v want="$(printf '%s' "$2" | tr '[:upper:]' '[:lower:]')" '
    { sub(/\r$/, "") }
    { i = index($0, ":"); if (i > 0 && tolower(substr($0, 1, i - 1)) == want) { v = substr($0, i + 1); sub(/^[ \t]+/, "", v); last = v } }
    END { if (last != "") print last }' "$1"
}

HEADERS="$RUN_TMP/headers"

# push_blob FILE DIGEST MEDIA-TYPE — uploads FILE as the blob DIGEST unless the
# registry holds it already.
push_blob() {
  local file="$1" digest="$2" status location
  status="$(request HEAD "$BASE_URL/v2/$REPO_PATH/blobs/$digest" "$HEADERS")"
  [ "$status" = "200" ] && return 0
  status="$(request POST "$BASE_URL/v2/$REPO_PATH/blobs/uploads/" "$HEADERS" --header "Content-Length: 0")"
  [ "$status" = "202" ] || fail "$REGISTRY_HOST answered HTTP $status to opening an upload in $REPO_PATH; nothing was tagged"
  location="$(header_value "$HEADERS" Location)"
  [ -n "$location" ] || fail "$REGISTRY_HOST opened an upload in $REPO_PATH without saying where to send it; nothing was tagged"
  case "$location" in http://* | https://*) ;; *) location="$BASE_URL$location" ;; esac
  case "$location" in *\?*) location="$location&digest=$digest" ;; *) location="$location?digest=$digest" ;; esac
  status="$(request PUT "$location" "$HEADERS" --header "Content-Type: application/octet-stream" --data-binary "@$file")"
  [ "$status" = "201" ] || fail "$REGISTRY_HOST answered HTTP $status to the upload of $digest; nothing was tagged"
}

# put_manifest TAG — tags the manifest TAG in the repository.
put_manifest() {
  local tag="$1" status landed
  status="$(request PUT "$BASE_URL/v2/$REPO_PATH/manifests/$tag" "$HEADERS" \
    --header "Content-Type: $MANIFEST_MEDIA_TYPE" --data-binary "@$MANIFEST")"
  [ "$status" = "201" ] || fail "$REGISTRY_HOST answered HTTP $status to the manifest tagged $tag"
  landed="$(header_value "$HEADERS" Docker-Content-Digest)"
  if [ -n "$landed" ] && [ "$landed" != "$MANIFEST_DIGEST" ]; then
    fail "$REGISTRY_HOST stored the manifest tagged $tag as $landed, not $MANIFEST_DIGEST"
  fi
}

push_blob "$CONFIG" "$CONFIG_DIGEST"
push_blob "$ARCHIVE" "$ARCHIVE_DIGEST"
put_manifest "$REVISION"
echo "publish-catalog-snapshot: pushed $REFERENCE:$REVISION ($MANIFEST_DIGEST)"

if [ -n "$SIGN" ]; then
  # The signature is made by the aggrega binary, which finds the registry's
  # credential where `aggrega login` stored it, in the workspace the run names
  # (scripts/lib/scratch-workspace.sh), as the entity publisher's signatures are.
  # shellcheck source=lib/scratch-workspace.sh
  . "$DIR/lib/scratch-workspace.sh" || exit 1
  scratch_workspace_root "$RUN_TMP" "$PWD" "$REPOSITORY" ||
    fail "cannot make a scratch workspace in $RUN_TMP"
  [ -z "$IDTOKEN" ] || SIGN_CMD+=(--identity-token "$IDTOKEN")
  "${SIGN_CMD[@]}" "$SIGN_REF" ||
    fail "signing $SIGN_REF failed, so latest was left where it was"
  echo "publish-catalog-snapshot: signed $SIGN_REF"
fi

put_manifest latest
echo "publish-catalog-snapshot: tagged $REFERENCE:latest ($MANIFEST_DIGEST)"
