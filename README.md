# MACSETUP-M1

Setup scripts for a fresh Apple Silicon Mac. This page covers everything: what to run, in what order, and every app it installs.

## What's in this repo

| Path | What it does |
|---|---|
| [appsetup/](appsetup/) | One app installer per category (Office, Coding, Entertainment, Gaming, Editing, Utils), plus a page per category for the apps you install by hand |
| [clone-projects.sh](clone-projects.sh) | Sets up GitHub SSH, clones every project into `~/projects` and recreates their `.env` files |
| [claudesetup/](claudesetup/) | `setup-claude.sh` sets up Claude Desktop and Claude Code. Also holds your own skills and commands |
| [settings/](settings/) | Captures the old Mac's settings and restores them on the new one. `settings/saved/` holds the ones without secrets |
| [appsettings/](appsettings/) | Full settings capture and restore for single apps (WebStorm), run by `settings/` or on their own |
| [useful-commands.md](useful-commands.md) | Handy commands from the old Mac's shell history |
| [installed-apps-report.md](installed-apps-report.md) | What was installed on the old Mac, and how |
| [tests/](tests/) | Shellcheck and stubbed tests for every script |

## Setting up a new Mac, step by step

**On the old Mac, first:** capture its settings, then copy the backup folder to the new Mac (see [Mac settings](#mac-settings)).

```bash
./settings/capture-settings.sh
```

**On the new Mac:**

1. **Get this repo.** The Mac has no SSH key yet, so clone over HTTPS. If the repo is private, git asks for your GitHub username and a personal access token instead of your password. You can also download the repo as a ZIP from GitHub and unzip it to `~/projects/MACSETUP-M1`.

   ```bash
   git clone https://github.com/rishabghosh/MacSetup-M1.git ~/projects/MACSETUP-M1
   ```

2. **Install apps.** Run the category scripts you want, in any order. Each one installs Homebrew first if it's missing. See [Install apps](#install-apps) for what each one installs.

   ```bash
   ~/projects/MACSETUP-M1/appsetup/install-office.sh
   ~/projects/MACSETUP-M1/appsetup/install-coding.sh
   ~/projects/MACSETUP-M1/appsetup/install-entertainment.sh
   ~/projects/MACSETUP-M1/appsetup/install-gaming.sh
   ~/projects/MACSETUP-M1/appsetup/install-editing.sh
   ~/projects/MACSETUP-M1/appsetup/install-utils.sh
   ```

3. **Install the apps that don't come from Homebrew** (App Store, websites, Adobe). They're listed under each category below.

4. **Clone your projects.** See [Clone all projects](#clone-all-projects).

   ```bash
   ~/projects/MACSETUP-M1/clone-projects.sh
   ```

5. **Set up Claude.** Run it after cloning, because two of the MCP servers belong to a single project folder. See [Set up Claude](#set-up-claude).

   ```bash
   ~/projects/MACSETUP-M1/claudesetup/setup-claude.sh
   ```

6. **Restore your settings.** Run it after the apps are installed, from Terminal (not iTerm2). See [Mac settings](#mac-settings).

   ```bash
   ~/projects/MACSETUP-M1/settings/restore-settings.sh
   ```

7. **Finish by hand:** sign in to your apps, follow the setup lines Homebrew printed for `nvm` and `pyenv`, and do the Claude steps under [Done by hand](#done-by-hand).

Every script is safe to re-run. Anything that's already installed or set up is skipped.

## Install apps

Each script in `appsetup/` shows a checklist of its apps. Anything already installed is marked `(installed)`. The checklist fills the terminal window and resizes with it.

- **↑ / ↓** (or `j` / `k`) moves the cursor.
- **Space** ticks or unticks the item under the cursor.
- **All**, the first row, ticks everything. Press space on it again to untick everything. `a` does the same from anywhere in the list.
- **Enter** installs what's ticked.
- **q** or **Esc** quits without installing anything.

To install everything except a few items, tick All, then untick the ones you don't want. Pass `--all` to skip the checklist and install everything, or `--list` to only print the list.

Each script skips anything that's already installed and lists any failures at the end. A cask usually fails because the app is already in `/Applications` from a direct download. Delete it and re-run.

Each category also has a page in `appsetup/` with the download links, the Homebrew alternative for each hand-installed app, and any caveats. [appsetup/install.md](appsetup/install.md) links to all of them.

### Office

```bash
./appsetup/install-office.sh
```

| App | Homebrew name | What it does |
|---|---|---|
| Slack | `slack` | Team chat: work channels, huddles and DMs |
| Microsoft Teams | `microsoft-teams` | Chat and meetings on a Microsoft 365 account. Asks for your password |
| Zoom | `zoom` | Video meetings, joined from a calendar link |
| Microsoft 365 | `microsoft-office` | Word, Excel, PowerPoint, Outlook, OneNote and OneDrive. Asks for your password. Open Word, Excel or PowerPoint once and sign in to activate it |
| WPS Office | `wpsoffice` | A free office suite that opens and edits Word, Excel and PowerPoint files without a Microsoft 365 license |
| Google Chrome | `google-chrome` | Google's browser, with your synced bookmarks and extensions. Claude in Chrome runs in it |
| Microsoft Edge | `microsoft-edge` | Microsoft's Chromium browser, handy for a work profile signed in to a Microsoft account |

Install by hand ([install-office.md](appsetup/install-office.md)):

| App | What it does | Where to get it |
|---|---|---|
| Safari | Apple's browser | Built into macOS |

### Coding

```bash
./appsetup/install-coding.sh
```

Apps:

| App | Homebrew name | What it does |
|---|---|---|
| VS Code | `visual-studio-code` | Microsoft's code editor. Adds the `code` command |
| Cursor | `cursor` | An AI-first fork of VS Code. Adds the `cursor` command |
| WebStorm | `webstorm` | JetBrains' IDE for JavaScript and TypeScript. Adds the `webstorm` command |
| IntelliJ IDEA | `intellij-idea` | JetBrains' IDE for Java and Kotlin. Since 2025.3 one app with a free tier and a paid Ultimate tier |
| IntelliJ IDEA CE | `intellij-idea-ce` | The old free Community Edition. Discontinued: Homebrew keeps it at 2025.2 and will stop installing it at some point |
| PyCharm | `pycharm` | JetBrains' IDE for Python. One app with a free tier since 2025.1, which replaced PyCharm CE |
| iTerm2 | `iterm2` | A Terminal replacement with split panes, tabs, profiles and searchable scrollback |
| Docker Desktop | `docker-desktop` | Runs containers locally and adds the `docker` command. `kind` needs it |
| XQuartz | `xquartz` | An X11 window server, needed by Linux/Unix apps that open X11 windows (Wine, older GUI tools). Asks for your password |
| Claude | `claude` | The Claude desktop app: chat, Cowork and the Code tab. `claudesetup/setup-claude.sh` configures it |
| ChatGPT | `chatgpt` | The ChatGPT desktop app. Option+Space opens its quick chat bar. It also replaces the discontinued Codex app cask |
| Claude Code | `claude-code` | Anthropic's coding agent in the terminal (`claude`) |
| Android platform tools | `android-platform-tools` | `adb` and `fastboot`, to talk to an Android phone over USB |
| AWS Session Manager plugin | `session-manager-plugin` | Lets `aws ssm start-session` open a shell on an EC2 instance without SSH |

Command-line tools:

| Tool | Homebrew name | What it does |
|---|---|---|
| git | `git` | Version control |
| Git LFS | `git-lfs` | Keeps big binaries (like `.blend` files) out of the git history |
| nvm | `nvm` | Node Version Manager. Needs a few lines in `~/.zshrc`, which Homebrew prints |
| pyenv | `pyenv` | Python version manager. Needs a few lines in `~/.zshrc`, which Homebrew prints |
| Python 3.10 | `python@3.10` | Python 3.10, as `python3.10` |
| AWS CLI | `awscli` | The AWS command line (`aws`) |
| Terraform | `hashicorp/tap/terraform` | Infrastructure as code. Your `~/.zshrc` aliases it to `tf` |
| kubectl | `kubernetes-cli` | The Kubernetes command line. Aliased to `k`, `kgp`, `kga` and `kev` in `~/.zshrc` |
| kubectx | `kubectx` | `kubectx` and `kubens`, to switch Kubernetes clusters and namespaces quickly |
| kind | `kind` | Kubernetes in Docker: a local cluster for learning and testing |
| Helm | `helm` | The Kubernetes package manager |
| k9s | `k9s` | A terminal UI for browsing and managing a Kubernetes cluster |
| jq | `jq` | Slices and filters JSON on the command line |
| yq | `yq` | jq for YAML files |
| tree | `tree` | Prints a folder as a tree |
| OpenCode | `opencode` | An open-source AI coding agent in the terminal |
| Claude Code Router | `claude-code-router` | `ccr`, runs Claude Code against other model providers |
| FFmpeg | `ffmpeg` | Converts, cuts and compresses video and audio |
| ImageMagick | `imagemagick` | Edits images from the command line (`magick`, `mogrify`) |
| img2pdf | `img2pdf` | Turns images into a PDF without re-compressing them |
| Poppler | `poppler` | PDF tools: `pdftoppm`, `pdftotext`, `pdfinfo`, `pdfimages` |
| innoextract | `innoextract` | Unpacks Windows Inno Setup installers (`.exe`), like GOG game installers, without Windows |
| hey | `hey` | HTTP load generator, for quick load tests |
| fio | `fio` | Disk read/write benchmark |
| cpulimit | `cpulimit` | Caps how much CPU a running process can use |
| argp-standalone | `argp-standalone` | A C library with no command of its own, needed to compile some Linux tools on macOS |

Other setup (not from Homebrew, run after the Homebrew installs):

| Step | What it does |
|---|---|
| `node-lts` | Installs the latest LTS Node with nvm and makes it the default. Needs `nvm` |
| `playwright-browsers` | Installs Playwright's test browsers (Chromium, Firefox, WebKit) with `npx playwright install`. Needs Node |

They run in that order, so nvm is there before Node and Node is there before Playwright. Until you add the nvm lines to `~/.zshrc`, `node` and `npm` only work inside the script.

Install by hand ([install-coding.md](appsetup/install-coding.md)):

| App | What it does | Where to get it |
|---|---|---|
| Codex (desktop app) | OpenAI's coding agent app. Its Homebrew cask was discontinued | https://openai.com/codex/ |

### Entertainment

```bash
./appsetup/install-entertainment.sh
```

| App | Homebrew name | What it does |
|---|---|---|
| VLC | `vlc` | Plays almost any video or audio file, including MKV files and subtitles QuickTime can't open |
| Discord | `discord` | Voice and text chat for communities and games |
| Brave | `brave-browser` | A Chromium browser that blocks ads and trackers, kept apart from your Chrome profile |
| Proton VPN | `protonvpn` | VPN: connect through another country, or use Secure Core on public Wi-Fi |

Install by hand ([install-entertainment.md](appsetup/install-entertainment.md)):

| App | What it does | Where to get it |
|---|---|---|
| Telegram | Messaging (the native macOS app, not Telegram Desktop) | https://macos.telegram.org/ or `brew install --cask telegram` |
| uTorrent Web | Torrent client that runs in the browser | https://www.utorrent.com/web/ |
| VMR Connect (VLC Mobile Remote) | Lets your phone remote-control VLC on the Mac | https://www.vlcmobileremote.com/ |
| Screen Mirror to TV & Device | Mirrors the Mac's screen to a smart TV or streaming device | App Store: https://apps.apple.com/app/id1496988766 |

### Gaming

```bash
./appsetup/install-gaming.sh
```

| App | Homebrew name | What it does |
|---|---|---|
| Epic Games Launcher | `epic-games` | Your Epic library and the weekly free games |
| Steam | `steam` | Valve's game store and launcher |
| GeForce NOW | `nvidia-geforce-now` | NVIDIA's cloud gaming: streams PC games you own on Steam or Epic, including ones your Mac can't run |
| BlueStacks Air | `bluestacks` | Runs Android games and apps with keyboard and mouse controls. Also installs the Multi-Instance Manager and BlueAI |
| GameHub | `gamehub` | GameSir's compatibility layer for running Windows and Steam games on Apple Silicon. In beta |

Nothing to install by hand.

### Editing

```bash
./appsetup/install-editing.sh
```

| App | Homebrew name | What it does |
|---|---|---|
| Canva | `canva` | Designs, social posts and mockups, including the templates the canva-bulk-template project fills in |
| Blender | `blender` | 3D modelling, animation and rendering. Claude's Blender extension needs it running with the MCP add-on |

Install by hand ([install-editing.md](appsetup/install-editing.md)):

| App | What it does | Where to get it |
|---|---|---|
| Adobe Illustrator 2025 | Vector graphics and illustration | Install Creative Cloud from https://creativecloud.adobe.com/apps/download/creative-cloud, sign in, then install Illustrator from it |
| Pixelmator Pro | Photo editing and image design (paid, already purchased) | App Store: https://apps.apple.com/app/id1289583905 |
| Topaz Gigapixel AI | AI image upscaling | https://www.topazlabs.com/downloads (sign in to your Topaz account) |
| Topaz Photo AI | AI photo denoise, sharpen and upscale | https://www.topazlabs.com/downloads |

The Topaz casks were disabled on 2026-09-27, and their replacements may not be covered by your license, so install these two from Topaz's site.

### Utils

```bash
./appsetup/install-utils.sh
```

| App | Homebrew name | What it does |
|---|---|---|
| 1Password | `1password` | Password manager: fills passwords and passkeys in the browser |
| Macs Fan Control | `macs-fan-control` | Shows temperatures and sets fan speeds, like raising the fan curve during long renders or games |
| Vorssaint | `vorssaint` | A menu bar toolkit: keep-awake, system monitor and a per-app volume mixer |

Install by hand ([install-utils.md](appsetup/install-utils.md)):

| App | What it does | Where to get it |
|---|---|---|
| iStat Menus 7 | System stats (CPU, memory, network, sensors) in the menu bar (paid, already purchased) | App Store: https://apps.apple.com/app/id6499559693. Not the `istat-menus` cask, which your App Store license won't unlock |
| OS Cleaner Pro | Finds and clears junk files and caches | App Store: https://apps.apple.com/app/id1084211765 |
| Send Anywhere | Sends files between devices with a 6-digit key | https://send-anywhere.com/ or `brew install --cask send-anywhere` |

App Store apps can also be installed from the command line with `mas` (`brew install mas`, then `mas install <id>`). Sign in to the App Store app first.

## Clone all projects

```bash
~/projects/MACSETUP-M1/clone-projects.sh
```

It does the following:

1. Installs the Xcode Command Line Tools (for `git`) if they're missing.
2. Checks that this Mac can reach GitHub over SSH. If it can't, it creates an `ed25519` key, copies the public key to your clipboard and opens GitHub's "New SSH key" page. It waits until you've added the key.
3. Creates `~/projects` if it doesn't exist and clones every repo listed below into it.
4. Optionally recreates each project's gitignored `.env` files. Paths and timings are written automatically. Secrets are asked for one at a time.

Options:

- `--skip-env`: only clone, don't create any `.env` files.
- `PROJECTS_DIR=~/somewhere ./clone-projects.sh`: clone somewhere other than `~/projects`.

Running the script again is safe. Folders that already exist and `.env` files that already exist are left alone. That means you can skip the secrets the first time and run it again once you have them.

Secret prompts are hidden while you type. You can press Enter to leave a value blank and fill it in later by editing the file. When several files share a value, like the TeeJutsu Shipmojo keys, you're asked for it only once. Every `.env` file is written with `600` permissions.

## Set up Claude

`claudesetup/setup-claude.sh` sets up Claude Desktop and Claude Code. Run it after `clone-projects.sh`, because two of the MCP servers belong to a single project folder.

```bash
~/projects/MACSETUP-M1/claudesetup/setup-claude.sh
```

It does the following:

1. Installs Claude Desktop (`claude`) and Claude Code (`claude-code`) with Homebrew, plus `uv` and `node`, which the MCP servers and desktop extensions run on.
2. Adds the Claude Code settings you're used to (Opus with 1M context, skipped permission warnings) to `~/.claude/settings.json`. Settings you already have win. If anything changes, the old file is kept as `settings.json.bak`.
3. Adds the `anthropics/skills` and `alirezarezvani/claude-skills` plugin marketplaces and installs `document-skills` and `example-skills`.
4. Adds the MCP servers:

   | Server | Where | Notes |
   |---|---|---|
   | fli-flights | all projects | Google Flights through `fli-mcp`, installed with `uv tool install 'flights[mcp]'`. INR, cheapest first. |
   | kiwi-flights | all projects | `https://mcp.kiwi.com`, no sign-in |
   | supabase | all projects | Read-only, project `mwmaxzznfwwmnmjlgybo` |
   | atlassian | tee_jutsu_v1 | |
   | vercel | teejutsu-admin-console | |

5. Copies your own skills (`codebase-refactor`, `find-flight`, `privatepdf-e2e-tests`) and the `/pleasurism` command from [claudesetup/](claudesetup/) into `~/.claude`. Installs the public `find-skills` and `remotion-best-practices` skills with `npx skills`.
6. Opens Claude Desktop and lists what you have to do in the app.

Options:

- `--skip-desktop`: Claude Code only.
- `--skip-code`: Claude Desktop only.

Running it again is safe. Anything that's already installed or configured is left alone.

### Done by hand

These belong to your account or this Mac, so the script can't set them up:

- **Sign in** to Claude Desktop and Claude Code.
- **Connectors** (Gmail, Google Drive, Slack, Claude Docs, ...) come back with your claude.ai account. Reconnect any that show "Connect" under Settings → Connectors.
- **MCP sign-ins.** In Claude Code, run `/mcp` and sign in to supabase, atlassian and vercel.
- **Desktop extensions.** In Claude Desktop, go to Settings → Extensions and install Filesystem (allow `~/projects/PrivatePdf`) and Blender. Blender only works while Blender is running with its MCP add-on enabled.
- **Claude in Chrome.** Install the extension from [claude.ai/chrome](https://claude.ai/chrome) and pair it with the app. The script offers to open the page.

The CapCut MCP from the old Mac isn't restored, because its source folder (`~/projects/try-capcut`) is gone.

If you change a skill in `~/.claude/skills`, copy it back into `claudesetup/skills/` so the next Mac gets it.

## Repos

| Folder | Repo |
|---|---|
| MACSETUP-M1 | rishabghosh/MacSetup-M1 |
| Blender-Utilis | rishabghosh/Blender-Utils |
| FabricFuser | rishabghosh/Fabric-Fuser |
| PrivatePdf | rishabghosh/PrivatePdf |
| ScreenGridOverlay | rishabghosh/ScreenGridOverlay-ChromeExtension |
| canva-bulk-template | rishabghosh/Canva-Generator-Utils |
| delete-x-posts | rishabghosh/delete-x-posts |
| excel_image_mapper | rishabghosh/excel-image-mapper |
| holehe | megadose/holehe (public, cloned over HTTPS) |
| image_product_mapper | rishabghosh/Image-Look-A-Like |
| job-finder | rishabghosh/job-finder |
| learning | rishabghosh/learning-n-experiments |
| placeit_bulk_mockup_extension | rishabghosh/PlaceIt-Automation-Utils |
| regroup-images | rishabghosh/File-Regroup-Utils |
| rename_drive_images | rishabghosh/rename-drive-images |
| rishab-cv | rishabghosh/CV |
| tee_jutsu_v1 | arnabghs/tee_jutsu_v1 (you need collaborator access) |
| teejutsu-admin-console | rishabghosh/TeeJutsu-Admin-Console |
| vma | voices-minds-action/vision-platform (you need org access) |

## Secrets required

### To clone

- **A GitHub SSH key** added to your GitHub account. The script walks you through creating one. Whatever passphrase you choose is saved in the macOS keychain.
- **A second SSH key for vma**, `~/.ssh/id_ed25519_voices_mind_saction`. `voices-minds-action/vision-platform` is reached through a different GitHub account, so it uses its own key. You can copy the key over from your old Mac, or let the script create a new one and add it to that account. The clone remembers the key (`core.sshCommand`), so later pulls and pushes use it too.
- **Collaborator access to `arnabghs/tee_jutsu_v1`.** It belongs to another account, so its clone fails until you've been granted access.

### For the `.env` files

The tables only list the values the script asks for. The rest of each file (paths, timeouts, ratios, API base URLs) is filled in automatically.

**FabricFuser** (`frontend/.env.local`)

| Variable | Where to get it |
|---|---|
| `API_KEY` | Google Gemini API key, from Google AI Studio |

**rename_drive_images** (`.env`)

| Variable | Where to get it |
|---|---|
| `API_KEY` | Google Cloud API key with the Drive API enabled, from Google Cloud Console → Credentials |

**tee_jutsu_v1** (`.env.dev` for `npm run dev`, `.env.local` for local and Playwright runs)

| Variable | File | Where to get it |
|---|---|---|
| `PUBLIC_SUPABASE_URL` / `SUPABASE_SERVER_URL` | both | Supabase → Project Settings → API (the same URL goes in both variables) |
| `PUBLIC_SUPABASE_PUBLISHABLE_KEY` | both | Supabase → Project Settings → API keys |
| `SUPABASE_PROJECT_ID` | .env.dev | Supabase project ref (only needed to run migrations) |
| `SUPABASE_DB_PASSWORD` | .env.dev | Supabase database password (only needed to run migrations) |
| `SUPABASE_ACCESS_TOKEN` | .env.dev | Supabase → Account → Access Tokens (only needed to run migrations) |
| `SUPABASE_SERVICE_ROLE_KEY` | .env.dev | Supabase → Project Settings → API keys (secret) |
| `SHIPMOJO_PUBLIC_KEY` / `SHIPMOJO_PRIVATE_KEY` | both | Shipmojo dashboard → API settings |
| `SHIPMOJO_PICKUP_PINCODE` / `SHIPMOJO_WAREHOUSE_ID` | both | Shipmojo dashboard → warehouse |
| `RAZORPAY_KEY_ID` / `PUBLIC_RAZORPAY_KEY_ID` | .env.dev | Razorpay dashboard → API Keys (the same value goes in both) |
| `RAZORPAY_KEY_SECRET` | .env.dev | Razorpay dashboard → API Keys |
| `RAZORPAY_WEBHOOK_SECRET` | .env.dev | Razorpay dashboard → Webhooks |
| `TEST_USER_EMAIL` / `TEST_USER_PASSWORD` / `TEST_USER_FIRST_NAME` / `TEST_USER_LAST_NAME` | .env.local | The Playwright test account |
| `TEST_REFRESH_TOKEN` | .env.local | `npm run test:setup:local` in the repo |

`.env.dev` and `.env.local` point at different Supabase projects, so the script asks for the URL and publishable key separately for each file.

**teejutsu-admin-console** (`.env.local`)

| Variable | Where to get it |
|---|---|
| `NEXT_PUBLIC_SUPABASE_URL` | Supabase → Project Settings → API |
| `NEXT_PUBLIC_SUPABASE_ANON_KEY` | Supabase → Project Settings → API keys |
| `SUPABASE_SERVICE_ROLE_KEY`, `SUPABASE_PROJECT_ID`, `SUPABASE_DB_PASSWORD`, `SUPABASE_ACCESS_TOKEN` | Same values as tee_jutsu_v1 `.env.dev`, asked for once |
| `ADMIN_EMAILS` | Comma-separated list of admin login emails |
| `SHIPMOJO_PUBLIC_KEY`, `SHIPMOJO_PRIVATE_KEY`, `SHIPMOJO_PICKUP_PINCODE`, `SHIPMOJO_WAREHOUSE_ID` | Same values as tee_jutsu_v1, asked for once |
| `SHIPMOJO_DEFAULT_COURIER` | Shipmojo courier to default to (can be blank) |
| `GOOGLE_CLIENT_ID` / `GOOGLE_CLIENT_SECRET` | Google Cloud Console → Credentials → OAuth client |
| `GOOGLE_REFRESH_TOKEN` | OAuth refresh token for the Drive account |
| `GOOGLE_DRIVE_FOLDER_ID` | The ID in the Drive folder's URL |
| `CRON_SECRET` | Any random string, e.g. from `openssl rand -hex 32` |

**vma** (`.env`)

| Variable | Where to get it |
|---|---|
| `PUBLIC_SUPABASE_URL` | Supabase → Project Settings → API |
| `PUBLIC_SUPABASE_ANON_KEY` | Supabase → Project Settings → API keys |
| `SUPABASE_SERVICE_ROLE_KEY` | Supabase → Project Settings → API keys (secret) |

### No secrets needed

- **FabricFuser** `backend/.env`, **image_product_mapper**, **placeit_bulk_mockup_extension** and **regroup-images**: only paths and timings, written automatically. Paths point at `~/Downloads`, so change them if your files live elsewhere.
- **PrivatePdf**: works with the committed `.env.development`. Production builds also need `VITE_CORS_PROXY_SECRET`; see the PrivatePdf README.
- All other projects need no `.env` file.

## Not cloned or restored

- Local data that isn't in git, such as excel_image_mapper's `input/` and `extracted_images/`. Copy it over by hand.
- Git stashes. They stay on the old machine, so apply or commit them before you switch.

## Mac settings

`settings/capture-settings.sh` saves the old Mac's settings, and `settings/restore-settings.sh` puts them back on the new one. It covers macOS system settings, shell dotfiles, iTerm2, WebStorm, other JetBrains IDEs, VS Code and Cursor, browsers (Chrome, Brave, Edge, Firefox, Safari) and the preferences of every app in `/Applications`.

On the old Mac:

```bash
./settings/capture-settings.sh
```

- This repo is public, so the capture is split in two:
  - [settings/saved/](settings/saved/), in the repo: settings without secrets. That's System Settings (Dock, Finder, keyboard, trackpad, menu bar, shortcuts), Quick Actions, shell and git dotfiles, iTerm2, WebStorm and other JetBrains settings (options, keymaps, code styles, colours, templates, plugin list), VS Code and Cursor settings and extensions, and each browser profile's extensions and custom search engines. Commit it after a capture.
  - `~/MacSettingsBackup` (and a `.zip` next to it), outside the repo: everything personal. That's bookmarks, browser preferences, the preferences of every app in `/Applications`, fonts, text replacements, `~/.ssh/config`, `~/.aws/config`, `~/.npmrc`, WebStorm's workspaces and scratches, and JetBrains files with accounts or recent projects. Copy that folder to the new Mac yourself. `BACKUP_DIR=/Volumes/USB/settings ./settings/capture-settings.sh` writes it somewhere else.
- Before a file goes in the repo, it's checked for secrets: API keys and tokens (`sk-…`, `ghp_…`, `AKIA…`, `xox…`, JWTs), private keys, passwords in URLs, and lines like `API_KEY=…` or `"token": "…"`. A file that has one goes to `~/MacSettingsBackup` instead, and the capture lists it. Plists lose recent files and folders, file bookmarks, and any key named like a token, password or licence.
- Passwords, cookies, browser history and IDE login tokens are left out of both.
- Safari's bookmarks are only saved when your terminal app has Full Disk Access (System Settings → Privacy & Security → Full Disk Access).

On the new Mac, after the apps are installed:

```bash
./settings/restore-settings.sh
```

- It restores the settings in `settings/saved` together with `~/MacSettingsBackup`. Without the private backup, only the repo's settings come back. Pass a folder to use a private backup somewhere else.
- It asks about each part (system settings, dotfiles, iTerm2, ...) in turn. `--yes` restores everything without asking.
- An app's settings are only restored for apps that are installed and closed, so run it from Terminal rather than iTerm2.
- Anything it replaces is saved first to `<backup folder>/undo-<time>`, so you can copy it back.
- IntelliJ IDEA, IntelliJ IDEA CE and PyCharm get your WebStorm settings (keymaps, code styles, colours, options) and plugins when the backup has none of their own. WebStorm-only plugins, such as the JavaScript ones, may not install in IDEA CE.

### WebStorm

`appsettings/webstorm/` saves all of WebStorm's settings, not just the options: keymaps, code styles, colour schemes, live and file templates, scratches, per-project workspaces and tasks, database drivers, `webstorm.vmoptions`, the AI agents it has set up, its macOS preferences and the list of installed plugins. Caches, logs, usage statistics, the settings-sync repo, login tokens and licence keys stay behind; sign in to your JetBrains account to activate.

`capture-settings.sh` and `restore-settings.sh` run these scripts for you. The settings without secrets go to `settings/saved/apps/webstorm` and the rest (workspaces, scratches, AI history, plugin files, macOS preferences) to `~/MacSettingsBackup/apps/webstorm`. To refresh or restore only WebStorm:

```bash
./appsettings/webstorm/capture.sh
```

```bash
./appsettings/webstorm/restore.sh
```

- `capture.sh --with-plugins` also copies the plugin files themselves (over 1 GB with the AI plugins), for plugins that aren't on the JetBrains Marketplace. Without it, `restore.sh` reinstalls the plugins from the list.
- The settings go into whichever WebStorm version is installed on the new Mac. Keep WebStorm closed while `restore.sh` runs.

## Useful commands

[useful-commands.md](useful-commands.md) has handy commands from the old Mac's shell history, like trimming and resizing every PNG in a folder with ImageMagick.

## Testing the scripts

`tests/run.sh` runs shellcheck and the tests for every script in a Docker container. Docker Desktop has to be running. The first run builds a ~100 MB image (about 30 s). After that a run takes about 20 s.

```bash
tests/run.sh
```

Nothing is installed, cloned or downloaded. `brew`, `git`, `ssh`, `claude`, `uv`, `npx`, `open` and the other commands the scripts call are replaced by stubs in [tests/stubs](tests/stubs). Each stub only logs what it was asked to do, and the tests check that log. The container has no network, mounts the repo read-only, gives each test an empty home folder, and uses bash 3.2 like macOS. Prompts are answered through a pseudo-terminal, so the checklist, hidden secret prompts and the `.env` answers are tested too.

- `tests/run.sh apps`: only the test files whose name contains `apps` (also `clone`, `claude`, `settings`). This skips shellcheck.
- `tests/run.sh --shell`: open a shell in the test image.

What it can't cover: real Homebrew installs, the macOS installer windows, and GitHub sign-in. To check those, run the scripts on a fresh Mac or a macOS VM.
