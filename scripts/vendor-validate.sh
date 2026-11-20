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
# commit carries: an unstaged fix cannot pass a broken staged file. A fixture is
# built in a copy of the index for the same reason, the selection reads the
# fixtures' locks from the index, and the Azure Resource Manager check runs from
# that copy. The bash that judges cannot run from it: the hook runs this script
# from the checkout, and the script sources its libraries from beside itself. So
# --staged refuses, before any rule runs, while a file of the gate differs from
# the index, and a commit is judged by the gate it carries. --all, a run on
# demand rather than a commit's, runs this script and its libraries as the
# checkout holds them.
#
# THE MARKER IS WRITTEN WHOLE NOWHERE HERE. The vendor-text marker is composed from
# its two parts when the script runs, so no file in this repository carries it and
# the rule needs no exemption for this script.
#
# RULES BEFORE ANY VALIDATOR. The vendor-text rule, the pass-through rule, the
# cfn-lint configuration rule and the fixtures' layout and selection read blobs
# with git and match text with grep and awk, and they run before any validator is
# looked for, so they hold on a machine where nothing is primed. Of them, only
# reading the known-findings file needs python3, which --all does every time and
# --staged when the commit changes that file. A container Recipe, and a rule
# .cfnlintrc.yaml ignores, are recognised by their text rather than by a YAML
# parser for the same reason: a rule depends on no tool the machine may lack.
#
# ONE PIN FILE, ONE CACHE PER PIN FILE. Every version and checksum lives in
# scripts/vendor-validators.json. The cache directory is named by the SHA-256 of
# that file, so a changed pin file finds no cache until it is primed, and a cache
# never answers for a pin file it was not primed from. Nothing outside the cache
# runs as a validator: a tofu or cfn-lint on PATH may be any version. --staged
# and --all name the cache by the pin file the index holds, since that is the
# file the commit carries; --prime and --self-test act on this checkout and read
# the one in the working tree. A pin file changed and not yet staged is primed
# by --prime and required by neither judging form until it is staged.
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
# root it reads when BOUNDARY holds it, and prints nothing and returns 2 when it
# does not, so a caller runs every one on every boundary and counts the roots
# validated: a positive Release none of whose boundaries holds a root would
# otherwise pass with nothing judged. On standard output it prints one line per
# finding, sorted:
#     <id> TAB <attribution> TAB <message>
# the attribution - for none; the message is the validator's, on one line, and
# may name a line number, which the id never does. It returns 0 with no finding
# and 1 with findings. Warnings go to standard error and refuse nothing. A
# validator that cannot give a reading is no verdict: the run exits 3 naming
# why, so a caller that must go on runs the function in a subshell. --help holds
# the ids and the attribution. A caller runs require_validators first.
#
# A FIXTURE IS BUILT AS ITS OWN WORKSPACE, AND ONLY AS THAT. Each Release is
# built in a copy of the index of its own (RELEASES ARE BUILT SIDE BY SIDE),
# with --workspace-root naming the fixture there, an empty global configuration
# (--config) and AGGREGA_CATALOG_DIRS, AGGREGA_WORKSPACE_ROOT and
# AGGREGA_CONFIG unset, so nothing on the machine changes what it resolves: a
# global auto_pull, say, would rewrite the lock in the copy and hide a lock out
# of date. Its sources are the ones aggrega pull fetched into the fixture's
# .aggrega/cache/ in the checkout; the build reaches them through
# AGGREGA_ARTIFACT_CACHE_DIR, which must be relative to the workspace root (an
# absolute value halts the build), so it is that directory named relative to
# the copy. The build reads it and writes nothing there.
#
# RELEASES ARE BUILT SIDE BY SIDE. A build is a process of its own, and two
# builds share nothing either writes but aggrega's per-user caches, which
# aggrega writes under a lock it takes across processes. So the Releases of
# every fixture a run builds are built several at once, through
# scripts/lib/bounded-jobs.sh, and judged one by one in the order a run
# building one at a time takes them, each as soon as it and every one before it
# have ended: the run prints, refuses and exits as that run does, line for line
# but for the seconds. Each build has a tree of its own, a copy of the copy of
# the index whose files are hard links to that copy's, and writes its dist/
# there and nothing else; it writes nothing in the fixture's .aggrega/cache/
# in the checkout. A build keeps 1.1 to 1.2 processing units busy and its
# resident memory peaks at 0.95 to 1.05 GiB, so the run builds two Releases
# for each three processing units nproc counts and one for each 1.5 GiB of
# MemAvailable, leaving the host room for the validators and its other work,
# and twelve at most: on 24 processing units, the Releases of
# proofs/terraform-google/container-service took 144 s built two at a time,
# 47 s eight, 33 s twelve, 29 s sixteen and 38 s twenty-four, so past twelve a
# commit would take the machine from its author for little. Under a bash older
# than 5.1 they are built one at a time. However the run ends, an interrupt
# among the ways, it stops every build still running and waits for each to end
# before removing its temporary directory.
#
# A LOCK IS READ AS TEXT. The selection matches what a commit changes against
# the entities and libraries each fixture's lock records, read with awk in the
# layout aggrega pull writes, so it needs no YAML parser and the rules before any
# validator stay free of tools. A lock from which nothing can be read is
# refused, so a change in that layout fails loudly rather than selecting
# nothing.
#
# A KNOWN FINDING BELONGS TO A PUBLISHED VERSION. A published version is final:
# a finding in it can only be listed, with its reason, and the list only
# shrinks, since an entry whose finding no longer appears is refused as stale.
# A version not yet published can still change, so a finding in it is mended
# and an entry naming it is refused. A finding's id carries names the fixture
# gives, an instance's among them, so two fixtures building one version show
# findings of their own: an entry is judged stale only by a run that built
# every fixture reaching its version.
#
# MEASURED COST, on an amd64 development machine: building the release.yaml of
# proofs/terraform-google/baseline offline with --verify-determinism takes 7 to
# 10 s; tofu init then tofu validate over its root take 0.2 s and 1.1 s, 1.2 to
# 2.6 s with the copy and the reading; the copy of the index takes 0.2 s and
# 22 MB, and a build's own tree linked from it 0.16 s to make and 0.08 s to
# remove. On a machine with 24 processing units and 62 GiB, 34 GiB of it
# available and a one-minute load near 10 from other work, --all built and
# judged 215 Releases in 160 s, twelve at a time; a commit changing the shared
# Terraform and Container Apps libraries, which reaches the container-service
# fixtures of arm, terraform-aws, terraform-azurerm and terraform-google, took
# 132 s through the pre-commit hook. The cache is 3.0 GB, 2.5 GB of it the
# provider mirror, which init links from rather than copies (a root's data
# directory and plugin cache take 0.1 MB). A commit reaching no fixture costs
# the rules alone, under a second.
#
# OFFLINE BY CONSTRUCTION. tofu runs with a CLI configuration naming the cache's
# mirror alone, refusing the module registries registry.opentofu.org and
# registry.terraform.io by name, and with every proxy variable pointing at a
# local port that refuses, so a module source that would reach the network fails
# at once, as a finding naming the module, rather than waiting on it.
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

  --staged     judge the commit being made, as the index holds it, by THE
               GATE'S OWN FILES, VENDOR TEXT, THE CANONICAL PASS-THROUGH and,
               when the commit changes it, THE CFN-LINT CONFIGURATION; then
               build THE FIXTURES the commit reaches (WHAT A COMMIT SELECTS)
               and hold their findings to KNOWN FINDINGS: the form for a
               pre-commit hook.
  --all        judge everything the index holds by VENDOR TEXT, THE
               CANONICAL PASS-THROUGH and THE CFN-LINT CONFIGURATION, then
               build every fixture and hold every finding and every entry
               of KNOWN FINDINGS to each other; an index holding no
               fixture is refused.
  --prime      fetch every validator the pin file names into the cache, verify
               each checksum, and run --self-test against the result. The one
               form that uses the network.
  --self-test  prove, in scratch repositories under a temporary directory,
               that each rule refuses the fault it exists for and passes a
               clean commit, that a missing or mismatched validator or binary
               gives no verdict, that Releases built side by side are
               reported as a run building one at a time reports them, that
               each cached validator answers its pinned version, that the
               Azure Resource Manager check refuses each fault it exists
               for, by its finding id, and passes a clean template, and that
               tofu, cfn-lint and that check, run over a rendered boundary,
               each name a fault planted there by its finding id and the
               entity version it belongs to, the id holding across runs and
               line moves, cfn-lint's even where the template tells cfn-lint
               to ignore its rule. Needs the primed cache.

  It judges the repository it belongs to, wherever it is run from. AGGREGA_BIN
  names the aggrega binary that builds the fixtures (default: aggrega on
  PATH). PUBLISHED_REMOTE names the remote whose published branch is read
  (default: the remote the checked-out branch tracks, else origin).

THE GATE'S OWN FILES (--staged; runs first)
  This script, scripts/vendor-validate-arm.py and the libraries in
  scripts/lib/ it sources are the gate. --staged refuses, naming each, a file
  of the gate whose working tree differs from the index, before any other
  rule runs: bash runs this script and its libraries as the checkout holds
  them, so a change not staged would judge the commit by rules the commit
  does not carry. Stage the change, or undo it. The Azure Resource Manager check runs
  from the copy of the index the fixtures are built in, in --staged and --all
  alike; --all runs this script and its libraries as the checkout holds them
  and refuses nothing for this.

VENDOR TEXT (--staged, --all)
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

  When no published ref has been fetched, every version counts as
  unpublished: this rule then judges all of them, and every entry of KNOWN
  FINDINGS judged is refused as naming an unpublished version. Fetch it:
      git fetch <remote> published

THE CFN-LINT CONFIGURATION (--all; --staged when the commit changes it)
  .cfnlintrc.yaml, at the top of this repository, is the one configuration
  cfn-lint reads, and ignore_checks is the one key it holds: any other key,
  such as ignore_templates, configure_rules or append_rules, changes which
  templates cfn-lint reads, which rules it runs or how they judge, with no
  reason reviewed beside it. Each rule it ignores is a line of its own under
  ignore_checks, - <rule>, with its reason in a comment beside it or on the
  line directly above: what the rule reports, and why a template this catalog
  renders is right to carry it anyway. A line outside that list that is not
  ignore_checks: at the margin, a comment nor blank — another key, a document
  marker or a directive — is refused, naming it; so are an entry with no
  reason, rules written in brackets on the ignore_checks line itself (an
  empty list, [], aside), and a line under ignore_checks that is neither an
  entry, a comment nor blank, each naming the line and the rule; and the
  file's absence from the index. The file is read from the index, as a text,
  with no YAML parser.

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
              --regions us-east-1, and nothing on its standard input. Every
              error and warning is a finding.
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

THE FIXTURES (--staged, --all)
  A fixture is a workspace of its own at proofs/<target>/<group>/, its
  target one of arm, cloudformation, terraform-aws, terraform-azurerm,
  terraform-google and terraform-cloudflare, its group naming what it
  proves: baseline holds one instance of the newest version of each cloud
  Recipe for its target, with a FeatureRecipe attached where a Recipe's
  slot asks for one. It holds:
    .aggrega-config.yaml   workspace.catalog_dirs naming ./catalog first
                           where the fixture carries a catalog of its
                           own, then ../../../aggrega-catalog; and
                           default_registry: hub.aggrega.ai
    its Aggregate and its Manifest
    release.yaml, release-<slug>.yaml
                           its Releases, each beside the lock aggrega
                           pull writes for it, <release>.lock
  A workspace under proofs/ laid out otherwise, a fixture holding no
  Release, and a Release with no lock in the index are refused.

  The sources a lock pins live in the fixture's .aggrega/cache/ in the
  checkout, which git ignores. aggrega pull fills it and writes the lock:
      (cd proofs/<target>/<group> && aggrega pull --release release.yaml)

  A fixture is built in a copy of the index — the catalog, proofs/,
  scripts/ and .cfnlintrc.yaml as the commit carries them — under a
  temporary directory removed when the run exits, so a fix left unstaged
  cannot pass a broken staged file and no build output lands in the
  checkout. Each Release is built in a copy of that copy of its own, its
  files linked rather than copied, with
      aggrega build --offline --verify-determinism
  reading its sources from the checkout's .aggrega/cache/, named to the
  build relative to the copy through AGGREGA_ARTIFACT_CACHE_DIR, and
  writing nothing there; no configuration but the fixture's own reaches
  the build. Releases are built several at once — two for each three
  processing units nproc counts, one for each @BUILD_MIB@ MiB of available
  memory, @BUILD_CEILING@ at most; one at a time under a bash older than 5.1 — and
  each is judged in turn, in the order a run building one at a time takes
  them, so the run prints and decides what that run does. An interrupted
  run stops its builds before removing its temporary directory.

  A Release other than a negative one must build: one that halts is
  refused, naming the fixture, the Release and why; a lock out of date
  (E0130) is refused, naming the pull that renews it; a source missing
  from the cache (E0137) gives no verdict, naming the same pull. Every
  validator then runs over each boundary the build rendered (THE
  VALIDATORS), and each finding is held to KNOWN FINDINGS. A Release whose
  boundaries hold no root any validator reads is refused, naming it, since
  no validator would judge anything it builds.

NEGATIVE RELEASES
  release-negative-<slug>.yaml, with its .lock and a .expect beside it, is
  a Release that must halt. Its .expect holds one line, which the halted
  build's output must contain: assertion "<key>" for a Recipe's assertion,
  as the build names one (Recipe "<name>" instance "<i>" assertion
  "<key>"), and a fixed phrase of the sentence for a refusal raised inside
  a mapping or a template, which the build quotes whole. A negative
  Release that builds is refused; so is one halting on another condition,
  naming the line expected and the halt; and one with no .expect, or a
  .expect holding other than one line with text.

