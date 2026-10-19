#!/usr/bin/env bash
#
# Install the Editing apps that come from Homebrew.
# Apps installed from a website or the App Store are listed in install-editing.md.
#
# Run it to pick from a list, or pass --all to install everything.
# Safe to re-run: anything already installed is skipped.

. "$(dirname "$0")/lib.sh"

cask canva "Canva desktop app, for designs, social posts and mockups." \
  "e.g. the templates the canva-bulk-template project fills in"

run_installer "Editing" "$@"
