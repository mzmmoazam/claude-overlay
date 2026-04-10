#!/usr/bin/env bash
# Shared test setup for claude-overlay bats tests

# Create an isolated test environment
setup_test_env() {
  TEST_HOME="$(mktemp -d)"
  TEST_PROJECT="$TEST_HOME/test-project"
  mkdir -p "$TEST_PROJECT"
  mkdir -p "$TEST_HOME/.config/claude-overlay"

  export HOME="$TEST_HOME"
  export XDG_CONFIG_HOME="$TEST_HOME/.config"

  # Find the repo root relative to test dir
  REPO_ROOT="$(cd "$(dirname "$BATS_TEST_FILENAME")/.." && pwd)"
  CLAUDE_OVERLAY="$REPO_ROOT/bin/claude-overlay"
  ENGINE_PY="$REPO_ROOT/lib/engine.py"
  PRESET_DIR="$REPO_ROOT/lib/presets"

  # Make the binary find lib/ correctly by symlinking
  mkdir -p "$TEST_HOME/.local/lib/claude-overlay/presets"
  cp "$ENGINE_PY" "$TEST_HOME/.local/lib/claude-overlay/engine.py"
  cp "$PRESET_DIR"/*.json "$TEST_HOME/.local/lib/claude-overlay/presets/" 2>/dev/null || true
  mkdir -p "$TEST_HOME/.local/bin"
  cp "$CLAUDE_OVERLAY" "$TEST_HOME/.local/bin/claude-overlay"
  chmod +x "$TEST_HOME/.local/bin/claude-overlay"

  # Use the local copy
  CLAUDE_OVERLAY="$TEST_HOME/.local/bin/claude-overlay"

  cd "$TEST_PROJECT"
}

teardown_test_env() {
  cd /
  rm -rf "$TEST_HOME"
}

# Write a minimal config file for testing
write_test_config() {
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
      "haiku_model": "databricks-claude-haiku-4-5",
      "custom_headers": "x-databricks-use-coding-agent-mode: true"
    }
  },
  "mcp_servers": {
    "tavily": {
      "type": "stdio",
      "command": "npx",
      "args": ["-y", "tavily-mcp@0.3.1"],
      "env": {"TAVILY_API_KEY": "env:TAVILY_API_KEY"}
    },
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

# Set required env vars for testing
set_test_env_vars() {
  export DATABRICKS_TOKEN="dapi-test-token-12345"
  export TAVILY_API_KEY="tvly-test-key-12345"
}

# Write an OpenRouter config for provider-agnostic testing
write_test_config_openrouter() {
  local config_dir="$TEST_HOME/.config/claude-overlay"
  mkdir -p "$config_dir"
  cat > "$config_dir/config.json" <<'EOF'
{
  "version": 1,
  "default_provider": "openrouter",
  "providers": {
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
    "tavily": {
      "type": "stdio",
      "command": "npx",
      "args": ["-y", "tavily-mcp@0.3.1"],
      "env": {"TAVILY_API_KEY": "env:TAVILY_API_KEY"}
    },
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

set_test_env_vars_openrouter() {
  export OPENROUTER_API_KEY="sk-or-test-key-12345"
  export TAVILY_API_KEY="tvly-test-key-12345"
}
