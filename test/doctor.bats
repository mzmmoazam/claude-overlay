#!/usr/bin/env bats

load test_helper

setup() {
  setup_test_env
}

teardown() {
  teardown_test_env
}

@test "doctor passes with valid config and env vars" {
  write_test_config
  set_test_env_vars
  run "$CLAUDE_OVERLAY" doctor
  [ "$status" -eq 0 ]
  [[ "$output" == *"✓"*"python3"* ]]
  [[ "$output" == *"✓"*"npx"* ]]
  [[ "$output" == *"✓"*"Config:"* ]]
  [[ "$output" == *"✓"*"Provider: databricks"* ]]
  [[ "$output" == *"✓"*"Endpoint:"* ]]
  [[ "$output" == *"✓"*"Auth:"*"→ set"* ]]
}

@test "doctor fails when config missing" {
  # No config written
  set_test_env_vars
  run "$CLAUDE_OVERLAY" doctor
  [ "$status" -eq 1 ]
  [[ "$output" == *"✗"*"No config"* ]]
}

@test "doctor fails when auth env var not set" {
  write_test_config
  # Set Tavily but NOT DATABRICKS_TOKEN
  export TAVILY_API_KEY="tvly-test-key"
  unset DATABRICKS_TOKEN 2>/dev/null || true
  run "$CLAUDE_OVERLAY" doctor
  [ "$status" -eq 1 ]
  [[ "$output" == *"✗"*"DATABRICKS_TOKEN"*"NOT SET"* ]]
}

@test "doctor warns when Tavily key not set" {
  write_test_config
  export DATABRICKS_TOKEN="dapi-test-token"
  unset TAVILY_API_KEY 2>/dev/null || true
  run "$CLAUDE_OVERLAY" doctor
  # Should still pass (warning, not error)
  [ "$status" -eq 0 ]
  [[ "$output" == *"⚠"*"TAVILY_API_KEY"*"NOT SET"* ]]
}

@test "doctor reports overlay status in project dir" {
  write_test_config
  set_test_env_vars
  # Set up a project with overlay
  run "$CLAUDE_OVERLAY" setup -y
  [ "$status" -eq 0 ]

  run "$CLAUDE_OVERLAY" doctor
  [ "$status" -eq 0 ]
  [[ "$output" == *"✓"*"Overlay:"* ]]
  [[ "$output" == *"✓"*"Status: ENABLED"* ]]
}

@test "doctor reports disabled overlay" {
  write_test_config
  set_test_env_vars
  run "$CLAUDE_OVERLAY" setup -y
  [ "$status" -eq 0 ]
  run "$CLAUDE_OVERLAY" disable
  [ "$status" -eq 0 ]

  run "$CLAUDE_OVERLAY" doctor
  [ "$status" -eq 0 ]
  [[ "$output" == *"⚠"*"DISABLED"* ]]
}

@test "doctor reports no overlay when not in project" {
  write_test_config
  set_test_env_vars
  run "$CLAUDE_OVERLAY" doctor
  [ "$status" -eq 0 ]
  [[ "$output" == *"ℹ"*"No overlay"* ]]
}

@test "doctor handles config with invalid JSON" {
  set_test_env_vars
  local config_dir="$TEST_HOME/.config/claude-overlay"
  mkdir -p "$config_dir"
  echo "not valid json {{{" > "$config_dir/config.json"
  run "$CLAUDE_OVERLAY" doctor
  [ "$status" -eq 1 ]
  [[ "$output" == *"✗"*"malformed JSON"* ]]
}
