#!/usr/bin/env bash
#
# Install the Entertainment apps that come from Homebrew.
# Apps installed from a website or the App Store are listed in install-entertainment.md.
#
# What each app is for is in the README.
# Run it to pick from a list, or pass --all to install everything.
# Safe to re-run: anything already installed is skipped.

. "$(dirname "$0")/lib.sh"

cask vlc
cask discord
cask brave-browser
cask protonvpn

run_installer "Entertainment" "$@"
