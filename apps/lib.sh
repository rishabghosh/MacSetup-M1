# Shared helpers for the install-*.sh scripts. Sourced, not run directly.
# Written for the macOS default bash (3.2), so no associative arrays, and
# arrays are never expanded while empty (that trips `set -u` on 3.2).
#
# A script lists its items with `cask`, `formula` and `step`, then calls
# run_installer:
#
#   cask    slack "Team chat" "e.g. ..."
#   formula jq    "JSON processor" "Used: ..."
#   step    playwright-browsers "Playwright's browsers" "Used: ..."
#   run_installer "Office" "$@"
#
# A step is anything that doesn't come from Homebrew. For a step named
# foo-bar the script defines two functions: foo_bar_installed (returns 0 when
# it's already there) and install_foo_bar. Steps run after the brew installs.
#
# run_installer shows a numbered menu with each item's description and lets
# you pick all of them or only some. Options (passed through "$@"):
#   --all    install everything without asking
#   --list   print the menu and exit
#   --help   show usage

set -u

FAILED=""
COUNT=0
KINDS=()
NAMES=()
DESCS=()
NOTES=()
PICKED=()

bold() { printf '\033[1m%s\033[0m\n' "$*"; }
info() { printf '  %s\n' "$*"; }
warn() { printf '\033[33m  ! %s\033[0m\n' "$*"; }
dim()  { printf '\033[2m%s\033[0m\n' "$*"; }

# cask|formula <brew name> <what it is> [example, or what we've run it for]
add_item() {
  KINDS[$COUNT]="$1"
  NAMES[$COUNT]="$2"
  DESCS[$COUNT]="$3"
  NOTES[$COUNT]="${4:-}"
  PICKED[$COUNT]=0
  COUNT=$((COUNT + 1))
}
cask()    { add_item cask "$@"; }
formula() { add_item formula "$@"; }
step()    { add_item step "$@"; }

# Function name prefix for a step: playwright-browsers -> playwright_browsers.
step_fn() { echo "$1" | tr - _; }

ensure_homebrew() {
  if ! command -v brew >/dev/null 2>&1 && [ -x /opt/homebrew/bin/brew ]; then
    eval "$(/opt/homebrew/bin/brew shellenv)"
  fi
  command -v brew >/dev/null 2>&1 && return

  bold "Homebrew is not installed. Installing it (asks for your password)..."
  /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)" || exit 1
  # A failed download runs an empty script, which still exits 0.
  if [ ! -x /opt/homebrew/bin/brew ]; then
    warn "Homebrew didn't install. Check your internet connection and re-run."
    exit 1
  fi
  eval "$(/opt/homebrew/bin/brew shellenv)"
  if ! grep -q "brew shellenv" "$HOME/.zprofile" 2>/dev/null; then
    echo 'eval "$(/opt/homebrew/bin/brew shellenv)"' >> "$HOME/.zprofile"
  fi
}

# Newline-wrapped list of everything Homebrew already has, so the menu can
# mark it. Empty when Homebrew itself isn't installed yet.
INSTALLED=""
load_installed() {
  if ! command -v brew >/dev/null 2>&1 && [ -x /opt/homebrew/bin/brew ]; then
    eval "$(/opt/homebrew/bin/brew shellenv)"
  fi
  command -v brew >/dev/null 2>&1 || return
  INSTALLED="
$(brew list --cask -1 2>/dev/null)
$(brew list --formula -1 2>/dev/null)
"
}

is_installed() {
  # Formulae from a tap (hashicorp/tap/terraform) are listed by short name.
  case "$INSTALLED" in *"
${1##*/}
"*) return 0 ;; esac
  return 1
}

# item_installed <index>
item_installed() {
  if [ "${KINDS[$1]}" = step ]; then
    "$(step_fn "${NAMES[$1]}")_installed"
  else
    is_installed "${NAMES[$1]}"
  fi
}

kind_heading() {
  case "$1" in
    cask) echo "Apps" ;;
    formula) echo "Command-line tools" ;;
    step) echo "Other setup" ;;
  esac
}

print_menu() {
  local i heading="" mark
  bold "$1: $COUNT items"
  i=0
  while [ $i -lt $COUNT ]; do
    if [ "${KINDS[$i]}" != "$heading" ]; then
      heading="${KINDS[$i]}"
      echo
      bold " $(kind_heading "$heading")"
    fi
    mark=""
    item_installed $i && mark="  (installed)"
    printf ' %3d) \033[1m%s\033[0m\033[32m%s\033[0m\n' $((i + 1)) "${NAMES[$i]}" "$mark"
    printf '      %s\n' "${DESCS[$i]}"
    [ -n "${NOTES[$i]}" ] && dim "      ${NOTES[$i]}"
    i=$((i + 1))
  done
  echo
}

# Sets PICKED[i] to $2 for every index in token $1 ("7" or "3-9").
# Returns 1 if the token isn't a valid number or range.
mark_token() {
  local from to
  case "$1" in
    *[!0-9-]* | "" | -* | *- | *-*-*) return 1 ;;
    *-*) from="${1%-*}"; to="${1#*-}" ;;
    *) from="$1"; to="$1" ;;
  esac
  [ "$from" -ge 1 ] && [ "$to" -le $COUNT ] && [ "$from" -le "$to" ] || return 1
  while [ "$from" -le "$to" ]; do
    PICKED[$((from - 1))]=$2
    from=$((from + 1))
  done
}

