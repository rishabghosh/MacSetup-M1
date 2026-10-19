# Editing apps

[All categories](install.md)

## Homebrew script

```bash
./install-editing.sh
```

Installs Canva.

## Install by hand

| App | From | Where to get it | Homebrew instead |
|---|---|---|---|
| Adobe Illustrator 2025 | Adobe Creative Cloud | Install Creative Cloud from https://creativecloud.adobe.com/apps/download/creative-cloud, sign in, then install Illustrator from it | `brew install --cask adobe-creative-cloud`. That installs Creative Cloud only, so install Illustrator from inside it |
| Pixelmator Pro | 🛒 App Store | https://apps.apple.com/app/id1289583905 | `mas install 1289583905` (paid, already purchased) |
| Topaz Gigapixel AI | ⬇️ Website | https://www.topazlabs.com/downloads (sign in to your Topaz account) | ⚠️ `brew install --cask topaz-gigapixel`, see below |
| Topaz Photo AI | ⬇️ Website | https://www.topazlabs.com/downloads | ⚠️ `brew install --cask topaz-photo`, see below |
| Blender | ⬇️ Website | https://www.blender.org/download/ (choose macOS Apple Silicon) | `brew install --cask blender` (`blender@lts` is also available) |
| Photopea | Chrome web app | Open https://www.photopea.com in Chrome, then ⋮ menu → **Cast, save, and share → Install page as app** | None, it's installed from Chrome |

⚠️ The `topaz-gigapixel-ai` and `topaz-photo-ai` casks were disabled on 2026-09-27. Their replacements, "Topaz Gigapixel" and "Topaz Photo", are Topaz's newer products, and your current license may not cover them.
