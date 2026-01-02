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

# Better xtrace prefix: file:line:function> (only used when you `set -x`)
PS4='+%N:%i:${funcstack[1]:-main}> '

set +o allexport

# ------------------------------ history (XDG) ---------------------------------

# NB: HISTFILE's parent directory must be created for all shells (login or non-login)
# so it is intentionally not gated with `[[ -o login ]] && ...`
: "${HISTFILE:=$XDG_STATE_HOME/zsh/history}"
mkdir -p -- "${HISTFILE:h}" 2>/dev/null || true
touch -- "$HISTFILE" 2>/dev/null || true
chmod 600 -- "$HISTFILE" 2>/dev/null || true

# ------------------------------ zshinit logging -------------------------------

# Log file for zsh initialization issues
typeset -g ZSHINIT_LOG="$XDG_STATE_HOME/zsh/zshinit.log"

# Number of issues encountered during zsh initialization (used by P10K prompt)
typeset -gi ZSHINIT_NUM_ERRORS=0

# ---
# function _zshinit_log: Centralized logging helper for zsh init messages
#
# Usage:
#   _zshinit_log [-1] message
#   where 1 means the file descriptor for stdout (instead of the default stderr)
#
#   _zshinit_log "msg"      # log to file and echo to stderr; increment ZSHINIT_NUM_ERRORS
#   _zshinit_log -1 "msg"   # log to file and echo to stdout; informational only
#
# ZSHINIT_NUM_ERRORS is referenced in ~/.config/zsh/p10k/.p10k.zsh as the
# condition to check if an error occurred during zsh initialization so
# that an error indicator can be added to the P10K zsh prompt.
#
# Behavior:
# - Always appends the message to $ZSHINIT_LOG.
# - By default, echoes the message to stderr and increments ZSHINIT_NUM_ERRORS.
# - Passing -1 echoes the message to stdout and does NOT increment ZSHINIT_NUM_ERRORS.
#
# Prompt integration:
# - ZSHINIT_NUM_ERRORS is referenced by a custom Powerlevel10k prompt
#   segment defined in ~/.config/zsh/p10k/.p10k.zsh
# - The prompt displays an error indicator when ZSHINIT_NUM_ERRORS > 0,
#   signaling that at least one initialization error occurred.
#
# Powerlevel10k instant prompt safety:
# - Powerlevel10k's instant prompt will warn if anything writes to
#   stdout or stderr during early shell initialization.
# - To avoid this, terminal output is emitted ONLY after the variable
#   P10K_PROMPT_INITIALIZED is set by Powerlevel10k.
# - File logging is always safe and is never suppressed.
# ---
_zshinit_log() {
  [[ -o interactive ]] || return 0

  local fd=2    # default to stderr, file descriptor 2

  # Optional first argument: -1 (stdout, file descriptor 1)
  if [[ $# -gt 0 && "$1" == (-1) ]]; then
    fd=1
    shift
  fi

  # Default (stderr) counts as an init error for the P10K prompt indicator
  if [[ $fd -eq 2 ]]; then
    (( ZSHINIT_NUM_ERRORS++ ))
  fi

  # Always log to file
  {
    printf '%(%Y-%m-%d %H:%M:%S)T [%s:%d] %s\n' \
      -1 "$ZSH_NAME" "$$" "$*"
  } >>"$ZSHINIT_LOG" 2>/dev/null

  # Echo to terminal only after P10K instant prompt initialization
  if [[ -n ${P10K_PROMPT_INITIALIZED-} ]]; then
    print -u$fd -- "$*"
  fi
}
