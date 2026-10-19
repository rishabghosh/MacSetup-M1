#!/usr/bin/env bash
#
# Install the coding apps and command-line tools that come from Homebrew.
# Apps installed from a website or the App Store are listed in install.md.
#
# Run it to pick from a list, or pass --all to install everything.
# Safe to re-run: anything already installed is skipped.
#
# "Used:" notes come from ~/.zsh_history and the commands run in past Claude
# Code sessions, checked on 2026-10-20.

. "$(dirname "$0")/lib.sh"

cask visual-studio-code "VS Code, Microsoft's code editor. Adds the \`code\` command." \
  "Used: code ~/.zshrc (2 times in shell history)"
cask cursor "Cursor, an AI-first fork of VS Code. Adds the \`cursor\` command." \
  "Used: cursor . (once in shell history)"
cask webstorm "WebStorm, JetBrains' IDE for JavaScript and TypeScript. Adds the \`webstorm\` command." \
  "Used: 35 times in shell history to open folders, e.g. webstorm rishab-cv, webstorm ~/.claude/skills/"
cask iterm2 "iTerm2, a Terminal replacement with split panes, tabs and profiles." \
  "e.g. split a pane with Cmd+D, search scrollback with Cmd+F"
cask docker-desktop "Docker Desktop: runs containers locally and adds the \`docker\` command. kind needs it." \
  "Used: docker info, docker run postgres:15-alpine for a throwaway database, docker ps (Claude sessions)"
cask xquartz "XQuartz, an X11 window server for Linux/Unix GUI apps. Asks for your password." \
  "Not run directly. Needed by apps that open X11 windows (e.g. Wine, older GUI tools)"
cask claude-code "Claude Code, Anthropic's coding agent in the terminal (\`claude\`)." \
  "Used: 155 times in shell history, e.g. claude --dangerously-skip-permissions --continue"
cask android-platform-tools "adb and fastboot, to talk to an Android phone over USB." \
  "Used: adb devices (4 times in shell history)"
cask session-manager-plugin "AWS Session Manager plugin, for shelling into EC2 without SSH." \
  "Not run yet. e.g. aws ssm start-session --target i-0abc123"

formula git "Version control." \
  "Used: 220 times in shell history (mostly add, push, commit, log, stash) plus the oh-my-zsh aliases gst 95, gco 63, gc 55, gl 31"
formula git-lfs "Git Large File Storage, keeps big binaries out of the git history." \
  "Not run yet. e.g. git lfs track \"*.blend\""
formula nvm "Node Version Manager. Needs a few lines in ~/.zshrc (Homebrew prints them)." \
  "Node v22.14.0 is installed through it. e.g. nvm install 22 && nvm use 22"
formula pyenv "Python version manager. Needs a few lines in ~/.zshrc (Homebrew prints them)." \
  "Not run directly yet. e.g. pyenv install 3.12 && pyenv global 3.12"
formula python@3.10 "Python 3.10, as \`python3.10\`." \
  "Not run directly, and nothing installed depends on it. e.g. python3.10 -m venv .venv"
formula awscli "AWS command line (\`aws\`)." \
  "Set up for the DevOps learning plan (Oct 2026), not run yet. e.g. aws sts get-caller-identity, aws s3 ls"
formula hashicorp/tap/terraform "Terraform, infrastructure as code. Your ~/.zshrc aliases it to \`tf\`." \
  "Set up for the DevOps learning plan (Oct 2026), not run yet. e.g. tf init && tf plan"
formula kubernetes-cli "kubectl, the Kubernetes command line. Aliased to k, kgp, kga and kev in ~/.zshrc." \
  "Used: kubectl cluster-info --context kind-learn, kubectl get nodes -o wide (Claude session, Oct 2026)"
formula kubectx "kubectx and kubens, to switch Kubernetes clusters and namespaces quickly." \
  "Not run yet. e.g. kubectx kind-learn, kubens kube-system"
formula kind "Kubernetes in Docker: a local cluster for learning and testing." \
  "Used: kind create cluster --name learn, kind get clusters, kind delete cluster --name learn (Claude session, Oct 2026)"
formula helm "Helm, the Kubernetes package manager." \
  "Only checked during the DevOps learning setup so far. e.g. helm repo add bitnami https://charts.bitnami.com/bitnami"
formula k9s "A terminal UI for browsing and managing a Kubernetes cluster." \
  "Not run yet. e.g. k9s --context kind-learn"
formula jq "Slice and filter JSON on the command line." \
  "Used: curl -fsSL https://api.github.com/repos/<repo>/releases/latest | jq (Claude sessions)"
formula yq "jq for YAML files." \
  "Not run yet. e.g. yq '.spec.replicas' deployment.yaml"
formula tree "Prints a folder as a tree." \
  "Used: tree (once in shell history)"
formula opencode "OpenCode, an open-source AI coding agent in the terminal." \
  "Used: opencode (7 times in shell history)"
formula claude-code-router "\`ccr\`, runs Claude Code against other model providers." \
  "Used: 33 times in shell history, mostly ccr code; also ccr model, ccr start"
formula ffmpeg "Convert, cut and compress video and audio." \
  "Not run directly yet. e.g. ffmpeg -i in.mov -c:v libx264 -crf 23 out.mp4"
formula imagemagick "Edit images from the command line (\`magick\`)." \
  "Used: magick in.png -resize 1920x1080 -gravity center -background none -extent 1920x1080 out.png (shell); magick identify, crop and resize for the CV photo (Claude sessions)"
formula img2pdf "Turn images into a PDF without re-compressing them." \
  "Not run yet. e.g. img2pdf page-*.jpg -o scan.pdf"
formula poppler "PDF tools: pdftoppm, pdftotext, pdfinfo, pdfimages." \
  "Used a lot in Claude sessions on the CV: pdftoppm 50 times (e.g. pdftoppm -png -r 90 -f 1 -l 1 cv.pdf page), pdftotext 32, pdfinfo 7"
formula innoextract "Unpacks Windows Inno Setup installers (.exe), e.g. GOG game installers, without Windows." \
  "Not run yet. e.g. innoextract setup_game.exe"
formula hey "HTTP load generator, for quick load tests." \
  "Not run yet. e.g. hey -n 1000 -c 50 http://localhost:3000/"
formula fio "Disk read/write benchmark." \
  "Used: pen drive benchmarks (Claude sessions, Jul 2026), e.g. fio --name=rand4k --directory=/Volumes/MOU-2 --size=256M --bs=4k --rw=randrw"
formula cpulimit "Caps how much CPU a running process can use." \
  "Not run yet. e.g. cpulimit -p <pid> -l 50"
formula argp-standalone "A C library with no command of its own, needed to compile some Linux tools on macOS." \
  "Probably installed to build f3 for the pen drive tests. Nothing installed depends on it now"

run_installer "Coding" "$@"
