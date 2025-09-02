# ==============================================================================
#                            Zsh Configuration
#                     (Intel + Apple Silicon friendly)
# ==============================================================================

# NOTE: This is an XDG-friendly Zsh config. XDG_* env vars are set in ~/.zshenv.

# -------------------- Powerlevel10k instant prompt (quiet) --------------------

# NOTE: This block should stay close to the top of .zshrc.
# Initialization code that requires console input (e.g. password prompts,
# [y/n] confirmations, etc.) should go above this block; everything else
# goes below.

# Enable Powerlevel10k's instant prompt but silence warnings about writing
# to stdout/stderr during .zshrc startup. Keeps startup fast/clean. Any
# messages must be deferred (e.g. via precmd) or logged since early output
# would garble the prompt.
typeset -g POWERLEVEL9K_INSTANT_PROMPT=quiet

# Use XDG cache for P10K’s instant prompt
if [[ -r "$XDG_CACHE_HOME/p10k-instant-prompt-${(%):-%n}.zsh" ]]; then
  source "$XDG_CACHE_HOME/p10k-instant-prompt-${(%):-%n}.zsh"
fi

# ----------------------------- Core environment ------------------------------

set -o allexport

# The amount of time (in hundredths of a second) that zsh waits
# after you hit ESC to see if more keys are coming.
# Lower values make vi-mode ESC feel snappier.
# Higher values give you more time to type ESC-prefixed combos.
KEYTIMEOUT=5

# Directory for your own zsh functions (one file per function).
# Added to fpath so functions can be autoloaded like built-ins.
ZFUNCDIR="$XDG_CONFIG_HOME/zsh/functions"

# Shell history (preserve a lot of history)
HISTFILE="$XDG_STATE_HOME/zsh/history"
HISTSIZE=200000  # max number of commands kept in memory per session
SAVEHIST=200000  # max number of commands saved to history file for persistence across sessions

# Oh-my-zsh
ZSH="$HOME/.oh-my-zsh"
ZSH_THEME="powerlevel10k/powerlevel10k"

set +o allexport

# --------------------------------- Homebrew ----------------------------------

# HOMEBREW_PREFIX (used below) is the path to Homebrew’s installations,
# and is set by `brew shellenv` in .zprofile.

# Homebrew command-not-found integration
_handler_sh="$HOMEBREW_PREFIX/Library/Taps/homebrew/homebrew-command-not-found/handler.sh"
if [[ -n $HOMEBREW_PREFIX && -r $_handler_sh ]]; then
  source "$_handler_sh"

  # Silence auto-update during command-not-found suggestions
  if typeset -f command_not_found_handler >/dev/null && ! typeset -f _handler_copy >/dev/null
  then
    functions -c command_not_found_handler _handler_copy
    command_not_found_handler() {
      HOMEBREW_NO_AUTO_UPDATE=1 _handler_copy "$@"
    }
  fi
fi
unset _handler_sh
unset _handler_copy

# ------------------------- History & shell behavior --------------------------

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

# Put functions dir on fpath so autoload finds them
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
alias ss='save -s'
alias killdock='killall -KILL Dock'
alias localhost='scutil --get LocalHostName'
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
