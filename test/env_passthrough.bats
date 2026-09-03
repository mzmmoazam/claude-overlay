#!/usr/bin/env bats

load test_helper

setup() {
  setup_test_env
}

teardown() {
  teardown_test_env
}

@test "provider env block flows to settings.local.json" {
  write_test_config_with_env
  set_test_env_vars_envtest

  run "$CLAUDE_OVERLAY" setup -y
  [ "$status" -eq 0 ]

  python3 -c "
import json
s = json.load(open('.claude/settings.local.json'))
assert s['env']['CLAUDE_CODE_MAX_CONTEXT_TOKENS'] == '131072', s['env']
"
}

@test "preset env default flows through when provider has no env block" {
  # Write a litellm-preset config with NO env block on the provider
  mkdir -p "$TEST_HOME/.config/claude-overlay"
  cat > "$TEST_HOME/.config/claude-overlay/config.json" <<'EOF'
{
  "version": 1,
  "default_provider": "litellm",
  "providers": {
    "litellm": {
      "base_url": "http://127.0.0.1:4000",
      "auth_token": "sk-test",
      "model": "test-model",
      "opus_model": "test-model",
      "sonnet_model": "test-model",
      "haiku_model": "test-model"
    }
  }
}
EOF
  chmod 600 "$TEST_HOME/.config/claude-overlay/config.json"

  run "$CLAUDE_OVERLAY" setup -y
  [ "$status" -eq 0 ]

  python3 -c "
import json
s = json.load(open('.claude/settings.local.json'))
assert s['env'].get('CLAUDE_CODE_MAX_CONTEXT_TOKENS') == '131072', 'preset default should flow'
"
}

@test "provider env overrides preset env on collision" {
  # litellm preset carries CLAUDE_CODE_MAX_CONTEXT_TOKENS=131072
  # Provider overrides to 65536
  mkdir -p "$TEST_HOME/.config/claude-overlay"
  cat > "$TEST_HOME/.config/claude-overlay/config.json" <<'EOF'
{
  "version": 1,
  "default_provider": "litellm",
  "providers": {
    "litellm": {
      "base_url": "http://127.0.0.1:4000",
      "auth_token": "sk-test",
      "model": "test-model",
      "opus_model": "test-model",
      "sonnet_model": "test-model",
      "haiku_model": "test-model",
      "env": {"CLAUDE_CODE_MAX_CONTEXT_TOKENS": "65536"}
    }
  }
}
EOF
  chmod 600 "$TEST_HOME/.config/claude-overlay/config.json"

  run "$CLAUDE_OVERLAY" setup -y
  [ "$status" -eq 0 ]

  python3 -c "
import json
s = json.load(open('.claude/settings.local.json'))
assert s['env']['CLAUDE_CODE_MAX_CONTEXT_TOKENS'] == '65536', 'provider should win'
"
}

@test "hardcoded keys win over env block hijack attempt" {
  # An env block trying to override ANTHROPIC_MODEL must NOT win.
  write_test_config_with_env '{"ANTHROPIC_MODEL": "hijack-attempt", "CLAUDE_CODE_MAX_CONTEXT_TOKENS": "131072"}'
  set_test_env_vars_envtest

  run "$CLAUDE_OVERLAY" setup -y
  [ "$status" -eq 0 ]

  python3 -c "
import json
s = json.load(open('.claude/settings.local.json'))
assert s['env']['ANTHROPIC_MODEL'] == 'test-model', 'hardcoded key must win, got: ' + s['env']['ANTHROPIC_MODEL']
assert s['env']['CLAUDE_CODE_MAX_CONTEXT_TOKENS'] == '131072', 'non-colliding env key still flows'
"
}

