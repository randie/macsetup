# ==============================================================================
#                            Zsh Configuration
#                     (Intel + Apple Silicon friendly)
# ==============================================================================

# NOTE: This is an XDG-friendly Zsh config. XDG_* env vars are set in ~/.zshenv.

# -------------------- Powerlevel10k instant prompt (quiet) --------------------

typeset -g POWERLEVEL9K_INSTANT_PROMPT=quiet

# Use XDG cache for P10K’s instant prompt
if [[ -r "$XDG_CACHE_HOME/p10k-instant-prompt-${(%):-%n}.zsh" ]]; then
  source "$XDG_CACHE_HOME/p10k-instant-prompt-${(%):-%n}.zsh"
fi

# ----------------------------- Core environment ------------------------------

set -o allexport

ZFUNCDIR="$XDG_CONFIG_HOME/zsh/functions"
ZSH="$HOME/.oh-my-zsh"
KEYTIMEOUT=5
PAGER="less"
PATH="$PATH:$HOME/bin"

if [[ "$(uname -s)" == "Darwin" ]]; then
  HOSTNAME="$(scutil --get LocalHostName 2>/dev/null || hostname)"
else
  HOSTNAME="$(uname -n)"
fi

if [[ -n "$SSH_CONNECTION" ]]; then
  EDITOR="vim"
else
  if command -v mvim >/dev/null 2>&1; then
    # Editor (prefer mvim when local GUI session)
    EDITOR="mvim"
  else
    EDITOR="vim"
  fi
fi
VISUAL="$EDITOR"
FCEDIT="$VISUAL"

set +o allexport

# --------------------------------- Homebrew ----------------------------------

# Set BREW_PATH based on architecture
case "$(uname -m)" in
  arm64)   export BREW_PATH="/opt/homebrew" ;;  # Apple Silicon
  x86_64)  export BREW_PATH="/usr/local"    ;;  # Intel macOS
  *)       export BREW_PATH="$(brew --prefix 2>/dev/null)" ;; # fallback (Linuxbrew/custom)
esac

# Bootstrap Homebrew into PATH/MANPATH/etc.
if [[ -x "$BREW_PATH/bin/brew" ]]; then
  eval "$("$BREW_PATH/bin/brew" shellenv)"
fi

# Homebrew command-not-found integration
if [[ -n $HOMEBREW_PREFIX && -r $HOMEBREW_PREFIX/Library/Taps/homebrew/homebrew-command-not-found/handler.sh ]]; then
  source "$HOMEBREW_PREFIX/Library/Taps/homebrew/homebrew-command-not-found/handler.sh"

  # Wrap to silence auto-update during command-not-found suggestions
  if typeset -f command_not_found_handler >/dev/null \
     && ! typeset -f _command_not_found_handler_orig >/dev/null
  then
    functions -c command_not_found_handler _command_not_found_handler_orig
    command_not_found_handler() {
      HOMEBREW_NO_AUTO_UPDATE=1 _command_not_found_handler_orig "$@"
    }
  fi
fi

# ------------------------- History & shell behavior --------------------------

set -o allexport
# HISTFILE="$HOME/.zsh_history"
HISTFILE="$XDG_STATE_HOME/zsh/history"
HISTSIZE=200000
SAVEHIST=200000
LESSHISTFILE="$XDG_STATE_HOME/less/history"
set +o allexport

# --- History options ---
setopt HIST_IGNORE_ALL_DUPS        # remove older duplicates, keep the most recent
setopt HIST_IGNORE_SPACE           # commands starting with a space are not saved
setopt HIST_REDUCE_BLANKS          # collapse extra whitespace before saving
setopt HIST_VERIFY                 # show expanded history line before running
setopt EXTENDED_HISTORY            # save timestamps with each history entry
setopt APPEND_HISTORY              # append (not overwrite) on shell exit
setopt INC_APPEND_HISTORY          # write each command to history as it executes
setopt INC_APPEND_HISTORY_TIME     # preserve correct timestamp order
setopt HIST_EXPIRE_DUPS_FIRST      # expire duplicate entries first when trimming

# --- Safety/UX options ---
setopt NOCLOBBER                   # '>' won’t overwrite existing files
setopt RM_STAR_WAIT                # prompt before 'rm *' if many files
unsetopt BEEP                      # disable terminal bell
setopt EXTENDED_GLOB               # enable advanced globbing operators

