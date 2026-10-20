# Tests for settings/capture-settings.sh and settings/restore-settings.sh.

# plist <file> key=value ...: writes an XML plist.
plist() {
  python3 -I - "$@" <<'EOF'
import os, plistlib, sys
path = sys.argv[1]
os.makedirs(os.path.dirname(path), exist_ok=True)
with open(path, "wb") as f:
    plistlib.dump(dict(a.split("=", 1) for a in sys.argv[2:]), f)
EOF
}

# pref <domain> key=value ...: a preferences domain the defaults stub knows.
pref() { plist "$STUB_STATE/defaults/$1.plist" "${@:2}"; }

# app <Name.app> <bundle id>: an app in $APPS_DIR.
app() { plist "$APPS_DIR/$1/Contents/Info.plist" "CFBundleIdentifier=$2"; }

# jetbrains_app <Name.app> <config folder> <launcher>: a JetBrains IDE in
# $APPS_DIR whose launcher logs what it's asked to do.
jetbrains_app() {
  local dir="$APPS_DIR/$1/Contents"
  mkdir -p "$dir/Resources" "$dir/MacOS"
  echo "{\"dataDirectoryName\": \"$2\", \"launch\": [{\"launcherPath\": \"../MacOS/$3\"}]}" \
    > "$dir/Resources/product-info.json"
  printf '#!/bin/sh\necho "%s $*" >> "$STUB_LOG"\n' "$3" > "$dir/MacOS/$3"
  chmod +x "$dir/MacOS/$3"
}

