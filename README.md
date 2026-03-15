# dotfiles

Personal dotfiles for **macOS** and **Ubuntu** workstations with Rancher Desktop, Kubernetes, and a complete media server stack.

**Platform Support:** macOS (Intel/Apple Silicon) • Ubuntu 20.04+  
**Container Runtime:** [Rancher Desktop](https://rancherdesktop.io/) (Docker CLI + Kubernetes)

---

## Quick Start

### 1. Install Everything

```bash
git clone https://github.com/simplyadrian/dotfiles.git ~/dotfiles
cd ~/dotfiles
make
```

This installs:
- ✅ Base packages via Homebrew (macOS) or apt (Ubuntu)
- ✅ Rancher Desktop (container runtime with docker CLI + k8s)
- ✅ Custom shell configuration and scripts
- ✅ kubectl, helm, k9s CLI tools

### 2. ⚠️ **IMPORTANT:** Secure Your Personal Info

Before using, **customize these files** (they contain personal information):

```bash
# 1. Create your personal config (gitignored)
cp .extra.example ~/.extra
vim ~/.extra
# → Add your git credentials, SSH aliases, secrets

# 2. Update .gitconfig with your info
vim .gitconfig
# → Change name, email, signing key

# 3. Update media stack paths (if using)
# Edit media/k8s/*.yaml
# → Change /home/aherrera/ to your username
```

**⚠️ Never commit secrets!** Use `~/.extra` (gitignored) for:
- Git credentials
- SSH host aliases and IP addresses
- API tokens (PLEX_CLAIM, AWS keys)
- Personal paths and host-specific config

### 3. Multi-Account GitHub (SSH)

This setup supports multiple GitHub accounts via SSH host aliases. See [`ssh_config.example`](ssh_config.example).

```bash
# Set up SSH config (if not already done)
cp ssh_config.example ~/.ssh/config
chmod 600 ~/.ssh/config

# Generate keys for each account
ssh-keygen -t ed25519 -C "work@email.com"    -f ~/.ssh/github
ssh-keygen -t ed25519 -C "personal@email.com" -f ~/.ssh/id_ed25519_personal

# Add each public key to its GitHub account at https://github.com/settings/ssh/new

# Test
ssh -T git@github.com            # → work account
ssh -T git@github.com-personal   # → personal account
```

**Cloning:**
```bash
ghclone org/repo               # clone with work account
ghclone-personal user/repo     # clone with personal account
ghwhoami                        # show which account a repo uses
ghswitch                        # toggle a repo between work/personal
```

### 4. Configure Rancher Desktop

After installation, launch **Rancher Desktop** and configure:

1. **Container Engine:** Select **dockerd (moby)** — enables `docker` CLI
2. **Kubernetes:** Enable and choose your k8s version

Verify everything works:
```bash
docker ps              # container management
kubectl get nodes      # kubernetes cluster
helm version           # helm charts
```

### 5. (Optional) Deploy Media Stack

A complete self-hosted media server stack is included:
- Plex, Transmission, Sonarr, Radarr, Prowlarr, Bazarr, Overseerr, Flaresolverr

```bash
# Create config directories
mkdir -p ~/docker/configs/{transmission,sonarr,radarr,prowlarr,bazarr,overseerr}

# Deploy to Kubernetes
media_up       # kubectl apply all manifests
media_ps       # check pod status
media_logs plex  # tail logs
media_svc      # list endpoints
```

See [`media/README.md`](media/README.md) for architecture and full setup.

---

## What's Included

### Shell Environment

| File | Purpose |
|------|---------|
| `.bashrc` | Main bash configuration |
| `.bash_profile` | Login shell setup |
| `.bash_prompt` | Custom PS1 prompt |
| `.aliases` | Command shortcuts (80+ aliases) |
| `.functions` | Useful shell functions |
| `.exports` | Environment variables |
| `.path` | PATH configuration |
| `.extra` | **Your personal config** (gitignored) |

### Container & Kubernetes Tools

- **Docker CLI** via Rancher Desktop's moby engine
- **kubectl** aliases: `k`, `kgp`, `kgs`, `kga`, etc. (all use `-A` for safety)
- **media_*** helpers: `media_up`, `media_down`, `media_logs`, `media_ps`
- **dcleanup()** — Clean up stopped containers and dangling images

### Custom Scripts (`bin/`)

| Script | Purpose |
|--------|---------|
| `htotheizzo` | Update homebrew/apt + cleanup docker images |
| `macos-defaults` | Configure macOS system preferences |
| `install_base.sh` | Full system setup script |
| `gitdate` | Commit with custom dates |
| `openprs` | List open PRs across all repos |
| More... | `update-repos`, `cleanup-non-running-images`, etc. |

### Security Features

✅ **Removed dangerous aliases** — No more `prikey` that exposed private SSH keys  
✅ **Auto-detect network interfaces** — `sniff`/`httpdump` work on any system  
✅ **Namespace-aware k8s** — kubectl aliases use `-A` to prevent accidents  
✅ **OS detection cached** — Faster shell startup (10+ `uname` calls eliminated)  
✅ **Secrets in `.extra`** — Never commit personal info to git

---

## Configuration

### Customize Your Setup

All personal configuration goes in `~/.extra` (gitignored):

```bash
# Example ~/.extra
GIT_AUTHOR_NAME="Your Name"
GIT_AUTHOR_EMAIL="you@example.com"
git config --global user.name "$GIT_AUTHOR_NAME"
git config --global user.email "$GIT_AUTHOR_EMAIL"

# Personal aliases
alias work="ssh user@work-server.com"
alias home="ssh user@192.168.1.100"

# Media stack config
export PLEX_CLAIM="claim-XXXX"  # Get from https://plex.tv/claim
export TZ="America/New_York"
```

See [`.extra.example`](.extra.example) for all available options.

### Update System Packages

```bash
htotheizzo  # Updates homebrew (macOS) or apt (Ubuntu) + docker cleanup
```

### macOS System Preferences

```bash
macos-defaults  # Configure macOS settings (keyboard, dock, finder, etc.)
```

---

## Media Stack

Complete self-hosted media server with request management and automation.

**Services:** Plex • Transmission • Sonarr • Radarr • Prowlarr • Bazarr • Overseerr • Flaresolverr

**Deployment:** Kubernetes manifests in `media/k8s/`

**Shell Helpers:**
```bash
media_up         # Deploy everything
media_down       # Tear down namespace
media_ps         # Pod status
media_logs <svc> # Tail logs (e.g., media_logs plex)
media_svc        # Service endpoints
```

**Before deploying:**
1. Edit `media/k8s/*.yaml` — change `/home/aherrera/` to your paths
2. Create secrets: `kubectl create secret generic media-secrets --namespace media --from-literal=plex-claim="claim-XXXX"`

Full docs: [media/README.md](media/README.md)

---

## Migration

### From Docker Desktop / Colima

```bash
brew uninstall --cask docker
brew uninstall colima docker
```

Rancher Desktop replaces both and adds Kubernetes.

---

## Testing

Validate shell scripts with shellcheck:

```bash
make test
```

Runs locally if `shellcheck` is installed, otherwise uses Docker container.

---

## Security Checklist

Before committing changes:

- [ ] No passwords, API keys, or tokens in tracked files
- [ ] No IP addresses or hostnames (use `~/.extra`)
- [ ] No personal email/name in committed files
- [ ] `.extra` exists and is in `.gitignore`
- [ ] Kubernetes secrets use `kubectl create secret`, not YAML

**Files to customize before using:**
1. `.gitconfig` — Update name, email, signing key
2. `~/.extra` — Add all personal config (use `.extra.example` as template)
3. `media/k8s/*.yaml` — Update hardcoded paths

---

## File Structure

```
dotfiles/
├── .aliases          # 80+ command shortcuts
├── .bashrc           # Main shell config
├── .dockerfunc       # Container helpers
├── .extra            # YOUR personal config (gitignored)
├── .extra.example    # Template
├── .functions        # Shell utility functions
├── .gitconfig        # Git configuration
├── bin/              # Custom scripts
│   ├── htotheizzo
│   ├── macos-defaults
│   └── install_base.sh
└── media/            # Media server stack
    ├── README.md
    └── k8s/          # Kubernetes manifests
```

---

## Credits

Based on dotfiles patterns from [@jessfraz](https://github.com/jessfraz/dotfiles) and [@mathiasbynens](https://github.com/mathiasbynens/dotfiles).

## License

MIT — See [LICENSE](LICENSE)

