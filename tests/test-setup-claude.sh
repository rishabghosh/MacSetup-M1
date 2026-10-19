# Tests for setup-claude.sh.

# The two project folders that get their own MCP server.
make_projects() {
  export PROJECTS_DIR="$HOME/projects"
  mkdir -p "$PROJECTS_DIR/tee_jutsu_v1" "$PROJECTS_DIR/teejutsu-admin-console"
}

test_claude_full_setup() {
  make_projects
  run_tty "n" ./setup-claude.sh
  expect_status 0
  expect_no_out "Couldn't"

  expect_log "brew install --cask claude"
  expect_log "brew install --cask claude-code"

  local settings="$HOME/.claude/settings.json"
  expect_eq "$(json "$settings" 'd["model"]')" "opus[1m]" "model"
  expect_eq "$(json "$settings" 'd["skipDangerousModePermissionPrompt"]')" True "skipDangerousModePermissionPrompt"
  expect_no_path "$settings.bak"

  expect_log "claude plugin marketplace add anthropics/skills"
  expect_log "claude plugin marketplace add alirezarezvani/claude-skills"
  expect_log "claude plugin install document-skills@anthropic-agent-skills"
  expect_log "claude plugin install example-skills@anthropic-agent-skills"

  local cfg="$HOME/.claude.json"
  expect_file "$HOME/.local/bin/fli-mcp"
  expect_eq "$(json "$cfg" 'd["mcpServers"]["fli-flights"]["command"]')" "$HOME/.local/bin/fli-mcp" "fli-flights command"
  expect_eq "$(json "$cfg" 'd["mcpServers"]["fli-flights"]["env"]["FLI_MCP_DEFAULT_CURRENCY"]')" INR "fli-flights currency"
  expect_eq "$(json "$cfg" 'd["mcpServers"]["kiwi-flights"]["url"]')" "https://mcp.kiwi.com" "kiwi-flights url"
  expect_eq "$(json "$cfg" 'd["mcpServers"]["supabase"]["url"]')" \
    "https://mcp.supabase.com/mcp?project_ref=mwmaxzznfwwmnmjlgybo&read_only=true" "supabase url"
  expect_eq "$(json "$cfg" 'd["projects"]["'"$PROJECTS_DIR"'/tee_jutsu_v1"]["mcpServers"]["atlassian"]["type"]')" sse "atlassian type"
  expect_eq "$(json "$cfg" 'd["projects"]["'"$PROJECTS_DIR"'/teejutsu-admin-console"]["mcpServers"]["vercel"]["url"]')" \
    "https://mcp.vercel.com" "vercel url"

  local skill
  for skill in codebase-refactor find-flight privatepdf-e2e-tests find-skills remotion-best-practices; do
    expect_dir "$HOME/.claude/skills/$skill"
  done
  expect_file "$HOME/.claude/commands/pleasurism.md"

  expect_log "open -a Claude"
  expect_no_log "open https://claude.ai/chrome"
}

test_claude_rerun_changes_nothing() {
  make_projects
  run_tty "n" ./setup-claude.sh
  : > "$STUB_LOG"
  run_tty "n" ./setup-claude.sh
  expect_status 0
  expect_no_log_match "brew install"
  expect_no_log_match " add"
  expect_no_log_match "plugin install"
  expect_no_log_match "uv tool install"
  expect_no_log_match "npx"
  expect_out "already set up"
  expect_out "atlassian (tee_jutsu_v1): already added"
}

test_claude_keeps_existing_settings() {
  mkdir -p "$HOME/.claude"
  printf '{"model": "sonnet", "theme": "dark"}' > "$HOME/.claude/settings.json"
  run ./setup-claude.sh --skip-desktop
  expect_status 0
  local settings="$HOME/.claude/settings.json"
  expect_eq "$(json "$settings" 'd["model"]')" sonnet "model"
  expect_eq "$(json "$settings" 'd["theme"]')" dark "theme"
  expect_eq "$(json "$settings" 'd["skipWorkflowUsageWarning"]')" True "skipWorkflowUsageWarning"
  expect_eq "$(cat "$settings.bak" 2>/dev/null)" '{"model": "sonnet", "theme": "dark"}' "settings.json.bak"
}

test_claude_keeps_existing_skills() {
  mkdir -p "$HOME/.claude/skills/find-flight"
  echo mine > "$HOME/.claude/skills/find-flight/SKILL.md"
  run ./setup-claude.sh --skip-desktop
  expect_out "find-flight: already there"
  expect_eq "$(cat "$HOME/.claude/skills/find-flight/SKILL.md")" mine "find-flight/SKILL.md"
}

test_claude_installs_uv_and_node() {
  without uv npx
  run ./setup-claude.sh --skip-desktop
  expect_log "brew install uv"
  expect_log "brew install node"
}

test_claude_opens_chrome_page() {
  run_tty "y" ./setup-claude.sh --skip-code
  expect_status 0
  expect_log "open https://claude.ai/chrome"
}

test_claude_skip_desktop() {
  run ./setup-claude.sh --skip-desktop
  expect_status 0
  expect_no_log "brew install --cask claude"
  expect_log "brew install --cask claude-code"
  expect_no_log "open -a Claude"
}

test_claude_skip_code() {
  run_tty "n" ./setup-claude.sh --skip-code
  expect_status 0
  expect_log "brew install --cask claude"
  expect_no_log "brew install --cask claude-code"
  expect_no_path "$HOME/.claude/settings.json"
  expect_no_log_match "claude "
  expect_log "open -a Claude"
}

test_claude_unknown_option() {
  run ./setup-claude.sh --bogus
  expect_status 1
  expect_out "Unknown option: --bogus"
}

test_claude_needs_homebrew() {
  without brew
  run ./setup-claude.sh
  expect_status 1
  expect_out "Homebrew is not installed."
}

test_claude_needs_xcode_tools() {
  export XCODE_MISSING=1
  run ./setup-claude.sh
  expect_status 1
  expect_log "xcode-select --install"
}

test_claude_needs_claude_on_path() {
  without claude
  run ./setup-claude.sh --skip-desktop
  expect_status 1
  expect_out "The claude command isn't on PATH."
}

test_claude_warns_about_missing_projects() {
  run ./setup-claude.sh --skip-desktop
  expect_status 0
  expect_out "atlassian: $HOME/projects/tee_jutsu_v1 doesn't exist."
  expect_out "vercel: $HOME/projects/teejutsu-admin-console doesn't exist."
}
