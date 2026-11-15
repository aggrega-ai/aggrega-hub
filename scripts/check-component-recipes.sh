#!/usr/bin/env bash
# SPDX-License-Identifier: Apache-2.0
#
# check-component-recipes.sh — refuse a Component version that no Recipe realizes
# while the version below it has Recipes.
#
# --help is the contract: what it reads, what it refuses, what it does not see, and
# every exit code. This header carries the reasoning behind the shape.
#
# IDENTITY IS THE AUTHORED NAME AND VERSION. An entity is resolved by the
# metadata.name and metadata.version its document declares, never by the directory
# it sits in, so those two values are what this check reads. A directory that
# disagrees with its document is judged by the document.
#
# ONE PASS, ONE READER. Every file is read by the one awk program below, in a single
# process, under LC_ALL=C, and every list it prints is sorted by byte order, so the
# same catalog gives the same output byte for byte. The program uses POSIX awk
# only, so it runs under mawk, gawk and busybox awk alike.
#
# THE READER IS NARROW ON PURPOSE, AND IT FAILS CLOSED. It reads a key only where
# the catalog conventions put it: a top-level key at column 0, and a field of
# metadata: or spec: at an indent of exactly two spaces, its value on the same line.
# A value in any other shape — a flow mapping, a block scalar, a version range — is
# not guessed at: the file is named with the value, and nothing is judged. A check
# that skipped what it could not read would pass over exactly the files it should
# have looked at.
#
# AN EMPTY CATALOG IS A REFUSAL. A run that finds no Component or no Recipe has
# judged nothing, and saying so with a passing exit would read as a clean catalog.
#
# THE REALIZATION RULE IS A DELIBERATE, NARROWER COPY. Whether a Recipe realizes a
# Component version is decided by the rule the compiler applies when it judges a
# Manifest mapping entry against the Recipe it names — the condition `aggrega explain E0096`
# describes, "Recipe implements does not match the mapped component type". It is
# restated here because the compiler offers no command that lists the Recipes
# realizing a Component version, so there is nothing for this check to ask. It is
# held narrower than the compiler's on purpose: every form where the two could
# answer differently — a version range in implements, a cycle of extends, any form
# the reader does not read — stops the check with nothing judged rather than being
# answered here.

usage() {
  cat <<'END_OF_HELP'
check-component-recipes.sh — refuse a Component version that no Recipe realizes
while the version below it has Recipes.

USAGE
  scripts/check-component-recipes.sh [--catalog DIR]
  scripts/check-component-recipes.sh -h | --help

  --catalog DIR  the catalog tree to judge (default: aggrega-catalog at the top
                 of the repository this script belongs to, wherever it is run
                 from).

WHAT IT READS
  Under DIR, every component/**/component.yaml — its kind, metadata.name,
  metadata.version and spec.extends when present — and every
  recipe/**/recipe.yaml — its kind, metadata.name, metadata.version,
  spec.capability and spec.implements. An entity is identified by the name and
  version its document declares, not by its directory; quotes around a value
  are not part of it.

WHAT IT REFUSES
  A Component version is realized when a Recipe's spec.implements names it
  exactly (name:X.Y.Z), or names the Component with no version, which
  implements every version; or when the base its spec.extends names is
  realized, by either route, through any number of extends.

  The versions of each Component are ordered by number (X, then Y, then Z). A
  version that is not realized, while the version immediately below it is, is
  refused: it is a version a Manifest can map to no Recipe. The refusal names
  the Component, the version, the version below it with that version's Recipes
  as <capability>/<name>:<version>, and the component.yaml declaring the
  version, and says what to do: give each of those Recipes a new version whose
  spec.implements names the new Component version, in the same change.

  Every refusal is printed, not only the first. A Component none of whose
  versions is realized is not refused, and the lowest version of a Component
  is never refused.

WHAT IT DOES NOT SEE
  - Only the catalog tree it is pointed at. It reads no registry, so a Recipe
    published from another tree, or a Component version already published,
    is outside it.
  - Features and FeatureRecipes are not judged.
  - A Recipe naming a Component the tree does not hold realizes nothing that
    is judged.

IT FAILS CLOSED
  Nothing is judged, and the run exits 2 naming the file and the value, when:
  a version is not X.Y.Z with each part a whole number; a spec.implements or
  spec.extends is in any other form than name:X.Y.Z (or, for implements, a bare
  name), a version range included; a name, version or capability cannot be
  read; a component.yaml is not a Component or a recipe.yaml not a Recipe; a
  field is declared twice in one file; two files declare the same Component
  version; a chain of spec.extends returns to a version already on it (a
  cycle), named with every version on it and the file declaring each; a file
  cannot be read; the catalog directory is missing; or the tree holds no
  Component or no Recipe at all.

EXIT CODES
  0  nothing refused; one line states what was judged
  1  refused; each finding is named
  2  a usage error, or the catalog could not be read as above; nothing judged
END_OF_HELP
}

