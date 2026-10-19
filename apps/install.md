# Installing apps on a new Mac

Each category has a script that installs its Homebrew apps, and a page listing the apps you install by hand from a website or the App Store.

| Category | Script | Page |
|---|---|---|
| Office | `install-office.sh` | [install-office.md](install-office.md) |
| Coding | `install-coding.sh` | [install-coding.md](install-coding.md) |
| Entertainment | `install-entertainment.sh` | [install-entertainment.md](install-entertainment.md) |
| Gaming | `install-gaming.sh` | [install-gaming.md](install-gaming.md) |
| Editing | `install-editing.sh` | [install-editing.md](install-editing.md) |
| Utils | `install-utils.sh` | [install-utils.md](install-utils.md) |

## Running a script

Each script lists its apps and tools, numbered, with a short description and an example of what each one is for. Command-line tools also show how often they've been run (from shell history and past Claude Code sessions). Anything already installed is marked. Then you pick:

- `a` installs everything
- `1 3 5-8` installs only those
- `a !4 !10-12` installs everything except those
- `q` quits

Run a script with `--all` to skip the question and install everything, or `--list` to only see the list.

Each script installs Homebrew first if it's missing, skips anything that's already installed, and lists any failures at the end. You can run them in any order.

## Installing by hand

Each category page has a table of the apps that the script doesn't install:

- **⬇️ Website:** download the `.dmg` (or `.pkg`) from the link, open it, and drag the app into Applications (or run the installer).
- **🛒 App Store:** open the link, sign in with the Apple ID you bought the app with, and click **Get** or the download icon.

Most of these apps can also be installed with Homebrew, so `brew upgrade` keeps them up to date too. The "Homebrew instead" column shows the command. Those options were checked against `brew info` on 2026-10-19.

App Store apps can be installed from the command line with `mas`. Sign in to the App Store app first. Paid apps must already be purchased on your Apple ID.

```bash
brew install mas
```
