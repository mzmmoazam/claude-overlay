#compdef claude-overlay
# Zsh completion for claude-overlay

_claude_overlay() {
  local -a commands=(
    'setup:Set up provider overlay for this project'
    'enable:Restore overlay keys alongside other settings'
    'disable:Remove overlay keys, keep other settings'
    'status:Show current state of project config'
    'configure:Create or update user config file'
    'switch:Switch active provider'
    'export:Export config for team sharing'
    'import:Import a shared config file'
    'doctor:Check setup health'
    'self-update:Update to the latest release'
  )

  _arguments -C \
    '--version[Print version]' \
    '--help[Show help]' \
    '--debug[Enable verbose debug output]' \
    '1:command:->cmd' \
    '*::arg:->args'

  case "$state" in
    cmd)
      _describe 'command' commands ;;
    args)
      case "${words[1]}" in
        setup)
          _arguments \
            '-y[Skip confirmation prompts]' \
            '--yes[Skip confirmation prompts]' \
            '--dry-run[Show what would happen without making changes]' ;;
        import)
          _files ;;
      esac ;;
  esac
}

_claude_overlay