WHAT A COMMIT SELECTS (--staged)
  --staged builds the fixtures the commit reaches, each lock read from the
  index:
    - a path in a version directory of the catalog — a Recipe, a
      FeatureRecipe, a Component, a Feature, or a mapping, artifact,
      schema or workload library — selects each fixture whose lock
      records that entity or library at that version, a negative
      Release's lock among them. A library is matched by the name its
      YAML gives, read as aggrega writes it: kind: <kind>Library at the
      margin and the name indented two spaces under metadata:. A library
      version from which no name can be read that way is refused, naming
      it;
    - a path in a fixture selects that fixture;
    - scripts/vendor-validators.json, and the files this script runs
      (itself, scripts/vendor-validate-arm.py and the libraries in
      scripts/lib/ it sources), select every fixture and run --self-test
      as the index holds them;
    - .cfnlintrc.yaml selects every cloudformation fixture, and runs THE
      CFN-LINT CONFIGURATION;
    - scripts/vendor-validators-known-findings.json selects each fixture
      reaching the entity version an entry it adds or removes names.
  A Recipe or FeatureRecipe version directory for arm, cloudformation or
  terraform that the commit changes and no fixture builds — recorded by no
  lock but a negative Release's, which halts before any validator runs — is
  refused, naming it, since no validator would judge it: build it in a
  fixture. A commit selecting nothing passes once the rules above hold,
  with no validator required.

KNOWN FINDINGS (--staged, --all)
  scripts/vendor-validators-known-findings.json lists the findings each
  published entity version is known to carry: format, 1, and findings,
  each entry an entity (<kind>/<capability>/<name>, as FINDINGS
  attributes one), its version, the finding's id and its reason, naming
  what in that version causes it. A published version is final, so its
  findings are listed rather than mended; a version not yet published is
  mended. A finding is refused unless an entry lists its id for the
  entity version it is attributed to, and one attributed to - can never
  be listed. An entry is refused when its version is not published (THE
  CANONICAL PASS-THROUGH says when one is), and as stale when the run
  built every fixture reaching that version and its finding did not
  appear, so the list only shrinks; a finding's id carries names the
  fixture gives, an instance's among them, so one fixture built says
  nothing of the findings another shows. --all builds every fixture and
  judges every entry, refusing one whose version no fixture builds;
  --staged judges each entry the commit adds, refusing one whose version
  no fixture reaches, in the order the file holds them, and each naming a
  version a fixture it built reaches.

EXIT CODES
  0  passed: nothing refused
  1  refused: every finding is named; for --self-test, a case that did not
     give its expected verdict, named
  2  a usage error
  3  no verdict: a requirement is missing, each named with the one command
     that supplies it — a source a fixture's lock pins missing from its
     cache among them; a git command failed; or --prime failed and left
     nothing primed
END_OF_HELP
)"
  text="${text//@BUILD_MIB@/$BUILD_MIB}"
  text="${text//@BUILD_CEILING@/$BUILD_CEILING}"
  printf '%s\n' "${text//@MARKER@/$VENDOR_MARKER}"
}

# The marker aggrega import opens every passage a draft takes from a vendor
# schema with, composed from its two parts so that no file here carries it whole.
VENDOR_MARKER_HEAD="[vendor schema"
VENDOR_MARKER_TAIL="text]"
VENDOR_MARKER="$VENDOR_MARKER_HEAD $VENDOR_MARKER_TAIL"

# How many Releases are built at once (RELEASES ARE BUILT SIDE BY SIDE, at the
# top; build_bound): never more than BUILD_CEILING, two for each three
# processing units, and one for each BUILD_MIB MiB of the memory the host has
# available.
BUILD_CEILING=12
BUILD_MIB=1536

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
# Every glob, comparison and text tool runs in the C locale, so the order a glob
# lists its matches in is byte order on every machine.
export LC_ALL=C
HERE="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)" || exit 3
# shellcheck source=lib/catalog-entities.sh
. "$HERE/lib/catalog-entities.sh" || exit 3
# shellcheck source=lib/published-branch.sh
. "$HERE/lib/published-branch.sh" || exit 3
# shellcheck source=lib/bounded-jobs.sh
. "$HERE/lib/bounded-jobs.sh" || exit 3

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

# --prime and --self-test read the pin file in the working tree; --staged and
# --all read the one the index holds, from the copy of the index they build in,
# so the cache they require is the one primed for the pin file the commit carries.
PIN_FILE="$HERE/vendor-validators.json"
PIN_REL="scripts/vendor-validators.json"
CANONICAL="scripts/container-pass-through/main.tf"
CFNLINTRC=".cfnlintrc.yaml"
TF_RECIPES="$CATALOG_ROOT/recipe/terraform"
KNOWN_FINDINGS="scripts/vendor-validators-known-findings.json"
PROOFS="proofs"
# The targets a fixture directory is named for, and the capabilities whose
# Recipes and FeatureRecipes a fixture must reach when a commit changes them.
FIXTURE_TARGETS=" arm cloudformation terraform-aws terraform-azurerm terraform-google terraform-cloudflare "
CLOUD_CAPABILITIES=" arm cloudformation terraform "
# The files this script runs: itself, the Azure Resource Manager check and the
# libraries it sources. A commit changing one runs the staged copy's --self-test
# and every fixture.
GATE_SCRIPTS=" scripts/vendor-validate.sh scripts/vendor-validate-arm.py scripts/lib/catalog-entities.sh scripts/lib/published-branch.sh scripts/lib/bounded-jobs.sh "
# What the gate copies out of the index to build in.
MATERIALIZED=("$CATALOG_ROOT" "$PROOFS" scripts "$CFNLINTRC")
PRIME_CMD="$HERE/vendor-validate.sh --prime"
# The Azure Resource Manager check: this checkout's, until materialize names the
# copy the index holds.
ARM_CHECK="$HERE/vendor-validate-arm.py"
TMP="$(mktemp -d)" || exit 3
# stop_builds — stops every build still running beside the run and waits for each
# to end, so that none outlives the run or writes into its temporary directory
# once that is removed. Asked to stop, a build stops its aggrega and then itself
# (build_run).
# shellcheck disable=SC2329 # called from the EXIT trap
stop_builds() {
  local running
  local -a pids
  running="$(jobs -p)"
  if [ -n "$running" ]; then
    mapfile -t pids <<<"$running"
    kill -TERM "${pids[@]}" 2>/dev/null
  fi
  wait
}
# However the run ends, it ends through exit: an interrupt, a termination request
# and a hang-up each exit, so the builds are stopped and the temporary directory
# removed every time.
trap 'stop_builds; rm -rf "$TMP"' EXIT
trap 'exit 130' INT
trap 'exit 143' TERM
trap 'exit 129' HUP

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

# --- the gate's own files -----------------------------------------------------------
# gate_unstaged_rule — refuses, naming each, every file of the gate (GATE_SCRIPTS)
# whose working tree differs from the index: bash runs this script and the
# libraries it sources as the checkout holds them, so a change not staged would
# judge the commit by rules the commit does not carry.
gate_unstaged_rule() {
  local path
  # shellcheck disable=SC2086 # the gate's files, space-separated
  git --literal-pathspecs diff --name-only -z -- $GATE_SCRIPTS >"$TMP/gate-unstaged" ||
    no_verdict "git cannot compare the gate's own files in the working tree with the index"
  while IFS= read -r -d '' path; do
    refuse "$path: changed in the working tree and not staged. --staged runs the gate's own files as this checkout holds them, so a change not staged would judge this commit by rules the commit does not carry: stage it (git add -- $path) or undo it, then commit again."
  done <"$TMP/gate-unstaged"
}

# --- vendor text -------------------------------------------------------------------
# vendor_text_rule — refuses every file the commit adds, changes, copies or renames
# (--staged), or every file the index holds (--all), whose staged content carries
# the marker, naming the file and each line.
vendor_text_rule() {
  local path line rc=0
  local -a judged=()
  local -A seen=()
  : >"$TMP/vendor-text-hits"
  if [ "$MODE" = staged ]; then
    git diff --cached --name-only -z --no-renames --diff-filter=ACMRT "$BASE" >"$TMP/vendor-text-paths" ||
      no_verdict "git cannot list what the commit stages"
    while IFS= read -r -d '' path; do judged+=("$path"); done <"$TMP/vendor-text-paths"
    [ "${#judged[@]}" -gt 0 ] || return 0
    # Only the paths judged are searched, named literally, a bounded number to
    # each search, so a commit's cost follows what it stages, not the index.
    while [ "${#judged[@]}" -gt 0 ]; do
      vendor_text_search -- "${judged[@]:0:256}"
      judged=("${judged[@]:256}")
    done
  else
    vendor_text_search
  fi
  while IFS= read -r -d '' path && IFS= read -r -d '' line && IFS= read -r _; do
    [ -z "${seen[$path:$line]+set}" ] || continue
    seen[$path:$line]=1
    refuse "$path:$line: carries the marker $VENDOR_MARKER, which opens a passage aggrega import took from a vendor schema. Vendor text is not committed to this catalog: write the passage in your own words, remove the marker, and stage the file again."
  done <"$TMP/vendor-text-hits"
}

