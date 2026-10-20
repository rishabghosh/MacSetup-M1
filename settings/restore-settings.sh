#!/usr/bin/env bash
#
# Put back the settings capture-settings.sh saved on the old Mac: the ones in
# the repo (settings/saved and appsettings/<app>/saved) together with the
# private backup copied over from
# the old Mac. Without the private backup, only the repo's settings come back.
# Run it after the apps are installed (appsetup/install-*.sh), because app
# settings are only restored for apps that are there.
#
# Usage:
#   ./settings/restore-settings.sh [backup folder]   default ~/MacSettingsBackup
#   ./settings/restore-settings.sh --yes             restore everything without asking
#
# Each part (system settings, dotfiles, iTerm2, ...) is asked about in turn.
# Anything that gets replaced is saved first to <backup folder>/undo-<time>, so
# you can copy it back. An app's settings are only restored while the app is
# closed, so run this from Terminal rather than iTerm2.
#
# Written for the macOS default bash (3.2), so no associative arrays.

set -u

PRIVATE_DIR="$HOME/MacSettingsBackup"
APPS_DIR="${APPS_DIR:-/Applications}"
SUPPORT="$HOME/Library/Application Support"
HERE="$(cd "$(dirname "$0")" && pwd)"
SAVED_ROOT="${SAVED_ROOT:-$(dirname "$HERE")}"
YES=false
for arg in "$@"; do
  case "$arg" in
    --yes | -y) YES=true ;;
    --help | -h) sed -n '3,19p' "$0" | sed 's/^# \{0,1\}//'; exit 0 ;;
    -*) echo "Unknown option: $arg" >&2; exit 1 ;;
    *) PRIVATE_DIR="$arg" ;;
  esac
done
UNDO="$PRIVATE_DIR/undo-$(date +%Y%m%d-%H%M%S)"

# Editors: name|folder in Application Support|command-line tool|tool inside the app
EDITORS="
VS Code|Code|code|Visual Studio Code.app/Contents/Resources/app/bin/code
Cursor|Cursor|cursor|Cursor.app/Contents/Resources/app/bin/cursor
Antigravity|Antigravity|antigravity|Antigravity.app/Contents/Resources/app/bin/antigravity
"
# Chrome-like browsers: name|folder in Application Support|app
BROWSERS="
Chrome|Google/Chrome|Google Chrome.app
Brave|BraveSoftware/Brave-Browser|Brave Browser.app
Edge|Microsoft Edge|Microsoft Edge.app
"
# JetBrains IDEs that get WebStorm's saved settings when the backup has none of
# their own: config folder name before the version|name
WEBSTORM_TWINS="
IntelliJIdea|IntelliJ IDEA
IdeaIC|IntelliJ IDEA CE
PyCharm|PyCharm
PyCharmCE|PyCharm CE
"
# What appsettings/webstorm saves that only makes sense in WebStorm, so the
# twins above don't get it. disabled_plugins.txt too: they bundle other plugins.
WEBSTORM_ONLY="workspace tasks scratches javascript extensions aia-task-history jdbc-drivers light-edit ssl
webstorm.vmoptions bundled_plugins.txt disabled_plugins.txt disabled_update.txt early-access-registry.txt
migration_installed_plugins.txt splash-subscription-mode.txt"

bold() { printf '\033[1m%s\033[0m\n' "$*"; }
info() { printf '  %s\n' "$*"; }
warn() { printf '\033[33m  ! %s\033[0m\n' "$*"; }

py() { python3 -I "$HERE/settings.py" "$@"; }

# Ctrl-D stops the script.
confirm() {
  local reply
  [ "$YES" = true ] && return 0
  read -r -p "$1 [y/N] " reply </dev/tty || { echo; exit 1; }
  case "$reply" in [yY]*) return 0 ;; *) return 1 ;; esac
}

# app_running <App.app>
app_running() { pgrep -f "/$1/Contents/MacOS/" >/dev/null 2>&1; }

# import_domain <plist> <domain> [-currentHost]: replaces the domain with the
# saved one, after saving the current values to the undo folder.
import_domain() {
  local file="$1" domain="$2" host="${3:-}" undo="$UNDO/defaults"
  [ -n "$host" ] && undo="$UNDO/defaults-currentHost"
  mkdir -p "$undo"
  if [ -n "$host" ]; then
    defaults -currentHost export "$domain" "$undo/$domain.plist" 2>/dev/null
    defaults -currentHost import "$domain" "$file"
  else
    defaults export "$domain" "$undo/$domain.plist" 2>/dev/null
    defaults import "$domain" "$file"
  fi
}

