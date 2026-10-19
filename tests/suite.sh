#!/usr/bin/env bash
#
# Runs inside the test container (see tests/run.sh): shellcheck, then every
# test_* function from tests/test-*.sh, each with its own empty HOME.
#
#   bash tests/suite.sh [filter]   filter: only test files whose name contains it

set -u
cd "$(dirname "$0")/.." || exit 1
BASE_PATH="$PATH"
FILTER="${1:-}"

. tests/helpers.sh

FAILURES=0
if [ -z "$FILTER" ]; then
  echo "shellcheck"
  # lib.sh is sourced through "$(dirname "$0")", which shellcheck can't follow.
  # Style notes are shown but only warnings and errors fail the run.
  shellcheck -x -e SC1091 -s bash -f gcc ./*.sh apps/*.sh tests/*.sh | sed 's/^/  /'
  if shellcheck -x -e SC1091 -s bash -S warning ./*.sh apps/*.sh tests/*.sh; then
    echo "  ok"
  else
    FAILURES=$((FAILURES + 1))
  fi
  echo
fi

for file in tests/test-*.sh; do
  case "$file" in *"$FILTER"*) ;; *) continue ;; esac
  # shellcheck source=/dev/null
  . "$file"
done

PASSED=0
BASE_TMP="$(mktemp)"
for test in $(compgen -A function test_); do
  if (
    setup
    "$test"
    [ -z "$TEST_FAILED" ] || { dump_output; exit 1; }
  ) > "$BASE_TMP" 2>&1; then
    echo "ok    $test"
    PASSED=$((PASSED + 1))
  else
    echo "FAIL  $test"
    cat "$BASE_TMP"
    FAILURES=$((FAILURES + 1))
  fi
done

echo
echo "$PASSED passed, $FAILURES failed"
[ "$FAILURES" = 0 ]
