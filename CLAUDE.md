# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Overview

This is a macOS dotfiles and bootstrap repository using a **bare git repo workflow**. The bare repo (`~/macsetup-bare`) tracks dotfiles directly in `$HOME` without cluttering it with a `.git` directory. Configuration follows the **XDG Base Directory** specification.

## Key Commands

### Bootstrapping a new Mac

```bash
# Step 0: Go to your home directory
cd $HOME

# Step 1: Clone a bare repo to macsetup-bare
git clone --bare https://github.com/randie/macsetup.git macsetup-bare

# Step 2: Check out macsetup.sh from the bare repo
git --git-dir=$HOME/macsetup-bare --work-tree=$HOME checkout main -- bin/macsetup.sh

# Step 3: Run it
./bin/macsetup.sh --verbose
```

### Running the Bootstrap Script
```bash
# Full bootstrap on a new Mac
$HOME/bin/macsetup.sh

# With verbose output
$HOME/bin/macsetup.sh --verbose

# Test mode (no system-wide changes)
$HOME/bin/macsetup.sh --test-mode

# Show help
$HOME/bin/macsetup.sh --help
```

### Working with the Bare Repo
The `c` alias is used for all git operations on this repo:
```bash
alias c='git --no-pager --git-dir=$HOME/macsetup-bare --work-tree=$HOME'

c status -s     # cs - short status
c add <file>    # ca - stage file
c commit -v     # ci - verbose commit
c checkout      # co - checkout
c push          # cpu - push
c ls-tree --full-tree -r --name-only HEAD  # cls - list all tracked files
```

### Homebrew
```bash
# Install packages from Brewfile
brew bundle --file=$HOME/.config/brew/Brewfile

# Check Brewfile syntax
brew bundle check --file=$HOME/.config/brew/Brewfile
```

### Zsh Plugin Management (Antidote)
```bash
# Rebuild plugin bundle (after editing .zsh_plugins.txt)
antidote bundle < ~/.config/zsh/.zsh_plugins.txt > ~/.cache/zsh/.zsh_plugins.zsh

# Update all plugins
antidote update
```

## Architecture

### Bare Repo Workflow
- **Bare repo location**: `~/macsetup-bare` (no working tree)
- **Work tree**: `$HOME` (dotfiles checked out directly to home)
- Config hides untracked files: `status.showUntrackedFiles no`

### Directory Structure (XDG-Compliant)
```
$HOME/
├── macsetup-bare/              # bare git repo (internal git structures)
├── bin/                        # utility scripts (macsetup.sh, etc.)
├── .zshenv                     # earliest zsh startup - sets XDG vars, ZDOTDIR
└── .config/                    # $XDG_CONFIG_HOME
    ├── brew/Brewfile           # Homebrew packages, casks
    ├── gh/config.yml           # GitHub CLI config
    ├── iterm2/                 # iTerm2 plist settings (binary + XML)
    └── zsh/
        ├── .zprofile           # login shell - brew shellenv, PATH, EDITOR
        ├── .zshrc              # interactive shell - plugins, aliases, prompt
        ├── .zsh_plugins.txt    # Antidote plugin manifest
        ├── functions/          # autoloaded zsh functions
        └── p10k/.p10k.zsh      # Powerlevel10k theme config
```

### Zsh Startup Sequence
1. `.zshenv` - XDG setup, sets `ZDOTDIR=~/.config/zsh`
2. `.zprofile` (login only) - Homebrew env, PATH, EDITOR
3. `.zshrc` (interactive) - Antidote plugins, completions, aliases, P10K prompt

### macsetup.sh Flow
1. `pre_flight` - parse args, verify preconditions, ensure bare repo + Homebrew, backup existing config
2. `apply_my_config` - checkout dotfiles, `brew bundle`, configure iTerm2, suggest shell changes
3. `post_flight` - print summary and manual action reminders

### Exit Codes
- `0` - success
- `1` - generic failure
- `3` - Brewfile not found or unreadable
- `4` - brew bundle failed
- `64` - usage error (unknown flag)

## Shell Configuration

### Plugin Manager: Antidote
- Plugin manifest: `.config/zsh/.zsh_plugins.txt`
- Cached bundle: `.cache/zsh/.zsh_plugins.zsh` (auto-rebuilds when manifest is newer)
- Key plugins: git, direnv, autojump, vi-mode, zsh-autosuggestions, zsh-syntax-highlighting

### Theme: Powerlevel10k
- Config: `.config/zsh/p10k/.p10k.zsh`
- Instant prompt cached in `$XDG_CACHE_HOME`
- Reconfigure: `p10k configure`

### History
- Location: `$XDG_STATE_HOME/zsh/history` (~/.local/state/zsh/history)
- Size: 200,000 lines (memory + persistent)

## Branches

- **main** - Uses Powerlevel10k prompt
- **starship** - Alternative Starship prompt (experimental)

Switch with: `c switch main` or `c switch starship` (work tree must be clean)
