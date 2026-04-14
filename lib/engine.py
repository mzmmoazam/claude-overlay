#!/usr/bin/env python3
"""
claude-overlay engine — JSON manipulation logic for overlay management.

Called by bin/claude-overlay as:
    python3 engine.py <action>

Actions:
    migrate_legacy   — restore old .disabled files and create overlay
    create_overlay   — write the overlay file from _OV_* env vars
    merge            — merge overlay into settings + mcp (enable)
    remove           — remove overlay keys from settings + mcp (disable)
    status           — print JSON status blob
    load_config      — load and resolve config file, print as JSON

All sensitive values are passed via environment variables, never via
command-line arguments or string interpolation.
"""

import json
import os
import re
import sys
import tempfile

# ── Paths ──────────────────────────────────────────────────────────────────

SETTINGS = ".claude/settings.local.json"
MCP = ".mcp.json"
OVERLAY = ".claude/provider-overlay.json"

# Legacy paths
LEG_SETT = ".claude/settings.local.json.disabled"
LEG_MCP = ".mcp.json.disabled"
LEG_OVERLAY = ".claude/databricks-overlay.json"

# Config
XDG_CONFIG = os.environ.get("XDG_CONFIG_HOME", os.path.join(os.path.expanduser("~"), ".config"))
CONFIG_FILE = os.path.join(XDG_CONFIG, "claude-overlay", "config.json")

# Claude Code's global config — gates the first-run welcome/login flow
HOME_CLAUDE_JSON = os.path.join(os.path.expanduser("~"), ".claude.json")

DEBUG = os.environ.get("CLAUDE_OVERLAY_DEBUG", "") == "1"


# ── Helpers ────────────────────────────────────────────────────────────────

def debug(msg):
    if DEBUG:
        print(f"[debug] {msg}", file=sys.stderr)


def load(path):
    """Load a JSON file, returning {} if it doesn't exist or is invalid."""
    try:
        with open(path) as f:
            data = json.load(f)
            debug(f"Loaded {path} ({len(data)} keys)")
            return data
    except (FileNotFoundError, json.JSONDecodeError, OSError):
        debug(f"Could not load {path} (missing or invalid)")
        return {}


def save(path, data):
    """Atomically write a JSON file with restricted permissions (0600)."""
    _atomic_write(path, data, 0o600)


def save_with_mode(path, data, mode):
    """Atomically write a JSON file, preserving a specific file mode.

    Used for files we don't exclusively own (e.g. ~/.claude.json, which
    Claude Code itself writes to with its own permission conventions).
    """
    _atomic_write(path, data, mode)


def _atomic_write(path, data, mode):
    d = os.path.dirname(path)
    if d:
        os.makedirs(d, exist_ok=True)

    fd, tmp = tempfile.mkstemp(dir=d if d else ".", suffix=".tmp")
    try:
        with os.fdopen(fd, "w") as f:
            json.dump(data, f, indent=2)
            f.write("\n")
        os.chmod(tmp, mode)
        os.rename(tmp, path)
        debug(f"Saved {path} ({oct(mode)})")
    except Exception:
        try:
            os.unlink(tmp)
        except OSError:
            pass
        raise


def list_union(existing, additions):
    """Add items to a list without duplicates, preserving order."""
    result = list(existing)
    for item in additions:
        if item not in result:
            result.append(item)
    return result


def list_subtract(existing, removals):
    """Remove items from a list."""
    return [x for x in existing if x not in removals]


def resolve_token(value):
    """Resolve a token value. 'env:VAR' reads from env; raw values returned as-is."""
    if not isinstance(value, str):
        return value
    if value.startswith("env:"):
        var_name = value[4:]
        resolved = os.environ.get(var_name, "")
        if not resolved:
            print(f"error:env_var_not_set:{var_name}", file=sys.stdout)
            sys.exit(1)
        debug(f"Resolved {var_name} = ****")
        return resolved
    return value


def mask_token(value):
    """Mask a token for debug output."""
    if not isinstance(value, str) or len(value) < 8:
        return "****"
    return value[:6] + "****"


# ── ACTION: load_config ────────────────────────────────────────────────────

