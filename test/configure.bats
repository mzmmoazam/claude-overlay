#!/usr/bin/env bats

load test_helper

setup() {
  setup_test_env
  # Don't write config — configure creates it
  set_test_env_vars
}

teardown() {
  teardown_test_env
}

@test "configure creates config for databricks provider" {
  printf '1\nhttps://test.cloud.databricks.com/serving-endpoints/anthropic\nenv:DATABRICKS_TOKEN\n1\n\n' | \
    "$CLAUDE_OVERLAY" configure
  [ -f "$TEST_HOME/.config/claude-overlay/config.json" ]
  python3 -c "
import json
d = json.load(open('$TEST_HOME/.config/claude-overlay/config.json'))
assert d['default_provider'] == 'databricks'
assert d['providers']['databricks']['base_url'] == 'https://test.cloud.databricks.com/serving-endpoints/anthropic'
assert d['providers']['databricks']['auth_token'] == 'env:DATABRICKS_TOKEN'
assert d['providers']['databricks']['model'] == 'databricks-claude-opus-4-6'
assert d['providers']['databricks']['custom_headers'] == 'x-databricks-use-coding-agent-mode: true'
"
}

@test "configure creates config for openrouter provider" {
  printf '2\nenv:OPENROUTER_API_KEY\n1\n\n' | \
    "$CLAUDE_OVERLAY" configure
  [ -f "$TEST_HOME/.config/claude-overlay/config.json" ]
  python3 -c "
import json
d = json.load(open('$TEST_HOME/.config/claude-overlay/config.json'))
assert d['default_provider'] == 'openrouter'
assert d['providers']['openrouter']['base_url'] == 'https://openrouter.ai/api'
assert d['providers']['openrouter']['model'] == 'anthropic/claude-opus-4.6'
"
}

@test "configure creates config for litellm provider" {
  printf '3\nhttp://localhost:4000\nenv:LITELLM_MASTER_KEY\n\n\n\n\n1\n\n' | \
    "$CLAUDE_OVERLAY" configure
  [ -f "$TEST_HOME/.config/claude-overlay/config.json" ]
  python3 -c "
import json
d = json.load(open('$TEST_HOME/.config/claude-overlay/config.json'))
assert d['default_provider'] == 'litellm'
assert d['providers']['litellm']['base_url'] == 'http://localhost:4000'
"
}

@test "configure creates config for cloudflare provider" {
  printf '4\nmy-account-123\nmy-gateway\nenv:ANTHROPIC_API_KEY\n\n1\n\n' | \
    "$CLAUDE_OVERLAY" configure
  [ -f "$TEST_HOME/.config/claude-overlay/config.json" ]
  python3 -c "
import json
d = json.load(open('$TEST_HOME/.config/claude-overlay/config.json'))
assert d['default_provider'] == 'cloudflare'
assert d['providers']['cloudflare']['base_url'] == 'https://gateway.ai.cloudflare.com/v1/my-account-123/my-gateway/anthropic'
assert d['providers']['cloudflare']['model'] == 'claude-sonnet-4-6'
"
}

@test "configure creates config for bedrock-gateway provider" {
  printf '5\nhttps://bedrock-gw.corp.example.com\nenv:BEDROCK_GATEWAY_TOKEN\n1\n\n' | \
    "$CLAUDE_OVERLAY" configure
  [ -f "$TEST_HOME/.config/claude-overlay/config.json" ]
  python3 -c "
import json
d = json.load(open('$TEST_HOME/.config/claude-overlay/config.json'))
assert d['default_provider'] == 'bedrock-gateway'
assert d['providers']['bedrock-gateway']['model'] == 'us.anthropic.claude-opus-4-6-v1'
"
}

@test "configure creates config for custom provider" {
  printf '6\nhttps://my-proxy.example.com/v1\nenv:MY_TOKEN\nmy-model\n\n\n\n\n1\n\n' | \
    "$CLAUDE_OVERLAY" configure
  [ -f "$TEST_HOME/.config/claude-overlay/config.json" ]
  python3 -c "
import json
d = json.load(open('$TEST_HOME/.config/claude-overlay/config.json'))
assert d['default_provider'] == 'custom'
assert d['providers']['custom']['base_url'] == 'https://my-proxy.example.com/v1'
assert d['providers']['custom']['model'] == 'my-model'
"
}

