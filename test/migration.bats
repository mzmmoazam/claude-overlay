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

@test "migrates legacy databricks-overlay.json to provider-overlay.json" {
  mkdir -p .claude
  echo '{"env":{"ANTHROPIC_MODEL":"test"}, "mcpServers":{}}' > .claude/databricks-overlay.json

  run "$CLAUDE_OVERLAY" status
  [ "$status" -eq 0 ]

  # Old file should be gone, new file should exist
  [ ! -f ".claude/databricks-overlay.json" ]
  [ -f ".claude/provider-overlay.json" ]
}

@test "migrates legacy .disabled files" {
  mkdir -p .claude
  echo '{"env":{"ANTHROPIC_MODEL":"test"}}' > .claude/settings.local.json.disabled
  echo '{"mcpServers":{"tavily":{"type":"stdio","command":"npx"}}}' > .mcp.json.disabled

  run "$CLAUDE_OVERLAY" status
  [ "$status" -eq 0 ]

  # Disabled files should be gone
  [ ! -f ".claude/settings.local.json.disabled" ]
  [ ! -f ".mcp.json.disabled" ]

  # Content should be in active files
  [ -f ".claude/settings.local.json" ]
  [ -f ".mcp.json" ]
}

@test "legacy migration preserves existing settings" {
  mkdir -p .claude
  echo '{"permissions":{"allow":["Bash(custom)"]}}' > .claude/settings.local.json
  echo '{"env":{"ANTHROPIC_MODEL":"test"}}' > .claude/settings.local.json.disabled

  run "$CLAUDE_OVERLAY" status
  [ "$status" -eq 0 ]

  # Both the existing and migrated content should be present
  python3 -c "
import json
d = json.load(open('.claude/settings.local.json'))
assert 'Bash(custom)' in d['permissions']['allow']
assert d['env']['ANTHROPIC_MODEL'] == 'test'
"
}