def action_load_config():
    """Load config file, resolve env: tokens, merge with preset, print as JSON."""
    config = load(CONFIG_FILE)
    if not config:
        print("error:no_config")
        sys.exit(1)

    provider_name = os.environ.get("CLAUDE_OVERLAY_PROVIDER", config.get("default_provider", "databricks"))
    providers = config.get("providers", {})
    provider = providers.get(provider_name, {})

    if not provider:
        print(f"error:unknown_provider:{provider_name}")
        sys.exit(1)

    # Load preset for defaults
    preset_dir = os.environ.get("_PRESET_DIR", "")
    preset = {}
    if preset_dir:
        preset_path = os.path.join(preset_dir, f"{provider_name}.json")
        preset = load(preset_path)

    # Resolve provider config with preset defaults
    resolved = {
        "base_url": resolve_token(provider.get("base_url", "")),
        "auth_token": resolve_token(provider.get("auth_token", "")),
        "model": provider.get("model", preset.get("env", {}).get("ANTHROPIC_MODEL", "")),
        "opus_model": provider.get("opus_model", preset.get("env", {}).get("ANTHROPIC_DEFAULT_OPUS_MODEL", "")),
        "sonnet_model": provider.get("sonnet_model", preset.get("env", {}).get("ANTHROPIC_DEFAULT_SONNET_MODEL", "")),
        "haiku_model": provider.get("haiku_model", preset.get("env", {}).get("ANTHROPIC_DEFAULT_HAIKU_MODEL", "")),
        "custom_headers": provider.get("custom_headers", preset.get("env", {}).get("ANTHROPIC_CUSTOM_HEADERS", "")),
    }

    # Validate
    if not resolved["base_url"]:
        print("error:missing_base_url")
        sys.exit(1)
    if not resolved["base_url"].startswith("https://"):
        # Allow http:// for local proxies (LiteLLM, custom)
        if provider_name in ("litellm", "custom") and resolved["base_url"].startswith("http://"):
            pass
        else:
            print("error:insecure_base_url")
            sys.exit(1)
    if not resolved["auth_token"]:
        print("error:missing_auth_token")
        sys.exit(1)

    # Resolve MCP servers
    mcp_servers = {}
    for name, server_conf in config.get("mcp_servers", {}).items():
        server = dict(server_conf)
        # Resolve env vars in server env block
        if "env" in server:
            resolved_env = {}
            for k, v in server["env"].items():
                resolved_env[k] = resolve_token(v)
            server["env"] = resolved_env
        mcp_servers[name] = server

    # Permissions from preset
    permissions_allow = preset.get("permissions_allow", [
        "mcp__tavily__tavily_search",
        "mcp__tavily__tavily_research",
        "mcp__duckduckgo__search"
    ])
    permissions_deny = preset.get("permissions_deny", [
        "WebSearch",
        "WebFetch"
    ])

    result = {
        "provider": provider_name,
        "resolved": resolved,
        "mcp_servers": mcp_servers,
        "permissions_allow": permissions_allow,
        "permissions_deny": permissions_deny,
    }
    print(json.dumps(result))


# ── ACTION: migrate_legacy ─────────────────────────────────────────────────

def action_migrate_legacy():
    """Restore old-style .disabled files and rename old overlay file."""
    migrated = False

    # Migrate overlay file rename: databricks-overlay.json → provider-overlay.json
    if os.path.exists(LEG_OVERLAY) and not os.path.exists(OVERLAY):
        os.rename(LEG_OVERLAY, OVERLAY)
        debug(f"Renamed {LEG_OVERLAY} → {OVERLAY}")
        migrated = True

    # Restore settings from .disabled
    if os.path.exists(LEG_SETT):
        old = load(LEG_SETT)
        current = load(SETTINGS)
        for section in old:
            if section not in current:
                current[section] = old[section]
            elif isinstance(old[section], dict) and isinstance(current.get(section), dict):
                for k, v in old[section].items():
                    if k not in current[section]:
                        current[section][k] = v
            elif isinstance(old[section], list) and isinstance(current.get(section), list):
                current[section] = list_union(current[section], old[section])
        if current:
            save(SETTINGS, current)
        os.remove(LEG_SETT)
        migrated = True

    # Restore MCP from .disabled
    if os.path.exists(LEG_MCP):
        old = load(LEG_MCP)
        current = load(MCP)
        old_servers = old.get("mcpServers", {})
        current.setdefault("mcpServers", {})
        for name, conf in old_servers.items():
            if name not in current["mcpServers"]:
                current["mcpServers"][name] = conf
        if current.get("mcpServers"):
            save(MCP, current)
        os.remove(LEG_MCP)
        migrated = True

    print("migrated" if migrated else "none")


