# Shared helpers for the install-*.sh scripts. Sourced, not run directly.
# Written for the macOS default bash (3.2), so no associative arrays, and
# arrays are never expanded while empty (that trips `set -u` on 3.2).
#
# A script lists its items with `cask`, `formula` and `step`, then calls
# run_installer:
#
#   cask    slack
#   formula jq
#   step    playwright-browsers
#   run_installer "Office" "$@"
#
# What each item is for is written up in the README, not here.
#
# A step is anything that doesn't come from Homebrew. For a step named
# foo-bar the script defines two functions: foo_bar_installed (returns 0 when
# it's already there) and install_foo_bar. Steps run after the brew installs.
#
# run_installer shows a checklist of the items: move with the arrow keys, tick with space, tick everything with the "All" row (or
# a), and press Enter to install what's ticked. Options (passed through "$@"):
#   --all    install everything without asking
#   --list   print the items and exit
#   --help   show usage

set -u

FAILED=""
COUNT=0
KINDS=()
NAMES=()
PICKED=()
INST=()

bold() { printf '\033[1m%s\033[0m\n' "$*"; }
info() { printf '  %s\n' "$*"; }
warn() { printf '\033[33m  ! %s\033[0m\n' "$*"; }

# add_item cask|formula|step <name>
add_item() {
  KINDS[$COUNT]="$1"
  NAMES[$COUNT]="$2"
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

# Fills INST[i] with 1 for each item that's already there, so the checklist
# doesn't re-check on every key.
load_item_status() {
  local i=0
  while [ $i -lt $COUNT ]; do
    INST[$i]=0
    item_installed $i && INST[$i]=1
    i=$((i + 1))
  done
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
    [ "${INST[$i]}" = 1 ] && mark="  (installed)"
    printf ' %3d) \033[1m%s\033[0m\033[32m%s\033[0m\n' $((i + 1)) "${NAMES[$i]}" "$mark"
    i=$((i + 1))
  done
  echo
}

picked_count() {
  local i=0 n=0
  while [ $i -lt $COUNT ]; do
    [ "${PICKED[$i]}" = 1 ] && n=$((n + 1))
    i=$((i + 1))
  done
  echo $n
}

# set_all 0|1: untick or tick every item.
set_all() {
  local i=0
  while [ $i -lt $COUNT ]; do PICKED[$i]=$1; i=$((i + 1)); done
}

picked_names() {
  local i=0 out=""
  while [ $i -lt $COUNT ]; do
    [ "${PICKED[$i]}" = 1 ] && [ "${KINDS[$i]}" = "$1" ] && out="$out ${NAMES[$i]}"
    i=$((i + 1))
  done
  echo "$out"
}

# --- The checklist -------------------------------------------------------
#
# Drawn on /dev/tty (fd 3) on the terminal's alternate screen, like less or
# fzf, and redrawn from the top after every key. The window size is read
# again before each redraw, so the list grows and shrinks with the window.
# Each row is cut to the terminal width so nothing wraps, and the item rows
# scroll when they don't fit. ROWS holds what each row shows: "all", "h:<kind>" for a
# heading, or an item index. CUR is the row the cursor is on (never a
# heading) and TOP the first row on screen.

ROWS=()
NROWS=0
CUR=0
TOP=0
VIEW=0
NAME_W=0
TERM_ROWS=24
TERM_COLS=80
STATUS_MSG=""
ESC="$(printf '\033')"
CTRL_D="$(printf '\004')"
OLD_STTY=""

build_rows() {
  local i=0 heading=""
  ROWS[0]=all
  NROWS=1
  NAME_W=0
  while [ $i -lt $COUNT ]; do
    if [ "${KINDS[$i]}" != "$heading" ]; then
      heading="${KINDS[$i]}"
      ROWS[$NROWS]="h:$heading"
      NROWS=$((NROWS + 1))
    fi
    ROWS[$NROWS]=$i
    NROWS=$((NROWS + 1))
    [ ${#NAMES[$i]} -gt $NAME_W ] && NAME_W=${#NAMES[$i]}
    i=$((i + 1))
  done
  [ $NAME_W -gt 26 ] && NAME_W=26
}

# Terminal size, or 24x80 when it can't be read. Also moves TOP so the
# cursor stays on screen and no rows are left empty at the bottom.
read_term_size() {
  local size
  size="$(stty size <&3 2>/dev/null)" || size=""
  TERM_ROWS="${size% *}"
  TERM_COLS="${size#* }"
  case "$TERM_ROWS" in "" | *[!0-9]* | 0) TERM_ROWS=24 ;; esac
  case "$TERM_COLS" in "" | *[!0-9]* | 0) TERM_COLS=80 ;; esac
  # Two header lines, a blank line, the rows, a blank line, the status line.
  VIEW=$((TERM_ROWS - 6))
  [ $VIEW -lt 3 ] && VIEW=3
  [ $VIEW -gt $NROWS ] && VIEW=$NROWS
  [ $TOP -gt $((NROWS - VIEW)) ] && TOP=$((NROWS - VIEW))
  scroll_to_cursor
}

# clip <text> <width>
clip() {
  if [ ${#1} -gt "$2" ]; then
    printf '%s...' "${1:0:$(($2 - 3))}"
  else
    printf '%s' "$1"
  fi
}

# draw_row <row>
draw_row() {
  local row="${ROWS[$1]}" ptr="  " box name rest n width=$((TERM_COLS - 7)) on="" off=""
  [ "$1" = "$CUR" ] && { ptr="> "; on=$'\033[1;36m'; off=$'\033[0m'; }
  case "$row" in
    all)
      n="$(picked_count)"
      if [ "$n" = "$COUNT" ]; then box="[x]"; elif [ "$n" = 0 ]; then box="[ ]"; else box="[-]"; fi
      rest="All ($COUNT items)" ;;
    h:*)
      printf '\033[1m   %s\033[0m\n' "$(clip "$(kind_heading "${row#h:}")" $((TERM_COLS - 4)))"
      return ;;
    *)
      if [ "${PICKED[$row]}" = 1 ]; then box="[x]"; else box="[ ]"; fi
      rest="$(clip "${NAMES[$row]}" $NAME_W)"
      [ "${INST[$row]}" = 1 ] && rest="$(printf '%-*s  ' $NAME_W "$rest")(installed)" ;;
  esac
  [ "$box" = "[ ]" ] || box=$'\033[32m'"$box"$'\033[0m'
  printf '%s%s%s %s%s\n' "$on" "$ptr" "$box" "$on$(clip "$rest" $width)" "$off"
}

