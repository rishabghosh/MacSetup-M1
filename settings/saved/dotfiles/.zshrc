# Added by Antigravity
export PATH="$HOME/.antigravity/antigravity/bin:$PATH"

# Path to your Oh My Zsh installation.
export ZSH="$HOME/.oh-my-zsh"

# You can change this to any theme in $ZSH/themes.
ZSH_THEME="robbyrussell"

# Add more plugins here if you want (example: zsh-autosuggestions zsh-syntax-highlighting)
plugins=(git)

source $ZSH/oh-my-zsh.sh

export CLAUDE_CODE_MAX_OUTPUT_TOKENS=100000
# >>> devops-learning setup >>>
# ~/.local/bin holds tools installed outside Homebrew (tflint).
export PATH="$HOME/.local/bin:$PATH"

# Tab completion needs compinit loaded before the tool completions below.
autoload -Uz compinit && compinit -i

# kubectl / helm / kind completion: tab-complete resource names, flags and
# pod names, which saves a lot of typing and typos.
command -v kubectl >/dev/null && source <(kubectl completion zsh)
command -v helm    >/dev/null && source <(helm completion zsh)
command -v kind    >/dev/null && source <(kind completion zsh)

# AWS CLI completion: tab-complete services and subcommands.
command -v aws_completer >/dev/null && complete -C "$(command -v aws_completer)" aws

# Terraform completion: tab-complete subcommands.
autoload -U +X bashcompinit && bashcompinit
command -v terraform >/dev/null && complete -o nospace -C "$(command -v terraform)" terraform

# Short aliases. 'k' is the universal kubectl shorthand, and completion is wired to it too.
alias k=kubectl
compdef k=kubectl 2>/dev/null
alias tf=terraform
alias kgp='kubectl get pods'
alias kga='kubectl get all'
alias kev='kubectl get events --sort-by=.lastTimestamp'

# Terraform plugin cache: providers (the AWS provider is ~500MB) are
# downloaded once and reused by every project, instead of once per folder.
export TF_PLUGIN_CACHE_DIR="$HOME/.terraform.d/plugin-cache"

# Default AWS region, so you don't have to pass --region every time.
# Change it to the region closest to you.
export AWS_DEFAULT_REGION="${AWS_DEFAULT_REGION:-ap-south-1}"

# Don't send AWS CLI output to a pager (less). Output stays in the terminal and pipes cleanly to jq.
export AWS_PAGER=""
# <<< devops-learning setup <<<