# ── ACTION: create_overlay ─────────────────────────────────────────────────

def action_create_overlay():
    """Build overlay from _OV_* environment variables and save it."""
    # Read MCP servers config from _OV_MCP_SERVERS (JSON string) or use defaults
    mcp_json = os.environ.get("_OV_MCP_SERVERS", "")
    if mcp_json:
        try:
            mcp_servers = json.loads(mcp_json)
        except json.JSONDecodeError:
            print("error:invalid_mcp_servers_json")
            sys.exit(1)
    else:
        mcp_servers = {
            "tavily": {
                "type": "stdio",
                "command": "npx",
                "args": ["-y", "tavily-mcp@0.3.1"],
                "env": {"TAVILY_API_KEY": os.environ.get("_OV_TAVILY_KEY", "")}
            },
            "duckduckgo": {
                "type": "stdio",
                "command": "npx",
                "args": ["-y", "duckduckgo-mcp-server@1.1.0"]
            }
        }

    # Read permissions from env or use defaults
    allow_json = os.environ.get("_OV_PERMISSIONS_ALLOW", "")
    deny_json = os.environ.get("_OV_PERMISSIONS_DENY", "")

    permissions_allow = json.loads(allow_json) if allow_json else [
        "mcp__tavily__tavily_search",
        "mcp__tavily__tavily_research",
        "mcp__duckduckgo__search"
    ]
    permissions_deny = json.loads(deny_json) if deny_json else [
        "WebSearch",
        "WebFetch"
    ]

    overlay = {
        "env": {
            "ANTHROPIC_MODEL": os.environ.get("_OV_MODEL", ""),
            "ANTHROPIC_BASE_URL": os.environ.get("_OV_BASE_URL", ""),
            "ANTHROPIC_AUTH_TOKEN": os.environ.get("_OV_AUTH_TOKEN", ""),
            "ANTHROPIC_DEFAULT_OPUS_MODEL": os.environ.get("_OV_OPUS", ""),
            "ANTHROPIC_DEFAULT_SONNET_MODEL": os.environ.get("_OV_SONNET", ""),
            "ANTHROPIC_DEFAULT_HAIKU_MODEL": os.environ.get("_OV_HAIKU", ""),
            "ANTHROPIC_CUSTOM_HEADERS": os.environ.get("_OV_HEADERS", ""),
            "CLAUDE_CODE_DISABLE_EXPERIMENTAL_BETAS": "1"
        },
        "permissions_allow": permissions_allow,
        "permissions_deny": permissions_deny,
        "mcpServers": mcp_servers
    }
    save(OVERLAY, overlay)
    print("ok")


# ── ACTION: merge ──────────────────────────────────────────────────────────

def action_merge():
    """Merge overlay INTO settings + mcp (non-destructive to other keys)."""
    overlay = load(OVERLAY)
    if not overlay:
        print("error:no_overlay")
        sys.exit(1)

    # Merge into settings.local.json
    settings = load(SETTINGS)

    settings.setdefault("env", {})
    for k, v in overlay.get("env", {}).items():
        settings["env"][k] = v

    settings.setdefault("permissions", {})
    existing_allow = settings["permissions"].get("allow", [])
    settings["permissions"]["allow"] = list_union(existing_allow, overlay.get("permissions_allow", []))

    existing_deny = settings["permissions"].get("deny", [])
    settings["permissions"]["deny"] = list_union(existing_deny, overlay.get("permissions_deny", []))

    save(SETTINGS, settings)

    # Merge into .mcp.json
    mcp = load(MCP)
    mcp.setdefault("mcpServers", {})
    for name, conf in overlay.get("mcpServers", {}).items():
        mcp["mcpServers"][name] = conf

    save(MCP, mcp)
    print("ok")


# ── ACTION: remove ─────────────────────────────────────────────────────────

