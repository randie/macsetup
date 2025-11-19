# ==============================================================================
#                              Zsh Configuration
#                       (Intel + Apple Silicon friendly)
# ==============================================================================

# NOTE: This is an XDG-friendly Zsh config. XDG_* env vars are set in ~/.zshenv.

# ----------------------- Powerlevel10k instant prompt -------------------------

# NOTE: This block should stay close to the top of .zshrc.
# Initialization code that requires console input (e.g. password prompts,
# [y/n] confirmations, etc.) should go above this block; everything else
# goes below.

# Use XDG cache for P10K’s instant prompt
if [[ -r "$XDG_CACHE_HOME/p10k-instant-prompt-${(%):-%n}.zsh" ]]; then
  source "$XDG_CACHE_HOME/p10k-instant-prompt-${(%):-%n}.zsh"
fi

# ------------------------------ Core environment ------------------------------

# The amount of time (in hundredths of a second) that zsh waits
# after you hit ESC to see if more keys are coming.
# Lower values make vi-mode ESC feel snappier.
# Higher values give you more time to type ESC-prefixed combos.
typeset -g KEYTIMEOUT=5

# ------------------------------- History options ------------------------------

typeset -g HISTFILE="$XDG_STATE_HOME/zsh/history"
typeset -g HISTSIZE=200000  # max number of commands kept in memory per session
typeset -g SAVEHIST=200000  # max number of commands saved to history file for persistence across sessions

setopt HIST_IGNORE_ALL_DUPS        # remove older duplicates, keep the most recent
setopt HIST_IGNORE_SPACE           # commands starting with a space are not saved
setopt HIST_REDUCE_BLANKS          # collapse extra whitespace before saving
setopt HIST_VERIFY                 # show expanded history line before running
setopt EXTENDED_HISTORY            # save timestamps with each history entry
setopt APPEND_HISTORY              # append (not overwrite) on shell exit
setopt INC_APPEND_HISTORY          # write each command to history as it executes
setopt INC_APPEND_HISTORY_TIME     # preserve correct timestamp order
setopt HIST_EXPIRE_DUPS_FIRST      # expire duplicate entries first when trimming

# ----------------------------- Safety/UX options ------------------------------

setopt NOCLOBBER                   # '>' won’t overwrite existing files
setopt RM_STAR_WAIT                # prompt before 'rm *' if many files
setopt NO_BEEP                     # disable terminal bell
setopt EXTENDED_GLOB               # enable advanced globbing operators

# ---------------------------- Autoload functions ------------------------------

# Autoload functions in $XDG_CONFIG_HOME/zsh/functions
typeset -g ZFUNCDIR="$XDG_CONFIG_HOME/zsh/functions"
typeset -gU fpath=("$ZFUNCDIR" $fpath)
autoload -Uz $ZFUNCDIR/*(.N:t)

# -------------------------- Tools that hook the shell -------------------------

# direnv (directory-local env)
if command -v direnv >/dev/null 2>&1; then
  eval "$(direnv hook zsh)"
else
  _zshinit_log "direnv not found; directory-local environment hooks will not be active."
fi

# VS Code shell integration (only inside VS Code terminal)
if [[ "$TERM_PROGRAM" == "vscode" ]]; then
  if command -v code >/dev/null 2>&1; then
    _vscode_zsh_integration="$(code --locate-shell-integration-path zsh 2>/dev/null)"
    if [[ -r "$_vscode_zsh_integration" ]]; then
      source "$_vscode_zsh_integration"
    else
      _zshinit_log "VS Code zsh integration file not readable: '$_vscode_zsh_integration'."
    fi
    unset _vscode_zsh_integration
  else
    _zshinit_log "code not found; VS Code shell integration will not be active."
  fi
fi

# ------------------------------ Antidote ---------------------------------

# FYI: HOMEBREW_PREFIX is set in .zprofile (which runs before .zshrc)
_antidote_zsh="$HOMEBREW_PREFIX/opt/antidote/share/antidote/antidote.zsh" 
if [[ -r "$_antidote_zsh" ]]; then
  source "$_antidote_zsh"
else
  _zshinit_log "Antidote script not readable at '$_antidote_zsh'."
fi
unset _antidote_zsh

typeset -gA _antidote_paths
_antidote_paths[txt]="$XDG_CONFIG_HOME/zsh/.zsh_plugins.txt"
_antidote_paths[zsh]="$XDG_CACHE_HOME/zsh/.zsh_plugins.zsh"
mkdir -p "${_antidote_paths[zsh]:h}"

# Rebuild bundle only if bundle file doesn't exist, or plugins file is newer than bundle file
if [[ ! -r "${_antidote_paths[zsh]}" || "${_antidote_paths[txt]}" -nt "${_antidote_paths[zsh]}" ]]; then
  antidote bundle < "${_antidote_paths[txt]}" > "${_antidote_paths[zsh]}"
fi

if [[ -r "${_antidote_paths[zsh]}" ]]; then
  if ! source "${_antidote_paths[zsh]}"; then
    _zshinit_log "Sourcing Antidote bundle '${_antidote_paths[zsh]}' failed; zsh plugins may not be loaded."
  fi
else
  _zshinit_log "Antidote bundle not readable at '${_antidote_paths[zsh]}'; zsh plugins not loaded."
fi

# Initialize completions *after* plugins adjust $fpath
autoload -Uz compinit || _zshinit_log "autoload of compinit failed; completions may be broken."
compinit -u || _zshinit_log "compinit -u failed; command-line completions may not work."

# plugin zsh-history-substring-search key bindings)
# up/down arrows
bindkey '^[[A' history-substring-search-up
bindkey '^[[B' history-substring-search-down
# vi normal mode bindings (j/k)
bindkey -M vicmd 'k' history-substring-search-up
bindkey -M vicmd 'j' history-substring-search-down
# # emacs-style bindings
# bindkey -M emacs '^P' history-substring-search-up
# bindkey -M emacs '^N' history-substring-search-down

# ---------------------------------- Aliases -----------------------------------

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
alias glos='g log --graph --pretty="%Cred%h%Creset -%C(auto)%d%Creset %s %Cgreen(%ar) %C(bold blue)<%an>%Creset" --stat'
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
_p10k_zsh="$XDG_CONFIG_HOME/zsh/p10k/.p10k.zsh" 
[[ -f "$_p10k_zsh" ]] && source "$_p10k_zsh"
unset _p10k_zsh