draw_frame() {
  local r last width
  read_term_size
  r=$TOP last=$((TOP + VIEW)) width=$((TERM_COLS - 1))
  {
    printf '\033[H\033[J'
    printf '\033[1m%s\033[0m\n' "$(clip "$1: pick what to install" $width)"
    printf '\033[2m%s\033[0m\n' "$(clip "up/down move   space tick   a all   enter install   q quit" $width)"
    echo
    while [ $r -lt $last ]; do draw_row $r; r=$((r + 1)); done
    echo
    if [ -n "$STATUS_MSG" ]; then
      printf '\033[33m%s\033[0m\n' "$(clip "$STATUS_MSG" $width)"
    else
      printf '%s\n' "$(clip "$(picked_count) of $COUNT picked" $width)"
    fi
  } >&3
}

# Keep the cursor on screen, with its heading when it's the first item.
scroll_to_cursor() {
  if [ $CUR -lt $TOP ]; then TOP=$CUR; fi
  if [ $CUR -gt 0 ]; then
    case "${ROWS[$((CUR - 1))]}" in h:*) [ $((CUR - 1)) -lt $TOP ] && TOP=$((CUR - 1)) ;; esac
  fi
  if [ $CUR -ge $((TOP + VIEW)) ]; then TOP=$((CUR - VIEW + 1)); fi
}