def action_remove():
    """Remove overlay keys FROM settings + mcp (leave other keys intact)."""
    overlay = load(OVERLAY)
    if not overlay:
        print("error:no_overlay")
        sys.exit(1)

    # Remove from settings.local.json
    settings = load(SETTINGS)

    env = settings.get("env", {})
    for k in overlay.get("env", {}):
        env.pop(k, None)
    if env:
        settings["env"] = env
    else:
        settings.pop("env", None)

    perms = settings.get("permissions", {})
    if "allow" in perms:
        perms["allow"] = list_subtract(perms["allow"], overlay.get("permissions_allow", []))
        if not perms["allow"]:
            del perms["allow"]
    if "deny" in perms:
        perms["deny"] = list_subtract(perms["deny"], overlay.get("permissions_deny", []))
        if not perms["deny"]:
            del perms["deny"]
    if perms:
        settings["permissions"] = perms
    else:
        settings.pop("permissions", None)

    if settings:
        save(SETTINGS, settings)
        print("settings:trimmed")
    else:
        try:
            os.remove(SETTINGS)
        except OSError:
            pass
        print("settings:removed")

    # Remove from .mcp.json
    mcp = load(MCP)
    servers = mcp.get("mcpServers", {})
    for name in overlay.get("mcpServers", {}):
        servers.pop(name, None)

    if servers:
        mcp["mcpServers"] = servers
        save(MCP, mcp)
        print("mcp:trimmed")
    else:
        try:
            os.remove(MCP)
        except OSError:
            pass
        print("mcp:removed")


# ── ACTION: status ─────────────────────────────────────────────────────────

def action_status():
    """Print JSON status blob describing current overlay state."""
    overlay = load(OVERLAY)
    settings = load(SETTINGS)
    mcp = load(MCP)

    has_overlay = bool(overlay)

    overlay_env_keys = set(overlay.get("env", {}).keys())
    settings_env_keys = set(settings.get("env", {}).keys())
    overlay_enabled = overlay_env_keys.issubset(settings_env_keys) and len(overlay_env_keys) > 0

    overlay_mcp = set(overlay.get("mcpServers", {}).keys())
    active_mcp = set(mcp.get("mcpServers", {}).keys())
    mcp_enabled = overlay_mcp.issubset(active_mcp) and len(overlay_mcp) > 0

    other_env = {k: v for k, v in settings.get("env", {}).items() if k not in overlay_env_keys}
    other_mcp = {k for k in active_mcp if k not in overlay_mcp}

    allow_list = settings.get("permissions", {}).get("allow", [])
    deny_list = settings.get("permissions", {}).get("deny", [])
    overlay_allow = overlay.get("permissions_allow", [])
    overlay_deny = overlay.get("permissions_deny", [])
    other_allow = [x for x in allow_list if x not in overlay_allow]
    other_deny = [x for x in deny_list if x not in overlay_deny]

    result = {
        "has_overlay": has_overlay,
        "overlay_enabled": overlay_enabled and mcp_enabled,
        "overlay_partial": overlay_enabled != mcp_enabled,
        "model": settings.get("env", {}).get("ANTHROPIC_MODEL", ""),
        "base_url": settings.get("env", {}).get("ANTHROPIC_BASE_URL", ""),
        "managed_mcp": sorted(overlay_mcp) if overlay_mcp else [],
        "managed_mcp_active": sorted(overlay_mcp & active_mcp),
        "other_mcp": sorted(other_mcp),
        "all_mcp": sorted(active_mcp),
        "other_env_keys": sorted(other_env.keys()),
        "managed_allow": [x for x in overlay_allow if x in allow_list],
        "managed_deny": [x for x in overlay_deny if x in deny_list],
        "other_allow": other_allow,
        "other_deny": other_deny,
    }
    print(json.dumps(result))


# ── ACTION: ensure_onboarding ──────────────────────────────────────────────
#
# Claude Code v2+ gates its interactive start on ~/.claude.json having both
#   hasCompletedOnboarding === true
#   theme set
# On a fresh machine neither is present, so `claude` shows the welcome/login
# picker regardless of any ANTHROPIC_* env vars coming from the overlay.
# This action stamps both keys, preserving everything else in the file.

def action_ensure_onboarding():
    """Stamp ~/.claude.json so Claude Code skips the welcome/login flow.

    Non-destructive: loads any existing file, sets the two gate keys only
    if missing/wrong, preserves all other keys and the file's existing mode.
    """
    existing = load(HOME_CLAUDE_JSON)
    created = not os.path.exists(HOME_CLAUDE_JSON)
    changed = False

    if existing.get("hasCompletedOnboarding") is not True:
        existing["hasCompletedOnboarding"] = True
        changed = True

    if "theme" not in existing:
        existing["theme"] = "dark"
        changed = True

    if not changed:
        print("skipped")
        return

    if created:
        mode = 0o600
    else:
        try:
            mode = os.stat(HOME_CLAUDE_JSON).st_mode & 0o777
        except OSError:
            mode = 0o600

    save_with_mode(HOME_CLAUDE_JSON, existing, mode)
    print("created" if created else "updated")