# The old Mac: system settings, dotfiles, iTerm2, WebStorm, VS Code, Chrome and
# a couple of apps.
make_old_mac() {
  export APPS_DIR="$TEST_DIR/Applications"
  export BACKUP_DIR="$TEST_DIR/backup"
  SUPPORT="$HOME/Library/Application Support"

  pref com.apple.dock autohide=1
  pref NSGlobalDomain KeyRepeat=2
  plist "$STUB_STATE/defaults-currentHost/com.apple.controlcenter.plist" Bluetooth=18
  pref com.other.thing a=1
  pref com.googlecode.iterm2 "Default Bookmark Guid=abc"
  pref com.tinyspeck.slackmacgap theme=dark
  app Slack.app com.tinyspeck.slackmacgap
  app NoPrefs.app com.example.noprefs
  app iTerm.app com.googlecode.iterm2

  mkdir -p "$HOME/.ssh" "$HOME/.oh-my-zsh/custom" "$HOME/.config/opencode/node_modules/x"
  echo 'alias ll="ls -l"' > "$HOME/.zshrc"
  echo "Host github.com" > "$HOME/.ssh/config"
  echo "PRIVATE KEY" > "$HOME/.ssh/id_ed25519"
  echo "github.com ssh-ed25519 AAAAC3NzaC1lZDI1NTE5" > "$HOME/.ssh/known_hosts"
  echo "alias g=git" > "$HOME/.oh-my-zsh/custom/aliases.zsh"
  echo "{}" > "$HOME/.config/opencode/opencode.json"
  echo "module" > "$HOME/.config/opencode/node_modules/x/index.js"

  local ws="$SUPPORT/JetBrains/WebStorm2026.1"
  mkdir -p "$SUPPORT/JetBrains/WebStorm2024.3/options" "$ws/options" "$ws/keymaps" "$ws/plugins/astro/lib" "$ws/workspace" \
    "$ws/event-log-metadata" "$ws/settingsSync" "$SUPPORT/JetBrains/acp-agents" "$SUPPORT/JetBrains/PyCharm2026.1/options"
  echo old > "$SUPPORT/JetBrains/WebStorm2024.3/options/editor.xml"
  echo new > "$ws/options/editor.xml"
  echo '<project path="/Users/me/secret-project"/>' > "$ws/options/recentProjects.xml"
  echo secret > "$ws/options/codex.oauth.xml"
  echo mine > "$ws/keymaps/Mine.xml"
  echo com.example.off > "$ws/disabled_plugins.txt"
  echo secret > "$ws/user.web.token"
  echo secret > "$ws/webstorm.key"
  echo secret > "$ws/plugin_PBASHSUPPORTPRO.license"
  echo "-Xmx4g" > "$ws/webstorm.vmoptions"
  echo project > "$ws/workspace/x.xml"
  echo stats > "$ws/event-log-metadata/x.json"
  echo sync > "$ws/settingsSync/x.xml"
  echo '{"agents": {}}' > "$SUPPORT/JetBrains/acp-agents/installed.json"
  echo py > "$SUPPORT/JetBrains/PyCharm2026.1/options/editor.xml"
  pref com.jetbrains.WebStorm theme=dark
  app WebStorm.app com.jetbrains.WebStorm

  mkdir -p "$SUPPORT/Code/User/snippets" "$HOME/.vscode/extensions"
  echo '{"editor.fontSize": 14}' > "$SUPPORT/Code/User/settings.json"
  echo '[{"identifier": {"id": "esbenp.prettier-vscode"}}]' > "$HOME/.vscode/extensions/extensions.json"

  local chrome="$SUPPORT/Google/Chrome"
  mkdir -p "$chrome/Default/Extensions/abcdef/1.0/_locales/en"
  echo '{"profile": {"info_cache": {"Default": {"name": "Personal"}}}}' > "$chrome/Local State"
  echo '{}' > "$chrome/Default/Preferences"
  echo '{"roots": {}}' > "$chrome/Default/Bookmarks"
  echo cookies > "$chrome/Default/Cookies"
  echo '{"name": "__MSG_appName__", "default_locale": "en"}' > "$chrome/Default/Extensions/abcdef/1.0/manifest.json"
  echo '{"appName": {"message": "uBlock"}}' > "$chrome/Default/Extensions/abcdef/1.0/_locales/en/messages.json"

  python3 -I - "$ws/plugins" "$chrome/Default/Web Data" <<'EOF'
import sqlite3, sys, zipfile
plugins, web_data = sys.argv[1:3]
with zipfile.ZipFile(plugins + "/astro/lib/astro.jar", "w") as z:
    z.writestr("META-INF/plugin.xml", "<idea-plugin><id>org.jetbrains.plugins.astro</id></idea-plugin>")
with zipfile.ZipFile(plugins + "/single.jar", "w") as z:
    z.writestr("META-INF/plugin.xml", "<idea-plugin><id>com.example.single</id></idea-plugin>")
con = sqlite3.connect(web_data)
con.execute("CREATE TABLE keywords (keyword, short_name, url, prepopulate_id)")
con.executemany("INSERT INTO keywords VALUES (?, ?, ?, ?)", [
    ("gh", "GitHub", "https://github.com/search?q={searchTerms}", 0),
    ("@history", "History", "chrome://history/?q={searchTerms}", 0),
    ("google.com", "Google", "https://google.com/search?q={searchTerms}", 1),
])
con.commit()
EOF
}

# The new Mac: an empty home, no preferences, and the apps installed.
make_new_mac() {
  rm -rf "$HOME" "$STUB_STATE"/defaults* "$APPS_DIR"
  mkdir -p "$HOME"
  : > "$STUB_LOG"
  app Slack.app com.tinyspeck.slackmacgap
  app iTerm.app com.googlecode.iterm2
  app "Google Chrome.app" com.google.Chrome

  jetbrains_app WebStorm.app WebStorm2026.2 webstorm
  jetbrains_app "IntelliJ IDEA.app" IntelliJIdea2026.2 idea

  local code="$APPS_DIR/Visual Studio Code.app/Contents/Resources/app/bin"
  mkdir -p "$code"
  printf '#!/bin/sh\n[ "$1" = --list-extensions ] && exit 0\necho "code $*" >> "$STUB_LOG"\n' > "$code/code"
  chmod +x "$code/code"
}

