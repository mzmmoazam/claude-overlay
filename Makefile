PREFIX ?= $(HOME)/.local
BIN_DIR = $(PREFIX)/bin
LIB_DIR = $(PREFIX)/lib/claude-overlay
BASH_COMP_DIR = $(PREFIX)/share/bash-completion/completions
ZSH_COMP_DIR = $(PREFIX)/share/zsh/site-functions

.PHONY: install uninstall test lint

install:
	@echo "Installing claude-overlay to $(PREFIX)…"
	install -d $(BIN_DIR) $(LIB_DIR)/presets
	install -m 755 bin/claude-overlay $(BIN_DIR)/claude-overlay
	install -m 644 lib/engine.py $(LIB_DIR)/engine.py
	install -m 644 lib/presets/*.json $(LIB_DIR)/presets/
	install -d $(BASH_COMP_DIR) $(ZSH_COMP_DIR)
	install -m 644 completions/claude-overlay.bash $(BASH_COMP_DIR)/claude-overlay
	install -m 644 completions/claude-overlay.zsh $(ZSH_COMP_DIR)/_claude-overlay
	@echo ""
	@echo "Installed. Run 'claude-overlay configure' to set up your credentials."

uninstall:
	@echo "Removing claude-overlay from $(PREFIX)…"
	rm -f $(BIN_DIR)/claude-overlay
	rm -rf $(LIB_DIR)
	rm -f $(BASH_COMP_DIR)/claude-overlay
	rm -f $(ZSH_COMP_DIR)/_claude-overlay
	@echo "Done."

lint:
	shellcheck bin/claude-overlay install.sh
	python3 -m py_compile lib/engine.py

test:
	@if command -v bats >/dev/null 2>&1; then \
		bats test/; \
	else \
		echo "bats not found. Install: brew install bats-core"; \
	fi
