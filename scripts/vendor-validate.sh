#!/usr/bin/env bash
# shellcheck source-path=SCRIPTDIR disable=SC1091
# scripts/vendor-validate.sh — hold the catalog's cloud Recipes to what the
# vendors' own validators accept, offline, and every commit to the two rules that
# need no validator.
#
# --help is the contract: the forms, what each judges, the cache, and every exit
# code. This header carries the reasoning behind the shape.
#
# THE INDEX, NOT THE WORKING TREE. Every file a rule reads is read from the index
# with git, as the published-version guard reads it, so what is judged is what the
# commit carries: an unstaged fix cannot pass a broken staged file.
#
# THE MARKER IS WRITTEN WHOLE NOWHERE HERE. The vendor-text marker is composed from
# its two parts when the script runs, so no file in this repository carries it and
# the rule needs no exemption for this script.
#
# TWO RULES BEFORE ANY VALIDATOR. The vendor-text rule and the pass-through rule
# read blobs with git and match text with grep and awk, and they run before any
# validator is looked for, so they hold on a machine where nothing is primed. A
# container Recipe is recognised by its text rather than by a YAML parser for the
# same reason: the rule depends on no tool the machine may lack.
#
# ONE PIN FILE, ONE CACHE PER PIN FILE. Every version and checksum lives in
# scripts/vendor-validators.json. The cache directory is named by the SHA-256 of
# that file, so a changed pin file finds no cache until it is primed, and a cache
# never answers for a pin file it was not primed from. Nothing outside the cache
# runs as a validator: a tofu or cfn-lint on PATH may be any version.
#
# A BUILD BETWEEN RELEASES COUNTS AS ITS RELEASE. aggrega version reports such a
# build as git describe writes it, 0.10.0-41-g697285c71-dirty. Read as a semantic
# version that is a pre-release, ranked below 0.10.0, though it carries everything
# 0.10.0 does; so only its leading X.Y.Z is compared with aggrega_min_version.
#
# THE SELF-TEST JUDGES COPIES. Each case copies this script's directory into a
# scratch repository of its own, stages one fault there and runs the copy, so a
# case proves the script end to end — its arguments, its reading of the index and
# its exit status — and never touches this repository or the cache it uses.
#
# MOVING A PIN. Pin a release once it is at least three days old. Each value is
# what its publisher states:
#   opentofu.sha256       the line for tofu_<version>_linux_<arch>.tar.gz in the
#                         release's tofu_<version>_SHA256SUMS
#   python_requirements   one entry per line that
#                           uv pip compile --generate-hashes --no-header
#                             --no-annotate --exclude-newer <date>
#                             --python-version <x.y> requirements.in
#                         writes, requirements.in pinning cfn-lint, jsonschema
#                         and referencing with ==
#   arm_schemas           a commit of Azure/azure-resource-manager-schemas and
#                         the SHA-256 of codeload.github.com's tar.gz of it
#   providers             one entry per version that a version constraint in the
#                         catalog, or in a module a Recipe sources, selects; zh is
#                         the shasum registry.opentofu.org answers at
#                         /v1/providers/<source>/<version>/download/linux/<arch>

usage() {
  # The delimiter is not a word the text uses on a line of its own. The text is
  # held quoted, so nothing in it expands, and @MARKER@ is then replaced by the
  # composed marker.
  local text
  text="$(cat <<'END_OF_HELP'
vendor-validate.sh — hold the catalog's cloud Recipes to what the vendors' own
validators accept, offline, and every commit to the two rules that need no
validator.

USAGE
  scripts/vendor-validate.sh --staged
  scripts/vendor-validate.sh --all
  scripts/vendor-validate.sh --prime
  scripts/vendor-validate.sh --self-test
  scripts/vendor-validate.sh -h | --help

  --staged     judge the commit being made, as the index holds it, by VENDOR
               TEXT and THE CANONICAL PASS-THROUGH: the form for a pre-commit
               hook.
  --all        judge everything the index holds by VENDOR TEXT and THE
               CANONICAL PASS-THROUGH, then require THE VALIDATORS.
  --prime      fetch every validator the pin file names into the cache, verify
               each checksum, and run --self-test against the result. The one
               form that uses the network.
  --self-test  prove, in scratch repositories under a temporary directory,
               that each rule refuses the fault it exists for and passes a
               clean commit, that a missing or mismatched validator or binary
               gives no verdict, and that each cached validator answers its
               pinned version. Needs the primed cache.

  It judges the repository it belongs to, wherever it is run from. AGGREGA_BIN
  names the aggrega binary (default: aggrega on PATH). PUBLISHED_REMOTE names
  the remote whose published branch is read (default: the remote the
  checked-out branch tracks, else origin).

VENDOR TEXT (--staged, --all; runs first)
  aggrega import, drafting an entity from a vendor's resource schema, opens
  every passage it takes from that schema with the marker
      @MARKER@
  Vendor text is not committed to this catalog. A file whose staged content
  carries the marker is refused, naming the file and the line. The whole
  staged file is read, not only the lines the commit changes, so a file
  carrying the marker cannot be added, changed, copied or renamed without
  removing it. --staged reads every path the commit adds, changes, copies or
  renames; --all reads every path the index holds. The rule runs before any
  validator is looked for, so it holds on a machine where nothing is primed.

THE CANONICAL PASS-THROUGH (--staged, --all)
  scripts/container-pass-through/main.tf is the one text of the module/main.tf
  a terraform container Recipe carries: its config input passes into the
  module the Recipe imports under the artifacts key service, and that module
  comes back out as its service output.

  A version directory under aggrega-catalog/recipe/terraform/ is a container
  Recipe when its module/main.tf references "./service", or when its
  recipe.yaml has an $import under the artifacts key service. Both are read as
  text, with no YAML parser and no validator. Its module/main.tf must equal the
  canonical file byte for byte — line ends and final newline included — or the
  commit is refused, naming both paths.

  --staged judges each container Recipe version directory the commit changes,
  and every container Recipe version when the commit changes the canonical
  file itself; --all judges every one. A version the record holds as published
  (.ci-published-digests on <remote>/published, as last fetched) is final and
  keeps the file it was published with, so it is not judged.

THE VALIDATORS
  scripts/vendor-validators.json pins each validator: OpenTofu by version and
  the SHA-256 of its release archive per architecture; cfn-lint, jsonschema
  and referencing with every dependency, hash-locked; the Azure Resource
  Manager schemas by commit and archive SHA-256; and every Terraform provider
  version a constraint in the catalog, or in a module a Recipe sources,
  selects, each by the checksum registry.opentofu.org gives for its archive
  (zh) per architecture. aggrega_min_version is the oldest aggrega release
  this script accepts; format is the file's format, 1.

  --prime fetches them for this machine (linux, amd64 or arm64) into
      ~/.cache/aggrega/vendor-validators/<sha256 of the pin file>/
  verifies each checksum, installs the Python packages into a virtual
  environment there with --require-hashes --only-binary=:all:, unpacks the
  providers into a filesystem mirror and the schemas beside it, runs
  --self-test, and marks the cache primed last. A checksum that does not
  match, a failed download or a failed self-test exits 3 naming what failed,
  and leaves nothing primed. On a cache already primed for this pin file it
  runs --self-test against it and fetches nothing, unless that fails. It
  needs curl, sha256sum, tar, unzip and python3 with its venv module. Each pin
  file's cache is a directory of its own; one no pin file names any more can
  be removed by hand.

  A form that requires the validators requires, before it runs any: the cache
  primed for this pin file; the cached tofu and cfn-lint answering their
  pinned versions; and an aggrega binary at aggrega_min_version or later, its
  version read from aggrega version -o json. Only the binary's leading X.Y.Z
  counts: a build between releases, 0.10.0-41-g697285c71-dirty, counts as
  0.10.0. Each missing requirement gives no verdict, naming the one command
  that supplies it. Every validator runs from the cache by its full path: the
  tofu or cfn-lint on PATH is never used.

EXIT CODES
  0  passed: nothing refused
  1  refused: every finding is named; for --self-test, a case that did not
     give its expected verdict, named
  2  a usage error
  3  no verdict: a requirement is missing, each named with the one command
     that supplies it; a git command failed; or --prime failed and left
     nothing primed
END_OF_HELP
)"
  printf '%s\n' "${text//@MARKER@/$VENDOR_MARKER}"
}

