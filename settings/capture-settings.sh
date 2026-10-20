#!/usr/bin/env bash
#
# Capture this Mac's settings so restore-settings.sh can put them back on a new
# Mac: macOS system settings, shell dotfiles, iTerm2, WebStorm (through
# appsettings/webstorm/capture.sh), other JetBrains IDEs, VS Code and Cursor,
# browsers (Chrome, Brave, Edge, Firefox, Safari) and the preferences of every
# app in /Applications.
#
# This repo is public, so the capture is split in two:
#   settings/saved/      settings without secrets, kept in the repo: system
#                        settings, dotfiles, iTerm2, JetBrains and editor
#                        settings, browser extension lists. Commit them.
#   ~/MacSettingsBackup  everything personal: bookmarks, app preferences,
#                        fonts, ssh and aws config, and any file that looks
#                        like it holds a secret. Copy that folder (or the .zip
#                        made next to it) to the new Mac yourself.
# Passwords, cookies, browser history and IDE login tokens are left out.
#
# Usage:
#   ./settings/capture-settings.sh                    writes settings/saved and ~/MacSettingsBackup
#   BACKUP_DIR=/Volumes/USB/settings ./settings/capture-settings.sh
#
# Safari's settings and bookmarks can only be read when the terminal app has
# Full Disk Access (System Settings → Privacy & Security → Full Disk Access).
#
# Safe to re-run: settings/saved and an earlier backup in the same folder are
# replaced.
# Written for the macOS default bash (3.2), so no associative arrays.

set -u

HERE="$(cd "$(dirname "$0")" && pwd)"
REPO_DIR="$(dirname "$HERE")"
BACKUP_DIR="${BACKUP_DIR:-$HOME/MacSettingsBackup}"
PUBLIC_DIR="${PUBLIC_DIR:-$HERE/saved}"
APPS_DIR="${APPS_DIR:-/Applications}"
SUPPORT="$HOME/Library/Application Support"
MARKER=".mac-settings-backup"

# System settings restored on the new Mac. Each one is a whole preferences
# domain, so everything in that part of System Settings comes back together.
SYSTEM_DOMAINS="
NSGlobalDomain
com.apple.dock
com.apple.finder
com.apple.screencapture
com.apple.AppleMultitouchTrackpad
com.apple.driver.AppleBluetoothMultitouch.trackpad
com.apple.AppleMultitouchMouse
com.apple.driver.AppleBluetoothMultitouch.mouse
com.apple.symbolichotkeys
com.apple.HIToolbox
com.apple.WindowManager
com.apple.spaces
com.apple.menuextra.clock
com.apple.controlcenter
com.apple.Spotlight
com.apple.universalaccess
com.apple.desktopservices
com.apple.screensaver
com.apple.Terminal
com.apple.TextEdit
com.apple.Preview
com.apple.ActivityMonitor
"
# Settings macOS keeps per machine (menu bar icons, screen saver).
CURRENT_HOST_DOMAINS="
NSGlobalDomain
com.apple.controlcenter
com.apple.screensaver
"

# Dotfiles and config files under ~. Credentials (~/.aws/credentials,
# ~/.kube/config, ssh keys) are left out on purpose.
DOTFILES="
.zshrc
.zprofile
.zshenv
.bashrc
.bash_profile
.profile
.gitconfig
.gitignore_global
.vimrc
.tmux.conf
.npmrc
.p10k.zsh
.ssh/config
.aws/config
.config/git
.config/starship.toml
.config/opencode
.oh-my-zsh/custom
"

# VS Code-like editors: name|folder in Application Support|extensions folder in ~
EDITORS="
VS Code|Code|.vscode
Cursor|Cursor|.cursor
Antigravity|Antigravity|.antigravity
"

# Chrome-like browsers: name|folder in Application Support
BROWSERS="
Chrome|Google/Chrome
Brave|BraveSoftware/Brave-Browser
Edge|Microsoft Edge
"

# JetBrains config folders worth keeping. Caches, logs, plugin binaries and
# login tokens stay behind; plugins are listed so they can be reinstalled.
JETBRAINS_KEEP="options codestyles colors keymaps templates fileTemplates inspection tools quicklists scratches disabled_plugins.txt"
JETBRAINS_SECRETS="*oauth* *token* *Token* *password* *Password* security.xml"

bold() { printf '\033[1m%s\033[0m\n' "$*"; }
info() { printf '  %s\n' "$*"; }
warn() { printf '\033[33m  ! %s\033[0m\n' "$*"; }

py() { python3 -I "$HERE/settings.py" "$@"; }

