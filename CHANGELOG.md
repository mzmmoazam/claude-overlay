# Changelog

## [0.4.0] - 2026-09-03

### Added
- Per-provider `env: {}` block in `~/.config/claude-overlay/config.json`. Keys flow into `.claude/settings.local.json` via the existing `setup` / `enable` / `disable` machinery, so switching providers atomically switches their env vars. Motivating case: local-model users (GLM 5.2, Llama 3.1, Mixtral fronted by LiteLLM / vLLM / Ollama) sit at 128k–131k context windows but Claude Code assumes 200k for unknown models and plans auto-compaction accordingly. Without a `CLAUDE_CODE_MAX_CONTEXT_TOKENS` hint the session crashes at ~99k input tokens with a hard `400 ContextWindowExceededError`. The new `env` block lets you thread that value (and any other Claude Code env var) through the overlay's atomic switch machinery.
- LiteLLM preset ships `CLAUDE_CODE_MAX_CONTEXT_TOKENS: "131072"` by default. Overridable per provider.
- README section "Per-provider environment variables" documents the merge order (preset → provider → hardcoded, hardcoded wins on collision), `env:VAR_NAME` token-resolution shortcut for secrets, empty-string drop, and the loopback URL bypass.

### Fixed
- `http://` URL allowlist was hardcoded to provider names `"litellm"` and `"custom"`. Any other name (e.g. `"glm-only"`, `"my-vllm"`) pointing at `http://127.0.0.1` was rejected with `error:insecure_base_url` even though the URL was loopback. Broadened to any provider with a loopback URL (`127.*` / `localhost` / `0.0.0.0` / IPv6 `[::1]`), anchored with a compiled regex so `localhost.run` (a real public HTTP-tunneling service) and `127.dns-name.tld` cannot bypass by prefix-collision.
- `configure` re-run on the same provider full-replaced the provider dict, silently wiping any user-added `env` block or hand-edited `custom_headers`. Now reads the existing provider first and preserves both fields if new values aren't provided. Prevents a UX regression that would have re-introduced the 131k crash the `env` feature exists to prevent.
- Non-object `env` blocks (`env: null`, `env: []`, `env: "string"`) now fail closed with a clean `error:{preset|provider}_env_not_object` line instead of raising a raw Python `TypeError` / `ValueError`. Non-scalar values inside `env` (`env: {"K": null}`, dicts, lists) also fail closed rather than being coerced to strings like `"None"` or `"[1, 2]"` via `str()`. Booleans coerce to lowercase `"true"`/`"false"` (Claude Code convention), not Python's `"True"`/`"False"`.

### Unchanged
- Configs without any `env` block behave identically to v0.3.x — regression-fence test pins byte-equivalent overlay emit.
- Provider names `"litellm"` and `"custom"` with any `http://` URL — still accepted (backward compat).
- Schema `version: 1` — no bump; the feature is additive.

## [0.3.0] - 2026-05-14

### Changed
- Default Opus model bumped from `claude-opus-4-6` to `claude-opus-4-7` across all provider presets (Databricks, OpenRouter, Cloudflare, LiteLLM, Bedrock gateway). Existing configs at `~/.config/claude-overlay/config.json` are untouched — only new `configure` runs pick up 4.7. To upgrade an existing project, re-run `claude-overlay configure` and accept the new default, or edit `model` / `opus_model` manually.
- README examples updated to reflect 4.7 defaults.

### Unchanged
- Sonnet 4.6 and Haiku 4.5 — no newer versions exist yet.

## [0.2.4] - 2026-04-17

### Fixed
- `configure` auth-token prompt was ambiguous when the env var wasn't set: the code printed a `1) env:… 2) Paste token` menu but then asked for the token value directly. Users (reasonably) typed `1` expecting to pick the menu option, and the CLI happily stored `1` as a raw auth token. `prompt_auth_token` now drives a real menu, rejects single-digit / yes-no / <10-char placeholders, and accepts a directly-pasted `env:VAR` reference as a shortcut. Thanks to the team members who flagged this.

## [0.2.3] - 2026-04-17

### Fixed
- MCP package versions were hallucinated and didn't exist on npm. Fixed `tavily-mcp@0.3.1` → `tavily-mcp@0.2.18` and `duckduckgo-mcp-server@1.1.0` → `duckduckgo-mcp-server@0.1.2`. This would have caused `npx` to fail on first `setup`.

## [0.2.2] - 2026-04-14

### Fixed
- Homebrew install broken by `resolve_dir` not handling relative symlinks. Homebrew links `/opt/homebrew/bin/claude-overlay` to `../Cellar/claude-overlay/<ver>/bin/claude-overlay`; the old code tried to `cd` to that relative path from the user's cwd instead of from the symlink's own directory, producing `cd: ../Cellar/claude-overlay/0.2.1/bin: No such file or directory`. `resolve_dir` now anchors relative `readlink` output to the symlink's parent directory. (Thanks Amir for the patch.)
- Shellcheck SC2088 warning on a debug message containing a leading `~/.claude.json` — reworded so the tilde isn't at the start of the string. CI lint is green again.

## [0.2.1] - 2026-04-14

### Fixed
- Claude Code v2+ welcome/login picker appearing after `setup` on fresh machines. Claude Code gates its interactive start on `~/.claude.json` having `hasCompletedOnboarding: true` and `theme` set — these are checked before project env vars are loaded, so the overlay's endpoint/token were never reached. `setup` and `enable` now stamp both keys non-destructively (existing values are preserved; `theme` is only set if the user hasn't already picked one).

### Added
- `doctor` — new first-run-gate check reports `~/.claude.json` state and surfaces a fix hint if either key is missing.
- `engine.py` — new actions `ensure_onboarding` and `check_onboarding`.

## [0.2.0] - 2026-04-11

### Added
- `doctor` command — validate full setup chain with 10 health checks
- `switch` command — switch active provider without re-running configure
- `export` command — export shareable config (secrets auto-sanitized)
- `import` command — import config from file with merge support
- `setup --dry-run` flag — preview what setup will do without writing files
- Shell completions for bash and zsh
- Multi-provider config support — configure merges instead of overwriting
- Homebrew tap distribution (`brew install mzmmoazam/claude-overlay/claude-overlay`)

### Changed
- `configure` now merges new provider into existing config instead of overwriting
- Overwrite guard changed from blocking prompt to informational display

### Fixed
- Shell injection prevention — file paths passed via sys.argv instead of string interpolation
- `set -e` compatibility — all `py_engine` calls use `|| true` for consistent error handling

## [0.1.0] - 2026-04-09

### Added
- Initial release
- `setup` command — create provider overlay for a project
- `disable` command — surgically remove overlay keys, preserve other settings
- `enable` command — merge overlay keys back alongside other settings
- `status` command — show current project state with managed vs. other breakdown
- `configure` command — interactive first-time credential setup
- `self-update` command — update to latest GitHub release
- Overlay architecture — non-destructive merge/remove of provider-specific config
- Databricks provider preset with Claude Opus 4.6, Sonnet 4.6, Haiku 4.5
- Tavily + DuckDuckGo MCP servers for web search
- Legacy migration from old `.disabled` file approach
- Legacy migration from `databricks-overlay.json` to `provider-overlay.json`
- Atomic file writes with `chmod 600` for files containing secrets
- `env:` token resolution — read secrets from environment variables
- curl | bash installer
- Makefile for manual installation
- bats test suite
- CI with ShellCheck + tests on macOS and Ubuntu
