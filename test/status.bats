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

@test "status shows 'not set up' with no overlay" {
  run "$CLAUDE_OVERLAY" status
  [ "$status" -eq 0 ]
  [[ "$output" == *"not set up"* ]]
}

@test "status shows ENABLED after setup" {
  "$CLAUDE_OVERLAY" setup -y >/dev/null 2>&1
  run "$CLAUDE_OVERLAY" status
  [ "$status" -eq 0 ]
  [[ "$output" == *"ENABLED"* ]]
}

@test "status shows DISABLED after disable" {
  "$CLAUDE_OVERLAY" setup -y >/dev/null 2>&1
  "$CLAUDE_OVERLAY" disable >/dev/null 2>&1
  run "$CLAUDE_OVERLAY" status
  [ "$status" -eq 0 ]
  [[ "$output" == *"DISABLED"* ]]
}

@test "status works without config file" {
  rm -f "$TEST_HOME/.config/claude-overlay/config.json"
  run "$CLAUDE_OVERLAY" status
  [ "$status" -eq 0 ]
}