# vendor_text_search [-- PATH...] — appends to vendor-text-hits each line of the
# index carrying the marker, in the PATHs given (taken literally) or in the whole
# index. With -o each hit is the path, the line number and the marker itself, so
# no file's own text can break the reading.
vendor_text_search() {
  local rc=0
  git --literal-pathspecs grep --cached --no-recurse-submodules --no-color --no-column -a -z -n -o -F \
    -e "$VENDOR_MARKER" "$@" >>"$TMP/vendor-text-hits" || rc=$?
  [ "$rc" -le 1 ] || no_verdict "git cannot search the index"
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
# fetched; with none fetched, nothing is recorded, which is said once on standard
# error.
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
    else
      printf '%s: note — %s/%s has not been fetched, so every version counts as unpublished; fetch it: git fetch %s %s\n' \
        "$ME" "$remote" "$PUBLISHED_BRANCH" "$remote" "$PUBLISHED_BRANCH" >&2
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
# ignore_checks is the one key .cfnlintrc.yaml holds, and each rule it ignores is
# a line of its own, - <rule>, with its reason in a comment beside it or on the
# line directly above; awk prints, for each line that breaks this, its line
# number, a tab and what to write. Outside the list under ignore_checks, a line
# is a comment, a blank line or ignore_checks: at the margin, so any other key,
# a document marker or a directive is refused, indented or not. A list written
# in brackets, empty or not, gives no rule a line of its own, so only the empty
# one, [], passes; so does no line under ignore_checks but a comment, a blank
# line or an entry - <rule>.
# shellcheck disable=SC2016 # awk's own $, not the shell's
CFNLINTRC_AWK='
  function trim(s) { sub(/^[ \t]+/, "", s); sub(/[ \t]+$/, "", s); return s }
  function uncomment(s) { sub(/^#.*$/, "", s); sub(/[ \t]+#.*$/, "", s); return trim(s) }
  function unquote(s) { if (s ~ /^".*"$/ || s ~ /^\047.*\047$/) s = substr(s, 2, length(s) - 2); return s }
  { sub(/\r$/, "") }
  in_list && $0 ~ /^[^ \t#-]/ { in_list = 0 }
  in_list && $0 ~ /^[ \t]+[^ \t#-]/ {
    printf "%d\twrites %s under ignore_checks, which is not an entry - <rule>: write each rule cfn-lint ignores as a line - <rule> under ignore_checks, with its reason in a comment beside it or on the line above\n", NR, trim($0)
  }
  in_list && $0 ~ /^[ \t]*-/ {
    entry = $0
    sub(/^[ \t]*-[ \t]*/, "", entry)
    rule = unquote(uncomment(entry))
    if (entry !~ /[ \t]#[ \t]*[^ \t]/ && previous !~ /^[ \t]*#[ \t]*[^ \t]/)
      printf "%d\tignores the cfn-lint rule %s with no reason beside it or on the line above: write, in a comment there, what the rule reports and why a template this catalog renders is right to carry it anyway, or remove the entry\n", NR, rule
  }
  !in_list && $0 !~ /^[ \t]*(#|$)/ && $0 !~ /^ignore_checks[ \t]*:/ {
    key = uncomment($0)
    sub(/[ \t]*:.*$/, "", key)
    printf "%d\twrites %s, and ignore_checks is the one key this file holds: any other key changes which templates cfn-lint reads, which rules it runs or how they judge, with no reason reviewed beside it; remove it\n", NR, key
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

# arm_check DIR TEMPLATE... — runs the Azure Resource Manager check (ARM_CHECK)
# with the cache's Python over the cache's schemas on each TEMPLATE, a path
# relative to DIR: the path every finding's id carries. Exits as the check does:
# 0 no finding, 1 findings, 2 a usage error, 3 no verdict.
# shellcheck disable=SC2329 # called from the cases, which run by name from ST_CASES
arm_check() {
  local dir="$1"
  shift
  (cd -- "$dir" && "$CACHE_DIR/venv/bin/python" -I "$ARM_CHECK" "$CACHE_DIR/arm-schemas/schemas" "$@")
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
  [ -d "$boundary/terraform" ] || return 2
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
  [ -d "$boundary/cloudformation" ] || return 2
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
    --regions us-east-1 --format json -- "$template") </dev/null >"$work/cfn-lint.json" 2>"$work/cfn-lint.err" || rc=$?
  [ -s "$work/cfn-lint.json" ] ||
    no_verdict "cfn-lint gave no reading of $boundary/$template (exit $rc): $(tail -n 3 "$work/cfn-lint.err" | tr '\n' ' ')"
  read_findings "$tree" cloudformation cfn-lint "$boundary" "$template" "$work/cfn-lint.json" "$rc" "$lines"
}

# arm_findings TREE BOUNDARY — the Azure Resource Manager check on the template
# BOUNDARY holds; prints its findings attributed through TREE's catalog.
# shellcheck disable=SC2329 # called by name, as a fixture's check calls it
arm_findings() {
  local tree="$1" boundary="$2" template="arm/arm-template.json" work why rc=0
  [ -d "$boundary/arm" ] || return 2
  [ -f "$boundary/$template" ] ||
    no_verdict "$boundary/arm holds no arm-template.json, the template the arm provider renders, so the Azure Resource Manager check has no template to read"
  work="$(mktemp -d "$TMP/arm.XXXXXX")" || no_verdict "cannot make a directory in $TMP"
  arm_check "$boundary" "$template" >"$work/arm.out" 2>"$work/arm.err" || rc=$?
  case "$rc" in
    0 | 1) ;;
    *)
      why="$(tail -n 3 "$work/arm.err" | tr '\n' ' ')"
      # The check runs from the copy of the index, and names the command that
      # primes the cache beside itself; the command to run is this checkout's.
      [ -z "${TREE:-}" ] || why="${why//"$TREE/scripts/vendor-validate.sh"/"$HERE/vendor-validate.sh"}"
      no_verdict "the Azure Resource Manager check gives no verdict on $boundary/$template (exit $rc): $why" ;;
  esac
  read_findings "$tree" arm arm "$boundary" "$template" "$work/arm.out" "$rc"
}

# --- the fixtures ----------------------------------------------------------------
# A fixture is a workspace of its own under proofs/<target>/<group>/, whose
# Releases build the catalog's cloud Recipes; --help holds the layout and the
# contract. Every file is read from the index: the selection reads the fixtures'
# locks as the index holds them, and the builds run in a copy of the index.

# Each versioned entry a release.lock records, as the key the selection matches
# on: entity:<kind>:<uri>@<version> for an entity, its uri without a :<version>
# of its own, and library:<section>:<name>@<version> for a library. The lock is
# read as the text aggrega pull writes: each section's name at the margin, each
# entry opening with "    - " and its fields indented six spaces.
# shellcheck disable=SC2016 # awk's own $, not the shell's
LOCK_KEYS_AWK='
  function flush(   u) {
    if (uri != "" && version != "") {
      if (section == "entities") { u = uri; sub(/:[^:\/]*$/, "", u); print "entity:" kind ":" u "@" version }
      else if (section ~ /_libraries$/) print "library:" section ":" uri "@" version
    }
    kind = ""; uri = ""; version = ""
  }
  function field(line,   key, value) {
    sub(/^[ -]+/, "", line)
    key = line; sub(/:.*$/, "", key)
    value = line; sub(/^[^:]*:[ \t]*/, "", value); gsub(/^["\047]|["\047]$/, "", value)
    if (key == "kind") kind = value
    else if (key == "uri") uri = value
    else if (key == "resolved_version") version = value
  }
  { sub(/\r$/, "") }
  /^[A-Za-z_]/ { flush(); section = $0; sub(/:.*$/, "", section); next }
  /^    - [a-z_]+:/ { flush(); field($0); next }
  /^      [a-z_]+:/ { field($0) }
  END { flush() }'

# The metadata.name of the YAML awk reads.
# shellcheck disable=SC2016 # awk's own $, not the shell's
METADATA_NAME_AWK='
  { sub(/\r$/, "") }
  /^metadata:[ \t]*$/ { inside = 1; next }
  inside && /^[^ \t#]/ { exit }
  inside && /^  name:/ { sub(/^  name:[ \t]*/, ""); sub(/[ \t]+#.*$/, ""); gsub(/^["\047]|["\047]$/, ""); print; exit }'

# pull_command FIXTURE RELEASE — the command that pulls RELEASE's lock in FIXTURE.
pull_command() {
  printf '(cd %s && aggrega pull --release %s)' "$1" "$2"
}

# fixtures_rule — FIXTURES gets every fixture the index holds, in byte order, and
# IS_FIXTURE marks each; a workspace under proofs/ laid out otherwise is refused.
fixtures_rule() {
  local path dir target
  FIXTURES=()
  declare -gA IS_FIXTURE=()
  git ls-files -z -- "$PROOFS/" >"$TMP/proof-paths" || no_verdict "git cannot list $PROOFS/"
  while IFS= read -r -d '' path; do
    [ "${path##*/}" = .aggrega-config.yaml ] || continue
    dir="${path%/*}"
    target="${dir#"$PROOFS"/}"
    target="${target%%/*}"
    if [[ $dir =~ ^$PROOFS/[^/]+/[^/]+$ && $FIXTURE_TARGETS == *" $target "* ]]; then
      FIXTURES+=("$dir")
      IS_FIXTURE[$dir]=1
    else
      refuse "$path: a workspace under $PROOFS/ outside the fixture layout. A fixture is $PROOFS/<target>/<group>/, its target one of:$FIXTURE_TARGETS(see --help): move it there."
    fi
  done <"$TMP/proof-paths"
}

# fixture_releases FIXTURE — RELEASES gets the Releases FIXTURE holds in the
# index, release.yaml and release-<slug>.yaml directly in it, in byte order.
fixture_releases() {
  local path name
  RELEASES=()
  git --literal-pathspecs ls-files -z -- "$1/" >"$TMP/fixture-paths" || no_verdict "git cannot list $1/"
  while IFS= read -r -d '' path; do
    [ "${path%/*}" = "$1" ] || continue
    name="${path##*/}"
    case "$name" in release.yaml | release-?*.yaml) RELEASES+=("$name") ;; esac
  done <"$TMP/fixture-paths"
}

# expect_line FILE — the one line with text the .expect FILE holds, its
# surrounding blanks and carriage return dropped.
# shellcheck disable=SC2329 # called from judge_build, which bounded_jobs reaches by name
expect_line() {
  awk '{ sub(/\r$/, ""); sub(/^[ \t]+/, ""); sub(/[ \t]+$/, "") } $0 != "" { print; exit }' "$1"
}

# fixture_shape_rule FIXTURE — refuses a fixture holding no Release, a Release
# with no lock beside it, and a negative Release with no .expect holding one
# line with text, each read from the index.
fixture_shape_rule() {
  local fx="$1" name lock expect lines
  fixture_releases "$fx"
  if [ "${#RELEASES[@]}" -eq 0 ]; then
    refuse "$fx: a fixture holding no Release, release.yaml or release-<slug>.yaml, so it proves nothing: add one, or remove the fixture."
    return
  fi
  for name in "${RELEASES[@]}"; do
    lock="$fx/${name%.yaml}.lock"
    git cat-file -e ":$lock" 2>/dev/null ||
      refuse "$fx/$name: no lock beside it in the index, and a fixture builds from its lock alone: pull it and stage it — $(pull_command "$fx" "$name"); git add -- $lock"
    case "$name" in release-negative-?*.yaml) ;; *) continue ;; esac
    expect="$fx/${name%.yaml}.expect"
    if ! staged_blob "$expect" "$TMP/expect"; then
      refuse "$fx/$name: a negative Release with no ${name%.yaml}.expect in the index: write in it the one line its halted build's output must contain — assertion \"<key>\" for an assertion, a fixed phrase of the sentence for a refusal — and stage it."
      continue
    fi
    lines="$(grep -c '[^[:space:]]' "$TMP/expect")"
    [ "$lines" = 1 ] ||
      refuse "$expect: holds $lines lines with text, and a negative Release's .expect holds one: the line its halted build's output must contain."
  done
}

# reach_table — REACH gets, for each key the locks of the fixtures' Releases in
# the index reach, the fixtures reaching it, space-separated; NEGATIVE_REACH the
# same for their negative Releases' locks, which select a fixture to build but
# prove nothing of what they record, since a negative Release halts before any
# validator runs. A lock from which no versioned entry can be read is refused.
reach_table() {
  local fx name lock key negative
  declare -gA REACH=() NEGATIVE_REACH=()
  for fx in ${FIXTURES[@]+"${FIXTURES[@]}"}; do
    fixture_releases "$fx"
    for name in ${RELEASES[@]+"${RELEASES[@]}"}; do
      case "$name" in
        release-negative-?*.yaml) negative=1 ;;
        *) negative=0 ;;
      esac
      lock="$fx/${name%.yaml}.lock"
      # A lock missing from the index is refused by fixture_shape_rule.
      staged_blob "$lock" "$TMP/lock" || continue
      awk "$LOCK_KEYS_AWK" "$TMP/lock" >"$TMP/lock-keys"
      if [ ! -s "$TMP/lock-keys" ]; then
        refuse "$lock: no resolved entity can be read from it, so no change can be traced to this fixture: pull it again and stage it — $(pull_command "$fx" "$name"); git add -- $lock"
        continue
      fi
      while IFS= read -r key; do
        if [ "$negative" = 1 ]; then
          [[ " ${NEGATIVE_REACH[$key]:-} " == *" $fx "* ]] ||
            NEGATIVE_REACH[$key]="${NEGATIVE_REACH[$key]:+${NEGATIVE_REACH[$key]} }$fx"
        else
          [[ " ${REACH[$key]:-} " == *" $fx "* ]] || REACH[$key]="${REACH[$key]:+${REACH[$key]} }$fx"
        fi
      done <"$TMP/lock-keys"
    done
  done
}

# library_name VDIR — the metadata.name of the library whose version directory
# is VDIR, read from the index, else from BASE for a library the commit removes:
# the YAML directly in VDIR whose kind:, at the margin, ends in Library, its name
# indented two spaces under metadata:, as aggrega writes them. Returns 2 when
# neither holds such a YAML or its name is empty.
library_name() {
  local vdir="$1" rev path name
  for rev in "" "$BASE"; do
    if [ -z "$rev" ]; then
      git --literal-pathspecs ls-files -z -- "$vdir/" >"$TMP/library-paths"
    else
      git --literal-pathspecs ls-tree -r -z --name-only "$rev" -- "$vdir/" >"$TMP/library-paths"
    fi || no_verdict "git cannot list $vdir/"
    while IFS= read -r -d '' path; do
      [ "${path%/*}" = "$vdir" ] || continue
      case "$path" in *.yaml | *.yml) ;; *) continue ;; esac
      git show "$rev:$path" >"$TMP/library.yaml" 2>/dev/null || continue
      case "$(peek_kind "$TMP/library.yaml")" in *Library) ;; *) continue ;; esac
      name="$(awk "$METADATA_NAME_AWK" "$TMP/library.yaml")"
      [ -n "$name" ] || return 2
      printf '%s\n' "$name"
      return 0
    done <"$TMP/library-paths"
  done
  return 2
}

# catalog_key PATH — the key, as LOCK_KEYS_AWK prints it, of the entity or
# library version PATH lies under: an entity's read from its directory, a
# library's name from its YAML. Returns 1 for a path under no version directory,
# and 2 for a library version whose name cannot be read (library_name).
catalog_key() {
  local vdir rest kind_dir name version section=""
  vdir="$(version_dir "$1")" || return 1
  rest="${vdir#"$CATALOG_ROOT"/}"
  kind_dir="${rest%%/*}"
  rest="${rest#*/}"
  version="${rest##*/}"
  name="${rest%/*}"
  case "$kind_dir" in
    feature-recipe) printf 'entity:feature_recipe:%s@%s\n' "$name" "$version" ;;
    mappinglibrary) section=mapping_libraries ;;
    artifactlibrary) section=artifact_libraries ;;
    schemalibrary) section=schema_libraries ;;
    workloadlibrary) section=workload_libraries ;;
    *) printf 'entity:%s:%s@%s\n' "$kind_dir" "$name" "$version" ;;
  esac
  [ -n "$section" ] || return 0
  name="$(library_name "$vdir")" || return "$?"
  printf 'library:%s:%s@%s\n' "$section" "$name" "$version"
}

# entry_key ENTITY VERSION — the key of a known-findings entry's entity version.
entry_key() {
  local kind="${1%%/*}"
  [ "$kind" != featurerecipe ] || kind=feature_recipe
  printf 'entity:%s:%s@%s\n' "$kind" "${1#*/}" "$2"
}

# select_fixtures FIXTURE... — marks each FIXTURE to be built.
declare -A SELECTED=()
select_fixtures() {
  local fx
  for fx in "$@"; do SELECTED[$fx]=1; done
}

