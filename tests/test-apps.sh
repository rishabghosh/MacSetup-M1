# Tests for apps/install-*.sh and apps/lib.sh.

APP_SCRIPTS="coding editing entertainment gaming office utils"

# items <script> cask|formula|step: the names a script lists.
items() { sed -n "s/^$2 \([^ ]*\) .*/\1/p" "apps/install-$1.sh"; }
item_count() { { items "$1" cask; items "$1" formula; items "$1" step; } | wc -l | tr -d ' '; }
category() { sed -n 's/^run_installer "\(.*\)" .*/\1/p' "apps/install-$1.sh"; }

test_apps_help() {
  local app
  for app in $APP_SCRIPTS; do
    run "apps/install-$app.sh" --help
    expect_status 0
    expect_out "Usage: install-$app.sh [--all | --list | --help]"
  done
}

test_apps_unknown_option() {
  run apps/install-office.sh --bogus
  expect_status 1
  expect_out "Unknown option: --bogus"
  expect_no_log_match "brew install"
}

test_apps_list_shows_every_item() {
  local app name
  for app in $APP_SCRIPTS; do
    run "apps/install-$app.sh" --list
    expect_status 0
    expect_out "$(category "$app"): $(item_count "$app") items"
    for name in $(items "$app" cask) $(items "$app" formula) $(items "$app" step); do
      expect_out ") $name"
    done
  done
  expect_no_log_match "brew install"
}

test_apps_list_marks_installed() {
  mkdir -p "$STUB_STATE/brew/cask" "$STUB_STATE/brew/formula"
  touch "$STUB_STATE/brew/cask/slack" "$STUB_STATE/brew/formula/terraform"
  run apps/install-office.sh --list
  expect_out "slack  (installed)"
  expect_no_out "zoom  (installed)"
  run apps/install-coding.sh --list
  expect_out "hashicorp/tap/terraform  (installed)"
  expect_no_out "kind  (installed)"
}

test_apps_all_installs_everything() {
  local app name
  for app in $APP_SCRIPTS; do
    run "apps/install-$app.sh" --all
    expect_status 0
    expect_no_out "Failed:"
    for name in $(items "$app" cask); do
      expect_log "brew install --cask $name"
    done
    for name in $(items "$app" formula); do
      expect_log "brew install $name"
    done
  done
  expect_log "brew tap hashicorp/tap"
  # Coding's steps run after the brew installs, Node before Playwright.
  expect_log "nvm install --lts"
  expect_log "nvm alias default lts/*"
  expect_log "npx -y playwright install"
  expect_eq "$(grep -n -e '^brew install nvm$' -e '^nvm install' -e '^npx -y playwright' "$STUB_LOG" | cut -d: -f2- | tr '\n' '|')" \
    "brew install nvm|nvm install --lts|npx -y playwright install|" "install order"
}

test_apps_list_shows_steps() {
  run apps/install-coding.sh --list
  expect_out "Other setup"
  expect_out ") node-lts"
  expect_out ") playwright-browsers"
  expect_no_out "node-lts  (installed)"
  mkdir -p "$HOME/Library/Caches/ms-playwright/chromium-1000"
  run apps/install-coding.sh --list
  expect_out "playwright-browsers  (installed)"
}

test_apps_node_needs_nvm() {
  local n
  n="$(item_count coding)"
  run_tty "$((n - 1))
y" apps/install-coding.sh
  expect_out "nvm not found. Pick nvm too"
  expect_out "Failed: node-lts"
  expect_no_log_match "nvm install"
}

test_apps_playwright_needs_node() {
  local n
  without npx
  n="$(item_count coding)"
  run_tty "$n
y" apps/install-coding.sh
  expect_out "npx not found. Pick node-lts too"
  expect_out "Failed: playwright-browsers"
  expect_no_log_match "npx"
}

test_apps_point_to_their_page() {
  local app
  for app in $APP_SCRIPTS; do
    expect_file "apps/install-$app.md"
    run "apps/install-$app.sh" --all
    expect_out "Apps that don't come from Homebrew are listed in apps/install-$app.md"
  done
}

test_apps_rerun_skips_installed() {
  run apps/install-coding.sh --all
  : > "$STUB_LOG"
  run apps/install-coding.sh --all
  expect_status 0
  expect_no_log_match "brew install"
  expect_out "visual-studio-code: already installed, skipped"
  expect_out "hashicorp/tap/terraform: already installed, skipped"
  expect_out "node-lts: already installed, skipped"
  expect_out "playwright-browsers: already installed, skipped"
  expect_no_log_match "nvm install"
  expect_no_log_match "npx"
}

test_apps_failed_install_is_reported() {
  export BREW_FAIL="zoom"
  run apps/install-office.sh --all
  expect_out "zoom: failed"
  expect_out "Failed: zoom"
  expect_log "brew install --cask slack"
  expect_log "brew install --cask brave-browser"
}

test_apps_pick_some() {
  run_tty "1 3
y" apps/install-coding.sh
  expect_status 0
  expect_out "Apps: visual-studio-code webstorm"
  expect_log "brew install --cask visual-studio-code"
  expect_log "brew install --cask webstorm"
  expect_log_count "brew install" 2
}

test_apps_pick_with_commas_and_default_yes() {
  run_tty "2,4
" apps/install-office.sh
  expect_status 0
  expect_log "brew install --cask zoom"
  expect_log "brew install --cask chatgpt"
  expect_log_count "brew install" 2
}

test_apps_pick_all_except() {
  local n
  n="$(item_count coding)"
  run_tty "a !1 !3-$n
y" apps/install-coding.sh
  expect_status 0
  expect_log "brew install --cask cursor"
  expect_log_count "brew install" 1
}

test_apps_pick_mixed_kinds() {
  # 9 casks, so 10 is the first formula (git).
  run_tty "9-10
y" apps/install-coding.sh
  expect_out "Apps: session-manager-plugin"
  expect_out "Command-line tools: git"
  expect_log "brew install --cask session-manager-plugin"
  expect_log "brew install git"
}

test_apps_pick_rejects_bad_input() {
  run_tty "0
5-3
99
abc
1-
-2
1-2-3
q" apps/install-office.sh
  expect_status 0
  local bad
  for bad in 0 5-3 99 abc 1- -2 1-2-3; do
    expect_out "not a valid number or range: $bad"
  done
  expect_no_log_match "brew install"
}

test_apps_pick_nothing() {
  run_tty "a !1-5
q" apps/install-office.sh
  expect_status 0
  expect_out "Nothing picked."
  expect_no_log_match "brew install"
}

test_apps_pick_say_no_then_quit() {
  run_tty "1
n
q" apps/install-office.sh
  expect_status 0
  expect_no_log_match "brew install"
}

test_apps_end_of_input_stops() {
  run_tty "" apps/install-office.sh
  expect_status 1
  expect_no_log_match "brew install"
}

test_apps_no_terminal() {
  run apps/install-office.sh
  expect_status 1
  expect_out "No terminal to ask on. Re-run with --all"
  expect_no_log_match "brew install"
}

test_apps_installs_homebrew_when_missing() {
  without brew
  run apps/install-office.sh --all
  expect_log "curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh"
  # The download fails (no network), so it should stop rather than carry on.
  expect_status 1
  expect_no_out "slack: failed"
}
