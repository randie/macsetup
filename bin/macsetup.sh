#!/usr/bin/env bash
# ==============================================================================
# macsetup.sh — Bootstrap a new macOS (Intel or Apple Silicon) machine
# ==============================================================================
#
# What this script does (step-by-step):
#   1) init:
#        • parse_args        — parse flags and configure behavior
#        • setup_colors      — apply color settings once (after flags parsed)
#        • ensure_xcode_clt  — verify Xcode Command Line Tools are present; exit with instructions if not
#        • mkdir -p          — ensure scratch directory exists
#   2) ensure_bare_repo:
#        • make sure $HOME/macsetup.git exists, clone if missing
#   3) backup_existing_config:
#        • get list of TRACKED_FILES excluding README*
#        • determine which of the tracked files already exist → EXISTING_TRACKED_FILES
#        • back up EXISTING_TRACKED_FILES to $SCRATCH_DIR/macsetup-backup-YYMMDDHHMM.tar
#        • remove backed-up EXISTING_TRACKED_FILES to avoid checkout conflicts
#   4) apply_my_config:
#        • check out dotfiles from the bare repo into $HOME (hide untracked files in status)
#        • brew_install_packages (brew install packages listed in $BREWFILE)
#        • install_oh_my_zsh     (placeholder; no-op except a warning)
#        • chsh_to_zsh           (placeholder; no-op except a warning)
#   5) wrap_up:
#        • print backup location and a handy alias for working with your bare repo
#
# Colorized logging:
#   • Log levels:
#       [info]    -> green
#       [warn]    -> yellow
#       ERROR:    -> red
#       [verbose] -> white (high contrast)
#   • Colors are enabled once in init() by setup_colors() AFTER parsing flags:
#       - Colors require a TTY ( [[ -t 1 ]] ) and a working `tput`
#       - Pass --no-color to disable
#
# Safety & repeatability:
#   • Tracked files that already exist in $HOME are backed up before they get replaced
#   • Re-running converges to the same state (whatever is in the bare repo)
#
# Usage:
#   macsetup.sh [--verbose|-v] [--no-color] [--help|-h]
#
# Exit codes (convention):
#   0  success
#   1  generic failure
#   3  brew bundle failed
#   64 usage error (unknown flag)
#
# ==============================================================================

# Fail-fast settings:
#   -e  stop on the first error
#   -u  error on unset variables
#   -o  pipefail  catch errors in pipelines
#   -E  ensure ERR traps propagate in functions/subshells
set -Eeuo pipefail
trap 'rc=$?; cmd=${BASH_COMMAND:-unknown}; printf "ERROR! %s failed at line %s while running: %s (exit %s).\n" "${BASH_SOURCE[0]}" "${LINENO}" "${cmd}" "${rc}" >&2; exit "$rc"' ERR

# ---------------------------------- globals -----------------------------------

readonly NOW="$(date +%y%m%d%H%M)"
readonly MACSETUP="macsetup"
readonly GITHUB_REPO="git@github.com:randie/$MACSETUP.git"
readonly BARE_REPO="$HOME/$MACSETUP.git"
readonly CONFIG_DIR="$HOME/.config"
readonly BREWFILE="$CONFIG_DIR/brew/Brewfile"
readonly SCRATCH_DIR="$HOME/.scratch/$MACSETUP"; mkdir -p "$SCRATCH_DIR"
readonly BACKUP_TAR="$SCRATCH_DIR/${MACSETUP}-backup-${NOW}.tar"

VERBOSE=false
NO_COLOR=false

# ------------------------------ logging helpers -------------------------------

log_info()    { printf "${COLOR_INFO}[info] %s${COLOR_RESET}\n" "$*"; }
log_warn()    { printf "${COLOR_WARN}[warn] %s${COLOR_RESET}\n" "$*"; }
log_error()   { printf "${COLOR_ERROR}ERROR: %s${COLOR_RESET}\n" "$*" >&2; }
log_verbose() { [[ "$VERBOSE" == true ]] && printf "${COLOR_VERBOSE}[verbose] %s${COLOR_RESET}\n" "$*" || true; }

# -------------------------- pre- and post-conditions --------------------------

