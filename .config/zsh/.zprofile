# ==============================================================================
# .zprofile
# - For login-time environment setup (PATH/MANPATH, Homebrew shellenv,
#   EDITOR/VISUAL/PAGER, host-related env, other global exports)
# - For things you want to set once per login session (not every new
#   shell) to speed up interactive shell startup.
# - Sourced after .zshenv and before .zshrc for *login* shells only.
# ==============================================================================
typeset arch brew_path
arch="$(uname -m)"
brew_path=""

# Set brew_path based on architecture, then run `brew shellenv`
# to bootstrap Homebrew into PATH, MANPATH, etc.
case "$arch" in
  arm64)  brew_path="/opt/homebrew" ;;  # Apple Silicon
  x86_64) brew_path="/usr/local"    ;;  # Intel
  *)                                    # Fallback
    if command -v brew >/dev/null 2>&1; then
      brew_path="$(brew --prefix 2>/dev/null)"
      _zshinit_log "WARNING: Non-standard architecture $arch; using brew --prefix: $brew_path"
    else
      _zshinit_log "WARNING: brew command not found on PATH for arch $arch; skipping brew shellenv."
    fi
    ;;
esac

if [[ -n "$brew_path" && -x "$brew_path/bin/brew" ]]; then
  eval "$("$brew_path/bin/brew" shellenv)"  # set Homebrew env vars
elif [[ -n "$brew_path" ]]; then
  _zshinit_log "WARNING: $brew_path/bin/brew is not executable; skipping brew shellenv."
fi

# Append $HOME/bin to $PATH if not already present
case ":$PATH:" in
  *":$HOME/bin:"*) ;;
  *) PATH="$PATH:$HOME/bin" ;;
esac
export PATH

# SSH_CONNECTION is set by OpenSSH for remote secure shell sessions.
# Use vim for remote SSH sessions, but prefer GUI editor (mvim) for local shells.
if [[ -n "${SSH_CONNECTION-}" ]]; then
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
export EDITOR FCEDIT VISUAL PAGER

# Redirect less(1) history to XDG state directory.
# Note, XDG_STATE_HOME should already be set in .zshenv.
LESSHISTFILE="$XDG_STATE_HOME/less/history"
mkdir -p "${LESSHISTFILE%/*}" 2>/dev/null || true
export LESSHISTFILE

# Clean up temporary variables.
unset arch brew_path