# export_domain <file> <domain> [-currentHost]: saves the domain as a plist.
# Fails if this Mac has no such domain.
export_domain() {
  local file="$1" domain="$2"
  if [ -n "${3:-}" ]; then
    defaults -currentHost read "$domain" >/dev/null 2>&1 || return 1
    mkdir -p "$(dirname "$file")"
    defaults -currentHost export "$domain" "$file" 2>/dev/null
  else
    defaults read "$domain" >/dev/null 2>&1 || return 1
    mkdir -p "$(dirname "$file")"
    defaults export "$domain" "$file" 2>/dev/null
  fi
}

# copy_into <source> <dest folder>: copies a file, or a folder that isn't
# empty, if it exists.
copy_into() {
  [ -f "$1" ] || [ -n "$(ls -A "$1" 2>/dev/null)" ] || return 1
  mkdir -p "$2"
  cp -R "$1" "$2/" 2>/dev/null
}

# ---------------------------------------------------------------------------

prepare_backup_dir() {
  case "$BACKUP_DIR" in
    "$REPO_DIR" | "$REPO_DIR"/*)
      warn "$BACKUP_DIR is inside this repo, which is public. Pick a folder outside it."
      exit 1 ;;
  esac
  if [ -e "$BACKUP_DIR" ]; then
    if [ ! -f "$BACKUP_DIR/$MARKER" ]; then
      warn "$BACKUP_DIR already exists and isn't a settings backup. Move it or set BACKUP_DIR."
      exit 1
    fi
    rm -rf "$BACKUP_DIR"
  fi
  mkdir -p "$BACKUP_DIR" || exit 1
  touch "$BACKUP_DIR/$MARKER"
}

# Everything is captured here first, then split_capture sorts it.
STAGE="$(mktemp -d)"
trap 'rm -rf "$STAGE"' EXIT

split_capture() {
  bold "Sorting out what's safe for the repo..."
  rm -rf "$PUBLIC_DIR"
  py split "$STAGE" "$PUBLIC_DIR" "$BACKUP_DIR"
}

capture_system() {
  bold "System settings..."
  local domain n=0
  for domain in $SYSTEM_DOMAINS; do
    export_domain "$STAGE/system/defaults/$domain.plist" "$domain" && n=$((n + 1))
  done
  for domain in $CURRENT_HOST_DOMAINS; do
    export_domain "$STAGE/system/currentHost/$domain.plist" "$domain" -currentHost && n=$((n + 1))
  done
  info "$n settings groups (Dock, Finder, keyboard, trackpad, menu bar, shortcuts, ...)"

  # Everything else, for reference only. restore-settings.sh doesn't touch it.
  local all="$STAGE/reference/all-defaults" count=0
  mkdir -p "$all"
  defaults export NSGlobalDomain "$all/NSGlobalDomain.plist" 2>/dev/null
  for domain in $(defaults domains 2>/dev/null | tr -d ' ' | tr ',' ' '); do
    case "$domain" in */*) continue ;; esac
    defaults export "$domain" "$all/$domain.plist" 2>/dev/null && count=$((count + 1))
  done
  info "$count other preference files kept for reference"

  py text-replacements "$HOME/Library/KeyboardServices/TextReplacements.db" \
    > "$STAGE/system/text-replacements.tsv"
  [ -s "$STAGE/system/text-replacements.tsv" ] || rm -f "$STAGE/system/text-replacements.tsv"
  copy_into "$HOME/Library/Fonts" "$STAGE/system" && info "your fonts"
  local workflow
  for workflow in "$HOME"/Library/Services/*.workflow; do
    copy_into "$workflow" "$STAGE/system/Services"
  done
  [ -d "$STAGE/system/Services" ] && info "Quick Actions (Services)"
  copy_into "$HOME/Library/LaunchAgents" "$STAGE/reference"

  {
    command -v sw_vers >/dev/null && sw_vers
    command -v scutil >/dev/null && echo "Computer name: $(scutil --get ComputerName 2>/dev/null)"
    echo "Time zone: $(readlink /etc/localtime 2>/dev/null | sed 's|.*zoneinfo/||')"
    if command -v pmset >/dev/null; then echo; echo "Power (pmset -g custom):"; pmset -g custom 2>/dev/null; fi
  } > "$STAGE/system/info.txt"
}

capture_dotfiles() {
  bold "Dotfiles..."
  local f n=0
  for f in $DOTFILES; do
    [ -e "$HOME/$f" ] || continue
    py copy "$HOME/$f" "$STAGE/dotfiles/$f" --exclude .git --exclude node_modules >/dev/null \
      && n=$((n + 1))
  done
  info "$n files and folders"
}

capture_iterm() {
  bold "iTerm2..."
  local dest="$STAGE/apps/iterm2"
  if ! export_domain "$dest/com.googlecode.iterm2.plist" com.googlecode.iterm2; then
    info "no iTerm2 settings found"
    return
  fi
  copy_into "$SUPPORT/iTerm2/DynamicProfiles" "$dest"
  copy_into "$SUPPORT/iTerm2/Scripts" "$dest"
  info "profiles, colours, key bindings and window arrangements"
}

capture_webstorm() {
  STAGE_DIR="$STAGE" "$REPO_DIR/appsettings/webstorm/capture.sh"
}

# The newest config folder for each other JetBrains IDE, e.g. PyCharm2026.1.
# WebStorm has its own capture_webstorm.
jetbrains_dirs() {
  local dir product last=""
  for dir in "$SUPPORT"/JetBrains/*; do
    case "$(basename "$dir")" in WebStorm*) continue ;; esac
    [ -d "$dir/options" ] && basename "$dir"
  done | sort -r | while read -r dir; do
    product="${dir%%[0-9]*}"
    [ "$product" = "$last" ] && continue
    last="$product"
    echo "$dir"
  done
}

capture_jetbrains() {
  bold "Other JetBrains IDEs..."
  local name src dest item pattern found=false
  for name in $(jetbrains_dirs); do
    found=true
    src="$SUPPORT/JetBrains/$name"
    dest="$STAGE/apps/jetbrains/$name"
    mkdir -p "$dest"
    for item in $JETBRAINS_KEEP; do
      [ -e "$src/$item" ] && cp -R "$src/$item" "$dest/"
    done
    for pattern in $JETBRAINS_SECRETS; do
      find "$dest/options" -name "$pattern" -exec rm -f {} + 2>/dev/null
    done
    py jetbrains-plugins "$src/plugins" > "$dest/plugins.tsv"
    info "$name: settings and $(wc -l < "$dest/plugins.tsv" | tr -d ' ') plugins"
  done
  [ "$found" = true ] || info "no other JetBrains IDE settings found"
}

capture_editors() {
  bold "VS Code and Cursor..."
  local name folder extdir user dest found=false
  while IFS='|' read -r name folder extdir; do
    [ -n "$name" ] || continue
    user="$SUPPORT/$folder/User"
    [ -d "$user" ] || continue
    found=true
    dest="$STAGE/apps/editors/$folder"
    mkdir -p "$dest"
    copy_into "$user/settings.json" "$dest"
    copy_into "$user/keybindings.json" "$dest"
    copy_into "$user/snippets" "$dest"
    py editor-extensions "$HOME/$extdir/extensions/extensions.json" > "$dest/extensions.txt"
    info "$name: settings, key bindings, snippets and $(wc -l < "$dest/extensions.txt" | tr -d ' ') extensions"
  done <<< "$EDITORS"
  [ "$found" = true ] || info "no VS Code or Cursor settings found"
}

capture_browsers() {
  bold "Browsers..."
  local name folder root profile dir dest
  while IFS='|' read -r name folder; do
    [ -n "$name" ] || continue
    root="$SUPPORT/$folder"
    if [ ! -f "$root/Local State" ]; then
      info "$name: no profiles found"
      continue
    fi
    dest="$STAGE/browsers/$name"
    mkdir -p "$dest"
    py chromium-profiles "$root/Local State" > "$dest/profiles.tsv"
    for dir in "$root"/*; do
      [ -f "$dir/Preferences" ] || continue
      profile="$(basename "$dir")"
      mkdir -p "$dest/$profile"
      copy_into "$dir/Bookmarks" "$dest/$profile"
      copy_into "$dir/Preferences" "$dest/$profile"
      copy_into "$dir/Custom Dictionary.txt" "$dest/$profile"
      py chromium-extensions "$dir" > "$dest/$profile/extensions.tsv"
      py chromium-search-engines "$dir/Web Data" > "$dest/$profile/search-engines.tsv"
    done
    info "$name: $(wc -l < "$dest/profiles.tsv" | tr -d ' ') profiles (bookmarks, extensions, search engines)"
  done <<< "$BROWSERS"

  capture_firefox
  capture_safari
}

capture_firefox() {
  local root="$SUPPORT/Firefox" dir dest latest n=0
  if [ ! -f "$root/profiles.ini" ]; then
    info "Firefox: no profiles found"
    return
  fi
  copy_into "$root/profiles.ini" "$STAGE/browsers/Firefox"
  for dir in "$root"/Profiles/*; do
    [ -f "$dir/prefs.js" ] || continue
    dest="$STAGE/browsers/Firefox/$(basename "$dir")"
    mkdir -p "$dest"
    copy_into "$dir/prefs.js" "$dest"
    copy_into "$dir/user.js" "$dest"
    copy_into "$dir/containers.json" "$dest"
    copy_into "$dir/chrome" "$dest"
    latest="$(ls -1 "$dir/bookmarkbackups" 2>/dev/null | sort | tail -1)"
    [ -n "$latest" ] && copy_into "$dir/bookmarkbackups/$latest" "$dest"
    py firefox-addons "$dir/extensions.json" > "$dest/extensions.tsv"
    n=$((n + 1))
  done
  info "Firefox: $n profiles (settings, bookmark backup, add-ons)"
}

capture_safari() {
  local dest="$STAGE/browsers/Safari"
  if [ ! -d "$APPS_DIR/Safari.app" ]; then
    return
  fi
  # Safari keeps everything in its sandbox, which needs Full Disk Access.
  if ! export_domain "$dest/com.apple.Safari.plist" com.apple.Safari; then
    warn "Safari: settings and bookmarks need Full Disk Access for this terminal app"
    info "  (System Settings → Privacy & Security → Full Disk Access), then re-run."
    info "  Bookmarks also come back through iCloud if Safari syncs there."
    return
  fi
  copy_into "$HOME/Library/Safari/Bookmarks.plist" "$dest"
  info "Safari: settings and bookmarks"
}

# Every app in /Applications that keeps preferences with macOS.
capture_apps() {
  bold "App preferences..."
  local app id dest="$STAGE/apps/plists" n=0
  mkdir -p "$dest"
  : > "$STAGE/apps/index.tsv"
  for app in "$APPS_DIR"/*.app; do
    [ -d "$app" ] || continue
    id="$(defaults read "$app/Contents/Info" CFBundleIdentifier 2>/dev/null)"
    [ -n "$id" ] || continue
    case "$id" in com.googlecode.iterm2 | com.apple.Safari | com.jetbrains.WebStorm) continue ;; esac
    export_domain "$dest/$id.plist" "$id" || continue
    printf '%s\t%s\n' "$id" "$(basename "$app")" >> "$STAGE/apps/index.tsv"
    n=$((n + 1))
  done
  info "$n apps"
}

write_readme() {
  cat > "$BACKUP_DIR/README.txt" <<EOF
Mac settings captured on $(date '+%Y-%m-%d') by MACSETUP-M1/settings/capture-settings.sh.

This folder holds personal data. Keep it off GitHub and other public places.
The settings without secrets are in the repo, in settings/saved. To put
everything back on a new Mac, copy this folder to ~/MacSettingsBackup on it,
then run:

  ~/projects/MACSETUP-M1/settings/restore-settings.sh

system/      fonts and text replacements
dotfiles/    ssh and aws config, and any dotfile that looks like it holds a
             secret
apps/        the preferences of every app in /Applications (index.tsv lists
             them), WebStorm's workspaces, scratches and macOS preferences, and
             JetBrains files with accounts or recent projects
browsers/    bookmarks and browser preferences per profile
reference/   every other preferences file and your LaunchAgents. Nothing here
             is restored automatically.
EOF
}

zip_backup() {
  command -v ditto >/dev/null 2>&1 || return
  local zip="$BACKUP_DIR.zip"
  rm -f "$zip"
  ditto -c -k --keepParent "$BACKUP_DIR" "$zip" && info "Also zipped to $zip"
}

# ---------------------------------------------------------------------------

if [ "${1:-}" = --help ] || [ "${1:-}" = -h ]; then
  sed -n '3,28p' "$0" | sed 's/^# \{0,1\}//'
  exit 0
fi

prepare_backup_dir
echo "Capturing settings"
echo
capture_system
echo; capture_dotfiles
echo; capture_iterm
echo; capture_webstorm
echo; capture_jetbrains
echo; capture_editors
echo; capture_browsers
echo; capture_apps
echo; split_capture
write_readme

echo
bold "Done."
info "Commit settings/saved to the repo (check git diff first)."
info "Private backup: $(du -sh "$BACKUP_DIR" | cut -f1) in $BACKUP_DIR"
zip_backup
info "Copy it to the new Mac yourself (AirDrop, USB drive, iCloud Drive), then"
info "run settings/restore-settings.sh there."