test_settings_capture() {
  make_old_mac
  run settings/capture-settings.sh
  expect_status 0
  # p: system settings and dotfiles without secrets, a: each app's settings
  # without secrets (both for the repo), b: the private backup.
  local p="$SAVED_ROOT/settings/saved" a="$SAVED_ROOT/appsettings" b="$BACKUP_DIR"

  expect_file "$b/README.txt"
  expect_file "$p/system/defaults/com.apple.dock.plist"
  expect_file "$p/system/defaults/NSGlobalDomain.plist"
  expect_file "$p/system/currentHost/com.apple.controlcenter.plist"
  expect_no_path "$b/system/defaults"
  expect_file "$b/reference/all-defaults/com.other.thing.plist"
  expect_no_path "$p/reference"
  expect_no_path "$p/system/defaults/com.other.thing.plist"

  expect_file "$p/dotfiles/.zshrc"
  expect_file "$b/dotfiles/.ssh/config"
  expect_no_path "$p/dotfiles/.ssh/config"
  expect_file "$p/dotfiles/.ssh/known_hosts"
  expect_no_path "$b/dotfiles/.ssh/known_hosts"
  expect_file "$p/dotfiles/.oh-my-zsh/custom/aliases.zsh"
  expect_file "$p/dotfiles/.config/opencode/opencode.json"
  expect_no_path "$b/dotfiles/.ssh/id_ed25519"
  expect_no_path "$p/dotfiles/.ssh/id_ed25519"
  expect_no_path "$p/dotfiles/.config/opencode/node_modules"

  expect_file "$a/iterm2/saved/com.googlecode.iterm2.plist"

  local ws="$a/webstorm/saved/WebStorm2026.1" wsb="$b/apps/webstorm/WebStorm2026.1"
  expect_eq "$(cat "$ws/options/editor.xml" 2>/dev/null)" new "newest WebStorm settings"
  expect_file "$ws/keymaps/Mine.xml"
  expect_file "$wsb/workspace/x.xml"
  expect_no_path "$ws/workspace"
  expect_file "$ws/webstorm.vmoptions"
  expect_file "$wsb/options/recentProjects.xml"
  expect_no_path "$ws/options/recentProjects.xml"
  expect_no_path "$a/webstorm/saved/WebStorm2024.3"
  expect_no_path "$b/apps/webstorm/WebStorm2024.3"
  expect_no_path "$a/jetbrains"
  local dir
  for dir in "$ws" "$wsb"; do
    expect_no_path "$dir/options/codex.oauth.xml"
    expect_no_path "$dir/user.web.token"
    expect_no_path "$dir/webstorm.key"
    expect_no_path "$dir/plugin_PBASHSUPPORTPRO.license"
    expect_no_path "$dir/plugins"
    expect_no_path "$dir/event-log-metadata"
    expect_no_path "$dir/settingsSync"
  done
  expect_line "$ws/plugins.tsv" "org.jetbrains.plugins.astro	astro"
  expect_line "$ws/plugins.tsv" "com.example.single	single.jar"
  expect_file "$b/apps/webstorm/com.jetbrains.WebStorm.plist"
  expect_file "$b/apps/webstorm/acp-agents/installed.json"
  expect_no_path "$b/apps/plists/com.jetbrains.WebStorm.plist"
  expect_file "$a/pycharm/saved/PyCharm2026.1/options/editor.xml"

  expect_file "$a/vscode/saved/settings.json"
  expect_line "$a/vscode/saved/extensions.txt" "esbenp.prettier-vscode"

  local chrome="$a/chrome/saved"
  expect_line "$chrome/profiles.tsv" "Default	Personal"
  expect_file "$b/browsers/Chrome/Default/Bookmarks"
  expect_no_path "$chrome/Default/Bookmarks"
  expect_no_path "$chrome/Default/Preferences"
  expect_no_path "$b/browsers/Chrome/Default/Cookies"
  expect_line "$chrome/Default/extensions.tsv" "abcdef	uBlock"
  expect_line "$chrome/Default/search-engines.tsv" "gh	GitHub	https://github.com/search?q={searchTerms}"
  expect_eq "$(wc -l < "$chrome/Default/search-engines.tsv" | tr -d ' ')" 1 "only your own search engines"

  expect_line "$b/apps/index.tsv" "com.tinyspeck.slackmacgap	Slack.app"
  expect_file "$b/apps/plists/com.tinyspeck.slackmacgap.plist"
  expect_no_path "$p/apps"
  expect_no_path "$p/browsers"
  expect_no_path "$b/apps/plists/com.example.noprefs.plist"
  expect_no_path "$b/apps/plists/com.googlecode.iterm2.plist"
  expect_out "Edge: no profiles found"
}