# Parses a reply like "a", "1 3 5-8" or "a !4 !10-12" into PICKED.
parse_choice() {
  local token i
  i=0
  while [ $i -lt $COUNT ]; do PICKED[$i]=0; i=$((i + 1)); done
  for token in $(echo "$1" | tr ',' ' '); do
    case "$token" in
      a | A | all)
        i=0
        while [ $i -lt $COUNT ]; do PICKED[$i]=1; i=$((i + 1)); done ;;
      !*) mark_token "${token#!}" 0 || { warn "not a valid number or range: $token"; return 1; } ;;
      *) mark_token "$token" 1 || { warn "not a valid number or range: $token"; return 1; } ;;
    esac
  done
}

picked_names() {
  local i=0 out=""
  while [ $i -lt $COUNT ]; do
    [ "${PICKED[$i]}" = 1 ] && [ "${KINDS[$i]}" = "$1" ] && out="$out ${NAMES[$i]}"
    i=$((i + 1))
  done
  echo "$out"
}

choose_items() {
  local reply
  if ! { exec 3</dev/tty; } 2>/dev/null; then
    warn "No terminal to ask on. Re-run with --all to install everything."
    exit 1
  fi
  while true; do
    echo "Pick what to install:"
    echo "  a            everything"
    echo "  1 3 5-8      only these"
    echo "  a !4 !10-12  everything except these"
    echo "  q            quit"
    read -r -p "> " reply <&3 || exit 1
    case "$reply" in q | Q | quit) exit 0 ;; "") continue ;; esac
    parse_choice "$reply" || continue
    if [ -z "$(picked_names cask)$(picked_names formula)$(picked_names step)" ]; then
      warn "Nothing picked."
      continue
    fi
    echo
    [ -n "$(picked_names cask)" ] && info "Apps:$(picked_names cask)"
    [ -n "$(picked_names formula)" ] && info "Command-line tools:$(picked_names formula)"
    [ -n "$(picked_names step)" ] && info "Other setup:$(picked_names step)"
    read -r -p "Install these? [Y/n] " reply <&3 || exit 1
    case "$reply" in [nN]*) echo; continue ;; esac
    break
  done
  exec 3<&-
}

install_casks() {
  local cask
  [ $# -eq 0 ] && return
  bold "Apps (Homebrew casks)"
  for cask in "$@"; do
    if brew list --cask "$cask" >/dev/null 2>&1; then
      info "$cask: already installed, skipped"
    elif brew install --cask "$cask"; then
      info "$cask: installed"
    else
      # Usually means the app is already in /Applications from a direct download.
      warn "$cask: failed (if the app is already installed outside Homebrew, delete it and re-run)"
      FAILED="$FAILED $cask"
    fi
  done
}

install_formulae() {
  local formula
  [ $# -eq 0 ] && return
  bold "Command-line tools (Homebrew formulae)"
  for formula in "$@"; do
    case "$formula" in
      */*/*) brew tap "${formula%/*}" >/dev/null 2>&1 || warn "could not tap ${formula%/*}" ;;
    esac
    if brew list --formula "$formula" >/dev/null 2>&1; then
      info "$formula: already installed, skipped"
    elif brew install "$formula"; then
      info "$formula: installed"
    else
      warn "$formula: failed"
      FAILED="$FAILED $formula"
    fi
  done
}

install_steps() {
  local name fn
  [ $# -eq 0 ] && return
  bold "Other setup"
  for name in "$@"; do
    fn="$(step_fn "$name")"
    if "${fn}_installed"; then
      info "$name: already installed, skipped"
    elif "install_$fn"; then
      info "$name: installed"
    else
      warn "$name: failed"
      FAILED="$FAILED $name"
    fi
  done
}

finish() {
  echo
  if [ -n "$FAILED" ]; then
    warn "Failed:$FAILED"
  fi
  bold "Done. Apps that don't come from Homebrew are listed in $(dirname "$0")/install.md"
}

usage() {
  echo "Usage: $(basename "$0") [--all | --list | --help]"
  echo
  echo "  (no option)  show the $1 items with descriptions and pick which to install"
  echo "  --all        install all of them without asking"
  echo "  --list       show the items and exit"
  echo
  echo "Safe to re-run: anything already installed is skipped."
}

# run_installer <category> "$@"
run_installer() {
  local category="$1" mode=pick i
  shift
  for arg in "$@"; do
    case "$arg" in
      --all | -a) mode=all ;;
      --list | -l) mode=list ;;
      --help | -h) usage "$category"; exit 0 ;;
      *) echo "Unknown option: $arg" >&2; usage "$category" >&2; exit 1 ;;
    esac
  done

  load_installed
  print_menu "$category"
  case "$mode" in
    list) exit 0 ;;
    all)
      i=0
      while [ $i -lt $COUNT ]; do PICKED[$i]=1; i=$((i + 1)); done ;;
    pick) choose_items ;;
  esac

  echo
  ensure_homebrew
  # Word splitting on the name lists is intended: brew names have no spaces.
  # shellcheck disable=SC2046
  install_casks $(picked_names cask)
  # shellcheck disable=SC2046
  install_formulae $(picked_names formula)
  # shellcheck disable=SC2046
  install_steps $(picked_names step)
  finish
}
