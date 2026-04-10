#!/usr/bin/env bats

load test_helper

setup() {
  setup_test_env
  write_test_config
  set_test_env_vars
}

teardown() {
  teardown_test_env
}

@test "setup creates overlay file" {
  run "$CLAUDE_OVERLAY" setup -y
  [ "$status" -eq 0 ]
  [ -f ".claude/provider-overlay.json" ]
}

@test "setup creates settings.local.json" {
  run "$CLAUDE_OVERLAY" setup -y
  [ "$status" -eq 0 ]
  [ -f ".claude/settings.local.json" ]
}

@test "setup creates .mcp.json" {
  run "$CLAUDE_OVERLAY" setup -y
  [ "$status" -eq 0 ]
  [ -f ".mcp.json" ]
}

@test "setup updates .gitignore" {
  run "$CLAUDE_OVERLAY" setup -y
  [ "$status" -eq 0 ]
  [ -f ".gitignore" ]
  grep -qF ".claude/settings.local.json" .gitignore
  grep -qF ".mcp.json" .gitignore
  grep -qF ".claude/provider-overlay.json" .gitignore
}

@test "setup preserves existing settings" {
  mkdir -p .claude
  echo '{"permissions":{"allow":["Bash(echo hello)"]}}' > .claude/settings.local.json

  run "$CLAUDE_OVERLAY" setup -y
  [ "$status" -eq 0 ]

  # Original permission should still be there
  python3 -c "
import json
d = json.load(open('.claude/settings.local.json'))
assert 'Bash(echo hello)' in d['permissions']['allow']
assert 'ANTHROPIC_MODEL' in d['env']
"
}

@test "setup preserves existing MCP servers" {
  echo '{"mcpServers":{"custom-server":{"type":"stdio","command":"echo"}}}' > .mcp.json

  run "$CLAUDE_OVERLAY" setup -y
  [ "$status" -eq 0 ]

  # Original server should still be there
  python3 -c "
import json
d = json.load(open('.mcp.json'))
assert 'custom-server' in d['mcpServers']
assert 'tavily' in d['mcpServers']
assert 'duckduckgo' in d['mcpServers']
"
}

@test "setup sets file permissions to 600" {
  run "$CLAUDE_OVERLAY" setup -y
  [ "$status" -eq 0 ]

  local perms
  perms=$(python3 -c "import os; print(oct(os.stat('.claude/settings.local.json').st_mode)[-3:])")
  [ "$perms" = "600" ]
}

@test "setup fails without config file" {
  rm -f "$TEST_HOME/.config/claude-overlay/config.json"
  run "$CLAUDE_OVERLAY" setup -y
  [ "$status" -ne 0 ]
  [[ "$output" == *"No config found"* ]]
}

@test "setup fails when env var not set" {
  unset DATABRICKS_TOKEN
  run "$CLAUDE_OVERLAY" setup -y
  [ "$status" -ne 0 ]
  [[ "$output" == *"DATABRICKS_TOKEN"* ]]
}

@test "setup works with openrouter config" {
  # Replace config with OpenRouter variant
  write_test_config_openrouter
  set_test_env_vars_openrouter

  run "$CLAUDE_OVERLAY" setup -y
  [ "$status" -eq 0 ]
  [ -f ".claude/settings.local.json" ]
  [ -f ".mcp.json" ]
  [ -f ".claude/provider-overlay.json" ]

  python3 -c "
import json
s = json.load(open('.claude/settings.local.json'))
assert s['env']['ANTHROPIC_MODEL'] == 'anthropic/claude-opus-4.6'
assert s['env']['ANTHROPIC_BASE_URL'] == 'https://openrouter.ai/api'
m = json.load(open('.mcp.json'))
assert 'tavily' in m['mcpServers']
"
}