# The marker aggrega import opens every passage a draft takes from a vendor
# schema with, composed from its two parts so that no file here carries it whole.
VENDOR_MARKER_HEAD="[vendor schema"
VENDOR_MARKER_TAIL="text]"
VENDOR_MARKER="$VENDOR_MARKER_HEAD $VENDOR_MARKER_TAIL"

ME="vendor-validate"
FORMS="--staged, --all, --prime or --self-test"
MODE=""
while [ "$#" -gt 0 ]; do
  case "$1" in
    -h | --help) usage; exit 0 ;;
    --staged | --all | --prime | --self-test)
      [ -z "$MODE" ] || { echo "$ME: name one of $FORMS (see --help)" >&2; exit 2; }
      MODE="${1#--}"; shift ;;
    *) echo "$ME: unknown argument '$1' (see --help)" >&2; exit 2 ;;
  esac
done
[ -n "$MODE" ] || { echo "$ME: name one of $FORMS (see --help)" >&2; exit 2; }

set -uo pipefail
HERE="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)" || exit 3
# shellcheck source=lib/catalog-entities.sh
. "$HERE/lib/catalog-entities.sh" || exit 3
# shellcheck source=lib/published-branch.sh
. "$HERE/lib/published-branch.sh" || exit 3

# A binary named by a relative path is made absolute before the script moves.
AGGREGA="${AGGREGA_BIN:-aggrega}"
case "$AGGREGA" in
  /*) ;;
  */*) AGGREGA="$PWD/$AGGREGA" ;;
esac
# The repository judged is the one this script belongs to, wherever it is run from.
TOP="$(git -C "$HERE/.." rev-parse --show-toplevel 2>/dev/null)" || { echo "$ME: $HERE/.. is not inside a git repository" >&2; exit 3; }
cd "$TOP" || exit 3
export GIT_OPTIONAL_LOCKS=0

PIN_FILE="$HERE/vendor-validators.json"
CANONICAL="scripts/container-pass-through/main.tf"
TF_RECIPES="$CATALOG_ROOT/recipe/terraform"
PRIME_CMD="$HERE/vendor-validate.sh --prime"
TMP="$(mktemp -d)" || exit 3
trap 'rm -rf "$TMP"' EXIT

REFUSED=0
refuse() { REFUSED=1; printf '✗ %s\n' "$1"; }
# no_verdict CAUSE... — nothing can be judged: each cause is named, exit 3.
no_verdict() {
  local cause
  for cause in "$@"; do printf '✗ %s: no verdict — %s\n' "$ME" "$cause" >&2; done
  exit 3
}

if git rev-parse -q --verify 'HEAD^{commit}' >/dev/null; then
  BASE=HEAD
else
  BASE="$(git hash-object -t tree /dev/null)" || no_verdict "git cannot name the empty tree"
fi

# --- vendor text -------------------------------------------------------------------
# vendor_text_rule — refuses every file the commit adds, changes, copies or renames
# (--staged), or every file the index holds (--all), whose staged content carries
# the marker, naming the file and each line.
vendor_text_rule() {
  local path line rc=0
  local -A judged=() seen=()
  if [ "$MODE" = staged ]; then
    git diff --cached --name-only -z --no-renames --diff-filter=ACMRT "$BASE" >"$TMP/vendor-text-paths" ||
      no_verdict "git cannot list what the commit stages"
    while IFS= read -r -d '' path; do judged[$path]=1; done <"$TMP/vendor-text-paths"
    [ "${#judged[@]}" -gt 0 ] || return 0
  fi
  # The whole index is searched at once; with -o each hit is the path, the line
  # number and the marker itself, so no file's own text can break the reading.
  git grep --cached --no-recurse-submodules --no-color --no-column -a -z -n -o -F \
    -e "$VENDOR_MARKER" >"$TMP/vendor-text-hits" || rc=$?
  [ "$rc" -le 1 ] || no_verdict "git cannot search the index"
  while IFS= read -r -d '' path && IFS= read -r -d '' line && IFS= read -r _; do
    if [ "$MODE" = staged ] && [ -z "${judged[$path]+set}" ]; then continue; fi
    [ -z "${seen[$path:$line]+set}" ] || continue
    seen[$path:$line]=1
    refuse "$path:$line: carries the marker $VENDOR_MARKER, which opens a passage aggrega import took from a vendor schema. Vendor text is not committed to this catalog: write the passage in your own words, remove the marker, and stage the file again."
  done <"$TMP/vendor-text-hits"
}

