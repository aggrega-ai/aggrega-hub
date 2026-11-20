#!/usr/bin/env bash
# shellcheck source-path=SCRIPTDIR disable=SC1091
# scripts/vendor-validate.sh — hold the catalog's cloud Recipes to what the
# vendors' own validators accept, offline, and every commit to the rules that
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
# RULES BEFORE ANY VALIDATOR. The vendor-text rule, the pass-through rule and the
# cfn-lint configuration rule read blobs with git and match text with grep and
# awk, and they run before any validator is looked for, so they hold on a machine
# where nothing is primed. A container Recipe, and a rule .cfnlintrc.yaml
# ignores, are recognised by their text rather than by a YAML parser for the same
# reason: a rule depends on no tool the machine may lack.
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
# THE VALIDATORS OVER A RENDERED BOUNDARY. tofu_findings, cfn_lint_findings and
# arm_findings each take TREE, the tree a build read its catalog from (the
# directory holding aggrega-catalog/ and .cfnlintrc.yaml), and BOUNDARY, one
# boundary directory the build rendered (dist/<directory>/). Each validates the
# root it reads when BOUNDARY holds it, and prints nothing and returns 0 when it
# does not, so a caller runs all three on every boundary. On standard output it
# prints one line per finding, sorted:
#     <id> TAB <attribution> TAB <message>
# the attribution - for none; the message is the validator's, on one line, and
# may name a line number, which the id never does. It returns 0 with no finding
# and 1 with findings. Warnings go to standard error and refuse nothing. A
# validator that cannot give a reading is no verdict: the run exits 3 naming
# why, so a caller that must go on runs the function in a subshell. --help holds
# the ids and the attribution. A caller runs require_validators first.
#
# OFFLINE BY CONSTRUCTION. tofu runs with a CLI configuration naming the cache's
# mirror alone, refusing the two public module registries by name, and with
# every proxy variable pointing at a local port that refuses, so a module source
# that would reach the network fails at once, as a finding naming the module,
# rather than waiting on it.
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
validators accept, offline, and every commit to the rules that need no
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
  --all        judge everything the index holds by VENDOR TEXT, THE
               CANONICAL PASS-THROUGH and THE CFN-LINT CONFIGURATION, then
               require THE VALIDATORS.
  --prime      fetch every validator the pin file names into the cache, verify
               each checksum, and run --self-test against the result. The one
               form that uses the network.
  --self-test  prove, in scratch repositories under a temporary directory,
               that each rule refuses the fault it exists for and passes a
               clean commit, that a missing or mismatched validator or binary
               gives no verdict, that each cached validator answers its
               pinned version, that the Azure Resource Manager check refuses
               each fault it exists for, by its finding id, and passes a
               clean template, and that tofu, cfn-lint and that check, run
               over a rendered boundary, each name a fault planted there by
               its finding id and the entity version it belongs to, the id
               holding across runs and line moves, cfn-lint's even where the
               template tells cfn-lint to ignore its rule. Needs the primed
               cache.

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

THE CFN-LINT CONFIGURATION (--all)
  .cfnlintrc.yaml, at the top of this repository, is the one configuration
  cfn-lint reads. Each rule it ignores is a line of its own under
  ignore_checks, - <rule>, with its reason in a comment beside it or on the
  line directly above: what the rule reports, and why a template this catalog
  renders is right to carry it anyway. An entry with no reason, or rules
  written in brackets on the ignore_checks line itself (an empty list, [],
  aside), is refused, naming the line and the rule; so is the file's absence
  from the index. The file is read from the index, as a text, with no YAML
  parser.

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

  The Azure Resource Manager check, scripts/vendor-validate-arm.py, runs with
  the cache's Python over the cached schemas: the template syntax Microsoft
  documents, then each resource against the vendor's schema for its type at
  its apiVersion. Its header holds its rules and its finding ids.

  Each validator runs over a boundary directory a build rendered, offline:
    tofu      the root configuration <boundary>/terraform/aggrega.modules.tf:
              tofu init -backend=false -input=false, then tofu validate. The
              cache's provider mirror is the one place a provider comes
              from, each linked from the mirror rather than copied; a module
              from a registry, or from any other remote source, fails init
              at once. Both run in a scratch copy of the root, so nothing
              they write lands in the boundary. Every error is a finding,
              init's included; a warning is printed and refuses nothing.
              tofu does not always report every error at once: an error in
              a module block's arguments hides those inside the module, so
              mending one finding can bring another to light.
    cfn-lint  <boundary>/cloudformation/cloudformation-stack.json, with
              --config-file .cfnlintrc.yaml --non-zero-exit-code warning
              --regions us-east-1. Every error and warning is a finding.
              cfn-lint reads no configuration file but .cfnlintrc.yaml (THE
              CFN-LINT CONFIGURATION above). It would also take rules to
              ignore, and more, from a template's own Metadata, under the
              key cfn-lint, at the top and on each resource: it lints a copy
              of the template with every such key set aside, each named on
              standard error, so that configuration takes no effect.
    arm       <boundary>/arm/arm-template.json, by the check above.

  A form that requires the validators requires, before it runs any: the cache
  primed for this pin file; the cached tofu and cfn-lint answering their
  pinned versions; and an aggrega binary at aggrega_min_version or later, its
  version read from aggrega version -o json. Only the binary's leading X.Y.Z
  counts: a build between releases, 0.10.0-41-g697285c71-dirty, counts as
  0.10.0. Each missing requirement gives no verdict, naming the one command
  that supplies it. Every validator runs from the cache by its full path: the
  tofu or cfn-lint on PATH is never used.

FINDINGS
  A finding's id is <validator>|<rule>|<address>, and carries no line number
  and no absolute path, so the same fault keeps its id across runs and when
  lines move above it:
    tofu      the diagnostic's summary; the file, relative to the boundary,
              then the block it lies in and the first quoted name in its
              detail, joined with /:
                tofu|Unsupported argument|terraform/modules/app/main.tf/
                  resource "random_id" "app"/no_such_attribute
              A diagnostic with no file, such as a provider the mirror
              lacks, is addressed by the provider its detail names.
    cfn-lint  the cfn-lint rule; the path to the value in the template,
              Resources/<LogicalId>/<property path>:
                cfn-lint|E3002|Resources/Queue/Properties/VisibilityTimeoutt
    arm       the check's keyword; <template path>/<symbolic name>/
              <property path>, as its header gives.
  Each finding is attributed to the catalog entity version that rendered
  it, <kind>/<capability>/<name>@<version> (recipe/terraform/server-ecs@1.1.0),
  through the provenance the build stamps, which names <name>:<version>:
    terraform       modules/<dir>/aggrega.provenance.tf, else the
                    aggrega.ai/recipe-uri line in the comment block atop the
                    file, else the one such line every file directly in
                    modules/<dir>/ opens with; a finding in a module block
                    of the root configuration takes the provenance of the
                    directory the block's source names
    cloudformation  the resource's Metadata, aggrega.ai/provenance
    arm             the metadata, aggrega.ai/provenance, of the template's
                    resource the address names first, a nested deployment
                    carrying it for everything inside it
  The capability is the validator's provider, and the kind, recipe or
  featurerecipe, is that of the one Recipe or FeatureRecipe the catalog holds
  at <kind directory>/<capability>/<name>/<version>/. A finding with no
  provenance, or one naming no such entity or more than one, is attributed to
  -: no catalog entity version answers for it.

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
CFNLINTRC=".cfnlintrc.yaml"
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