@test "empty-string values dropped from emitted env" {
  write_test_config_with_env '{"CLAUDE_CODE_MAX_CONTEXT_TOKENS": "131072", "EMPTY_VAR": ""}'
  set_test_env_vars_envtest

  run "$CLAUDE_OVERLAY" setup -y
  [ "$status" -eq 0 ]

  python3 -c "
import json
s = json.load(open('.claude/settings.local.json'))
assert 'EMPTY_VAR' not in s['env'], 'empty-string value should be dropped'
assert s['env']['CLAUDE_CODE_MAX_CONTEXT_TOKENS'] == '131072'
"
}

@test "env:VAR token resolution works inside env block" {
  write_test_config_with_env '{"MY_SECRET": "env:MY_INJECTED_SECRET"}'
  set_test_env_vars_envtest
  export MY_INJECTED_SECRET="resolved-value-xyz"

  run "$CLAUDE_OVERLAY" setup -y
  [ "$status" -eq 0 ]

  python3 -c "
import json
s = json.load(open('.claude/settings.local.json'))
assert s['env']['MY_SECRET'] == 'resolved-value-xyz', s['env']
"
}

@test "env:VAR unset fails cleanly with the same error path as auth tokens" {
  write_test_config_with_env '{"NEEDS_SECRET": "env:UNSET_VAR_NAME_XYZ"}'
  set_test_env_vars_envtest
  unset UNSET_VAR_NAME_XYZ

  run "$CLAUDE_OVERLAY" setup -y
  [ "$status" -ne 0 ]
  [[ "$output" == *"UNSET_VAR_NAME_XYZ"* ]]
}

@test "disable removes managed env keys but preserves user-set keys" {
  write_test_config_with_env
  set_test_env_vars_envtest

  run "$CLAUDE_OVERLAY" setup -y
  [ "$status" -eq 0 ]

  # User adds an unrelated key by hand
  python3 -c "
import json
s = json.load(open('.claude/settings.local.json'))
s['env']['MY_UNRELATED_VAR'] = 'preserve-me'
json.dump(s, open('.claude/settings.local.json', 'w'), indent=2)
"

  run "$CLAUDE_OVERLAY" disable -y
  [ "$status" -eq 0 ]

  python3 -c "
import json, os
assert os.path.exists('.claude/settings.local.json'), \
    'file must survive because MY_UNRELATED_VAR was set'
if os.path.exists('.claude/settings.local.json'):
    s = json.load(open('.claude/settings.local.json'))
    assert 'CLAUDE_CODE_MAX_CONTEXT_TOKENS' not in s.get('env', {}), 'managed key should be gone'
    assert s.get('env', {}).get('MY_UNRELATED_VAR') == 'preserve-me', 'user key should survive'
# Or the file may have been removed entirely if it only held overlay keys
# — but that would be wrong here because we set MY_UNRELATED_VAR, so the
# file must still exist.
"
}

@test "config without env block behaves identically (regression fence)" {
  # Use the existing test config which has NO env block on the provider
  # and NO preset env (databricks preset has none).
  write_test_config
  set_test_env_vars

  run "$CLAUDE_OVERLAY" setup -y
  [ "$status" -eq 0 ]

  # Assert the exact same 8 keys the old code emitted (7 non-empty + the
  # DISABLE_EXPERIMENTAL_BETAS flag). No extras.
  python3 -c "
import json
s = json.load(open('.claude/settings.local.json'))
env = s['env']
expected_keys = {
    'ANTHROPIC_MODEL',
    'ANTHROPIC_BASE_URL',
    'ANTHROPIC_AUTH_TOKEN',
    'ANTHROPIC_DEFAULT_OPUS_MODEL',
    'ANTHROPIC_DEFAULT_SONNET_MODEL',
    'ANTHROPIC_DEFAULT_HAIKU_MODEL',
    'ANTHROPIC_CUSTOM_HEADERS',
    'CLAUDE_CODE_DISABLE_EXPERIMENTAL_BETAS',
}
assert set(env.keys()) == expected_keys, sorted(set(env.keys()) ^ expected_keys)
"
}