# --- the canonical pass-through ----------------------------------------------------
# Whether the recipe.yaml awk reads has an $import under the artifacts key
# service: a line `service:` among the children of a line `artifacts:`, with an
# `$import:` nested below it or written inline.
# shellcheck disable=SC2016 # awk's own $ and the YAML's, not the shell's
SERVICE_IMPORT_AWK='
  function indent(s) { match(s, /^ */); return RLENGTH }
  { sub(/\r$/, "") }
  /^[[:space:]]*(#|$)/ { next }
  {
    ind = indent($0)
    if (in_service && ind <= service_ind) in_service = 0
    if (in_artifacts && ind <= artifacts_ind) in_artifacts = 0
    if (in_service) {
      if ($0 ~ /^[[:space:]]*\$import[[:space:]]*:/) { found = 1; exit }
      next
    }
    if (in_artifacts) {
      if (child_ind < 0) child_ind = ind
      if (ind == child_ind && $0 ~ /^[[:space:]]*service[[:space:]]*:/) {
        if ($0 ~ /:[[:space:]]*\{[[:space:]]*\$import[[:space:]]*:/) { found = 1; exit }
        in_service = 1
        service_ind = ind
      }
      next
    }
    if ($0 ~ /^[[:space:]]*artifacts[[:space:]]*:[[:space:]]*(#.*)?$/) {
      in_artifacts = 1
      artifacts_ind = ind
      child_ind = -1
    } else if ($0 ~ /^[[:space:]]*artifacts[[:space:]]*:[[:space:]]*\{.*service[[:space:]]*:[[:space:]]*\{[[:space:]]*\$import[[:space:]]*:/) {
      found = 1
      exit
    }
  }
  END { exit !found }'

# staged_blob PATH FILE — writes PATH as the index holds it to FILE; fails when
# the index holds no PATH.
staged_blob() {
  git cat-file -e ":$1" 2>/dev/null && git cat-file blob ":$1" >"$2"
}

# is_container VDIR — whether the terraform Recipe version VDIR, as the index
# holds it, is a container Recipe. Each blob is read into a file first, so a
# match found early never cuts the reading short.
is_container() {
  if staged_blob "$1/module/main.tf" "$TMP/main.tf" && grep -Eq '"\./service/?"' "$TMP/main.tf"; then
    return 0
  fi
  staged_blob "$1/recipe.yaml" "$TMP/recipe.yaml" && awk "$SERVICE_IMPORT_AWK" "$TMP/recipe.yaml"
}

# recorded_published PATH VERSION — whether the record holds the reference ending
# in /PATH at VERSION. The record is read once, from <remote>/published as last
# fetched; with none fetched, nothing is recorded.
PUB_ROWS_READ=0
PUB_ROWS=""
recorded_published() {
  if [ "$PUB_ROWS_READ" = 0 ]; then
    PUB_ROWS_READ=1
    local remote pub
    remote="${PUBLISHED_REMOTE:-$(published_remote .)}"
    pub="refs/remotes/$remote/$PUBLISHED_BRANCH"
    if git cat-file -e "$pub:$DIGESTS_FILE" 2>/dev/null; then
      PUB_ROWS="$(git show "$pub:$DIGESTS_FILE" | published_rows)" ||
        no_verdict "git cannot read $remote/$PUBLISHED_BRANCH:$DIGESTS_FILE"
    fi
  fi
  printf '%s\n' "$PUB_ROWS" | awk -F'\t' -v p="/$1" -v v="$2" '
    $2 == v && ($1 == substr(p, 2) || (length($1) > length(p) && substr($1, length($1) - length(p) + 1) == p)) { found = 1 }
    END { exit !found }'
}

# pass_through_rule — refuses every container Recipe version it judges whose
# staged module/main.tf is not the staged canonical file byte for byte.
pass_through_rule() {
  local canonical_id copy copy_id vdir path entity all=0 rc=0
  local -a vdirs=()
  local -A seen=()
  if ! canonical_id="$(git rev-parse -q --verify ":$CANONICAL")"; then
    refuse "$CANONICAL: not in the index. It is the canonical pass-through every terraform container Recipe's module/main.tf equals, and this rule reads it from the index: stage it (git add -- $CANONICAL), restoring it from git first if it was removed."
    return
  fi
  git cat-file blob "$canonical_id" >"$TMP/canonical" || no_verdict "git cannot read the staged $CANONICAL"
  if [ "$MODE" = all ]; then
    all=1
  else
    git diff --cached --quiet "$BASE" -- "$CANONICAL" || rc=$?
    case "$rc" in
      0) ;;
      1) all=1 ;;
      *) no_verdict "git cannot compare the staged $CANONICAL with $BASE" ;;
    esac
  fi
  if [ "$all" = 1 ]; then
    git ls-files -z -- "$TF_RECIPES/" >"$TMP/pass-through-paths" || no_verdict "git cannot list $TF_RECIPES/"
  else
    git diff --cached --name-only -z --no-renames "$BASE" -- "$TF_RECIPES/" >"$TMP/pass-through-paths" ||
      no_verdict "git cannot list what the commit stages under $TF_RECIPES/"
  fi
  while IFS= read -r -d '' path; do
    vdir="$(version_dir "$path")" || continue
    [ -z "${seen[$vdir]+set}" ] || continue
    seen[$vdir]=1
    vdirs+=("$vdir")
  done <"$TMP/pass-through-paths"
  for vdir in ${vdirs[@]+"${vdirs[@]}"}; do
    # A version directory the commit removes whole has nothing left to judge.
    [ -n "$(git --literal-pathspecs ls-files -- "$vdir/")" ] || continue
    is_container "$vdir" || continue
    entity="${vdir#"$CATALOG_ROOT"/}"
    recorded_published "${entity%/*}" "${vdir##*/}" && continue
    copy="$vdir/module/main.tf"
    if ! copy_id="$(git rev-parse -q --verify ":$copy")"; then
      refuse "$vdir: a terraform container Recipe with no module/main.tf. It carries $CANONICAL there byte for byte: copy $CANONICAL to $copy and stage it."
      continue
    fi
    [ "$copy_id" != "$canonical_id" ] || continue
    refuse "$copy $(pass_through_drift "$copy_id"). A terraform container Recipe's module/main.tf is $CANONICAL byte for byte, line ends and final newline included: copy $CANONICAL over it and stage it again."
  done
}

# pass_through_drift BLOB — how BLOB differs from the canonical file, as a phrase.
pass_through_drift() {
  if ! git cat-file blob "$1" >"$TMP/copy" 2>/dev/null; then
    printf 'differs from %s' "$CANONICAL"
  elif tr -d '\r' <"$TMP/copy" | cmp -s - "$TMP/canonical"; then
    printf 'differs from %s only in its line ends (it carries carriage returns)' "$CANONICAL"
  elif [ "$(cat "$TMP/copy")" = "$(cat "$TMP/canonical")" ]; then
    printf 'differs from %s only in the newlines at its end' "$CANONICAL"
  else
    printf 'differs from %s' "$CANONICAL"
  fi
}

# --- the pin file and the cache --------------------------------------------------
# settle_cache — names the pin file's digest and the cache directory primed from it.
settle_cache() {
  [ -n "${HOME:-}" ] || no_verdict "HOME is not set, so the cache ~/.cache/aggrega/vendor-validators has no place"
  [ -f "$PIN_FILE" ] || no_verdict "the pin file $PIN_FILE is missing; restore it from git"
  PIN_DIGEST="$(sha256sum <"$PIN_FILE" | awk '{ print $1 }')" || no_verdict "sha256sum cannot read $PIN_FILE"
  CACHE_ROOT="$HOME/.cache/aggrega/vendor-validators"
  CACHE_DIR="$CACHE_ROOT/$PIN_DIGEST"
}

# The pin file's reader: it checks the file's shape and prints one row per pinned
# item, tab-separated. ARCH (amd64, arm64 or empty) picks the checksums printed;
# REQUIREMENTS, when given, receives the hash-locked requirement lines.
PY_PINS='
import json, re, sys
path, arch, requirements = sys.argv[1], sys.argv[2], sys.argv[3]
def fail(why):
    sys.exit(f"the pin file {path} cannot be used: {why}")
try:
    with open(path, encoding="utf-8") as f:
        pins = json.load(f)
except (OSError, ValueError) as e:
    fail(f"it is not readable as JSON ({e})")
if not isinstance(pins, dict) or pins.get("format") != 1:
    fail("its format is not 1, the format this script reads")
ARCHES = ("amd64", "arm64")
def get(obj, *keys):
    for key in keys:
        obj = obj.get(key) if isinstance(obj, dict) else None
    return obj
def version(label, value):
    if not isinstance(value, str) or not re.fullmatch(r"[0-9]+\.[0-9]+\.[0-9]+", value):
        fail(f"{label} is not a version X.Y.Z")
    return value
def hexdigits(label, value, n):
    if not isinstance(value, str) or not re.fullmatch(f"[0-9a-f]{{{n}}}", value):
        fail(f"{label} is not {n} lowercase hexadecimal digits")
    return value
def pick(values):
    return values[ARCHES.index(arch)] if arch else "-"
rows = [("aggrega_min_version", version("aggrega_min_version", pins.get("aggrega_min_version")))]
tofu = [hexdigits(f"opentofu.sha256.{a}", get(pins, "opentofu", "sha256", a), 64) for a in ARCHES]
rows.append(("opentofu", version("opentofu.version", get(pins, "opentofu", "version")), pick(tofu)))
lines = pins.get("python_requirements")
if not isinstance(lines, list) or not lines or not all(isinstance(l, str) and not set(l) & set("\r\n\t") for l in lines):
    fail("python_requirements is not a list of requirement lines")
pinned = {}
for line in lines:
    m = re.match(r"([A-Za-z0-9][A-Za-z0-9._-]*)==([^\s\\;]+)", line)
    if m:
        pinned[m.group(1).lower()] = m.group(2)
for name in ("cfn-lint", "jsonschema", "referencing"):
    if name not in pinned:
        fail(f"python_requirements pins no {name}")
    rows.append(("python", name, pinned[name]))
rows.append(("arm_schemas",
             hexdigits("arm_schemas.commit", get(pins, "arm_schemas", "commit"), 40),
             hexdigits("arm_schemas.archive_sha256", get(pins, "arm_schemas", "archive_sha256"), 64)))
providers = pins.get("providers")
if not isinstance(providers, list) or not providers:
    fail("providers is not a list of providers")
for i, p in enumerate(providers):
    source = get(p, "source")
    if not isinstance(source, str) or not re.fullmatch(r"[A-Za-z0-9][A-Za-z0-9-]*/[A-Za-z0-9][A-Za-z0-9-]*", source):
        fail(f"providers[{i}].source is not <namespace>/<type>")
    zh = [hexdigits(f"providers[{i}].zh.linux_{a}", get(p, "zh", f"linux_{a}"), 64) for a in ARCHES]
    rows.append(("provider", source, version(f"providers[{i}].version", get(p, "version")), pick(zh)))
if requirements:
    with open(requirements, "w", encoding="utf-8") as f:
        f.write("\n".join(lines) + "\n")
for row in rows:
    print("\t".join(row))
'

# load_pins [ARCH [REQUIREMENTS]] — reads the pin file into PIN_*.
load_pins() {
  local out kind a b c
  command -v python3 >/dev/null 2>&1 ||
    no_verdict "python3 is not on PATH, and the pin file and the validators' answers are read with it; install Python 3"
  out="$(python3 -I -c "$PY_PINS" "$PIN_FILE" "${1:-}" "${2:-}" 2>&1)" || no_verdict "$out"
  PIN_PROVIDERS=()
  declare -gA PIN_PYTHON=()
  while IFS=$'\t' read -r kind a b c; do
    case "$kind" in
      aggrega_min_version) PIN_AGGREGA_MIN="$a" ;;
      opentofu) PIN_TOFU_VERSION="$a"; PIN_TOFU_SHA256="$b" ;;
      python) PIN_PYTHON[$a]="$b" ;;
      arm_schemas) PIN_ARM_COMMIT="$a"; PIN_ARM_SHA256="$b" ;;
      provider) PIN_PROVIDERS+=("$a $b $c") ;;
    esac
  done <<<"$out"
}

