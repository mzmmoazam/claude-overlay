#!/usr/bin/env bash
# claude-overlay installer
#
# Usage:
#   curl -fsSL https://raw.githubusercontent.com/mzmmoazam/claude-overlay/main/install.sh | bash
#
# Environment variables:
#   INSTALL_DIR — override install prefix (default: ~/.local)

set -euo pipefail

# ── Config ─────────────────────────────────────────────────────────────────
REPO="mzmmoazam/claude-overlay"
INSTALL_PREFIX="${INSTALL_DIR:-$HOME/.local}"
BIN_DIR="$INSTALL_PREFIX/bin"
LIB_DIR="$INSTALL_PREFIX/lib/claude-overlay"

# ── Colours ────────────────────────────────────────────────────────────────
GREEN='\033[0;32m'; BLUE='\033[0;34m'; YELLOW='\033[1;33m'
RED='\033[0;31m'; BOLD='\033[1m'; NC='\033[0m'

ok()   { echo -e "${GREEN}✓${NC} $*"; }
info() { echo -e "${BLUE}→${NC} $*"; }
warn() { echo -e "${YELLOW}!${NC} $*"; }
err()  { echo -e "${RED}✗${NC} $*" >&2; }

# ── Safety checks ─────────────────────────────────────────────────────────
main() {
  echo ""
  echo -e "${BOLD}Claude Overlay — Installer${NC}"
  echo ""

  # Never run as root
  if [ "$(id -u)" = "0" ]; then
    err "Do not run this installer as root or with sudo."
    exit 1
  fi

  # Check dependencies
  for cmd in curl python3 tar; do
    if ! command -v "$cmd" >/dev/null 2>&1; then
      err "$cmd is required but not found. Please install it first."
      exit 1
    fi
  done

  # Check Python version
  if ! python3 -c "import sys; sys.exit(0 if sys.version_info >= (3,7) else 1)" 2>/dev/null; then
    err "python3 >= 3.7 is required. Found: $(python3 --version 2>&1)"
    exit 1
  fi

  # ── Detect OS ──────────────────────────────────────────────────────────
  local os_name
  os_name="$(uname -s)"
  case "$os_name" in
    Darwin|Linux) info "Detected OS: $os_name" ;;
    *)
      err "Unsupported OS: $os_name. claude-overlay supports macOS and Linux."
      exit 1 ;;
  esac

  # ── Fetch latest release ───────────────────────────────────────────────
  info "Fetching latest release from GitHub…"
  local api_url="https://api.github.com/repos/$REPO/releases/latest"
  local release_json
  release_json=$(curl -fsSL "$api_url" 2>/dev/null) || {
    # Fallback: if no releases yet, install from main branch
    warn "No releases found. Installing from main branch."
    install_from_main
    return
  }

  local version tarball_url
  version=$(python3 -c "import json,sys; print(json.loads(sys.stdin.read())['tag_name'].lstrip('v'))" <<< "$release_json")
  tarball_url=$(python3 -c "import json,sys; print(json.loads(sys.stdin.read())['tarball_url'])" <<< "$release_json")

  info "Latest version: v$version"

  # ── Download and extract ───────────────────────────────────────────────
  local tmpdir
  tmpdir=$(mktemp -d)
  trap 'rm -rf "$tmpdir"' EXIT

  info "Downloading…"
  curl -fsSL "$tarball_url" -o "$tmpdir/release.tar.gz" || {
    err "Failed to download release."
    exit 1
  }

  tar -xzf "$tmpdir/release.tar.gz" -C "$tmpdir" --strip-components=1

  do_install "$tmpdir" "$version"
}

# ── Install from main branch (fallback when no releases) ─────────────────
install_from_main() {
  local tmpdir
  tmpdir=$(mktemp -d)
  trap 'rm -rf "$tmpdir"' EXIT

  local tarball_url="https://github.com/$REPO/archive/refs/heads/main.tar.gz"
  info "Downloading from main branch…"
  curl -fsSL "$tarball_url" -o "$tmpdir/main.tar.gz" || {
    err "Failed to download from main branch."
    exit 1
  }

  tar -xzf "$tmpdir/main.tar.gz" -C "$tmpdir" --strip-components=1
  do_install "$tmpdir" "dev"
}

# ── Shared install logic ─────────────────────────────────────────────────
do_install() {
  local source_dir="$1"
  local version="$2"

  # ── Install files ──────────────────────────────────────────────────────
  info "Installing to $INSTALL_PREFIX"
  mkdir -p "$BIN_DIR" "$LIB_DIR/presets"

  install -m 755 "$source_dir/bin/claude-overlay" "$BIN_DIR/claude-overlay"
  ok "Installed bin/claude-overlay"

  install -m 644 "$source_dir/lib/engine.py" "$LIB_DIR/engine.py"
  ok "Installed lib/engine.py"

  if [ -d "$source_dir/lib/presets" ]; then
    cp "$source_dir/lib/presets/"*.json "$LIB_DIR/presets/" 2>/dev/null || true
    ok "Installed provider presets"
  fi

  # ── Shell completions ─────────────────────────────────────────────────
  if [ -d "$source_dir/completions" ]; then
    local bash_comp_dir="$INSTALL_PREFIX/share/bash-completion/completions"
    local zsh_comp_dir="$INSTALL_PREFIX/share/zsh/site-functions"
    mkdir -p "$bash_comp_dir" "$zsh_comp_dir"
    cp "$source_dir/completions/claude-overlay.bash" "$bash_comp_dir/claude-overlay" 2>/dev/null || true
    cp "$source_dir/completions/claude-overlay.zsh" "$zsh_comp_dir/_claude-overlay" 2>/dev/null || true
    ok "Installed shell completions"
  fi

  # ── Check PATH ─────────────────────────────────────────────────────────
  echo ""
  if echo "$PATH" | tr ':' '\n' | grep -qF "$BIN_DIR"; then
    ok "$BIN_DIR is in your PATH"
  else
    warn "$BIN_DIR is not in your PATH"
    echo ""
    echo -e "  Add this to your ${BOLD}~/.zshrc${NC} or ${BOLD}~/.bashrc${NC}:"
    echo ""
    echo "    export PATH=\"\$HOME/.local/bin:\$PATH\""
    echo ""
    echo "  Then reload: source ~/.zshrc"
  fi

  # ── Summary ────────────────────────────────────────────────────────────
  echo ""
  echo -e "${GREEN}${BOLD}claude-overlay v$version installed!${NC}"
  echo ""
  echo -e "${BOLD}Next steps:${NC}"
  echo ""
  echo "  1. Set up your credentials:"
  echo ""
  echo "     claude-overlay configure"
  echo ""
  echo "  2. Go to a project and enable the overlay:"
  echo ""
  echo "     cd your-project"
  echo "     claude-overlay setup"
  echo ""
}

main "$@"
