#!/usr/bin/env bats

load test_helper

setup() {
  setup_test_env
  write_test_config
  set_test_env_vars
  # Run setup first to create the overlay
  "$CLAUDE_OVERLAY" setup -y >/dev/null 2>&1
}

teardown() {
  teardown_test_env
}

@test "disable removes overlay env vars" {
  run "$CLAUDE_OVERLAY" disable
  [ "$status" -eq 0 ]

  # Settings file should not have ANTHROPIC_MODEL
  if [ -f ".claude/settings.local.json" ]; then
    python3 -c "
import json
d = json.load(open('.claude/settings.local.json'))
assert 'ANTHROPIC_MODEL' not in d.get('env', {})
"
  fi
}

@test "disable preserves non-overlay settings" {
  # Add a custom permission before disable
  python3 -c "
import json
d = json.load(open('.claude/settings.local.json'))
d['permissions']['allow'].append('Bash(echo test)')
with open('.claude/settings.local.json', 'w') as f:
    json.dump(d, f, indent=2)
"

  run "$CLAUDE_OVERLAY" disable
  [ "$status" -eq 0 ]

  # Custom permission should survive
  python3 -c "
import json
d = json.load(open('.claude/settings.local.json'))
assert 'Bash(echo test)' in d['permissions']['allow']
"
}

@test "disable removes MCP servers" {
  run "$CLAUDE_OVERLAY" disable
  [ "$status" -eq 0 ]

  # .mcp.json should not exist (no other servers)
  [ ! -f ".mcp.json" ]
}

@test "disable preserves non-overlay MCP servers" {
  # Add a custom MCP server
  python3 -c "
import json
d = json.load(open('.mcp.json'))
d['mcpServers']['custom'] = {'type': 'stdio', 'command': 'echo'}
with open('.mcp.json', 'w') as f:
    json.dump(d, f, indent=2)
"

  run "$CLAUDE_OVERLAY" disable
  [ "$status" -eq 0 ]

  # Custom server should survive, overlay servers gone
  python3 -c "
import json
d = json.load(open('.mcp.json'))
assert 'custom' in d['mcpServers']
assert 'tavily' not in d['mcpServers']
assert 'duckduckgo' not in d['mcpServers']
"
}

@test "enable restores overlay after disable" {
  "$CLAUDE_OVERLAY" disable >/dev/null 2>&1

  run "$CLAUDE_OVERLAY" enable
  [ "$status" -eq 0 ]

  # Overlay env vars should be back
  python3 -c "
import json
d = json.load(open('.claude/settings.local.json'))
assert 'ANTHROPIC_MODEL' in d['env']
"

  # MCP servers should be back
  python3 -c "
import json
d = json.load(open('.mcp.json'))
assert 'tavily' in d['mcpServers']
assert 'duckduckgo' in d['mcpServers']
"
}

@test "disable is idempotent" {
  "$CLAUDE_OVERLAY" disable >/dev/null 2>&1
  run "$CLAUDE_OVERLAY" disable
  [ "$status" -eq 0 ]
  [[ "$output" == *"already disabled"* ]]
}

@test "enable is idempotent" {
  run "$CLAUDE_OVERLAY" enable
  [ "$status" -eq 0 ]
  [[ "$output" == *"already enabled"* ]]
}

@test "enable fails without overlay" {
  rm -f ".claude/provider-overlay.json"
  run "$CLAUDE_OVERLAY" enable
  [ "$status" -ne 0 ]
  [[ "$output" == *"No overlay found"* ]]
}

@test "full cycle: setup → disable → enable preserves custom settings" {
  # Add custom settings
  python3 -c "
import json
d = json.load(open('.claude/settings.local.json'))
d['permissions']['allow'].append('Bash(custom)')
d['custom_key'] = 'custom_value'
with open('.claude/settings.local.json', 'w') as f:
    json.dump(d, f, indent=2)
"
  python3 -c "
import json
d = json.load(open('.mcp.json'))
d['mcpServers']['my-server'] = {'type': 'stdio', 'command': 'test'}
with open('.mcp.json', 'w') as f:
    json.dump(d, f, indent=2)
"

  # Disable
  "$CLAUDE_OVERLAY" disable >/dev/null 2>&1

  # Verify custom settings survived
  python3 -c "
import json
d = json.load(open('.claude/settings.local.json'))
assert 'Bash(custom)' in d['permissions']['allow']
assert d['custom_key'] == 'custom_value'
"
  python3 -c "
import json
d = json.load(open('.mcp.json'))
assert 'my-server' in d['mcpServers']
"

  # Enable
  "$CLAUDE_OVERLAY" enable >/dev/null 2>&1

  # Verify everything is present
  python3 -c "
import json
d = json.load(open('.claude/settings.local.json'))
assert 'Bash(custom)' in d['permissions']['allow']
assert 'ANTHROPIC_MODEL' in d['env']
assert d['custom_key'] == 'custom_value'
"
  python3 -c "
import json
d = json.load(open('.mcp.json'))
assert 'my-server' in d['mcpServers']
assert 'tavily' in d['mcpServers']
"
}