# plist_keys <file>: the plist's top-level keys, one per line.
plist_keys() {
  python3 -I -c 'import plistlib, sys; print("\n".join(plistlib.load(open(sys.argv[1], "rb"))))' "$1"
}

test_settings_capture_cleans_plists_for_the_repo() {
  make_old_mac
  pref com.apple.finder ShowPathbar=1 FXRecentFolders=/Users/me/private NSNavLastRootDirectory=/Users/me
  plist "$STUB_STATE/defaults-currentHost/com.apple.controlcenter.plist" Bluetooth=18 IRServiceToken=abcdefgh
  run settings/capture-settings.sh
  expect_status 0
  local keys
  keys="$(plist_keys "$SAVED_ROOT/settings/saved/system/defaults/com.apple.finder.plist")"
  expect_eq "$keys" ShowPathbar "Finder settings without recent folders"
  keys="$(plist_keys "$SAVED_ROOT/settings/saved/system/currentHost/com.apple.controlcenter.plist")"
  expect_eq "$keys" Bluetooth "Control Centre settings without the token"
}

test_settings_capture_keeps_secrets_out_of_the_repo() {
  make_old_mac
  printf 'alias ll="ls -l"\nexport OPENAI_API_KEY="sk-abcdefghijklmnopqrstuvwxyz123456"\n' > "$HOME/.zshrc"
  echo '{"editor.fontSize": 14, "github.token": "abcdefgh12345678"}' > "$HOME/Library/Application Support/Code/User/settings.json"
  echo 'export CLAUDE_CODE_MAX_OUTPUT_TOKENS=100000' > "$HOME/.zprofile"
  echo "//registry.npmjs.org/:_authToken=abc" > "$HOME/.npmrc"
  run settings/capture-settings.sh
  expect_status 0
  expect_file "$BACKUP_DIR/dotfiles/.zshrc"
  expect_no_path "$SAVED_ROOT/settings/saved/dotfiles/.zshrc"
  expect_file "$BACKUP_DIR/apps/editors/Code/settings.json"
  expect_no_path "$SAVED_ROOT/appsettings/vscode/saved/settings.json"
  expect_file "$SAVED_ROOT/settings/saved/dotfiles/.zprofile"
  expect_file "$BACKUP_DIR/dotfiles/.npmrc"
  expect_no_path "$SAVED_ROOT/settings/saved/dotfiles/.npmrc"
  expect_out "Kept out of the repo because they look like they hold a secret:"
  expect_out "dotfiles/.zshrc (line 2)"
  expect_out "apps/editors/Code/settings.json (line 1)"
  expect_no_out "sk-abcdefghijklmnopqrstuvwxyz123456"
  expect_no_out "dotfiles/.zprofile"
}

test_settings_capture_refuses_repo_folder() {
  make_old_mac
  BACKUP_DIR="$PWD/backup" run settings/capture-settings.sh
  expect_status 1
  expect_out "inside this repo, which is public"
}

test_settings_capture_keeps_unrelated_folder() {
  make_old_mac
  mkdir -p "$BACKUP_DIR"
  echo keep > "$BACKUP_DIR/notes.txt"
  run settings/capture-settings.sh
  expect_status 1
  expect_out "isn't a settings backup"
  expect_file "$BACKUP_DIR/notes.txt"
}

test_settings_capture_replaces_earlier_backup() {
  make_old_mac
  run settings/capture-settings.sh
  echo stale > "$BACKUP_DIR/stale.txt"
  echo stale > "$SAVED_ROOT/settings/saved/stale.txt"
  echo stale > "$SAVED_ROOT/appsettings/vscode/saved/stale.txt"
  echo script > "$SAVED_ROOT/appsettings/vscode/capture.sh"
  run settings/capture-settings.sh
  expect_status 0
  expect_no_path "$BACKUP_DIR/stale.txt"
  expect_no_path "$SAVED_ROOT/settings/saved/stale.txt"
  expect_no_path "$SAVED_ROOT/appsettings/vscode/saved/stale.txt"
  expect_file "$SAVED_ROOT/appsettings/vscode/capture.sh"
  expect_file "$SAVED_ROOT/settings/saved/system/defaults/com.apple.dock.plist"
}

