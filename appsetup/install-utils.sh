#!/usr/bin/env bash
#
# Install the Utils apps that come from Homebrew.
# Apps installed from a website or the App Store are listed in install-utils.md.
#
# What each app is for is in the README.
# Run it to pick from a list, or pass --all to install everything.
# Safe to re-run: anything already installed is skipped.

. "$(dirname "$0")/lib.sh"

cask 1password
cask macs-fan-control
cask vorssaint

run_installer "Utils" "$@"
