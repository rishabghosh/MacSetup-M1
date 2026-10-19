#!/usr/bin/env bash
#
# Install the Utils apps that come from Homebrew.
# Apps installed from a website or the App Store are listed in install-utils.md.
#
# Run it to pick from a list, or pass --all to install everything.
# Safe to re-run: anything already installed is skipped.

. "$(dirname "$0")/lib.sh"

cask 1password "1Password, password manager." \
  "e.g. fill passwords and passkeys in the browser; also has the \`op\` CLI if you add it"
cask protonvpn "Proton VPN." \
  "e.g. connect to another country, or use Secure Core on public Wi-Fi"
cask macs-fan-control "Macs Fan Control, shows temperatures and sets fan speeds." \
  "e.g. raise the fan curve during long renders or games"

run_installer "Utils" "$@"