# tofu_version TOFU — the version TOFU answers, or nothing.
tofu_version() {
  [ -x "$1" ] || return 0
  "$1" version -json 2>/dev/null |
    python3 -I -c 'import json, sys; print(json.load(sys.stdin).get("terraform_version", ""))' 2>/dev/null
}

# cfn_lint_version CFN_LINT — the version CFN_LINT answers, or nothing.
cfn_lint_version() {
  [ -x "$1" ] || return 0
  "$1" --version 2>/dev/null | awk 'NR == 1 && $1 == "cfn-lint" { print $2 }'
}

# python_package_version PYTHON PACKAGE — the version of PACKAGE installed for PYTHON, or nothing.
# shellcheck disable=SC2329 # called from the cases, which run by name from ST_CASES
python_package_version() {
  [ -x "$1" ] || return 0
  "$1" -I -c 'import importlib.metadata as m, sys; print(m.version(sys.argv[1]))' "$2" 2>/dev/null
}

# --- the validators --------------------------------------------------------------
# Set while --prime runs --self-test over the cache it has just filled, which is
# not yet marked primed.
PRIMING=0

# cache_causes — adds to CAUSES what the cache lacks: a mark that it is primed for
# this pin file, and a tofu and a cfn-lint answering their pinned versions.
cache_causes() {
  local mark got
  local -a others=()
  if [ "$PRIMING" = 0 ] && [ ! -f "$CACHE_DIR/primed" ]; then
    for mark in "$CACHE_ROOT"/*/primed; do
      [ -f "$mark" ] || continue
      mark="${mark%/primed}"
      mark="${mark##*/}"
      [ "$mark" = "$PIN_DIGEST" ] || others+=("${mark:0:12}")
    done
    if [ "${#others[@]}" -gt 0 ]; then
      CAUSES+=("the validators in $CACHE_ROOT are primed for another pin file (${others[*]}), not for this one (${PIN_DIGEST:0:12}). Prime them for this one (network, once): $PRIME_CMD")
    else
      CAUSES+=("the validators are not primed for this pin file (${PIN_DIGEST:0:12}; cache $CACHE_DIR). Prime them (network, once): $PRIME_CMD")
    fi
    return
  fi
  got="$(tofu_version "$CACHE_DIR/opentofu/tofu")"
  [ "$got" = "$PIN_TOFU_VERSION" ] ||
    CAUSES+=("the cached tofu ($CACHE_DIR/opentofu/tofu) answers ${got:-no version}, not the pinned $PIN_TOFU_VERSION. Prime again: $PRIME_CMD")
  got="$(cfn_lint_version "$CACHE_DIR/venv/bin/cfn-lint")"
  [ "$got" = "${PIN_PYTHON[cfn-lint]}" ] ||
    CAUSES+=("the cached cfn-lint ($CACHE_DIR/venv/bin/cfn-lint) answers ${got:-no version}, not the pinned ${PIN_PYTHON[cfn-lint]}. Prime again: $PRIME_CMD")
}

# Reads aggrega version -o json on standard input and prints ok, low or
# unreadable, a tab, and the version as written. Only the leading X.Y.Z is
# compared with the minimum (argument 1).
PY_VERSION_CORE='
import json, re, sys
try:
    version = json.load(sys.stdin)["version"]
except Exception:
    version = None
m = re.match(r"v?([0-9]+)\.([0-9]+)\.([0-9]+)", version) if isinstance(version, str) else None
if not m:
    print(f"unreadable\t{version}")
else:
    core = tuple(int(x) for x in m.groups())
    minimum = tuple(int(x) for x in sys.argv[1].split("."))
    print(("ok" if core >= minimum else "low") + "\t" + version)
'

# binary_causes — adds to CAUSES what the aggrega binary lacks.
binary_causes() {
  local out supply="Install aggrega $PIN_AGGREGA_MIN or later and put it on PATH, or point AGGREGA_BIN at one."
  if ! command -v "$AGGREGA" >/dev/null 2>&1; then
    CAUSES+=("no aggrega binary: '$AGGREGA' is not found, and this script requires aggrega $PIN_AGGREGA_MIN or later. $supply")
    return
  fi
  out="$("$AGGREGA" version -o json 2>/dev/null | python3 -I -c "$PY_VERSION_CORE" "$PIN_AGGREGA_MIN")" || out="unreadable"
  case "${out%%$'\t'*}" in
    ok) ;;
    low) CAUSES+=("'$AGGREGA' is aggrega ${out#*$'\t'}, below $PIN_AGGREGA_MIN, the oldest release this script accepts. $supply") ;;
    *) CAUSES+=("'$AGGREGA version -o json' gives no version this script can read. $supply") ;;
  esac
}

# require_validators — exit 3, naming each cause, unless the cache is primed for
# this pin file at the pinned versions and the aggrega binary is recent enough.
require_validators() {
  CAUSES=()
  settle_cache
  load_pins
  cache_causes
  binary_causes
  [ "${#CAUSES[@]}" -eq 0 ] || no_verdict "${CAUSES[@]}"
}

