# README-branches.md
## Managing Two Prompt Systems: P10K (`main`) and Starship (`starship`)

This repo contains two parallel configurations of the Zsh prompt:

- **`main` branch** → **Powerlevel10k (P10K)**
- **`starship` branch** → **Starship**

Each branch tracks a complete, coherent set of dotfiles.  
Switching branches instantly switches the active prompt because the bare repo’s **work-tree = `$HOME`**.

## Branch Purposes

### **`main`**
- This is the current stable configuration.
- Uses **Powerlevel10k**, including:
  - instant prompt block
  - `.p10k.zsh` theme
  - Antidote plugin entry `romkatv/powerlevel10k`
- No Starship config loaded.

### **`starship`**
- Experimental branch for transitioning to **Starship**.
- P10K is *fully disabled*:
  - instant prompt block is commented
  - sourcing of `.p10k.zsh` is commented
  - Antidote plugin entry `romkatv/powerlevel10k` is removed
- Starship is enabled (in .config/zsh/.zshrc) via:
  ```zsh
  eval "$(starship init zsh)"
  ```
- Starship configuration lives in:
  ```
  ~/.config/starship.toml
  ```

## Switching Between Prompts

Because this repo is a **bare repo**:

- The **tracked files in `$HOME` change automatically** when you switch branches.
- You do **not** manually edit `.zshrc` or `.zsh_plugins.txt` when switching back and forth.
- This is safe and reversible.

### Switch to P10K:

```bash
c switch main
```

### Switch to Starship:

```bash
c switch starship
```

> `c` is the alias for  
> `git --git-dir=$HOME/macsetup-bare --work-tree=$HOME`

## Requirements Before Switching Branches

Your work-tree (`$HOME`) must be clean:

```bash
c status -s
```

If there are modifications you want to keep:

```bash
c add <files>
c commit -m "Save changes"
```

If modifications are temporary:

```bash
c stash push -m "temporary changes"
```

Then switch branches.

## Files That Differ Between Branches

These files contain meaningful differences:

### In `main`:
- `.zshrc`  
  - P10K instant prompt enabled  
  - P10K sourcing block enabled  
  - Starship disabled

- `.zsh_plugins.txt`  
  - Includes `romkatv/powerlevel10k`

- `.config/zsh/p10k/.p10k.zsh`  
  - Actively used

- `.config/starship.toml`  
  - May or may not exist, but not used

### In `starship`:
- `.zshrc`  
  - P10K instant prompt **commented**  
  - P10K sourcing block **commented**
  - Starship enabled via `eval "$(starship init zsh)"`

- `.zsh_plugins.txt`  
  - P10K plugin entry removed

- `.config/starship.toml`  
  - Actively used on this branch

## Merging When Ready

Once the Starship prompt is stable:

```bash
c switch main
c merge starship
```

Resolve conflicts in:
- `.zshrc`
- `.zsh_plugins.txt`
- `.config/zsh/p10k/.p10k.zsh` (likely removed)
- Add/merge `starship.toml`

After merging, the `main` branch will permanently switch to Starship.

## Safety Notes

- This setup is fully reversible because **branches track the entire prompt state**.
- You can keep both prompts indefinitely while experimenting.
- Never switch branches with uncommitted changes in `$HOME`.