# select_staged — selects the fixtures the commit reaches (--help, WHAT A COMMIT
# SELECTS), sets SELF_TEST when the gate's own files change, and refuses each
# cloud Recipe or FeatureRecipe version the commit changes that no fixture's
# positive Release reaches.
select_staged() {
  local path key vdir rest kind_dir capability fx what only rc
  local -A unreached=() unreadable=()
  git diff --cached --name-only -z --no-renames "$BASE" >"$TMP/staged-paths" ||
    no_verdict "git cannot list what the commit stages"
  while IFS= read -r -d '' path; do
    if [ "$path" = "$PIN_REL" ] || [[ $GATE_SCRIPTS == *" $path "* ]]; then
      SELF_TEST=1
      select_fixtures ${FIXTURES[@]+"${FIXTURES[@]}"}
      continue
    fi
    case "$path" in
      "$CFNLINTRC")
        cfnlintrc_rule
        for fx in ${FIXTURES[@]+"${FIXTURES[@]}"}; do
          [[ $fx != "$PROOFS/cloudformation/"* ]] || select_fixtures "$fx"
        done
        ;;
      "$KNOWN_FINDINGS") KNOWN_STAGED=1 ;;
      "$PROOFS"/*/*/*)
        rest="${path#"$PROOFS"/}"
        fx="$PROOFS/${rest%%/*}"
        rest="${rest#*/}"
        fx="$fx/${rest%%/*}"
        [ -z "${IS_FIXTURE[$fx]+set}" ] || select_fixtures "$fx"
        ;;
      "$CATALOG_ROOT"/*)
        rc=0
        key="$(catalog_key "$path")" || rc=$?
        case "$rc" in
          0) ;;
          1) continue ;;
          2)
            vdir="$(version_dir "$path")"
            [ -z "${unreadable[$vdir]+set}" ] || continue
            unreadable[$vdir]=1
            refuse "$vdir: a library version the commit changes, and no library name can be read from it, so no fixture reaching it can be found: write its YAML directly in this directory, kind: <kind>Library at the margin and its name indented two spaces under metadata:, as aggrega writes them."
            continue
            ;;
          *) exit 3 ;;
        esac
        # shellcheck disable=SC2086 # the fixtures, space-separated
        [ -z "${NEGATIVE_REACH[$key]:-}" ] || select_fixtures ${NEGATIVE_REACH[$key]}
        if [ -n "${REACH[$key]:-}" ]; then
          # shellcheck disable=SC2086 # the fixtures, space-separated
          select_fixtures ${REACH[$key]}
          continue
        fi
        vdir="$(version_dir "$path")"
        rest="${vdir#"$CATALOG_ROOT"/}"
        kind_dir="${rest%%/*}"
        rest="${rest#*/}"
        capability="${rest%%/*}"
        case "$kind_dir" in
          recipe) what=Recipe ;;
          feature-recipe) what=FeatureRecipe ;;
          *) continue ;;
        esac
        [[ $CLOUD_CAPABILITIES == *" $capability "* ]] || continue
        [ -z "${unreached[$vdir]+set}" ] || continue
        unreached[$vdir]=1
        # A version directory the commit removes whole has nothing left to build.
        [ -n "$(git --literal-pathspecs ls-files -- "$vdir/")" ] || continue
        only=""
        [ -z "${NEGATIVE_REACH[$key]:-}" ] ||
          only=" (only a negative Release records it, and a negative Release halts before any validator runs)"
        refuse "$vdir: a cloud $what version the commit changes, and no fixture under $PROOFS/ builds it$only, so no vendor validator judges it. Build it in a fixture: an instance of it in a fixture's Aggregate, bound in its Manifest (a FeatureRecipe attached where a Recipe's slot asks for one); then pull that fixture's Release and stage its lock."
        ;;
    esac
  done <"$TMP/staged-paths"
  [ "$KNOWN_STAGED" = 0 ] || select_known_changes
}

# The known-findings reader: it reads the file named, as the index or a commit
# holds it, and prints one line per entry, entry TAB entity TAB version TAB id,
# and one line per fault, bad TAB what is wrong, in the file's order.
PY_KNOWN="$(cat <<'END_OF_PYTHON'
import json, re, sys

path = sys.argv[1]
ENTITY = re.compile(r"(recipe|featurerecipe)/(arm|cloudformation|terraform)/[A-Za-z0-9][A-Za-z0-9._-]*")
VERSION = re.compile(r"[0-9]+\.[0-9]+\.[0-9]+([-+][0-9A-Za-z.+-]+)?")
IDENT = re.compile(r"(tofu|cfn-lint|arm)\|[^|\t\r\n]+\|[^\t\r\n]+")
KEYS = ("entity", "version", "id", "reason")

def bad(why):
    print(f"bad\t{why}")

try:
    with open(path, encoding="utf-8") as f:
        doc = json.load(f)
except (OSError, ValueError) as e:
    bad(f"it is not readable as JSON ({' '.join(str(e).split())})")
    sys.exit(0)
if not isinstance(doc, dict) or doc.get("format") != 1 or set(doc) != {"format", "findings"}:
    bad("it is not an object holding format, 1, and findings, the format this script reads")
    sys.exit(0)
if not isinstance(doc["findings"], list):
    bad("findings is not a list of entries")
    sys.exit(0)
seen = set()
for i, e in enumerate(doc["findings"]):
    where = f"findings[{i}]"
    if not isinstance(e, dict) or set(e) != set(KEYS):
        bad(f"{where} is not an object holding exactly entity, version, id and reason")
        continue
    entity, version, ident, reason = (e[k] for k in KEYS)
    if not (isinstance(entity, str) and ENTITY.fullmatch(entity)):
        bad(f"{where}.entity is not <kind>/<capability>/<name>, kind recipe or featurerecipe, capability arm, cloudformation or terraform")
    elif not (isinstance(version, str) and VERSION.fullmatch(version)):
        bad(f"{where}.version is not a version X.Y.Z")
    elif not (isinstance(ident, str) and IDENT.fullmatch(ident)):
        bad(f"{where}.id is not a finding id, <validator>|<rule>|<address>")
    elif not (isinstance(reason, str) and reason.strip()):
        bad(f"{where}.reason is empty: name what in that published version causes the finding")
    elif (entity, version, ident) in seen:
        bad(f"{where} lists {entity}@{version} {ident} a second time")
    else:
        seen.add((entity, version, ident))
        print(f"entry\t{entity}\t{version}\t{ident}")
END_OF_PYTHON
)"

# read_known REV FILE — writes to FILE what PY_KNOWN reads in the known-findings
# file as REV holds it, "" for the index; returns 1 when REV holds none.
read_known() {
  local out
  command -v python3 >/dev/null 2>&1 ||
    no_verdict "python3 is not on PATH, and $KNOWN_FINDINGS is read with it; install Python 3"
  if [ -z "$1" ]; then
    staged_blob "$KNOWN_FINDINGS" "$TMP/known.json" || return 1
  else
    git cat-file -e "$1:$KNOWN_FINDINGS" 2>/dev/null || return 1
    git show "$1:$KNOWN_FINDINGS" >"$TMP/known.json" || no_verdict "git cannot read $KNOWN_FINDINGS at $1"
  fi
  out="$(python3 -I -c "$PY_KNOWN" "$TMP/known.json")" || no_verdict "$KNOWN_FINDINGS cannot be read: $out"
  printf '%s\n' "$out" >"$2"
}

# load_known — KNOWN gets the entries of the known-findings file the index holds,
# entity@version TAB id, in the file's order; each fault in the file is refused.
# Read once.
KNOWN_LOADED=0
KNOWN=()
load_known() {
  local what entity version id
  [ "$KNOWN_LOADED" = 0 ] || return 0
  KNOWN_LOADED=1
  if ! read_known "" "$TMP/known"; then
    refuse "$KNOWN_FINDINGS: not in the index. It lists the findings each published entity version is known to carry: restore it from git and stage it (git add -- $KNOWN_FINDINGS)."
    return
  fi
  while IFS=$'\t' read -r what entity version id; do
    case "$what" in
      entry) KNOWN+=("$entity@$version"$'\t'"$id") ;;
      bad) refuse "$KNOWN_FINDINGS: $entity." ;;
    esac
  done <"$TMP/known"
}

# select_known_changes — the commit changes the known-findings file: selects the
# fixtures reaching the entity version each added or removed entry names, marks
# each added entry in KNOWN_ADDED to be judged, and refuses an added entry whose
# entity version no fixture reaches, since nothing could ever show its finding.
# The entries are taken in the order the file holds them, each it adds first,
# then each it removes, so its refusals come out in that order.
declare -A KNOWN_ADDED=()
select_known_changes() {
  local row what entity version id key
  local -a removed=()
  local -A before=() after=()
  load_known
  for row in ${KNOWN[@]+"${KNOWN[@]}"}; do after[$row]=1; done
  if read_known "$BASE" "$TMP/known-before"; then
    while IFS=$'\t' read -r what entity version id; do
      [ "$what" = entry ] || continue
      row="$entity@$version"$'\t'"$id"
      before[$row]=1
      [ -n "${after[$row]+set}" ] || removed+=("$row")
    done <"$TMP/known-before"
  fi
  for row in ${KNOWN[@]+"${KNOWN[@]}"} ${removed[@]+"${removed[@]}"}; do
    [ -z "${after[$row]+set}" ] || [ -z "${before[$row]+set}" ] || continue
    entity="${row%%@*}"
    version="${row#*@}"
    version="${version%%$'\t'*}"
    key="$(entry_key "$entity" "$version")"
    if [ -n "${REACH[$key]:-}" ]; then
      # shellcheck disable=SC2086 # the fixtures, space-separated
      select_fixtures ${REACH[$key]}
    fi
    [ -n "${after[$row]+set}" ] || continue
    KNOWN_ADDED[$row]=1
    [ -n "${REACH[$key]:-}" ] ||
      refuse "$KNOWN_FINDINGS: the entry for $entity@$version (${row#*$'\t'}) names a version no fixture under $PROOFS/ builds, so its finding can never be shown: build that version in a fixture, or remove the entry."
  done
}

# materialize — writes what the index holds of the catalog, the fixtures, the
# scripts and the cfn-lint configuration into TREE, under the run's temporary
# directory, removed when the run exits; the pin file read and the Azure
# Resource Manager check run from then on are the ones the index holds.
materialize() {
  TREE="$TMP/tree"
  mkdir -p "$TREE" || no_verdict "cannot make $TREE"
  git ls-files -z -- "${MATERIALIZED[@]}" | git checkout-index -z --stdin --prefix="$TREE/" ||
    no_verdict "git cannot write what the index holds into $TREE"
  printf '{}\n' >"$TMP/aggrega-config.yaml" || no_verdict "cannot write $TMP/aggrega-config.yaml"
  PIN_FILE="$TREE/$PIN_REL"
  ARM_CHECK="$TREE/scripts/vendor-validate-arm.py"
}

# staged_self_test — runs --self-test as the index holds this script and its pin
# file, from TREE, made a repository of its own for it.
staged_self_test() {
  local rc=0
  echo "$ME: the commit changes the gate's own files: --self-test, as the index holds them"
  (
    for var in $(git rev-parse --local-env-vars); do unset "$var"; done
    git -C "$TREE" init -q && bash "$TREE/scripts/vendor-validate.sh" --self-test
  ) || rc=$?
  case "$rc" in
    0) ;;
    1) refuse "--self-test, as the index holds this script and its pin file, did not give every expected verdict (above): mend the staged scripts." ;;
    *) exit 3 ;;
  esac
}

# build_bound — prints how many Releases are built at once: two for each three
# processing units nproc counts, one for each BUILD_MIB MiB of MemAvailable,
# BUILD_CEILING at most and one at least; one where this bash cannot run two at
# once, or where either count cannot be read.
build_bound() {
  local cpus mib bound="$BUILD_CEILING"
  bounded_jobs_concurrency_available || { echo 1; return 0; }
  cpus="$(nproc 2>/dev/null)"
  mib="$(awk '$1 == "MemAvailable:" { print int($2 / 1024); exit }' /proc/meminfo 2>/dev/null)"
  bounded_jobs_bound_ok "$cpus" || cpus=1
  [[ $mib =~ ^[0-9]+$ ]] || mib=0
  [ "$((cpus * 2 / 3))" -ge "$bound" ] || bound="$((cpus * 2 / 3))"
  [ "$((mib / BUILD_MIB))" -ge "$bound" ] || bound="$((mib / BUILD_MIB))"
  [ "$bound" -ge 1 ] || bound=1
  echo "$bound"
}

# build_release DIR RELEASE CACHE — replaces this shell with the build of RELEASE
# in the fixture at DIR, offline, rendering every node twice, everything it prints
# on standard output. The sources come from CACHE, the fixture's cache in this
# checkout named relative to DIR, and nothing is written there; no configuration
# but the fixture's own reaches the build.
# shellcheck disable=SC2329 # called from build_run, which bounded_jobs calls by name
build_release() {
  cd -- "$1" && exec env -u AGGREGA_CATALOG_DIRS -u AGGREGA_WORKSPACE_ROOT -u AGGREGA_CONFIG \
    AGGREGA_ARTIFACT_CACHE_DIR="$3" NO_COLOR=1 "$AGGREGA" build --config "$TMP/aggrega-config.yaml" \
    --workspace-root "$1" --offline --verify-determinism --quiet --release "$2" 2>&1
}

# halt_excerpt — the lines of BUILD_OUT that say why the build halted, indented:
# from the first diagnostic on, at most twelve.
# shellcheck disable=SC2329 # called from judge_build, which bounded_jobs reaches by name
halt_excerpt() {
  printf '%s\n' "$BUILD_OUT" | awk '
    !started && (/^\[/ || /^aggrega build:/) { started = 1 }
    started && n < 12 { print "    " $0; n++ }
    { last[NR % 12] = $0 }
    END { if (!started) for (i = NR - 11; i <= NR; i++) if (i > 0) print "    " last[i % 12] }'
}

# build_halted FIXTURE RELEASE — the build of RELEASE halted: a source missing
# from the fixture's cache gives no verdict, and a lock out of date is refused,
# each naming the pull; returns 1 for any other halt, left to the caller.
# shellcheck disable=SC2329 # called from judge_build, which bounded_jobs reaches by name
build_halted() {
  local fx="$1" name="$2"
  case "$BUILD_OUT" in
    *E0137*)
      no_verdict "$fx/$name: a source its lock pins is missing from $fx/.aggrega/cache, where this checkout keeps the fixture's sources. Fetch them (network, once): $(pull_command "$fx" "$name")" ;;
    *E0130*)
      refuse "$fx/${name%.yaml}.lock: out of date — the Release no longer resolves to what it records, so what the commit carries cannot be built from it. Pull it again and stage it: $(pull_command "$fx" "$name"); git add -- $fx/${name%.yaml}.lock"$'\n'"$(halt_excerpt)"
      return 0 ;;
  esac
  return 1
}