@test "configure with duckduckgo-only MCP" {
  printf '2\nenv:OPENROUTER_API_KEY\n2\n' | \
    "$CLAUDE_OVERLAY" configure
  python3 -c "
import json
d = json.load(open('$TEST_HOME/.config/claude-overlay/config.json'))
assert 'duckduckgo' in d['mcp_servers'], 'duckduckgo should be present'
assert 'tavily' not in d['mcp_servers'], 'tavily should not be present'
"
}

@test "configure with skip MCP" {
  printf '2\nenv:OPENROUTER_API_KEY\n3\n' | \
    "$CLAUDE_OVERLAY" configure
  python3 -c "
import json
d = json.load(open('$TEST_HOME/.config/claude-overlay/config.json'))
assert d['mcp_servers'] == {}, 'mcp_servers should be empty'
"
}

@test "configure sets file permissions to 600" {
  printf '2\nenv:OPENROUTER_API_KEY\n1\n\n' | \
    "$CLAUDE_OVERLAY" configure
  local perms
  perms=$(python3 -c "import os,sys; print(oct(os.stat(sys.argv[1]).st_mode)[-3:])" "$TEST_HOME/.config/claude-overlay/config.json")
  [ "$perms" = "600" ]
}

@test "configure shows existing config info" {
  # Create an existing config
  write_test_config
  # Configure a second provider (openrouter), skipping MCP
  printf '2\nenv:OPENROUTER_API_KEY\n3\n' | "$CLAUDE_OVERLAY" configure
  run bash -c "printf '2\nenv:OPENROUTER_API_KEY\n3\n' | '$CLAUDE_OVERLAY' configure"
  [ "$status" -eq 0 ]
  [[ "$output" == *"Existing config"* ]]
}

@test "configure rejects invalid provider selection" {
  run bash -c "printf '99\n' | '$CLAUDE_OVERLAY' configure"
  [ "$status" -ne 0 ]
  [[ "$output" == *"Invalid selection"* ]]
}

@test "configure rejects bare '1' as a raw token (menu-mistake guard)" {
  # Regression: users typed '1' thinking they were picking the menu option.
  # Simulate: no DATABRICKS_TOKEN set, pick databricks (1), url, choose
  # paste-token (2), then type '1' (should be rejected), then a real token.
  unset DATABRICKS_TOKEN
  output=$(printf '1\nhttps://test.cloud.databricks.com/serving-endpoints/anthropic\n2\n1\nreal-token-abcdef12345\n1\n\n' | \
    "$CLAUDE_OVERLAY" configure 2>&1)
  [[ "$output" == *"doesn't look like a real token"* ]]
  python3 -c "
import json
d = json.load(open('$TEST_HOME/.config/claude-overlay/config.json'))
assert d['providers']['databricks']['auth_token'] == 'real-token-abcdef12345', d['providers']['databricks']['auth_token']
"
}

@test "configure accepts env: reference directly at the menu prompt" {
  # When env var is not set, the menu still accepts a pasted env:VAR reference
  # as a shortcut (length > 4, starts with env:).
  unset DATABRICKS_TOKEN
  printf '1\nhttps://test.cloud.databricks.com/serving-endpoints/anthropic\nenv:DATABRICKS_TOKEN\n1\n\n' | \
    "$CLAUDE_OVERLAY" configure
  python3 -c "
import json
d = json.load(open('$TEST_HOME/.config/claude-overlay/config.json'))
assert d['providers']['databricks']['auth_token'] == 'env:DATABRICKS_TOKEN'
"
}

@test "configure auto-detects DATABRICKS_HOST" {
  export DATABRICKS_HOST="https://my-workspace.cloud.databricks.com"
  output=$(printf '1\n\nenv:DATABRICKS_TOKEN\n1\n\n' | "$CLAUDE_OVERLAY" configure 2>&1)
  python3 -c "
import json
d = json.load(open('$TEST_HOME/.config/claude-overlay/config.json'))
assert 'my-workspace.cloud.databricks.com' in d['providers']['databricks']['base_url']
"
}
