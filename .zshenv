# ~/.zshenv — earliest zsh startup file

set -o allexport

# XDG base directories
XDG_CONFIG_HOME="$HOME/.config"
XDG_CACHE_HOME="$HOME/.cache"
XDG_DATA_HOME="$HOME/.local/share"
XDG_STATE_HOME="$HOME/.local/state"
[[ -o login ]] && mkdir -p "$XDG_CONFIG_HOME" "$XDG_CACHE_HOME" "$XDG_DATA_HOME" "$XDG_STATE_HOME" || true

# globally useful to both interactive and non-interactive shells
HOMEBREW_CACHE="$XDG_CACHE_HOME/Homebrew"
HOMEBREW_BUNDLE_FILE="$XDG_CONFIG_HOME/brew/Brewfile"
INPUTRC="$XDG_CONFIG_HOME/readline/inputrc"
GIT_CONFIG_GLOBAL="$XDG_CONFIG_HOME/git/config"
[[ -o login ]] && mkdir -p "$HOMEBREW_CACHE" "${HOMEBREW_BUNDLE_FILE%/*}" "${INPUTRC%/*}" "${GIT_CONFIG_GLOBAL%/*}" || true

# Tell zsh where to find its dotfiles
ZDOTDIR="$XDG_CONFIG_HOME/zsh"
[[ -o login ]] && mkdir -p "$ZDOTDIR/functions" || true

# ------------------------------ zshinit logging -------------------------------

# Log file for zsh init deviations from the "happy path"
typeset -g ZSHINIT_LOG="${XDG_STATE_HOME:-$HOME/.local/state}/zsh/zshinit.log"

# Integer counter: how many issues were logged during init
typeset -gi ZSHINIT_NUM_ERRORS=0

_zshinit_log() {
  # Optional: only log for login shells
  [[ -o login ]] || return 0

  # Optional: allow global debug disable (e.g. ZSH_INIT_DEBUG=0)
  if [[ -n "$ZSH_INIT_DEBUG" && "$ZSH_INIT_DEBUG" != 1 ]]; then
    return 0
  fi

  # Increment error counter on each log call
  (( ZSHINIT_NUM_ERRORS++ ))

  # Ensure parent directory exists; fail silently if it can't be created
  mkdir -p "${ZSHINIT_LOG:h}" 2>/dev/null || return 0

  # Timestamped log entry → file only (no terminal output)
  {
    printf '%s [%s:%d] %s\n' \
      "$(date '+%Y-%m-%d %H:%M:%S')" \
      "$ZSH_NAME" "$$" \
      "$*"
  } >>"$ZSHINIT_LOG" 2>/dev/null
}

# Better xtrace prefix: file:line:function> (only used when you `set -x`)
PS4='+%N:%i:${funcstack[1]:-main}> '

set +o allexport
