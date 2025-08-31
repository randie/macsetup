# ==============================================================================
#                            Zsh Configuration
#                     (Intel + Apple Silicon friendly)
# ==============================================================================

# -------------------- Powerlevel10k instant prompt (quiet) --------------------

typeset -g POWERLEVEL9K_INSTANT_PROMPT=quiet

# Ensure XDG defaults exist even if ~/.zshenv didn’t run
[[ -z $XDG_CONFIG_HOME ]] && XDG_CONFIG_HOME="$HOME/.config"
[[ -z $XDG_DATA_HOME   ]] && XDG_DATA_HOME="$HOME/.local/share"
[[ -z $XDG_CACHE_HOME  ]] && XDG_CACHE_HOME="$HOME/.cache"

if [[ -r "$XDG_CACHE_HOME/p10k-instant-prompt-${(%):-%n}.zsh" ]]; then
  source "$XDG_CACHE_HOME/p10k-instant-prompt-${(%):-%n}.zsh"
fi

# ----------------------------- Core environment ------------------------------

# Export env vars without repeating `export`
set -o allexport

# zsh directories (ZDOTDIR is set in ~/.zshenv; this file lives under $ZDOTDIR)
[[ -z $ZFUNCDIR ]] && ZFUNCDIR="$XDG_CONFIG_HOME/zsh/functions"

# Oh My Zsh remains until we migrate
[[ -z $ZSH ]] && ZSH="$HOME/.oh-my-zsh"

# Editors, pager, path
[[ -z $KEYTIMEOUT ]] && KEYTIMEOUT=5
[[ -z $VISUAL     ]] && VISUAL="${EDITOR:-vim}"
FCEDIT="$VISUAL"
[[ -z $PAGER      ]] && PAGER="less"
PATH="$PATH:$HOME/bin"

# Hostname (portable, silent)
if [[ "$(uname -s)" == "Darwin" ]]; then
  HOSTNAME="$(scutil --get LocalHostName 2>/dev/null || hostname)"
else
  HOSTNAME="$(uname -n)"
fi

# Editor (prefer mvim when in a local GUI session)
if [[ -n "$SSH_CONNECTION" ]]; then
  EDITOR="vim"
else
  if command -v mvim >/dev/null 2>&1; then
    EDITOR="mvim"
  else
    EDITOR="vim"
  fi
fi
VISUAL="$EDITOR"

set +o allexport

# --------------------------------- Homebrew ----------------------------------

# Early so PATH/MANPATH are set before plugins/tools; quiet and arch-aware
if [[ "$(uname -s)" == "Darwin" ]]; then
  if [[ "$(uname -m)" == "arm64" && -x /opt/homebrew/bin/brew ]]; then
    BREW_PATH=/opt/homebrew/bin/brew        # Apple Silicon
  elif [[ -x /usr/local/bin/brew ]]; then
    BREW_PATH=/usr/local/bin/brew           # Intel
  fi
  if [[ -n "$BREW_PATH" ]]; then
    eval "$("$BREW_PATH" shellenv)"
  fi
fi

# Homebrew command-not-found integration (no auto-update noise)
if command -v brew >/dev/null 2>&1; then
  local _hb_repo _hb_cnf_handler
  _hb_repo="$(brew --repository 2>/dev/null)"
  _hb_cnf_handler="${_hb_repo}/Library/Taps/homebrew/homebrew-command-not-found/handler.sh"
  if [[ -r "$_hb_cnf_handler" ]]; then
    # shellcheck disable=SC1090
    source "$_hb_cnf_handler"
    if typeset -f command_not_found_handler >/dev/null 2>&1 \
       && ! typeset -f __command_not_found_handler_orig >/dev/null 2>&1; then
      functions -c command_not_found_handler __command_not_found_handler_orig
      command_not_found_handler() { HOMEBREW_NO_AUTO_UPDATE=1 __command_not_found_handler_orig "$@"; }
    fi
  fi
  unset _hb_repo _hb_cnf_handler
fi

# ------------------------- History & shell behavior --------------------------

