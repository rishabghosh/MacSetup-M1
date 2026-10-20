# Helpers for the tests/test-*.sh files. Sourced by suite.sh.
# Bash 3.2 like the scripts under test.

STUBS="$PWD/tests/stubs"
ESC="$(printf '\033')"

# Called before each test: an empty HOME, stub log and stub state, and the
# stubs first on PATH.
setup() {
  TEST_DIR="$(mktemp -d)"
  export HOME="$TEST_DIR/home"
  export STUB_LOG="$TEST_DIR/stub.log"
  export STUB_STATE="$TEST_DIR/state"
  export HOMEBREW_PREFIX="$TEST_DIR/homebrew"
  export PATH="$STUBS:$BASE_PATH"
  mkdir -p "$HOME" "$STUB_STATE"
  : > "$STUB_LOG"
  unset BREW_FAIL XCODE_MISSING GIT_FAIL SSH_FAIL_TIMES SSH_FAIL_KEY PROJECTS_DIR
  unset BACKUP_DIR APPS_DIR RUNNING STAGE_DIR
  export PUBLIC_DIR="$TEST_DIR/saved"
  TEST_FAILED=""
  OUT=""
  STATUS=""
}

# without <stub> ...: make those commands disappear from PATH.
without() {
  local bin="$TEST_DIR/bin" stub
  mkdir -p "$bin"
  for stub in "$STUBS"/*; do
    case " $* " in
      *" $(basename "$stub") "*) ;;
      *) ln -sf "$stub" "$bin/" ;;
    esac
  done
  export PATH="$bin:$BASE_PATH"
}

strip_colors() { sed "s/$ESC\[[0-9;]*m//g"; }

# run <command> [args]: no terminal, empty stdin. Sets OUT and STATUS.
run() {
  OUT="$("$@" </dev/null 2>&1)"
  STATUS=$?
  OUT="$(printf '%s' "$OUT" | strip_colors)"
}

# run_tty <answers> <command> [args]: on a terminal, typing one line of
# <answers> at each prompt. Sets OUT and STATUS.
run_tty() {
  local answers="$TEST_DIR/answers"
  printf '%s\n' "$1" > "$answers"
  shift
  OUT="$(python3 -I "$STUBS/../tty.py" "$answers" "$@" 2>&1)"
  STATUS=$?
  OUT="$(printf '%s' "$OUT" | strip_colors)"
}

fail() {
  # shellcheck disable=SC2034  # read by suite.sh
  TEST_FAILED=1
  echo "    $*"
}

expect_status() {
  [ "$STATUS" = "$1" ] || fail "expected exit status $1, got $STATUS"
}

expect_out() {
  case "$OUT" in *"$1"*) ;; *) fail "output should contain: $1" ;; esac
}

expect_no_out() {
  case "$OUT" in *"$1"*) fail "output should not contain: $1" ;; esac
}

# The stub log has one line per stub call, e.g. "brew install --cask slack".
expect_log() {
  grep -qxF -- "$1" "$STUB_LOG" || fail "expected call: $1"
}

expect_no_log() {
  grep -qxF -- "$1" "$STUB_LOG" && fail "unexpected call: $1"
}

# expect_no_log_match <text>: no call contains <text>.
expect_no_log_match() {
  grep -qF -- "$1" "$STUB_LOG" && fail "unexpected call containing: $1 ($(grep -F -- "$1" "$STUB_LOG" | head -1))"
}

expect_log_count() {
  local n
  n="$(grep -cF -- "$1" "$STUB_LOG")"
  [ "$n" = "$2" ] || fail "expected $2 calls containing '$1', got $n"
}

expect_file() {
  [ -f "$1" ] || fail "missing file: $1"
}

expect_dir() {
  [ -d "$1" ] || fail "missing folder: $1"
}

expect_no_path() {
  [ ! -e "$1" ] || fail "should not exist: $1"
}

# expect_line <file> <line>: the file has exactly that line.
expect_line() {
  grep -qxF -- "$2" "$1" 2>/dev/null || fail "$1 should have the line: $2"
}

expect_eq() {
  [ "$1" = "$2" ] || fail "expected '$2', got '$1'${3:+ ($3)}"
}

# json <file> <python expression on d>: prints the value, e.g.
#   json ~/.claude.json 'd["mcpServers"]["kiwi-flights"]["url"]'
json() {
  python3 -I -c 'import json, sys; d = json.load(open(sys.argv[1])); print(eval(sys.argv[2]))' "$1" "$2" 2>&1
}

# Shows what the script printed when a test fails.
dump_output() {
  echo "    --- last output (exit $STATUS) ---"
  printf '%s\n' "$OUT" | tail -25 | sed 's/^/    | /'
}
