# ==============================================================================
#  Zsh Configuration (Intel + Apple Silicon friendly)
# ==============================================================================

#  NOTE: Startup is SILENT to play nice with Powerlevel10k instant prompt.

# --- Powerlevel10k instant prompt ----------------------------------------------
# Recommended: keep P10K instant prompt quiet about init-time I/O
typeset -g POWERLEVEL9K_INSTANT_PROMPT=quiet

# --- Powerlevel10k instant prompt (must remain near top) -----------------------
if [[ -r "${XDG_CACHE_HOME:-$HOME/.cache}/p10k-instant-prompt-${(%):-%n}.zsh" ]]; then
  source "${XDG_CACHE_HOME:-$HOME/.cache}/p10k-instant-prompt-${(%):-%n}.zsh"
fi

# ==============================================================================
#  Core environment
# ==============================================================================

export ZSH="$HOME/.oh-my-zsh"

# Hostname (portable, silent)
if [[ "$(uname -s)" == "Darwin" ]]; then
  HOSTNAME="$(scutil --get LocalHostName 2>/dev/null || hostname)"
else
  HOSTNAME="$(uname -n)"
fi

# Make ESC combos snappy for vi-mode
export KEYTIMEOUT=5   # 1–15 is typical; tweak if ESC feels too sensitive

# Editor/Pager (silent)
if [[ -n "$SSH_CONNECTION" ]]; then
  export EDITOR="vim"
else
  if command -v mvim >/dev/null 2>&1; then
    export EDITOR="mvim"
  else
    export EDITOR="vim"
  fi
fi
export VISUAL="$EDITOR"
export FCEDIT="$EDITOR"
export PAGER="less"

# PATH additions (append user bin)
export PATH="$PATH:$HOME/bin"

# ==============================================================================
#  Homebrew (early so PATH, MANPATH, etc. are set before plugins/tools)
#  Also integrates Homebrew "command-not-found" with scoped no-auto-update.
#  NOTE: Silent during init to avoid P10K warnings.
# ==============================================================================
# Setup Homebrew shell environment (Apple Silicon first, then Intel)
if [ -x /opt/homebrew/bin/brew ]; then
  eval "$(/opt/homebrew/bin/brew shellenv)"   # Apple Silicon
elif [ -x /usr/local/bin/brew ]; then
  eval "$(/usr/local/bin/brew shellenv)"      # Intel Macs
fi

# Homebrew command-not-found integration (silent; correct path)
if command -v brew >/dev/null 2>&1; then
  _hb_repo="$(brew --repository 2>/dev/null)"
  _hb_cnf_handler="${_hb_repo}/Library/Taps/homebrew/homebrew-command-not-found/handler.sh"
  if [ -r "$_hb_cnf_handler" ]; then
    # shellcheck disable=SC1090
    source "$_hb_cnf_handler"
    if typeset -f command_not_found_handler >/dev/null 2>&1; then
      if ! typeset -f __command_not_found_handler_orig >/dev/null 2>&1; then
        functions -c command_not_found_handler __command_not_found_handler_orig
        command_not_found_handler() {
          HOMEBREW_NO_AUTO_UPDATE=1 __command_not_found_handler_orig "$@"
        }
      fi
    fi
  fi
  unset _hb_repo _hb_cnf_handler
fi

# ==============================================================================
#  History & shell behavior
# ==============================================================================
export HISTFILE="$HOME/.zsh_history"
export HISTSIZE=200000
export SAVEHIST=200000

setopt HIST_IGNORE_ALL_DUPS
setopt HIST_IGNORE_SPACE
setopt HIST_REDUCE_BLANKS
setopt HIST_VERIFY
setopt EXTENDED_HISTORY
setopt APPEND_HISTORY
setopt INC_APPEND_HISTORY
setopt HIST_EXPIRE_DUPS_FIRST

setopt NOCLOBBER
setopt RM_STAR_WAIT

