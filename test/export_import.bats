#!/usr/bin/env bats

load test_helper

setup() {
  setup_test_env
}

teardown() {
  teardown_test_env
}

@test "export produces valid JSON" {
  write_test_config
  run "$CLAUDE_OVERLAY" export
  [ "$status" -eq 0 ]
  # Should be valid JSON
  echo "$output" | python3 -c "import json,sys; json.load(sys.stdin)"
}

@test "export includes provider and MCP servers" {
  write_test_config
  run "$CLAUDE_OVERLAY" export
  [ "$status" -eq 0 ]
  python3 -c "
import json, sys
d = json.loads(sys.argv[1])
assert 'databricks' in d['providers'], 'should include databricks'
assert d['default_provider'] == 'databricks'
assert 'tavily' in d.get('mcp_servers', {}), 'should include tavily'
" "$output"
}

@test "export sanitizes raw tokens" {
  # Create a config with an inline token (not env: prefixed)
  local config_dir="$TEST_HOME/.config/claude-overlay"
  mkdir -p "$config_dir"
  cat > "$config_dir/config.json" <<'EOF'
{
  "version": 1,
  "default_provider": "custom",
  "providers": {
    "custom": {
      "base_url": "https://proxy.example.com",
      "auth_token": "sk-secret-raw-token-12345",
      "model": "claude-sonnet-4-20250514"
    }
  },
  "mcp_servers": {}
}
EOF
  run "$CLAUDE_OVERLAY" export
  [ "$status" -eq 0 ]
  # Raw token should be replaced
  [[ "$output" != *"sk-secret-raw-token"* ]]
  [[ "$output" == *"env:YOUR_TOKEN_HERE"* ]]
}

@test "import creates config from file" {
  # No existing config
  local import_file="$TEST_HOME/team-config.json"
  cat > "$import_file" <<'EOF'
{
  "version": 1,
  "default_provider": "openrouter",
  "providers": {
    "openrouter": {
      "base_url": "https://openrouter.ai/api",
      "auth_token": "env:OPENROUTER_API_KEY",
      "model": "anthropic/claude-opus-4.6"
    }
  },
  "mcp_servers": {
    "duckduckgo": {
      "type": "stdio",
      "command": "npx",
      "args": ["-y", "duckduckgo-mcp-server@0.1.2"]
    }
  }
}
EOF
  run "$CLAUDE_OVERLAY" import "$import_file"
  [ "$status" -eq 0 ]
  [[ "$output" == *"imported"* ]]

  # Verify config was created
  python3 -c "
import json
d = json.load(open('$TEST_HOME/.config/claude-overlay/config.json'))
assert d['default_provider'] == 'openrouter'
assert 'openrouter' in d['providers']
"
}

@test "import merges with existing config" {
  write_test_config
  local import_file="$TEST_HOME/team-config.json"
  cat > "$import_file" <<'EOF'
{
  "version": 1,
  "default_provider": "openrouter",
  "providers": {
    "openrouter": {
      "base_url": "https://openrouter.ai/api",
      "auth_token": "env:OPENROUTER_API_KEY",
      "model": "anthropic/claude-opus-4.6"
    }
  }
}
EOF
  run "$CLAUDE_OVERLAY" import "$import_file"
  [ "$status" -eq 0 ]

  # Both providers should exist
  python3 -c "
import json
d = json.load(open('$TEST_HOME/.config/claude-overlay/config.json'))
assert 'databricks' in d['providers'], 'existing provider preserved'
assert 'openrouter' in d['providers'], 'imported provider added'
assert d['default_provider'] == 'openrouter', 'default updated to imported'
"
}

@test "import fails on missing file" {
  run "$CLAUDE_OVERLAY" import /nonexistent/file.json
  [ "$status" -eq 1 ]
  [[ "$output" == *"not found"* ]]
}

@test "import fails on invalid JSON" {
  local bad_file="$TEST_HOME/bad.json"
  echo "not json {{{" > "$bad_file"
  run "$CLAUDE_OVERLAY" import "$bad_file"
  [ "$status" -eq 1 ]
}

@test "round-trip: export then import produces working config" {
  write_test_config
  set_test_env_vars

  # Export
  run "$CLAUDE_OVERLAY" export
  [ "$status" -eq 0 ]
  echo "$output" > "$TEST_HOME/exported.json"

  # Clear config
  rm "$TEST_HOME/.config/claude-overlay/config.json"

  # Import
  run "$CLAUDE_OVERLAY" import "$TEST_HOME/exported.json"
  [ "$status" -eq 0 ]

  # Setup should work with imported config
  run "$CLAUDE_OVERLAY" setup -y
  [ "$status" -eq 0 ]
  [ -f ".claude/settings.local.json" ]
}