# boundary_findings FIXTURE RELEASE TREE — runs every validator over each
# boundary the build rendered in TREE, the build's own tree, appending each
# finding to findings as FIXTURE TAB RELEASE TAB boundary TAB id TAB attribution
# TAB message; prints how many findings, a space, and how many roots the
# validators read.
# shellcheck disable=SC2329 # called from judge_build, which bounded_jobs reaches by name
boundary_findings() {
  local fx="$1" name="$2" tree="$3" b runner out rc n=0 roots=0 id attr message
  for b in "$tree/$fx/dist"/*/; do
    [ -d "$b" ] || continue
    b="${b%/}"
    for runner in tofu_findings cfn_lint_findings arm_findings; do
      rc=0
      out="$("$runner" "$tree" "$b")" || rc=$?
      case "$rc" in
        0 | 1) roots=$((roots + 1)) ;;
        2) continue ;;
        *) exit 3 ;;
      esac
      while IFS=$'\t' read -r id attr message; do
        [ -n "$id" ] || continue
        n=$((n + 1))
        printf '%s\t%s\t%s\t%s\t%s\t%s\n' "$fx" "$name" "${b##*/}" "$id" "$attr" "$message" >>"$TMP/findings"
      done <<<"$out"
    done
  done
  printf '%s %s\n' "$n" "$roots"
}

# seconds_since START — the seconds since START, an EPOCHREALTIME, to a tenth.
# shellcheck disable=SC2329 # called from build_run and judge_build, which bounded_jobs reaches by name
seconds_since() {
  awk -v a="$1" -v b="$EPOCHREALTIME" 'BEGIN { printf "%.1f", b - a }'
}

# The Releases to build, by position: the fixture each lies in, and its file
# name; and, in the subshell building one, the build running there.
BUILD_FX=()
BUILD_NAME=()
BUILD_CHILD=""

# queue_fixture FIXTURE — queues each Release of FIXTURE to be built.
queue_fixture() {
  local fx="$1" name
  fixture_releases "$fx"
  for name in "${RELEASES[@]}"; do
    # A Release with no lock, or a negative one with no .expect, is refused by
    # fixture_shape_rule.
    [ -f "$TREE/$fx/${name%.yaml}.lock" ] || continue
    BUILD_FX+=("$fx")
    BUILD_NAME+=("$name")
  done
}

# build_fixtures — builds every Release queued, up to build_bound at once, and
# judges each in queue order (build_read).
build_fixtures() {
  [ "${#BUILD_FX[@]}" -gt 0 ] || return 0
  mkdir -p "$TMP/build" || no_verdict "cannot make $TMP/build"
  bounded_jobs "$(build_bound)" "$TMP/build" build_run build_read "${!BUILD_FX[@]}"
}

# build_run INDEX — builds the Release queued at INDEX in a tree of its own,
# $TMP/build/INDEX/tree: a copy of TREE whose files are hard links to TREE's, in
# which the build writes its own dist/. The build's output goes to
# $TMP/build/INDEX/out and, once it has ended, its exit status and its seconds to
# $TMP/build/INDEX/built; standard output names what kept it from building.
# Asked to stop, it stops the build, waits for it to end, and exits.
# shellcheck disable=SC2329 # called by name, through bounded_jobs
build_run() {
  local fx="${BUILD_FX[$1]}" name="${BUILD_NAME[$1]}" work="$TMP/build/$1" dir cache started rc=0
  # shellcheck disable=SC2064 # the Release is named now, as the trap is set
  trap "build_stop $(printf '%q' "$fx/$name")" INT TERM
  dir="$work/tree/$fx"
  { mkdir -- "$work" && cp -al -- "$TREE" "$work/tree" && rm -rf -- "$dir/dist"; } ||
    { echo "cannot link $TREE into $work/tree"; return 1; }
  cache="$(python3 -I -c 'import os, sys; print(os.path.relpath(sys.argv[1], sys.argv[2]))' \
    "$TOP/$fx/.aggrega/cache" "$dir")" || { echo "cannot name $TOP/$fx/.aggrega/cache relative to $dir"; return 1; }
  started="$EPOCHREALTIME"
  (build_release "$dir" "$name" "$cache") >"$work/out" </dev/null &
  BUILD_CHILD=$!
  wait "$BUILD_CHILD" || rc=$?
  BUILD_CHILD=""
  printf '%s %s\n' "$rc" "$(seconds_since "$started")" >"$work/built"
}

# build_stop RELEASE — stops the build running in this subshell, waits for it to
# end, and exits, naming RELEASE as stopped.
# shellcheck disable=SC2329 # called from the trap build_run sets
build_stop() {
  [ -z "$BUILD_CHILD" ] || kill -TERM "$BUILD_CHILD" 2>/dev/null
  wait
  echo "$1: the build was stopped before it ended"
  exit 1
}

# build_read INDEX ITEM STATUS OUTFILE — judges the build of the Release queued
# at INDEX (judge_build), then removes its tree; ITEM is INDEX again, the queue
# being handed to bounded_jobs by position. A build that did not run gives no
# verdict, naming why, as build_run wrote it to OUTFILE.
# shellcheck disable=SC2329 # called by name, through bounded_jobs
build_read() {
  local work="$TMP/build/$1" why built
  if [ ! -f "$work/built" ]; then
    why="$(cat -- "$4")"
    no_verdict "${why:-the build of ${BUILD_FX[$1]}/${BUILD_NAME[$1]} ended before it reported (exit $3)}"
  fi
  read -r BUILD_RC built <"$work/built"
  BUILD_OUT="$(cat -- "$work/out")"
  judge_build "${BUILD_FX[$1]}" "${BUILD_NAME[$1]}" "$work/tree" "$built"
  rm -rf -- "$work"
}

# judge_build FIXTURE RELEASE TREE SECONDS — judges the build of RELEASE of
# FIXTURE, rendered in TREE in SECONDS, by BUILD_RC and BUILD_OUT: a positive one
# must build and render a root a validator reads, and its findings go to
# findings, each entity version its lock reaches to BUILT (built_by); a negative
# one must halt with output holding its .expect line.
declare -A BUILT=()
# shellcheck disable=SC2329 # called from build_read, which bounded_jobs calls by name
judge_build() {
  local fx="$1" name="$2" tree="$3" built="$4" dir="$TREE/$1" expect started counts n roots key
  case "$name" in
    release-negative-?*.yaml)
      [ -f "$dir/${name%.yaml}.expect" ] || return 0
      expect="$(expect_line "$dir/${name%.yaml}.expect")"
      if [ "$BUILD_RC" -eq 0 ]; then
        refuse "$fx/$name: a negative Release, and it builds. It must halt, with output holding its .expect line: $expect. Give it the one fault it exists for, or move it out of release-negative-*."
      elif [[ $BUILD_OUT == *"$expect"* ]]; then
        echo "$ME: $fx/$name halts as its .expect says ($built s)"
      elif ! build_halted "$fx" "$name"; then
        refuse "$fx/$name: a negative Release halting on another condition than the one its .expect names. Expected output holding: $expect; the build halted with:"$'\n'"$(halt_excerpt)"
      fi
      return 0
      ;;
  esac
  if [ "$BUILD_RC" -ne 0 ]; then
    build_halted "$fx" "$name" ||
      refuse "$fx/$name: the build halts, offline, rendering every node twice:"$'\n'"$(halt_excerpt)"
    return 0
  fi
  started="$EPOCHREALTIME"
  counts="$(boundary_findings "$fx" "$name" "$tree")" || exit 3
  read -r n roots <<<"$counts"
  if [ "$roots" -eq 0 ]; then
    refuse "$fx/$name: a positive Release whose build renders no root a vendor validator reads (--help, THE VALIDATORS), so no validator judges anything it builds: give it an instance of a cloud Recipe of its target, or remove it."
    return 0
  fi
  echo "$ME: $fx/$name built in $built s; its boundaries validated in $(seconds_since "$started") s, $n finding(s)"
  while IFS= read -r key; do
    case "$key" in
      entity:recipe:*) built_by "recipe/${key#entity:recipe:}" "$fx" ;;
      entity:feature_recipe:*) built_by "featurerecipe/${key#entity:feature_recipe:}" "$fx" ;;
    esac
  done < <(awk "$LOCK_KEYS_AWK" "$dir/${name%.yaml}.lock")
}

# built_by ENTITY@VERSION FIXTURE — records in BUILT that a positive Release of
# FIXTURE built ENTITY at VERSION: BUILT holds, for each, the fixtures that built
# it, space-separated.
# shellcheck disable=SC2329 # called from judge_build, which bounded_jobs reaches by name
built_by() {
  [[ " ${BUILT[$1]:-} " == *" $2 "* ]] || BUILT[$1]="${BUILT[$1]:+${BUILT[$1]} }$2"
}

# every_reaching_fixture_built ENTITY VERSION — whether the run built ENTITY at
# VERSION in every fixture whose lock reaches it. A finding's id carries names a
# fixture gives, an instance's among them, so a fixture built says nothing of
# the findings another shows. --all builds every fixture.
every_reaching_fixture_built() {
  local fx key built=" ${BUILT[$1@$2]:-} "
  [ "$MODE" = staged ] || return 0
  key="$(entry_key "$1" "$2")"
  for fx in ${REACH[$key]:-}; do
    [[ $built == *" $fx "* ]] || return 1
  done
}