test_settings_restore_everything() {
  make_old_mac
  run settings/capture-settings.sh
  make_new_mac
  run settings/restore-settings.sh "$BACKUP_DIR" --yes
  expect_status 0
  local SUPPORT="$HOME/Library/Application Support"

  expect_log "defaults import com.apple.dock"
  expect_log "defaults import NSGlobalDomain"
  expect_log "defaults -currentHost import com.apple.controlcenter"
  expect_no_log "defaults import com.other.thing"
  expect_log "killall Dock Finder SystemUIServer ControlCenter"

  expect_eq "$(cat "$HOME/.zshrc" 2>/dev/null)" 'alias ll="ls -l"' ".zshrc"
  expect_file "$HOME/.ssh/config"
  expect_no_path "$HOME/.oh-my-zsh"
  expect_out ".oh-my-zsh/custom/aliases.zsh: install Oh My Zsh first"

  expect_log "defaults import com.googlecode.iterm2"
  expect_log "defaults import com.tinyspeck.slackmacgap"

  expect_eq "$(cat "$SUPPORT/JetBrains/WebStorm2026.2/options/editor.xml" 2>/dev/null)" new "WebStorm settings"
  expect_file "$SUPPORT/JetBrains/WebStorm2026.2/keymaps/Mine.xml"
  expect_file "$SUPPORT/JetBrains/WebStorm2026.2/workspace/x.xml"
  expect_file "$SUPPORT/JetBrains/acp-agents/installed.json"
  expect_log "defaults import com.jetbrains.WebStorm"
  expect_log "webstorm installPlugins org.jetbrains.plugins.astro com.example.single"
  expect_out "PyCharm isn't installed"
  expect_file "$SUPPORT/JetBrains/WebStorm2026.2/disabled_plugins.txt"

  local idea="$SUPPORT/JetBrains/IntelliJIdea2026.2"
  expect_out "JetBrains: IntelliJ IDEA, from WebStorm2026.1"
  expect_eq "$(cat "$idea/options/editor.xml" 2>/dev/null)" new "WebStorm settings in IDEA"
  expect_file "$idea/keymaps/Mine.xml"
  expect_no_path "$idea/disabled_plugins.txt"
  expect_no_path "$idea/plugins.tsv"
  expect_no_path "$idea/workspace"
  expect_no_path "$idea/webstorm.vmoptions"
  expect_log "idea installPlugins org.jetbrains.plugins.astro com.example.single"

  expect_file "$SUPPORT/Code/User/settings.json"
  expect_no_path "$SUPPORT/Code/User/extensions.txt"
  expect_log "code --install-extension esbenp.prettier-vscode"

  expect_file "$SUPPORT/Google/Chrome/Default/Bookmarks"
  expect_no_out "Couldn't"
}

test_settings_restore_from_the_repo_alone() {
  make_old_mac
  run settings/capture-settings.sh
  make_new_mac
  run settings/restore-settings.sh "$TEST_DIR/nothing" --yes
  expect_status 0
  expect_out "No private backup in $TEST_DIR/nothing"
  expect_log "defaults import com.apple.dock"
  expect_eq "$(cat "$HOME/.zshrc" 2>/dev/null)" 'alias ll="ls -l"' ".zshrc"
  expect_no_path "$HOME/.ssh/config"
  expect_file "$HOME/.ssh/known_hosts"
  expect_file "$HOME/Library/Application Support/JetBrains/WebStorm2026.2/keymaps/Mine.xml"
  expect_no_path "$HOME/Library/Application Support/JetBrains/WebStorm2026.2/workspace"
  expect_no_path "$HOME/Library/Application Support/Google/Chrome/Default/Bookmarks"
  expect_no_log "defaults import com.tinyspeck.slackmacgap"
}

test_settings_restore_saves_what_it_replaces() {
  make_old_mac
  run settings/capture-settings.sh
  make_new_mac
  echo "# new Mac" > "$HOME/.zshrc"
  run settings/restore-settings.sh "$BACKUP_DIR" --yes
  expect_status 0
  expect_eq "$(cat "$HOME/.zshrc")" 'alias ll="ls -l"' ".zshrc"
  expect_eq "$(cat "$BACKUP_DIR"/undo-*/dotfiles/.zshrc 2>/dev/null)" "# new Mac" "saved .zshrc"
  expect_out "What was replaced is saved in $BACKUP_DIR/undo-"
}

