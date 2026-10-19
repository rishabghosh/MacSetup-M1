#!/usr/bin/env bash
#
# Install the Entertainment apps that come from Homebrew.
# Apps installed from a website or the App Store are listed in install.md.
#
# Run it to pick from a list, or pass --all to install everything.
# Safe to re-run: anything already installed is skipped.

. "$(dirname "$0")/lib.sh"

cask vlc "VLC, plays almost any video or audio file." \
  "e.g. MKV files and subtitles QuickTime can't open; VMR Connect remote-controls it"
cask discord "Discord, voice and text chat for communities and games." \
  "e.g. game servers and voice channels"

run_installer "Entertainment" "$@"
