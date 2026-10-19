#!/usr/bin/env bash
#
# Clone all projects into ~/projects and recreate their (gitignored) .env files.
#
# Usage:
#   ./clone-projects.sh              clone repos, then set up .env files
#   ./clone-projects.sh --skip-env   clone repos only
#   PROJECTS_DIR=~/code ./clone-projects.sh   use a different target folder
#
# Safe to re-run: existing folders and existing .env files are never touched.
# Written for the macOS default bash (3.2), so no associative arrays.

set -u

PROJECTS_DIR="${PROJECTS_DIR:-$HOME/projects}"
SKIP_ENV=false
[ "${1:-}" = "--skip-env" ] && SKIP_ENV=true

# folder|clone url[|ssh key]
# The optional ssh key is for repos reached through a different GitHub account.
REPOS="
MACSETUP-M1|git@github.com:rishabghosh/MACSETUP-M1.git
Blender-Utilis|git@github.com:rishabghosh/Blender-Utils.git
FabricFuser|git@github.com:rishabghosh/Fabric-Fuser.git
PrivatePdf|git@github.com:rishabghosh/PrivatePdf.git
ScreenGridOverlay|git@github.com:rishabghosh/ScreenGridOverlay-ChromeExtension.git
canva-bulk-template|git@github.com:rishabghosh/Canva-Generator-Utils.git
delete-x-posts|git@github.com:rishabghosh/delete-x-posts.git
excel_image_mapper|git@github.com:rishabghosh/excel-image-mapper.git
holehe|https://github.com/megadose/holehe.git
image_product_mapper|git@github.com:rishabghosh/Image-Look-A-Like.git
job-finder|git@github.com:rishabghosh/job-finder.git
learning|git@github.com:rishabghosh/learning-n-experiments.git
placeit_bulk_mockup_extension|git@github.com:rishabghosh/PlaceIt-Automation-Utils.git
regroup-images|git@github.com:rishabghosh/File-Regroup-Utils.git
rename_drive_images|git@github.com:rishabghosh/rename-drive-images.git
rishab-cv|git@github.com:rishabghosh/CV.git
tee_jutsu_v1|git@github.com:arnabghs/tee_jutsu_v1.git
teejutsu-admin-console|git@github.com:rishabghosh/TeeJutsu-Admin-Console.git
vma|git@github.com:voices-minds-action/vision-platform.git|$HOME/.ssh/id_ed25519_voices_mind_saction
"

bold() { printf '\033[1m%s\033[0m\n' "$*"; }
info() { printf '  %s\n' "$*"; }
warn() { printf '\033[33m  ! %s\033[0m\n' "$*"; }

confirm() {
  local reply
  read -r -p "$1 [y/N] " reply </dev/tty
  case "$reply" in [yY]*) return 0 ;; *) return 1 ;; esac
}

# ---------------------------------------------------------------------------
# 1. Prerequisites
# ---------------------------------------------------------------------------

ensure_git() {
  if ! xcode-select -p >/dev/null 2>&1; then
    bold "Xcode Command Line Tools (git) are not installed."
    info "A macOS installer window will open. Re-run this script once it finishes."
    xcode-select --install
    exit 1
  fi
}

# Optional $1: a specific key to test instead of the default one.
github_ssh_ok() {
  local opts=""
  [ -n "${1:-}" ] && opts="-i $1 -o IdentitiesOnly=yes"
  # shellcheck disable=SC2086
  ssh -T $opts -o BatchMode=yes -o StrictHostKeyChecking=accept-new git@github.com </dev/null 2>&1 \
    | grep -q "successfully authenticated"
}

# Make sure a dedicated key exists and is added to its GitHub account.
ensure_extra_key() {
  local key="$1" folder="$2" reply
  github_ssh_ok "$key" && return 0

  warn "$folder needs its own SSH key: $key"
  if [ ! -f "$key" ]; then
    confirm "  Create $key now? (No = copy it over from the old Mac yourself)" || return 1
    local email
    read -r -p "  Email of the GitHub account that has access to $folder: " email </dev/tty
    ssh-keygen -t ed25519 -C "$email" -f "$key" </dev/tty || return 1
  fi
  ssh-add --apple-use-keychain "$key" </dev/tty 2>/dev/null
  pbcopy < "$key.pub"
  info "Public key copied. Sign in to the GitHub account that has access to $folder,"
  info "then add it at https://github.com/settings/ssh/new"
  open "https://github.com/settings/ssh/new"
  while ! github_ssh_ok "$key"; do
    read -r -p "  Press Enter once it's added (type 's' to skip $folder): " reply </dev/tty
    [ "$reply" = "s" ] && return 1
  done
}

