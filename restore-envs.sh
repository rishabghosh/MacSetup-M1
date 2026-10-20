#!/usr/bin/env bash
#
# Put back the .env files saved by backup-envs.sh. Run it after
# clone-projects.sh has cloned the projects.
#
# Usage:
#   ./restore-envs.sh                         restore from env-backup.tar.gz in this repo
#   ./restore-envs.sh ~/Desktop/envs.tar.gz   restore from somewhere else
#   ./restore-envs.sh --force                 also replace .env files that already exist
#   PROJECTS_DIR=~/code ./restore-envs.sh     restore into a different folder
#
# Safe to re-run: existing .env files are left alone unless --force is given,
# and projects that aren't cloned are skipped.
# Written for the macOS default bash (3.2), so no associative arrays.

set -u

HERE="$(cd "$(dirname "$0")" && pwd)"
PROJECTS_DIR="${PROJECTS_DIR:-$HOME/projects}"
ENV_BACKUP="${ENV_BACKUP:-$HERE/env-backup.tar.gz}"
FORCE=false
for arg; do
  case "$arg" in
    --force) FORCE=true ;;
    *) ENV_BACKUP="$arg" ;;
  esac
done

bold() { printf '\033[1m%s\033[0m\n' "$*"; }
info() { printf '  %s\n' "$*"; }
warn() { printf '\033[33m  ! %s\033[0m\n' "$*"; }

if [ ! -f "$ENV_BACKUP" ]; then
  warn "No backup at $ENV_BACKUP"
  info "Make one on the old Mac with ./backup-envs.sh, or pass its path."
  exit 1
fi

STAGE="$(mktemp -d)"
trap 'rm -rf "$STAGE"' EXIT
tar -xzf "$ENV_BACKUP" -C "$STAGE" || { warn "Could not read $ENV_BACKUP"; exit 1; }

bold "Restoring .env files into $PROJECTS_DIR"
restored=0 skipped=0
while IFS= read -r rel; do
  [ -n "$rel" ] || continue
  case "$rel" in *..*) warn "$rel: unsafe path, skipped"; continue ;; esac
  folder="${rel%%/*}"
  target="$PROJECTS_DIR/$rel"
  if [ ! -d "$PROJECTS_DIR/$folder" ]; then
    warn "$rel: $folder not cloned, skipped"
    skipped=$((skipped + 1))
    continue
  fi
  if [ -e "$target" ] && [ "$FORCE" = false ]; then
    info "$rel: already exists, skipped"
    skipped=$((skipped + 1))
    continue
  fi
  mkdir -p "$(dirname "$target")"
  cp "$STAGE/$rel" "$target"
  chmod 600 "$target"
  info "$rel: restored"
  restored=$((restored + 1))
done <<EOF
$(cd "$STAGE" && find . -type f | sed 's|^\./||' | sort)
EOF

echo
bold "Done: $restored restored, $skipped skipped."