# --- the prime -------------------------------------------------------------------
# prime_fail WHAT — --prime failed: the cache directory is removed, so nothing is
# primed, and the run exits 3.
prime_fail() {
  rm -rf -- "$CACHE_DIR"
  no_verdict "--prime failed, and nothing is primed: $1"
}

# fetch_verified ITEM URL SHA256 FILE — downloads URL to FILE and holds it to
# SHA256.
fetch_verified() {
  local got
  curl --proto '=https' --proto-redir '=https' --tlsv1.2 -fsSL --retry 3 -o "$4" "$2" ||
    prime_fail "$1: the download from $2 failed"
  got="$(sha256sum <"$4" | awk '{ print $1 }')"
  [ "$got" = "$3" ] || prime_fail "$1: the download from $2 has SHA-256 $got, not the pinned $3"
}

# prime — fills the cache for this pin file and this machine, verified, then runs
# --self-test over it and marks it primed last.
prime() {
  local arch tool downloads entry source version zh url dir n=0 started
  started="$(date +%s)"
  for tool in curl sha256sum tar unzip python3; do
    command -v "$tool" >/dev/null 2>&1 || no_verdict "--prime needs $tool, which is not on PATH; install it, then: $PRIME_CMD"
  done
  [ "$(uname -s)" = Linux ] || no_verdict "the pin file pins linux builds, and this machine runs $(uname -s)"
  case "$(uname -m)" in
    x86_64 | amd64) arch=amd64 ;;
    aarch64 | arm64) arch=arm64 ;;
    *) no_verdict "the pin file pins linux amd64 and arm64 builds, and this machine's architecture is $(uname -m)" ;;
  esac
  settle_cache
  load_pins "$arch" "$TMP/requirements.txt"
  [[ $PIN_DIGEST =~ ^[0-9a-f]{64}$ ]] || no_verdict "the pin file's digest is unreadable"

  if [ -f "$CACHE_DIR/primed" ]; then
    echo "$ME: the cache is primed for this pin file ($CACHE_DIR); running --self-test over it"
    if (self_test); then
      echo "$ME: primed — $CACHE_DIR"
      return 0
    fi
    echo "$ME: the primed cache fails --self-test; priming it again"
  fi

  rm -rf -- "$CACHE_DIR"
  downloads="$CACHE_DIR/downloads"
  mkdir -p "$downloads" "$CACHE_DIR/opentofu" "$CACHE_DIR/arm-schemas" || prime_fail "cannot make $CACHE_DIR"

  echo "$ME: OpenTofu $PIN_TOFU_VERSION (linux_$arch)"
  fetch_verified "OpenTofu $PIN_TOFU_VERSION (linux_$arch)" \
    "https://github.com/opentofu/opentofu/releases/download/v$PIN_TOFU_VERSION/tofu_${PIN_TOFU_VERSION}_linux_$arch.tar.gz" \
    "$PIN_TOFU_SHA256" "$downloads/opentofu.tar.gz"
  { tar -xzf "$downloads/opentofu.tar.gz" -C "$CACHE_DIR/opentofu" tofu && [ -x "$CACHE_DIR/opentofu/tofu" ]; } ||
    prime_fail "OpenTofu $PIN_TOFU_VERSION: its archive holds no tofu to unpack"
  rm -f -- "$downloads/opentofu.tar.gz"

  echo "$ME: the Azure Resource Manager schemas at $PIN_ARM_COMMIT"
  fetch_verified "the Azure Resource Manager schemas at $PIN_ARM_COMMIT" \
    "https://codeload.github.com/Azure/azure-resource-manager-schemas/tar.gz/$PIN_ARM_COMMIT" \
    "$PIN_ARM_SHA256" "$downloads/arm-schemas.tar.gz"
  { tar -xzf "$downloads/arm-schemas.tar.gz" -C "$CACHE_DIR/arm-schemas" --strip-components=1 \
    "azure-resource-manager-schemas-$PIN_ARM_COMMIT/schemas" && [ -d "$CACHE_DIR/arm-schemas/schemas" ]; } ||
    prime_fail "the Azure Resource Manager schemas at $PIN_ARM_COMMIT: the archive holds no schemas directory to unpack"
  rm -f -- "$downloads/arm-schemas.tar.gz"

  # Each provider unpacked where an OpenTofu filesystem mirror looks for it:
  # <host>/<namespace>/<type>/<version>/<os>_<arch>/, the address in lower case.
  for entry in "${PIN_PROVIDERS[@]}"; do
    read -r source version zh <<<"$entry"
    n=$((n + 1))
    echo "$ME: provider $source $version (linux_$arch)"
    url="https://registry.opentofu.org/v1/providers/$source/$version/download/linux/$arch"
    curl --proto '=https' --proto-redir '=https' --tlsv1.2 -fsSL --retry 3 -o "$downloads/provider-$n.json" "$url" ||
      prime_fail "provider $source $version (linux_$arch): registry.opentofu.org answers no download at $url"
    url="$(python3 -I -c '
import json, sys
with open(sys.argv[1], encoding="utf-8") as f:
    url = json.load(f).get("download_url", "")
if not isinstance(url, str) or not url.startswith("https://"):
    sys.exit(1)
print(url)
' "$downloads/provider-$n.json")" ||
      prime_fail "provider $source $version (linux_$arch): registry.opentofu.org names no https download_url"
    fetch_verified "provider $source $version (linux_$arch)" "$url" "$zh" "$downloads/provider-$n.zip"
    dir="$CACHE_DIR/providers/registry.opentofu.org/${source,,}/$version/linux_$arch"
    { mkdir -p "$dir" && unzip -q -o "$downloads/provider-$n.zip" -d "$dir" &&
      compgen -G "$dir/terraform-provider-*" >/dev/null && chmod +x "$dir"/terraform-provider-*; } ||
      prime_fail "provider $source $version (linux_$arch): its archive holds no terraform-provider binary to unpack"
    rm -f -- "$downloads/provider-$n.zip" "$downloads/provider-$n.json"
  done

  echo "$ME: cfn-lint ${PIN_PYTHON[cfn-lint]}, jsonschema ${PIN_PYTHON[jsonschema]} and referencing ${PIN_PYTHON[referencing]}, hash-locked"
  cp "$TMP/requirements.txt" "$CACHE_DIR/requirements.txt" || prime_fail "cannot write $CACHE_DIR/requirements.txt"
  python3 -m venv "$CACHE_DIR/venv" ||
    prime_fail "python3 -m venv cannot make a virtual environment (on Debian and Ubuntu its module is the python3-venv package)"
  if ! "$CACHE_DIR/venv/bin/python" -I -m pip --isolated --disable-pip-version-check --no-input install \
    --require-hashes --only-binary=:all: -r "$CACHE_DIR/requirements.txt" >"$TMP/pip.log" 2>&1; then
    tail -n 15 "$TMP/pip.log" >&2
    prime_fail "the Python packages did not install from their pinned hashes (pip's last lines above)"
  fi
  rmdir -- "$downloads" || prime_fail "$downloads holds something no step unpacked"

  PRIMING=1
  (self_test) || prime_fail "--self-test failed over the cache just filled (above)"
  printf '%s\n' "$PIN_DIGEST" >"$CACHE_DIR/primed" || prime_fail "cannot write $CACHE_DIR/primed"
  echo "$ME: primed in $(($(date +%s) - started)) s — $CACHE_DIR"
}

