# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Overview

This is a macOS dotfiles and bootstrap repository using a **bare git repo workflow**. The bare repo (`~/macsetup-bare`) tracks dotfiles directly in `$HOME` without cluttering it with a `.git` directory.

## Key Commands

### Running the Bootstrap Script
```bash
# Full bootstrap on a new Mac (after cloning bare repo)
$HOME/bin/macsetup.sh

# With verbose output
$HOME/bin/macsetup.sh -v

# Show help
$HOME/bin/macsetup.sh --help
```

### Working with the Bare Repo
The `c` alias is used for all git operations on this repo:
```bash
alias c='git --no-pager --git-dir=$HOME/macsetup-bare --work-tree=$HOME'

c status -s     # cs
c add <file>    # ca
c commit -v     # ci
c checkout      # co
c push          # cpu
c ls-tree --full-tree -r --name-only HEAD  # cls - list all tracked files
```

### Homebrew
```bash
# Install packages from Brewfile
brew bundle --file=$HOME/.config/brew/Brewfile

# Check Brewfile syntax
brew bundle check --file=$HOME/.config/brew/Brewfile
```

## Architecture

### Bare Repo Workflow
- **Bare repo location**: `~/macsetup-bare` (no working tree)
- **Work tree**: `$HOME` (dotfiles checked out directly to home)
- Config hides untracked files: `status.showUntrackedFiles no`

### Directory Structure
```
$HOME/
├── macsetup-bare/          # bare git repo (internal git structures)
├── bin/                    # utility scripts (macsetup.sh, etc.)
└── .config/
    ├── brew/Brewfile       # Homebrew packages, casks, vscode extensions
    ├── gh/config.yml       # GitHub CLI config
    ├── iterm2/             # iTerm2 plist settings
    └── zsh/
        ├── .zshrc          # main zsh config (XDG-friendly)
        ├── .zprofile       # login shell setup
        ├── functions/      # autoloaded zsh functions
        └── p10k/.p10k.zsh  # Powerlevel10k theme config
```

### macsetup.sh Flow
1. `init` - parse args, setup colors, verify Xcode CLT, create scratch dir
2. `ensure_bare_repo` - clone or verify `~/macsetup-bare`
3. `backup_existing_config` - tarball existing tracked files to `~/.scratch/macsetup/`
4. `apply_my_config` - checkout dotfiles, run `brew bundle`, configure iTerm2
5. `wrap_up` - print summary and alias reminder

### Exit Codes
- `0` - success
- `1` - generic failure
- `3` - brew bundle failed
- `64` - usage error (unknown flag)

## Shell Configuration

Uses XDG Base Directory spec:
- Config: `$XDG_CONFIG_HOME` (`~/.config`)
- Cache: `$XDG_CACHE_HOME` (`~/.cache`)
- State: `$XDG_STATE_HOME` (`~/.local/state`)

Zsh plugins (via Oh My Zsh): git, direnv, vi-mode, zsh-autosuggestions, zsh-syntax-highlighting

Theme: Powerlevel10k with instant prompt enabled
