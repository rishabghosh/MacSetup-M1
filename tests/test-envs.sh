# Tests for backup-envs.sh and restore-envs.sh.

# A few projects with .env files, as if cloned and set up on the old Mac.
make_env_projects() {
  local p="$HOME/projects"
  mkdir -p "$p/vma" "$p/FabricFuser/backend" "$p/FabricFuser/frontend/node_modules/pkg" \
    "$p/PrivatePdf" "$p/not-in-the-list"
  echo "SUPABASE_SERVICE_ROLE_KEY=secret one" > "$p/vma/.env"
  echo "LOGO_IMAGE_PATH=/x/logo.png" > "$p/FabricFuser/backend/.env"
  echo "API_KEY=gemini" > "$p/FabricFuser/frontend/.env.local"
  echo "API_KEY=" > "$p/FabricFuser/frontend/.env.example"
  echo "IGNORED=1" > "$p/FabricFuser/frontend/node_modules/pkg/.env"
  echo "VITE_X=committed" > "$p/PrivatePdf/.env.development"
  echo "OTHER=1" > "$p/not-in-the-list/.env"
  export GIT_TRACKED="$p/PrivatePdf/.env.development"
}

env_backup_list() {
  tar -tzf "$ENV_BACKUP" | sed 's|^\./||' | grep -v -e '/$' -e '^\.$' -e '^$' | sort
}

test_envs_backup_picks_up_untracked_env_files() {
  export ENV_BACKUP="$TEST_DIR/out/env-backup.tar.gz"
  make_env_projects
  run repos/backup-envs.sh
  expect_status 0
  expect_out "Saved 3 files to $ENV_BACKUP"
  expect_eq "$(env_backup_list | tr '\n' ' ')" \
    "FabricFuser/backend/.env FabricFuser/frontend/.env.local vma/.env " "files in backup"
  expect_eq "$(stat -c %a "$ENV_BACKUP" 2>/dev/null)" 600 "permissions of the backup"
}

test_envs_backup_with_nothing_to_save() {
  export ENV_BACKUP="$TEST_DIR/env-backup.tar.gz"
  mkdir -p "$HOME/projects/vma"
  run repos/backup-envs.sh
  expect_status 0
  expect_out "No .env files found"
  expect_no_path "$ENV_BACKUP"
}

test_envs_restore_after_fresh_clone() {
  local p="$HOME/projects"
  export ENV_BACKUP="$TEST_DIR/env-backup.tar.gz"
  make_env_projects
  run repos/backup-envs.sh
  rm -rf "$p"
  # Fresh clone, except vma which failed.
  mkdir -p "$p/FabricFuser"
  run repos/restore-envs.sh
  expect_status 0
  expect_line "$p/FabricFuser/backend/.env" "LOGO_IMAGE_PATH=/x/logo.png"
  expect_line "$p/FabricFuser/frontend/.env.local" "API_KEY=gemini"
  expect_eq "$(stat -c %a "$p/FabricFuser/frontend/.env.local" 2>/dev/null)" 600 "permissions"
  expect_out "vma/.env: vma not cloned, skipped"
  expect_no_path "$p/vma"
  expect_out "Done: 2 restored, 1 skipped."
}

test_envs_restore_keeps_existing_unless_forced() {
  local p="$HOME/projects"
  export ENV_BACKUP="$TEST_DIR/env-backup.tar.gz"
  make_env_projects
  run repos/backup-envs.sh
  echo "SUPABASE_SERVICE_ROLE_KEY=newer" > "$p/vma/.env"

  run repos/restore-envs.sh
  expect_status 0
  expect_out "vma/.env: already exists, skipped"
  expect_line "$p/vma/.env" "SUPABASE_SERVICE_ROLE_KEY=newer"

  run repos/restore-envs.sh --force
  expect_status 0
  expect_line "$p/vma/.env" "SUPABASE_SERVICE_ROLE_KEY=secret one"
}

test_envs_restore_from_given_path() {
  export ENV_BACKUP="$TEST_DIR/env-backup.tar.gz"
  make_env_projects
  run repos/backup-envs.sh
  mv "$ENV_BACKUP" "$TEST_DIR/moved.tar.gz"
  rm "$HOME/projects/vma/.env"
  run repos/restore-envs.sh "$TEST_DIR/moved.tar.gz"
  expect_status 0
  expect_line "$HOME/projects/vma/.env" "SUPABASE_SERVICE_ROLE_KEY=secret one"
}

test_envs_restore_without_backup() {
  export ENV_BACKUP="$TEST_DIR/missing.tar.gz"
  run repos/restore-envs.sh
  expect_status 1
  expect_out "No backup at $TEST_DIR/missing.tar.gz"
}
