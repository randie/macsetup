# ==============================================================================
# .zprofile
# - For login-time environment setup (PATH/MANPATH, Homebrew shellenv,
#   EDITOR/VISUAL/PAGER, host-related env, other global exports)
# - For things you want to set once per login session (not every new
#   shell) to speed up interactive shell startup.
# - Sourced after .zshenv and before .zshrc for *login* shells only.
# ==============================================================================

set -o allexport

# Set brew_path based on architecture, then run `brew shellenv`
# to bootstrap Homebrew into PATH, MANPATH, etc.
case "$(uname -m)" in
  arm64)  brew_path="/opt/homebrew"                ;;  # Apple Silicon
  x86_64) brew_path="/usr/local"                   ;;  # Intel macOS
  *)      brew_path="$(brew --prefix 2>/dev/null)" ;;  # fallback
esac
if [[ -x "$brew_path/bin/brew" ]]; then
  eval "$("$brew_path/bin/brew" shellenv)"
fi
unset brew_path

PATH="$PATH:$HOME/bin"

if [[ -n "$SSH_CONNECTION" ]]; then
  EDITOR="vim"
else
  if command -v mvim >/dev/null 2>&1; then
    EDITOR="mvim"
  else
    EDITOR="vim"
  fi
fi
FCEDIT="$EDITOR"  # default editor for the 'fc' builtin
VISUAL="$EDITOR"
PAGER="less"

# Redirect less(1) history to XDG state directory
LESSHISTFILE="$XDG_STATE_HOME/less/history"

# The localhost's [base]name (i.e. mozart vs. mozart.MG8702 on macOS)
if [[ "$(uname -s)" == "Darwin" ]]; then
  HOSTNAME="$(scutil --get LocalHostName 2>/dev/null || hostname)"
else
  HOSTNAME="$(uname -n)"
fi

set +o allexport
