#!/usr/bin/env bash
#
# Install the Office apps that come from Homebrew.
# Apps installed from a website or the App Store are listed in install-office.md.
#
# What each app is for is in the README.
# Run it to pick from a list, or pass --all to install everything.
# Safe to re-run: anything already installed is skipped.

. "$(dirname "$0")/lib.sh"

cask slack
cask microsoft-teams
cask zoom
cask microsoft-office
cask wpsoffice
cask google-chrome
cask microsoft-edge

run_installer "Office" "$@"