# sync_into <source folder> <dest folder> <undo name> [--exclude <name>]...:
# copies the source's contents over the destination. Replaced files go to the
# undo folder.
sync_into() {
  local src="$1" dest="$2" undo="$UNDO/$3"
  shift 3
  py copy "$src" "$dest" --undo "$undo" "$@" >/dev/null
}

# copy_file <source> <dest> <undo name>: the same for one file.
copy_file() {
  mkdir -p "$(dirname "$2")"
  if [ -e "$2" ]; then
    mkdir -p "$UNDO/$3"
    cp -R "$2" "$UNDO/$3/"
  fi
  cp -R "$1" "$2"
}

# saved_path <path inside the backup>: where that file is kept, in the repo or
# the private backup, for messages. BACKUP_DIR is a temporary merge of the two.
saved_path() {
  local repo
  repo="$(py repo-path "$SAVED_ROOT" "$1")"
  if [ -e "$repo" ]; then echo "$repo"; else echo "$PRIVATE_DIR/$1"; fi
}

# ---------------------------------------------------------------------------

restore_system() {
  [ -d "$BACKUP_DIR/system/defaults" ] || return
  bold "System settings"
  info "Dock, Finder, keyboard, trackpad, mouse, menu bar, shortcuts, screenshots, ..."
  confirm "  Restore them?" || return
  local file n=0
  for file in "$BACKUP_DIR"/system/defaults/*.plist; do
    import_domain "$file" "$(basename "$file" .plist)" && n=$((n + 1))
  done
  for file in "$BACKUP_DIR"/system/currentHost/*.plist; do
    [ -f "$file" ] || continue
    import_domain "$file" "$(basename "$file" .plist)" -currentHost && n=$((n + 1))
  done
  info "$n settings groups restored"

  local dir
  for dir in Fonts Services; do
    [ -d "$BACKUP_DIR/system/$dir" ] || continue
    mkdir -p "$HOME/Library/$dir"
    py copy "$BACKUP_DIR/system/$dir" "$HOME/Library/$dir" --keep-existing >/dev/null
    info "$dir copied"
  done
  killall Dock Finder SystemUIServer ControlCenter >/dev/null 2>&1
  info "Some settings (keyboard, trackpad) take effect after you log out and back in."
}

restore_dotfiles() {
  [ -d "$BACKUP_DIR/dotfiles" ] || return
  bold "Dotfiles"
  info "$(cd "$BACKUP_DIR/dotfiles" && find . -type f | sed 's|^\./||' | grep -v '^\.oh-my-zsh/\|^\.config/opencode/' | tr '\n' ' ')"
  confirm "  Restore them?" || return
  local rel src dest
  (cd "$BACKUP_DIR/dotfiles" && find . -type f) | sed 's|^\./||' | while read -r rel; do
    src="$BACKUP_DIR/dotfiles/$rel"
    dest="$HOME/$rel"
    # The Oh My Zsh installer won't run if ~/.oh-my-zsh already exists.
    case "$rel" in
      .oh-my-zsh/*)
        [ -d "$HOME/.oh-my-zsh" ] || { info "$rel: install Oh My Zsh first, then re-run"; continue; } ;;
    esac
    if [ ! -e "$dest" ]; then
      mkdir -p "$(dirname "$dest")"
      cp "$src" "$dest"
      info "$rel: copied"
    elif cmp -s "$src" "$dest"; then
      :
    elif confirm "  ~/$rel is different on this Mac. Replace it? (yours is kept in the undo folder)"; then
      copy_file "$src" "$dest" "dotfiles/$(dirname "$rel")"
      info "$rel: replaced"
    else
      info "$rel: left alone. Compare with: diff ~/$rel '$(saved_path "dotfiles/$rel")'"
    fi
  done
  [ -f "$HOME/.ssh/config" ] && chmod 600 "$HOME/.ssh/config"
}

restore_iterm() {
  local src="$BACKUP_DIR/apps/iterm2"
  [ -f "$src/com.googlecode.iterm2.plist" ] || return
  bold "iTerm2"
  if [ ! -d "$APPS_DIR/iTerm.app" ]; then
    info "iTerm2 isn't installed. Install it (appsetup/install-coding.sh), then re-run."
    return
  fi
  if app_running iTerm.app; then
    warn "iTerm2 is open, and it would overwrite the settings when it quits."
    info "Quit it and run this script from Terminal to restore them."
    return
  fi
  confirm "  Restore profiles, colours and key bindings?" || return
  import_domain "$src/com.googlecode.iterm2.plist" com.googlecode.iterm2
  local dir
  for dir in DynamicProfiles Scripts; do
    [ -d "$src/$dir" ] && sync_into "$src/$dir" "$SUPPORT/iTerm2/$dir" "iTerm2/$dir"
  done
  info "restored"
}

# The installed JetBrains IDE for a saved config folder like WebStorm2024.3:
# prints "<its config folder> <launcher>", e.g. WebStorm2026.1 and its path.
jetbrains_install_for() {
  local product="${1%%[0-9]*}" app line
  for app in "$APPS_DIR"/*.app; do
    line="$(py jetbrains-app "$app")"
    [ -n "$line" ] || continue
    case "$line" in "$product"[0-9]*) echo "$line"; return ;; esac
  done
}

# apply_jetbrains <saved folder> <installed IDE line> <question> [--exclude <name>]...:
# copies the saved settings into the installed IDE's config folder and offers
# to install the saved plugins.
apply_jetbrains() {
  local saved="$1" line="$2" question="$3" target launcher app ids
  shift 3
  target="$(printf '%s\n' "$line" | cut -f1)"
  launcher="$(printf '%s\n' "$line" | cut -f2)"
  app="${launcher%%.app/*}.app"
  if app_running "$(basename "$app")"; then
    warn "$(basename "$app" .app) is open. Quit it and re-run to restore its settings."
    return
  fi
  confirm "  $question $target?" || return
  if sync_into "$saved" "$SUPPORT/JetBrains/$target" "JetBrains/$target" --exclude plugins.tsv "$@"; then
    info "settings restored"
  else
    warn "Couldn't copy the settings into $SUPPORT/JetBrains/$target"
    return
  fi

  ids="$(cut -f1 "$saved/plugins.tsv" 2>/dev/null | tr '\n' ' ')"
  if [ -n "${ids// /}" ] && [ -x "$launcher" ]; then
    info "plugins: $ids"
    if confirm "  Install these plugins?"; then
      # shellcheck disable=SC2086  # one argument per plugin id
      if "$launcher" installPlugins $ids </dev/null >/dev/null 2>&1; then
        info "plugins installed"
      else
        warn "Some plugins didn't install. Add them in Settings → Plugins."
      fi
    fi
  fi
}

# saved_jetbrains <product>: the newest saved config folder for an IDE, e.g.
# WebStorm -> .../apps/webstorm/WebStorm2026.1 (apps/jetbrains in older
# backups). Fails if there's none.
saved_jetbrains() {
  local dir found=""
  for dir in "$BACKUP_DIR"/apps/jetbrains/"$1"[0-9]* "$BACKUP_DIR"/apps/webstorm/"$1"[0-9]*; do
    [ -d "$dir" ] && found="$dir"
  done
  [ -n "$found" ] && echo "$found"
}

restore_webstorm() {
  [ -d "$BACKUP_DIR/apps/webstorm" ] || return
  local yes=""
  [ "$YES" = true ] && yes=--yes
  # It exits 1 only when Ctrl-D stopped it.
  UNDO="$UNDO" "$(dirname "$HERE")/appsettings/webstorm/restore.sh" "$BACKUP_DIR" ${yes:+"$yes"} || exit 1
}

restore_jetbrains() {
  [ -d "$BACKUP_DIR/apps/jetbrains" ] || return
  local saved name line
  for saved in "$BACKUP_DIR"/apps/jetbrains/*; do
    name="$(basename "$saved")"
    bold "JetBrains: $name"
    line="$(jetbrains_install_for "$name")"
    if [ -z "$line" ]; then
      info "${name%%[0-9]*} isn't installed. Install it, then re-run."
      continue
    fi
    apply_jetbrains "$saved" "$line" "Restore settings, keymaps, code styles and colours into"
  done
  restore_webstorm_twins
}

# IntelliJ IDEA and PyCharm get WebStorm's settings when the backup has none
# of their own, so every JetBrains IDE looks and types the same. WebStorm's
# disabled plugins list is left out: those IDEs bundle different plugins.
restore_webstorm_twins() {
  local webstorm product label line item excludes=""
  webstorm="$(saved_jetbrains WebStorm)" || return
  for item in $WEBSTORM_ONLY; do excludes="$excludes --exclude $item"; done
  while IFS='|' read -r product label; do
    [ -n "$product" ] || continue
    saved_jetbrains "$product" >/dev/null && continue
    line="$(jetbrains_install_for "$product")"
    [ -n "$line" ] || continue
    bold "JetBrains: $label, from $(basename "$webstorm")"
    # shellcheck disable=SC2086  # one --exclude per name
    apply_jetbrains "$webstorm" "$line" "Apply your WebStorm settings, keymaps, code styles and colours to" \
      $excludes
  done <<< "$WEBSTORM_TWINS"
}

restore_editors() {
  local name folder tool bundled saved cli ext have n
  while IFS='|' read -r name folder tool bundled; do
    [ -n "$name" ] || continue
    saved="$BACKUP_DIR/apps/editors/$folder"
    [ -d "$saved" ] || continue
    bold "$name"
    if [ ! -d "$APPS_DIR/${bundled%%.app/*}.app" ]; then
      info "$name isn't installed. Install it, then re-run."
      continue
    fi
    confirm "  Restore settings, key bindings, snippets and extensions?" || continue
    if sync_into "$saved" "$SUPPORT/$folder/User" "$folder" --exclude extensions.txt; then
      info "settings restored"
    else
      warn "Couldn't copy the settings into $SUPPORT/$folder/User"
      continue
    fi

    cli="$(command -v "$tool" 2>/dev/null || true)"
    [ -z "$cli" ] && [ -x "$APPS_DIR/$bundled" ] && cli="$APPS_DIR/$bundled"
    if [ -z "$cli" ]; then
      warn "No $tool command, so extensions weren't installed. The list is in $(saved_path "apps/editors/$folder/extensions.txt")"
      continue
    fi
    have="$("$cli" --list-extensions </dev/null 2>/dev/null | tr '[:upper:]' '[:lower:]')"
    n=0
    while read -r ext; do
      [ -n "$ext" ] || continue
      printf '%s\n' "$have" | grep -qxF "$(printf '%s' "$ext" | tr '[:upper:]' '[:lower:]')" && continue
      if "$cli" --install-extension "$ext" </dev/null >/dev/null 2>&1; then
        n=$((n + 1))
      else
        warn "Couldn't install extension $ext"
      fi
    done < "$saved/extensions.txt"
    info "$n extensions installed"
  done <<< "$EDITORS"
}

restore_browsers() {
  [ -d "$BACKUP_DIR/browsers" ] || return
  bold "Browsers"
  info "Signing in to Chrome, Brave or Edge sync brings back bookmarks, extensions"
  info "and settings by itself. This restores bookmarks for profiles that don't sync."
  local name folder app saved profile dest label
  while IFS='|' read -r name folder app; do
    [ -n "$name" ] || continue
    saved="$BACKUP_DIR/browsers/$name"
    [ -d "$saved" ] || continue
    if [ ! -d "$APPS_DIR/$app" ]; then
      info "$name isn't installed, skipped"
      continue
    fi
    if app_running "$app"; then
      warn "$name is open. Quit it and re-run to restore its bookmarks."
      continue
    fi
    for profile in "$saved"/*/; do
      profile="$(basename "$profile")"
      [ -f "$saved/$profile/Bookmarks" ] || continue
      label="$(grep "^$profile	" "$saved/profiles.tsv" 2>/dev/null | cut -f2)"
      dest="$SUPPORT/$folder/$profile"
      if [ ! -d "$dest" ] && [ "$profile" != Default ]; then
        info "$name / ${label:-$profile}: create this profile in $name first, then re-run"
        continue
      fi
      confirm "  Restore $name bookmarks for ${label:-$profile}?" || continue
      copy_file "$saved/$profile/Bookmarks" "$dest/Bookmarks" "$name/$profile"
      info "$name / ${label:-$profile}: bookmarks restored"
    done
  done <<< "$BROWSERS"

  restore_safari
  info "Extensions and custom search engines for each profile are listed in"
  info "$SAVED_ROOT/appsettings/<browser>/saved/<profile>/extensions.tsv and search-engines.tsv."
}