# --- the cfn-lint configuration ---------------------------------------------------
# Each rule .cfnlintrc.yaml ignores, under ignore_checks, is a line of its own,
# - <rule>, with its reason in a comment beside it or on the line directly above;
# awk prints, for each that breaks this, its line number, a tab and what to write.
# A list written in brackets, empty or not, gives no rule a line of its own, so
# only the empty one, [], passes.
# shellcheck disable=SC2016 # awk's own $, not the shell's
CFNLINTRC_AWK='
  function trim(s) { sub(/^[ \t]+/, "", s); sub(/[ \t]+$/, "", s); return s }
  function uncomment(s) { sub(/^#.*$/, "", s); sub(/[ \t]+#.*$/, "", s); return trim(s) }
  function unquote(s) { if (s ~ /^".*"$/ || s ~ /^\047.*\047$/) s = substr(s, 2, length(s) - 2); return s }
  { sub(/\r$/, "") }
  in_list && $0 ~ /^[^ \t#-]/ { in_list = 0 }
  in_list && $0 ~ /^[ \t]*-/ {
    entry = $0
    sub(/^[ \t]*-[ \t]*/, "", entry)
    rule = unquote(uncomment(entry))
    if (entry !~ /[ \t]#[ \t]*[^ \t]/ && previous !~ /^[ \t]*#[ \t]*[^ \t]/)
      printf "%d\tignores the cfn-lint rule %s with no reason beside it or on the line above: write, in a comment there, what the rule reports and why a template this catalog renders is right to carry it anyway, or remove the entry\n", NR, rule
  }
  !in_list && $0 ~ /^ignore_checks[ \t]*:/ {
    rest = $0
    sub(/^ignore_checks[ \t]*:/, "", rest)
    rest = uncomment(rest)
    if (rest == "") in_list = 1
    else if (rest !~ /^\[[ \t]*\]$/)
      printf "%d\twrites the rules cfn-lint ignores inside the line itself (%s), where no rule has a line of its own for its reason: write each as a line - <rule> under ignore_checks, with its reason in a comment beside it or on the line above\n", NR, rest
  }
  { previous = $0 }'

# cfnlintrc_rule — refuses each rule .cfnlintrc.yaml, as the index holds it,
# ignores without its reason, naming the line and the rule; and the file's
# absence from the index, since cfn-lint takes its configuration from it alone.
cfnlintrc_rule() {
  local line why
  if ! staged_blob "$CFNLINTRC" "$TMP/cfnlintrc.yaml"; then
    refuse "$CFNLINTRC: not in the index. cfn-lint takes its configuration from it alone, each rule it ignores with its reason: restore it from git and stage it (git add -- $CFNLINTRC)."
    return
  fi
  while IFS=$'\t' read -r line why; do
    refuse "$CFNLINTRC:$line: $why."
  done < <(awk "$CFNLINTRC_AWK" "$TMP/cfnlintrc.yaml")
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

# arm_check DIR TEMPLATE... — runs the Azure Resource Manager check
# (vendor-validate-arm.py) with the cache's Python over the cache's schemas on
# each TEMPLATE, a path relative to DIR: the path every finding's id carries.
# Exits as the check does: 0 no finding, 1 findings, 2 a usage error, 3 no
# verdict.
# shellcheck disable=SC2329 # called from the cases, which run by name from ST_CASES
arm_check() {
  local dir="$1"
  shift
  (cd -- "$dir" && "$CACHE_DIR/venv/bin/python" -I "$HERE/vendor-validate-arm.py" "$CACHE_DIR/arm-schemas/schemas" "$@")
}

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

# --- the validators over a rendered boundary ---------------------------------------
# The findings reader: it reads what a validator wrote and prints one line per
# finding: its id, a tab, the provenance it was traced to (<name>:<version>, or -
# for none), a tab, and its message, the lines sorted. Warnings, which refuse nothing, go to standard error.
# When the validator's answer cannot be read, it prints why and exits 3. The first
# argument names the validator, and the rest are what it reads:
#   tofu      BOUNDARY WORK INIT_STATUS VALIDATE_STATUS — WORK holds the scratch
#             copy of the root (WORK/terraform), init.json, init.err and, when
#             init succeeded, validate.json and validate.err; VALIDATE_STATUS is
#             - when validate did not run
#   cfn-lint  BOUNDARY TEMPLATE OUTPUT STATUS LINES — LINES is 0 when cfn-lint
#             read a rewritten copy of the template, whose line numbers are not
#             the template's, so no message names one
#   arm       BOUNDARY TEMPLATE OUTPUT STATUS
PY_FINDINGS="$(cat <<'END_OF_PYTHON'
import json, os, re, sys

mode, boundary = sys.argv[1], sys.argv[2]
URI = re.compile(r"[A-Za-z0-9][A-Za-z0-9._-]*:[0-9][0-9A-Za-z.+-]*")
RECIPE_URI = re.compile(r"#\s*aggrega\.ai/recipe-uri:\s*(\S+)")
PROVENANCE = ("aggrega.ai/provenance", "aggrega.ai/recipe-uri")

def no_verdict(why):
    print(why)
    sys.exit(3)

def one_line(text):
    return " ".join(str(text).split())

def get(obj, *keys):
    for key in keys:
        obj = obj.get(key) if isinstance(obj, dict) else None
    return obj

def uri(value):
    return value if isinstance(value, str) and URI.fullmatch(value) else None

def read_json(path, what):
    try:
        with open(path, encoding="utf-8") as f:
            return json.load(f)
    except (OSError, ValueError) as e:
        no_verdict(f"{what} cannot be read as JSON ({e})")

def tail(path):
    try:
        with open(path, encoding="utf-8", errors="replace") as f:
            return one_line(" ".join(f.read().splitlines()[-5:]))
    except OSError:
        return ""

# terraform: the recipe-uri the comment block atop a file names.
def header_uri(path):
    found = []
    try:
        with open(path, encoding="utf-8") as f:
            for line in f:
                line = line.strip()
                if not line.startswith("#"):
                    break
                m = RECIPE_URI.fullmatch(line)
                if m:
                    found.append(m.group(1))
    except (OSError, UnicodeDecodeError):
        return None
    return uri(found[0]) if len(found) == 1 else None

# terraform: the provenance of a file in modules/<d>/ (the file FILE) or of the
# directory as a whole (FILE None): its aggrega.provenance.tf, else the
# recipe-uri atop FILE, else the one recipe-uri every file directly in it opens
# with.
def dir_uri(root, d, file=None):
    base = os.path.join(root, "modules", d)
    stamp = os.path.join(base, "aggrega.provenance.tf")
    if os.path.isfile(stamp):
        return header_uri(stamp)
    own = header_uri(os.path.join(root, file)) if file else None
    if own:
        return own
    try:
        names = sorted(n for n in os.listdir(base) if n.endswith(".tf"))
    except OSError:
        return None
    uris = {header_uri(os.path.join(base, n)) for n in names}
    return uris.pop() if len(uris) == 1 else None

# terraform: the directory under modules/ the module block NAME of the root file
# PATH sources.
def module_dir(path, name):
    head = re.compile(r'module\s+"' + re.escape(name) + r'"\s*\{\s*')
    source = re.compile(r'\s*source\s*=\s*"\./modules/([^"/]+)/?"\s*')
    inside = False
    try:
        with open(path, encoding="utf-8") as f:
            for line in f:
                line = line.rstrip("\n")
                if not inside:
                    inside = bool(head.fullmatch(line))
                elif line.startswith("}"):
                    return None
                else:
                    m = source.fullmatch(line)
                    if m:
                        return m.group(1)
    except (OSError, UnicodeDecodeError):
        return None
    return None

def tofu_provenance(root, rel, context):
    parts = rel.split("/")
    if len(parts) >= 3 and parts[0] == "modules":
        return dir_uri(root, parts[1], rel)
    if len(parts) == 1:
        m = re.fullmatch(r'module "([^"]+)"', context or "")
        d = module_dir(os.path.join(root, rel), m.group(1)) if m else None
        return dir_uri(root, d) if d else None
    return None

def tofu():
    work, init_status, validate_status = sys.argv[3], sys.argv[4], sys.argv[5]
    root = os.path.join(work, "terraform")
    diagnostics = []
    try:
        with open(os.path.join(work, "init.json"), encoding="utf-8") as f:
            for line in f:
                if not line.strip():
                    continue
                try:
                    event = json.loads(line)
                except ValueError:
                    no_verdict(f"tofu init wrote a line that is not JSON: {one_line(line)}")
                if isinstance(event, dict) and event.get("type") == "diagnostic":
                    diagnostics.append(("init", event.get("diagnostic")))
    except OSError as e:
        no_verdict(f"tofu init's output cannot be read ({e})")
    init_errors = sum(1 for _, d in diagnostics if get(d, "severity") == "error")
    if init_status != "0" and not init_errors:
        no_verdict(f"tofu init exited {init_status} naming no error: {tail(os.path.join(work, 'init.err'))}")
    if validate_status != "-":
        result = read_json(os.path.join(work, "validate.json"), "tofu validate's output")
        found = result.get("diagnostics") if isinstance(result, dict) else None
        if not isinstance(found, list):
            no_verdict(f"tofu validate exited {validate_status} with no diagnostics list: {tail(os.path.join(work, 'validate.err'))}")
        diagnostics += [("validate", d) for d in found]
        if validate_status != "0" and not any(get(d, "severity") == "error" for d in found):
            no_verdict(f"tofu validate exited {validate_status} naming no error: {tail(os.path.join(work, 'validate.err'))}")
    findings, warnings = set(), set()
    for stage, d in diagnostics:
        if not isinstance(d, dict):
            no_verdict(f"tofu {stage} wrote a diagnostic that is not an object: {d!r}")
        severity, summary, detail = d.get("severity"), one_line(d.get("summary") or ""), d.get("detail") or ""
        # Providers come from the cache's mirror alone, so init always reckons
        # their checksums locally, which says nothing of the root.
        if stage == "init" and severity == "warning" and summary == "Incomplete lock file information for providers":
            continue
        filename = get(d, "range", "filename")
        rel, outside = None, False
        if isinstance(filename, str) and filename:
            rel = os.path.relpath(filename, root) if os.path.isabs(filename) else os.path.normpath(filename)
            # A file outside the root is named alone: no id carries a path of
            # this machine, and no provenance answers for it.
            outside = rel == os.pardir or rel.startswith(os.pardir + os.sep)
            if outside:
                rel = os.path.basename(filename)
        context = get(d, "snippet", "context")
        context = one_line(context) if isinstance(context, str) else ""
        m = re.search(r'"([^"]+)"', detail) or re.search(
            r"\bprovider ([A-Za-z0-9][A-Za-z0-9_.-]*/[A-Za-z0-9][A-Za-z0-9_.-]*)", detail)
        name = m.group(1) if m else ""
        # A name that is a path of this machine is named relative to the
        # boundary when it lies in the root, and left out otherwise.
        if os.path.isabs(name):
            named = os.path.relpath(name, root)
            name = "" if named == os.pardir or named.startswith(os.pardir + os.sep) else "terraform/" + named
        elif work in name:
            name = ""
        name = one_line(name)
        shown = (rel if outside else "terraform/" + rel) if rel else ""
        address = "/".join(p for p in (one_line(shown), context, name) if p)
        ident = f"tofu|{summary}|{address}"
        line = get(d, "range", "start", "line")
        where = f" ({shown}:{line})" if shown and isinstance(line, int) else ""
        message = one_line(f"tofu {stage}: {summary}: {detail}{where}").replace(root, os.path.join(boundary, "terraform"))
        if severity == "error":
            prov = tofu_provenance(root, rel, context) if rel and not outside else None
            findings.add((ident, prov or "-", message))
        else:
            warnings.add((ident, message))
    for ident, message in sorted(warnings):
        print(f"  warning  {ident}\t{message}", file=sys.stderr)
    return findings

def cfn_lint():
    template, output, status, lines = sys.argv[3], sys.argv[4], sys.argv[5], sys.argv[6]
    matches = read_json(output, f"cfn-lint's reading of {template} (exit {status})")
    if not isinstance(matches, list):
        no_verdict(f"cfn-lint's reading of {template} (exit {status}) is not a list of findings")
    try:
        with open(os.path.join(boundary, template), encoding="utf-8") as f:
            doc = json.load(f)
    except (OSError, ValueError):
        doc = None
    findings, levels = set(), 0
    for m in matches:
        level, rule = get(m, "Level"), get(m, "Rule", "Id")
        if level not in ("Error", "Warning"):
            continue
        levels |= 2 if level == "Error" else 4
        path = get(m, "Location", "Path") or []
        address = "/".join(one_line(p) for p in path) if isinstance(path, list) else ""
        prov = None
        if isinstance(path, list) and len(path) >= 2 and path[0] == "Resources":
            prov = uri(get(get(doc, "Resources", str(path[1])), "Metadata", *PROVENANCE))
        line = get(m, "Location", "Start", "LineNumber")
        where = f" ({template}:{line})" if isinstance(line, int) and lines == "1" else ""
        message = one_line(f"cfn-lint {level.lower()}: {get(m, 'Message')}{where}")
        findings.add((f"cfn-lint|{one_line(rule)}|{address}", prov or "-", message))
    if status != str(levels):
        no_verdict(f"cfn-lint exited {status}, which its {len(findings)} error(s) and warning(s) on {template} do not account for")
    return findings

# arm: a finding about a section of the rendered template itself names no
# resource, so no Recipe.
TEMPLATE_KEYWORDS = ("template-json", "template-key", "resources-form")

def arm():
    template, output, status = sys.argv[3], sys.argv[4], sys.argv[5]
    try:
        with open(output, encoding="utf-8") as f:
            lines = f.read().splitlines()
    except OSError as e:
        no_verdict(f"the Azure Resource Manager check's output cannot be read ({e})")
    m = re.fullmatch(r"([0-9]+) finding\(s\)", lines[-1]) if lines else None
    if not m or int(m.group(1)) != len(lines) - 1 or status != ("1" if lines[:-1] else "0"):
        no_verdict(f"the Azure Resource Manager check on {template} (exit {status}) gave no reading ending in its count of findings")
    try:
        with open(os.path.join(boundary, template), encoding="utf-8") as f:
            resources = get(json.load(f), "resources")
    except (OSError, ValueError):
        resources = None
    findings = set()
    for line in lines[:-1]:
        ident, _, message = line.partition("\t")
        parts = ident.split("|", 2)
        if len(parts) != 3 or parts[0] != "arm":
            no_verdict(f"the Azure Resource Manager check wrote a line that is no finding: {one_line(line)}")
        prov, rest = None, parts[2][len(template) + 1:] if parts[2].startswith(template + "/") else ""
        if rest and not (parts[1] in TEMPLATE_KEYWORDS and "/" not in rest):
            name = rest.split("/", 1)[0]
            resource = None
            if isinstance(resources, dict):
                resource = resources.get(name)
            elif isinstance(resources, list) and name.isdigit() and int(name) < len(resources):
                resource = resources[int(name)]
            prov = uri(get(resource, "metadata", *PROVENANCE))
        findings.add((ident, prov or "-", one_line(f"arm: {message}")))
    return findings

findings = {"tofu": tofu, "cfn-lint": cfn_lint, "arm": arm}[mode]()
for finding in sorted(findings):
    print("\t".join(finding))
END_OF_PYTHON
)"

# The copy cfn-lint reads: it copies the stack template SOURCE to COPY and prints
# the path of each cfn-lint key it set aside, one a line. cfn-lint takes rules to
# ignore, regions and more from a template's own Metadata, under the key cfn-lint,
# at the top and on each resource; the copy carries none of them, so cfn-lint is
# configured by .cfnlintrc.yaml alone. A template with no such key, or one that
# is not JSON, is copied byte for byte; otherwise the copy is the template
# written again, every key in its order, a key written twice kept twice and every
# number as written, less those keys.
PY_CFN_LINT_COPY="$(cat <<'END_OF_PYTHON'
import json, sys

source, copy = sys.argv[1], sys.argv[2]
KEY = "cfn-lint"

class Members(list):
    """An object's members, as (key, value) pairs in their order."""

class Number(str):
    """A number, as written."""

def set_aside(obj, path, found):
    if isinstance(obj, Members) and any(k == KEY for k, _ in obj):
        obj[:] = [(k, v) for k, v in obj if k != KEY]
        found.append(f"{path}/{KEY}")

def dump(value, depth=0):
    pad, end = "  " * (depth + 1), "  " * depth
    if isinstance(value, Members):
        if not value:
            return "{}"
        return "{\n" + ",\n".join(f"{pad}{json.dumps(k)}: {dump(v, depth + 1)}" for k, v in value) + f"\n{end}}}"
    if isinstance(value, list):
        if not value:
            return "[]"
        return "[\n" + ",\n".join(pad + dump(v, depth + 1) for v in value) + f"\n{end}]"
    if isinstance(value, Number):
        return str(value)
    return json.dumps(value)

with open(source, "rb") as f:
    raw = f.read()
found = []
try:
    doc = json.loads(raw.decode("utf-8"), object_pairs_hook=Members, parse_float=Number, parse_int=Number,
                     parse_constant=Number)
except ValueError:
    doc = None
if isinstance(doc, Members):
    for key, value in doc:
        if key == "Metadata":
            set_aside(value, "Metadata", found)
        elif key == "Resources" and isinstance(value, Members):
            for name, resource in value:
                for rkey, rvalue in resource if isinstance(resource, Members) else ():
                    if rkey == "Metadata":
                        set_aside(rvalue, f"Resources/{name}/Metadata", found)
with open(copy, "wb") as f:
    f.write(dump(doc).encode("utf-8") + b"\n" if found else raw)
for path in found:
    print(path)
END_OF_PYTHON
)"

# entity_attribution TREE CAPABILITY PROVENANCE — the catalog entity version
# PROVENANCE (<name>:<version>, as the build stamps it) names among TREE's
# CAPABILITY entities, as <kind>/<capability>/<name>@<version>, kind recipe or
# featurerecipe; - when it names none, or more than one.
# shellcheck disable=SC2329 # called from the runners below, which are called by name
entity_attribution() {
  local tree="$1" cap="$2" prov="$3" name="${3%:*}" version="${3##*:}" dir file kind found=""
  if [[ $prov == *:* && $name =~ ^[A-Za-z0-9][A-Za-z0-9._-]*$ && $version =~ ^[0-9][0-9A-Za-z.+-]*$ ]]; then
    for dir in "$tree/$CATALOG_ROOT"/*/"$cap/$name/$version"; do
      for file in "$dir"/*.yaml "$dir"/*.yml; do
        [ -f "$file" ] || continue
        kind="$(peek_kind "$file")"
        case "$kind" in Recipe | FeatureRecipe) ;; *) continue ;; esac
        if [ -n "$found" ]; then
          found="-"
          break 2
        fi
        found="${kind,,}/$cap/$name@$version"
      done
    done
  fi
  printf '%s\n' "${found:--}"
}

# read_findings TREE CAPABILITY VALIDATOR ARG... — reads the validator's answer
# with PY_FINDINGS and prints each finding as its id, a tab, its attribution, a
# tab and its message. Returns 1 when there is a finding, 0 when there is none;
# an answer that cannot be read gives no verdict.
# shellcheck disable=SC2329 # called from the runners below, which are called by name
read_findings() {
  local tree="$1" cap="$2" out id prov message rc=0 n=0
  out="$(python3 -I -c "$PY_FINDINGS" "${@:3}")" || rc=$?
  if [ "$rc" -ne 0 ]; then
    [ -n "$out" ] || out="the answer of $3 cannot be read (exit $rc)"
    no_verdict "$out"
  fi
  while IFS=$'\t' read -r id prov message; do
    [ -n "$id" ] || continue
    n=$((n + 1))
    printf '%s\t%s\t%s\n' "$id" "$(entity_attribution "$tree" "$cap" "$prov")" "$message"
  done <<<"$out"
  [ "$n" -eq 0 ]
}

# The OpenTofu CLI configuration every root is initialised with, written once a
# run: the cache's mirror is the one place providers come from, and the plugin
# cache links each provider there rather than copying it. A module source on a
# registry host fails at once, and every other remote source fails too, since
# tofu_run points each proxy at a port that refuses: nothing reaches the network.
TOFU_RC=""
# shellcheck disable=SC2329 # called from the runners below, which are called by name
tofu_config() {
  [ -z "$TOFU_RC" ] || return 0
  local mirror="$CACHE_DIR/providers" plugins="$TMP/tofu-plugin-cache"
  [[ $mirror$plugins != *[\"\\\$]* ]] || no_verdict "the path $mirror or $plugins carries a character an OpenTofu configuration string cannot hold"
  mkdir -p "$plugins" || no_verdict "cannot make $plugins"
  printf '%s\n' \
    "provider_installation {" \
    "  filesystem_mirror {" \
    "    path = \"$mirror\"" \
    "  }" \
    "}" \
    "plugin_cache_dir = \"$plugins\"" \
    "host \"registry.opentofu.org\" {" \
    "  services = {}" \
    "}" \
    "host \"registry.terraform.io\" {" \
    "  services = {}" \
    "}" >"$TMP/tofu.tfrc" || no_verdict "cannot write $TMP/tofu.tfrc"
  TOFU_RC="$TMP/tofu.tfrc"
}

# tofu_run WORK ARG... — runs the cache's tofu with ARG in WORK/terraform, in an
# environment of its own: the CLI configuration above, its data directory in
# WORK, no prompt, and every proxy pointing at a port that refuses, so a module
# fetched over the network fails at once rather than waiting on it.
# shellcheck disable=SC2329 # called from the runners below, which are called by name
tofu_run() {
  local work="$1" refuse="http://127.0.0.1:9"
  shift
  (cd -- "$work/terraform" && env -i PATH="$PATH" HOME="$work" LANG=C.UTF-8 \
    TF_CLI_CONFIG_FILE="$TOFU_RC" TF_DATA_DIR="$work/data" TF_IN_AUTOMATION=1 TF_INPUT=0 \
    HTTPS_PROXY="$refuse" HTTP_PROXY="$refuse" ALL_PROXY="$refuse" https_proxy="$refuse" \
    http_proxy="$refuse" all_proxy="$refuse" NO_PROXY= no_proxy= \
    GIT_TERMINAL_PROMPT=0 GIT_SSH_COMMAND=false GIT_CONFIG_GLOBAL=/dev/null GIT_CONFIG_NOSYSTEM=1 \
    "$CACHE_DIR/opentofu/tofu" "$@")
}

# tofu_findings TREE BOUNDARY — tofu init, then tofu validate, on the terraform
# root BOUNDARY holds, in a scratch copy of it, so nothing either writes lands in
# BOUNDARY; prints its findings attributed through TREE's catalog.
# shellcheck disable=SC2329 # called by name, as a fixture's check calls it
tofu_findings() {
  local tree="$1" boundary="$2" work init=0 validate=-
  [ -d "$boundary/terraform" ] || return 0
  [ -f "$boundary/terraform/aggrega.modules.tf" ] ||
    no_verdict "$boundary/terraform holds no aggrega.modules.tf, the root configuration the terraform provider renders, so tofu has no root to validate"
  tofu_config
  work="$(mktemp -d "$TMP/tofu.XXXXXX")" || no_verdict "cannot make a directory in $TMP"
  cp -R -- "$boundary/terraform" "$work/terraform" || no_verdict "cannot copy $boundary/terraform to $work"
  tofu_run "$work" init -backend=false -input=false -json >"$work/init.json" 2>"$work/init.err" || init=$?
  if [ "$init" -eq 0 ]; then
    validate=0
    tofu_run "$work" validate -json >"$work/validate.json" 2>"$work/validate.err" || validate=$?
  fi
  read_findings "$tree" terraform tofu "$boundary" "$work" "$init" "$validate"
}

# cfn_lint_findings TREE BOUNDARY — cfn-lint, configured by TREE's .cfnlintrc.yaml
# alone, on a copy of the stack template BOUNDARY holds with the template's own
# cfn-lint configuration set aside (PY_CFN_LINT_COPY), each key set aside named on
# standard error; prints its findings attributed through TREE's catalog.
# shellcheck disable=SC2329 # called by name, as a fixture's check calls it
cfn_lint_findings() {
  local tree="$1" boundary="$2" template="cloudformation/cloudformation-stack.json" work set_aside key rc=0 lines=1
  [ -d "$boundary/cloudformation" ] || return 0
  [ -f "$boundary/$template" ] ||
    no_verdict "$boundary/cloudformation holds no cloudformation-stack.json, the stack template the cloudformation provider renders, so cfn-lint has no template to lint"
  # cfn-lint reads a configuration file that is not there as an empty one.
  [ -f "$tree/.cfnlintrc.yaml" ] ||
    no_verdict "$tree/.cfnlintrc.yaml is missing, and cfn-lint reads its rules from it; restore it from git"
  work="$(mktemp -d "$TMP/cfn-lint.XXXXXX")" || no_verdict "cannot make a directory in $TMP"
  mkdir -p "$work/cloudformation" || no_verdict "cannot make a directory in $work"
  set_aside="$(python3 -I -c "$PY_CFN_LINT_COPY" "$boundary/$template" "$work/$template")" ||
    no_verdict "cannot copy $boundary/$template to $work for cfn-lint"
  if [ -n "$set_aside" ]; then
    lines=0
    while IFS= read -r key; do
      printf '  set aside  %s\t%s\n' "$key" "cfn-lint's own configuration, written in $boundary/$template: cfn-lint takes its rules from .cfnlintrc.yaml alone, so the copy it reads carries none of it" >&2
    done <<<"$set_aside"
  fi
  (cd -- "$work" && env -i PATH="$PATH" HOME="$work" LANG=C.UTF-8 PYTHONUTF8=1 \
    "$CACHE_DIR/venv/bin/cfn-lint" --config-file "$tree/.cfnlintrc.yaml" --non-zero-exit-code warning \
    --regions us-east-1 --format json -- "$template") >"$work/cfn-lint.json" 2>"$work/cfn-lint.err" || rc=$?
  [ -s "$work/cfn-lint.json" ] ||
    no_verdict "cfn-lint gave no reading of $boundary/$template (exit $rc): $(tail -n 3 "$work/cfn-lint.err" | tr '\n' ' ')"
  read_findings "$tree" cloudformation cfn-lint "$boundary" "$template" "$work/cfn-lint.json" "$rc" "$lines"
}

# arm_findings TREE BOUNDARY — the Azure Resource Manager check on the template
# BOUNDARY holds; prints its findings attributed through TREE's catalog.
# shellcheck disable=SC2329 # called by name, as a fixture's check calls it
arm_findings() {
  local tree="$1" boundary="$2" template="arm/arm-template.json" work rc=0
  [ -d "$boundary/arm" ] || return 0
  [ -f "$boundary/$template" ] ||
    no_verdict "$boundary/arm holds no arm-template.json, the template the arm provider renders, so the Azure Resource Manager check has no template to read"
  work="$(mktemp -d "$TMP/arm.XXXXXX")" || no_verdict "cannot make a directory in $TMP"
  arm_check "$boundary" "$template" >"$work/arm.out" 2>"$work/arm.err" || rc=$?
  case "$rc" in
    0 | 1) ;;
    *) no_verdict "the Azure Resource Manager check gives no verdict on $boundary/$template (exit $rc): $(tail -n 3 "$work/arm.err" | tr '\n' ' ')" ;;
  esac
  read_findings "$tree" arm arm "$boundary" "$template" "$work/arm.out" "$rc"
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
  st_cfnlintrc_reason_missing
  st_cfnlintrc_flow_list
  st_cfnlintrc_reasons_given
  st_unprimed
  st_primed_for_another_pin_file
  st_cached_tofu_other_version
  st_cached_cfn_lint_other_version
  st_tofu_on_path_unused
  st_binary_missing
  st_binary_below_minimum
  st_binary_between_releases
  st_validators_answer_pins
  st_arm_clean
  st_arm_wrong_type
  st_arm_wrong_type_nested
  st_arm_resource_key_misspelt
  st_arm_template_section_unknown
  st_arm_api_version_uncovered
  st_arm_property_misspelt
  st_arm_composed_clean
  st_arm_schemas_missing
  st_arm_template_absolute
  st_arm_template_escaping
  st_tofu_unsupported_argument
  st_tofu_registry_module
  st_tofu_provider_not_mirrored
  st_tofu_warning_printed
  st_tofu_id_stable
  st_cfn_lint_invalid_property
  st_cfn_lint_unattributed
  st_cfn_lint_ambiguous
  st_cfn_lint_id_stable
  st_cfn_lint_resource_ignore
  st_cfn_lint_template_ignore
  st_arm_boundary_attributed
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
# directory, this repository's .cfnlintrc.yaml and a terraform container Recipe
# carrying the canonical pass-through, all committed.
# shellcheck disable=SC2329 # called from the cases, which run by name from ST_CASES
st_repo() {
  ST_N=$((ST_N + 1))
  ST_REPO="$ST_ROOT/repo-$ST_N"
  local recipe="$ST_REPO/$ST_RECIPE"
  mkdir -p "$recipe/module" &&
    cp -R "$HERE" "$ST_REPO/scripts" &&
    cp "$TOP/.cfnlintrc.yaml" "$ST_REPO/.cfnlintrc.yaml" &&
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

# st_cfnlintrc LINE... — writes .cfnlintrc.yaml in ST_REPO from the lines given,
# and stages it.
# shellcheck disable=SC2329 # called from the cases, which run by name from ST_CASES
st_cfnlintrc() {
  printf '%s\n' "$@" >"$ST_REPO/.cfnlintrc.yaml" && git -C "$ST_REPO" add -- .cfnlintrc.yaml
}

# shellcheck disable=SC2329 # a case, run by name from ST_CASES
st_cfnlintrc_reason_missing() {
  { st_repo && st_cfnlintrc "# cfn-lint's configuration." "ignore_checks:" "  - E3012"; } ||
    { st_broken "stage .cfnlintrc.yaml"; return; }
  st_run --all
  st_caught "a rule ignored in .cfnlintrc.yaml with no reason beside it" 1 ".cfnlintrc.yaml:3:" "E3012"
}

# shellcheck disable=SC2329 # a case, run by name from ST_CASES
st_cfnlintrc_flow_list() {
  { st_repo && st_cfnlintrc "ignore_checks: [E3012]"; } || { st_broken "stage .cfnlintrc.yaml"; return; }
  st_run --all
  st_caught "rules ignored in .cfnlintrc.yaml as a list on one line, with no line for a reason" 1 \
    ".cfnlintrc.yaml:1:" "E3012"
}

# shellcheck disable=SC2329 # a case, run by name from ST_CASES
st_cfnlintrc_reasons_given() {
  local home="$ST_ROOT/home-$((ST_N + 1))"
  { st_repo && st_cache "$home" "$PIN_TOFU_VERSION" "${PIN_PYTHON[cfn-lint]}" &&
    st_cfnlintrc "ignore_checks:" "  # The reason W3011 is ignored, on the line above." "  - W3011" \
      "  - E3012  # The reason E3012 is ignored, beside it."; } || { st_broken "stage .cfnlintrc.yaml"; return; }
  st_run --all HOME="$home" AGGREGA_BIN="$ST_ROOT/bin/aggrega-at-minimum"
  st_passed "rules ignored in .cfnlintrc.yaml, each with its reason on the line above or beside it"
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

# The Azure Resource Manager check, run by arm_check: the cache's Python over the
# cache's schemas. A negative case plants one fault with sed in a clean template
# and expects that fault's id and no other finding.
ST_ARM_TEMPLATE="arm-template.json"

# st_arm_template FILE — a clean languageVersion 2.0 template: an existing
# environment, a container app reading a neighbour through reference(), a nested
# deployment wrapping a small inline template with enableTelemetry false,
# outputs and metadata. Two of its enum values, single and inner, are written in
# another case than the schemas', and its CPU count is an expression, as Bicep
# writes them.
# shellcheck disable=SC2329 # called from the cases, which run by name from ST_CASES
st_arm_template() {
  cat >"$1" <<'END_OF_TEMPLATE'
{
  "$schema": "https://schema.management.azure.com/schemas/2019-04-01/deploymentTemplate.json#",
  "languageVersion": "2.0",
  "contentVersion": "1.0.0.0",
  "metadata": {
    "description": "A clean template the self-test checks."
  },
  "parameters": {
    "location": {
      "type": "string",
      "defaultValue": "[resourceGroup().location]"
    },
    "environmentName": {
      "type": "string",
      "defaultValue": "example-environment"
    }
  },
  "resources": {
    "environment": {
      "existing": true,
      "type": "Microsoft.App/managedEnvironments",
      "apiVersion": "2025-07-01",
      "name": "[parameters('environmentName')]"
    },
    "worker": {
      "type": "Microsoft.App/containerApps",
      "apiVersion": "2026-01-01",
      "name": "example-worker",
      "location": "[parameters('location')]",
      "properties": {
        "environmentId": "[resourceId('Microsoft.App/managedEnvironments', parameters('environmentName'))]",
        "configuration": {
          "activeRevisionsMode": "single"
        },
        "template": {
          "containers": [
            {
              "name": "worker",
              "image": "example.com/worker:1.0.0",
              "resources": {
                "cpu": "[json('0.25')]",
                "memory": "0.5Gi"
              }
            }
          ]
        }
      }
    },
    "api": {
      "type": "Microsoft.App/containerApps",
      "apiVersion": "2026-01-01",
      "name": "example-api",
      "location": "[parameters('location')]",
      "dependsOn": [
        "worker"
      ],
      "properties": {
        "environmentId": "[resourceId('Microsoft.App/managedEnvironments', parameters('environmentName'))]",
        "configuration": {
          "activeRevisionsMode": "single",
          "ingress": {
            "external": true,
            "targetPort": 80,
            "transport": "auto"
          }
        },
        "template": {
          "containers": [
            {
              "name": "api",
              "image": "example.com/api:1.0.0",
              "env": [
                {
                  "name": "WORKER_REVISION",
                  "value": "[reference('worker').latestRevisionName]"
                }
              ]
            }
          ],
          "scale": {
            "minReplicas": 1,
            "maxReplicas": 3
          }
        }
      }
    },
    "module": {
      "type": "Microsoft.Resources/deployments",
      "apiVersion": "2025-04-01",
      "name": "example-module",
      "metadata": {
        "aggrega.ai/provenance": {
          "aggrega.ai/recipe-uri": "example-app:1.0.0"
        }
      },
      "properties": {
        "expressionEvaluationOptions": {
          "scope": "inner"
        },
        "mode": "Incremental",
        "parameters": {
          "name": {
            "value": "example-app"
          },
          "location": {
            "value": "[parameters('location')]"
          },
          "environmentResourceId": {
            "value": "[resourceId('Microsoft.App/managedEnvironments', parameters('environmentName'))]"
          },
          "enableTelemetry": {
            "value": false
          }
        },
        "template": {
          "$schema": "https://schema.management.azure.com/schemas/2019-04-01/deploymentTemplate.json#",
          "languageVersion": "2.0",
          "contentVersion": "1.0.0.0",
          "parameters": {
            "name": {
              "type": "string"
            },
            "location": {
              "type": "string"
            },
            "environmentResourceId": {
              "type": "string"
            },
            "enableTelemetry": {
              "type": "bool",
              "defaultValue": true
            }
          },
          "resources": {
            "app": {
              "type": "Microsoft.App/containerApps",
              "apiVersion": "2026-01-01",
              "name": "[parameters('name')]",
              "location": "[parameters('location')]",
              "properties": {
                "environmentId": "[parameters('environmentResourceId')]",
                "configuration": {
                  "ingress": {
                    "external": false,
                    "targetPort": 8080,
                    "transport": "http"
                  }
                },
                "template": {
                  "containers": [
                    {
                      "name": "app",
                      "image": "example.com/app:1.0.0"
                    }
                  ]
                }
              }
            }
          },
          "outputs": {
            "fqdn": {
              "type": "string",
              "value": "[reference('app').configuration.ingress.fqdn]"
            }
          }
        }
      }
    }
  },
  "outputs": {
    "apiFqdn": {
      "type": "string",
      "value": "[reference('api').configuration.ingress.fqdn]"
    },
    "appFqdn": {
      "type": "string",
      "value": "[reference('module').outputs.fqdn.value]"
    }
  }
}
END_OF_TEMPLATE
}

# st_arm_composed_template FILE — a clean template whose one resource's
# properties object is composed from several schemas through allOf: one lists
# componentType and configurations, and each alternative of a union pairs a
# component's schema with one listing componentType alone. Its name is a
# format() expression, as Bicep writes a child resource's name.
# shellcheck disable=SC2329 # called from the cases, which run by name from ST_CASES
st_arm_composed_template() {
  cat >"$1" <<'END_OF_TEMPLATE'
{
  "$schema": "https://schema.management.azure.com/schemas/2019-04-01/deploymentTemplate.json#",
  "languageVersion": "2.0",
  "contentVersion": "1.0.0.0",
  "resources": {
    "admin": {
      "type": "Microsoft.App/managedEnvironments/javaComponents",
      "apiVersion": "2026-01-01",
      "name": "[format('{0}/{1}', 'example-environment', 'example-admin')]",
      "properties": {
        "componentType": "SpringBootAdmin",
        "configurations": [
          {
            "propertyName": "spring.boot.admin.ui.title",
            "value": "Example"
          }
        ]
      }
    }
  }
}
END_OF_TEMPLATE
}

# st_arm_run WRITER [SED_SCRIPT] — writes a template with WRITER into a
# directory of its own, applies SED_SCRIPT to it, and runs the check on it
# there; ST_RC and ST_OUT get its exit status and everything it printed.
# shellcheck disable=SC2329 # called from the cases, which run by name from ST_CASES
st_arm_run() {
  ST_N=$((ST_N + 1))
  local dir="$ST_ROOT/arm-$ST_N"
  { mkdir -p "$dir" && "$1" "$dir/$ST_ARM_TEMPLATE"; } || return 1
  if [ -n "${2:-}" ]; then sed -i "$2" "$dir/$ST_ARM_TEMPLATE" || return 1; fi
  ST_RC=0
  ST_OUT="$(arm_check "$dir" "$ST_ARM_TEMPLATE" 2>&1)" || ST_RC=$?
}

# st_arm_caught LABEL ID — the run found exactly one finding, the one named ID.
# shellcheck disable=SC2329 # called from the cases, which run by name from ST_CASES
st_arm_caught() {
  st_caught "$1" 1 "$2" $'\n'"1 finding(s)"
}

# shellcheck disable=SC2329 # a case, run by name from ST_CASES
st_arm_clean() {
  st_arm_run st_arm_template || { st_broken "write a template"; return; }
  st_passed "a clean languageVersion 2.0 template: an existing environment, a container app reading a neighbour through reference(), a nested deployment with telemetry off, outputs, metadata"
}

# shellcheck disable=SC2329 # a case, run by name from ST_CASES
st_arm_wrong_type() {
  st_arm_run st_arm_template 's/"targetPort": 80,/"targetPort": "eighty",/' || { st_broken "write a template"; return; }
  st_arm_caught "a literal of the wrong type in a resource (targetPort \"eighty\")" \
    "arm|type|$ST_ARM_TEMPLATE/api/properties/configuration/ingress/targetPort"
}

# shellcheck disable=SC2329 # a case, run by name from ST_CASES
st_arm_wrong_type_nested() {
  st_arm_run st_arm_template 's/"targetPort": 8080,/"targetPort": "eighty",/' || { st_broken "write a template"; return; }
  st_arm_caught "a literal of the wrong type inside a nested deployment's template" \
    "arm|type|$ST_ARM_TEMPLATE/module/properties/template/resources/app/properties/configuration/ingress/targetPort"
}

# shellcheck disable=SC2329 # a case, run by name from ST_CASES
st_arm_resource_key_misspelt() {
  st_arm_run st_arm_template 's/"dependsOn"/"dependOn"/' || { st_broken "write a template"; return; }
  st_arm_caught "a misspelt resource key (dependOn)" "arm|resource-key|$ST_ARM_TEMPLATE/api/dependOn"
}

# shellcheck disable=SC2329 # a case, run by name from ST_CASES
st_arm_template_section_unknown() {
  st_arm_run st_arm_template '0,/"contentVersion": "1.0.0.0",/s//&\n  "output": {},/' || { st_broken "write a template"; return; }
  st_arm_caught "a template section outside the documented ones" "arm|template-key|$ST_ARM_TEMPLATE/output"
}

# The worker's apiVersion is the first one written as 2026-01-01.
# shellcheck disable=SC2329 # a case, run by name from ST_CASES
st_arm_api_version_uncovered() {
  st_arm_run st_arm_template '0,/"apiVersion": "2026-01-01"/s//"apiVersion": "2026-01-03"/' || { st_broken "write a template"; return; }
  st_arm_caught "an apiVersion the pinned schemas lack" "arm|no-schema|$ST_ARM_TEMPLATE/worker/apiVersion"
}

# The api's ingress is the first one written.
# shellcheck disable=SC2329 # a case, run by name from ST_CASES
st_arm_property_misspelt() {
  st_arm_run st_arm_template '0,/"ingress": {/s//"ingresss": {/' || { st_broken "write a template"; return; }
  st_arm_caught "a misspelt property (ingresss)" \
    "arm|additionalProperties|$ST_ARM_TEMPLATE/api/properties/configuration/ingresss"
}

# The closed reading spans the composition: read one schema at a time, the
# schema listing componentType alone would refuse configurations.
# shellcheck disable=SC2329 # a case, run by name from ST_CASES
st_arm_composed_clean() {
  st_arm_run st_arm_composed_template || { st_broken "write a template"; return; }
  st_passed "a type composed from several schemas through allOf, its properties listed across them"
}

# shellcheck disable=SC2329 # a case, run by name from ST_CASES
st_arm_schemas_missing() {
  local dir="$ST_ROOT/arm-no-schemas"
  { mkdir -p "$dir" && st_arm_template "$dir/$ST_ARM_TEMPLATE"; } || { st_broken "write a template"; return; }
  ST_RC=0
  ST_OUT="$(cd -- "$dir" && "$CACHE_DIR/venv/bin/python" -I "$HERE/vendor-validate-arm.py" \
    "$dir/no-schemas" "$ST_ARM_TEMPLATE" 2>&1)" || ST_RC=$?
  st_caught "the Azure Resource Manager check with no schemas in the cache" 3 "$PRIME_CMD"
}

# shellcheck disable=SC2329 # a case, run by name from ST_CASES
st_arm_template_absolute() {
  ST_N=$((ST_N + 1))
  local dir="$ST_ROOT/arm-$ST_N"
  { mkdir -p "$dir" && st_arm_template "$dir/$ST_ARM_TEMPLATE"; } || { st_broken "write a template"; return; }
  ST_RC=0
  ST_OUT="$(arm_check "$dir" "$dir/$ST_ARM_TEMPLATE" 2>&1)" || ST_RC=$?
  st_caught "a template named by an absolute path, which a finding's id would carry" 2 \
    "$dir/$ST_ARM_TEMPLATE" "relative to"
}

# shellcheck disable=SC2329 # a case, run by name from ST_CASES
st_arm_template_escaping() {
  ST_N=$((ST_N + 1))
  local dir="$ST_ROOT/arm-$ST_N"
  { mkdir -p "$dir/run" && st_arm_template "$dir/$ST_ARM_TEMPLATE"; } || { st_broken "write a template"; return; }
  ST_RC=0
  ST_OUT="$(arm_check "$dir/run" "../$ST_ARM_TEMPLATE" 2>&1)" || ST_RC=$?
  st_caught "a template named by a path leading out of the directory the check runs in" 2 \
    "../$ST_ARM_TEMPLATE" "relative to"
}

# The validators over a rendered boundary, run as a fixture's check runs them:
# tofu_findings, cfn_lint_findings or arm_findings on a tree holding a catalog
# and .cfnlintrc.yaml, and a boundary holding one root. A negative case plants
# one fault in a clean root and expects that fault's id, attributed to the entity
# version whose provenance the root carries, and no other finding.

# st_tree — ST_TREE, the tree every boundary case reads: a catalog holding the
# entity versions the planted roots' provenance names, probe-twice twice over,
# and this repository's .cfnlintrc.yaml, copied last. Made once.
# shellcheck disable=SC2329 # called from the cases, which run by name from ST_CASES
st_tree() {
  ST_TREE="$ST_ROOT/tree"
  [ ! -f "$ST_TREE/.cfnlintrc.yaml" ] || return 0
  local c="$ST_TREE/$CATALOG_ROOT"
  mkdir -p "$c/recipe/terraform/probe-app/1.0.0" "$c/feature-recipe/terraform/probe-password/1.0.0" \
    "$c/recipe/cloudformation/probe-queue/1.0.0" "$c/recipe/arm/example-app/1.0.0" \
    "$c/recipe/cloudformation/probe-twice/1.0.0" "$c/feature-recipe/cloudformation/probe-twice/1.0.0" &&
    st_entity Recipe probe-app terraform >"$c/recipe/terraform/probe-app/1.0.0/recipe.yaml" &&
    st_entity FeatureRecipe probe-password terraform >"$c/feature-recipe/terraform/probe-password/1.0.0/recipe.yaml" &&
    st_entity Recipe probe-queue cloudformation >"$c/recipe/cloudformation/probe-queue/1.0.0/recipe.yaml" &&
    st_entity Recipe example-app arm >"$c/recipe/arm/example-app/1.0.0/recipe.yaml" &&
    st_entity Recipe probe-twice cloudformation >"$c/recipe/cloudformation/probe-twice/1.0.0/recipe.yaml" &&
    st_entity FeatureRecipe probe-twice cloudformation >"$c/feature-recipe/cloudformation/probe-twice/1.0.0/recipe.yaml" &&
    cp "$TOP/.cfnlintrc.yaml" "$ST_TREE/.cfnlintrc.yaml"
}

# st_entity KIND NAME CAPABILITY — an entity's YAML at version 1.0.0.
# shellcheck disable=SC2329 # called from the cases, which run by name from ST_CASES
st_entity() {
  printf '%s\n' "apiVersion: aggrega.ai/v1beta1" "kind: $1" "metadata:" "  name: $2" "  version: 1.0.0" \
    "spec:" "  capability: $3"
}

# st_boundary — ST_BOUNDARY, an empty boundary directory of the case's own.
# shellcheck disable=SC2329 # called from the cases, which run by name from ST_CASES
st_boundary() {
  ST_N=$((ST_N + 1))
  ST_BOUNDARY="$ST_ROOT/boundary-$ST_N"
  mkdir -p "$ST_BOUNDARY"
}

# st_tf_root BOUNDARY — a clean terraform root as the terraform provider renders
# one: aggrega.modules.tf calling a source: Recipe's module, which carries
# aggrega.provenance.tf, and a FeatureRecipe's, whose file opens with the
# provenance header. Both use hashicorp/random, which the mirror holds.
# shellcheck disable=SC2329 # called from the cases, which run by name from ST_CASES
st_tf_root() {
  local root="$1/terraform"
  mkdir -p "$root/modules/app" "$root/modules/app--password" || return 1
  cat >"$root/aggrega.modules.tf" <<'END_OF_ROOT' &&
# The root configuration the self-test validates.

module "app--password" {
  source = "./modules/app--password"
}

module "app" {
  source = "./modules/app"

  password = module.app--password.value
}
END_OF_ROOT
    cat >"$root/modules/app/aggrega.provenance.tf" <<'END_OF_PROVENANCE' &&
# Aggrega build provenance
# aggrega.ai/component-id: app
# aggrega.ai/provider: terraform
# aggrega.ai/recipe-uri: probe-app:1.0.0
END_OF_PROVENANCE
    cat >"$root/modules/app/main.tf" <<'END_OF_MODULE' &&
terraform {
  required_providers {
    random = {
      source = "hashicorp/random"
    }
  }
}

variable "password" {
  type      = string
  sensitive = true
}

resource "random_id" "app" {
  byte_length = 8
}

output "id" {
  value = random_id.app.hex
}
END_OF_MODULE
    cat >"$root/modules/app--password/random-password.tf" <<'END_OF_MODULE'
# Aggrega build provenance
# aggrega.ai/component-id: cfr--app--password
# aggrega.ai/provider: terraform
# aggrega.ai/recipe-uri: probe-password:1.0.0
resource "random_password" "app_password" {
  length  = 16
  special = false
}

output "value" {
  value     = random_password.app_password.result
  sensitive = true
}
END_OF_MODULE
}

# st_cfn_stack BOUNDARY — a clean stack template as the cloudformation provider
# renders one, its resource carrying the provenance metadata.
# shellcheck disable=SC2329 # called from the cases, which run by name from ST_CASES
st_cfn_stack() {
  mkdir -p "$1/cloudformation" || return 1
  cat >"$1/cloudformation/cloudformation-stack.json" <<'END_OF_TEMPLATE'
{
  "AWSTemplateFormatVersion": "2010-09-09",
  "Resources": {
    "Queue": {
      "Type": "AWS::SQS::Queue",
      "Metadata": {
        "aggrega.ai/provenance": {
          "aggrega.ai/component-id": "queue",
          "aggrega.ai/provider": "cloudformation",
          "aggrega.ai/recipe-uri": "probe-queue:1.0.0"
        }
      },
      "Properties": {
        "QueueName": "example-queue",
        "VisibilityTimeout": 30
      }
    }
  },
  "Outputs": {
    "QueueUrl": {
      "Value": {
        "Ref": "Queue"
      }
    }
  }
}
END_OF_TEMPLATE
}

# st_findings RUNNER — runs RUNNER on ST_TREE and ST_BOUNDARY; ST_RC, ST_OUT and
# ST_ERR get its exit status, its standard output and its standard error.
# shellcheck disable=SC2329 # called from the cases, which run by name from ST_CASES
st_findings() {
  ST_RC=0
  ST_OUT="$("$1" "$ST_TREE" "$ST_BOUNDARY" 2>"$ST_ROOT/stderr")" || ST_RC=$?
  ST_ERR="$(cat "$ST_ROOT/stderr")"
}

# st_ids — each finding ST_OUT holds, without its message.
# shellcheck disable=SC2329 # called from the cases, which run by name from ST_CASES
st_ids() {
  printf '%s\n' "$ST_OUT" | cut -f1,2
}

# st_found LABEL ID ATTRIBUTION — the run exited 1 with exactly one finding: ID,
# attributed to ATTRIBUTION.
# shellcheck disable=SC2329 # called from the cases, which run by name from ST_CASES
st_found() {
  local want="$2"$'\t'"$3"$'\t'
  if [ "$ST_RC" -eq 1 ] && [[ $ST_OUT != *$'\n'* ]] && [ "${ST_OUT#"$want"}" != "$ST_OUT" ]; then
    printf '  caught  %s\n' "$1"
    return
  fi
  ST_OUT="$ST_OUT${ST_ERR:+$'\n'$ST_ERR}"
  st_failed "$1" "exit 1 and the one finding $2, attributed to $3"
}

# shellcheck disable=SC2329 # a case, run by name from ST_CASES
st_tofu_unsupported_argument() {
  { st_tree && st_boundary && st_tf_root "$ST_BOUNDARY" &&
    sed -i 's/^  byte_length = 8$/&\n  no_such_attribute = 1/' "$ST_BOUNDARY/terraform/modules/app/main.tf"; } ||
    { st_broken "write a terraform root"; return; }
  st_findings tofu_findings
  st_found "an unsupported argument in a terraform root, caught by tofu" \
    'tofu|Unsupported argument|terraform/modules/app/main.tf/resource "random_id" "app"/no_such_attribute' \
    "recipe/terraform/probe-app@1.0.0"
}

# shellcheck disable=SC2329 # a case, run by name from ST_CASES
st_tofu_registry_module() {
  { st_tree && st_boundary && st_tf_root "$ST_BOUNDARY" &&
    printf '\nmodule "vpc" {\n  source  = "terraform-aws-modules/vpc/aws"\n  version = "6.0.0"\n}\n' \
      >>"$ST_BOUNDARY/terraform/modules/app/main.tf"; } || { st_broken "write a terraform root"; return; }
  st_findings tofu_findings
  st_found "a module called from a registry: a finding of tofu init naming the module, with no network" \
    "tofu|Error accessing remote module registry|terraform/modules/app/main.tf/vpc" \
    "recipe/terraform/probe-app@1.0.0"
}

# A finding with no file names no provenance, so it is attributed to none.
# shellcheck disable=SC2329 # a case, run by name from ST_CASES
st_tofu_provider_not_mirrored() {
  { st_tree && st_boundary && st_tf_root "$ST_BOUNDARY" &&
    printf '\nresource "nosuch_thing" "app" {}\n' >>"$ST_BOUNDARY/terraform/modules/app/main.tf"; } ||
    { st_broken "write a terraform root"; return; }
  st_findings tofu_findings
  st_found "a provider the mirror lacks: a finding of tofu init naming the provider" \
    "tofu|Failed to query available provider packages|hashicorp/nosuch" "-"
}

# shellcheck disable=SC2329 # a case, run by name from ST_CASES
st_tofu_warning_printed() {
  { st_tree && st_boundary && st_tf_root "$ST_BOUNDARY" &&
    sed -i 's/^  special = false$/&\n  number  = true/' "$ST_BOUNDARY/terraform/modules/app--password/random-password.tf"; } ||
    { st_broken "write a terraform root"; return; }
  st_findings tofu_findings
  if [ "$ST_RC" -eq 0 ] && [ -z "$ST_OUT" ] && [[ $ST_ERR == *"Attribute Deprecated"* ]]; then
    printf '  passed  %s\n' "a deprecated argument: tofu's warning printed, refusing nothing"
    return
  fi
  ST_OUT="$ST_OUT${ST_ERR:+$'\n'$ST_ERR}"
  st_failed "a deprecated argument: tofu's warning printed, refusing nothing" "exit 0, no finding, the warning printed"
}

# Two runs, then a block written above the fault: the id holds, while the
# message, which names the line, moves with it.
# shellcheck disable=SC2329 # a case, run by name from ST_CASES
st_tofu_id_stable() {
  local file first first_ids second_ids label="the same tofu finding's id across two runs and after a block moves it down"
  { st_tree && st_boundary && st_tf_root "$ST_BOUNDARY" &&
    file="$ST_BOUNDARY/terraform/modules/app--password/random-password.tf" &&
    sed -i 's/^  length  = 16$/&\n  no_such_attribute = 1/' "$file"; } || { st_broken "write a terraform root"; return; }
  st_findings tofu_findings
  first="$ST_OUT"
  first_ids="$(st_ids)"
  st_findings tofu_findings
  second_ids="$(st_ids)"
  sed -i 's/^resource "random_password"/locals {\n  moved = true\n}\n\n&/' "$file" || { st_broken "move a line"; return; }
  st_findings tofu_findings
  if [ "$second_ids" != "$first_ids" ] || [ "$(st_ids)" != "$first_ids" ] || [ "$ST_OUT" = "$first" ]; then
    ST_RC=-1
    ST_OUT="first run: $first"$'\n'"second run: $second_ids"$'\n'"after the move: $ST_OUT"
    st_failed "$label" "one id from every run, and a message naming the moved line"
    return
  fi
  st_found "$label" \
    'tofu|Unsupported argument|terraform/modules/app--password/random-password.tf/resource "random_password" "app_password"/no_such_attribute' \
    "featurerecipe/terraform/probe-password@1.0.0"
}

# shellcheck disable=SC2329 # a case, run by name from ST_CASES
st_cfn_lint_invalid_property() {
  { st_tree && st_boundary && st_cfn_stack "$ST_BOUNDARY" &&
    sed -i 's/"VisibilityTimeout": 30/"VisibilityTimeoutt": 30/' "$ST_BOUNDARY/cloudformation/cloudformation-stack.json"; } ||
    { st_broken "write a stack template"; return; }
  st_findings cfn_lint_findings
  st_found "an invalid property in a stack template, caught by cfn-lint" \
    "cfn-lint|E3002|Resources/Queue/Properties/VisibilityTimeoutt" "recipe/cloudformation/probe-queue@1.0.0"
}

# The resource's provenance names an entity version the catalog does not hold.
# shellcheck disable=SC2329 # a case, run by name from ST_CASES
st_cfn_lint_unattributed() {
  { st_tree && st_boundary && st_cfn_stack "$ST_BOUNDARY" &&
    sed -i -e 's/"VisibilityTimeout": 30/"VisibilityTimeoutt": 30/' -e 's/probe-queue:1.0.0/probe-unknown:1.0.0/' \
      "$ST_BOUNDARY/cloudformation/cloudformation-stack.json"; } || { st_broken "write a stack template"; return; }
  st_findings cfn_lint_findings
  st_found "a finding whose provenance names no entity the catalog holds, attributed to none" \
    "cfn-lint|E3002|Resources/Queue/Properties/VisibilityTimeoutt" "-"
}

# The resource's provenance names a Recipe and a FeatureRecipe at one capability,
# name and version.
# shellcheck disable=SC2329 # a case, run by name from ST_CASES
st_cfn_lint_ambiguous() {
  { st_tree && st_boundary && st_cfn_stack "$ST_BOUNDARY" &&
    sed -i -e 's/"VisibilityTimeout": 30/"VisibilityTimeoutt": 30/' -e 's/probe-queue:1.0.0/probe-twice:1.0.0/' \
      "$ST_BOUNDARY/cloudformation/cloudformation-stack.json"; } || { st_broken "write a stack template"; return; }
  st_findings cfn_lint_findings
  st_found "a finding whose provenance names two entities the catalog holds, attributed to none" \
    "cfn-lint|E3002|Resources/Queue/Properties/VisibilityTimeoutt" "-"
}

# shellcheck disable=SC2329 # a case, run by name from ST_CASES
st_cfn_lint_id_stable() {
  local file first first_ids second_ids label="the same cfn-lint finding's id across two runs and after a line moves it down"
  { st_tree && st_boundary && st_cfn_stack "$ST_BOUNDARY" &&
    file="$ST_BOUNDARY/cloudformation/cloudformation-stack.json" &&
    sed -i 's/"VisibilityTimeout": 30/"VisibilityTimeout": "thirty"/' "$file"; } || { st_broken "write a stack template"; return; }
  st_findings cfn_lint_findings
  first="$ST_OUT"
  first_ids="$(st_ids)"
  st_findings cfn_lint_findings
  second_ids="$(st_ids)"
  sed -i 's/^  "AWSTemplateFormatVersion": "2010-09-09",$/&\n  "Description": "A stack the self-test lints.",/' "$file" ||
    { st_broken "move a line"; return; }
  st_findings cfn_lint_findings
  if [ "$second_ids" != "$first_ids" ] || [ "$(st_ids)" != "$first_ids" ] || [ "$ST_OUT" = "$first" ]; then
    ST_RC=-1
    ST_OUT="first run: $first"$'\n'"second run: $second_ids"$'\n'"after the move: $ST_OUT"
    st_failed "$label" "one id from every run, and a message naming the moved line"
    return
  fi
  st_found "$label" "cfn-lint|E3012|Resources/Queue/Properties/VisibilityTimeout" "recipe/cloudformation/probe-queue@1.0.0"
}

# The resource's own Metadata asks cfn-lint to ignore the rule its fault breaks.
# shellcheck disable=SC2329 # a case, run by name from ST_CASES
st_cfn_lint_resource_ignore() {
  { st_tree && st_boundary && st_cfn_stack "$ST_BOUNDARY" &&
    sed -i -e 's/"VisibilityTimeout": 30/"VisibilityTimeout": "thirty"/' \
      -e 's/^      "Metadata": {$/&\n        "cfn-lint": {\n          "config": {\n            "ignore_checks": ["E3012"]\n          }\n        },/' \
      "$ST_BOUNDARY/cloudformation/cloudformation-stack.json"; } || { st_broken "write a stack template"; return; }
  st_findings cfn_lint_findings
  st_found "a fault whose resource's own Metadata tells cfn-lint to ignore its rule, caught all the same" \
    "cfn-lint|E3012|Resources/Queue/Properties/VisibilityTimeout" "recipe/cloudformation/probe-queue@1.0.0"
}

# The template's own Metadata asks cfn-lint to ignore the rule its fault breaks.
# shellcheck disable=SC2329 # a case, run by name from ST_CASES
st_cfn_lint_template_ignore() {
  { st_tree && st_boundary && st_cfn_stack "$ST_BOUNDARY" &&
    sed -i -e 's/"VisibilityTimeout": 30/"VisibilityTimeout": "thirty"/' \
      -e 's/^  "AWSTemplateFormatVersion": "2010-09-09",$/&\n  "Metadata": {\n    "cfn-lint": {\n      "config": {\n        "ignore_checks": ["E3012"]\n      }\n    }\n  },/' \
      "$ST_BOUNDARY/cloudformation/cloudformation-stack.json"; } || { st_broken "write a stack template"; return; }
  st_findings cfn_lint_findings
  st_found "a fault whose template's own Metadata tells cfn-lint to ignore its rule, caught all the same" \
    "cfn-lint|E3012|Resources/Queue/Properties/VisibilityTimeout" "recipe/cloudformation/probe-queue@1.0.0"
}

# The fault lies inside the nested deployment, whose metadata carries the
# provenance.
# shellcheck disable=SC2329 # a case, run by name from ST_CASES
st_arm_boundary_attributed() {
  { st_tree && st_boundary && mkdir -p "$ST_BOUNDARY/arm" && st_arm_template "$ST_BOUNDARY/arm/arm-template.json" &&
    sed -i 's/"targetPort": 8080,/"targetPort": "eighty",/' "$ST_BOUNDARY/arm/arm-template.json"; } ||
    { st_broken "write a template"; return; }
  st_findings arm_findings
  st_found "a fault in a rendered Azure Resource Manager template, attributed through its nested deployment's metadata" \
    "arm|type|arm/arm-template.json/module/properties/template/resources/app/properties/configuration/ingress/targetPort" \
    "recipe/arm/example-app@1.0.0"
}

# --- the run ---------------------------------------------------------------------
case "$MODE" in
  staged | all)
    vendor_text_rule
    pass_through_rule
    [ "$MODE" != all ] || cfnlintrc_rule
    [ "$REFUSED" -eq 0 ] || exit 1
    if [ "$MODE" = all ]; then
      require_validators
      echo "$ME: passed — no vendor text, every container Recipe carries the canonical pass-through, every rule $CFNLINTRC ignores carries its reason, and the validators are primed ($CACHE_DIR)"
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
