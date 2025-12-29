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

# ------------------------------ logging helpers -------------------------------

log_info()    { printf "${COLOR_INFO}[info] %s${COLOR_RESET}\n" "$*"; }
log_warn()    { printf "${COLOR_WARN}[warn] %s${COLOR_RESET}\n" "$*"; }
log_error()   { printf "${COLOR_ERROR}ERROR: %s${COLOR_RESET}\n" "$*" >&2; }
log_verbose() { [[ "$VERBOSE" == true ]] && printf "${COLOR_VERBOSE}[verbose] %s${COLOR_RESET}\n" "$*" || true; }

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

# --------------------------- ensure homebrew exists ---------------------------

ensure_homebrew() {
  if brew --version >/dev/null 2>&1; then
    log_verbose "Homebrew is already installed at: $(brew --prefix)"
    [[ -n "${HOMEBREW_PREFIX:-}" ]] || eval "$(brew shellenv)"
    return 0
  fi

  if [[ "$TEST_MODE" == true ]]; then
    log_warn "[TEST MODE] Skipping ensure_homebrew (because it would affect system-wide Homebrew)."
    return 0
  fi

  if curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh | /usr/bin/env bash; then
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
    log_warn "[TEST MODE] Skipping brew bundle in test mode because it would install system-wide packages."
    return 0
  fi

  log_info "Installing packages from $BREWFILE"
  if ! brew bundle --no-lock --file="$BREWFILE"; then
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

# ------------------------ apply my iterm2 configuration -----------------------

apply_iterm2_config() {
  # readonly variables (constants)
  local -r ITERM2_CONFIG_DIR="$CONFIG_DIR/iterm2"; mkdir -p "$ITERM2_CONFIG_DIR"
  local -r DOMAIN="com.googlecode.iterm2"
  local -r PLIST="$ITERM2_CONFIG_DIR/$DOMAIN.plist"
  local -r PLIST_XML="$ITERM2_CONFIG_DIR/$DOMAIN.plist.xml"
  local -r SYS_PLIST="$HOME/Library/Preferences/${DOMAIN}.plist"

  # Ensure iTerm2 is installed
  if [[ "$TEST_MODE" == true ]]; then
    if ! brew list --cask iterm2 > /dev/null 2>&1; then
      log_warn "[TEST MODE] iTerm2 is not installed. Skipping iTerm2 config in test mode."
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

  # Pick a source plist in priority order
  local plist_src=""
  if [[ -f "$PLIST" ]]; then
    plist_src="$PLIST"
  elif [[ -f "$PLIST_XML" ]]; then
    plist_src="$PLIST_XML"
  elif [[ -f "$SYS_PLIST" ]]; then
    log_warn "No $DOMAIN plist in $ITERM2_CONFIG_DIR. Falling back to $SYS_PLIST."
    plist_src="$SYS_PLIST"
  else
    log_warn "No existing $DOMAIN settings found. iTerm2 will start with defaults."
  fi

  # Apply settings if available
  if [[ -n "$plist_src" ]]; then
    log_info "Applying $DOMAIN settings from: $plist_src"

    if [[ "$plist_src" == "$PLIST_XML" ]]; then
      # Fast path: the plist source is already in XML format, so importing it directly
      defaults import "$DOMAIN" "$PLIST_XML" > /dev/null 2>&1 || log_warn "defaults import failed."
    else
      # Convert plist to XML because the defaults import command
      # works more reliably with XML-format plists
      local plist_xml_tmp
      plist_xml_tmp="${SCRATCH_DIR}/${DOMAIN}.${NOW}${RANDOM}.xml"

      if plutil -convert xml1 -o "$plist_xml_tmp" "$plist_src" > /dev/null 2>&1; then
        defaults import "$DOMAIN" "$plist_xml_tmp" > /dev/null 2>&1 || log_warn "defaults import failed."

        # Replace $PLIST_XML with $plist_xml_tmp if:
        # 1) $PLIST_XML doesn't exist, or
        # 2) $plist_xml_tmp is different from $PLIST_XML
        if [[ ! -f "$PLIST_XML" ]] || ! cmp -s "$plist_xml_tmp" "$PLIST_XML"; then
          if mv -f "$plist_xml_tmp" "$PLIST_XML" > /dev/null 2>&1; then
            log_verbose "Updated $PLIST_XML"
          else
            log_warn "Failed to update $PLIST_XML"
            [[ -f "$plist_xml_tmp" ]] && rm -f "$plist_xml_tmp"
          fi
        else
          rm -f "$plist_xml_tmp"
          log_verbose "No changes for $PLIST_XML; left as-is."
        fi
      else
        log_warn "Failed to convert plist to XML; attempting import of plist directly."
        defaults import "$DOMAIN" "$plist_src" > /dev/null 2>&1 || log_warn "defaults import of plist failed."

        # Best-effort: refresh tracked XML copy from source
        if [[ "$plist_src" != "$PLIST_XML" ]]; then
          plutil -convert xml1 -o "$PLIST_XML" "$plist_src" > /dev/null 2>&1 || log_warn "Failed to refresh $PLIST_XML"
        fi

        # Clean up any leftover temp file if it was created before conversion failed
        [[ -n "${plist_xml_tmp:-}" && -f "$plist_xml_tmp" ]] && rm -f "$plist_xml_tmp"
      fi
    fi

    # Also stage a copy where iTerm2 reads/writes by default
    # cp -f "$plist_src" "$SYS_PLIST" 2>/dev/null || true
  fi

  # Point iTerm2 at ITERM2_CONFIG_DIR for load/save of iterm2 settings
  defaults write "$DOMAIN" PrefsCustomFolder -string "$ITERM2_CONFIG_DIR"
  defaults write "$DOMAIN" LoadPrefsFromCustomFolder -bool true

  # Suppress the nag dialog about custom prefs not syncing
  defaults write "$DOMAIN" NoSyncNeverRemindPrefsChangesLostForFile -bool true

  # Flush settings cache
  killall -u "$USER" cfprefsd > /dev/null 2>&1 || true

  log_info "iTerm2 is set to load & save settings from: $ITERM2_CONFIG_DIR"
  log_info "Tracked XML plist updated (if possible): $PLIST_XML"
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
