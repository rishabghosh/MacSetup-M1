# Installing apps on a new Mac

Each category has a script that installs its Homebrew apps. Everything else comes from a website or the App Store and is listed below.

## 1. Run the Homebrew scripts

Each script lists its apps and tools, numbered, with a short description and an example of what each one is for. Command-line tools also show how often they've been run (from shell history and past Claude Code sessions). Anything already installed is marked. Then you pick:

- `a` installs everything
- `1 3 5-8` installs only those
- `a !4 !10-12` installs everything except those
- `q` quits

Run a script with `--all` to skip the question and install everything, or `--list` to only see the list.

Each script installs Homebrew first if it's missing, skips anything that's already installed, and lists any failures at the end. You can run them in any order.

```bash
./install-office.sh
```

```bash
./install-coding.sh
```

```bash
./install-entertainment.sh
```

```bash
./install-gaming.sh
```

```bash
./install-editing.sh
```

```bash
./install-utils.sh
```

| Script | Installs |
|---|---|
| `install-office.sh` | Slack, Zoom, Claude, ChatGPT, Brave Browser |
| `install-coding.sh` | VS Code, Cursor, WebStorm, iTerm2, Docker Desktop, XQuartz, Claude Code, Android platform tools, AWS Session Manager plugin, plus 26 command-line tools (git, nvm, pyenv, terraform, kubectl, helm, ffmpeg, imagemagick…) |
| `install-entertainment.sh` | VLC, Discord |
| `install-gaming.sh` | Epic Games Launcher |
| `install-editing.sh` | Canva |
| `install-utils.sh` | 1Password, ProtonVPN, Macs Fan Control |

`install-coding.sh` asks for your password once, for XQuartz. After it finishes, follow the setup lines Homebrew prints for `nvm` and `pyenv`. They need a few lines added to `~/.zshrc`.

## 2. Install the rest by hand

**⬇️ Website:** download the `.dmg` (or `.pkg`) from the link, open it, and drag the app into Applications (or run the installer).
**🛒 App Store:** open the link, sign in with the Apple ID you bought the app with, and click **Get** or the download icon.

### Office
| App | From | Where to get it |
|---|---|---|
| WPS Office | ⬇️ Website | https://www.wps.com/download/ |
| Google Chrome | ⬇️ Website | https://www.google.com/chrome/ |
| Safari | 🍎 Built in | Nothing to install |

### Coding
| App | From | Where to get it |
|---|---|---|
| Codex (desktop app) | ⬇️ Website | https://openai.com/codex/ |

### Entertainment
| App | From | Where to get it |
|---|---|---|
| Telegram | ⬇️ Website | https://macos.telegram.org/ (the native macOS app, not Telegram Desktop) |
| uTorrent Web | ⬇️ Website | https://www.utorrent.com/web/ |
| VMR Connect (VLC Mobile Remote) | ⬇️ Website | https://www.vlcmobileremote.com/ |
| Screen Mirror to TV & Device | 🛒 App Store | https://apps.apple.com/app/id1496988766 |

### Gaming
| App | From | Where to get it |
|---|---|---|
| Steam | ⬇️ Website | https://store.steampowered.com/about/ |
| GeForce NOW | ⬇️ Website | https://www.nvidia.com/en-us/geforce-now/download/ |
| BlueStacks Air | ⬇️ Website | https://www.bluestacks.com/mac (also installs the Multi-Instance Manager) |
| BlueAI | ⬇️ Website | Made by BlueStacks (now.gg). Check whether BlueStacks installed it; otherwise look on https://www.bluestacks.com |
| GameHub (GameSir) | ⬇️ Website | https://www.gamesir.com (Mac version is in beta) |
| Rise of the Tomb Raider | Mythic launcher | Install Mythic from https://getmythic.app, sign in to the store you bought the game on, and download it again |

### Editing
| App | From | Where to get it |
|---|---|---|
| Adobe Illustrator 2025 | Adobe Creative Cloud | Install Creative Cloud from https://creativecloud.adobe.com/apps/download/creative-cloud, sign in, then install Illustrator from it |
| Pixelmator Pro | 🛒 App Store | https://apps.apple.com/app/id1289583905 |
| Topaz Gigapixel AI | ⬇️ Website | https://www.topazlabs.com/downloads (sign in to your Topaz account) |
| Topaz Photo AI | ⬇️ Website | https://www.topazlabs.com/downloads |
| Blender | ⬇️ Website | https://www.blender.org/download/ (choose macOS Apple Silicon) |
| Photopea | Chrome web app | Open https://www.photopea.com in Chrome, then ⋮ menu → **Cast, save, and share → Install page as app** |

