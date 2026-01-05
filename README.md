# macsetup (WIP)
This repo contains everything I need to setup a new Mac to my preferred configuration.

## Quick start (new Mac)

This is the **happy path** for setting up a brand-new or factory-reset Mac.  
Expect this to take **~5 minutes**, mostly waiting for installers to finish.

### A. Pre-macsetup (one-time prerequisites)

```bash
# Step 1: Install the Xcode Command Line Tools (CLT)
xcode-select -p >/dev/null 2>&1 || xcode-select --install

# Step 2: Install Homebrew
command -v brew >/dev/null 2>&1 || /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"
```

Follow the prompts as needed. When both are installed, continue.

---

### B. Run macsetup

```bash
# Step 0: Go to your home directory
cd "$HOME"

# Step 1: Clone macsetup as a bare repo
git clone --bare https://github.com/randie/macsetup.git macsetup-bare

# Step 2: Check out macsetup.sh
git --git-dir="$HOME/macsetup-bare" --work-tree="$HOME" checkout main -- bin/macsetup.sh

# Step 3: Run it
./bin/macsetup.sh --verbose
```

That’s it.  
All further configuration happens inside `macsetup.sh`.

---

## Notes / Troubleshooting (read only if needed)

- **Why HTTPS instead of SSH for git cloning?**  
  This is intentional so the bootstrap works on a brand-new Mac with no SSH keys yet.

- **CLT install didn’t start or seems stuck?**  
  Re-run:
  ```bash
  xcode-select --install
  ```
- **Homebrew not found after installation?**  
  Open a new Terminal window and try again. The installer prints PATH instructions if needed.

- **Re-running macsetup**  
  `macsetup.sh` is safe to re-run. It is not strictly idempotent (it may back up and replace tracked files), but it is designed to **converge your system toward the same desired configuration state** on each run.
