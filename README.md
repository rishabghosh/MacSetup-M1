# MACSETUP-M1

Setup scripts for a fresh Apple Silicon Mac.

## Install apps

`apps/` has one script per category: Office, Coding, Entertainment, Gaming, Editing and Utils. Each one lists that category's Homebrew apps with a description of each, lets you pick all of them or only some (or pass `--all`), and installs Homebrew first if it's missing. Apps that come from a website or the App Store are listed in [apps/install.md](apps/install.md) with their download links.

```bash
./MACSETUP-M1/apps/install-coding.sh
```

## Clone all projects

`clone-projects.sh` does the following:

1. Installs the Xcode Command Line Tools (for `git`) if they're missing.
2. Checks that this Mac can reach GitHub over SSH. If it can't, it creates an `ed25519` key, copies the public key to your clipboard and opens GitHub's "New SSH key" page. It waits until you've added the key.
3. Creates `~/projects` if it doesn't exist and clones every repo listed below into it.
4. Optionally recreates each project's gitignored `.env` files. Paths and timings are written automatically. Secrets are asked for one at a time.

```bash
git clone https://github.com/rishabghosh/MacSetup-M1.git ~/projects/MACSETUP-M1
```

```bash
~/projects/MACSETUP-M1/clone-projects.sh
```

This first clone uses HTTPS because the Mac has no SSH key yet. If the repo is private, git asks for your GitHub username and a personal access token instead of your password. You can also download the repo as a ZIP from GitHub and unzip it to `~/projects/MACSETUP-M1`.

Options:

- `--skip-env`: only clone, don't create any `.env` files.
- `PROJECTS_DIR=~/somewhere ./clone-projects.sh`: clone somewhere other than `~/projects`.

Running the script again is safe. Folders that already exist and `.env` files that already exist are left alone. That means you can skip the secrets the first time and run it again once you have them.

Secret prompts are hidden while you type. You can press Enter to leave a value blank and fill it in later by editing the file. When several files share a value, like the TeeJutsu Shipmojo keys, you're asked for it only once. Every `.env` file is written with `600` permissions.

## Set up Claude

`setup-claude.sh` sets up Claude Desktop and Claude Code. Run it after `clone-projects.sh`, because two of the MCP servers belong to a single project folder.

```bash
~/projects/MACSETUP-M1/setup-claude.sh
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

5. Copies your own skills (`codebase-refactor`, `find-flight`, `privatepdf-e2e-tests`) and the `/pleasurism` command from [claude/](claude/) into `~/.claude`. Installs the public `find-skills` and `remotion-best-practices` skills with `npx skills`.
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

If you change a skill in `~/.claude/skills`, copy it back into `claude/skills/` so the next Mac gets it.

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
