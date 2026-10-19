#!/usr/bin/env bash
#
# Set up Claude Desktop and Claude Code: apps, settings, plugins, MCP servers,
# skills and commands. Prints a checklist for what can't be scripted (sign-in,
# claude.ai connectors, desktop extensions, Claude in Chrome).
#
# Usage:
#   ./setup-claude.sh                  set up both
#   ./setup-claude.sh --skip-desktop   Claude Code only
#   ./setup-claude.sh --skip-code      Claude Desktop only
#   PROJECTS_DIR=~/code ./setup-claude.sh   projects live somewhere other than ~/projects
#
# Safe to re-run: anything already installed or configured is left alone.
# Written for the macOS default bash (3.2), so no associative arrays.

set -u

REPO_DIR="$(cd "$(dirname "$0")" && pwd)"
PROJECTS_DIR="${PROJECTS_DIR:-$HOME/projects}"
SKIP_DESKTOP=false
SKIP_CODE=false
for arg in "$@"; do
  case "$arg" in
    --skip-desktop) SKIP_DESKTOP=true ;;
    --skip-code) SKIP_CODE=true ;;
    *) echo "Unknown option: $arg" >&2; exit 1 ;;
  esac
done

# Plugin marketplaces (GitHub repos) and plugins (name@marketplace).
MARKETPLACES="
anthropics/skills
alirezarezvani/claude-skills
"
PLUGINS="
document-skills@anthropic-agent-skills
example-skills@anthropic-agent-skills
"

# Public skills installed with `npx skills`: repo|skill name
PUBLIC_SKILLS="
vercel-labs/skills|find-skills
remotion-dev/skills|remotion-best-practices
"

