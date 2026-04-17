# Changelog

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
