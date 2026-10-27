# shellcheck shell=bash
# scripts/lib/bounded-jobs.sh — run one command per item, with at most a given
# number running at once, and hand every item's result back in the order the items
# were given. Sourced by scripts/publish-diff.sh and
# scripts/published-version-guard.sh; it defines functions and runs nothing.
#
# WHY THE RESULTS COME BACK IN ORDER. Each item's command is a separate process —
# an `aggrega push`, or its dry run — that spends most of its time waiting on a
# registry and on start-up, so running several at once shortens a run without
# changing any one of them. What must not change is what the run prints and
# records: every item's output whole, never interleaved with another's, in item
# order, and every count, list and verdict derived from those outputs in item order
# too. So no command writes to the terminal while others run: each writes its
# standard output and standard error to files of its own, and the caller reads them
# back item by item, as soon as that item and every item before it have finished.
#
# ONE AT A TIME IS THE RUN IT ALWAYS WAS. With a bound of 1 each command runs in
# the foreground, its standard error reaching the terminal while it runs, and its
# result is handed back before the next starts — the order and the timing of a
# loop over the items.
#
# Running more than one at once needs bash 5.1 or later, for `wait -n -p` over the
# running commands; bounded_jobs_concurrency_available says whether this shell has
# it, so a caller can refuse a bound above 1 before it starts anything.

# bounded_jobs_bound_ok VALUE — succeeds when VALUE is a whole number of at least
# 1, written in decimal digits with no sign and no leading zero.
bounded_jobs_bound_ok() {
  case "$1" in
    '' | 0* | *[!0-9]*) return 1 ;;
  esac
  return 0
}

# bounded_jobs_concurrency_available — succeeds when this shell can run more than
# one command at once here (bash 5.1 or later).
bounded_jobs_concurrency_available() {
  [ "${BASH_VERSINFO[0]}" -gt 5 ] || { [ "${BASH_VERSINFO[0]}" -eq 5 ] && [ "${BASH_VERSINFO[1]}" -ge 1 ]; }
}

# bounded_jobs BOUND DIR RUN CONSUME ITEM... — for each ITEM, at position INDEX
# counted from 0, runs `RUN INDEX ITEM` in a subshell, at most BOUND at once, with
# its standard output written to DIR/INDEX.out. Above a bound of 1 its standard
# error is written to DIR/INDEX.err; at a bound of 1 it reaches the terminal as the
# command runs.
#
# Then, in item order, as soon as an item and every item before it have finished,
# it writes that item's standard error file to standard error and calls
# `CONSUME INDEX ITEM STATUS OUTFILE` in this shell — so CONSUME may add to the
# caller's variables — where STATUS is RUN's exit status and OUTFILE holds what it
# wrote to standard output. Each item's files are removed once CONSUME returns. A
# command that fails does not stop the others. DIR is a directory the caller made
# and removes. Names local to this function begin with _bj_, so a CONSUME that sets
# a variable of the caller's sets the caller's.
bounded_jobs() {
  local _bj_bound="$1" _bj_dir="$2" _bj_run="$3" _bj_consume="$4"
  shift 4
  local -a _bj_items=("$@") _bj_status=()
  local -A _bj_index=()
  local _bj_n="$#" _bj_i=0 _bj_next=0 _bj_pid _bj_rc _bj_p

  if [ "$_bj_bound" -le 1 ]; then
    while [ "$_bj_i" -lt "$_bj_n" ]; do
      _bj_rc=0
      ( "$_bj_run" "$_bj_i" "${_bj_items[_bj_i]}" ) >"$_bj_dir/$_bj_i.out" || _bj_rc=$?
      "$_bj_consume" "$_bj_i" "${_bj_items[_bj_i]}" "$_bj_rc" "$_bj_dir/$_bj_i.out"
      rm -f "$_bj_dir/$_bj_i.out"
      _bj_i=$((_bj_i + 1))
    done
    return 0
  fi

  while [ "$_bj_i" -lt "$_bj_n" ] || [ "${#_bj_index[@]}" -gt 0 ]; do
    if [ "$_bj_i" -lt "$_bj_n" ] && [ "${#_bj_index[@]}" -lt "$_bj_bound" ]; then
      ( "$_bj_run" "$_bj_i" "${_bj_items[_bj_i]}" ) >"$_bj_dir/$_bj_i.out" 2>"$_bj_dir/$_bj_i.err" &
      _bj_index[$!]="$_bj_i"
      _bj_i=$((_bj_i + 1))
      continue
    fi
    # Only the commands this function started are waited for, so a process the
    # caller started earlier is never mistaken for one of them.
    _bj_pid=""
    _bj_rc=0
    wait -n -p _bj_pid "${!_bj_index[@]}" || _bj_rc=$?
    if [ -n "$_bj_pid" ]; then
      _bj_status[${_bj_index[$_bj_pid]}]="$_bj_rc"
      unset "_bj_index[$_bj_pid]"
    else
      # None of them is a child of this shell any longer, so every one has ended
      # without its status being read; each is reported as a failure.
      for _bj_p in "${!_bj_index[@]}"; do
        _bj_status[${_bj_index[$_bj_p]}]=1
      done
      _bj_index=()
    fi
    while [ "$_bj_next" -lt "$_bj_n" ] && [ -n "${_bj_status[_bj_next]+set}" ]; do
      cat "$_bj_dir/$_bj_next.err" >&2
      "$_bj_consume" "$_bj_next" "${_bj_items[_bj_next]}" "${_bj_status[_bj_next]}" "$_bj_dir/$_bj_next.out"
      rm -f "$_bj_dir/$_bj_next.out" "$_bj_dir/$_bj_next.err"
      _bj_next=$((_bj_next + 1))
    done
  done
  return 0
}