# --- the self-test ----------------------------------------------------------------
# The cases, in the order they run: one function each, below.
ST_CASES=(
  st_marker_added
  st_marker_renamed
  st_marker_kept_in_an_edited_file
  st_pass_through_one_byte
  st_pass_through_final_newline
  st_pass_through_crlf
  st_pass_through_by_import
  st_canonical_changed
  st_canonical_changed_published_kept
  st_clean_commit
  st_unprimed
  st_primed_for_another_pin_file
  st_cached_tofu_other_version
  st_cached_cfn_lint_other_version
  st_tofu_on_path_unused
  st_binary_missing
  st_binary_below_minimum
  st_binary_between_releases
  st_validators_answer_pins
)
# The container Recipe every scratch repository carries.
ST_RECIPE="$TF_RECIPES/probe-service/1.0.0"

# self_test — runs every case; fails when one does not give its expected verdict.
# Its callers run it in a subshell, (self_test), so nothing it sets for the
# scratch repositories reaches the rest of the run.
self_test() {
  local var c
  # A scratch repository is a repository of its own: no variable git set for the
  # repository this script judges reaches it, and no configuration but its own.
  for var in $(git rev-parse --local-env-vars); do unset "$var"; done
  export GIT_CONFIG_GLOBAL=/dev/null GIT_CONFIG_NOSYSTEM=1
  export GIT_AUTHOR_NAME=self-test GIT_AUTHOR_EMAIL=self-test@example.com
  export GIT_COMMITTER_NAME=self-test GIT_COMMITTER_EMAIL=self-test@example.com
  unset PUBLISHED_REMOTE
  ST_ROOT="$TMP/self-test"
  ST_N=0
  ST_FAILED=0
  mkdir -p "$ST_ROOT" || exit 1
  st_stubs
  echo "$ME --self-test:"
  for c in "${ST_CASES[@]}"; do "$c"; done
  if [ "$ST_FAILED" -gt 0 ]; then
    echo "$ME --self-test: $ST_FAILED case(s) did not give their expected verdict"
    exit 1
  fi
  echo "$ME --self-test: every case gave its expected verdict"
}

# st_broken WHAT — a case could not set up its scratch repository.
# shellcheck disable=SC2329 # called from the cases, which run by name from ST_CASES
st_broken() {
  ST_RC=-1
  ST_OUT="the self-test could not $1"
  st_failed "${FUNCNAME[1]}" "its scratch repository"
}

# st_repo — makes ST_REPO, a scratch repository holding a copy of this script's
# directory and a terraform container Recipe carrying the canonical pass-through,
# all committed.
# shellcheck disable=SC2329 # called from the cases, which run by name from ST_CASES
st_repo() {
  ST_N=$((ST_N + 1))
  ST_REPO="$ST_ROOT/repo-$ST_N"
  local recipe="$ST_REPO/$ST_RECIPE"
  mkdir -p "$recipe/module" &&
    cp -R "$HERE" "$ST_REPO/scripts" &&
    cp "$HERE/container-pass-through/main.tf" "$recipe/module/main.tf" &&
    st_recipe_yaml probe-service >"$recipe/recipe.yaml" &&
    printf 'A scratch repository the self-test judges.\n' >"$ST_REPO/README.md" &&
    git -C "$ST_REPO" init -q &&
    git -C "$ST_REPO" add -- . &&
    git -C "$ST_REPO" commit -q -m base
}

# st_recipe_yaml NAME — a terraform container Recipe's recipe.yaml, importing its
# service module under the artifacts key service.
# shellcheck disable=SC2329 # called from the cases, which run by name from ST_CASES
st_recipe_yaml() {
  printf '%s\n' \
    "apiVersion: aggrega.ai/v1beta1" \
    "kind: Recipe" \
    "metadata:" \
    "  name: $1" \
    "spec:" \
    "  source: ./module" \
    "  artifacts:" \
    "    service:" \
    "      \$import: ProbeService#/artifacts/Service"
}

# st_plant_marker FILE — writes FILE in ST_REPO carrying the vendor-text marker on
# its third line.
# shellcheck disable=SC2329 # called from the cases, which run by name from ST_CASES
st_plant_marker() {
  mkdir -p "$(dirname -- "$ST_REPO/$1")" &&
    printf '%s\n' "# A drafted Component." "description: The bucket." "  # $VENDOR_MARKER The bucket's name." >"$ST_REPO/$1"
}

# st_publish REFERENCE/VERSION — records REFERENCE at VERSION as published in
# ST_REPO: origin's published branch, as last fetched, holding the record.
# shellcheck disable=SC2329 # called from the cases, which run by name from ST_CASES
st_publish() {
  local blob tree commit
  blob="$(printf '%s\t%s\t%s\n' "${1%/*}" "${1##*/}" "sha256:$(printf '%064d' 0)" |
    git -C "$ST_REPO" hash-object -w --stdin)" &&
    tree="$(printf '100644 blob %s\t%s\n' "$blob" "$DIGESTS_FILE" | git -C "$ST_REPO" mktree)" &&
    commit="$(git -C "$ST_REPO" commit-tree -m published "$tree")" &&
    git -C "$ST_REPO" update-ref "refs/remotes/origin/$PUBLISHED_BRANCH" "$commit"
}

# st_run FORM [NAME=VALUE...] — runs the copy of this script in ST_REPO with FORM
# and the environment given; ST_RC and ST_OUT get its exit status and everything
# it printed.
# shellcheck disable=SC2329 # called from the cases, which run by name from ST_CASES
st_run() {
  local form="$1"
  shift
  ST_RC=0
  ST_OUT="$(cd "$ST_REPO" && env "$@" bash "$ST_REPO/scripts/vendor-validate.sh" "$form" 2>&1)" || ST_RC=$?
}

# st_stubs — the stand-ins the cases run: aggrega binaries answering a version,
# and a tofu and a cfn-lint on PATH answering one no pin names.
st_stubs() {
  local a b c low
  IFS=. read -r a b c <<<"$PIN_AGGREGA_MIN"
  if [ "$c" -gt 0 ]; then low="$a.$b.$((c - 1))"
  elif [ "$b" -gt 0 ]; then low="$a.$((b - 1)).99"
  else low="$((a - 1)).99.99"
  fi
  ST_BELOW_MIN="$low"
  mkdir -p "$ST_ROOT/bin" "$ST_ROOT/path" || return 1
  st_stub_aggrega "$ST_ROOT/bin/aggrega-at-minimum" "$PIN_AGGREGA_MIN"
  st_stub_aggrega "$ST_ROOT/bin/aggrega-below-minimum" "$ST_BELOW_MIN"
  st_stub_aggrega "$ST_ROOT/bin/aggrega-between-releases" "$PIN_AGGREGA_MIN-41-g697285c71-dirty"
  st_stub_tofu "$ST_ROOT/path/tofu" 0.0.0
  st_stub_cfn_lint "$ST_ROOT/path/cfn-lint" 0.0.0
}

# shellcheck disable=SC2016 # the stub's own $1, not this script's
st_stub_aggrega() {
  printf '#!/bin/sh\n[ "$1 $2 $3" = "version -o json" ] || exit 2\nprintf %s\n' \
    "'{\"version\": \"$2\", \"commit\": \"0000000\"}\\n'" >"$1" && chmod +x "$1"
}
st_stub_tofu() {
  printf '#!/bin/sh\nprintf %s\n' "'{\"terraform_version\": \"$2\"}\\n'" >"$1" && chmod +x "$1"
}
st_stub_cfn_lint() {
  printf '#!/bin/sh\necho "cfn-lint %s"\n' "$2" >"$1" && chmod +x "$1"
}

