# ~/.zshenv — earliest zsh startup file

set -o allexport

# XDG base directories
XDG_CONFIG_HOME="$HOME/.config"
XDG_CACHE_HOME="$HOME/.cache"
XDG_DATA_HOME="$HOME/.local/share"
XDG_STATE_HOME="$HOME/.local/state"

# XDG extras (nice-to-have)
# globally useful to both interactive and non-interactive shells
HOMEBREW_CACHE="$XDG_CACHE_HOME/Homebrew"
HOMEBREW_BUNDLE_FILE="$XDG_CONFIG_HOME/brew/Brewfile"
INPUTRC="$XDG_CONFIG_HOME/readline/inputrc"
GIT_CONFIG_GLOBAL="$XDG_CONFIG_HOME/git/config"

# Tell zsh where to find its dotfiles
ZDOTDIR="$XDG_CONFIG_HOME/zsh"

# Better xtrace prefix: file:line:function> (only used when you `set -x`)
PS4='+%N:%i:${funcstack[1]:-main}> '

set +o allexport
