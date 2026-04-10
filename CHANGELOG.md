# Changelog

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
