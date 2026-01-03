#!/usr/bin/env bash
# ------------------------------------------------------------------------------
# macsetup.sh — Bootstrap a new macOS (Intel or Apple Silicon) machine
# ------------------------------------------------------------------------------
#
# What this script does (step-by-step):
#   1) pre_flight:
#        • parse_args — parse commandline arguments and configure behavior
#        • setup_colors — apply color settings (must be called after parse_args)
#        • ensure_preconditions — verify we are on macOS, Xcode CLT exist, etc.
#        • ensure_bare_repo — verify a bare Git repo exists at $HOME/macsetup-bare
#        • ensure_homebrew — verify that Homebrew is installed; install if needed
#        • backup_existing_config — back up any tracked files that already exist
#   2) apply_my_config:
#        • checkout files from the bare repo into $HOME
#        • brew_install_packages - brew install packages listed in $BREWFILE
#        • apply_iterm2_config - import and point iTerm2 at tracked plist/config dir
#        • chsh_to_zsh - set login shell to Homebrew zsh
#   3) post_flight:
#        • ensure_postconditions — verify that the post-flight conditions are met
#        • wrap_up_message — print a wrap-up message
#        • print_manual_actions_summary — print a summary of manual actions required
#
# Colorized logging:
#   • Log levels:
#       [info]    -> green
#       [warn]    -> yellow
#       ERROR:    -> red
#       [verbose] -> white (high contrast)
#   • Colors are enabled once in pre_flight() by setup_colors():
#       - Colors require a TTY ( [[ -t 1 ]] ) and a working `tput`
#       - Pass --no-color to disable colorized output
#
# Safety & repeatability:
#   • Tracked files that already exist in $HOME are backed up before they get replaced
#   • Re-running converges to the same state (whatever is in the bare repo)
#
# Usage:
#   macsetup.sh [--test-mode|-t] [--verbose|-v] [--no-color] [--help|-h]
#
# Exit codes:
#   0  success
#   1  generic failure
#   3  brew bundle failed - Brewfile not found or unreadable
#   4  brew bundle failed - brew bundle did not complete successfully
#  64  usage error (unknown flag)
#
# ------------------------------------------------------------------------------

# Fail-fast settings:
#   -E  ensure ERR traps propagate in functions/subshells
#   -e  stop on the first error
#   -u  error on unset variables
#   -o  pipefail  catch errors in pipelines
set -Eeuo pipefail

# This trap is executed when any command in the script fails;
# it provides a more detailed error message with the file name,
# line number, failed command, and exit code.
trap 'rc=$?; cmd=${BASH_COMMAND:-unknown}; printf "ERROR! %s failed at line %s while running: %s (exit %s).\n" "${BASH_SOURCE[0]}" "${LINENO}" "${cmd}" "${rc}" >&2; exit "$rc"' ERR

# ---------------------------------- globals -----------------------------------

# Setting these color defaults here so logging works even before setup_colors is called,
# i.e. avoids "unbound variable" errors when logging before setup_colors is called.
COLOR_INFO=""
COLOR_WARN=""
COLOR_ERROR=""
COLOR_VERBOSE=""
COLOR_RESET=""
NO_COLOR=false

VERBOSE=false
TEST_MODE=false
MANUAL_ACTIONS=()

readonly NOW="$(date +%y%m%d%H%M)"
readonly MACSETUP="macsetup"
# readonly GITHUB_REPO="git@github.com:randie/$MACSETUP.git"
readonly BARE_REPO="$HOME/$MACSETUP-bare"
readonly CONFIG_DIR="$HOME/.config"
readonly BREWFILE="$CONFIG_DIR/brew/Brewfile"
readonly SCRATCH_DIR="$HOME/$MACSETUP-scratch"; mkdir -p "$SCRATCH_DIR"
readonly BACKUP_TAR="$SCRATCH_DIR/${MACSETUP}-backup-${NOW}.tar"

# ----------------------------------- usage ------------------------------------

usage() {
  cat << 'EOF'
Usage: macsetup.sh [--test-mode|-t] [--verbose|-v] [--no-color] [--help|-h]

Options:
  -t, --test-mode Run in test mode (no changes to shared/system state)
  -v, --verbose   Print extra diagnostic output
  --no-color      Disable colorized output
  -h, --help      Show this help and exit
EOF
}