# st_cache HOME TOFU CFN_LINT [DIGEST] — a primed cache under HOME, for DIGEST
# (default: this pin file's), whose tofu and cfn-lint answer the versions given.
# shellcheck disable=SC2329 # called from the cases, which run by name from ST_CASES
st_cache() {
  local dir="$1/.cache/aggrega/vendor-validators/${4:-$PIN_DIGEST}"
  mkdir -p "$dir/opentofu" "$dir/venv/bin" &&
    st_stub_tofu "$dir/opentofu/tofu" "$2" &&
    st_stub_cfn_lint "$dir/venv/bin/cfn-lint" "$3" &&
    printf '%s\n' "${4:-$PIN_DIGEST}" >"$dir/primed"
}

# The reporters every case ends with. st_caught LABEL STATUS NEEDLE... — the
# case's run must exit STATUS and its output name every NEEDLE. st_passed LABEL —
# the case's run must exit 0.
# shellcheck disable=SC2329 # called from the cases, which run by name from ST_CASES
st_caught() {
  local label="$1" want="$2" needle
  shift 2
  if [ "$ST_RC" -ne "$want" ]; then
    st_failed "$label" "exit $want"
    return
  fi
  for needle in "$@"; do
    case "$ST_OUT" in
      *"$needle"*) ;;
      *) st_failed "$label" "exit $want naming \"$needle\""; return ;;
    esac
  done
  printf '  caught  %s\n' "$label"
}
# shellcheck disable=SC2329 # called from the cases, which run by name from ST_CASES
st_passed() {
  if [ "$ST_RC" -ne 0 ]; then
    st_failed "$1" "exit 0"
    return
  fi
  printf '  passed  %s\n' "$1"
}
# shellcheck disable=SC2329 # called from the cases, which run by name from ST_CASES
st_failed() {
  ST_FAILED=$((ST_FAILED + 1))
  printf '  ✗ FAILED  %s: expected %s, got exit %s; its output ends:\n' "$1" "$2" "$ST_RC"
  printf '%s\n' "$ST_OUT" | tail -n 6 | sed 's/^/        /'
}

# --- the cases -------------------------------------------------------------------
# shellcheck disable=SC2329 # a case, run by name from ST_CASES
st_marker_added() {
  { st_repo && st_plant_marker docs/draft.yaml && git -C "$ST_REPO" add -- docs/draft.yaml; } || { st_broken "stage a file"; return; }
  st_run --staged
  st_caught "a staged file carrying the vendor-text marker" 1 "docs/draft.yaml:3:"
}

# shellcheck disable=SC2329 # a case, run by name from ST_CASES
st_marker_renamed() {
  { st_repo && st_plant_marker docs/draft.yaml && git -C "$ST_REPO" add -- docs/draft.yaml &&
    git -C "$ST_REPO" commit -q -m draft && git -C "$ST_REPO" mv -- docs/draft.yaml docs/renamed.yaml; } ||
    { st_broken "rename a file"; return; }
  st_run --staged
  st_caught "a file carrying the vendor-text marker, only renamed" 1 "docs/renamed.yaml:3:"
}

# shellcheck disable=SC2329 # a case, run by name from ST_CASES
st_marker_kept_in_an_edited_file() {
  { st_repo && st_plant_marker docs/draft.yaml && git -C "$ST_REPO" add -- docs/draft.yaml &&
    git -C "$ST_REPO" commit -q -m draft && sed -i '1s/$/ Edited./' "$ST_REPO/docs/draft.yaml" &&
    git -C "$ST_REPO" add -- docs/draft.yaml; } || { st_broken "edit a file"; return; }
  st_run --staged
  st_caught "a file carrying the vendor-text marker, edited on another line" 1 "docs/draft.yaml:3:"
}

# shellcheck disable=SC2329 # a case, run by name from ST_CASES
st_pass_through_one_byte() {
  { st_repo && sed -i 's/type = any/type = anz/' "$ST_REPO/$ST_RECIPE/module/main.tf" &&
    git -C "$ST_REPO" add -- "$ST_RECIPE/module/main.tf"; } || { st_broken "change a pass-through"; return; }
  st_run --staged
  st_caught "a pass-through differing by one byte" 1 "$ST_RECIPE/module/main.tf" "$CANONICAL"
}

# shellcheck disable=SC2329 # a case, run by name from ST_CASES
st_pass_through_final_newline() {
  { st_repo && printf '\n' >>"$ST_REPO/$ST_RECIPE/module/main.tf" &&
    git -C "$ST_REPO" add -- "$ST_RECIPE/module/main.tf"; } || { st_broken "change a pass-through"; return; }
  st_run --staged
  st_caught "a pass-through differing by a trailing newline" 1 "$ST_RECIPE/module/main.tf" "$CANONICAL"
}

# shellcheck disable=SC2329 # a case, run by name from ST_CASES
st_pass_through_crlf() {
  { st_repo && sed -i 's/$/\r/' "$ST_REPO/$ST_RECIPE/module/main.tf" &&
    git -C "$ST_REPO" add -- "$ST_RECIPE/module/main.tf"; } || { st_broken "change a pass-through"; return; }
  st_run --staged
  st_caught "a pass-through with CRLF line ends" 1 "$ST_RECIPE/module/main.tf" "$CANONICAL"
}

# A Recipe whose module/main.tf does not reference ./service is a container Recipe
# by its recipe.yaml alone.
# shellcheck disable=SC2329 # a case, run by name from ST_CASES
st_pass_through_by_import() {
  local worker="$TF_RECIPES/probe-worker/1.0.0"
  { st_repo && mkdir -p "$ST_REPO/$worker/module" &&
    st_recipe_yaml probe-worker >"$ST_REPO/$worker/recipe.yaml" &&
    printf 'variable "config" {\n  type = any\n}\n' >"$ST_REPO/$worker/module/main.tf" &&
    git -C "$ST_REPO" add -- "$worker"; } || { st_broken "add a Recipe"; return; }
  st_run --staged
  st_caught "a Recipe importing under the artifacts key service without the pass-through" 1 \
    "$worker/module/main.tf" "$CANONICAL"
}

# shellcheck disable=SC2329 # a case, run by name from ST_CASES
st_canonical_changed() {
  { st_repo && printf '# Changed.\n' >>"$ST_REPO/$CANONICAL" &&
    git -C "$ST_REPO" add -- "$CANONICAL"; } || { st_broken "change the canonical file"; return; }
  st_run --staged
  st_caught "a changed canonical file every unpublished container Recipe now differs from" 1 \
    "$ST_RECIPE/module/main.tf" "$CANONICAL"
}

# The same change, with the Recipe's version in the published record: a published
# version keeps the file it was published with.
# shellcheck disable=SC2329 # a case, run by name from ST_CASES
st_canonical_changed_published_kept() {
  { st_repo && st_publish "hub.aggrega.ai/${ST_RECIPE#"$CATALOG_ROOT"/}" &&
    printf '# Changed.\n' >>"$ST_REPO/$CANONICAL" &&
    git -C "$ST_REPO" add -- "$CANONICAL"; } || { st_broken "record a published version"; return; }
  st_run --staged
  st_passed "a changed canonical file, a published container Recipe keeping its own"
}

# shellcheck disable=SC2329 # a case, run by name from ST_CASES
st_clean_commit() {
  local next="$TF_RECIPES/probe-service/1.1.0"
  { st_repo && mkdir -p "$ST_REPO/$next/module" &&
    cp "$ST_REPO/$CANONICAL" "$ST_REPO/$next/module/main.tf" &&
    st_recipe_yaml probe-service >"$ST_REPO/$next/recipe.yaml" &&
    printf 'Edited.\n' >>"$ST_REPO/README.md" &&
    git -C "$ST_REPO" add -- "$next" README.md; } || { st_broken "stage a clean change"; return; }
  st_run --staged
  st_passed "a clean commit"
}

