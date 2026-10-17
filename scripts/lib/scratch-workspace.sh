# shellcheck shell=bash
# scripts/lib/scratch-workspace.sh — the Aggrega workspace a run uses when nothing
# else gives it one. Sourced by scripts/publish-diff.sh and
# scripts/published-version-guard.sh; it defines a function and a constant and runs
# nothing.
#
# WHY A RUN NEEDS ONE. A Recipe or FeatureRecipe whose source is fetched from a
# remote registry — a chart in an OCI registry, say — is fetched by `aggrega push`,
# its dry run included, into the artifact cache of the workspace the binary
# resolves. A checkout of this repository on its own, as continuous integration
# checks it out, is in no workspace, and the binary refuses to write a cache into a
# folder nobody chose as one. Naming a scratch folder as the workspace root gives
# the fetch a place the run owns and removes.
#
# WHEN ONE IS NAMED. Only when nothing else decides the workspace: a caller that sets
# AGGREGA_WORKSPACE_ROOT keeps its value, and a run whose folders are inside a
# workspace keeps that workspace, whose configuration then applies as it does to any
# aggrega command run there.
#
# WHO SAYS A FOLDER IS IN NO WORKSPACE. The binary, never this file. How a folder is
# found to be in a workspace is the binary's rule, and a copy of it here would agree
# with the binary only until either changed — after which it could name a scratch
# root over a real workspace, replacing its configuration without a word. The answer
# read is the sentence the binary writes to standard error when it finds no
# workspace, matched by its opening words. That stream is written for people rather
# than scripts, so the sentence may change; if it does, no scratch root is named and
# the fetch refuses as it would with no helper at all, naming AGGREGA_WORKSPACE_ROOT:
# loudly, never with a quiet wrong answer.

# The opening words of the sentence the binary writes to standard error when it
# finds no workspace from the folder it runs in.
NO_WORKSPACE_NOTICE="no Aggrega workspace was found from"

# scratch_workspace_root PARENT DIR... — names a scratch workspace root for the rest
# of the run when nothing else names one. When AGGREGA_WORKSPACE_ROOT is unset or
# empty and the binary in AGGREGA finds no workspace from any DIR — each a folder an
# aggrega call of this run resolves its workspace from — it makes PARENT/workspace
# and exports AGGREGA_WORKSPACE_ROOT naming it, so every later aggrega call, and
# every script the run starts, uses that folder. Otherwise it changes nothing.
#
# PARENT is a temporary directory the caller removes when it exits, which removes
# the scratch workspace with it. A DIR the binary gives no answer for — no binary,
# a configuration it refuses — names nothing, so the next aggrega call reports the
# problem in its own words, as it would without this function. It returns non-zero
# only when PARENT/workspace cannot be made.
scratch_workspace_root() {
  local parent="$1" bin="$AGGREGA" dir said
  shift
  [ -z "${AGGREGA_WORKSPACE_ROOT:-}" ] || return 0
  # The binary is asked from inside each DIR, so a relative path to it is made
  # absolute against the current folder first.
  case "$bin" in
    /*) ;;
    */*) bin="$PWD/$bin" ;;
  esac
  for dir in "$@"; do
    said="$(cd "$dir" && "$bin" config show --workspace 2>&1 >/dev/null)" || return 0
    case "$said" in
      *"$NO_WORKSPACE_NOTICE"*) ;;
      *) return 0 ;;
    esac
  done
  mkdir "$parent/workspace" || return 1
  AGGREGA_WORKSPACE_ROOT="$parent/workspace"
  export AGGREGA_WORKSPACE_ROOT
}