test_settings_restore_skips_open_apps() {
  make_old_mac
  run settings/capture-settings.sh
  make_new_mac
  RUNNING="iTerm.app:Slack.app:Google Chrome.app" run settings/restore-settings.sh "$BACKUP_DIR" --yes
  expect_status 0
  expect_no_log "defaults import com.googlecode.iterm2"
  expect_no_log "defaults import com.tinyspeck.slackmacgap"
  expect_no_path "$HOME/Library/Application Support/Google/Chrome/Default/Bookmarks"
  expect_out "iTerm2 is open"
  expect_out "Chrome is open"
  expect_out "Open, so skipped (quit them and re-run): Slack"
  expect_log "defaults import com.apple.dock"
}

test_settings_restore_skips_missing_apps() {
  make_old_mac
  run settings/capture-settings.sh
  make_new_mac
  rm -rf "$APPS_DIR/Slack.app" "$APPS_DIR/WebStorm.app"
  run settings/restore-settings.sh "$BACKUP_DIR" --yes
  expect_status 0
  expect_no_log "defaults import com.tinyspeck.slackmacgap"
  expect_out "Not installed, skipped: Slack"
  expect_out "WebStorm isn't installed"
  expect_no_path "$HOME/Library/Application Support/JetBrains/WebStorm2026.2"
  expect_no_log "defaults import com.jetbrains.WebStorm"
}

test_settings_restore_keeps_own_jetbrains_settings() {
  make_old_mac
  local pc="$HOME/Library/Application Support/JetBrains/PyCharm2026.1"
  mkdir -p "$pc/options"
  echo pycharm > "$pc/options/editor.xml"
  run settings/capture-settings.sh
  make_new_mac
  jetbrains_app PyCharm.app PyCharm2026.2 pycharm
  jetbrains_app "IntelliJ IDEA CE.app" IdeaIC2025.2 idea
  run settings/restore-settings.sh "$BACKUP_DIR" --yes
  expect_status 0
  local SUPPORT="$HOME/Library/Application Support"
  expect_eq "$(cat "$SUPPORT/JetBrains/PyCharm2026.2/options/editor.xml" 2>/dev/null)" pycharm "PyCharm's own settings"
  expect_no_out "PyCharm, from WebStorm"
  expect_out "JetBrains: IntelliJ IDEA CE, from WebStorm2026.1"
  expect_eq "$(cat "$SUPPORT/JetBrains/IdeaIC2025.2/options/editor.xml" 2>/dev/null)" new "WebStorm settings in IDEA CE"
}

test_settings_restore_skips_open_twin() {
  make_old_mac
  run settings/capture-settings.sh
  make_new_mac
  RUNNING="IntelliJ IDEA.app" run settings/restore-settings.sh "$BACKUP_DIR" --yes
  expect_status 0
  expect_out "IntelliJ IDEA is open"
  expect_no_path "$HOME/Library/Application Support/JetBrains/IntelliJIdea2026.2"
  expect_file "$HOME/Library/Application Support/JetBrains/WebStorm2026.2/keymaps/Mine.xml"
}

test_settings_restore_asks_first() {
  make_old_mac
  run settings/capture-settings.sh
  make_new_mac
  # system, dotfiles, iTerm2, WebStorm, IDEA, VS Code, Chrome bookmarks, apps
  run_tty "n
n
n
n
n
n
n
n" settings/restore-settings.sh "$BACKUP_DIR"
  expect_status 0
  expect_no_log_match "defaults import"
  expect_no_log_match "install"
  expect_no_path "$HOME/.zshrc"
}

test_settings_restore_stops_on_ctrl_d() {
  make_old_mac
  run settings/capture-settings.sh
  make_new_mac
  # Enter says no to system settings, then Ctrl-D at the dotfiles question.
  run_tty "" settings/restore-settings.sh "$BACKUP_DIR"
  expect_status 1
  expect_out "Dotfiles"
  expect_no_out "iTerm2"
  expect_no_log_match "defaults import"
}

test_settings_restore_needs_a_backup() {
  run settings/restore-settings.sh "$TEST_DIR/nothing" --yes
  expect_status 1
  expect_out "No settings in $SAVED_ROOT/settings/saved or $TEST_DIR/nothing"
}