set -o allexport
[[ -z $HISTFILE ]] && HISTFILE="$HOME/.zsh_history"
[[ -z $HISTSIZE ]] && HISTSIZE=200000
[[ -z $SAVEHIST ]] && SAVEHIST=200000
set +o allexport

setopt HIST_IGNORE_ALL_DUPS
setopt HIST_IGNORE_SPACE
setopt HIST_REDUCE_BLANKS
setopt HIST_VERIFY
setopt EXTENDED_HISTORY            # timestamps in history
setopt APPEND_HISTORY
setopt INC_APPEND_HISTORY          # write each command as you go
setopt INC_APPEND_HISTORY_TIME     # preserve timestamp ordering
setopt HIST_EXPIRE_DUPS_FIRST

setopt NOCLOBBER
setopt RM_STAR_WAIT
unsetopt BEEP                      # silence the terminal bell
setopt EXTENDED_GLOB               # nicer globbing

# ------------------------ Functions: path & autoloading ----------------------

# Ensure function dir exists and is on fpath (so autoload works)
fpath=("$ZFUNCDIR" $fpath)

# Autoload each function (one function per file, filename == funcname)
if [[ -d "$ZFUNCDIR" ]]; then
  for _f in "$ZFUNCDIR"/*(.N); do
    autoload -Uz "${_f:t}"
  done
  unset _f
fi

# --------------------------- Tools that hook the shell -----------------------

# direnv
if command -v direnv >/dev/null 2>&1; then
  eval "$(direnv hook zsh)"
fi

# VS Code shell integration (only inside VS Code terminal)
if [[ "$TERM_PROGRAM" == "vscode" ]] && command -v code >/dev/null 2>&1; then
  local _code_zsh_integration_path
  _code_zsh_integration_path="$(code --locate-shell-integration-path zsh 2>/dev/null)"
  [[ -n "$_code_zsh_integration_path" && -r "$_code_zsh_integration_path" ]] && source "$_code_zsh_integration_path"
  unset _code_zsh_integration_path
fi

# autojump (prefer brew path; fall back to common paths)
if command -v brew >/dev/null 2>&1; then
  local _aj_path
  _aj_path="$(brew --prefix)/etc/profile.d/autojump.sh"
  [[ -r "$_aj_path" ]] && source "$_aj_path"
  unset _aj_path
else
  [[ -r /opt/homebrew/etc/profile.d/autojump.sh ]] && source /opt/homebrew/etc/profile.d/autojump.sh
  [[ -r /usr/local/etc/profile.d/autojump.sh ]] && source /usr/local/etc/profile.d/autojump.sh
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
alias d='dirs -v'
alias dirs='dirs -v'
alias h='history'
alias hn='scutil --get LocalHostName'
alias killdock='killall -KILL Dock'
alias ss='save -s'          # requires external 'save' function/command
alias sshjj='ssh -i ~/.ssh/hostgator_rsa jj@108.179.232.68 -p2222'

# --- Git aliases ---
alias g='git --no-pager'
alias gs='git status -s'
alias gm='git merge --no-commit --no-ff'
alias gci='git commit --verbose'
alias gita='alias | grep git | grep'
alias glol="git --no-pager log --graph --pretty='%Cred%h%Creset -%C(auto)%d%Creset %s %Cgreen(%ar) %C(bold blue)<%an>%Creset'"

# --- myconfig bare-repo aliases ---
alias c='git --no-pager --git-dir=/Users/randie/myconfig-bare --work-tree=/Users/randie'
alias ca='c add'
alias ci='c commit --verbose'
alias co='c checkout'
alias cs='c status -s'
alias cpu='c push'
alias clo='c log --oneline --decorate'
alias clog='c log --oneline --decorate --graph'
alias clol="c log --graph --pretty='%Cred%h%Creset -%C(auto)%d%Creset %s %Cgreen(%ar) %C(bold blue)<%an>%Creset'"
alias cls='c ls-tree --full-tree -r --name-only HEAD'

# Helper to save modified *.py files (not a function; keep here)
savepy='gs | grep py | grep " M" | cut -d " " -f3 | xargs save -s'

# ---------------------------- Powerlevel10k prompt ----------------------------

[[ -f "$HOME/.p10k.zsh" ]] && source "$HOME/.p10k.zsh"

