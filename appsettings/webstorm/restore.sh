#!/usr/bin/env bash
#
# Put back the WebStorm settings capture.sh saved on the old Mac, into the
# WebStorm installed here (its config folder may be a newer version), then
# reinstall its plugins. Install WebStorm first (appsetup/install-coding.sh)
# and keep it closed while this runs.
#
# settings/restore-settings.sh runs this too.
#
# Usage:
#   ./appsettings/webstorm/restore.sh [backup folder]   default ~/MacSettingsBackup
#   ./appsettings/webstorm/restore.sh --yes             restore without asking
#
# Anything that gets replaced is saved first to <backup folder>/undo-<time>.
# Written for the macOS default bash (3.2).

set -u

HERE="$(cd "$(dirname "$0")" && pwd)"
REPO_DIR="$(cd "$HERE/../.." && pwd)"
BACKUP_DIR="$HOME/MacSettingsBackup"
APPS_DIR="${APPS_DIR:-/Applications}"
JETBRAINS="$HOME/Library/Application Support/JetBrains"
YES=false
for arg in "$@"; do
  case "$arg" in
    --yes | -y) YES=true ;;
    --help | -h) sed -n '3,15p' "$0" | sed 's/^# \{0,1\}//'; exit 0 ;;
    -*) echo "Unknown option: $arg" >&2; exit 1 ;;
    *) BACKUP_DIR="$arg" ;;
  esac
done
SAVED="$BACKUP_DIR/apps/webstorm"
# restore-settings.sh passes its own, so everything lands in one undo folder.
UNDO="${UNDO:-$BACKUP_DIR/undo-$(date +%Y%m%d-%H%M%S)}"

bold() { printf '\033[1m%s\033[0m\n' "$*"; }
info() { printf '  %s\n' "$*"; }
warn() { printf '\033[33m  ! %s\033[0m\n' "$*"; }

py() { python3 -I "$REPO_DIR/settings/settings.py" "$@"; }

# Ctrl-D stops the script.
confirm() {
  local reply
  [ "$YES" = true ] && return 0
  read -r -p "$1 [y/N] " reply </dev/tty || { echo; exit 1; }
  case "$reply" in [yY]*) return 0 ;; *) return 1 ;; esac
}

# The installed WebStorm: prints "<its config folder> <launcher>".
installed_webstorm() {
  local app line
  for app in "$APPS_DIR"/*.app; do
    line="$(py jetbrains-app "$app")"
    case "$line" in WebStorm[0-9]*) echo "$line"; return ;; esac
  done
}

# ---------------------------------------------------------------------------

saved_config=""
for dir in "$SAVED"/WebStorm*; do
  [ -d "$dir" ] && saved_config="$dir"
done
if [ -z "$saved_config" ]; then
  warn "No WebStorm settings in $SAVED."
  info "Run appsettings/webstorm/capture.sh on the old Mac and copy the backup here."
  exit 1
fi

bold "WebStorm: $(basename "$saved_config")"
line="$(installed_webstorm)"
if [ -z "$line" ]; then
  info "WebStorm isn't installed. Install it (appsetup/install-coding.sh), then re-run."
  exit 0
fi
target="$(printf '%s\n' "$line" | cut -f1)"
launcher="$(printf '%s\n' "$line" | cut -f2)"
app="${launcher%%.app/*}.app"
if pgrep -f "/$(basename "$app")/Contents/MacOS/" >/dev/null 2>&1; then
  warn "WebStorm is open. Quit it and re-run to restore its settings."
  exit 0
fi
if [ "$YES" = false ] && ! { : </dev/tty; } 2>/dev/null; then
  warn "No terminal to ask on. Re-run with --yes."
  exit 1
fi

confirm "  Restore all settings, keymaps, templates, scratches and workspaces into $target?" || exit 0
if py copy "$saved_config" "$JETBRAINS/$target" --undo "$UNDO/JetBrains/$target" --exclude plugins.tsv >/dev/null; then
  info "settings restored"
else
  warn "Couldn't copy the settings into $JETBRAINS/$target"
  exit 0
fi
if [ -f "$SAVED/com.jetbrains.WebStorm.plist" ]; then
  mkdir -p "$UNDO/defaults"
  defaults export com.jetbrains.WebStorm "$UNDO/defaults/com.jetbrains.WebStorm.plist" 2>/dev/null
  defaults import com.jetbrains.WebStorm "$SAVED/com.jetbrains.WebStorm.plist"
  info "macOS preferences restored"
fi
if [ -d "$SAVED/acp-agents" ]; then
  py copy "$SAVED/acp-agents" "$JETBRAINS/acp-agents" --undo "$UNDO/JetBrains/acp-agents" >/dev/null
  info "AI agents restored"
fi

if [ -d "$SAVED/plugins" ]; then
  if confirm "  Copy the saved plugins into $target?"; then
    py copy "$SAVED/plugins" "$JETBRAINS/$target/plugins" --keep-existing >/dev/null
    info "plugins copied"
  fi
  exit 0
fi
ids="$(cut -f1 "$saved_config/plugins.tsv" 2>/dev/null | tr '\n' ' ')"
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
