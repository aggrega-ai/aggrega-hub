# shellcheck shell=bash
# scripts/lib/catalog-entities.sh — which catalog files are publishable entities,
# read the one way every script in this repository reads it. Sourced by
# scripts/publish-diff.sh and scripts/published-version-guard.sh; it defines
# functions and variables and runs nothing.
#
# A caller sets AGGREGA (the binary it publishes or judges with) before calling
# load_publishable_kinds.

# --- The entity kinds the binary publishes -------------------------------------
# The set is not written down here. It is read from the binary that does the
# pushing: `aggrega push --list-kinds` emits every kind `aggrega push` addresses,
# one per line, sorted and undecorated, and that is what this library consumes. So
# a caller cannot name a kind the push path does not handle, nor silently miss one
# it does — the failure that motivated asking in the first place, where an entity
# of a perfectly publishable kind was skipped with no message at all.
#
# A kind a caller declines is its own call, and it passes that exclusion in: what a
# publisher declines to push is decided in the publisher that applies it, and one
# shared exclusion list would let a widening made for one caller take effect
# silently in the others. Manifest / Release never appear in the answer at all,
# for a different reason: they are deployment-side and `aggrega push` addresses
# neither. A YAML with no `kind:` (recipe fragments, source/ files) is never an
# entity.
#
# Asking costs a caller nothing it did not already require: it invokes the same
# binary to push or to compute a digest. That holds from a standalone checkout of
# this repository, which carries no CLI source tree — the query needs a binary, not
# a source tree. What such a checkout gives up is the chance to act on a wrong set
# quietly: a binary that is missing, broken, or too old to answer refuses below,
# before anything is done, rather than skipping entities one at a time with no
# message.
#
# Note that `aggrega get-schema --list` is not this route: it enumerates schemas,
# including deployment-side kinds and the plugin socket contracts, so no filter
# over it yields this answer.
#
# No count is stated anywhere here, on purpose: a count is a third thing to keep
# in step, and it is the number that rots first.

# Kinds whose absence means the QUERY broke rather than that the product changed.
# A plausibility floor expressed as named kinds instead of a minimum count, for
# the same reason no count appears above — and because a publishable set that has
# lost Component or Recipe is not a set the platform could have shipped. Retiring
# one of these genuinely would mean editing this line, which is the correct amount
# of friction.
#
# The floor is written out here rather than read back from the query below, and
# that is the one simplification to resist. A floor derived from the binary's own
# answer would agree with every answer, including an empty one — and agreeing
# with an empty answer is precisely the failure this floor exists to catch. It is
# a deliberate independent statement of part of the set, not a second home for
# it: deriving it from the thing it cross-checks would leave it checking nothing.
PUBLISHABLE_SENTINELS="Component Feature Recipe FeatureRecipe"

PUBLISHABLE_KINDS=""

# load_publishable_kinds EXCLUDED... asks the binary ONCE and fills
# PUBLISHABLE_KINDS with every kind it publishes but the ones named. It refuses —
# non-zero, naming what to fix — when the binary is missing, fails, does not
# understand the query, or answers with a set too small to be real. It never falls
# back to a built-in list: a hard-coded list is the drift this query removes, and
# an empty one would act on nothing while reporting success.
load_publishable_kinds() {
  local answer kind sentinel excluded who
  who="${0##*/}"
  PUBLISHABLE_KINDS=""
  if ! answer="$("$AGGREGA" push --list-kinds)"; then
    echo "$who: cannot read the publishable entity kinds from '$AGGREGA push --list-kinds'." >&2
    echo "  The binary is missing, failed, or predates that flag. Point AGGREGA_BIN at a current" >&2
    echo "  build. Refusing rather than guessing which kinds are entities." >&2
    return 1
  fi
  for sentinel in $PUBLISHABLE_SENTINELS; do
    case $'\n'"$answer"$'\n' in
      *$'\n'"$sentinel"$'\n'*) ;;
      *)
        echo "$who: the publishable entity kinds reported by the binary are missing '$sentinel'." >&2
        echo "  Got: $(printf '%s' "$answer" | tr '\n' ' ')" >&2
        echo "  That kind is load-bearing, so its absence means the query broke rather than that the" >&2
        echo "  publishable set legitimately shrank. Refusing rather than acting on a partial set." >&2
        return 1
        ;;
    esac
  done
  while IFS= read -r kind; do
    [ -n "$kind" ] || continue
    for excluded in "$@"; do
      [ "$kind" = "$excluded" ] && continue 2
    done
    PUBLISHABLE_KINDS="${PUBLISHABLE_KINDS:+$PUBLISHABLE_KINDS }$kind"
  done <<< "$answer"
}

# is_publishable KIND — whether KIND is in the set load_publishable_kinds filled.
is_publishable() {
  case " $PUBLISHABLE_KINDS " in
    *" $1 "*) return 0 ;;
    *) return 1 ;;
  esac
}

# peek_kind prints the top-level `kind:` value of the YAML read from FILE, or from
# standard input when FILE is "-", or nothing.
peek_kind() {
  awk -F':[[:space:]]*' '/^kind:[[:space:]]/{print $2; exit}' "$1" | tr -d '\r'
}
