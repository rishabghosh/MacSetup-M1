#!/usr/bin/env bash
#
# Back up the gitignored .env files of every project clone-projects.sh clones,
# so restore-envs.sh can put them back after a fresh clone.
#
# Usage:
#   ./backup-envs.sh                          writes env-backup.tar.gz in this repo
#   ENV_BACKUP=/Volumes/USB/envs.tar.gz ./backup-envs.sh
#   PROJECTS_DIR=~/code ./backup-envs.sh      read projects from a different folder
#
# The backup holds secrets. It is gitignored and written with 600 permissions;
# copy it somewhere safe yourself and don't share it.
#
# Picked up: .env and .env.* files anywhere in a project (except .env.example
# and files git tracks), skipping node_modules, .git and virtualenvs.
# Safe to re-run: an earlier backup at the same path is replaced.
# Written for the macOS default bash (3.2), so no associative arrays.

set -u

HERE="$(cd "$(dirname "$0")" && pwd)"
PROJECTS_DIR="${PROJECTS_DIR:-$HOME/projects}"
ENV_BACKUP="${ENV_BACKUP:-$HERE/env-backup.tar.gz}"

bold() { printf '\033[1m%s\033[0m\n' "$*"; }
info() { printf '  %s\n' "$*"; }
warn() { printf '\033[33m  ! %s\033[0m\n' "$*"; }

# The project folders listed in clone-projects.sh.
project_folders() {
  sed -n '/^REPOS="/,/^"/p' "$HERE/clone-projects.sh" | sed -n 's/^\([A-Za-z0-9_.-]*\)|.*/\1/p'
}

# Prints the .env files in $1, relative to it.
find_envs() {
  (cd "$1" && find . \
    \( -name node_modules -o -name .git -o -name .venv -o -name venv \) -prune -o \
    -type f \( -name '.env' -o -name '.env.*' \) ! -name '.env.example' -print) \
    | sed 's|^\./||' | sort
}

STAGE="$(mktemp -d)"
trap 'rm -rf "$STAGE"' EXIT

bold "Backing up .env files from $PROJECTS_DIR"
count=0
for folder in $(project_folders); do
  dir="$PROJECTS_DIR/$folder"
  [ -d "$dir" ] || continue
  while IFS= read -r rel; do
    [ -n "$rel" ] || continue
    # Committed files come back with the clone.
    if git -C "$dir" ls-files --error-unmatch -- "$rel" >/dev/null 2>&1; then
      continue
    fi
    mkdir -p "$STAGE/$folder/$(dirname "$rel")"
    cp -p "$dir/$rel" "$STAGE/$folder/$rel"
    info "$folder/$rel"
    count=$((count + 1))
  done <<EOF
$(find_envs "$dir")
EOF
done

if [ "$count" = 0 ]; then
  warn "No .env files found, nothing written."
  exit 0
fi

mkdir -p "$(dirname "$ENV_BACKUP")"
tmp="$ENV_BACKUP.tmp.$$"
(umask 077 && tar -czf "$tmp" -C "$STAGE" .) || { rm -f "$tmp"; warn "Backup failed."; exit 1; }
mv "$tmp" "$ENV_BACKUP"
chmod 600 "$ENV_BACKUP"

echo
bold "Saved $count files to $ENV_BACKUP"
info "It holds secrets: copy it somewhere safe, then run ./restore-envs.sh after cloning."