# ==============================================================================
#  Tools that hook the shell (silent)
# ==============================================================================
# direnv (allow directory-local env changes)
if command -v direnv >/dev/null 2>&1; then
  eval "$(direnv hook zsh)"
fi

# VS Code shell integration (only in VS Code terminals)
if [[ "$TERM_PROGRAM" == "vscode" ]] && command -v code >/dev/null 2>&1; then
  _code_zsh_integration_path="$(code --locate-shell-integration-path zsh 2>/dev/null)"
  [[ -n "$_code_zsh_integration_path" && -r "$_code_zsh_integration_path" ]] && source "$_code_zsh_integration_path"
  unset _code_zsh_integration_path
fi

# autojump (portable: prefer brew --prefix; fall back to common paths) — silent
if command -v brew >/dev/null 2>&1; then
  _aj_path="$(brew --prefix)/etc/profile.d/autojump.sh"
  [ -r "$_aj_path" ] && source "$_aj_path"
  unset _aj_path
else
  [ -r /opt/homebrew/etc/profile.d/autojump.sh ] && source /opt/homebrew/etc/profile.d/autojump.sh
  [ -r /usr/local/etc/profile.d/autojump.sh ] && source /usr/local/etc/profile.d/autojump.sh
fi

# ==============================================================================
#  Oh My Zsh (themes & plugins) — place AFTER Homebrew/env so plugins see PATH
# ==============================================================================
ZSH_THEME="powerlevel10k/powerlevel10k"

# Keep 'zsh-syntax-highlighting' LAST per its docs; include 'vi-mode' to manage bindings.
plugins=(
  git
  direnv
  autojump
  vi-mode
  zsh-autosuggestions
  zsh-syntax-highlighting
)

# Load Oh My Zsh (silent if missing)
[ -r "$ZSH/oh-my-zsh.sh" ] && source "$ZSH/oh-my-zsh.sh"

# (No manual bindkey lines needed — vi-mode plugin handles vi keymaps)

# ==============================================================================
#  Aliases
# ==============================================================================
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
alias ss='save -s'          # requires a 'save' function/command if you use it
alias sshjj='ssh -i ~/.ssh/hostgator_rsa jj@108.179.232.68 -p2222'

# --- Git aliases ---
alias g='git --no-pager'
alias gs='git status -s'
alias gm='git merge --no-commit --no-ff'
alias gci='git commit --verbose'
alias gita='alias | grep git | grep'
alias glol="git --no-pager log --graph --pretty='%Cred%h%Creset -%C(auto)%d%Creset %s %Cgreen(%ar) %C(bold blue)<%an>%Creset'"

# --- macsetup bare-repo aliases ---
alias c='git --no-pager --git-dir=/Users/randie/macsetup-bare --work-tree=/Users/randie'
alias ca='c add'
alias ci='c commit --verbose'
alias co='c checkout'
alias cs='c status -s'
alias cpu='c push'
alias clo='c log --oneline --decorate'
alias clog='c log --oneline --decorate --graph'
alias clol="c log --graph --pretty='%Cred%h%Creset -%C(auto)%d%Creset %s %Cgreen(%ar) %C(bold blue)<%an>%Creset'"
alias cls='c ls-tree --full-tree -r --name-only HEAD'

# Helper to save modified *.py files (unchanged from your original)
savepy='gs | grep py | grep " M" | cut -d " "  -f3 | xargs save -s'

# ==============================================================================
#  Convenience Functions
# ==============================================================================
s() { echo "$HOME/save/$(date +%y%m%d)"; }

shred() {
  if [[ -z "$1" ]]; then echo "Usage: shred <filename>"; return 1; fi
  local file="$1"
  if [[ ! -f "$file" ]]; then echo "ERROR! '$file' is not a valid file."; return 1; fi
  local file_size block_count
  file_size=$(stat -f%z "$file" 2>/dev/null || stat -c %s "$file")
  block_count=$(( (file_size + 1048575) / 1048576 ))
  dd if=/dev/urandom of="$file" bs=1m count="$block_count" status=progress 2>/dev/null
  \rm -f "$file"
  echo "Poof! $file is gone."
}

