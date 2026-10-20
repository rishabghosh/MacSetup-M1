#!/usr/bin/env bash
#
# Capture all of WebStorm's settings so restore.sh can put them back on a new
# Mac: everything in its config folder (options, keymaps, code styles, colour
# schemes, live templates, file templates, scratches, per-project workspaces
# and tasks, database drivers, Node.js typings, AI agent history), the list of
# installed plugins, its macOS preferences and the AI agents it has set up.
#
# settings/capture-settings.sh runs this too, so you only need it on its own
# to refresh the WebStorm part of an existing backup.
#
# Usage:
#   ./appsettings/webstorm/capture.sh                 writes ~/MacSettingsBackup/apps/webstorm
#   ./appsettings/webstorm/capture.sh --with-plugins  also copy the plugin files (can be >1 GB)
#   BACKUP_DIR=/Volumes/USB/settings ./appsettings/webstorm/capture.sh
#
# Left out: caches, logs, usage statistics, the settings-sync repo, login
# tokens, and licence keys (sign in to your JetBrains account to activate).
#
# Safe to re-run: an earlier WebStorm backup in the same folder is replaced.
# Written for the macOS default bash (3.2).

set -u

HERE="$(cd "$(dirname "$0")" && pwd)"
REPO_DIR="$(cd "$HERE/../.." && pwd)"
BACKUP_DIR="${BACKUP_DIR:-$HOME/MacSettingsBackup}"
JETBRAINS="$HOME/Library/Application Support/JetBrains"
MARKER=".mac-settings-backup"
DEST="$BACKUP_DIR/apps/webstorm"
WITH_PLUGINS=false

# Not settings: caches and state WebStorm rebuilds, plus secrets.
SKIP=".lock plugins event-log-metadata app-internal-state.db updatedBrokenPlugins.db settingsSync user.web.token"
SECRETS="*oauth* *token* *Token* *password* *Password* security.xml"
LICENCES="*.key *.license"

bold() { printf '\033[1m%s\033[0m\n' "$*"; }
info() { printf '  %s\n' "$*"; }
warn() { printf '\033[33m  ! %s\033[0m\n' "$*"; }

py() { python3 -I "$REPO_DIR/settings/settings.py" "$@"; }

for arg in "$@"; do
  case "$arg" in
    --with-plugins) WITH_PLUGINS=true ;;
    --help | -h) sed -n '3,21p' "$0" | sed 's/^# \{0,1\}//'; exit 0 ;;
    *) echo "Unknown option: $arg" >&2; exit 1 ;;
  esac
done

# The newest WebStorm config folder, e.g. WebStorm2026.1.
config_dir() {
  local dir
  for dir in "$JETBRAINS"/WebStorm*; do
    [ -d "$dir/options" ] && basename "$dir"
  done | sort | tail -1
}

prepare_dest() {
  case "$BACKUP_DIR" in
    "$REPO_DIR" | "$REPO_DIR"/*)
      warn "$BACKUP_DIR is inside this repo, which is public. Pick a folder outside it."
      exit 1 ;;
  esac
  if [ -e "$BACKUP_DIR" ] && [ ! -f "$BACKUP_DIR/$MARKER" ]; then
    warn "$BACKUP_DIR already exists and isn't a settings backup. Move it or set BACKUP_DIR."
    exit 1
  fi
  mkdir -p "$BACKUP_DIR" || exit 1
  touch "$BACKUP_DIR/$MARKER"
  rm -rf "$DEST"
}

# ---------------------------------------------------------------------------

bold "WebStorm..."
name="$(config_dir)"
if [ -z "$name" ]; then
  info "no WebStorm settings found"
  exit 0
fi
prepare_dest

src="$JETBRAINS/$name"
excludes=""
for item in $SKIP; do excludes="$excludes --exclude $item"; done
# shellcheck disable=SC2086  # one --exclude per name
n="$(py copy "$src" "$DEST/$name" $excludes)"
for pattern in $SECRETS; do
  find "$DEST/$name/options" -name "$pattern" -exec rm -f {} + 2>/dev/null
done
for pattern in $LICENCES; do
  find "$DEST/$name" -maxdepth 1 -name "$pattern" -exec rm -f {} + 2>/dev/null
done
info "$name: $n files (settings, keymaps, code styles, colours, templates, scratches, workspaces)"

py jetbrains-plugins "$src/plugins" > "$DEST/$name/plugins.tsv"
info "$(wc -l < "$DEST/$name/plugins.tsv" | tr -d ' ') plugins listed"
if [ "$WITH_PLUGINS" = true ] && [ -d "$src/plugins" ]; then
  py copy "$src/plugins" "$DEST/plugins" >/dev/null
  info "plugin files copied ($(du -sh "$DEST/plugins" | cut -f1))"
fi

if defaults read com.jetbrains.WebStorm >/dev/null 2>&1; then
  defaults export com.jetbrains.WebStorm "$DEST/com.jetbrains.WebStorm.plist" 2>/dev/null
  info "macOS preferences"
fi
if [ -f "$JETBRAINS/acp-agents/installed.json" ]; then
  mkdir -p "$DEST/acp-agents"
  cp "$JETBRAINS/acp-agents/installed.json" "$DEST/acp-agents/"
  info "AI agents (acp-agents)"
fi
