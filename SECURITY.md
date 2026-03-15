# Security Reference

## ⚠️ Before You Start

These dotfiles contain **personal information** that must be customized:

1. **`.gitconfig`** — Contains name, email, GPG key (update to yours)
2. **No `.extra` file** — You must create it from `.extra.example`

## What Goes Where

### ✅ Committed to Git (Public)
- Shell configuration (`.bashrc`, `.aliases`, etc.)
- Generic scripts and functions
- `.extra.example` template (no secrets)
- K8s manifests with `${VAR}` templates (no hardcoded paths)
- Documentation

### ❌ Never Commit (Use `~/.extra`)
- Git credentials (name, email)
- SSH host aliases with IP addresses
- API tokens (PLEX_CLAIM, AWS keys)
- Media stack paths (CONFIG_PATH, MEDIA_PATH, etc.)
- Passwords or secrets

## Quick Setup

```bash
# 1. Create personal config
cp .extra.example ~/.extra
vim ~/.extra  # Add your info, paths, and secrets

# 2. Update git config
vim .gitconfig  # Change name, email, signing key

# 3. Set up SSH for multi-account GitHub
cp ssh_config.example ~/.ssh/config
chmod 600 ~/.ssh/config
```

## Security Checklist

Before `git commit`:
- [ ] No passwords or API keys
- [ ] No IP addresses (personal SSH hosts go in `~/.extra`)
- [ ] No real names/emails in committed files (use `~/.extra`)
- [ ] `.extra` is gitignored (check with `git status`)

## Kubernetes Secrets

**Don't put secrets in YAML files.** Use kubectl:

```bash
kubectl create secret generic media-secrets \
  --namespace media \
  --from-literal=plex-claim="claim-XXXX"
```

## SSH Keys
**Safe practices:**
- ✅ Use `pubkey` to copy your public key
- ✅ Use passphrase-protected keys
- ✅ Use `ssh-agent` for key management

## Questions?

See the main [README.md](README.md) for full documentation.