# judge_known — holds every finding to the known-findings file and the file to the
# findings: a finding is refused unless an entry lists its id for the entity
# version it is attributed to; an entry judged is refused when its version is not
# published, and as stale when every fixture reaching that version built it and
# its finding did not appear. --all judges every entry, refusing one whose
# version no fixture built; --staged judges those the commit adds and those
# naming a version it built.
judge_known() {
  local fx name boundary id attr message row entity version
  local -A listed=() produced=()
  load_known
  for row in ${KNOWN[@]+"${KNOWN[@]}"}; do listed[$row]=1; done
  while IFS=$'\t' read -r fx name boundary id attr message; do
    produced["$attr"$'\t'"$id"]=1
    # A validator's message may end its own sentence; the refusal ends it once.
    message="${message%.}"
    [ -z "${listed["$attr"$'\t'"$id"]+set}" ] || continue
    if [ "$attr" = - ]; then
      refuse "$fx/$name: dist/$boundary: $id — $message. No catalog entity version answers for it, so it cannot be listed as known: mend the fixture."
    elif recorded_published "${attr%@*}" "${attr##*@}"; then
      refuse "$fx/$name: dist/$boundary: $id, from $attr — $message. $attr is published and cannot change: list the finding in $KNOWN_FINDINGS, its entity ${attr%@*}, version ${attr##*@}, this id and the reason, naming what in that version causes it."
    else
      refuse "$fx/$name: dist/$boundary: $id, from $attr — $message. $attr is not published, so it can still change: mend it there."
    fi
  done <"$TMP/findings"
  for row in ${KNOWN[@]+"${KNOWN[@]}"}; do
    entity="${row%%@*}"
    version="${row#*@}"
    version="${version%%$'\t'*}"
    id="${row#*$'\t'}"
    [ "$MODE" = all ] || [ -n "${KNOWN_ADDED[$row]+set}" ] || [ -n "${BUILT[$entity@$version]+set}" ] || continue
    recorded_published "$entity" "$version" ||
      refuse "$KNOWN_FINDINGS: the entry for $entity@$version ($id) names a version not published, as the published record last fetched holds it. A version not yet published can still change, so its finding is mended, not listed: remove the entry and mend the finding."
    if [ -n "${BUILT[$entity@$version]+set}" ]; then
      every_reaching_fixture_built "$entity" "$version" || continue
      [ -n "${produced["$entity@$version"$'\t'"$id"]+set}" ] ||
        refuse "$KNOWN_FINDINGS: the entry for $entity@$version ($id) is stale: every fixture reaching that version built it, and the finding did not appear. Remove the entry."
    elif [ "$MODE" = all ]; then
      refuse "$KNOWN_FINDINGS: the entry for $entity@$version ($id) names a version no fixture under $PROOFS/ builds, so its finding can never be shown: build that version in a fixture, or remove the entry."
    fi
  done
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
  st_cloud_version_unreached
  st_cloud_version_negative_only
  st_library_name_unreadable
  st_clean_commit
  st_gate_unstaged
  st_positive_renders_no_root
  st_known_added_in_file_order
  st_known_one_fixture_of_two_built
  st_known_stale
  st_arm_check_from_index
  st_arm_no_verdict_names_checkout
  st_all_no_fixture
  st_cfnlintrc_reason_missing
  st_cfnlintrc_flow_list
  st_cfnlintrc_entry_not_a_line
  st_cfnlintrc_other_key
  st_cfnlintrc_staged
  st_cfnlintrc_reasons_given
  st_unprimed
  st_primed_for_another_pin_file
  st_cached_tofu_other_version
  st_cached_cfn_lint_other_version
  st_tofu_on_path_unused
  st_binary_missing
  st_binary_below_minimum
  st_binary_between_releases
  st_builds_side_by_side
  st_validators_answer_pins
  st_arm_clean
  st_arm_wrong_type
  st_arm_wrong_type_nested
  st_arm_resource_key_misspelt
  st_arm_template_section_unknown
  st_arm_api_version_uncovered
  st_arm_property_misspelt
  st_arm_composed_clean
  st_arm_documented_clean
  st_arm_documented_other_api_version
  st_arm_documented_misspelt
  st_arm_parameters_clean
  st_arm_parameter_undeclared
  st_arm_parameter_required_missing
  st_arm_parameter_wrong_type
  st_arm_parameter_not_allowed
  st_arm_parameter_array_not_allowed
  st_arm_parameter_array_item_expression
  st_arm_parameter_expression
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

# self_test — runs every case; exits 1 when one does not give its expected
# verdict, and 3 when the cases cannot be set up. Its callers run it in a
# subshell, (self_test), so nothing it sets for the scratch repositories reaches
# the rest of the run.
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
  mkdir -p "$ST_ROOT" || no_verdict "cannot make $ST_ROOT"
  st_stubs || no_verdict "cannot write the stand-ins the cases run under $ST_ROOT"
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
# directory with a known-findings file listing nothing, this repository's
# .cfnlintrc.yaml, a terraform container Recipe carrying the canonical
# pass-through and a fixture reaching it, all committed.
# shellcheck disable=SC2329 # called from the cases, which run by name from ST_CASES
st_repo() {
  ST_N=$((ST_N + 1))
  ST_REPO="$ST_ROOT/repo-$ST_N"
  local recipe="$ST_REPO/$ST_RECIPE"
  mkdir -p "$recipe/module" &&
    cp -R "$HERE" "$ST_REPO/scripts" &&
    printf '{"format": 1, "findings": []}\n' >"$ST_REPO/$KNOWN_FINDINGS" &&
    cp "$TOP/.cfnlintrc.yaml" "$ST_REPO/.cfnlintrc.yaml" &&
    cp "$HERE/container-pass-through/main.tf" "$recipe/module/main.tf" &&
    st_recipe_yaml probe-service >"$recipe/recipe.yaml" &&
    st_fixture probe 1.0.0 &&
    printf 'A scratch repository the self-test judges.\n' >"$ST_REPO/README.md" &&
    git -C "$ST_REPO" init -q &&
    git -C "$ST_REPO" add -- . &&
    git -C "$ST_REPO" commit -q -m base
}

# st_fixture GROUP VERSION — writes in ST_REPO the fixture
# proofs/terraform-google/GROUP, whose Release's lock records the container
# Recipe at VERSION. A stub aggrega builds it into the boundary it renders.
# shellcheck disable=SC2329 # called from the cases, which run by name from ST_CASES
st_fixture() {
  local fx="$ST_REPO/$PROOFS/terraform-google/$1"
  mkdir -p "$fx" &&
    printf 'workspace: {}\n' >"$fx/.aggrega-config.yaml" &&
    printf 'kind: Release\n' >"$fx/release.yaml" &&
    printf '%s\n' "entities:" "    - kind: recipe" "      uri: terraform/probe-service:$2" \
      "      resolved_version: $2" >"$fx/release.lock"
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
# and the environment given, a line on its standard input that no validator it
# runs may read (st_stub_cfn_lint); ST_RC and ST_OUT get its exit status and
# everything it printed.
# shellcheck disable=SC2329 # called from the cases, which run by name from ST_CASES
st_run() {
  local form="$1"
  shift
  ST_RC=0
  ST_OUT="$(cd "$ST_REPO" && env "$@" bash "$ST_REPO/scripts/vendor-validate.sh" "$form" 2>&1 \
    <<<"a line no validator reads")" || ST_RC=$?
}

# st_stubs — the stand-ins the cases run: aggrega binaries answering a version,
# each building one boundary, holding a stack template, an Azure Resource
# Manager template or nothing; and a tofu and a cfn-lint on PATH answering a
# version no pin names.
st_stubs() {
  local a b c low
  IFS=. read -r a b c <<<"$PIN_AGGREGA_MIN"
  if [ "$c" -gt 0 ]; then low="$a.$b.$((c - 1))"
  elif [ "$b" -gt 0 ]; then low="$a.$((b - 1)).99"
  else low="$((a - 1)).99.99"
  fi
  ST_BELOW_MIN="$low"
  mkdir -p "$ST_ROOT/bin" "$ST_ROOT/path" &&
    st_stub_aggrega "$ST_ROOT/bin/aggrega-at-minimum" "$PIN_AGGREGA_MIN" cloudformation &&
    st_stub_aggrega "$ST_ROOT/bin/aggrega-below-minimum" "$ST_BELOW_MIN" cloudformation &&
    st_stub_aggrega "$ST_ROOT/bin/aggrega-between-releases" "$PIN_AGGREGA_MIN-41-g697285c71-dirty" cloudformation &&
    st_stub_aggrega "$ST_ROOT/bin/aggrega-arm" "$PIN_AGGREGA_MIN" arm &&
    st_stub_aggrega "$ST_ROOT/bin/aggrega-no-root" "$PIN_AGGREGA_MIN" none &&
    st_stub_tofu "$ST_ROOT/path/tofu" 0.0.0 &&
    st_stub_cfn_lint "$ST_ROOT/path/cfn-lint" 0.0.0
}

# st_render ROOT — the shell line a stub aggrega renders ROOT with, in the
# boundary dist/main of the directory it runs in: cloudformation, a stack
# template declaring nothing; arm, an Azure Resource Manager template declaring
# nothing; none, nothing at all. The line holds no &, which a bash replacing a
# pattern with it would read as the text matched.
# shellcheck disable=SC2329 # called from the stubs, which the cases write
st_render() {
  case "$1" in
    cloudformation)
      printf '%s' "mkdir -p dist/main/cloudformation || exit 1; printf '{\"AWSTemplateFormatVersion\": \"2010-09-09\", \"Resources\": {}}\\n' >dist/main/cloudformation/cloudformation-stack.json" ;;
    arm) printf '%s' "mkdir -p dist/main/arm || exit 1; printf '{\"resources\": {}}\\n' >dist/main/arm/arm-template.json" ;;
    none) printf '%s' "mkdir -p dist/main" ;;
  esac
}

# st_stub_aggrega FILE VERSION ROOT — an aggrega answering VERSION, and building
# one boundary holding ROOT (st_render) in the directory it runs in.
st_stub_aggrega() {
  local text
  text="$(cat <<'END_OF_STUB'
#!/bin/sh
case "$1" in
  version) printf '{"version": "@VERSION@", "commit": "0000000"}\n' ;;
  build) @RENDER@ ;;
  *) exit 2 ;;
esac
END_OF_STUB
)"
  text="${text//@VERSION@/$2}"
  printf '%s\n' "${text//@RENDER@/$(st_render "$3")}" >"$1" && chmod +x "$1"
}
st_stub_tofu() {
  printf '#!/bin/sh\nprintf %s\n' "'{\"terraform_version\": \"$2\"}\\n'" >"$1" && chmod +x "$1"
}
# st_stub_cfn_lint FILE VERSION — a cfn-lint answering VERSION to --version and,
# linting, a reading holding no finding. The run gives cfn-lint nothing to read
# on its standard input, and each case's run is handed a line there (st_run), so
# one that reads a line exits 9, naming it.
st_stub_cfn_lint() {
  local text
  text="$(cat <<'END_OF_STUB'
#!/bin/sh
case "$1" in
  --version) echo "cfn-lint @VERSION@" ;;
  *)
    if read -r line; then
      echo "cfn-lint read its standard input: $line" >&2
      exit 9
    fi
    echo '[]' ;;
esac
END_OF_STUB
)"
  printf '%s\n' "${text//@VERSION@/$2}" >"$1" && chmod +x "$1"
}
# st_stub_python FILE — a Python that is the python3 on PATH.
# shellcheck disable=SC2329 # called from st_cache, which the cases call
st_stub_python() {
  printf '#!/bin/sh\nexec python3 "$@"\n' >"$1" && chmod +x "$1"
}

# st_stub_nproc FILE COUNT — an nproc counting COUNT processing units.
# shellcheck disable=SC2329 # called from the cases, which run by name from ST_CASES
st_stub_nproc() {
  printf '#!/bin/sh\necho %s\n' "$2" >"$1" && chmod +x "$1"
}

# st_stub_aggrega_side_by_side FILE LOG — an aggrega answering the oldest version
# this script accepts, and building a Release in the directory it runs in: a
# negative one halts naming the planted fault, any other renders one boundary
# holding a stack template (st_render). While LOG/meet exists, each build first waits, ten seconds at
# most, until another runs beside it, marking LOG/met once one does; a negative
# one then takes half a second longer; and each adds its Release to LOG/ended as
# it ends.
# shellcheck disable=SC2329 # called from the cases, which run by name from ST_CASES
st_stub_aggrega_side_by_side() {
  local text
  text="$(cat <<'END_OF_STUB'
#!/bin/sh
case "$1" in
  version) printf '{"version": "@VERSION@", "commit": "0000000"}\n'; exit 0 ;;
  build) ;;
  *) exit 2 ;;
esac
log='@LOG@' release='' prev='' meet=0 status=0
for arg in "$@"; do
  [ "$prev" != --release ] || release="$arg"
  prev="$arg"
done
if [ -e "$log/meet" ]; then
  meet=1
  : >"$log/running.$release"
  n=0
  until [ -e "$log/met" ] || [ "$n" -ge 100 ]; do
    if [ "$(ls -- "$log" | grep -c '^running\.')" -ge 2 ]; then
      : >"$log/met"
    else
      sleep 0.1
      n=$((n + 1))
    fi
  done
  rm -f -- "$log/running.$release"
fi
case "$release" in
  release-negative-*)
    [ "$meet" = 0 ] || sleep 0.5
    echo "rendering halted: the planted fault"
    status=1 ;;
  *) @RENDER@ ;;
esac
[ "$meet" = 0 ] || echo "$release" >>"$log/ended"
exit "$status"
END_OF_STUB
)"
  text="${text//@VERSION@/$PIN_AGGREGA_MIN}"
  text="${text//@RENDER@/$(st_render cloudformation)}"
  printf '%s\n' "${text//@LOG@/$2}" >"$1" && chmod +x "$1"
}

# st_untimed — standard input, with every time a run prints, <seconds> s, read
# as N s.
# shellcheck disable=SC2329 # called from the cases, which run by name from ST_CASES
st_untimed() {
  sed -E 's/[0-9]+\.[0-9] s/N s/g'
}