export LC_ALL=C
WHO="check-component-recipes.sh"

HERE="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)" || exit 2
CATALOG="$(cd -- "$HERE/.." && pwd)/aggrega-catalog" || exit 2

while [ "$#" -gt 0 ]; do
  case "$1" in
    -h|--help) usage; exit 0 ;;
    --catalog)
      if [ "$#" -lt 2 ] || [ -z "$2" ]; then
        echo "$WHO: --catalog needs a directory" >&2
        exit 2
      fi
      CATALOG="$2"
      shift 2
      ;;
    *)
      echo "$WHO: unknown argument: $1 (see --help)" >&2
      exit 2
      ;;
  esac
done

if [ ! -d "$CATALOG" ]; then
  echo "$WHO: nothing judged: the catalog directory $CATALOG does not exist" >&2
  exit 2
fi
for sub in component recipe; do
  if [ ! -d "$CATALOG/$sub" ]; then
    echo "$WHO: nothing judged: $CATALOG holds no $sub directory, so it holds no $sub to judge" >&2
    exit 2
  fi
done

WORK="$(mktemp -d)" || exit 2
trap 'rm -rf -- "$WORK"' EXIT

if ! find "$CATALOG/component" -type f -name component.yaml > "$WORK/components.unsorted"; then
  echo "$WHO: nothing judged: cannot list the component.yaml files under $CATALOG/component" >&2
  exit 2
fi
if ! find "$CATALOG/recipe" -type f -name recipe.yaml > "$WORK/recipes.unsorted"; then
  echo "$WHO: nothing judged: cannot list the recipe.yaml files under $CATALOG/recipe" >&2
  exit 2
fi
sort "$WORK/components.unsorted" > "$WORK/components" || exit 2
sort "$WORK/recipes.unsorted" > "$WORK/recipes" || exit 2

# The paths reach awk through the environment rather than -v, which would read a
# backslash in a path as an escape.
CCR_WHO="$WHO" CCR_CATALOG="$CATALOG" \
CCR_CLIST="$WORK/components" CCR_RLIST="$WORK/recipes" awk '
# --- reading ------------------------------------------------------------------

