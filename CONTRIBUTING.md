# Contributing

## Development Setup

```bash
git clone https://github.com/mzmmoazam/claude-overlay.git
cd claude-overlay
```

The tool consists of two files:
- `bin/claude-overlay` — bash script (CLI, user interaction, routing)
- `lib/engine.py` — Python (JSON manipulation, overlay merge/remove logic)

## Testing

```bash
# Install bats
brew install bats-core  # macOS
# or: sudo apt install bats  # Ubuntu

# Run all tests
make test

# Run a specific test file
bats test/setup.bats
```

Tests create isolated temp directories and never touch your real config.

## Linting

```bash
make lint
# Runs: shellcheck bin/claude-overlay install.sh
# Runs: python3 -m py_compile lib/engine.py
```

## Release Process

1. Update `VERSION` in `bin/claude-overlay`
2. Update `CHANGELOG.md`
3. Commit and push
4. Tag: `git tag v0.x.0 && git push --tags`
5. CI creates the GitHub release automatically
