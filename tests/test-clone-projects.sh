# Tests for clone-projects.sh.

repo_folders() {
  sed -n '/^REPOS="/,/^"/p' clone-projects.sh | sed -n 's/^\([A-Za-z0-9_.-]*\)|.*/\1/p'
}

VMA_KEY_SUFFIX=".ssh/id_ed25519_voices_mind_saction"

test_clone_clones_everything() {
  local folder
  run ./clone-projects.sh --skip-env
  expect_status 0
  expect_no_out "Failed:"
  for folder in $(repo_folders); do
    expect_dir "$HOME/projects/$folder"
    expect_out "$folder: cloned"
  done
  expect_eq "$(repo_folders | wc -l | tr -d ' ')" 19 "repo count"
  expect_log "git clone --quiet https://github.com/megadose/holehe.git $HOME/projects/holehe"
  # vma goes through its own key, kept in the clone's config.
  expect_log "git clone --quiet -c core.sshCommand=ssh -i $HOME/$VMA_KEY_SUFFIX -o IdentitiesOnly=yes git@github.com:voices-minds-action/vision-platform.git $HOME/projects/vma"
}

test_clone_custom_projects_dir() {
  export PROJECTS_DIR="$HOME/code"
  run ./clone-projects.sh --skip-env
  expect_status 0
  expect_dir "$HOME/code/rishab-cv"
  expect_no_path "$HOME/projects"
}

test_clone_rerun_skips_existing() {
  run ./clone-projects.sh --skip-env
  : > "$STUB_LOG"
  run ./clone-projects.sh --skip-env
  expect_status 0
  expect_no_log_match "git clone"
  expect_out "rishab-cv: already exists, skipped"
}

test_clone_needs_xcode_tools() {
  export XCODE_MISSING=1
  run ./clone-projects.sh --skip-env
  expect_status 1
  expect_log "xcode-select --install"
  expect_no_log_match "git clone"
}

test_clone_failure_is_reported() {
  export GIT_FAIL="git@github.com:arnabghs/tee_jutsu_v1.git"
  run ./clone-projects.sh --skip-env
  expect_status 0
  expect_out "tee_jutsu_v1: clone failed"
  expect_out "Failed: tee_jutsu_v1"
  expect_dir "$HOME/projects/rishab-cv"
  expect_no_path "$HOME/projects/tee_jutsu_v1"
}

test_clone_creates_ssh_key_when_github_refuses() {
  # 1st check fails, then the "press Enter" loop fails once before working.
  export SSH_FAIL_TIMES=2
  run_tty "me@example.com
" ./clone-projects.sh --skip-env
  expect_status 0
  expect_log "ssh-keygen -t ed25519 -C me@example.com -f $HOME/.ssh/id_ed25519"
  expect_file "$HOME/.ssh/id_ed25519"
  expect_line "$HOME/.ssh/config" "  UseKeychain yes"
  expect_line "$HOME/.ssh/config" "  IdentityFile $HOME/.ssh/id_ed25519"
  expect_eq "$(cat "$STUB_STATE/clipboard" 2>/dev/null)" "ssh-ed25519 AAAAstub stub" "clipboard"
  expect_log "open https://github.com/settings/ssh/new"
  expect_out "GitHub SSH access works."
  expect_dir "$HOME/projects/rishab-cv"
}

test_clone_extra_key_can_be_skipped() {
  export SSH_FAIL_KEY="$HOME/$VMA_KEY_SUFFIX"
  run_tty "n" ./clone-projects.sh --skip-env
  expect_status 0
  expect_out "vma: skipped (no working SSH key)"
  expect_out "Failed: vma"
  expect_no_path "$HOME/projects/vma"
  expect_no_log_match "ssh-keygen"
}

# Answers for the .env prompts: "y" to start, then one per distinct prompt.
# The first (Gemini key) has characters that need quoting; the rest are
# ans02, ans03, ...
env_answers() {
  local i=2
  printf 'y\nsp ace #"q"\n'
  while [ $i -le 40 ]; do printf 'ans%02d\n' $i; i=$((i + 1)); done
}

test_clone_writes_env_files() {
  local p="$HOME/projects" f
  run_tty "$(env_answers)" ./clone-projects.sh
  expect_status 0

  for f in FabricFuser/backend/.env FabricFuser/frontend/.env.local image_product_mapper/.env \
    placeit_bulk_mockup_extension/.env regroup-images/.env rename_drive_images/.env \
    tee_jutsu_v1/.env.dev tee_jutsu_v1/.env.local teejutsu-admin-console/.env.local vma/.env; do
    expect_file "$p/$f"
    expect_eq "$(stat -c %a "$p/$f" 2>/dev/null)" 600 "permissions of $f"
  done

  # Fixed values, with $HOME filled in.
  expect_line "$p/FabricFuser/backend/.env" "LOGO_IMAGE_PATH=$HOME/Downloads/logo.png"
  expect_line "$p/regroup-images/.env" "IMAGES_PATH=$HOME/Downloads/boys"
  # Quoted when dotenv would misread it.
  expect_line "$p/FabricFuser/frontend/.env.local" 'API_KEY="sp ace #\"q\""'
  # Answers land in the right place, and shared ones are asked only once.
  expect_line "$p/rename_drive_images/.env" "API_KEY=ans02"
  expect_line "$p/tee_jutsu_v1/.env.dev" "PUBLIC_SUPABASE_URL=ans03"
  expect_line "$p/tee_jutsu_v1/.env.dev" "SUPABASE_SERVER_URL=ans03"
  expect_line "$p/tee_jutsu_v1/.env.dev" "SUPABASE_PROJECT_ID=ans05"
  expect_line "$p/tee_jutsu_v1/.env.dev" "PUBLIC_RAZORPAY_KEY_ID=ans13"
  expect_line "$p/tee_jutsu_v1/.env.local" "SHIPMOJO_PUBLIC_KEY=ans09"
  expect_line "$p/teejutsu-admin-console/.env.local" "SUPABASE_PROJECT_ID=ans05"
  expect_line "$p/teejutsu-admin-console/.env.local" "SUPABASE_SERVICE_ROLE_KEY=ans08"
  expect_line "$p/vma/.env" "SUPABASE_SERVICE_ROLE_KEY=ans34"
  expect_eq "$(wc -l < "$p/vma/.env" | tr -d ' ')" 3 "lines in vma/.env"

  # Secret prompts don't echo, visible ones do.
  expect_no_out "ans02"
  expect_out "ans03"
}

test_clone_rerun_keeps_env_files() {
  local before
  run_tty "$(env_answers)" ./clone-projects.sh
  before="$(cat "$HOME/projects/vma/.env")"
  run_tty "y" ./clone-projects.sh
  expect_status 0
  expect_out "vma/.env: already exists, skipped"
  expect_no_out "(hidden, Enter to leave blank)"
  expect_eq "$(cat "$HOME/projects/vma/.env")" "$before" "vma/.env after re-run"
}

test_clone_env_can_be_declined() {
  run_tty "n" ./clone-projects.sh
  expect_status 0
  expect_out "Skipped."
  expect_no_path "$HOME/projects/vma/.env"
}