ensure_github_ssh() {
  bold "Checking GitHub SSH access..."
  if github_ssh_ok; then
    info "OK"
    return
  fi

  warn "This Mac can't reach GitHub over SSH yet."
  local key="$HOME/.ssh/id_ed25519"
  if [ ! -f "$key" ]; then
    local email
    read -r -p "  Email for the new SSH key (your GitHub email): " email
    info "ssh-keygen will now ask for a passphrase (recommended)."
    mkdir -p "$HOME/.ssh" && chmod 700 "$HOME/.ssh"
    ssh-keygen -t ed25519 -C "$email" -f "$key" || exit 1
  fi

  # Remember the passphrase in the macOS keychain.
  if ! grep -q "UseKeychain" "$HOME/.ssh/config" 2>/dev/null; then
    printf 'Host github.com\n  AddKeysToAgent yes\n  UseKeychain yes\n  IdentityFile %s\n\n' "$key" >> "$HOME/.ssh/config"
  fi
  eval "$(ssh-agent -s)" >/dev/null
  ssh-add --apple-use-keychain "$key"

  pbcopy < "$key.pub"
  info "Your public key is copied to the clipboard."
  info "Add it at https://github.com/settings/ssh/new (opening now)."
  open "https://github.com/settings/ssh/new"

  while ! github_ssh_ok; do
    read -r -p "  Press Enter once the key is added on GitHub (Ctrl-C to quit)... " _
  done
  info "GitHub SSH access works."
}

# ---------------------------------------------------------------------------
# 2. Clone
# ---------------------------------------------------------------------------

clone_all() {
  mkdir -p "$PROJECTS_DIR"
  bold "Cloning into $PROJECTS_DIR"

  local failed="" line folder url key
  for line in $REPOS; do
    folder="${line%%|*}"
    url="${line#*|}"
    key=""
    case "$url" in *"|"*) key="${url#*|}"; url="${url%%|*}" ;; esac

    if [ -d "$PROJECTS_DIR/$folder" ]; then
      info "$folder: already exists, skipped"
      continue
    fi

    set --
    if [ -n "$key" ]; then
      if ! ensure_extra_key "$key" "$folder"; then
        warn "$folder: skipped (no working SSH key)"
        failed="$failed $folder"
        continue
      fi
      # Stored in the clone's config, so later pulls/pushes use the same key.
      set -- -c "core.sshCommand=ssh -i $key -o IdentitiesOnly=yes"
    fi

    if git clone --quiet "$@" "$url" "$PROJECTS_DIR/$folder" </dev/null; then
      info "$folder: cloned"
    else
      warn "$folder: clone failed ($url)"
      failed="$failed $folder"
    fi
  done

  if [ -n "$failed" ]; then
    warn "Failed:$failed"
    warn "tee_jutsu_v1 and vma live in other people's GitHub accounts; ask for access if those failed."
  fi
}

# ---------------------------------------------------------------------------
# 3. .env files
# ---------------------------------------------------------------------------
#
# Each spec line is  NAME|kind|value
#   fixed   write <value> as-is, no prompt (non-secret config)
#   ask     visible prompt, <value> is a cache id
#   secret  hidden prompt, <value> is a cache id
#
# Answers are cached by id, so a value shared by several files (for example the
# TeeJutsu Shipmojo keys) is only typed once per run.

# Sets PROMPTED to the answer. Not used via $(...) because the cache must
# survive between calls, which a subshell would throw away.
prompt_value() {
  local name="$1" kind="$2" id="$3"
  if eval "[ -n \"\${ANS_$id+x}\" ]"; then
    eval "PROMPTED=\$ANS_$id"
    return
  fi
  if [ "$kind" = "secret" ]; then
    read -r -s -p "    $name (hidden, Enter to leave blank): " PROMPTED </dev/tty
    printf '\n' >/dev/tty
  else
    read -r -p "    $name (Enter to leave blank): " PROMPTED </dev/tty
  fi
  eval "ANS_$id=\$PROMPTED"
}