# MCP servers available in every project: name|json
USER_MCPS="
fli-flights|{\"type\":\"stdio\",\"command\":\"$HOME/.local/bin/fli-mcp\",\"args\":[],\"env\":{\"FLI_MCP_DEFAULT_CURRENCY\":\"INR\",\"FLI_MCP_DEFAULT_SORT_BY\":\"CHEAPEST\"}}
kiwi-flights|{\"type\":\"http\",\"url\":\"https://mcp.kiwi.com\"}
supabase|{\"type\":\"http\",\"url\":\"https://mcp.supabase.com/mcp?project_ref=mwmaxzznfwwmnmjlgybo&read_only=true\"}
"

# MCP servers for one project only: project folder|name|json
PROJECT_MCPS="
tee_jutsu_v1|atlassian|{\"type\":\"sse\",\"url\":\"https://mcp.atlassian.com/v1/mcp\"}
teejutsu-admin-console|vercel|{\"type\":\"http\",\"url\":\"https://mcp.vercel.com\"}
"

# Settings merged into ~/.claude/settings.json. Keys you already have win.
SETTINGS='{
  "model": "opus[1m]",
  "skipDangerousModePermissionPrompt": true,
  "skipAutoPermissionPrompt": true,
  "skipWorkflowUsageWarning": true
}'

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

ensure_brew() {
  if ! command -v brew >/dev/null 2>&1 && [ -x /opt/homebrew/bin/brew ]; then
    eval "$(/opt/homebrew/bin/brew shellenv)"
  fi
  if ! command -v brew >/dev/null 2>&1; then
    bold "Homebrew is not installed."
    info "Install it from https://brew.sh, then re-run this script."
    exit 1
  fi
  if ! xcode-select -p >/dev/null 2>&1; then
    bold "Xcode Command Line Tools (git, python3) are not installed."
    info "A macOS installer window will open. Re-run this script once it finishes."
    xcode-select --install
    exit 1
  fi
}

brew_cask() {
  if brew list --cask "$1" >/dev/null 2>&1 || { [ -n "${2:-}" ] && [ -e "$2" ]; }; then
    info "$1: already installed"
  else
    info "$1: installing..."
    brew install --cask "$1" || warn "Couldn't install $1"
  fi
}

brew_formula() {
  if command -v "$2" >/dev/null 2>&1; then
    info "$1: already installed"
  else
    info "$1: installing..."
    brew install "$1" || warn "Couldn't install $1"
  fi
}

install_tools() {
  bold "Installing apps and tools..."
  [ "$SKIP_DESKTOP" = false ] && brew_cask claude /Applications/Claude.app
  [ "$SKIP_CODE" = false ] && brew_cask claude-code
  brew_formula uv uv     # fli-mcp and the Blender desktop extension
  brew_formula node npx  # npx skills, and the Filesystem desktop extension
}

# ---------------------------------------------------------------------------
# 2. Claude Code
# ---------------------------------------------------------------------------

merge_settings() {
  bold "Claude Code settings..."
  local file="$HOME/.claude/settings.json"
  mkdir -p "$HOME/.claude"
  python3 -I - "$file" "$SETTINGS" <<'EOF'
import json, os, shutil, sys
path, wanted = sys.argv[1], json.loads(sys.argv[2])
current = json.load(open(path)) if os.path.exists(path) else {}
added = [k for k in wanted if k not in current]
for k in added:
    current[k] = wanted[k]
if added:
    if os.path.exists(path):
        shutil.copy(path, path + ".bak")
    with open(path, "w") as f:
        json.dump(current, f, indent=2)
    print("  added: " + ", ".join(added))
else:
    print("  already set up")
EOF
}

install_plugins() {
  bold "Plugins..."
  local repo plugin
  local have_markets have_plugins
  have_markets="$(claude plugin marketplace list 2>/dev/null)"
  for repo in $MARKETPLACES; do
    if printf '%s' "$have_markets" | grep -q "($repo)"; then
      info "marketplace $repo: already added"
    else
      info "marketplace $repo: adding..."
      claude plugin marketplace add "$repo" >/dev/null || warn "Couldn't add marketplace $repo"
    fi
  done
  have_plugins="$(claude plugin list 2>/dev/null)"
  for plugin in $PLUGINS; do
    if printf '%s' "$have_plugins" | grep -q "$plugin"; then
      info "$plugin: already installed"
    else
      info "$plugin: installing..."
      claude plugin install "$plugin" >/dev/null || warn "Couldn't install $plugin"
    fi
  done
}

# Is MCP server $1 configured? $2: project folder for a local-scope server.
mcp_exists() {
  python3 -I - "$HOME/.claude.json" "$1" "${2:-}" <<'EOF'
import json, os, sys
path, name, project = sys.argv[1:4]
if not os.path.exists(path):
    sys.exit(1)
d = json.load(open(path))
servers = d.get("projects", {}).get(project, {}) if project else d
sys.exit(0 if name in servers.get("mcpServers", {}) else 1)
EOF
}

install_fli() {
  if [ -x "$HOME/.local/bin/fli-mcp" ]; then
    info "fli-mcp: already installed"
  else
    info "fli-mcp: installing..."
    uv tool install -q 'flights[mcp]' --with click || warn "Couldn't install fli-mcp"
  fi
}

add_mcps() {
  bold "MCP servers..."
  install_fli

  local line name json folder dir
  set -f  # the JSON has ? and {} in it, keep the shell from globbing them
  for line in $USER_MCPS; do
    name="${line%%|*}"; json="${line#*|}"
    if mcp_exists "$name"; then
      info "$name: already added"
    else
      info "$name: adding..."
      claude mcp add-json -s user "$name" "$json" >/dev/null || warn "Couldn't add $name"
    fi
  done

  for line in $PROJECT_MCPS; do
    folder="${line%%|*}"; line="${line#*|}"
    name="${line%%|*}"; json="${line#*|}"
    dir="$PROJECTS_DIR/$folder"
    if [ ! -d "$dir" ]; then
      warn "$name: $dir doesn't exist. Run clone-projects.sh, then this script again."
    elif mcp_exists "$name" "$dir"; then
      info "$name ($folder): already added"
    else
      info "$name ($folder): adding..."
      (cd "$dir" && claude mcp add-json -s local "$name" "$json" >/dev/null) || warn "Couldn't add $name"
    fi
  done
  set +f
}

# Copy each file or folder in $1 into $2, skipping ones that already exist.
copy_missing() {
  local src dest
  mkdir -p "$2"
  for src in "$1"/*; do
    dest="$2/$(basename "$src")"
    if [ -e "$dest" ]; then
      info "$(basename "$src"): already there"
    else
      cp -R "$src" "$dest" && info "$(basename "$src"): copied"
    fi
  done
}

install_skills() {
  bold "Skills and commands..."
  copy_missing "$REPO_DIR/claude/skills" "$HOME/.claude/skills"
  copy_missing "$REPO_DIR/claude/commands" "$HOME/.claude/commands"

  local line repo skill
  for line in $PUBLIC_SKILLS; do
    repo="${line%%|*}"; skill="${line#*|}"
    if [ -e "$HOME/.claude/skills/$skill" ]; then
      info "$skill: already there"
    else
      info "$skill: installing from $repo..."
      npx -y skills add "$repo" -g -a claude-code -s "$skill" -y >/dev/null 2>&1 \
        || warn "Couldn't install $skill. Try: npx skills add $repo -g -s $skill"
    fi
  done
}

# ---------------------------------------------------------------------------
# 3. Claude Desktop
# ---------------------------------------------------------------------------
#
# Desktop preferences are tied to this Mac and your account, so nothing is
# written to claude_desktop_config.json. Connectors (Gmail, Drive, Slack, ...)
# belong to your claude.ai account and come back when you sign in.

setup_desktop() {
  bold "Claude Desktop..."
  open -a Claude 2>/dev/null || warn "Couldn't open Claude.app"
  cat <<EOF
  Finish these by hand in the app:
    1. Sign in. Your claude.ai connectors (Gmail, Google Drive, Slack, Docs, ...)
       come back with your account. Reconnect any that show "Connect" under
       Settings → Connectors.
    2. Settings → Extensions → Browse: install
         - Filesystem, and allow $PROJECTS_DIR/PrivatePdf
         - Blender (needs Blender running with its MCP add-on enabled)
    3. Install Claude in Chrome and pair it with the app.
EOF
  if confirm "  Open the Claude in Chrome page now?"; then
    open "https://claude.ai/chrome"
  fi
}

# ---------------------------------------------------------------------------

ensure_brew
install_tools

if [ "$SKIP_CODE" = false ]; then
  if ! command -v claude >/dev/null 2>&1; then
    warn "The claude command isn't on PATH. Open a new terminal and re-run this script."
    exit 1
  fi
  echo; merge_settings
  echo; install_plugins
  echo; add_mcps
  echo; install_skills
fi

if [ "$SKIP_DESKTOP" = false ]; then
  echo; setup_desktop
fi

echo
bold "Done."
if [ "$SKIP_CODE" = false ]; then
  info "In Claude Code, run /mcp and sign in to supabase, atlassian and vercel."
  info "Check everything with: claude mcp list"
fi
