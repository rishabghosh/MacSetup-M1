#!/usr/bin/env bash
#
# Install the coding apps and command-line tools that come from Homebrew, plus
# the latest LTS Node (through nvm) and Playwright's browsers. Apps installed from a website or the App Store are
# listed in install-coding.md.
#
# What each app is for is in the README.
# Run it to pick from a list, or pass --all to install everything.
# Safe to re-run: anything already installed is skipped.

. "$(dirname "$0")/lib.sh"

cask visual-studio-code
cask cursor
cask webstorm
cask intellij-idea
cask intellij-idea-ce
cask pycharm
cask iterm2
cask docker-desktop
cask xquartz
cask claude
cask chatgpt
cask claude-code
cask android-platform-tools
cask session-manager-plugin

formula git
formula git-lfs
formula nvm
formula pyenv
formula python@3.10
formula awscli
formula hashicorp/tap/terraform
formula kubernetes-cli
formula kubectx
formula kind
formula helm
formula k9s
formula jq
formula yq
formula tree
formula opencode
formula claude-code-router
formula ffmpeg
formula imagemagick
formula img2pdf
formula poppler
formula innoextract
formula hey
formula fio
formula cpulimit
formula argp-standalone

step node-lts
step playwright-browsers

# Homebrew's nvm is a shell function in nvm.sh, not a command, so it has to
# be sourced. Call it in a subshell: nvm.sh doesn't work under `set -u`.
load_nvm() {
  local nvm_sh="${HOMEBREW_PREFIX:-/opt/homebrew}/opt/nvm/nvm.sh"
  [ -s "$nvm_sh" ] || return 1
  export NVM_DIR="$HOME/.nvm"
  set +u
  # shellcheck source=/dev/null
  . "$nvm_sh"
}

node_lts_installed() {
  ( load_nvm && [ "$(nvm version 'lts/*')" != N/A ] ) >/dev/null 2>&1
}
install_node_lts() {
  (
    mkdir -p "$HOME/.nvm"
    load_nvm || { warn "nvm not found. Pick nvm too, then re-run."; exit 1; }
    nvm install --lts && nvm alias default 'lts/*'
  )
}

# Playwright keeps its browsers here, one folder per browser and version.
playwright_browsers_installed() {
  ls -d "$HOME/Library/Caches/ms-playwright"/chromium-* >/dev/null 2>&1
}
install_playwright_browsers() {
  (
    command -v npx >/dev/null 2>&1 || load_nvm
    if ! command -v npx >/dev/null 2>&1; then
      warn "npx not found. Pick node-lts too (or run claudesetup/setup-claude.sh), then re-run."
      exit 1
    fi
    npx -y playwright install
  )
}

run_installer "Coding" "$@"