restore_safari() {
  local saved="$BACKUP_DIR/browsers/Safari"
  [ -d "$saved" ] || return
  if app_running Safari.app; then
    warn "Safari is open. Quit it and re-run to restore its settings."
    return
  fi
  if [ -f "$saved/Bookmarks.plist" ]; then
    confirm "  Restore Safari settings and bookmarks?" || return
  else
    confirm "  Restore Safari settings?" || return
  fi
  [ -f "$saved/com.apple.Safari.plist" ] && import_domain "$saved/com.apple.Safari.plist" com.apple.Safari
  if [ -f "$saved/Bookmarks.plist" ]; then
    if [ -w "$HOME/Library/Safari" ]; then
      copy_file "$saved/Bookmarks.plist" "$HOME/Library/Safari/Bookmarks.plist" Safari
      info "Safari: settings and bookmarks restored"
      return
    fi
    warn "Safari bookmarks need Full Disk Access for this terminal app. They also come back through iCloud."
  fi
  info "Safari: settings restored"
}

restore_apps() {
  local index="$BACKUP_DIR/apps/index.tsv"
  [ -s "$index" ] || return
  bold "App preferences"
  local id app installed="" missing="" running=""
  while IFS='	' read -r id app; do
    if [ ! -d "$APPS_DIR/$app" ]; then
      missing="$missing, ${app%.app}"
    elif app_running "$app"; then
      running="$running, ${app%.app}"
    else
      installed="$installed, ${app%.app}"
    fi
  done < "$index"
  if [ -z "$installed" ]; then
    info "None of the saved apps are installed and closed."
  else
    info "Ready: ${installed#, }"
    if confirm "  Restore preferences for these apps?"; then
      while IFS='	' read -r id app; do
        if [ ! -d "$APPS_DIR/$app" ] || app_running "$app"; then continue; fi
        import_domain "$BACKUP_DIR/apps/plists/$id.plist" "$id"
      done < "$index"
      info "restored"
    fi
  fi
  [ -n "$running" ] && warn "Open, so skipped (quit them and re-run): ${running#, }"
  [ -n "$missing" ] && info "Not installed, skipped: ${missing#, }"
}

