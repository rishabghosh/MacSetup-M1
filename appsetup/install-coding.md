# Coding apps

[All categories](install.md)

## Homebrew script

```bash
./install-coding.sh
```

Installs VS Code, Cursor, WebStorm, IntelliJ IDEA, IntelliJ IDEA CE, PyCharm, iTerm2, Docker Desktop, XQuartz, Claude, ChatGPT, Claude Code, Android platform tools and the AWS Session Manager plugin. It also installs 26 command-line tools, such as git, nvm, pyenv, terraform, kubectl, helm, ffmpeg and imagemagick.

After the Homebrew installs, it offers two more steps:

- **node-lts** installs the latest LTS Node with nvm and makes it the default.
- **playwright-browsers** installs Playwright's browsers with `npx playwright install`.

Each step is skipped if it's already installed.

Things to know:

- It asks for your password once, for XQuartz.
- IntelliJ IDEA CE is discontinued, so Homebrew warns about it and keeps it at 2025.2. IntelliJ IDEA and PyCharm both have a free tier now.
- `settings/restore-settings.sh` gives IntelliJ IDEA, IDEA CE and PyCharm your WebStorm settings. Run it after this script.
- When it finishes, follow the setup lines Homebrew prints for `nvm` and `pyenv`. They need a few lines added to `~/.zshrc`. Until you add them, `node` and `npm` only work inside the script.

## Install by hand

| App | From | Where to get it | Homebrew instead |
|---|---|---|---|
| Codex (desktop app) | ⬇️ Website | https://openai.com/codex/ | None. The `codex-app` cask was discontinued on 2026-07-12, and Homebrew points to `chatgpt` instead, which this script also installs |
