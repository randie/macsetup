# ~/.zshenv - earliest zsh startup file (full XDG layout)

set -o allexport

[[ -z $XDG_CONFIG_HOME ]] && XDG_CONFIG_HOME="$HOME/.config"
[[ -z $XDG_DATA_HOME ]]   && XDG_DATA_HOME="$HOME/.local/share"
[[ -z $XDG_CACHE_HOME ]]  && XDG_CACHE_HOME="$HOME/.cache"

# Tell zsh to use ~/.config/zsh instead of $HOME
ZDOTDIR="$XDG_CONFIG_HOME/zsh"

set +o allexport
