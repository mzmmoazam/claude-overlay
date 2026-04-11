# Security Policy

## Supported Versions

| Version | Supported          |
|---------|--------------------|
| 0.2.x   | :white_check_mark: |
| < 0.2   | :x:                |

## How claude-overlay Handles Secrets

- API tokens are stored in `~/.config/claude-overlay/config.json` with `chmod 600` permissions
- Tokens are recommended to use `env:VARIABLE_NAME` syntax, so the actual secret lives in the environment, not on disk
- The `export` command automatically sanitizes raw tokens before output
- Project overlay files (`.claude/settings.local.json`) are added to `.gitignore` during setup

## Reporting a Vulnerability

If you discover a security vulnerability, please report it responsibly:

1. **Do NOT open a public issue**
2. Email: **mzmmoazam@gmail.com** with subject line `[claude-overlay security]`
3. Include:
   - Description of the vulnerability
   - Steps to reproduce
   - Potential impact
4. You will receive a response within 72 hours

We will coordinate a fix and disclosure timeline with you. Credit will be given in the release notes unless you prefer to remain anonymous.
