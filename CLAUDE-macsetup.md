# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Overview

This is a macOS dotfiles and bootstrap repository using a **bare git repo workflow**. The bare repo (`~/macsetup-bare`) tracks dotfiles directly in `$HOME` without cluttering it with a `.git` directory. Configuration follows the **XDG Base Directory** specification.

## Key Commands

### Bootstrapping a new Mac

```bash
# Step 0: Go to your home directory
cd

# Step 1: Clone macsetup as a bare-repo in your home directory
git clone --bare https://github.com/randie/macsetup.git macsetup-bare

# Step 2: Check out macsetup.sh from the bare repo's main branch
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
The $HOME work tree was checked out from $HOME/macsetup-bare bare repo.
The `b` alias is used for all git operations on this repo ($HOME):
```bash
alias gitb='git --no-pager --git-dir=$HOME/macsetup-bare --work-tree=$HOME'
alias b='gitb'  

b status -s     # bss - short status
b add <file>    # ba - stage file
b commit -v     # bci - commit / checkin
b checkout      # bco - checkout
b push          # bp - push
b ls-tree --full-tree -r --name-only HEAD  # bls - list all tracked files
```

### Homebrew
```bash
# Check Brewfile syntax (i.e. make sure you have a valid Brewfile)
brew bundle check --file=$HOME/.config/brew/Brewfile

# Install packages from Brewfile
brew bundle --file=$HOME/.config/brew/Brewfile
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
- **Bare repo location**: `~/macsetup-bare` (this is the .git directory for the work tree, i.e. the actual repo)
- **Work tree**: `$HOME` (files checked out from ~/macsetup-bare directly to your home directory)
- untracked files are hidden: `status.showUntrackedFiles no`
- You can run the `bls` alias to see the list of tracked files
- To track a file that isn't already being tracked, run the following:
  - ba the-new-file              # add the new file to track
  - bci -m "track the-new-file"  # git commit the new file
  - bp                           # git push the new file to github

### Directory Structure (XDG-Compliant)
```
$HOME/
├── macsetup-bare/              # bare git repo (internal git structures)
├── bin/                        # utility scripts (macsetup.sh, etc.)
├── .zshenv                     # zsh config starts here - sets XDG-*, ZDOTDIR environment vars
├── .local                      # contains local state, cache, history files
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
1. `.zshenv` - sets XDG-* env vars, sets `ZDOTDIR=$XDG_CONFIG_HOME/zsh`
2. `.zprofile` (login shell only) - sets Homebrew, PATH, EDITOR env vars
3. `.zshrc` (interactive shells) - Antidote plugins, completions, aliases, P10K prompt

### macsetup.sh Flow
1. `pre_flight` - parse args, verify preconditions, ensure bare repo + Homebrew, backup existing config
2. `apply_my_config` - checkout config files, `brew bundle`, configure iTerm2, suggest shell changes
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
- Cached bundle: `.cache/zsh/.zsh_plugins.zsh` (auto-rebuilds when plugin manifest is newer)
- Key plugins: git, direnv, autojump, vi-mode, zsh-autosuggestions, zsh-syntax-highlighting

### Theme: Powerlevel10k
- Config: `.config/zsh/p10k/.p10k.zsh`
- Instant prompt cached in `$XDG_CACHE_HOME`
- To reconfigure run: `p10k configure`

### Zsh command line history
- Location: `$XDG_STATE_HOME/zsh/history` (~/.local/state/zsh/history)
- Size: 200,000 lines (memory + persistent)

## Git repo branches

- **main** - Uses Powerlevel10k prompt
- **starship** - Uses Starship prompt (alternative prompt, WIP)

Switching branches:
- `gitb switch main`
- `gitb switch starship`    # work tree must be clean