def action_check_onboarding():
    """Print JSON describing ~/.claude.json first-run-gate state."""
    exists = os.path.exists(HOME_CLAUDE_JSON)
    data = load(HOME_CLAUDE_JSON) if exists else {}
    result = {
        "file_exists": exists,
        "has_completed_onboarding": data.get("hasCompletedOnboarding") is True,
        "has_theme": "theme" in data,
        "theme_value": data.get("theme", ""),
    }
    print(json.dumps(result))


def action_switch_provider():
    """Switch default_provider in config file. Provider name in _SWITCH_TO env var."""
    target = os.environ.get("_SWITCH_TO", "")
    config = load(CONFIG_FILE)
    if not config:
        print("error:no_config")
        sys.exit(1)

    providers = config.get("providers", {})
    if not target:
        # List mode: print available providers as JSON
        result = {
            "default": config.get("default_provider", ""),
            "providers": sorted(providers.keys()),
        }
        print(json.dumps(result))
        return

    if target not in providers:
        print(f"error:unknown_provider:{target}")
        sys.exit(1)

    if config.get("default_provider") == target:
        print("already_default")
        return

    config["default_provider"] = target
    save(CONFIG_FILE, config)
    print("ok")


def action_export_config():
    """Export config to stdout, sanitized for sharing."""
    config = load(CONFIG_FILE)
    if not config:
        print("error:no_config")
        sys.exit(1)

    # Config should already use env: references, but scrub any raw tokens
    for pname, pconf in config.get("providers", {}).items():
        token = pconf.get("auth_token", "")
        if token and not token.startswith("env:"):
            pconf["auth_token"] = "env:YOUR_TOKEN_HERE"
        # Scrub potential bearer tokens in custom headers
        headers = pconf.get("custom_headers", "")
        if headers:
            pconf["custom_headers"] = re.sub(
                r"(Bearer|Token|Basic)\s+\S+", r"\1 REDACTED", headers, flags=re.IGNORECASE
            )

    print(json.dumps(config, indent=2))


def action_import_config():
    """Import config from a file (path in _IMPORT_PATH env var). Merge with existing."""
    import_path = os.environ.get("_IMPORT_PATH", "")
    if not import_path or not os.path.isfile(import_path):
        print("error:file_not_found")
        sys.exit(1)

    imported = load(import_path)
    if not imported:
        print("error:invalid_json")
        sys.exit(1)

    # Validate minimal structure
    if "providers" not in imported or not isinstance(imported["providers"], dict):
        print("error:missing_providers")
        sys.exit(1)

    existing = load(CONFIG_FILE) or {"version": 1, "providers": {}}

    # Merge providers (imported overwrites on conflict)
    for pname, pconf in imported["providers"].items():
        existing.setdefault("providers", {})[pname] = pconf

    # Update default provider
    if imported.get("default_provider"):
        existing["default_provider"] = imported["default_provider"]

    # Merge MCP servers
    for name, conf in imported.get("mcp_servers", {}).items():
        existing.setdefault("mcp_servers", {})[name] = conf

    existing["version"] = imported.get("version", existing.get("version", 1))

    os.makedirs(os.path.dirname(CONFIG_FILE), exist_ok=True)
    save(CONFIG_FILE, existing)
    print("ok")


# ── Dispatch ───────────────────────────────────────────────────────────────

ACTIONS = {
    "load_config": action_load_config,
    "migrate_legacy": action_migrate_legacy,
    "create_overlay": action_create_overlay,
    "merge": action_merge,
    "remove": action_remove,
    "status": action_status,
    "ensure_onboarding": action_ensure_onboarding,
    "check_onboarding": action_check_onboarding,
    "switch_provider": action_switch_provider,
    "export_config": action_export_config,
    "import_config": action_import_config,
}

def main():
    action = sys.argv[1] if len(sys.argv) > 1 else ""
    if action not in ACTIONS:
        print(f"error:unknown_action:{action}")
        sys.exit(1)
    ACTIONS[action]()

if __name__ == "__main__":
    main()