# ------------------------ Functions: path & autoloading ----------------------

# Put our functions dir on fpath so autoload finds them
fpath=("$ZFUNCDIR" $fpath)

# Autoload each function (one function per file, filename == funcname)
if [[ -d "$ZFUNCDIR" ]]; then
  for _f in "$ZFUNCDIR"/*(.N); do
    autoload -Uz "${_f:t}"
  done
  unset _f
fi

# --------------------------- Tools that hook the shell -----------------------

# direnv (directory-local env)
if command -v direnv >/dev/null 2>&1; then
  eval "$(direnv hook zsh)"
fi

# VS Code shell integration (only inside VS Code terminal)
if [[ "$TERM_PROGRAM" == "vscode" ]] && command -v code >/dev/null 2>&1; then
  _vscode_zsh_integration="$(code --locate-shell-integration-path zsh 2>/dev/null)"
  [[ -r "$_vscode_zsh_integration" ]] && source "$_vscode_zsh_integration"
  unset _vscode_zsh_integration
fi

# Activate autojump plugin
# [ -f /usr/local/etc/profile.d/autojump.sh ] && . /usr/local/etc/profile.d/autojump.sh  
if [[ -n "$HOMEBREW_PREFIX" && -r "$HOMEBREW_PREFIX/etc/profile.d/autojump.sh" ]]; then
  source "$HOMEBREW_PREFIX/etc/profile.d/autojump.sh"
fi 

# --------------------------------- Oh My Zsh ---------------------------------

# Keep 'zsh-syntax-highlighting' LAST per its docs; include 'vi-mode'
ZSH_THEME="powerlevel10k/powerlevel10k"
plugins=(
  git
  direnv
  autojump
  vi-mode
  zsh-autosuggestions
  zsh-syntax-highlighting
)

# Load Oh My Zsh (silent if missing)
[[ -r "$ZSH/oh-my-zsh.sh" ]] && source "$ZSH/oh-my-zsh.sh"

# If OMZ is absent (e.g., fresh machine), ensure completion still works
if [[ ! -r "$ZSH/oh-my-zsh.sh" ]]; then
  autoload -Uz compinit && compinit -u
fi

# ---------------------------------- Aliases ----------------------------------

alias a='alias'
alias cp='cp -i'
alias mv='mv -i'
alias rm='rm -i'
alias lsa='ls -a'
alias h='history'
alias localhost='scutil --get LocalHostName'
alias killdock='killall -KILL Dock'
alias ss='save -s'
alias sshjj='ssh -i ~/.ssh/hostgator_rsa jj@108.179.232.68 -p2222'

# --- Git aliases ---
alias g='git --no-pager'
alias gs='g status -s'
alias ga='g add'
alias gci='g commit --verbose'
alias gco='g checkout'
alias gm='g merge --no-commit --no-ff'
alias gita='alias | grep git | grep'
alias glol="g log --graph --pretty='%Cred%h%Creset -%C(auto)%d%Creset %s %Cgreen(%ar) %C(bold blue)<%an>%Creset'"
alias savepy='gs | grep py | grep " M" | cut -d " " -f3 | xargs save -s'

# --- macsetup bare-repo aliases ---
alias c='git --no-pager --git-dir=$HOME/macsetup-bare --work-tree=$HOME'
alias cs='c status -s'
alias ca='c add'
alias ci='c commit --verbose'
alias co='c checkout'
alias cm='c merge --no-commit --no-ff'
alias cpu='c push'
alias clo='c log --oneline --decorate'
alias clog='c log --oneline --decorate --graph'
alias clol="c log --graph --pretty='%Cred%h%Creset -%C(auto)%d%Creset %s %Cgreen(%ar) %C(bold blue)<%an>%Creset'"
alias cls='c ls-tree --full-tree -r --name-only HEAD'

# ---------------------------- Powerlevel10k prompt ----------------------------

# To customize prompt, run `p10k configure` or edit ~/.config/zsh/p10k/.p10k.zsh
# [[ -f "$HOME/.p10k.zsh" ]] && source "$HOME/.p10k.zsh"
[[ -f "$XDG_CONFIG_HOME/zsh/p10k/.p10k.zsh" ]] && source "$XDG_CONFIG_HOME/zsh/p10k/.p10k.zsh"
