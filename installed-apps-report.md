# Installed Applications Report — MacBook (M1)

Every installed app is in exactly one of six categories: Office, Coding, Entertainment, Gaming, Editing and Utils. Sources checked: `/Applications`, `~/Applications`, `brew list --cask`, `brew leaves`, App Store receipts (`_MASReceipt`) and code signatures.

**Install methods:** 🍺 Homebrew cask · 🛒 Mac App Store · ⬇️ Direct download (DMG/PKG from the vendor) · 🍎 Built into macOS · other installers named in full

## Office (8)
| App | Install method | Notes |
|---|---|---|
| Slack | 🍺 Homebrew | |
| Zoom | 🍺 Homebrew | |
| Claude | 🍺 Homebrew | |
| ChatGPT | 🍺 Homebrew | |
| WPS Office | ⬇️ Direct download | Signed by Kingsoft |
| Google Chrome | ⬇️ Direct download | |
| Brave Browser | 🍺 Homebrew | |
| Safari | 🍎 Built in | |

## Coding (7 apps + command-line tools)
| App | Install method | Notes |
|---|---|---|
| Visual Studio Code | 🍺 Homebrew | |
| Cursor | 🍺 Homebrew | |
| WebStorm | 🍺 Homebrew | |
| iTerm2 | 🍺 Homebrew | |
| Docker Desktop | 🍺 Homebrew | |
| Codex (desktop app) | ⬇️ Direct download | Signed by OpenAI; the `codex` cask is the CLI |
| XQuartz | 🍺 Homebrew | X11 server, in `/Applications/Utilities` |
| Command-line casks: claude-code, android-platform-tools, session-manager-plugin | 🍺 Homebrew | No app bundle |
| Command-line formulae: git, git-lfs, nvm, pyenv, python@3.10, awscli, terraform, helm, kubectl, k9s, kind, kubectx, jq, yq, opencode, claude-code-router, ffmpeg, imagemagick, poppler, and others | 🍺 Homebrew | 25 top-level formulae |

## Entertainment (6)
| App | Install method | Notes |
|---|---|---|
| VLC | 🍺 Homebrew | Media player |
| Discord | 🍺 Homebrew | Chat |
| Telegram | ⬇️ Direct download | Chat |
| uTorrent Web | ⬇️ Direct download | Torrent client |
| Screen Mirror to TV & Device | 🛒 App Store | Casting to a TV |
| VMR Connect | ⬇️ Direct download | VLC Mobile Remote: controls VLC from your phone |

## Gaming (8)
| App | Install method | Notes |
|---|---|---|
| Steam | ⬇️ Direct download | Signed by Valve |
| Epic Games Launcher | 🍺 Homebrew | |
| GeForce NOW | ⬇️ Direct download | |
| BlueStacks | ⬇️ Direct download | |
| BlueStacks Air Multi-Instance Manager | ⬇️ Direct download | Comes with BlueStacks |
| BlueAI | ⬇️ Direct download | Signed by now.gg (BlueStacks parent) |
| GameHub | ⬇️ Direct download | Signed by Guangzhou Chicken Run Network Technology |
| Rise of the Tomb Raider | Mythic launcher | In `/Applications/Games/Mythic`, but Mythic.app itself is no longer installed |

## Editing (7)
| App | Install method | Notes |
|---|---|---|
| Adobe Illustrator 2025 | Adobe Creative Cloud | Plus Adobe Installers / Adobe Sync in Utilities |
| Pixelmator Pro | 🛒 App Store | |
| Canva | 🍺 Homebrew | |
| Topaz Gigapixel AI | ⬇️ Direct download | |
| Topaz Photo AI | ⬇️ Direct download | |
| Blender | ⬇️ Direct download | Signed by Blender Foundation |
| Photopea | Chrome web app | In `~/Applications/Chrome Apps` |

## Utils (7)
| App | Install method | Notes |
|---|---|---|
| 1Password | 🍺 Homebrew | |
| ProtonVPN | 🍺 Homebrew | |
| Macs Fan Control | 🍺 Homebrew | |
| iStat Menus | 🛒 App Store | |
| OS Cleaner Pro | 🛒 App Store | |
| Send Anywhere | ⬇️ Direct download | File transfer |
| Vorssaint | ⬇️ Direct download | Signed by Pedro Gomes (independent developer) |

## Summary
| Category | 🍺 Homebrew | ⬇️ Direct | 🛒 App Store | Other | Total |
|---|---|---|---|---|---|
| Office | 5 | 2 | 0 | 1 (built in) | 8 |
| Coding | 6 | 1 | 0 | 0 | 7 |
| Entertainment | 2 | 3 | 1 | 0 | 6 |
| Gaming | 1 | 6 | 0 | 1 (Mythic) | 8 |
| Editing | 1 | 3 | 1 | 2 (Adobe CC, Chrome web app) | 7 |
| Utils | 3 | 2 | 2 | 0 | 7 |
| **Total** | **18** | **17** | **4** | **4** | **43** |

## ⚠️ Housekeeping findings
1. **9 Homebrew records point to deleted apps.** Homebrew still lists these casks as installed, but their apps are gone from `/Applications`: Antigravity, Bartender 7, CapCut, Firefox, Jellyfin, LuLu, Obsidian, SVP 4 Mac, WebTorrent. Running `brew upgrade` will try to update or reinstall them.
2. **Leftover folders.** `~/Applications/CrossOver` is empty, and `/Applications/Games/Mythic` holds a game whose launcher has been removed.
3. **Apps you could move to Homebrew** so they update with `brew upgrade`: Chrome, Steam, Telegram, Blender, GeForce NOW, BlueStacks, Send Anywhere, WPS Office (all have casks).
4. `mas` (the App Store command-line tool) is not installed, so App Store apps can't be scripted for a new machine yet.
