#!/usr/bin/env bash
# Run this script to test idris2-fmt against the taiga-cli codebase.
# Usage: ./test_idris2-fmt.sh /path/to/taiga-cli/src /path/to/taiga-cli.ipkg

set -euo pipefail

SRC_DIR="${1:-src}"
IPKG="${2:-taiga-cli.ipkg}"
TMPDIR="$(mktemp -d)"

cleanup() { rm -rf "$TMPDIR"; }
trap cleanup EXIT

# 1. Copy source to temp dir
cp -r "$SRC_DIR" "$TMPDIR/src"

echo "=== idris2-fmt ==="
idris2-fmt --version

echo ""
echo "=== Formatting all .idr files... ==="

FAILED_FORMAT=0
for f in $(find "$TMPDIR/src" -name '*.idr' | sort); do
  if ! idris2-fmt --inplace "$f" 2>&1; then
    echo "FAIL: format error in $f"
    FAILED_FORMAT=1
  fi
done

if [ "$FAILED_FORMAT" -ne 0 ]; then
  echo ""
  echo "FORMAT ERRORS DETECTED — aborting compile test."
  exit 1
fi

echo ""
echo "=== Compiling formatted codebase... ==="

# Copy ipkg to temp dir and adjust paths
cp "$IPKG" "$TMPDIR/$IPKG"
cd "$TMPDIR"

COMPILE_OUTPUT=$(idris2 --build "$IPKG" 2>&1) || COMPILE_FAILED=1
echo "$COMPILE_OUTPUT" | tail -60

if [ "${COMPILE_FAILED:-0}" -ne 0 ]; then
  echo ""
  echo "COMPILE ERRORS DETECTED!"
  exit 1
else
  echo ""
  echo "ALL CHECKS PASSED."
fi