# ------------------------------ logging helpers -------------------------------

log_info()    { printf "${COLOR_INFO}[info] %s${COLOR_RESET}\n" "$*"; }
log_warn()    { printf "${COLOR_WARN}[warn] %s${COLOR_RESET}\n" "$*"; }
log_error()   { printf "${COLOR_ERROR}ERROR: %s${COLOR_RESET}\n" "$*" >&2; }
log_verbose() { [[ "$VERBOSE" == true ]] && printf "${COLOR_VERBOSE}[verbose] %s${COLOR_RESET}\n" "$*" || true; }

# -------------------------------- args parsing --------------------------------

parse_args() {
  while [[ $# -gt 0 ]]; do
    case "$1" in
      -t | --test-mode)
        TEST_MODE=true
        shift
        ;;
      -v | --verbose)
        VERBOSE=true
        shift
        ;;
      --no-color)
        NO_COLOR=true
        shift
        ;;
      -h | --help)
        usage
        exit 0
        ;;
      --)
        shift
        break
        ;;
      *)
        log_error "Unknown option: $1"
        usage
        exit 64
        ;;
    esac
  done
}

# -------------------------- pre- and post-conditions --------------------------

ensure_preconditions() {
  # 1) Running on macOS
  if [[ "$(uname -s)" != "Darwin" ]]; then
    log_error "This script targets macOS machines only. Detected $(uname -s)."
    exit 1
  fi

  local fail=0

  # 2) Xcode Command Line Tools installed
  if [[ ! -x /usr/bin/xcode-select ]] || ! /usr/bin/xcode-select -p >/dev/null 2>&1; then
    log_error $'Xcode Command Line Tools are required.\nInstall: xcode-select --install'
    fail=1
  fi

  # 3) Tools needed by Homebrew are available
  local -a required_tools=(git curl)
  local -a missing_tools=()
  local t
  for t in "${required_tools[@]}"; do
    command -v "$t" >/dev/null 2>&1 || missing_tools+=("$t")
  done
  if ((${#missing_tools[@]})); then
    log_error "Missing tools: ${missing_tools[*]}"
    fail=1
  fi

  # 4) HOME directory is writable
  if [[ ! -w "$HOME" ]]; then
    log_error "\$HOME ($HOME) is not writable"
    fail=1
  fi

  if ((fail)); then
    log_error "Preconditions are not met. Fix the above and re-run."
    exit 1
  fi
}

ensure_postconditions() {
  : # TODO: implement
}

# ----------------------- colors (conditionally enabled) -----------------------

setup_colors() {
  # Conditionally enable colors if:
  # - NO_COLOR is not true (i.e. --no-color flag not passed)
  # - stdout is a TTY (i.e. not redirected to a file)
  # - tput is available (i.e. a terminal is connected)
  if [[ "$NO_COLOR" != true ]] && [[ -t 1 ]] && command -v tput >/dev/null 2>&1; then
    COLOR_INFO=$(tput setaf 2)    # green
    COLOR_WARN=$(tput setaf 3)    # yellow
    COLOR_ERROR=$(tput setaf 1)   # red
    COLOR_VERBOSE=$(tput setaf 7) # white (high-contrast)
    COLOR_RESET=$(tput sgr0)
  fi
}

# --------------------------- ensure homebrew exists ---------------------------

ensure_homebrew() {
  if brew --version >/dev/null 2>&1; then
    log_verbose "Homebrew is already installed at: $(brew --prefix)"
    [[ -n "${HOMEBREW_PREFIX:-}" ]] || eval "$(brew shellenv)"
    return 0
  fi

  if [[ "$TEST_MODE" == true ]]; then
    log_warn "[TEST MODE] Skipping ensure_homebrew in test mode."
    return 0
  fi

  # IMPORTANT: Don't pipe the installer into a shell, because that makes stdin a pipe
  # (not a TTY) and Homebrew will switch to non-interactive mode.
  # if curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh | /usr/bin/env bash; then
  if /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"; then
    if command -v brew > /dev/null 2>&1; then
      log_verbose "Homebrew installed successfully at: $(brew --prefix)"
      [[ -n "${HOMEBREW_PREFIX:-}" ]] || eval "$(brew shellenv)"
    else
      local found=""
      for b in /opt/homebrew/bin/brew /usr/local/bin/brew; do
        if [[ -x "$b" ]]; then
          eval "$($b shellenv)"
          found="$b"
          break
        fi
      done
      if [[ -z "$found" ]]; then
        log_error "Homebrew installed but brew command not found in PATH or in standard locations."
        exit 1
      else
        log_verbose "brew found at: $found"
      fi
    fi
  else
    log_error "Homebrew installation failed"
    exit 1
  fi
}

# --------------------------- brew install packages ----------------------------

brew_install_packages() {
  if [[ ! -r "$BREWFILE" ]]; then
    log_error "Brewfile not found or unreadable: $BREWFILE"
    exit 3
  fi

  if [[ "$TEST_MODE" == true ]]; then
    log_warn "[TEST MODE] Skipping brew bundle in test mode."
    return 0
  fi

  log_info "Installing packages from $BREWFILE"
  if ! brew bundle --file="$BREWFILE"; then
    log_error "brew bundle did not complete successfully."
    exit 4
  fi
}

# -------------------------- ensure bare repo exists ---------------------------

ensure_bare_repo() {
  local commit branch

  if [[ -d "$BARE_REPO" && -d "$BARE_REPO/objects" ]]; then
    log_verbose "Bare repo exists @ $BARE_REPO"
  else
    # If you're running this script, then a bare repo should already exist
    # in $HOME/macsetup-bare since this script would have been checked out
    # from that bare repo (if instructions in README.md were followed).
    log_error "Bare repo does not exist @ $BARE_REPO"
    exit 1
  fi

  if [[ "$VERBOSE" == true ]]; then
    commit="$(git --git-dir="$BARE_REPO" rev-parse --short HEAD)"
    branch="$(git --git-dir="$BARE_REPO" symbolic-ref -q --short HEAD || echo "DETACHED")"
    log_verbose "Bare repo ready @ $BARE_REPO (commit: ${commit}, branch: ${branch})"
  fi
}

# --------------------------- backup existing config ---------------------------

backup_existing_config() {(
  # NOTE: The parens enclosing this function creates a subshell
  # and runs this function in the subshell, so cd's are confined
  # to the subshell.

  local -r TRACKED_FILES="$SCRATCH_DIR/tracked-files.txt"
  local -r EXISTING_TRACKED_FILES="$SCRATCH_DIR/existing-tracked-files.txt"

  cd "$HOME"

  # List tracked files, excluding README* files
  # git --no-pager --git-dir="$BARE_REPO" ls-tree --full-tree -r --name-only HEAD \
  #   | grep -Ev '^(README($|\.md$)|macsetup\.sh$)' > "$TRACKED_FILES"
  git --no-pager --git-dir="$BARE_REPO" ls-tree --full-tree -r --name-only HEAD > "$TRACKED_FILES"

  # List which of those tracked files already exist
  while IFS= read -r f; do
    [ -e "$f" ] && echo "$f"
  done < "$TRACKED_FILES" > "$EXISTING_TRACKED_FILES"

  if [[ -s "$EXISTING_TRACKED_FILES" ]]; then
    # Create a backup tarball rooted at $HOME (entries are relative paths)
    tar cf "$BACKUP_TAR" -T "$EXISTING_TRACKED_FILES"
    log_verbose "Created backup: $BACKUP_TAR"

    # Remove existing tracked files that were backed up to $BACKUP_TAR
    # for f in $(tar tf $BACKUP_TAR); do
    #   [[ -e $f ]] && rm -f $f
    # done
    tar tf "$BACKUP_TAR" | while IFS= read -r f; do
      [[ -e "$f" ]] && rm -f -- "$f"
    done
    log_verbose "Removed existing tracked files"
  else
    log_verbose "No existing tracked files to back up."
  fi
);}

# --------------------------- manual actions helpers ---------------------------

add_manual_action() { MANUAL_ACTIONS+=("$1"); }

print_manual_actions_summary() {
  if ((${#MANUAL_ACTIONS[@]})); then
    log_warn "Manual follow-up actions required:"
    local action
    for action in "${MANUAL_ACTIONS[@]}"; do
      printf "  - %s\n" "$action"
    done
  fi
}

# ------------------------ apply my iterm2 configuration -----------------------

apply_iterm2_config() {

  # ----------------------------------------------------------------------------
  # Configure iTerm2 to load (and save) its preferences/settings from:
  #   ~/.config/iterm2/com.googlecode.iterm2.plist
  #
  # What this function does:
  #   1) Ensures iTerm2 is installed (skips the config part in TEST_MODE).
  #   2) Enforces custom prefs mode by setting:
  #        - LoadPrefsFromCustomFolder = true
  #        - PrefsCustomFolder = ~/.config/iterm2
  #   3) Checks whether the custom prefs folder exists.
  #   4) Checks whether the canonical plist exists in that folder.
  #      - If missing, logs a warning and adds a manual action (import + Save Now).
  #   5) Suppresses the non-critical iTerm2 warning about custom prefs not syncing.
  #   6) Instructs relaunch if iTerm2 is running.
  # ----------------------------------------------------------------------------

  local -r DOMAIN="com.googlecode.iterm2"
  local -r ITERM2_CONFIG_DIR="$CONFIG_DIR/iterm2"
  local -r PLIST="$ITERM2_CONFIG_DIR/$DOMAIN.plist"

  # Ensure iTerm2 is installed
  if [[ "$TEST_MODE" == true ]]; then
    if ! brew list --cask iterm2 > /dev/null 2>&1; then
      log_warn "[TEST MODE] iTerm2 is not installed. Skipping iTerm2 install and config in test mode."
      return 0
    fi
    log_verbose "iTerm2 is already installed."
    log_warn "[TEST MODE] Skipping iTerm2 config in test mode."
    return 0
  else
    if ! brew list --cask iterm2 > /dev/null 2>&1; then
      log_info "Installing iTerm2 (Homebrew cask)"
      brew install --cask iterm2
    else
      log_verbose "iTerm2 already installed"
    fi
  fi

  # Specify custom prefs mode and folder path.
  defaults write "$DOMAIN" LoadPrefsFromCustomFolder -bool true
  defaults write "$DOMAIN" PrefsCustomFolder -string "$ITERM2_CONFIG_DIR"

  # Suppress the nag dialog about custom prefs not syncing.
  defaults write "$DOMAIN" NoSyncNeverRemindPrefsChangesLostForFile -bool true

  # Confirm the custom prefs folder and plist exist.
  if [[ -d "$ITERM2_CONFIG_DIR" ]]; then
    if [[ -f "$PLIST" ]]; then
      log_verbose "Found canonical iTerm2 prefs file: $PLIST"
    else
      log_warn "Canonical iTerm2 prefs file is missing: $PLIST"
      log_warn "In external-prefs mode, iTerm2 will start with defaults until this file exists."
      add_manual_action "Open iTerm2 → Settings → General → Preferences, confirm it is set to load prefs from: $ITERM2_CONFIG_DIR. If needed, import your .itermexport and click 'Save Now' to write $PLIST."
    fi
  else
    log_warn "iTerm2 prefs folder does not exist: $ITERM2_CONFIG_DIR"
    add_manual_action "Create $ITERM2_CONFIG_DIR and ensure $PLIST exists (e.g., open iTerm2, import your .itermexport, then click 'Save Now' to write $PLIST)."
  fi

  # Read back defaults intent flags as a non-authoritative sanity check.
  # This verifies that the custom-prefs mode and folder path were written.
  # Failure here does not necessarily indicate a problem, as the defaults
  # domain may not be materialized until iTerm2 is launched.

  local read_custom_folder=""
  local read_load_from_folder=""

  read_custom_folder="$(defaults read "$DOMAIN" PrefsCustomFolder 2>/dev/null || true)"
  read_load_from_folder="$(defaults read "$DOMAIN" LoadPrefsFromCustomFolder 2>/dev/null || true)"

  if [[ "$read_custom_folder" == "$ITERM2_CONFIG_DIR" && "$read_load_from_folder" == "1" ]]; then
    log_verbose "Confirmed iTerm2 external prefs mode is enabled and points to: $ITERM2_CONFIG_DIR"
  else
    log_warn "Could not definitively confirm iTerm2 external prefs settings via defaults read."
    log_warn "Expected: LoadPrefsFromCustomFolder=1 and PrefsCustomFolder=$ITERM2_CONFIG_DIR"
    log_warn "Got:      LoadPrefsFromCustomFolder=${read_load_from_folder:-<unset>} PrefsCustomFolder=${read_custom_folder:-<unset>}"
  fi

  log_info "iTerm2 is set to load & save settings from: $ITERM2_CONFIG_DIR"
  log_info "Canonical iTerm2 prefs file: $PLIST"
  add_manual_action "If iTerm2 is running, quit and relaunch it to apply the new iTerm2 settings."
}

# ------------------------- change login shell to zsh --------------------------

chsh_to_zsh() {
  local brew_prefix=""
  local zsh_path=""
  local current_shell=""
  local dscl_output=""

  # Determine Homebrew-installed zsh
  brew_prefix="$(brew --prefix 2>/dev/null || true)"
  zsh_path="${brew_prefix}/bin/zsh"

  if [[ -z "$brew_prefix" || ! -x "$zsh_path" ]]; then
    log_error "Homebrew-installed zsh not found at: $zsh_path"
    return 1
  fi

  # Determine the user's actual login shell via Directory Services
  dscl_output="$(dscl . -read "/Users/$USER" UserShell 2>/dev/null)"
  current_shell="$(awk 'NF==2 {print $2}' <<< "$dscl_output")"

  # Already Homebrew zsh? Nothing to do.
  if [[ "$current_shell" == "$zsh_path" ]]; then
    log_verbose "Login shell is already Homebrew zsh: $current_shell"
    return 0
  fi

  # If Homebrew zsh is NOT in /etc/shells, tell the user how to add it.
  if ! grep -qx "$zsh_path" /etc/shells 2>/dev/null; then
    add_manual_action "Add Homebrew zsh ($zsh_path) to /etc/shells: echo \"$zsh_path\" | sudo tee -a /etc/shells >/dev/null"
  fi

  # One clean "chsh" message, outside the if
  add_manual_action "Change your login shell to Homebrew zsh: chsh -s \"$zsh_path\""
}

# --------------------------- apply my configuration ---------------------------

apply_my_config() {
  # Hide untracked files in status
  git --git-dir="$BARE_REPO" --work-tree="$HOME" config --local status.showUntrackedFiles no

  # Check out dotfiles from the bare repo into $HOME
  if git --git-dir="$BARE_REPO" --work-tree="$HOME" checkout -f; then
    brew_install_packages
    apply_iterm2_config
    chsh_to_zsh
  else
    log_error "Failed to checkout dotfiles from the bare repo into $HOME"
    exit 1
  fi
}

# ---------------------------------- wrap up -----------------------------------

wrap_up_message() {
  local summary details repo_commit repo_branch

  summary="$(cat << EOF
Done!
Handy alias for working with your bare repo:
  alias c='git --no-pager --git-dir=$BARE_REPO --work-tree=$HOME'
  Example: c status -s
EOF
)"
  log_info "$summary"

  if [[ "$VERBOSE" == true ]]; then
    # Report the current local bare repo state to avoid referencing an undefined BRANCH var
    repo_commit="$(git --git-dir="$BARE_REPO" rev-parse --short HEAD 2> /dev/null || true)"
    repo_branch="$(git --git-dir="$BARE_REPO" symbolic-ref -q --short HEAD 2> /dev/null || echo DETACHED)"
    details="$(cat <<EOF

BARE REPO   : $BARE_REPO
REPO COMMIT : $repo_commit
REPO BRANCH : $repo_branch
BREW PREFIX : $(brew --prefix)
BACKUP TAR  : $BACKUP_TAR
EOF
)"
    log_verbose "$details"
  fi
}

# ---------------------------- pre- and post-flight ----------------------------

pre_flight() {
  parse_args "$@"
  setup_colors
  ensure_preconditions
  ensure_bare_repo
  ensure_homebrew
  backup_existing_config
}

post_flight() {
  ensure_postconditions
  wrap_up_message
  print_manual_actions_summary
}

#=======================#
#                       #
#    M A I N L I N E    #
#                       #
#=======================#

# Run only if script is *executed* directly, i.e. not sourced
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
  pre_flight "$@"
  apply_my_config    # all the heavy lifting to configure this Mac happens here
  post_flight
fi
