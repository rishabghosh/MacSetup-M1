#!/usr/bin/env bash
#
# Install the Gaming apps that come from Homebrew.
# Apps installed from a website or the App Store are listed in install.md.
#
# Run it to pick from a list, or pass --all to install everything.
# Safe to re-run: anything already installed is skipped.

. "$(dirname "$0")/lib.sh"

cask epic-games "Epic Games Launcher, for your Epic library and the weekly free games." \
  "e.g. claim free games; Mythic can also play Epic games"

run_installer "Gaming" "$@"
