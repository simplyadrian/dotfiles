# dotfiles

Personal dotfiles for **macOS** and **Ubuntu** workstations with Rancher Desktop, Kubernetes, and a complete media server stack.

**Platform Support:** macOS 11 Big Sur through Tahoe (Intel & Apple Silicon) • Ubuntu 20.04+  
**Container Runtime:** [Rancher Desktop](https://rancherdesktop.io/) (macOS 12+) or Docker + Colima (macOS 11)

---

## Quick Start

### 1. Install Everything

```bash
git clone git@github.com-personal:simplyadrian/dotfiles.git ~/dotfiles
cd ~/dotfiles
make
```

This installs:
- ✅ Base packages via Homebrew (macOS) or apt (Ubuntu)
- ✅ **macOS 12+**: Rancher Desktop (docker CLI + Kubernetes) + kubectl, helm, k9s
- ✅ **macOS 11**: Docker CLI + Colima (docker only — Rancher Desktop requires 12+)
- ✅ Custom shell configuration and scripts
- ✅ **macOS 11**: Pins packages that can't upgrade on Homebrew Tier 3 (go, gcc, llvm, gnupg, etc.)

### 2. ⚠️ **IMPORTANT:** Secure Your Personal Info

Before using, **customize these files** (they contain personal information):

```bash
# 1. Create your personal config (gitignored)
cp .extra.example ~/.extra
vim ~/.extra
# → Add your git credentials, SSH aliases, media stack paths, secrets

# 2. Update .gitconfig with your info
vim .gitconfig
# → Change name, email, signing key
```

**⚠️ Never commit secrets!** Use `~/.extra` (gitignored) for:
- Git credentials
- SSH host aliases and IP addresses
- API tokens (PLEX_CLAIM, AWS keys)
- Media stack paths (CONFIG_PATH, MEDIA_PATH, etc.)
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

**Cloning & Account Management:**
```bash
ghclone org/repo               # clone with work account
ghclone-personal user/repo     # clone with personal account
ghwhoami                       # show which account a repo uses
ghswitch                       # toggle a repo between work/personal
```

> These functions are defined in `.functions` and rely on the SSH host aliases in `ssh_config.example`.

### 4. Configure Container Runtime

**macOS 12+ (Rancher Desktop):**

Launch **Rancher Desktop** and configure:

1. **Container Engine:** Select **dockerd (moby)** — enables `docker` CLI
2. **Kubernetes:** Enable and choose your k8s version

**macOS 11 (Colima):**

```bash
colima start                     # start the Docker engine
colima start --cpu 4 --memory 8  # with more resources
```

> ⚠️ Kubernetes and the media stack k8s manifests are not available on macOS 11.
> Docker containers (`.dockerfunc`) and Docker Compose (`media/docker-compose.yaml`) work fine.

Verify everything works:
```bash
docker ps              # container management
kubectl get nodes      # kubernetes cluster (macOS 12+ only)
helm version           # helm charts (macOS 12+ only)
```

### 5. (Optional) Deploy Media Stack

A complete self-hosted media server stack is included:
- Plex, Transmission, Sonarr, Radarr, Prowlarr, Bazarr, Overseerr, Flaresolverr

**Two deployment options:**
- **Docker Compose** — works on all supported macOS (including Big Sur)
- **Kubernetes** — requires Rancher Desktop with k8s enabled (macOS 12+)

```bash
# Docker Compose (all macOS versions)
cd ~/dotfiles/media
docker compose up -d

# Kubernetes (macOS 12+ only)
media_up              # kubectl apply all manifests
media_ps              # check pod status
media_logs plex       # tail logs
media_svc             # list endpoints
```

> All media stack variables (paths, PLEX_CLAIM, TZ, etc.) are configured in `~/.extra`.
> See `.extra.example` for the full list.

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
| `.functions` | Useful shell functions (GitHub helpers, calc, etc.) |
| `.exports` | Environment variables |
| `.path` | PATH configuration (Homebrew, Rancher Desktop `~/.rd/bin`) |
| `.dockerfunc` | Docker wrappers + media stack k8s helpers |
| `.extra` | **Your personal config** (gitignored) |
| `.extra.example` | Template for `.extra` |

### Container & Kubernetes Tools

- **Docker CLI** via Rancher Desktop's moby engine (macOS 12+) or Colima (macOS 11)
- **kubectl** aliases: `k`, `kgp`, `kgs`, `kga`, etc. (all use `-A` for safety)
- **media_*** k8s helpers: `media_up`, `media_down`, `media_logs`, `media_ps`, `media_svc`
- **Docker Compose** media stack for macOS 11+ (no k8s required)
- **dcleanup()** — Clean up stopped containers and dangling images

### Custom Scripts (`bin/`)

| Script | Purpose |
|--------|---------|
| `htotheizzo` | Update homebrew/apt + auto-pin Tier 3 packages + cleanup docker images |
| `install_base.sh` | Full system setup script (macOS 11+ and Ubuntu 20.04+) |
| `macos-defaults` | Configure macOS system preferences |
| `gitdate` | Commit with custom dates |
| `openprs` | List open PRs across all repos |
| `keysign` | GPG key signing helper |
| `avconvert` | Audio/video conversion |
| `cleanup-non-running-images` | Remove stopped Docker images |
| `update-repos` | Pull latest on all repos in a directory |
| `update-mirrors` | Update package mirrors |

### Security Features

✅ **Auto-detect network interfaces** — `sniff`/`httpdump` work on any system  
✅ **Namespace-aware k8s** — kubectl aliases use `-A` to prevent accidents  
✅ **OS detection cached** — Faster shell startup  
✅ **Secrets in `.extra`** — Never commit personal info to git  
✅ **Multi-account SSH** — Work and personal GitHub accounts via separate keys

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

# Media stack paths
export MEDIA_PATH="/mnt/media"
export DOWNLOADS_PATH="/home/you/Torrents"
export CONFIG_PATH="/home/you/docker/configs"
export PLEX_CONFIG_PATH="/mnt/plexmediaserver"
export PLEX_TRANSCODE_PATH="/tmp/plex-transcode"
export TZ="America/New_York"
export PUID=1000
export PGID=1000
# export PLEX_CLAIM="claim-XXXX"  # Get from https://plex.tv/claim
```

See [`.extra.example`](.extra.example) for all available options.

### Update System Packages

```bash
htotheizzo  # Updates homebrew (macOS) or apt (Ubuntu) + docker cleanup
```

> On macOS 11 (Big Sur), `htotheizzo` automatically pins packages that can't upgrade
> on Homebrew Tier 3 (go, gcc, llvm, gnupg, gnutls, docker, colima, lima, and their
> dependents like qemu) before running `brew upgrade`.

### macOS System Preferences

```bash
macos-defaults  # Configure macOS settings (keyboard, dock, finder, etc.)
```

---

## Media Stack

Complete self-hosted media server with request management and automation.

**Services:** Plex • Transmission • Sonarr • Radarr • Prowlarr • Bazarr • Overseerr • Flaresolverr

**Deployment Options:**
- **Docker Compose** (`media/docker-compose.yaml`) — all macOS versions
- **Kubernetes** (`media/k8s/`) — requires Rancher Desktop (macOS 12+)

**Shell Helpers (Kubernetes):**
```bash
media_up         # Deploy all k8s manifests
media_down       # Tear down media namespace
media_ps         # Pod status
media_logs <svc> # Tail logs (e.g., media_logs plex)
media_svc        # Service endpoints
```

Full docs: [media/README.md](media/README.md)

---

## macOS 11 (Big Sur) Notes

macOS 11 is [Homebrew Tier 3](https://docs.brew.sh/Support-Tiers#tier-3) — many packages
lack pre-built bottles and must compile from source, which frequently fails.

**What's different on macOS 11:**
- **Rancher Desktop** → not available (requires macOS 12+). Uses Docker + Colima instead
- **Kubernetes** → not available (no k8s cluster). Use Docker Compose for media stack
- **Homebrew packages** → installed individually (one failure won't abort the rest)
- **Skipped packages** → cmake, gcc, gnupg, helm, kubectl, k9s (all depend on `go` or fail to build)
- **Pinned packages** → go, gcc, llvm, gnupg, gnutls, docker, colima, lima, and any dependents
  (prevents `brew upgrade` from attempting and failing on these)

---

## Testing

Comprehensive test suite for validating dotfiles:

```bash
make test           # Run shellcheck (locally or via docker)
./test.sh all       # Run all tests
./test.sh quick     # Syntax + secrets + permissions (no shellcheck)
./test.sh shell     # Shell syntax + shellcheck only
./test.sh yaml      # YAML/k8s manifest + Docker Compose validation
./test.sh docker    # Docker Compose validation only
./test.sh secrets   # Credential leak scan only
```

**Tests include:** shell syntax, shellcheck lint, YAML validation, kubectl dry-run,
secrets scan, file permissions, dotfile integrity, Python version references,
path hygiene (hardcoded paths), and Docker Compose validation.

---

## Security Checklist

Before committing changes:

- [ ] No passwords, API keys, or tokens in tracked files
- [ ] No IP addresses or hostnames (use `~/.extra`)
- [ ] No personal email/name in committed files
- [ ] `.extra` exists and is in `.gitignore`
- [ ] Kubernetes secrets use `kubectl create secret`, not YAML

See [SECURITY.md](SECURITY.md) for full guidelines.

**Files to customize before using:**
1. `.gitconfig` — Update name, email, signing key
2. `~/.extra` — Add all personal config (use `.extra.example` as template)
3. `ssh_config.example` → `~/.ssh/config` — Set up your SSH keys

---

## File Structure

```
dotfiles/
├── .aliases            # 80+ command shortcuts
├── .bash_profile       # Login shell setup
├── .bash_prompt        # Custom PS1 prompt
├── .bashrc             # Main shell config
├── .dockerfunc         # Container helpers + media stack k8s commands
├── .exports            # Environment variables
├── .extra.example      # Template for personal config
├── .functions          # Shell functions (GitHub helpers, etc.)
├── .gitconfig          # Git configuration
├── .inputrc            # Readline config
├── .path               # PATH setup (Homebrew, ~/.rd/bin)
├── .tmux.conf          # tmux configuration
├── gitignore           # Global gitignore
├── ssh_config.example  # Multi-account SSH template
├── Makefile            # Install targets (base, bin, dotfiles, test)
├── test.sh             # Comprehensive test suite
├── SECURITY.md         # Security guidelines
├── bin/                # Custom scripts
│   ├── htotheizzo      # System updater
│   ├── install_base.sh # Full system setup
│   ├── macos-defaults  # macOS preferences
│   ├── gitdate         # Custom date commits
│   ├── openprs         # List open PRs
│   └── ...
└── media/              # Media server stack
    ├── README.md       # Media stack documentation
    ├── docker-compose.yaml  # Docker Compose deployment
    └── k8s/            # Kubernetes manifests
        ├── namespace.yaml
        ├── plex.yaml
        ├── sonarr-radarr.yaml
        ├── prowlarr-flaresolverr.yaml
        ├── bazarr-overseerr.yaml
        └── transmission.yaml
```

---

## Credits

Based on dotfiles patterns from [@jessfraz](https://github.com/jessfraz/dotfiles) and [@mathiasbynens](https://github.com/mathiasbynens/dotfiles).

## License

MIT — See [LICENSE](LICENSE)

