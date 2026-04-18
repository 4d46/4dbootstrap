# 4D Bootstrap

Idempotent setup scripts for a fresh Ubuntu machine. Scripts are safe to rerun  -  they install if missing, upgrade if a newer version is available, and skip if already up to date.

## Quick start (fresh machine)

```bash
sudo apt-get install -y git curl
git clone https://github.com/4d46/4dbootstrap.git ~/bootstrap
cd ~/bootstrap
chmod +x bootstrap.sh scripts/*.sh
./bootstrap.sh
```

Restart your terminal when it finishes.

## Before first run

### 1. Fork kickstart.nvim
Fork [nvim-lua/kickstart.nvim](https://github.com/nvim-lua/kickstart.nvim) to your own GitHub account, then set before running:

```bash
export NVIM_CONFIG_REPO=https://github.com/YOURUSERNAME/kickstart.nvim.git
```

Without this, bootstrap will clone upstream and warn you. Your Neovim config won't be versioned under your account.

### 2. Create required 1Password items

**Git identity**  -  used by `scripts/git.sh` to configure `user.name` and `user.email`:
```bash
op item create --category=login --title="Git Identity" \
  --vault=Personal name="Your Name" email=you@example.com
```

**Shell env config**  -  used by `load-secrets` to know which variables to load. Contains `op://` references only, no actual secrets:
```bash
op item create \
  --category="Secure Note" \
  --title="Shell Env Config" \
  --vault=Personal \
  notesPlain="GITHUB_USERNAME=op://Personal/GitHub/username
GITHUB_TOKEN=op://Personal/GitHub/token"
```

**SSH hosts**  -  used by `scripts/ssh.sh` to populate system-specific SSH host entries:
```bash
op item create \
  --category="Secure Note" \
  --title="SSH Hosts" \
  --vault=Personal \
  "config[text]=Host myserver
    HostName 192.168.1.100
    User myuser"
```

### 3. Enable 1Password SSH agent
1Password app → Settings → Developer → Use the SSH agent

---

## What gets installed

| Module | What |
|---|---|
| `system` | curl, wget, build-essential, ripgrep, fd, bat, fzf, jq, … |
| `shell` | zsh, oh-my-zsh, powerlevel10k, InconsolataGo Nerd Font |
| `git` | Latest git via PPA, sensible global defaults, identity from 1Password |
| `github` | GitHub CLI (`gh`) via official apt repo |
| `mise` | [mise](https://mise.jdx.dev/) version manager + Go, Node LTS, Python, Java 21, Ruby |
| `editors` | Neovim (latest binary) + kickstart.nvim config, VS Code + extensions |
| `docker` | Docker CE, docker compose, adds user to docker group |
| `kubernetes` | kubectl, minikube, helm |
| `terraform` | Terraform via HashiCorp apt repo |
| `onepassword` | 1Password desktop app + `op` CLI |
| `env` | Installs `load-secrets` shell function for memory-only secret loading |
| `ssh` | `~/.ssh/config` with 1Password agent, GitHub block, hosts from 1Password |
| `godot` | Godot Engine (latest stable), desktop entry |

## Running individual modules

```bash
./bootstrap.sh docker          # single module
./bootstrap.sh mise editors    # multiple
bash scripts/godot.sh          # run directly
```

## Adding new tools

1. Create `scripts/mytool.sh` following the pattern in any existing script.
2. Add `mytool` to the `MODULES` array in `bootstrap.sh` (or leave it out to call it manually).
3. Add `!scripts/mytool.sh` to the appropriate section in `.gitignore`.
4. Rerun `./bootstrap.sh mytool`.

---

## Version management  -  mise

mise manages runtimes that have multiple incompatible versions in the wild (Node, Python, Ruby, Java). Go is included for consistency but version conflicts are rare.

Edit `config/mise.toml` to change global defaults. Per-project overrides go in a `mise.toml` at the repo root  -  mise picks them up automatically.

```bash
mise use -g node@20          # switch global Node version
mise use node@18             # project-local override
mise install                 # install everything configured
mise ls                      # see what's active
mise use -g dotnet@latest    # add .NET for Godot C# scripting
```

---

## 1Password & secrets

No credentials belong in this repo. Secrets are handled in two ways:

### SSH keys  -  automatic via agent
The 1Password SSH agent serves keys directly to SSH. No environment variables needed. `git push`, `ssh myserver` etc. work transparently once the agent is enabled.

### Environment variables  -  `load-secrets`
The `env` module installs a `load-secrets` shell function. Values are read from 1Password into shell memory only  -  never written to disk.

```zsh
load-secrets              # load all configured variables into current session
load-secrets --refresh    # re-fetch the config mapping from 1Password first
```

The mapping of variable names to 1Password references is stored as a Secure Note ("Shell Env Config") in 1Password  -  not in this repo. To add a new variable, edit that note and run `load-secrets --refresh`.

### GitHub CLI authentication
```bash
op read 'op://Personal/GitHub/token' | gh auth login --with-token
```

---

## GPG key fingerprints

All apt repository signing keys are verified against a hardcoded fingerprint before installation. If a key changes unexpectedly the script aborts rather than trusting it silently.

| Vendor | Fingerprint | Source |
|---|---|---|
| Docker | `9DC858229FC7DD38854AE2D88D81803C0EBFCD88` | docs.docker.com/engine/install/ubuntu |
| HashiCorp | `798AEC654E5C15428C8E42EEAA16FCBCA621E701` | developer.hashicorp.com/terraform/install |
| Microsoft (VS Code) | `BC528686B50D79E339D3721CEB3E94ADBE1229CF` | code.visualstudio.com/docs/setup/linux |
| Kubernetes v1.30 | `DE15B14486CD377B9E876E1A234654DA9A296436` | kubernetes.io/docs/tasks/tools |
| 1Password | `3FEF9748469ADBE15DA7CA80AC2D62742012EA22` | support.1password.com/install-linux |
| GitHub CLI | `2C6106201985B60E6C7AC87323F3D4EA75716059` | cli.github.com |

To look up a key fingerprint yourself:
```bash
tmpdir=$(mktemp -d)
curl -fsSL <key_url> | GNUPGHOME="$tmpdir" gpg --import 2>/dev/null
GNUPGHOME="$tmpdir" gpg --fingerprint --with-colons | awk -F: '/^fpr/{print $10; exit}'
rm -rf "$tmpdir"
```

> **Note:** The Kubernetes fingerprint is version-specific. Re-verify when bumping `K8S_VERSION` in `scripts/kubernetes.sh`.

---

## Godot development

The Godot editor is all you need for GDScript. For C#:

```bash
mise use -g dotnet@latest    # install .NET SDK
```

The VS Code extension `gedeondoescode.godot-tools` is installed automatically and provides LSP, debugger integration, and GDScript syntax highlighting.

---

## Dotfiles options

### Option A  -  chezmoi (recommended)

[chezmoi](https://chezmoi.io) is built for exactly this situation: dotfiles in a public repo, secrets from 1Password, templates for per-machine differences.

```bash
mise use -g chezmoi@latest
chezmoi init https://github.com/YOURUSERNAME/dotfiles
# In a dotfile template, reference 1Password directly:
# export GITHUB_TOKEN="{{ onepasswordRead "op://Personal/GitHub/token" }}"
```

### Option B  -  private dotfiles repo + GNU Stow

Keep a private GitHub repo. Use [GNU Stow](https://www.gnu.org/software/stow/) to symlink everything into `$HOME`.

```bash
apt_install stow
git clone git@github.com:YOURUSERNAME/dotfiles-private.git ~/dotfiles
cd ~/dotfiles && stow zsh git nvim
```

### Option C  -  no dotfiles repo

Leave dotfiles untracked. Store sensitive config in 1Password Secure Notes. Lowest maintenance, highest friction on a fresh install.

---

## Mac support

Detection is in place (`is_mac()` in `lib/common.sh`); individual module scripts exit cleanly on macOS with a "not yet implemented" message. Mac modules would use Homebrew as the package manager.

---

## Structure

```
bootstrap.sh          entry point
lib/
  common.sh           shared utilities (logging, apt helpers, checksum verification)
scripts/
  system.sh           base system packages
  shell.sh            zsh, oh-my-zsh, powerlevel10k, fonts
  git.sh              git + global config
  github.sh           GitHub CLI
  mise.sh             mise version manager + runtimes
  editors.sh          Neovim + kickstart.nvim, VS Code + extensions
  docker.sh           Docker CE
  kubernetes.sh       kubectl, minikube, helm
  terraform.sh        Terraform
  onepassword.sh      1Password desktop + CLI
  env.sh              load-secrets shell function
  ssh.sh              SSH config + 1Password agent
  godot.sh            Godot Engine
config/
  mise.toml           default runtime versions
```