# trimval strips the space after the colon, a trailing comment, trailing space,
# and one pair of matching quotes around the whole value.
function trimval(v,   q) {
  sub(/^[ \t]+/, "", v)
  sub(/[ \t]+#.*$/, "", v)
  sub(/[ \t]+$/, "", v)
  if (length(v) >= 2) {
    q = substr(v, 1, 1)
    if ((q == "\"" || q == "\047") && substr(v, length(v), 1) == q)
      v = substr(v, 2, length(v) - 2)
  }
  return v
}

function bad(path, msg) {
  nbad++
  BAD[nbad] = path ": " msg
}

function setf(key, line, path,   v) {
  v = line
  sub(/^[^:]*:/, "", v)
  v = trimval(v)
  if (key in F) {
    bad(path, key " is declared more than once")
    return
  }
  F[key] = v
}

# readdoc fills F with the fields this check reads from one file. It reads kind:
# itself rather than through peek_kind in scripts/lib/catalog-entities.sh: one
# pass reads all five keys of a file, and every key, kind included, gets the same
# quote and trailing-comment stripping.
function readdoc(path,   line, sec, key, rc, k) {
  for (k in F) delete F[k]
  sec = ""
  while ((rc = (getline line < path)) > 0) {
    sub(/\r$/, "", line)
    if (line ~ /^[^ \t#-][^:]*:/) {
      sec = line
      sub(/:.*$/, "", sec)
      if (sec == "kind") setf("kind", line, path)
      continue
    }
    if (line !~ /^  [A-Za-z_][A-Za-z0-9_-]*:/) continue
    key = line
    sub(/^  /, "", key)
    sub(/:.*$/, "", key)
    if (sec == "metadata" && (key == "name" || key == "version"))
      setf("metadata." key, line, path)
    else if (sec == "spec" && (key == "capability" || key == "implements" || key == "extends"))
      setf("spec." key, line, path)
  }
  if (rc < 0) bad(path, "cannot be read")
  close(path)
}

function isver(v) {
  return v ~ /^(0|[1-9][0-9]*)\.(0|[1-9][0-9]*)\.(0|[1-9][0-9]*)$/
}

function isname(v) {
  return v ~ /^[A-Za-z0-9][A-Za-z0-9._\/-]*$/
}

function field(k) {
  return (k in F) ? F[k] : ""
}

# needname and needver record a finding and return 0 when the field is unreadable.
function needname(path, k,   v) {
  v = field(k)
  if (!(k in F)) { bad(path, k " is missing"); return 0 }
  if (!isname(v)) { bad(path, k " \"" v "\" is not a name this check reads"); return 0 }
  return 1
}

function needver(path, k,   v) {
  v = field(k)
  if (!(k in F)) { bad(path, k " is missing"); return 0 }
  if (!isver(v)) { bad(path, k " \"" v "\" is not a version of the form X.Y.Z"); return 0 }
  return 1
}

# pinned reports whether v is name:X.Y.Z, filling PIN_NAME and PIN_VER.
function pinned(v,   i) {
  i = index(v, ":")
  if (i == 0) return 0
  PIN_NAME = substr(v, 1, i - 1)
  PIN_VER = substr(v, i + 1)
  return isname(PIN_NAME) && isver(PIN_VER)
}

# --- realizations -------------------------------------------------------------

# addreal records that the Recipe labelled lab realizes the Component version id,
# once; it returns 1 when that is new.
function addreal(id, lab) {
  if ((id, lab) in HAS) return 0
  HAS[id, lab] = 1
  RN[id]++
  REAL[id, RN[id]] = lab
  return 1
}

# --- ordering, by byte order and by version number ------------------------------

function strlt(a, b) {
  return ("" a) < ("" b)
}

# verlt orders two X.Y.Z versions by number. The parts carry no leading zero, so
# a longer part is the larger one, and parts of one length compare as strings,
# which holds for numbers of any size.
function verlt(a, b,   x, y, i) {
  split(a, x, ".")
  split(b, y, ".")
  for (i = 1; i <= 3; i++) {
    if (length(x[i]) != length(y[i])) return length(x[i]) < length(y[i])
    if (("" x[i]) != ("" y[i])) return strlt(x[i], y[i])
  }
  return 0
}

# sortstr sorts A[1..n] by byte order; sortver sorts A[1..n] by version number.
function sortstr(A, n,   i, j, t) {
  for (i = 2; i <= n; i++) {
    t = A[i]
    for (j = i - 1; j >= 1 && strlt(t, A[j]); j--) A[j + 1] = A[j]
    A[j + 1] = t
  }
}

function sortver(A, n,   i, j, t) {
  for (i = 2; i <= n; i++) {
    t = A[i]
    for (j = i - 1; j >= 1 && verlt(t, A[j]); j--) A[j + 1] = A[j]
    A[j + 1] = t
  }
}

# reallist prints the Recipes realizing id, sorted, comma-separated.
function reallist(id,   L, i, n, s) {
  n = RN[id]
  for (i = 1; i <= n; i++) L[i] = REAL[id, i]
  sortstr(L, n)
  s = ""
  for (i = 1; i <= n; i++) s = s (i > 1 ? ", " : "") L[i]
  return s
}

function stderr(msg) {
  print msg | "cat 1>&2"
}

BEGIN {
  who = ENVIRON["CCR_WHO"]
  catalog = ENVIRON["CCR_CATALOG"]
  clist = ENVIRON["CCR_CLIST"]
  rlist = ENVIRON["CCR_RLIST"]
  ncomp = 0
  while ((rc = (getline path < clist)) > 0) {
    ncomp++
    readdoc(path)
    ok = 1
    if (field("kind") != "Component") {
      bad(path, "kind is \"" field("kind") "\", not Component")
      ok = 0
    }
    if (!needname(path, "metadata.name")) ok = 0
    if (!needver(path, "metadata.version")) ok = 0
    ext = ""
    if ("spec.extends" in F) {
      ext = F["spec.extends"]
      if (!pinned(ext)) {
        bad(path, "spec.extends \"" ext "\" is not of the form name:X.Y.Z")
        ok = 0
      }
    }
    if (!ok) continue
    name = F["metadata.name"]
    ver = F["metadata.version"]
    id = name ":" ver
    if (id in CFILE) {
      bad(path, "declares " id ", which " CFILE[id] " declares too")
      continue
    }
    CFILE[id] = path
    EXT[id] = ext
    ncids++
    CIDS[ncids] = id
    if (!(name in NV)) { nnames++; NAMES[nnames] = name; NV[name] = 0 }
    NV[name]++
    VERS[name, NV[name]] = ver
  }
  if (rc < 0) bad(clist, "cannot be read")
  close(clist)

  nrec = 0
  while ((rc = (getline path < rlist)) > 0) {
    nrec++
    readdoc(path)
    ok = 1
    if (field("kind") != "Recipe") {
      bad(path, "kind is \"" field("kind") "\", not Recipe")
      ok = 0
    }
    if (!needname(path, "metadata.name")) ok = 0
    if (!needver(path, "metadata.version")) ok = 0
    if (!("spec.capability" in F)) {
      bad(path, "spec.capability is missing")
      ok = 0
    } else if (F["spec.capability"] !~ /^[A-Za-z0-9][A-Za-z0-9._-]*$/) {
      bad(path, "spec.capability \"" F["spec.capability"] "\" is not a capability this check reads")
      ok = 0
    }
    impl = field("spec.implements")
    if (!("spec.implements" in F)) {
      bad(path, "spec.implements is missing")
      ok = 0
    } else if (!isname(impl) && !pinned(impl)) {
      bad(path, "spec.implements \"" impl "\" is not of the form name:X.Y.Z or name")
      ok = 0
    }
    if (!ok) continue
    lab = F["spec.capability"] "/" F["metadata.name"] ":" F["metadata.version"]
    if (isname(impl)) {
      if (!((impl, lab) in EVERY)) {
        EVERY[impl, lab] = 1
        NEVERY[impl]++
        EVERYLAB[impl, NEVERY[impl]] = lab
      }
    } else {
      addreal(impl, lab)
    }
  }
  if (rc < 0) bad(rlist, "cannot be read")
  close(rlist)

  if (ncomp == 0) bad(catalog "/component", "holds no component.yaml, so there is nothing to judge")
  if (nrec == 0) bad(catalog "/recipe", "holds no recipe.yaml, so there is nothing to judge")

  # A chain of extends that returns to a version already on it is a cycle, which
  # the compiler refuses; it is named here, once per cycle, rather than judged.
  for (k = 1; k <= ncids; k++) {
    for (x in ONPATH) delete ONPATH[x]
    step = 0
    id = CIDS[k]
    while (id != "" && (id in CFILE) && !(id in ONPATH)) {
      step++
      ONPATH[id] = step
      ORDER[step] = id
      id = EXT[id]
    }
    if (id == "" || !(id in ONPATH)) continue
    first = ONPATH[id]
    # Start the cycle at its byte-smallest version, so every walk names it alike.
    low = first
    for (i = first + 1; i <= step; i++) if (strlt(ORDER[i], ORDER[low])) low = i
    s = ""
    for (i = 0; i <= step - first; i++) {
      j = low + i
      if (j > step) j = j - (step - first + 1)
      s = s ORDER[j] " (" CFILE[ORDER[j]] ") extends "
    }
    s = s ORDER[low]
    if (s in CYCLE) continue
    CYCLE[s] = 1
    nbad++
    BAD[nbad] = "spec.extends forms a cycle: " s
  }

  if (nbad > 0) {
    for (i = 1; i <= nbad; i++) stderr(who ": " BAD[i])
    stderr(who ": nothing judged: " nbad " problem(s) above; each names the file and what this check cannot read in it")
    close("cat 1>&2")
    exit 2
  }

  # A Recipe implementing a Component with no version realizes every version.
  for (id in CFILE) {
    name = substr(id, 1, index(id, ":") - 1)
    for (i = 1; i <= NEVERY[name]; i++) addreal(id, EVERYLAB[name, i])
  }

  # A version extending a realized base is realized by the Recipes of that base,
  # through any number of extends. A cycle never reaches this point, and Recipes
  # are only ever added, so the loop ends.
  changed = 1
  while (changed) {
    changed = 0
    for (id in EXT) {
      if (EXT[id] == "") continue
      base = EXT[id]
      for (i = 1; i <= RN[base]; i++)
        if (addreal(id, REAL[base, i])) changed = 1
    }
  }

  sortstr(NAMES, nnames)
  nver = 0
  nfind = 0
  for (k = 1; k <= nnames; k++) {
    name = NAMES[k]
    n = NV[name]
    for (i = 1; i <= n; i++) V[i] = VERS[name, i]
    sortver(V, n)
    nver += n
    for (i = 2; i <= n; i++) {
      prev = name ":" V[i - 1]
      cur = name ":" V[i]
      if (RN[prev] > 0 && !(RN[cur] > 0)) {
        nfind++
        print who ": refused: no Recipe realizes " cur ", while the version below it, " V[i - 1] ", has: " reallist(prev)
        print "  declared in " CFILE[cur]
        print "  a Manifest can map " cur " to no Recipe; give each of those Recipes a new version whose spec.implements names " cur ", in the same change"
      }
    }
  }

  if (nfind > 0) {
    print who ": " nfind " Component version(s) refused, of " nver " judged"
    exit 1
  }
  print who ": judged " nver " Component version(s) of " nnames " Component(s) against " nrec " Recipe(s) under " catalog "; none refused"
  exit 0
}
'
RC=$?
exit $RC