# st_cache HOME TOFU CFN_LINT [DIGEST] — a primed cache under HOME, for DIGEST
# (default: this pin file's), whose tofu and cfn-lint answer the versions given
# and whose Python is the python3 on PATH.
# shellcheck disable=SC2329 # called from the cases, which run by name from ST_CASES
st_cache() {
  local dir="$1/.cache/aggrega/vendor-validators/${4:-$PIN_DIGEST}"
  mkdir -p "$dir/opentofu" "$dir/venv/bin" &&
    st_stub_tofu "$dir/opentofu/tofu" "$2" &&
    st_stub_cfn_lint "$dir/venv/bin/cfn-lint" "$3" &&
    st_stub_python "$dir/venv/bin/python" &&
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

# st_next_version — stages, in ST_REPO, the container Recipe's next version,
# carrying the canonical pass-through, and an edited README.
# shellcheck disable=SC2329 # called from the cases, which run by name from ST_CASES
st_next_version() {
  local next="$TF_RECIPES/probe-service/1.1.0"
  mkdir -p "$ST_REPO/$next/module" &&
    cp "$ST_REPO/$CANONICAL" "$ST_REPO/$next/module/main.tf" &&
    st_recipe_yaml probe-service >"$ST_REPO/$next/recipe.yaml" &&
    printf 'Edited.\n' >>"$ST_REPO/README.md" &&
    git -C "$ST_REPO" add -- "$next" README.md
}

# shellcheck disable=SC2329 # a case, run by name from ST_CASES
st_cloud_version_unreached() {
  { st_repo && st_next_version; } || { st_broken "stage a Recipe version"; return; }
  st_run --staged
  st_caught "a cloud Recipe version the commit adds, which no fixture reaches" 1 \
    "$TF_RECIPES/probe-service/1.1.0: a cloud Recipe version" "no fixture under $PROOFS/ builds it"
}

# The same version, reached by a fixture whose lock records it.
# shellcheck disable=SC2329 # a case, run by name from ST_CASES
st_clean_commit() {
  local home="$ST_ROOT/home-$((ST_N + 1))"
  { st_repo && st_cache "$home" "$PIN_TOFU_VERSION" "${PIN_PYTHON[cfn-lint]}" && st_next_version &&
    st_fixture probe-next 1.1.0 && git -C "$ST_REPO" add -- "$PROOFS"; } || { st_broken "stage a clean change"; return; }
  st_run --staged HOME="$home" AGGREGA_BIN="$ST_ROOT/bin/aggrega-at-minimum"
  st_passed "a clean commit: a container Recipe version a fixture reaches, carrying the canonical pass-through"
}

# The same version, recorded only by the lock of a negative Release, which halts
# before any validator runs.
# shellcheck disable=SC2329 # a case, run by name from ST_CASES
st_cloud_version_negative_only() {
  local fx
  { st_repo && st_next_version && fx="$ST_REPO/$PROOFS/terraform-google/probe-negative" && mkdir -p "$fx" &&
    printf 'workspace: {}\n' >"$fx/.aggrega-config.yaml" &&
    printf 'kind: Release\n' >"$fx/release-negative-fault.yaml" &&
    printf '%s\n' "entities:" "    - kind: recipe" "      uri: terraform/probe-service:1.1.0" \
      "      resolved_version: 1.1.0" >"$fx/release-negative-fault.lock" &&
    printf 'the planted fault\n' >"$fx/release-negative-fault.expect" &&
    git -C "$ST_REPO" add -- "$PROOFS"; } || { st_broken "stage a negative Release"; return; }
  st_run --staged
  st_caught "a cloud Recipe version the commit adds, which only a negative Release reaches" 1 \
    "$TF_RECIPES/probe-service/1.1.0: a cloud Recipe version" "only a negative Release records it"
}

# A library version whose YAML writes its name indented four spaces under
# metadata:, where the selection reads it at two.
# shellcheck disable=SC2329 # a case, run by name from ST_CASES
st_library_name_unreadable() {
  local lib="$CATALOG_ROOT/mappinglibrary/probe-mappings/1.0.0"
  { st_repo && mkdir -p "$ST_REPO/$lib" &&
    printf '%s\n' "apiVersion: aggrega.ai/v1beta1" "kind: MappingLibrary" "metadata:" "    name: ProbeMappings" \
      "    version: 1.0.0" "spec:" "  mappings: {}" >"$ST_REPO/$lib/library.yaml" &&
    git -C "$ST_REPO" add -- "$lib"; } || { st_broken "stage a library"; return; }
  st_run --staged
  st_caught "a library version the commit adds, whose name the selection cannot read" 1 "$lib: a library version"
}

# A library the gate sources, changed in the working tree and not staged, while
# the commit stages something else.
# shellcheck disable=SC2329 # a case, run by name from ST_CASES
st_gate_unstaged() {
  { st_repo && printf '# Changed.\n' >>"$ST_REPO/scripts/lib/bounded-jobs.sh" &&
    printf 'Edited.\n' >>"$ST_REPO/README.md" && git -C "$ST_REPO" add -- README.md; } ||
    { st_broken "change a file of the gate"; return; }
  st_run --staged
  st_caught "a file of the gate changed in the working tree and not staged" 1 \
    "scripts/lib/bounded-jobs.sh: changed in the working tree and not staged"
}

# shellcheck disable=SC2329 # a case, run by name from ST_CASES
st_positive_renders_no_root() {
  local home="$ST_ROOT/home-$((ST_N + 1))"
  { st_repo && st_cache "$home" "$PIN_TOFU_VERSION" "${PIN_PYTHON[cfn-lint]}"; } || { st_broken "make a cache"; return; }
  st_run --all HOME="$home" AGGREGA_BIN="$ST_ROOT/bin/aggrega-no-root"
  st_caught "a positive Release whose build renders no root a validator reads" 1 \
    "$PROOFS/terraform-google/probe/release.yaml: a positive Release whose build renders no root"
}

# st_known_entry ENTITY ID — one entry of a known-findings file, at version 1.0.0.
# shellcheck disable=SC2329 # called from the cases, which run by name from ST_CASES
st_known_entry() {
  printf '{"entity": "%s", "version": "1.0.0", "id": "%s", "reason": "The planted fault."}' "$1" "$2"
}

# Entries the commit adds, each naming a version no fixture builds: each is
# refused, in the order the file holds them.
# shellcheck disable=SC2329 # a case, run by name from ST_CASES
st_known_added_in_file_order() {
  local name entries="" want="" got label="entries the commit adds to the known findings, refused in the order the file holds them"
  for name in probe-f probe-a probe-e probe-b probe-d probe-c probe-h probe-g; do
    entries="${entries:+$entries, }$(st_known_entry "recipe/terraform/$name" "cfn-lint|E3002|Resources/Planted/Properties/X")"
    want="$want recipe/terraform/$name@"
  done
  { st_repo && printf '{"format": 1, "findings": [%s]}\n' "$entries" >"$ST_REPO/$KNOWN_FINDINGS" &&
    git -C "$ST_REPO" add -- "$KNOWN_FINDINGS"; } || { st_broken "stage the known findings"; return; }
  st_run --staged
  got="$(grep -o 'the entry for recipe/terraform/probe-[a-h]@' <<<"$ST_OUT" | sed 's/^the entry for / /' | tr -d '\n')"
  if [ "$ST_RC" -ne 1 ] || [ "$got" != "$want" ]; then
    ST_OUT="refused in the order:$got"$'\n'"$ST_OUT"
    st_failed "$label" "exit 1, the entries refused in the order:$want"
    return
  fi
  printf '  caught  %s\n' "$label"
}

# st_known_two_fixtures — makes ST_REPO, then commits a second fixture,
# probe-other, reaching the container Recipe at 1.0.0 as probe does, that version
# recorded as published, and a known finding of it that probe-other alone would
# show, a finding whose id carries a name probe-other gives.
# shellcheck disable=SC2329 # called from the cases, which run by name from ST_CASES
st_known_two_fixtures() {
  st_repo && st_fixture probe-other 1.0.0 &&
    st_publish "hub.aggrega.ai/${ST_RECIPE#"$CATALOG_ROOT"/}" &&
    printf '{"format": 1, "findings": [%s]}\n' \
      "$(st_known_entry recipe/terraform/probe-service "cfn-lint|E3002|Resources/ProbeOther/Properties/Planted")" \
      >"$ST_REPO/$KNOWN_FINDINGS" &&
    git -C "$ST_REPO" add -- "$PROOFS" "$KNOWN_FINDINGS" && git -C "$ST_REPO" commit -q -m "a second fixture"
}

# A commit reaching probe alone builds one of the two fixtures reaching the
# version, so the entry naming what probe-other shows is not judged stale.
# shellcheck disable=SC2329 # a case, run by name from ST_CASES
st_known_one_fixture_of_two_built() {
  local home="$ST_ROOT/home-$((ST_N + 1))"
  { st_known_two_fixtures && st_cache "$home" "$PIN_TOFU_VERSION" "${PIN_PYTHON[cfn-lint]}" &&
    printf '# Edited.\n' >>"$ST_REPO/$PROOFS/terraform-google/probe/release.yaml" &&
    git -C "$ST_REPO" add -- "$PROOFS"; } || { st_broken "stage a fixture"; return; }
  st_run --staged HOME="$home" AGGREGA_BIN="$ST_ROOT/bin/aggrega-at-minimum"
  st_passed "a known finding of a version two fixtures reach, kept while the commit builds one of them"
}

# The same entry, with the commit reaching both fixtures.
# shellcheck disable=SC2329 # a case, run by name from ST_CASES
st_known_stale() {
  local home="$ST_ROOT/home-$((ST_N + 1))"
  { st_known_two_fixtures && st_cache "$home" "$PIN_TOFU_VERSION" "${PIN_PYTHON[cfn-lint]}" &&
    printf '# Edited.\n' >>"$ST_REPO/$PROOFS/terraform-google/probe/release.yaml" &&
    printf '# Edited.\n' >>"$ST_REPO/$PROOFS/terraform-google/probe-other/release.yaml" &&
    git -C "$ST_REPO" add -- "$PROOFS"; } || { st_broken "stage two fixtures"; return; }
  st_run --staged HOME="$home" AGGREGA_BIN="$ST_ROOT/bin/aggrega-at-minimum"
  st_caught "a known finding that every fixture reaching its version, built, does not show" 1 \
    "the entry for recipe/terraform/probe-service@1.0.0 (cfn-lint|E3002|Resources/ProbeOther/Properties/Planted) is stale"
}

# st_arm_check_stub FILE VERDICT — writes at FILE a stand-in for the Azure
# Resource Manager check: planted, one finding; clean, none; no-verdict, no
# verdict, naming the command that primes the cache beside it, as the check does.
# shellcheck disable=SC2329 # called from the cases, which run by name from ST_CASES
st_arm_check_stub() {
  case "$2" in
    planted)
      printf '%s\n' 'import sys' \
        'print("arm|type|arm/arm-template.json/app/properties/planted\tthe planted fault")' \
        'print("1 finding(s)")' 'sys.exit(1)' ;;
    clean) printf '%s\n' 'print("0 finding(s)")' ;;
    no-verdict)
      printf '%s\n' 'import os, sys' \
        'prime = os.path.join(os.path.dirname(os.path.abspath(__file__)), "vendor-validate.sh") + " --prime"' \
        'print(f"no verdict: a schema is missing. Prime the cache (network, once): {prime}", file=sys.stderr)' \
        'sys.exit(3)' ;;
  esac >"$1"
}

# The index holds a check finding the planted fault, the working tree one
# finding nothing: the run judges by the one the index holds.
# shellcheck disable=SC2329 # a case, run by name from ST_CASES
st_arm_check_from_index() {
  local home="$ST_ROOT/home-$((ST_N + 1))"
  { st_repo && st_cache "$home" "$PIN_TOFU_VERSION" "${PIN_PYTHON[cfn-lint]}" &&
    st_arm_check_stub "$ST_REPO/scripts/vendor-validate-arm.py" planted &&
    git -C "$ST_REPO" add -- scripts/vendor-validate-arm.py &&
    st_arm_check_stub "$ST_REPO/scripts/vendor-validate-arm.py" clean; } ||
    { st_broken "stage an Azure Resource Manager check"; return; }
  st_run --all HOME="$home" AGGREGA_BIN="$ST_ROOT/bin/aggrega-arm"
  st_caught "an Azure Resource Manager check changed in the working tree alone, the one the index holds judging" 1 \
    "arm|type|arm/arm-template.json/app/properties/planted"
}

# The check the index holds gives no verdict, naming the command that primes the
# cache beside it: the run names that command in this checkout.
# shellcheck disable=SC2329 # a case, run by name from ST_CASES
st_arm_no_verdict_names_checkout() {
  local home="$ST_ROOT/home-$((ST_N + 1))"
  { st_repo && st_cache "$home" "$PIN_TOFU_VERSION" "${PIN_PYTHON[cfn-lint]}" &&
    st_arm_check_stub "$ST_REPO/scripts/vendor-validate-arm.py" no-verdict &&
    git -C "$ST_REPO" add -- scripts/vendor-validate-arm.py; } ||
    { st_broken "stage an Azure Resource Manager check"; return; }
  st_run --all HOME="$home" AGGREGA_BIN="$ST_ROOT/bin/aggrega-arm"
  st_caught "the Azure Resource Manager check giving no verdict, the prime command named in this checkout" 3 \
    "Prime the cache (network, once): $ST_REPO/scripts/vendor-validate.sh --prime"
}