test_settings_restore_needs_a_terminal_to_ask() {
  make_old_mac
  run settings/capture-settings.sh
  run settings/restore-settings.sh "$BACKUP_DIR"
  expect_status 1
  expect_out "Re-run with --yes"
}

# appsettings/webstorm, run on its own.

test_webstorm_capture_on_its_own() {
  make_old_mac
  run settings/capture-settings.sh
  echo newer > "$SUPPORT/JetBrains/WebStorm2026.1/options/editor.xml"
  run appsettings/webstorm/capture.sh --with-plugins
  expect_status 0
  local p="$SAVED_ROOT/settings/saved" a="$SAVED_ROOT/appsettings" b="$BACKUP_DIR"
  expect_eq "$(cat "$a/webstorm/saved/WebStorm2026.1/options/editor.xml" 2>/dev/null)" newer "refreshed WebStorm settings"
  expect_file "$b/apps/webstorm/WebStorm2026.1/workspace/x.xml"
  expect_file "$b/apps/webstorm/plugins/astro/lib/astro.jar"
  expect_no_path "$a/webstorm/saved/plugins"
  expect_file "$p/system/defaults/com.apple.dock.plist"
  expect_file "$a/iterm2/saved/com.googlecode.iterm2.plist"
  expect_file "$b/apps/plists/com.tinyspeck.slackmacgap.plist"
}

test_webstorm_capture_refuses_repo_folder() {
  make_old_mac
  BACKUP_DIR="$PWD/backup" run appsettings/webstorm/capture.sh
  expect_status 1
  expect_out "inside this repo, which is public"
}

test_webstorm_capture_keeps_unrelated_folder() {
  make_old_mac
  mkdir -p "$BACKUP_DIR"
  echo keep > "$BACKUP_DIR/notes.txt"
  run appsettings/webstorm/capture.sh
  expect_status 1
  expect_out "isn't a settings backup"
  expect_no_path "$BACKUP_DIR/apps"
}

test_webstorm_capture_without_webstorm() {
  export BACKUP_DIR="$TEST_DIR/backup"
  run appsettings/webstorm/capture.sh
  expect_status 0
  expect_out "no WebStorm settings found"
  expect_no_path "$BACKUP_DIR"
}

test_webstorm_restore_copies_saved_plugins() {
  make_old_mac
  run appsettings/webstorm/capture.sh --with-plugins
  make_new_mac
  run appsettings/webstorm/restore.sh "$BACKUP_DIR" --yes
  expect_status 0
  local ws="$HOME/Library/Application Support/JetBrains/WebStorm2026.2"
  expect_file "$ws/options/editor.xml"
  expect_file "$ws/plugins/astro/lib/astro.jar"
  expect_no_log_match "installPlugins"
}

test_webstorm_restore_saves_what_it_replaces() {
  make_old_mac
  run appsettings/webstorm/capture.sh
  make_new_mac
  local ws="$HOME/Library/Application Support/JetBrains/WebStorm2026.2"
  mkdir -p "$ws/options"
  echo fresh > "$ws/options/editor.xml"
  run appsettings/webstorm/restore.sh "$BACKUP_DIR" --yes
  expect_status 0
  expect_eq "$(cat "$ws/options/editor.xml")" new "editor.xml"
  expect_eq "$(cat "$BACKUP_DIR"/undo-*/JetBrains/WebStorm2026.2/options/editor.xml 2>/dev/null)" fresh "saved editor.xml"
}

test_webstorm_restore_skips_open_webstorm() {
  make_old_mac
  run appsettings/webstorm/capture.sh
  make_new_mac
  RUNNING="WebStorm.app" run appsettings/webstorm/restore.sh "$BACKUP_DIR" --yes
  expect_status 0
  expect_out "WebStorm is open"
  expect_no_path "$HOME/Library/Application Support/JetBrains"
}

test_webstorm_restore_needs_a_backup() {
  run appsettings/webstorm/restore.sh "$TEST_DIR/nothing" --yes
  expect_status 1
  expect_out "No WebStorm settings in $SAVED_ROOT/appsettings/webstorm/saved or $TEST_DIR/nothing/apps/webstorm"
}