dc() {
  local cmd="$1"; shift
  echo "╰─❯ docker-compose --env-file docker-compose.env ${cmd} --remove-orphans --build $*"
  docker-compose --env-file docker-compose.env "$cmd" --remove-orphans --build "$@"
}

dcsh() {
  if [[ -z "$1" ]]; then echo "Usage: dcsh <service>"; return 1; fi
  echo "╰─❯ docker-compose --env-file docker-compose.env exec ${1} /bin/bash"
  docker-compose --env-file docker-compose.env exec "$1" /bin/bash
}

# ==============================================================================
#  Diagnostics
# ==============================================================================
check-brew-setup() {
  echo ">>> Checking Homebrew + command-not-found integration"
  local prefix brew_bin handler
  prefix=$(brew --prefix 2>/dev/null)
  brew_bin=$(command -v brew 2>/dev/null)
  handler=$(typeset -f command_not_found_handler 2>/dev/null | grep -q HOMEBREW_NO_AUTO_UPDATE && echo OK || echo BROKEN)
  [[ -z "$prefix" || -z "$brew_bin" ]] && echo "❌ Homebrew not found" || {
    echo "✅ Homebrew prefix: $prefix"
    echo "✅ brew binary:    $brew_bin"
  }
  [[ "$handler" == "OK" ]] && echo "✅ command_not_found_handler wrapper is active" || echo "❌ command_not_found_handler is missing or unwrapped"
  echo; echo ">>> Testing missing command (foobar123)"; foobar123
}

fix-brew-setup() {
  echo ">>> Fixing Homebrew + command-not-found integration"
  if [ -x /opt/homebrew/bin/brew ]; then eval "$(/opt/homebrew/bin/brew shellenv)"
  elif [ -x /usr/local/bin/brew ]; then eval "$(/usr/local/bin/brew shellenv)"; fi
  if ! command -v brew >/dev/null 2>&1; then echo "❌ Homebrew not found; cannot continue."; return 1; fi
  local repo handler
  repo="$(brew --repository 2>/dev/null)"
  handler="$repo/Library/Taps/homebrew/homebrew-command-not-found/handler.sh"
  [ ! -r "$handler" ] && { echo "❌ handler not found at $handler"; echo "   (brew tap homebrew/command-not-found)"; return 1; }
  source "$handler"
  if typeset -f command_not_found_handler >/dev/null 2>&1; then
    if ! typeset -f __command_not_found_handler_orig >/dev/null 2>&1; then
      functions -c command_not_found_handler __command_not_found_handler_orig
      command_not_found_handler() { HOMEBREW_NO_AUTO_UPDATE=1 __command_not_found_handler_orig "$@"; }
      echo "✅ Wrapped command_not_found_handler"
    else echo "ℹ️  Wrapper already present"; fi
  else echo "❌ command_not_found_handler not defined"; return 1; fi
  echo; check-brew-setup 2>/dev/null || echo "⚠️  Run 'foobar123' to test manually."
}

# ==============================================================================
#  Conda (optional; switched to uv)
# ==============================================================================
my_conda_init() {
  __conda_setup="$('/usr/local/anaconda3/bin/conda' 'shell.zsh' 'hook' 2>/dev/null)"
  if [ $? -eq 0 ]; then eval "$__conda_setup"
  elif [ -f "/usr/local/anaconda3/etc/profile.d/conda.sh" ]; then . "/usr/local/anaconda3/etc/profile.d/conda.sh"
  else export PATH="/usr/local/anaconda3/bin:$PATH"; fi
  unset __conda_setup
}
# my_conda_init

# ==============================================================================
#  Powerlevel10k prompt
# ==============================================================================
[[ -f "$HOME/.p10k.zsh" ]] && source "$HOME/.p10k.zsh"

