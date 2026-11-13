#------------------------------------------------
# These files are git source-controlled [261112]
#------------------------------------------------

.config/brew/Brewfile
.config/brew/Brewfile_arm64
.config/brew/Brewfile_x86_64
.config/brew/README.txt

.config/homebrew -> brew

.config/gh/config.yml
.config/gh/hosts.yml

.config/git/config

.config/iterm2/README
.config/iterm2/beethoven-iterm2-settings.itermexport
.config/iterm2/com.googlecode.iterm2.plist
.config/iterm2/com.googlecode.iterm2.plist.xml

.config/zsh/.zlogin
.config/zsh/.zprofile
.config/zsh/.zsh_plugins.txt
.config/zsh/.zshenv
.config/zsh/.zshrc

.config/zsh/functions/brewfile
.config/zsh/functions/check-brew-setup
.config/zsh/functions/cpc
.config/zsh/functions/dc
.config/zsh/functions/dcsh
.config/zsh/functions/fix-brew-setup
.config/zsh/functions/my_conda_init
.config/zsh/functions/my_history
.config/zsh/functions/s
.config/zsh/functions/shred

.config/zsh/p10k/.p10k.zsh


#-------------------------------------------------------------
# These files are not git source-controlled, and shouldn't be.
#-------------------------------------------------------------

# This file is managed by 1Password, leave it alone.
- .config/1Password/telemetry-enabled

# TODO: These do not belong in ~/.config. Move them to the appropriate XDG location.
- .config/zsh/.zcompcache/brew_all_commands
- .config/zsh/.zcompcache/brew_formulae
- .config/zsh/.zsh_sessions/

# TODO: Remove. XDG zsh history file is already set to ~/.local/state/zsh/history .
- .config/zsh/.zsh_history_