# Quote a value if dotenv would otherwise misread it.
format_value() {
  case "$1" in
    *[[:space:]#\"\']*) printf '"%s"' "$(printf '%s' "$1" | sed 's/\\/\\\\/g; s/"/\\"/g')" ;;
    *) printf '%s' "$1" ;;
  esac
}

write_env() {
  local project="$1" file="$2" spec="$3"
  local dir="$PROJECTS_DIR/$project"
  local target="$dir/$file"

  [ -d "$dir" ] || { warn "$project not cloned, skipping $file"; return; }
  if [ -f "$target" ]; then
    info "$project/$file: already exists, skipped"
    return
  fi

  bold "$project/$file"
  mkdir -p "$(dirname "$target")"
  local tmp line name kind arg value
  tmp="$(mktemp)"
  while IFS= read -r line; do
    [ -z "$line" ] && continue
    name="${line%%|*}"; line="${line#*|}"
    kind="${line%%|*}"; arg="${line#*|}"
    arg="${arg//\$HOME/$HOME}"
    case "$kind" in
      fixed) value="$arg" ;;
      *)     prompt_value "$name" "$kind" "$arg"; value="$PROMPTED" ;;
    esac
    printf '%s=%s\n' "$name" "$(format_value "$value")" >> "$tmp"
  done <<EOF
$spec
EOF
  mv "$tmp" "$target"
  chmod 600 "$target"
  info "written"
}