# move 1|-1: to the next or previous row that isn't a heading, wrapping round.
move() {
  CUR=$(((CUR + $1 + NROWS) % NROWS))
  case "${ROWS[$CUR]}" in h:*) CUR=$(((CUR + $1 + NROWS) % NROWS)) ;; esac
  scroll_to_cursor
}

toggle_all() {
  if [ "$(picked_count)" = "$COUNT" ]; then set_all 0; else set_all 1; fi
}

# Reads one key into KEY: up, down, esc, or the character itself ("" for
# Enter). Returns 1 at end of input.
read_key() {
  local rest
  IFS= read -rsn1 KEY <&3 || return 1
  if [ "$KEY" = "$ESC" ]; then
    IFS= read -rsn2 -t 1 rest <&3 || rest=""
    case "$rest" in
      "[A" | OA) KEY=up ;;
      "[B" | OB) KEY=down ;;
      "") KEY=esc ;;
      *) KEY=other ;;
    esac
  fi
}

restore_terminal() {
  # Show the cursor and leave the alternate screen.
  printf '\033[?25h\033[?1049l' >&3
  [ -n "$OLD_STTY" ] && stty "$OLD_STTY" <&3 2>/dev/null
  OLD_STTY=""
}

# choose_items <category>: shows the checklist and fills PICKED.
choose_items() {
  local status=""
  if ! { exec 3<>/dev/tty; } 2>/dev/null; then
    warn "No terminal to ask on. Re-run with --all to install everything."
    exit 1
  fi
  build_rows
  read_term_size
  OLD_STTY="$(stty -g <&3 2>/dev/null)"
  # Keys typed while a frame is drawn mustn't echo over it.
  stty -echo -icanon <&3 2>/dev/null
  trap 'restore_terminal' EXIT
  trap 'exit 130' INT TERM
  # Switch to the alternate screen and hide the cursor.
  printf '\033[?1049h\033[?25l' >&3

  while true; do
    draw_frame "$1"
    STATUS_MSG=""
    read_key || { status=1; break; }
    case "$KEY" in
      up | k) move -1 ;;
      down | j) move 1 ;;
      " ")
        case "${ROWS[$CUR]}" in
          all) toggle_all ;;
          *) PICKED[${ROWS[$CUR]}]=$((1 - PICKED[${ROWS[$CUR]}])) ;;
        esac ;;
      a | A) toggle_all ;;
      q | Q | esc) status=0; break ;;
      "$CTRL_D") status=1; break ;;
      "")
        [ "$(picked_count)" != 0 ] && break
        STATUS_MSG="Nothing picked. Tick something with space, or press q to quit." ;;
    esac
  done

  restore_terminal
  trap - EXIT INT TERM
  exec 3>&-
  [ -n "$status" ] && exit "$status"
  [ -n "$(picked_names cask)" ] && info "Apps:$(picked_names cask)"
  [ -n "$(picked_names formula)" ] && info "Command-line tools:$(picked_names formula)"
  [ -n "$(picked_names step)" ] && info "Other setup:$(picked_names step)"
  return 0
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
  bold "Done. Apps that don't come from Homebrew are listed in ${0%.sh}.md"
}

usage() {
  echo "Usage: $(basename "$0") [--all | --list | --help]"
  echo
  echo "  (no option)  pick the $1 items to install from a checklist"
  echo "  --all        install all of them without asking"
  echo "  --list       show the items and exit"
  echo
  echo "Safe to re-run: anything already installed is skipped."
}

# run_installer <category> "$@"
run_installer() {
  local category="$1" mode=pick
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
  load_item_status
  case "$mode" in
    list) print_menu "$category"; exit 0 ;;
    all) print_menu "$category"; set_all 1 ;;
    pick) choose_items "$category" ;;
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
