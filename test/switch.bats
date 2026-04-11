#!/usr/bin/env bats

load test_helper

setup() {
  setup_test_env
}

teardown() {
  teardown_test_env
}

# Helper to write a multi-provider config
write_multi_provider_config() {
  local config_dir="$TEST_HOME/.config/claude-overlay"
  mkdir -p "$config_dir"
  cat > "$config_dir/config.json" <<'EOF'
{
  "version": 1,
  "default_provider": "databricks",
  "providers": {
    "databricks": {
      "base_url": "https://test-workspace.cloud.databricks.com/serving-endpoints/anthropic",
      "auth_token": "env:DATABRICKS_TOKEN",
      "model": "databricks-claude-opus-4-6",
      "opus_model": "databricks-claude-opus-4-6",
      "sonnet_model": "databricks-claude-sonnet-4-6",
      "haiku_model": "databricks-claude-haiku-4-5"
    },
    "openrouter": {
      "base_url": "https://openrouter.ai/api",
      "auth_token": "env:OPENROUTER_API_KEY",
      "model": "anthropic/claude-opus-4.6",
      "opus_model": "anthropic/claude-opus-4.6",
      "sonnet_model": "anthropic/claude-sonnet-4.6",
      "haiku_model": "anthropic/claude-haiku-4.5"
    }
  },
  "mcp_servers": {
    "duckduckgo": {
      "type": "stdio",
      "command": "npx",
      "args": ["-y", "duckduckgo-mcp-server@1.1.0"]
    }
  }
}
EOF
  chmod 600 "$config_dir/config.json"
}

@test "switch changes default provider" {
  write_multi_provider_config
  run "$CLAUDE_OVERLAY" switch openrouter
  [ "$status" -eq 0 ]
  [[ "$output" == *"Switched"*"openrouter"* ]]

  # Verify config was updated
  local default
  default=$(python3 -c "import json; print(json.load(open('$TEST_HOME/.config/claude-overlay/config.json'))['default_provider'])")
  [ "$default" = "openrouter" ]
}

@test "switch reports already default" {
  write_multi_provider_config
  run "$CLAUDE_OVERLAY" switch databricks
  [ "$status" -eq 0 ]
  [[ "$output" == *"already"* ]]
}

@test "switch fails for unknown provider" {
  write_multi_provider_config
  run "$CLAUDE_OVERLAY" switch nonexistent
  [ "$status" -eq 1 ]
  [[ "$output" == *"not found"* ]]
}

@test "switch preserves all providers in config" {
  write_multi_provider_config
  run "$CLAUDE_OVERLAY" switch openrouter
  [ "$status" -eq 0 ]

  # Both providers should still exist
  python3 -c "
import json
d = json.load(open('$TEST_HOME/.config/claude-overlay/config.json'))
assert 'databricks' in d['providers'], 'databricks should still exist'
assert 'openrouter' in d['providers'], 'openrouter should still exist'
assert d['default_provider'] == 'openrouter', 'default should be openrouter'
"
}

@test "configure adds provider to existing config" {
  write_test_config
  set_test_env_vars
  # Add openrouter to existing databricks config
  printf '2\nenv:OPENROUTER_API_KEY\n3\n' | \
    "$CLAUDE_OVERLAY" configure

  # Both providers should exist
  python3 -c "
import json
d = json.load(open('$TEST_HOME/.config/claude-overlay/config.json'))
assert 'databricks' in d['providers'], 'databricks should be preserved'
assert 'openrouter' in d['providers'], 'openrouter should be added'
assert d['default_provider'] == 'openrouter', 'default should be the new one'
"
}
