#!/bin/bash
set -u

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
FAILED=0
TOTAL=0

for test_file in "$SCRIPT_DIR"/test-*.sh; do
  TOTAL=$((TOTAL + 1))
  echo "==> $(basename "$test_file")"
  if bash "$test_file"; then
    echo "   PASS"
  else
    echo "   FAIL"
    FAILED=$((FAILED + 1))
  fi
done

echo ""
echo "$TOTAL tests, $FAILED failed"
[ "$FAILED" -eq 0 ]
