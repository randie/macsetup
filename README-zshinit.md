# Zsh Init Architecture & Dependency Guide

This document explains how all Zsh startup files in this configuration work together, what depends on what, the exact initialization order, performance considerations, and cross-platform behavior.

The files covered:

```
.zshenv
.config/zsh/.zprofile
.config/zsh/.zshrc
.config/zsh/.zlogin
.config/zsh/.zsh_plugins.txt
.config/zsh/p10k/.p10k.zsh
```

---

# 1. Dependency Map

## 1.1 `.zshenv`: Global, earliest environment

`.zshenv` runs for **every** zsh invocation—login, non-login, interactive, non-interactive.

It defines:

### **XDG base directories**

* `XDG_CONFIG_HOME=$HOME/.config`
* `XDG_CACHE_HOME=$HOME/.cache`
* `XDG_DATA_HOME=$HOME/.local/share`
* `XDG_STATE_HOME=$HOME/.local/state`

### **Global environment paths**

* `HOMEBREW_CACHE`
* `HOMEBREW_BUNDLE_FILE`
* `INPUTRC`
* `GIT_CONFIG_GLOBAL`

### **Zsh dotfile root**

* `ZDOTDIR=$XDG_CONFIG_HOME/zsh`

### **Logging**

* `ZSHINIT_LOG` → log file
* `ZSHINIT_NUM_ERRORS` → counter
* `_zshinit_log()` → logging function (only logs in login shells)

### **Debug tracing**

* `PS4='+%N:%i:${funcstack[1]:-main}>'`

### **Used by downstream files**

* `.zprofile`: uses logging + XDG
* `.zshrc`: uses logging + XDG
* Plugins + p10k: use XDG paths

`.zshenv` is the foundation of the whole system.

---

## 1.2 `.zprofile`: Login-only environment setup

Runs **once per login session**.

It sets:

### **Homebrew environment**

* Determines architecture (`arm64`, `x86_64`)
* Picks the correct Homebrew prefix (`/opt/homebrew` or `/usr/local`)
* Runs:

  ```
  eval "$("$brew_path/bin/brew" shellenv)"
  ```

  which sets:

  * `HOMEBREW_PREFIX`
  * `HOMEBREW_CELLAR`
  * `HOMEBREW_REPOSITORY`
  * `PATH`, `MANPATH`, `INFOPATH`

### **Editor, pager, hostname**

* `EDITOR`, `VISUAL`
* `LESSHISTFILE`
* `HOSTNAME` (macOS vs non-macOS logic)

### **Effect on other files**

* `.zshrc` uses `HOMEBREW_PREFIX` to load Antidote
* p10k + plugins rely on Homebrew packages being in PATH

---

## 1.3 `.zshrc`: Interactive shell setup

Runs for **every interactive shell** (both login and non-login).

It handles:

### **Prompt (p10k)**

* Instant prompt from `$XDG_CACHE_HOME`
* Full prompt from `$XDG_CONFIG_HOME/zsh/p10k`

### **Function paths**

* `ZFUNCDIR="$XDG_CONFIG_HOME/zsh/functions"`
* Updates `fpath`

### **direnv**

* Add hook if available

### **VS Code shell integration**

* Only when `TERM_PROGRAM=vscode`

### **Antidote (plugin manager)**

Depends on:

* `HOMEBREW_PREFIX` (set by `.zprofile` or fallback via `brew --prefix`)
* Antidote script at:

  ```
  $HOMEBREW_PREFIX/opt/antidote/share/antidote/antidote.zsh
  ```

Steps:

1. Resolve `HOMEBREW_PREFIX`
2. Source Antidote script (if readable)
3. Build plugin bundle if missing or out-of-date
4. Source plugin bundle
5. Log problems via `_zshinit_log`

### **Plugin-dependent bindings**

`history-substring-search` keybindings applied **only if** widgets are loaded:

```
if zle -l | grep -q history-substring-search-up; then ...
```

### **Completion system**

```
autoload -Uz compinit
compinit -u
```

### **Aliases**

Defined last.

---

## 1.4 `.zlogin`: After-login hook

Currently empty.

Runs only for **login + interactive shells**, after `.zshrc`.

You may place “welcome messages,” motd, session banners, or startup apps here.

---

## 1.5 `.zsh_plugins.txt`

List of Antidote-managed plugins. Typically includes:

* `zsh-users/zsh-history-substring-search`
* `zsh-users/zsh-autosuggestions`
* `zsh-users/zsh-syntax-highlighting`

Antidote uses this list to build a cached bundle.

---

## 1.6 `.p10k.zsh`

Your fully customized Powerlevel10k theme.

Loaded by `.zshrc`.

---

# 2. Startup Flow

Zsh has three major startup scenarios.

---

## 2.1 Login + interactive shell

Example: opening iTerm2 or Terminal.

Order:

1. `.zshenv`
2. `.zprofile`
3. `.zshrc`
4. `.zlogin`

This is the full initialization path.

---

## 2.2 Non-login interactive shell

Example: typing `zsh` inside an existing shell.

Order:

1. `.zshenv`
2. **NO `.zprofile`**
3. `.zshrc`
4. **NO `.zlogin`**

Here, your `.zshrc` fallback for `HOMEBREW_PREFIX` ensures Antidote still works.

---

## 2.3 Non-interactive shell (`zsh -c "cmd"`)

Order:

1. `.zshenv`
2. **NO `.zprofile`**
3. **NO `.zshrc`**
4. **NO `.zlogin`**

Plugins, completion, p10k, aliasing, keybindings, etc., do not load.
This is correct for scripts.

Your `_zshinit_log` also stays dormant because it only logs in login shells.

---

# 3. Performance Characteristics

### Heavy operations (correctly placed)

* `brew shellenv` → runs only in `.zprofile` (login only)
* `antidote bundle` → runs only when needed
* `compinit -u` → interactive only

### Light operations (run per shell)

* `zle -l | grep -q ...`
* `command -v ...`
* PATH adjustments
* Function directory adjustments

### Optimizations you already have

* No repeated PATH rebuilds
* No `brew shellenv` in `.zshrc`
* Plugin bundle caching
* Safe guards around plugin existence

Overall: **fast shells, minimal redundancy, good caching.**

---

# 4. Portability & Degradation Behavior

## macOS

Everything works as intended:

* Homebrew architecture detection
* `scutil` hostname logic
* Antidote via Homebrew package path
* p10k instant prompt caching

## Linux / other Unix

Graceful degradation:

* Homebrew not found → Antidote disabled
* Plugins disabled → shell still works
* Hostname falls back to `uname -n`

Nothing breaks. No infinite loops, hangs, or misconfigurations.

---

# 5. Summary of zsh startup files

Think of each file as responsible for a specific domain:

| File               | Purpose                                                                |
| ------------------ | ---------------------------------------------------------------------- |
| `.zshenv`          | Minimal core env, paths, logging, XDG, ZDOTDIR                         |
| `.zprofile`        | Login-time setup: Homebrew, PATH, EDITOR, hostname                     |
| `.zshrc`           | Interactive shell: plugins, direnv, VS Code hook, completions, aliases |
| `.zlogin`          | Post-login hooks (currently unused)                                    |
| `.zsh_plugins.txt` | Plugin manifest                                                        |
| `.p10k.zsh`        | Prompt theme config                                                    |