checklist() {
  bold "Not restored by this script"
  cat <<EOF
  - Passwords: they come from 1Password and iCloud Keychain.
  - Login items: System Settings → General → Login Items.
  - Wallpaper, Wi-Fi, Touch ID, notifications and privacy permissions.
  - Text replacements sync through iCloud. A copy is in $PRIVATE_DIR/system/text-replacements.tsv.
  - Browser extensions: they come back with browser sync, or install them from the
    lists in $SAVED_ROOT/appsettings/<browser>/saved.
  - Firefox: sign in to Firefox sync. Its prefs.js and a bookmark backup are in $PRIVATE_DIR/browsers/Firefox.
  - Power settings: compare with $SAVED_ROOT/settings/saved/system/info.txt in System Settings → Battery.
EOF
}

# ---------------------------------------------------------------------------

if [ ! -d "$SAVED_ROOT/settings/saved" ] && [ ! -d "$PRIVATE_DIR/system" ] && [ ! -d "$PRIVATE_DIR/apps" ]; then
  warn "No settings in $SAVED_ROOT/settings/saved or $PRIVATE_DIR."
  info "Run settings/capture-settings.sh on the old Mac, commit what it saved, and copy"
  info "the private backup it made there, or pass its path."
  exit 1
fi
if [ "$YES" = false ] && ! { : </dev/tty; } 2>/dev/null; then
  warn "No terminal to ask on. Re-run with --yes to restore everything."
  exit 1
fi

# One folder with both: the repo's settings, then the private backup's.
BACKUP_DIR="$(mktemp -d)"
trap 'rm -rf "$BACKUP_DIR"' EXIT
py gather "$SAVED_ROOT" "$BACKUP_DIR"
[ -d "$PRIVATE_DIR" ] && py copy "$PRIVATE_DIR" "$BACKUP_DIR" --exclude 'undo-*' >/dev/null

echo "Restoring settings from the repo ($SAVED_ROOT)"
if [ -d "$PRIVATE_DIR/system" ] || [ -d "$PRIVATE_DIR/apps" ]; then
  info "and $PRIVATE_DIR"
  [ -f "$PRIVATE_DIR/README.txt" ] && info "$(head -1 "$PRIVATE_DIR/README.txt")"
else
  warn "No private backup in $PRIVATE_DIR, so bookmarks, app preferences and"
  info "anything else personal won't come back. Copy it from the old Mac, or pass its path."
fi
echo
restore_system
echo; restore_dotfiles
echo; restore_iterm
echo; restore_webstorm
echo; restore_jetbrains
echo; restore_editors
echo; restore_browsers
echo; restore_apps
echo
[ -d "$UNDO" ] && info "What was replaced is saved in $UNDO" && echo
checklist
