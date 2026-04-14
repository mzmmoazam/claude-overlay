# claude-overlay

[![CI](https://github.com/mzmmoazam/claude-overlay/workflows/CI/badge.svg)](https://github.com/mzmmoazam/claude-overlay/actions?query=workflow:CI)
[![License: MIT](https://img.shields.io/badge/license-MIT-blue.svg)](LICENSE)
[![GitHub release](https://img.shields.io/github/release/mzmmoazam/claude-overlay.svg)](https://github.com/mzmmoazam/claude-overlay/releases)
[![macOS](https://img.shields.io/badge/macOS-supported-000000?logo=apple&logoColor=white)](https://github.com/mzmmoazam/claude-overlay)
[![Linux](https://img.shields.io/badge/Linux-supported-FCC624?logo=linux&logoColor=black)](https://github.com/mzmmoazam/claude-overlay)
[![Homebrew](https://img.shields.io/badge/homebrew-tap-FBB040?logo=homebrew&logoColor=white)](https://github.com/mzmmoazam/homebrew-claude-overlay)

Manage project-level [Claude Code](https://docs.anthropic.com/en/docs/claude-code) configuration for custom model providers.

When using Claude Code through a proxy or third-party endpoint — **Databricks**, **Amazon Bedrock**, **OpenRouter**, **LiteLLM**, or others — Anthropic's native WebSearch and WebFetch tools may not work because they rely on Anthropic's own infrastructure. `claude-overlay` solves this by creating a project-level configuration overlay that:

- Routes Claude Code to your custom endpoint
- Replaces native web search with MCP-based alternatives (Tavily + DuckDuckGo)
- Preserves all your existing project settings and MCP servers
- Toggles cleanly between custom provider and native Anthropic modes

## Install

### Homebrew (macOS / Linux)

```bash
brew tap mzmmoazam/claude-overlay
brew install claude-overlay
```

### curl

```bash
curl -fsSL https://raw.githubusercontent.com/mzmmoazam/claude-overlay/main/install.sh | bash
```

### From source

```bash
git clone https://github.com/mzmmoazam/claude-overlay.git
cd claude-overlay && make install
```

**Requirements:** bash, python3 >= 3.7, npx (Node.js)

## Quick Start

```bash
# 1. Configure your provider credentials (one time)
claude-overlay configure

# 2. Set env vars in your shell profile (~/.zshrc or ~/.bashrc)
export DATABRICKS_TOKEN="your-databricks-token"
export TAVILY_API_KEY="your-tavily-api-key"

# 3. Go to a project and set up the overlay
cd your-project
claude-overlay setup

# 4. Verify everything is working
claude-overlay doctor

# 5. Launch Claude Code — it now uses your custom provider + MCP web search
```

## Commands

| Command | Description |
|---------|-------------|
| `claude-overlay configure` | Set up provider credentials (creates `~/.config/claude-overlay/config.json`) |
| `claude-overlay setup` | Create overlay in current project |
| `claude-overlay setup --dry-run` | Preview what setup would do without writing files |
| `claude-overlay disable` | Remove overlay keys, keep other project settings |
| `claude-overlay enable` | Restore overlay keys alongside other settings |
| `claude-overlay status` | Show current project state |
| `claude-overlay switch [provider]` | Switch active provider (multi-provider configs) |
| `claude-overlay export` | Export config for team sharing (stdout) |
| `claude-overlay import <file>` | Import a shared config file |
| `claude-overlay doctor` | Check setup health (config, env vars, project) |
| `claude-overlay self-update` | Update to latest release |
| `claude-overlay --version` | Print version |

## Enable / Disable

A key feature of `claude-overlay` is the ability to **switch between your custom provider and native Anthropic** without losing any project configuration.

### Disabling the overlay

```bash
claude-overlay disable
```

This **surgically removes** only the keys that `claude-overlay` manages:
- Provider env vars (`ANTHROPIC_MODEL`, `ANTHROPIC_BASE_URL`, `ANTHROPIC_AUTH_TOKEN`, etc.)
- MCP web search servers (`tavily`, `duckduckgo`)
- Permission rules for MCP tools and native tool deny rules

Everything else — your custom permissions, other MCP servers, other env vars — is **left untouched**.

After disabling, Claude Code falls back to your global settings (`~/.claude/settings.json`), which typically means direct Anthropic API with native WebSearch/WebFetch.

### Enabling the overlay

```bash
claude-overlay enable
```

This **merges the overlay keys back** into your project config without duplicating anything. Your custom settings remain intact.

### Checking status

```bash
claude-overlay status
```

Shows a complete view of your project's state:

```
Claude Overlay — Project Status
/home/user/my-project

  Provider       ENABLED
  Model          databricks-claude-opus-4-6
  Endpoint       https://my-workspace.cloud.databricks.com/serving-endpoints/anthropic

  Managed MCP servers:
    ● tavily
    ● duckduckgo
  Other MCP servers (untouched):
    ● my-custom-server

  Native tools   denied: WebSearch, WebFetch
  MCP tools      pre-approved: mcp__tavily__tavily_search, mcp__tavily__tavily_research, mcp__duckduckgo__search
  Other allow    2 rule(s)
```

### What gets preserved

```
.claude/settings.local.json     ENABLED           AFTER disable
├── env.ANTHROPIC_MODEL         ✅ overlay        ❌ removed
├── env.ANTHROPIC_BASE_URL      ✅ overlay        ❌ removed
├── env.MY_CUSTOM_VAR           ✅ yours          ✅ kept
├── permissions.deny.WebSearch   ✅ overlay        ❌ removed
├── permissions.allow
│   ├── mcp__tavily__*           ✅ overlay        ❌ removed
│   └── Bash(your custom rule)   ✅ yours          ✅ kept

.mcp.json
├── tavily                       ✅ overlay        ❌ removed
├── duckduckgo                   ✅ overlay        ❌ removed
└── your-custom-server           ✅ yours          ✅ kept
```

### Typical workflow

```bash
# Working with Databricks models
claude-overlay setup         # first time
claude-overlay status        # verify

# Need to switch to direct Anthropic temporarily
claude-overlay disable

# Back to Databricks
claude-overlay enable
```

## Multi-Provider & Team Sharing

### Multiple providers

Run `configure` multiple times to add providers — existing ones are preserved:

```bash
claude-overlay configure    # set up Databricks
claude-overlay configure    # add OpenRouter (Databricks stays)
claude-overlay switch       # interactive: pick which to use
claude-overlay switch openrouter   # or switch directly by name
```

### Team sharing

Export your config (secrets are sanitized to `env:` references) and share with teammates:

```bash
# Person A: export
claude-overlay export > team-overlay.json

# Person B: import and set up
claude-overlay import team-overlay.json
claude-overlay setup
```

### Health check

Run `doctor` to validate your full setup:

```bash
claude-overlay doctor
```

```
  ✓ python3 3.12.0
  ✓ npx available
  ✓ Config: ~/.config/claude-overlay/config.json
  ✓ Config valid JSON
  ✓ Provider: databricks
  ✓ Endpoint: https://workspace.cloud.databricks.com/...
  ✓ Auth: env:DATABRICKS_TOKEN → set
  ✓ Tavily: env:TAVILY_API_KEY → set

  ✓ Overlay: .claude/provider-overlay.json
  ✓ Status: ENABLED
```

## Provider Examples

The config file lives at `~/.config/claude-overlay/config.json`. Below are examples for various providers. Each uses the `env:` prefix for secrets, which reads from environment variables at runtime so credentials never touch disk.

### Databricks Model Serving

Databricks exposes Claude models via the Anthropic Messages API format.

```json
{
  "version": 1,
  "default_provider": "databricks",
  "providers": {
    "databricks": {
      "base_url": "https://YOUR-WORKSPACE.cloud.databricks.com/serving-endpoints/anthropic",
      "auth_token": "env:DATABRICKS_TOKEN",
      "model": "databricks-claude-opus-4-6",
      "opus_model": "databricks-claude-opus-4-6",
      "sonnet_model": "databricks-claude-sonnet-4-6",
      "haiku_model": "databricks-claude-haiku-4-5",
      "custom_headers": "x-databricks-use-coding-agent-mode: true"
    }
  },
  "mcp_servers": {
    "tavily": {
      "type": "stdio",
      "command": "npx",
      "args": ["-y", "tavily-mcp@0.3.1"],
      "env": { "TAVILY_API_KEY": "env:TAVILY_API_KEY" }
    },
    "duckduckgo": {
      "type": "stdio",
      "command": "npx",
      "args": ["-y", "duckduckgo-mcp-server@1.1.0"]
    }
  }
}
```

```bash
export DATABRICKS_TOKEN="dapi..."
export TAVILY_API_KEY="tvly-..."
```

**WebSearch/WebFetch:** ❌ Not available through Databricks. Use MCP servers instead (configured above).

### OpenRouter

[OpenRouter](https://openrouter.ai) aggregates multiple model providers. Claude Code works with the Anthropic first-party provider on OpenRouter.

```json
{
  "version": 1,
  "default_provider": "openrouter",
  "providers": {
    "openrouter": {
      "base_url": "https://openrouter.ai/api",
      "auth_token": "env:OPENROUTER_API_KEY",
      "model": "anthropic/claude-sonnet-4.6",
      "opus_model": "anthropic/claude-opus-4.6",
      "sonnet_model": "anthropic/claude-sonnet-4.6",
      "haiku_model": "anthropic/claude-haiku-4.5"
    }
  },
  "mcp_servers": {
    "tavily": {
      "type": "stdio",
      "command": "npx",
      "args": ["-y", "tavily-mcp@0.3.1"],
      "env": { "TAVILY_API_KEY": "env:TAVILY_API_KEY" }
    },
    "duckduckgo": {
      "type": "stdio",
      "command": "npx",
      "args": ["-y", "duckduckgo-mcp-server@1.1.0"]
    }
  }
}
```

```bash
export OPENROUTER_API_KEY="sk-or-..."
export TAVILY_API_KEY="tvly-..."
```

**WebSearch/WebFetch:** ❌ Not available through OpenRouter. Use MCP servers instead.

> **Note:** OpenRouter only guarantees Claude Code compatibility with the Anthropic first-party provider. Non-Anthropic models are not expected to work.

### LiteLLM Proxy

[LiteLLM](https://github.com/BerriAI/litellm) is an open-source proxy that can front Anthropic, Bedrock, Vertex AI, and other backends with a unified API.

```json
{
  "version": 1,
  "default_provider": "litellm",
  "providers": {
    "litellm": {
      "base_url": "https://your-litellm-server:4000",
      "auth_token": "env:LITELLM_API_KEY",
      "model": "claude-sonnet-4-6",
      "opus_model": "claude-opus-4-6",
      "sonnet_model": "claude-sonnet-4-6",
      "haiku_model": "claude-haiku-4-5"
    }
  },
  "mcp_servers": {
    "tavily": {
      "type": "stdio",
      "command": "npx",
      "args": ["-y", "tavily-mcp@0.3.1"],
      "env": { "TAVILY_API_KEY": "env:TAVILY_API_KEY" }
    },
    "duckduckgo": {
      "type": "stdio",
      "command": "npx",
      "args": ["-y", "duckduckgo-mcp-server@1.1.0"]
    }
  }
}
```

```bash
export LITELLM_API_KEY="sk-..."
export TAVILY_API_KEY="tvly-..."
```

**WebSearch/WebFetch:** LiteLLM has a unique feature — it can [intercept `web_search` tool calls](https://docs.litellm.ai/docs/tutorials/claude_code_websearch) and execute them server-side using Perplexity, Tavily, or other search providers. If your LiteLLM instance has this enabled, you may not need MCP web search servers at all. Otherwise, the MCP servers above provide a reliable client-side fallback.

> **Security note:** LiteLLM PyPI versions 1.82.7 and 1.82.8 were compromised with credential-stealing malware. Always verify the version you're running.

### Cloudflare AI Gateway

[Cloudflare AI Gateway](https://developers.cloudflare.com/ai-gateway/) acts as a pass-through proxy to Anthropic's API, adding logging, caching, rate limiting, and analytics.

```json
{
  "version": 1,
  "default_provider": "cloudflare",
  "providers": {
    "cloudflare": {
      "base_url": "https://gateway.ai.cloudflare.com/v1/ACCOUNT_ID/GATEWAY_ID/anthropic",
      "auth_token": "env:ANTHROPIC_API_KEY",
      "model": "claude-sonnet-4-6",
      "opus_model": "claude-opus-4-6",
      "sonnet_model": "claude-sonnet-4-6",
      "haiku_model": "claude-haiku-4-5",
      "custom_headers": "cf-aig-authorization: Bearer env:CF_AIG_TOKEN"
    }
  }
}
```

```bash
export ANTHROPIC_API_KEY="sk-ant-..."
export CF_AIG_TOKEN="..."  # optional, if your gateway requires auth
```

**WebSearch/WebFetch:** ✅ Available — Cloudflare forwards requests to Anthropic, so native tools work. You may not need MCP web search servers at all with this provider. Omit the `mcp_servers` block if you don't need them.

### Amazon Bedrock (via custom gateway)

Bedrock has [native Claude Code support](https://code.claude.com/docs/en/amazon-bedrock) (`CLAUDE_CODE_USE_BEDROCK=1`), but if your org routes Bedrock through a custom gateway, you can use `claude-overlay` to manage the project config:

```json
{
  "version": 1,
  "default_provider": "bedrock-gateway",
  "providers": {
    "bedrock-gateway": {
      "base_url": "https://your-bedrock-gateway.corp.example.com",
      "auth_token": "env:BEDROCK_GATEWAY_TOKEN",
      "model": "us.anthropic.claude-sonnet-4-6-v1",
      "opus_model": "us.anthropic.claude-opus-4-6-v1",
      "sonnet_model": "us.anthropic.claude-sonnet-4-6-v1",
      "haiku_model": "us.anthropic.claude-haiku-4-5-20251001-v1:0"
    }
  },
  "mcp_servers": {
    "tavily": {
      "type": "stdio",
      "command": "npx",
      "args": ["-y", "tavily-mcp@0.3.1"],
      "env": { "TAVILY_API_KEY": "env:TAVILY_API_KEY" }
    }
  }
}
```

**WebSearch/WebFetch:** ❌ Not available through Bedrock. Anthropic hides the WebSearch tool when Bedrock is active.

> **Tip:** For standard Bedrock usage without a gateway, you don't need `claude-overlay` — use the built-in `CLAUDE_CODE_USE_BEDROCK=1` with [AWS credential chain](https://code.claude.com/docs/en/amazon-bedrock). Use `claude-overlay` when your org adds a gateway layer on top.

### Custom / Corporate Proxy

Any endpoint that exposes the [Anthropic Messages API format](https://code.claude.com/docs/en/llm-gateway) (`/v1/messages`) can be used:

```json
{
  "version": 1,
  "default_provider": "corp-proxy",
  "providers": {
    "corp-proxy": {
      "base_url": "https://ai-gateway.corp.example.com/v1",
      "auth_token": "env:CORP_AI_TOKEN",
      "model": "claude-sonnet-4-6",
      "opus_model": "claude-opus-4-6",
      "sonnet_model": "claude-sonnet-4-6",
      "haiku_model": "claude-haiku-4-5",
      "custom_headers": "X-Team-Id: platform-eng"
    }
  },
  "mcp_servers": {
    "tavily": {
      "type": "stdio",
      "command": "npx",
      "args": ["-y", "tavily-mcp@0.3.1"],
      "env": { "TAVILY_API_KEY": "env:TAVILY_API_KEY" }
    },
    "duckduckgo": {
      "type": "stdio",
      "command": "npx",
      "args": ["-y", "duckduckgo-mcp-server@1.1.0"]
    }
  }
}
```

The gateway must forward the `anthropic-beta` and `anthropic-version` headers and the `X-Claude-Code-Session-Id` header that Claude Code sends on every request.

## WebSearch/WebFetch Compatibility

Not all providers support Anthropic's native WebSearch and WebFetch tools. This is the primary reason `claude-overlay` exists — it replaces them with MCP-based alternatives.

| Provider | WebSearch | WebFetch | Notes |
|----------|-----------|----------|-------|
| Anthropic API (direct) | ✅ | ✅ | No overlay needed |
| Microsoft Foundry (Azure) | ✅ | ✅ | Native support; no overlay needed |
| Google Vertex AI | ✅ basic | ❓ | Works but without dynamic filtering |
| Amazon Bedrock | ❌ | ❌ | Tool is hidden by Claude Code |
| Databricks | ❌ | ❌ | Not supported |
| OpenRouter | ❌ | ❌ | Not supported |
| LiteLLM | ⚡ server-side | ❌ | Can intercept via Perplexity/Tavily |
| Cloudflare AI Gateway | ✅ | ✅ | Pass-through to Anthropic |

**When you see ❌, that's where `claude-overlay` helps** — it adds Tavily and DuckDuckGo as MCP servers so Claude Code still has web search capabilities.

## How It Works

### Overlay Architecture

Instead of replacing your entire project config, `claude-overlay` uses a **surgical overlay** approach:

1. **`setup`** saves a `provider-overlay.json` recording exactly which keys it manages, then merges them into your existing `.claude/settings.local.json` and `.mcp.json`

2. **`disable`** reads the overlay and removes *only* those specific keys — your custom settings, MCP servers, and permissions are untouched

3. **`enable`** merges the overlay keys back in without duplicating anything

### Files Modified

| File | Purpose | Managed by overlay |
|------|---------|-------------------|
| `.claude/settings.local.json` | Project-local Claude Code settings | Env vars, permissions |
| `.mcp.json` | MCP server definitions | Web search servers |
| `.claude/provider-overlay.json` | Record of managed keys | Entire file |
| `.gitignore` | Git exclusions | Entries for above files |

All sensitive files are created with `chmod 600` and added to `.gitignore`.

### Config File

`~/.config/claude-overlay/config.json` stores your provider configuration. Secrets are referenced using the `env:` prefix:

```json
{
  "providers": {
    "databricks": {
      "auth_token": "env:DATABRICKS_TOKEN"
    }
  }
}
```

The `env:` prefix tells claude-overlay to read the value from the named environment variable at runtime. This keeps secrets out of config files and version control.

## MCP Web Search Servers

`claude-overlay` configures two complementary search providers:

| Server | Purpose | API Key Required |
|--------|---------|-----------------|
| [Tavily](https://tavily.com) | AI-optimized search with research mode | Yes (`TAVILY_API_KEY`) |
| [DuckDuckGo](https://github.com/nickclyde/duckduckgo-mcp-server) | Free fallback search, no API key needed | No |

You can customize which servers are included in your config file. If you only want DuckDuckGo (no API key needed):

```json
{
  "mcp_servers": {
    "duckduckgo": {
      "type": "stdio",
      "command": "npx",
      "args": ["-y", "duckduckgo-mcp-server@1.1.0"]
    }
  }
}
```

Or add other MCP search servers like [Brave Search](https://github.com/nicholasgriffintn/brave-search-mcp):

```json
{
  "mcp_servers": {
    "brave": {
      "type": "stdio",
      "command": "npx",
      "args": ["-y", "@nicholasgriffintn/brave-search-mcp@1.0.0"],
      "env": { "BRAVE_API_KEY": "env:BRAVE_API_KEY" }
    }
  }
}
```

## Shell Completions

Tab completions for all commands and flags are installed automatically via Homebrew and `make install`. To enable manually:

**Bash** — add to `~/.bashrc`:
```bash
source ~/.local/share/bash-completion/completions/claude-overlay
```

**Zsh** — add to `~/.zshrc` (before `compinit`):
```zsh
fpath=(~/.local/share/zsh/site-functions $fpath)
```

## Security

- **File permissions**: All files containing tokens are created with `chmod 600`
- **Atomic writes**: Files are written to a temp file first, then atomically renamed (prevents partial writes on crash)
- **No hardcoded secrets**: All tokens come from config file or environment variables
- **env: references**: Recommended way to store secrets — reads from env vars at runtime, never written to disk
- **MCP package pinning**: npm packages use pinned versions (not `@latest`) to reduce supply chain risk
- **gitignore**: Setup automatically adds sensitive files to `.gitignore`
- **HTTPS only**: Base URLs must start with `https://` — the tool rejects insecure endpoints

### npx Trust Model

MCP servers are installed via `npx -y`, which auto-installs and runs npm packages. Packages are version-pinned in your config, but you should audit them:

```bash
# Check what will be installed
npm info tavily-mcp@0.3.1
npm info duckduckgo-mcp-server@1.1.0
```

## Development

```bash
git clone https://github.com/mzmmoazam/claude-overlay.git
cd claude-overlay

# Run tests (61 tests covering all commands)
brew install bats-core  # or: apt install bats
make test

# Lint (shellcheck + py_compile)
make lint

# Install locally
make install

# Uninstall
make uninstall
```

### Project Structure

```
bin/claude-overlay          # Main CLI (bash)
lib/engine.py               # JSON manipulation engine (python3)
lib/presets/*.json           # Provider preset defaults
completions/                # Shell completions (bash, zsh)
test/                       # bats test suite (61 tests)
  test_helper.bash          # Shared test setup
  setup.bats                # Setup + dry-run tests
  enable_disable.bats       # Enable/disable cycle tests
  status.bats               # Status command tests
  configure.bats            # Configure command tests
  doctor.bats               # Doctor health-check tests
  switch.bats               # Provider switching tests
  export_import.bats        # Export/import round-trip tests
  migration.bats            # Legacy migration tests
install.sh                  # curl|bash installer
Makefile                    # make install/uninstall/test/lint
```

## FAQ

**Q: Do I need this if I use Anthropic's API directly?**
No. If you're using `claude.ai` or the Anthropic API with your own API key, WebSearch and WebFetch work natively. `claude-overlay` is for when you route through a third-party provider.

**Q: Do I need this for Bedrock / Vertex AI?**
Maybe not. Bedrock and Vertex AI have [native Claude Code integrations](https://code.claude.com/docs/en/amazon-bedrock) (`CLAUDE_CODE_USE_BEDROCK=1`, `CLAUDE_CODE_USE_VERTEX=1`). Use `claude-overlay` only if your org adds a gateway layer on top, or if you want MCP-based web search as a replacement for the missing native tools.

**Q: Can I have multiple providers configured?**
Yes. Run `claude-overlay configure` multiple times to add providers — existing ones are preserved. Use `claude-overlay switch` to change the active provider, or set the `CLAUDE_OVERLAY_PROVIDER` environment variable before running `setup`.

**Q: What happens to my existing project settings?**
They are preserved. `claude-overlay` only touches the keys it manages. Your custom permissions, env vars, and MCP servers are never modified.

**Q: Can I use this in a shared team project?**
Yes. The overlay files are automatically added to `.gitignore`, so each team member has their own local configuration. Use `claude-overlay export > team-config.json` to share a sanitized config (secrets replaced with `env:` references), and teammates import it with `claude-overlay import team-config.json`.

## Troubleshooting

**`claude` still shows the welcome/login picker after `setup`**
Claude Code v2+ checks `~/.claude.json` for `hasCompletedOnboarding` and `theme` before it ever loads your project's env vars — so on a fresh machine the welcome flow runs even when the overlay is correctly configured. `claude-overlay setup` and `enable` stamp those two keys for you automatically; if you're still seeing the picker, run `claude-overlay doctor` — it will report the first-run gate state and tell you how to fix it. Your existing keys in `~/.claude.json` are preserved; only the two gate fields are added (and `theme` is only set if you haven't already picked one).

## License

MIT
