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
cd

# Step 1: Clone macsetup as a bare-repo in your home directory
git clone --bare https://github.com/randie/macsetup.git macsetup-bare

# Step 2: Check out macsetup.sh from the bare repo's main branch
git --git-dir="$HOME/macsetup-bare" --work-tree="$HOME" checkout main -- bin/macsetup.sh

# Step 3: Run it
./bin/macsetup.sh --verbose
```

macsetup.sh will let you know what manual steps, if any, will need to be taken yet.

---

## Notes / Troubleshooting (read only if needed)

- **Why use HTTPS instead of SSH for git cloning?**
  Because a brand new Mac will likely not have a github SSH key yet.

- **CLT install didn’t start or seems stuck.**
  Re-run:
  ```bash
  xcode-select --install
  ```
- **Homebrew not found after installation.**
  Open a new Terminal window and try again. The installer prints PATH instructions if needed.

- **Re-running macsetup**  
  `macsetup.sh` is safe to re-run. It is not strictly idempotent because it will back up and replace tracked files that already exist on your Mac. What each successive run of macsetup.sh does is **converge toward the same desired configuration state**.

