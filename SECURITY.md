# Security Reference

## ⚠️ Before You Start

These dotfiles contain **personal information** that must be customized:

1. **`.gitconfig`** — Contains Adrian Herrera's name, email, GPG key
2. **`media/k8s/*.yaml`** — Hardcoded paths to `/home/aherrera/`
3. **No `.extra` file** — You must create it from `.extra.example`

## What Goes Where

### ✅ Committed to Git (Public)
- Shell configuration (`.bashrc`, `.aliases`, etc.)
- Generic scripts and functions
- `.extra.example` template (no secrets)
- Documentation

### ❌ Never Commit (Use `~/.extra`)
- Git credentials (name, email)
- SSH host aliases with IP addresses
- API tokens (PLEX_CLAIM, AWS keys)
- Personal paths
- Passwords or secrets

## Quick Setup

```bash
# 1. Create personal config
cp .extra.example ~/.extra
vim ~/.extra  # Add your info

# 2. Update git config
vim .gitconfig  # Change name, email, signing key

# 3. Update media stack paths
find media/k8s -name "*.yaml" -exec sed -i '' 's|/home/aherrera|/home/YOURUSERNAME|g' {} \;
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

