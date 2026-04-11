#!/usr/bin/env bash
# Bash completion for claude-overlay

_claude_overlay() {
  local commands="setup enable disable status configure switch export import doctor self-update"
  local cur="${COMP_WORDS[COMP_CWORD]}"

  if [ "$COMP_CWORD" -eq 1 ]; then
    COMPREPLY=($(compgen -W "$commands --version --help --debug" -- "$cur"))
    return
  fi

  local cmd="${COMP_WORDS[1]}"
  case "$cmd" in
    setup)
      COMPREPLY=($(compgen -W "-y --yes --dry-run --debug" -- "$cur")) ;;
    import)
      COMPREPLY=($(compgen -f -- "$cur")) ;;
  esac
}

complete -F _claude_overlay claude-overlay