### Utils
| App | From | Where to get it |
|---|---|---|
| iStat Menus 7 | 🛒 App Store | https://apps.apple.com/app/id6499559693 |
| OS Cleaner Pro | 🛒 App Store | https://apps.apple.com/app/id1084211765 |
| Send Anywhere | ⬇️ Website | https://send-anywhere.com/ |
| Vorssaint | ⬇️ Website | https://github.com/vorssaint/vorssaint-utils (Releases) |

## Homebrew options for the apps above

Most of the apps above can also be installed with Homebrew. Then `brew upgrade` keeps them up to date as well. Each option below was checked against `brew info` on 2026-10-19.

### ✅ Homebrew cask available (same app)
| App | Category | Command | Notes |
|---|---|---|---|
| WPS Office | Office | `brew install --cask wpsoffice` | |
| Google Chrome | Office | `brew install --cask google-chrome` | |
| Telegram | Entertainment | `brew install --cask telegram` | Same native macOS app (`macos.telegram.org`) |
| Steam | Gaming | `brew install --cask steam` | |
| GeForce NOW | Gaming | `brew install --cask nvidia-geforce-now` | |
| BlueStacks Air + Multi-Instance Manager + BlueAI | Gaming | `brew install --cask bluestacks` | Runs the official BlueStacks installer. BlueAI's version matches BlueStacks, so it comes with it |
| GameHub | Gaming | `brew install --cask gamehub` | Same version as the one installed now (0.8.613) |
| Mythic (for Rise of the Tomb Raider) | Gaming | `brew install --cask mythic` | Re-download the game inside Mythic |
| Blender | Editing | `brew install --cask blender` | `blender@lts` is also available |
| Adobe Creative Cloud (for Illustrator) | Editing | `brew install --cask adobe-creative-cloud` | Installs Creative Cloud only. Install Illustrator from inside it |
| Send Anywhere | Utils | `brew install --cask send-anywhere` | |
| Vorssaint | Utils | `brew install --cask vorssaint` | Open-source menu bar toolkit: https://github.com/vorssaint/vorssaint-utils |

### ⚠️ Homebrew cask available, with a catch
| App | Category | Command | Catch |
|---|---|---|---|
| Topaz Gigapixel AI | Editing | `brew install --cask topaz-gigapixel` | The `topaz-gigapixel-ai` cask was disabled on 2026-09-27. Its replacement, "Topaz Gigapixel", is Topaz's newer product, and your current license may not cover it |
| Topaz Photo AI | Editing | `brew install --cask topaz-photo` | Same situation: `topaz-photo-ai` is disabled and "Topaz Photo" replaces it |
| Codex (desktop app) | Coding | none | The `codex-app` cask was discontinued on 2026-07-12. Homebrew points to `chatgpt` instead, which `install-office.sh` already installs. To keep the separate Codex app, download it from https://openai.com/codex/ |
| iStat Menus 7 | Utils | `brew install --cask istat-menus` | This is Bjango's website version. Your App Store license won't unlock it, so use `mas` (below) instead |

### 🛒 App Store apps, through `mas`
`mas` installs App Store apps from the command line. Sign in to the App Store app first. Paid apps must already be purchased on your Apple ID.

```bash
brew install mas
```

| App | Category | Command | Price |
|---|---|---|---|
| Screen Mirror to TV & Device | Entertainment | `mas install 1496988766` | Free |
| Pixelmator Pro | Editing | `mas install 1289583905` | Paid (already purchased) |
| iStat Menus 7 | Utils | `mas install 6499559693` | Paid (already purchased) |
| OS Cleaner Pro | Utils | `mas install 1084211765` | Free |

### ❌ No Homebrew option
| App | Category | Why |
|---|---|---|
| Safari | Office | Built into macOS |
| uTorrent Web | Entertainment | No cask exists |
| VMR Connect | Entertainment | No cask exists |
| Rise of the Tomb Raider | Gaming | A game, installed through Mythic |
| Adobe Illustrator | Editing | Only installable through Creative Cloud |
| Photopea | Editing | A Chrome web app, installed from Chrome
