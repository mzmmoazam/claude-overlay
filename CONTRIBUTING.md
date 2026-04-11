# Contributing to claude-overlay

Thanks for your interest in improving claude-overlay! Here's how to get started.

## Development Setup

```bash
git clone https://github.com/mzmmoazam/claude-overlay.git
cd claude-overlay
```

The tool consists of two files:
- `bin/claude-overlay` — bash script (CLI, user interaction, routing)
- `lib/engine.py` — Python (JSON manipulation, overlay merge/remove logic)

### Prerequisites

- bash 4+
- python3 >= 3.7
- [bats-core](https://github.com/bats-core/bats-core) (for tests)
- [ShellCheck](https://www.shellcheck.net/) (for linting)

### Local install for development

```bash
# Symlink so changes take effect immediately
ln -sf "$(pwd)/bin/claude-overlay" ~/.local/bin/claude-overlay
```

## Testing

```bash
# Install bats
brew install bats-core  # macOS
# or: sudo apt install bats  # Ubuntu

# Run all tests
make test

# Run a specific test file
bats test/setup.bats

# Run a specific test by name
bats test/setup.bats -f "creates overlay"
```

Tests create isolated temp directories and never touch your real config.

## Linting

```bash
make lint
# Runs: shellcheck bin/claude-overlay install.sh
# Runs: python3 -m py_compile lib/engine.py
```

## Project Structure

```
bin/claude-overlay          # Main CLI script (~1400 lines)
lib/engine.py               # Python engine for JSON operations (~570 lines)
lib/presets/*.json           # Provider preset configs
completions/                # Shell completions (bash, zsh)
test/*.bats                 # Test suite
install.sh                  # curl | bash installer
Makefile                    # Build/install targets
```

## Code Style

- Bash: 2-space indent, functions prefixed with `cmd_` for subcommands
- Python: 4-space indent, PEP 8
- All `py_engine` calls must use `|| true` to prevent `set -e` from killing the script
- File paths passed to embedded Python via `sys.argv`, never via string interpolation

## Release Process

1. Update `VERSION` in `bin/claude-overlay`
2. Update `CHANGELOG.md`
3. Commit and push
4. Tag: `git tag v0.x.0 && git push --tags`
5. CI creates the GitHub release and updates the Homebrew tap automatically

## Reporting Issues

- Run `claude-overlay doctor` first and include the output
- Include your OS, Python version, and install method
- See [SECURITY.md](SECURITY.md) for reporting vulnerabilities