setup_envs() {
  bold "Setting up .env files (see README.md for where each secret comes from)"

  write_env FabricFuser backend/.env "
LOGO_IMAGE_PATH|fixed|\$HOME/Downloads/logo.png
MAIN_IMAGES_DIR|fixed|\$HOME/Downloads
OUTPUT_DIR|fixed|\$HOME/Downloads
CONFIG_JSON_PATH|fixed|./config.json"

  write_env FabricFuser frontend/.env.local "
API_KEY|secret|gemini_api_key"

  write_env image_product_mapper .env "
REFERENCE_DIR|fixed|input/swag
QUERY_DIR|fixed|output/extracted_images
OUTPUT_PATH|fixed|output/output_mapping.xlsx
EXCEL_FILE|fixed|input/swag.xlsx
OUTPUT_FOLDER|fixed|output/extracted_images
OUTPUT_JSON|fixed|output/output_mapping.json"

  write_env placeit_bulk_mockup_extension .env "
VITE_MAPPING_FILE_PATH|fixed|src/mapping_sample.json
VITE_OPEN_INTERVAL_MS|fixed|15000
VITE_WAIT_BEFORE_CLICK_MS|fixed|5000
VITE_RETRY_ATTEMPTS|fixed|2
VITE_TIMEOUT_MS|fixed|30000
VITE_POST_CLICK_WAIT_MS|fixed|1000
VITE_SKIP_IF_NO_BUTTON|fixed|false
VITE_TAB_CHECK_INTERVAL_MS|fixed|500
VITE_BUTTON_WAIT_TIMEOUT_MS|fixed|5000
VITE_MODAL_WAIT_MS|fixed|3000
IMAGES_DIR|fixed|\$HOME/Downloads
MAPPING_FILE|fixed|./src/mapping_sample.json"

  write_env regroup-images .env "
CROP_WIDTH_RATIO|fixed|0.4
CROP_HEIGHT_RATIO|fixed|0.1
IMAGES_PATH|fixed|\$HOME/Downloads/boys"

  write_env rename_drive_images .env "
API_KEY|secret|google_drive_api_key
EXCEL_PATH|fixed|./data/tshirt_list.xlsx
DRIVE_API_BASE|fixed|https://www.googleapis.com/drive/v3/files"

  write_env tee_jutsu_v1 .env.dev "
PUBLIC_SUPABASE_URL|ask|tj_dev_supabase_url
PUBLIC_SUPABASE_PUBLISHABLE_KEY|secret|tj_dev_publishable_key
SUPABASE_SERVER_URL|ask|tj_dev_supabase_url
SUPABASE_PROJECT_ID|ask|tj_supabase_project_id
SUPABASE_DB_PASSWORD|secret|tj_supabase_db_password
SUPABASE_ACCESS_TOKEN|secret|tj_supabase_access_token
SUPABASE_SERVICE_ROLE_KEY|secret|tj_supabase_service_role_key
SHIPMOJO_PUBLIC_KEY|secret|tj_shipmojo_public_key
SHIPMOJO_PRIVATE_KEY|secret|tj_shipmojo_private_key
SHIPMOJO_PICKUP_PINCODE|ask|tj_shipmojo_pincode
SHIPMOJO_WAREHOUSE_ID|ask|tj_shipmojo_warehouse_id
SHIPPING_PROCESSING_BUFFER_DAYS|fixed|5
RAZORPAY_KEY_ID|ask|tj_razorpay_key_id
PUBLIC_RAZORPAY_KEY_ID|ask|tj_razorpay_key_id
RAZORPAY_KEY_SECRET|secret|tj_razorpay_key_secret
RAZORPAY_WEBHOOK_SECRET|secret|tj_razorpay_webhook_secret"

  write_env tee_jutsu_v1 .env.local "
PUBLIC_SUPABASE_URL|ask|tj_local_supabase_url
PUBLIC_SUPABASE_PUBLISHABLE_KEY|secret|tj_local_publishable_key
SUPABASE_SERVER_URL|ask|tj_local_supabase_url
PLAYWRIGHT_BASE_URL|fixed|http://localhost:4321
TEST_USER_EMAIL|ask|tj_test_user_email
TEST_USER_PASSWORD|secret|tj_test_user_password
TEST_USER_FIRST_NAME|ask|tj_test_user_first_name
TEST_USER_LAST_NAME|ask|tj_test_user_last_name
TEST_REFRESH_TOKEN|secret|tj_test_refresh_token
SHIPMOJO_PUBLIC_KEY|secret|tj_shipmojo_public_key
SHIPMOJO_PRIVATE_KEY|secret|tj_shipmojo_private_key
SHIPMOJO_PICKUP_PINCODE|ask|tj_shipmojo_pincode
SHIPMOJO_WAREHOUSE_ID|ask|tj_shipmojo_warehouse_id
SHIPPING_PROCESSING_BUFFER_DAYS|fixed|5"

  write_env teejutsu-admin-console .env.local "
NEXT_PUBLIC_SUPABASE_URL|ask|tjadmin_supabase_url
NEXT_PUBLIC_SUPABASE_ANON_KEY|secret|tjadmin_supabase_anon_key
SUPABASE_SERVICE_ROLE_KEY|secret|tj_supabase_service_role_key
SUPABASE_PROJECT_ID|ask|tj_supabase_project_id
SUPABASE_DB_PASSWORD|secret|tj_supabase_db_password
SUPABASE_ACCESS_TOKEN|secret|tj_supabase_access_token
ADMIN_EMAILS|ask|tjadmin_admin_emails
SHIPMOJO_PUBLIC_KEY|secret|tj_shipmojo_public_key
SHIPMOJO_PRIVATE_KEY|secret|tj_shipmojo_private_key
SHIPMOJO_API_BASE_URL|fixed|https://shipping-api.com/app/api/v1
SHIPMOJO_PICKUP_PINCODE|ask|tj_shipmojo_pincode
SHIPMOJO_WAREHOUSE_ID|ask|tj_shipmojo_warehouse_id
SHIPMOJO_DEFAULT_COURIER|ask|tjadmin_default_courier
GOOGLE_CLIENT_ID|ask|tjadmin_google_client_id
GOOGLE_CLIENT_SECRET|secret|tjadmin_google_client_secret
GOOGLE_REFRESH_TOKEN|secret|tjadmin_google_refresh_token
GOOGLE_DRIVE_FOLDER_ID|ask|tjadmin_drive_folder_id
CRON_SECRET|secret|tjadmin_cron_secret"

  write_env vma .env "
PUBLIC_SUPABASE_URL|ask|vma_supabase_url
PUBLIC_SUPABASE_ANON_KEY|secret|vma_supabase_anon_key
SUPABASE_SERVICE_ROLE_KEY|secret|vma_supabase_service_role_key"
}

# ---------------------------------------------------------------------------

ensure_git
ensure_github_ssh
clone_all

if [ "$SKIP_ENV" = false ]; then
  echo
  if confirm "Create the projects' .env files now (asks for secrets)?"; then
    setup_envs
  else
    info "Skipped. Run '$0' again later to create them; existing clones are skipped."
  fi
fi

echo
bold "Done."