# shellcheck disable=SC2329 # a case, run by name from ST_CASES
st_all_no_fixture() {
  local home="$ST_ROOT/home-$((ST_N + 1))"
  { st_repo && st_cache "$home" "$PIN_TOFU_VERSION" "${PIN_PYTHON[cfn-lint]}" &&
    git -C "$ST_REPO" rm -r -q -- "$PROOFS"; } || { st_broken "remove the fixture"; return; }
  st_run --all HOME="$home" AGGREGA_BIN="$ST_ROOT/bin/aggrega-at-minimum"
  st_caught "--all over an index holding no fixture" 1 "no fixture under $PROOFS/"
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

# The list's entry written as a list in brackets on the line below ignore_checks.
# shellcheck disable=SC2329 # a case, run by name from ST_CASES
st_cfnlintrc_entry_not_a_line() {
  { st_repo && st_cfnlintrc "ignore_checks:" "  [E3012]  # The reason E3012 is ignored."; } ||
    { st_broken "stage .cfnlintrc.yaml"; return; }
  st_run --all
  st_caught "a rule ignored in .cfnlintrc.yaml on a line under ignore_checks that is no entry - <rule>" 1 \
    ".cfnlintrc.yaml:2:" "[E3012]"
}

# A key beside ignore_checks, which would change what cfn-lint reads.
# shellcheck disable=SC2329 # a case, run by name from ST_CASES
st_cfnlintrc_other_key() {
  { st_repo && st_cfnlintrc "ignore_checks: []" "ignore_templates:" "  - cloudformation/*.json"; } ||
    { st_broken "stage .cfnlintrc.yaml"; return; }
  st_run --all
  st_caught "a key in .cfnlintrc.yaml other than ignore_checks" 1 ".cfnlintrc.yaml:2:" "ignore_templates"
}

# The rule also judges a commit changing the file.
# shellcheck disable=SC2329 # a case, run by name from ST_CASES
st_cfnlintrc_staged() {
  { st_repo && st_cfnlintrc "# cfn-lint's configuration." "ignore_checks:" "  - E3012"; } ||
    { st_broken "stage .cfnlintrc.yaml"; return; }
  st_run --staged
  st_caught "a commit changing .cfnlintrc.yaml to ignore a rule with no reason" 1 ".cfnlintrc.yaml:3:" "E3012"
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

# Two Releases of one fixture, a negative one first in byte order and a positive
# one, built by a run counting one processing unit, room for one build at a
# time, then by a run counting three, room for two. The second prints what the
# first prints, line for line but for the seconds, and exits as it does, though
# in it the two builds run at once and the positive one ends first. Where this
# bash or the memory available leaves room for one build at a time, the second
# run builds one at a time too, and the outputs alone are compared.
# shellcheck disable=SC2329 # a case, run by name from ST_CASES
st_builds_side_by_side() {
  local home="$ST_ROOT/home-$((ST_N + 1))" log="$ST_ROOT/side-by-side" fx serial serial_rc together=0
  local label="a fixture's two Releases built side by side, the positive one ending first, reported as a run one at a time reports them"
  { st_repo && st_cache "$home" "$PIN_TOFU_VERSION" "${PIN_PYTHON[cfn-lint]}" &&
    fx="$ST_REPO/$PROOFS/terraform-google/probe" &&
    printf 'kind: Release\n' >"$fx/release-negative-fault.yaml" &&
    cp "$fx/release.lock" "$fx/release-negative-fault.lock" &&
    printf 'the planted fault\n' >"$fx/release-negative-fault.expect" &&
    git -C "$ST_REPO" add -- "$PROOFS" &&
    mkdir -p "$log" "$ST_ROOT/one-unit" "$ST_ROOT/three-units" &&
    st_stub_nproc "$ST_ROOT/one-unit/nproc" 1 && st_stub_nproc "$ST_ROOT/three-units/nproc" 3 &&
    st_stub_aggrega_side_by_side "$ST_ROOT/bin/aggrega-side-by-side" "$log"; } ||
    { st_broken "stage a second Release"; return; }
  st_run --all HOME="$home" AGGREGA_BIN="$ST_ROOT/bin/aggrega-side-by-side" PATH="$ST_ROOT/one-unit:$PATH"
  serial_rc="$ST_RC"
  serial="$(st_untimed <<<"$ST_OUT")"
  if [ "$serial_rc" -ne 0 ] ||
    [[ $serial != *"/probe/release-negative-fault.yaml halts as its .expect says"*$'\n'*"/probe/release.yaml built in"* ]]; then
    st_failed "$label" "the run one at a time to exit 0, reporting the negative Release, then the positive one"
    return
  fi
  if [ "$(PATH="$ST_ROOT/three-units:$PATH" build_bound)" -ge 2 ]; then
    together=1
    : >"$log/meet" || { st_broken "write $log/meet"; return; }
  fi
  st_run --all HOME="$home" AGGREGA_BIN="$ST_ROOT/bin/aggrega-side-by-side" PATH="$ST_ROOT/three-units:$PATH"
  if [ "$ST_RC" -ne "$serial_rc" ] || [ "$(st_untimed <<<"$ST_OUT")" != "$serial" ]; then
    ST_OUT="$(diff <(printf '%s\n' "$serial") <(st_untimed <<<"$ST_OUT"))"
    st_failed "$label" "exit $serial_rc and the output of the run one at a time"
    return
  fi
  if [ "$together" = 1 ] && { [ ! -e "$log/met" ] || [ "$(head -n 1 "$log/ended")" != release.yaml ]; }; then
    ST_OUT="the builds ended in this order: $(tr '\n' ' ' <"$log/ended")"
    [ -e "$log/met" ] || ST_OUT="the two builds never ran at once; $ST_OUT"
    st_failed "$label" "the two builds to run at once, the positive one ending first"
    return
  fi
  st_passed "$label"
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

# st_arm_documented_template FILE — a clean template holding one model
# deployment, Microsoft.CognitiveServices/accounts/deployments at 2026-05-01,
# whose properties carry modelProviderData, a property the resource provider
# takes and its specification omits, as an expression over a parameter, as the
# Azure Verified Modules account module writes it.
# shellcheck disable=SC2329 # called from the cases, which run by name from ST_CASES
st_arm_documented_template() {
  cat >"$1" <<'END_OF_TEMPLATE'
{
  "$schema": "https://schema.management.azure.com/schemas/2019-04-01/deploymentTemplate.json#",
  "languageVersion": "2.0",
  "contentVersion": "1.0.0.0",
  "parameters": {
    "modelProviderData": {
      "type": "object",
      "nullable": true
    }
  },
  "resources": {
    "chat": {
      "type": "Microsoft.CognitiveServices/accounts/deployments",
      "apiVersion": "2026-05-01",
      "name": "[format('{0}/{1}', 'example-account', 'example-chat')]",
      "sku": {
        "name": "Standard",
        "capacity": 1
      },
      "properties": {
        "model": {
          "format": "OpenAI",
          "name": "gpt-4o-mini"
        },
        "modelProviderData": "[parameters('modelProviderData')]"
      }
    }
  }
}
END_OF_TEMPLATE
}

# st_arm_parameters_template FILE — a clean template holding one nested
# deployment, evaluated in its own scope, and the parameters its template
# declares: a required string with length bounds, a string with allowedValues, a
# string with a default and not passed, an int with a default and a minValue,
# an int with allowedValues passed as an expression, an int whose whole entry is
# an expression, as Bicep writes an entry passed under a condition, a
# securestring passed as a Key Vault reference, an array, an array with
# allowedValues, a parameter of a type its definitions declare, and a nullable
# object not passed.
# shellcheck disable=SC2329 # called from the cases, which run by name from ST_CASES
st_arm_parameters_template() {
  cat >"$1" <<'END_OF_TEMPLATE'
{
  "$schema": "https://schema.management.azure.com/schemas/2019-04-01/deploymentTemplate.json#",
  "languageVersion": "2.0",
  "contentVersion": "1.0.0.0",
  "parameters": {
    "zone": {
      "type": "int",
      "defaultValue": -1
    }
  },
  "resources": {
    "database": {
      "type": "Microsoft.Resources/deployments",
      "apiVersion": "2025-04-01",
      "name": "example-database",
      "properties": {
        "expressionEvaluationOptions": {
          "scope": "inner"
        },
        "mode": "Incremental",
        "parameters": {
          "name": {
            "value": "example-db"
          },
          "tier": {
            "value": "GeneralPurpose"
          },
          "storageSizeGB": {
            "value": 64
          },
          "availabilityZone": {
            "value": "[parameters('zone')]"
          },
          "administratorLoginPassword": {
            "reference": {
              "keyVault": {
                "id": "/subscriptions/00000000-0000-0000-0000-000000000000/resourceGroups/example-rg/providers/Microsoft.KeyVault/vaults/example-vault"
              },
              "secretName": "example-password"
            }
          },
          "databases": {
            "value": [
              {
                "name": "orders"
              }
            ]
          },
          "highAvailability": {
            "value": "Disabled"
          },
          "zones": {"value": [1, 2]},
          "backupRetentionDays": "[if(equals(parameters('zone'), -1), createObject('value', 7), createObject('value', 14))]"
        },
        "template": {
          "$schema": "https://schema.management.azure.com/schemas/2019-04-01/deploymentTemplate.json#",
          "languageVersion": "2.0",
          "contentVersion": "1.0.0.0",
          "definitions": {
            "highAvailabilityType": {
              "type": "string",
              "allowedValues": ["Disabled", "ZoneRedundant"]
            }
          },
          "parameters": {
            "name": {"type": "string", "minLength": 3, "maxLength": 63},
            "tier": {"type": "string", "allowedValues": ["Burstable", "GeneralPurpose", "MemoryOptimized"]},
            "skuName": {"type": "string", "defaultValue": "Standard_D2ds_v5"},
            "storageSizeGB": {"type": "int", "minValue": 32, "defaultValue": 32},
            "availabilityZone": {"type": "int", "allowedValues": [-1, 1, 2, 3]},
            "administratorLoginPassword": {"type": "securestring"},
            "databases": {"type": "array"},
            "highAvailability": {"$ref": "#/definitions/highAvailabilityType"},
            "backupRetentionDays": {"type": "int", "minValue": 7, "maxValue": 35, "defaultValue": 7},
            "zones": {"type": "array", "allowedValues": [1, 2, 3], "defaultValue": []},
            "tags": {"type": "object", "nullable": true}
          },
          "resources": {}
        }
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

# Rule 5 lists modelProviderData on a model deployment at 2026-05-01 alone.
# shellcheck disable=SC2329 # a case, run by name from ST_CASES
st_arm_documented_clean() {
  st_arm_run st_arm_documented_template || { st_broken "write a template"; return; }
  st_passed "a property the resource provider takes and its specification omits, where the reading rules list it (modelProviderData on a model deployment at 2026-05-01)"
}

# shellcheck disable=SC2329 # a case, run by name from ST_CASES
st_arm_documented_other_api_version() {
  st_arm_run st_arm_documented_template 's/"apiVersion": "2026-05-01"/"apiVersion": "2026-07-01"/' ||
    { st_broken "write a template"; return; }
  st_arm_caught "a property the reading rules list at one apiVersion, written at another (modelProviderData at 2026-07-01)" \
    "arm|additionalProperties|$ST_ARM_TEMPLATE/chat/properties/modelProviderData"
}

# shellcheck disable=SC2329 # a case, run by name from ST_CASES
st_arm_documented_misspelt() {
  st_arm_run st_arm_documented_template 's/"modelProviderData": "\[/"modelProviderDta": "[/' ||
    { st_broken "write a template"; return; }
  st_arm_caught "a misspelling of a property the reading rules list (modelProviderDta)" \
    "arm|additionalProperties|$ST_ARM_TEMPLATE/chat/properties/modelProviderDta"
}

# shellcheck disable=SC2329 # a case, run by name from ST_CASES
st_arm_parameters_clean() {
  st_arm_run st_arm_parameters_template || { st_broken "write a template"; return; }
  st_passed "a nested deployment passing the parameters its template declares: literals of their types and allowed values, an expression, a Key Vault reference, defaults and a nullable one left out"
}

# shellcheck disable=SC2329 # a case, run by name from ST_CASES
st_arm_parameter_undeclared() {
  st_arm_run st_arm_parameters_template '0,/"storageSizeGB": {/s//"storageSizeGBB": {/' ||
    { st_broken "write a template"; return; }
  st_arm_caught "a parameter passed to a nested deployment that its template does not declare (storageSizeGBB)" \
    "arm|parameter-key|$ST_ARM_TEMPLATE/database/properties/parameters/storageSizeGBB"
}

# shellcheck disable=SC2329 # a case, run by name from ST_CASES
st_arm_parameter_required_missing() {
  st_arm_run st_arm_parameters_template 's/"skuName": {"type": "string", "defaultValue": "Standard_D2ds_v5"}/"skuName": {"type": "string"}/' ||
    { st_broken "write a template"; return; }
  st_arm_caught "a parameter a nested deployment's template requires and the deployment does not pass (skuName)" \
    "arm|parameter-key|$ST_ARM_TEMPLATE/database/properties/parameters/skuName"
}

# shellcheck disable=SC2329 # a case, run by name from ST_CASES
st_arm_parameter_wrong_type() {
  st_arm_run st_arm_parameters_template 's/"value": 64/"value": "64"/' || { st_broken "write a template"; return; }
  st_arm_caught "a literal of another type than the parameter declares (storageSizeGB \"64\")" \
    "arm|parameter-value|$ST_ARM_TEMPLATE/database/properties/parameters/storageSizeGB"
}

# shellcheck disable=SC2329 # a case, run by name from ST_CASES
st_arm_parameter_not_allowed() {
  st_arm_run st_arm_parameters_template 's/"value": "GeneralPurpose"/"value": "Premium"/' ||
    { st_broken "write a template"; return; }
  st_arm_caught "a literal outside the parameter's allowedValues (tier Premium)" \
    "arm|parameter-value|$ST_ARM_TEMPLATE/database/properties/parameters/tier"
}

# shellcheck disable=SC2329 # a case, run by name from ST_CASES
st_arm_parameter_array_not_allowed() {
  st_arm_run st_arm_parameters_template 's/"zones": {"value": \[1, 2\]}/"zones": {"value": [1, 4]}/' ||
    { st_broken "write a template"; return; }
  st_arm_caught "an item of an array outside the parameter's allowedValues (zones 4)" \
    "arm|parameter-value|$ST_ARM_TEMPLATE/database/properties/parameters/zones"
}

# shellcheck disable=SC2329 # a case, run by name from ST_CASES
st_arm_parameter_array_item_expression() {
  st_arm_run st_arm_parameters_template "s/\"zones\": {\"value\": \\[1, 2\\]}/\"zones\": {\"value\": [1, \"[parameters('zone')]\"]}/" ||
    { st_broken "write a template"; return; }
  st_passed "an item of an array parameter written as an expression, which Resource Manager evaluates when it deploys (zones [parameters('zone')])"
}

# shellcheck disable=SC2329 # a case, run by name from ST_CASES
st_arm_parameter_expression() {
  st_arm_run st_arm_parameters_template 's/"value": 64/"value": "[add(32, 32)]"/' ||
    { st_broken "write a template"; return; }
  st_passed "a parameter passed as an expression, which Resource Manager evaluates when it deploys (storageSizeGB [add(32, 32)])"
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
    if [ "$MODE" = staged ]; then
      gate_unstaged_rule
      [ "$REFUSED" -eq 0 ] || exit 1
    fi
    vendor_text_rule
    pass_through_rule
    fixtures_rule
    SELF_TEST=0
    KNOWN_STAGED=0
    if [ "$MODE" = all ]; then
      cfnlintrc_rule
      [ "${#FIXTURES[@]}" -gt 0 ] ||
        refuse "$PROOFS/: the index holds no fixture under $PROOFS/, so --all would build nothing and no vendor validator would judge any Recipe: restore the fixtures from git and stage them."
      select_fixtures ${FIXTURES[@]+"${FIXTURES[@]}"}
      load_known
    else
      reach_table
      select_staged
    fi
    for fx in ${FIXTURES[@]+"${FIXTURES[@]}"}; do
      [ -z "${SELECTED[$fx]+set}" ] || fixture_shape_rule "$fx"
    done
    [ "$REFUSED" -eq 0 ] || exit 1
    if [ "$MODE" = staged ] && [ "${#SELECTED[@]}" -eq 0 ] && [ "$SELF_TEST" = 0 ]; then
      echo "$ME: passed — no vendor text staged, every container Recipe the commit reaches carries the canonical pass-through, and no fixture reaches what it changes"
      exit 0
    fi
    materialize
    require_validators
    [ "$SELF_TEST" = 0 ] || staged_self_test
    : >"$TMP/findings" || no_verdict "cannot write $TMP/findings"
    for fx in ${FIXTURES[@]+"${FIXTURES[@]}"}; do
      [ -z "${SELECTED[$fx]+set}" ] || queue_fixture "$fx"
    done
    build_fixtures
    judge_known
    [ "$REFUSED" -eq 0 ] || exit 1
    if [ "$MODE" = all ]; then
      echo "$ME: passed — no vendor text, every container Recipe carries the canonical pass-through, every rule $CFNLINTRC ignores carries its reason, every fixture builds as its Releases say, and every finding is listed as known, each entry still shown ($CACHE_DIR)"
    else
      echo "$ME: passed — no vendor text staged, every container Recipe the commit reaches carries the canonical pass-through, and each fixture it reaches builds as its Releases say, every finding listed as known"
    fi
    ;;
  self-test)
    CAUSES=()
    settle_cache
    load_pins
    cache_causes
    [ "${#CAUSES[@]}" -eq 0 ] || no_verdict "${CAUSES[@]}"
    # A case that did not give its verdict exits 1, and no verdict exits 3.
    (self_test) || exit "$?"
    ;;
  prime)
    prime
    ;;
esac
exit 0
