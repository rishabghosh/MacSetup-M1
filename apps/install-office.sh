#!/usr/bin/env bash
#
# Install the Office apps that come from Homebrew.
# Apps installed from a website or the App Store are listed in install.md.
#
# Run it to pick from a list, or pass --all to install everything.
# Safe to re-run: anything already installed is skipped.

. "$(dirname "$0")/lib.sh"

cask slack "Slack, team chat." \
  "e.g. work channels, huddles and DMs"
cask zoom "Zoom, video meetings." \
  "e.g. join a meeting from a calendar link"
cask claude "Claude desktop app: chat, Cowork and the Code tab." \
  "e.g. this app; setup-claude.sh configures it after install"
cask chatgpt "ChatGPT desktop app. Also replaces the discontinued Codex app cask." \
  "e.g. Option+Space opens the quick chat bar"
cask brave-browser "Brave, a Chromium browser that blocks ads and trackers." \
  "e.g. a second browser profile kept apart from Chrome"

run_installer "Office" "$@"
