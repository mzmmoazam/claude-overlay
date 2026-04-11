# Changelog

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
