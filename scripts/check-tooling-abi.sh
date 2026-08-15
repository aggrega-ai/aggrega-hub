#!/usr/bin/env bash
#
# check-tooling-abi.sh — consumer-side plugin-ABI compatibility gate.
#
# Fails loudly when the pinned tooling image speaks a different plugin ABI
# version than this repository is authored against. The publish workflow runs
# inside the pinned tooling image, so the `aggrega` on PATH is that image's own
# binary and its `aggrega version -o json` abiVersion is exactly the pinned
# image's ABI. That actual value is compared against the ABI this repository
# expects (EXPECTED_ABI_VERSION — a single reviewed value in the publish
# workflow).
#
# A mismatch is never resolved automatically. It halts the run so a human
# consciously reviews catalog compatibility and, only if the new ABI is
# intended, bumps the expected ABI alongside the image tag. This is the
# load-bearing safety net: it protects the publish regardless of how the
# tooling-image tag was bumped, whether through an opened update pull request or
# any other route.
#
# The gate deliberately lives in the consumer repository, not inside the tooling
# image: a check shipped inside the image being validated could not be trusted
# to report that image's own incompatibility.
#
# Local testing without the image: set ACTUAL_ABI_VERSION to simulate the
# image's reported ABI. A value equal to EXPECTED_ABI_VERSION exits 0; a
# different value exits non-zero.
set -euo pipefail

expected="${EXPECTED_ABI_VERSION:-}"
if [ -z "$expected" ]; then
  echo "check-tooling-abi: EXPECTED_ABI_VERSION is unset — cannot gate." >&2
  exit 2
fi

# The actual ABI is the pinned image's own report. ACTUAL_ABI_VERSION overrides
# it for local testing without the image on PATH.
actual="${ACTUAL_ABI_VERSION:-}"
if [ -z "$actual" ]; then
  if ! json="$(aggrega version -o json)"; then
    echo "check-tooling-abi: could not read 'aggrega version -o json'." >&2
    exit 2
  fi
  # Extract the abiVersion string field from the reported JSON.
  # Whitespace is stripped before the match so the extraction is insensitive to
  # the pretty-printer, and it needs no jq. Stripping the whole payload is safe
  # only where the extracted value contains no whitespace, which holds for the
  # version and ABI version strings read here.
  # The `|| true` keeps a no-match from tripping pipefail so the empty-value
  # check below owns the diagnostic.
  actual="$(printf '%s' "$json" | tr -d '[:space:]' | grep -o '"abiVersion":"[^"]*"' | head -1 | cut -d'"' -f4 || true)"
fi

if [ -z "$actual" ]; then
  echo "check-tooling-abi: the tooling image reported no abiVersion." >&2
  exit 2
fi

if [ "$actual" != "$expected" ]; then
  echo "check-tooling-abi: PLUGIN ABI MISMATCH." >&2
  echo "  pinned tooling image ABI: $actual" >&2
  echo "  this repository expects:  $expected" >&2
  echo "A human must review catalog compatibility before publishing. If the new" >&2
  echo "ABI is intended, bump EXPECTED_ABI_VERSION in the publish workflow in the" >&2
  echo "same reviewed change that adopts the new tooling-image tag." >&2
  exit 1
fi

echo "check-tooling-abi: OK — tooling image ABI '$actual' matches expected."