# shellcheck disable=SC2329 # a case, run by name from ST_CASES
st_unprimed() {
  local home="$ST_ROOT/home-$((ST_N + 1))"
  { st_repo && mkdir -p "$home"; } || { st_broken "make a home"; return; }
  st_run --all HOME="$home" AGGREGA_BIN="$ST_ROOT/bin/aggrega-at-minimum"
  st_caught "a machine where nothing is primed" 3 \
    "not primed for this pin file" "$ST_REPO/scripts/vendor-validate.sh --prime"
}

# shellcheck disable=SC2329 # a case, run by name from ST_CASES
st_primed_for_another_pin_file() {
  local home="$ST_ROOT/home-$((ST_N + 1))" other
  other="$(printf 'another pin file\n' | sha256sum | awk '{ print $1 }')"
  { st_repo && st_cache "$home" "$PIN_TOFU_VERSION" "${PIN_PYTHON[cfn-lint]}" "$other"; } ||
    { st_broken "make a cache"; return; }
  st_run --all HOME="$home" AGGREGA_BIN="$ST_ROOT/bin/aggrega-at-minimum"
  st_caught "a cache primed for another pin file" 3 \
    "primed for another pin file" "$ST_REPO/scripts/vendor-validate.sh --prime"
}

# shellcheck disable=SC2329 # a case, run by name from ST_CASES
st_cached_tofu_other_version() {
  local home="$ST_ROOT/home-$((ST_N + 1))"
  { st_repo && st_cache "$home" 0.0.0 "${PIN_PYTHON[cfn-lint]}"; } || { st_broken "make a cache"; return; }
  st_run --all HOME="$home" AGGREGA_BIN="$ST_ROOT/bin/aggrega-at-minimum"
  st_caught "a cached tofu at another version" 3 \
    "cached tofu" "answers 0.0.0" "$ST_REPO/scripts/vendor-validate.sh --prime"
}

# shellcheck disable=SC2329 # a case, run by name from ST_CASES
st_cached_cfn_lint_other_version() {
  local home="$ST_ROOT/home-$((ST_N + 1))"
  { st_repo && st_cache "$home" "$PIN_TOFU_VERSION" 0.0.0; } || { st_broken "make a cache"; return; }
  st_run --all HOME="$home" AGGREGA_BIN="$ST_ROOT/bin/aggrega-at-minimum"
  st_caught "a cached cfn-lint at another version" 3 \
    "cached cfn-lint" "answers 0.0.0" "$ST_REPO/scripts/vendor-validate.sh --prime"
}

# shellcheck disable=SC2329 # a case, run by name from ST_CASES
st_tofu_on_path_unused() {
  local home="$ST_ROOT/home-$((ST_N + 1))"
  { st_repo && st_cache "$home" "$PIN_TOFU_VERSION" "${PIN_PYTHON[cfn-lint]}"; } || { st_broken "make a cache"; return; }
  st_run --all HOME="$home" AGGREGA_BIN="$ST_ROOT/bin/aggrega-at-minimum" PATH="$ST_ROOT/path:$PATH"
  st_passed "a tofu and a cfn-lint on PATH at another version, never used"
}

# shellcheck disable=SC2329 # a case, run by name from ST_CASES
st_binary_missing() {
  local home="$ST_ROOT/home-$((ST_N + 1))"
  { st_repo && st_cache "$home" "$PIN_TOFU_VERSION" "${PIN_PYTHON[cfn-lint]}"; } || { st_broken "make a cache"; return; }
  st_run --all HOME="$home" AGGREGA_BIN="$ST_ROOT/bin/no-such-aggrega"
  st_caught "no aggrega binary" 3 "no aggrega binary" "AGGREGA_BIN"
}

# shellcheck disable=SC2329 # a case, run by name from ST_CASES
st_binary_below_minimum() {
  local home="$ST_ROOT/home-$((ST_N + 1))"
  { st_repo && st_cache "$home" "$PIN_TOFU_VERSION" "${PIN_PYTHON[cfn-lint]}"; } || { st_broken "make a cache"; return; }
  st_run --all HOME="$home" AGGREGA_BIN="$ST_ROOT/bin/aggrega-below-minimum"
  st_caught "an aggrega binary below aggrega_min_version" 3 \
    "is aggrega $ST_BELOW_MIN, below $PIN_AGGREGA_MIN" "AGGREGA_BIN"
}

# shellcheck disable=SC2329 # a case, run by name from ST_CASES
st_binary_between_releases() {
  local home="$ST_ROOT/home-$((ST_N + 1))"
  { st_repo && st_cache "$home" "$PIN_TOFU_VERSION" "${PIN_PYTHON[cfn-lint]}"; } || { st_broken "make a cache"; return; }
  st_run --all HOME="$home" AGGREGA_BIN="$ST_ROOT/bin/aggrega-between-releases"
  st_passed "an aggrega build between releases, $PIN_AGGREGA_MIN-41-g697285c71-dirty, counted as $PIN_AGGREGA_MIN"
}

# The cache this script runs from, not a copy: each validator it holds answers the
# version the pin file names.
# shellcheck disable=SC2329 # a case, run by name from ST_CASES
st_validators_answer_pins() {
  local got want name
  local -a wrong=()
  got="$(tofu_version "$CACHE_DIR/opentofu/tofu")"
  [ "$got" = "$PIN_TOFU_VERSION" ] || wrong+=("tofu answers '${got}', not $PIN_TOFU_VERSION")
  got="$(cfn_lint_version "$CACHE_DIR/venv/bin/cfn-lint")"
  want="${PIN_PYTHON[cfn-lint]}"
  [ "$got" = "$want" ] || wrong+=("cfn-lint answers '${got}', not $want")
  for name in jsonschema referencing; do
    got="$(python_package_version "$CACHE_DIR/venv/bin/python" "$name")"
    want="${PIN_PYTHON[$name]}"
    [ "$got" = "$want" ] || wrong+=("$name answers '${got}', not $want")
  done
  ST_RC=0
  ST_OUT=""
  if [ "${#wrong[@]}" -gt 0 ]; then
    ST_RC=1
    ST_OUT="$(printf '%s\n' "${wrong[@]}")"
  fi
  st_passed "each cached validator answers its pinned version: tofu $PIN_TOFU_VERSION, cfn-lint ${PIN_PYTHON[cfn-lint]}, jsonschema ${PIN_PYTHON[jsonschema]}, referencing ${PIN_PYTHON[referencing]}"
}

# --- the run ---------------------------------------------------------------------
case "$MODE" in
  staged | all)
    vendor_text_rule
    pass_through_rule
    [ "$REFUSED" -eq 0 ] || exit 1
    if [ "$MODE" = all ]; then
      require_validators
      echo "$ME: passed — no vendor text, every container Recipe carries the canonical pass-through, and the validators are primed ($CACHE_DIR)"
    else
      echo "$ME: passed — no vendor text staged, and every container Recipe the commit reaches carries the canonical pass-through"
    fi
    ;;
  self-test)
    CAUSES=()
    settle_cache
    load_pins
    cache_causes
    [ "${#CAUSES[@]}" -eq 0 ] || no_verdict "${CAUSES[@]}"
    (self_test) || exit 1
    ;;
  prime)
    prime
    ;;
esac
exit 0