ensure_preconditions() {
  local fail=0

  # 1) macOS only
  if [[ "$(uname -s)" != "Darwin" ]]; then
    log_error "This script targets macOS machines only. Detected $(uname -s)."
    return 1
  fi

  # 2) Apple Command Line Tools installed
  if [[ ! -x /usr/bin/xcode-select ]] || ! /usr/bin/xcode-select -p >/dev/null 2>&1; then
    log_error $'Apple Command Line Tools are required.\nInstall: xcode-select --install'
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
  COLOR_INFO=""
  COLOR_WARN=""
  COLOR_ERROR=""
  COLOR_VERBOSE=""
  COLOR_RESET=""

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
Usage: macsetup.sh [--verbose|-v] [--no-color] [--help|-h]

Options:
  -v, --verbose   Print extra diagnostic output
  --no-color      Disable colorized output
  -h, --help      Show this help and exit
EOF
}

# -------------------------------- args parsing --------------------------------

parse_args() {
  while [[ $# -gt 0 ]]; do
    case "$1" in
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

# ---------------------- ensure Xcode Command Line Tools -----------------------

# ensure_xcode_clt() {
#   if ! xcode-select -p > /dev/null 2>&1; then
#     log_error "Xcode Command Line Tools not found."
#     cat << 'MSG' >&2
#
# Please install them manually by running:
#     xcode-select --install
#
# Then re-run this script.
# MSG
#     exit 1
#   fi
#   log_verbose "Xcode Command Line Tools detected: $(xcode-select -p)"
# }

# --------------------------- ensure homebrew exists ---------------------------

ensure_homebrew() {
  if command -v brew > /dev/null 2>&1; then
    log_verbose "Homebrew is already installed at: $(command -v brew)"
    eval "$(brew shellenv)"
    return 0
  fi

  log_verbose "Installing Homebrew"
  curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh | /usr/bin/env bash

  if command -v brew > /dev/null 2>&1; then
    log_verbose "Homebrew installed at: $(command -v brew)"
    eval "$(brew shellenv)"
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
}

# --------------------------- brew install packages ----------------------------

brew_install_packages() {
  if [[ ! -r "$BREWFILE" ]]; then
    log_error "Brewfile not found or unreadable: $BREWFILE"
    exit 3
  fi
  if ! brew bundle --file="$BREWFILE"; then
    log_error "brew bundle did not complete successfully."
    exit 3
  fi
}


# -------------------------- ensure bare repo exists ---------------------------

ensure_bare_repo() {
    local commit branch

    if [[ -d "$BARE_REPO" && -d "$BARE_REPO/objects" ]]; then
      # If you're running this script, then you should already have
      # a bare repo in $HOME/macsetup.git since this script would
      # have been checked out from that bare repo.
      log_verbose "Bare repo already exists"
    else
      log_info "Cloning bare repo"
      git clone --bare "$GITHUB_REPO" "$BARE_REPO"
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
  git --no-pager --git-dir="$BARE_REPO" ls-tree --full-tree -r --name-only HEAD \
    | grep -Ev '^(README($|\.md$)|macsetup\.sh$)' > "$TRACKED_FILES"

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
  if ! brew list --cask iterm2 > /dev/null 2>&1; then
    log_info "Installing iTerm2 (Homebrew cask)"
    brew install --cask iterm2
  else
    log_verbose "iTerm2 already installed"
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
  log_info "If iTerm2 is running, quit and relaunch to pick up changes."
}

# ---------------------------- not implemented yet -----------------------------

install_oh_my_zsh() { log_warn "install_oh_my_zsh() is not implemented yet."; }
chsh_to_zsh() { log_warn "chsh_to_zsh() is not implemented yet."; }

# --------------------------- apply my configuration ---------------------------

apply_my_config() {
  # Hide untracked files in status
  git --git-dir="$BARE_REPO" --work-tree="$HOME" config --local status.showUntrackedFiles no

  # Check out dotfiles from the bare repo into $HOME
  if git --git-dir="$BARE_REPO" --work-tree="$HOME" checkout -f; then
    brew_install_packages
    # install_oh_my_zsh    # TODO: switch to antidote
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
BREW PREFIX : $HOMEBREW_PREFIX
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
