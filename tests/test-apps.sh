# Tests for appsetup/install-*.sh and appsetup/lib.sh.

APP_SCRIPTS="coding editing entertainment gaming office utils"

# items <script> cask|formula|step: the names a script lists.
items() { sed -n "s/^$2 \([^ ]*\).*/\1/p" "appsetup/install-$1.sh"; }
item_count() { { items "$1" cask; items "$1" formula; items "$1" step; } | wc -l | tr -d ' '; }
category() { sed -n 's/^run_installer "\(.*\)" .*/\1/p' "appsetup/install-$1.sh"; }

test_apps_help() {
  local app
  for app in $APP_SCRIPTS; do
    run "appsetup/install-$app.sh" --help
    expect_status 0
    expect_out "Usage: install-$app.sh [--all | --list | --help]"
  done
}

test_apps_unknown_option() {
  run appsetup/install-office.sh --bogus
  expect_status 1
  expect_out "Unknown option: --bogus"
  expect_no_log_match "brew install"
}

test_apps_list_shows_every_item() {
  local app name
  for app in $APP_SCRIPTS; do
    run "appsetup/install-$app.sh" --list
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
  run appsetup/install-office.sh --list
  expect_out "slack  (installed)"
  expect_no_out "zoom  (installed)"
  run appsetup/install-coding.sh --list
  expect_out "hashicorp/tap/terraform  (installed)"
  expect_no_out "kind  (installed)"
}

test_apps_all_installs_everything() {
  local app name
  for app in $APP_SCRIPTS; do
    run "appsetup/install-$app.sh" --all
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
  run appsetup/install-coding.sh --list
  expect_out "Other setup"
  expect_out ") node-lts"
  expect_out ") playwright-browsers"
  expect_no_out "node-lts  (installed)"
  mkdir -p "$HOME/Library/Caches/ms-playwright/chromium-1000"
  run appsetup/install-coding.sh --list
  expect_out "playwright-browsers  (installed)"
}

test_apps_node_needs_nvm() {
  # Up from "All" wraps to the last item, so two ups is node-lts.
  run_tty "kk " appsetup/install-coding.sh
  expect_out "Other setup: node-lts"
  expect_out "nvm not found. Pick nvm too"
  expect_out "Failed: node-lts"
  expect_no_log_match "nvm install"
}

test_apps_playwright_needs_node() {
  without npx
  run_tty "k " appsetup/install-coding.sh
  expect_out "npx not found. Pick node-lts too"
  expect_out "Failed: playwright-browsers"
  expect_no_log_match "npx"
}

test_apps_point_to_their_page() {
  local app
  for app in $APP_SCRIPTS; do
    expect_file "appsetup/install-$app.md"
    run "appsetup/install-$app.sh" --all
    expect_out "Apps that don't come from Homebrew are listed in appsetup/install-$app.md"
  done
}

test_apps_rerun_skips_installed() {
  run appsetup/install-coding.sh --all
  : > "$STUB_LOG"
  run appsetup/install-coding.sh --all
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
  run appsetup/install-office.sh --all
  expect_out "zoom: failed"
  expect_out "Failed: zoom"
  expect_log "brew install --cask slack"
  expect_log "brew install --cask microsoft-edge"
}

# downs <n>: the j key n times, to move down n rows.
downs() {
  local i=0
  while [ $i -lt "$1" ]; do printf j; i=$((i + 1)); done
}

test_apps_pick_some() {
  # The cursor starts on "All"; one down is the first item.
  run_tty "j jj " appsetup/install-coding.sh
  expect_status 0
  expect_out "Coding: pick what to install"
  expect_out "[x] visual-studio-code"
  expect_out "2 of $(item_count coding) picked"
  expect_out "Apps: visual-studio-code webstorm"
  expect_log "brew install --cask visual-studio-code"
  expect_log "brew install --cask webstorm"
  expect_log_count "brew install" 2
}

test_apps_pick_with_arrow_keys() {
  local down="${ESC}[B" up="${ESC}[A"
  run_tty "$down$down$down $up$up " appsetup/install-office.sh
  expect_status 0
  expect_log "brew install --cask zoom"
  expect_log "brew install --cask slack"
  expect_log_count "brew install" 2
}

test_apps_pick_all_row() {
  run_tty " " appsetup/install-office.sh
  expect_status 0
  expect_out "[x] All (7 items)"
  expect_out "7 of 7 picked"
  expect_log_count "brew install" 7
}

test_apps_pick_all_key() {
  run_tty "a" appsetup/install-utils.sh
  expect_status 0
  expect_log "brew install --cask 1password"
  expect_log "brew install --cask macs-fan-control"
  expect_log "brew install --cask vorssaint"
}

test_apps_pick_all_except() {
  # Tick everything, then untick the 6th item (two up from "All").
  run_tty "akk " appsetup/install-office.sh
  expect_status 0
  expect_out "[-] All (7 items)"
  expect_log_count "brew install" 6
  expect_no_log "brew install --cask google-chrome"
}

test_apps_pick_mixed_kinds() {
  # 14 casks, so the 15th item is the first formula (git). The headings are
  # skipped by the cursor.
  run_tty "$(downs 14) j " appsetup/install-coding.sh
  expect_out "Apps: session-manager-plugin"
  expect_out "Command-line tools: git"
  expect_log "brew install --cask session-manager-plugin"
  expect_log "brew install git"
  expect_log_count "brew install" 2
}

test_apps_pick_scrolls_to_the_end() {
  # Coding has more rows than fit on a 24-line terminal.
  run_tty "$(downs "$(item_count coding)") " appsetup/install-coding.sh
  expect_status 0
  expect_out "[x] playwright-browsers"
  expect_out "Other setup: playwright-browsers"
  expect_log "npx -y playwright install"
  expect_no_log_match "brew install"
}

test_apps_pick_ignores_other_keys() {
  run_tty "xyz7!j " appsetup/install-office.sh
  expect_status 0
  expect_log "brew install --cask slack"
  expect_log_count "brew install" 1
}

test_apps_pick_untick_all() {
  run_tty "aa
q" appsetup/install-office.sh
  expect_status 0
  expect_out "Nothing picked."
  expect_no_log_match "brew install"
}

test_apps_pick_nothing() {
  run_tty "
q" appsetup/install-office.sh
  expect_status 0
  expect_out "Nothing picked."
  expect_no_log_match "brew install"
}

test_apps_pick_then_quit() {
  run_tty "j q" appsetup/install-office.sh
  expect_status 0
  expect_no_log_match "brew install"
}

test_apps_end_of_input_stops() {
  # Enter with nothing ticked, then the answers run out and Ctrl-D is sent.
  run_tty "" appsetup/install-office.sh
  expect_status 1
  expect_no_log_match "brew install"
}

test_apps_no_terminal() {
  run appsetup/install-office.sh
  expect_status 1
  expect_out "No terminal to ask on. Re-run with --all"
  expect_no_log_match "brew install"
}

test_apps_installs_homebrew_when_missing() {
  without brew
  run appsetup/install-office.sh --all
  expect_log "curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh"
  # The download fails (no network), so it should stop rather than carry on.
  expect_status 1
  expect_no_out "slack: failed"
}
