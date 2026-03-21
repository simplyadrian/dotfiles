# Media Stack

Self-hosted media stack with two deployment options:

- **Docker Compose** — works on macOS Big Sur and later (no Rancher Desktop required)
- **Kubernetes** — manifests for Rancher Desktop with K8s enabled

## Services

| Service | Port | Purpose |
|---|---|---|
| **Plex** | 32400 | Media streaming server |
| **Transmission** | 9091 | Torrent client |
| **SABnzbd** | 8080 | Usenet download client |
| **Sonarr** | 8989 | TV show management |
| **Radarr** | 7878 | Movie management |
| **Prowlarr** | 9696 | Indexer manager (feeds Sonarr/Radarr) |
| **Bazarr** | 6767 | Subtitle management |
| **LazyLibrarian** | 5299 | Ebook/audiobook management |
| **Overseerr** | 5055 | Request management (Plex-compatible) |
| **Flaresolverr** | 8191 | Cloudflare bypass (used by Prowlarr) |

## Architecture

```
                    ┌─────────────┐
                    │   Overseerr │ :5055  (request UI)
                    └──────┬──────┘
                           │ requests
                    ┌──────┴──────┐
              ┌─────┤             ├─────┐
              │     │             │     │
        ┌─────▼──┐  │         ┌──▼─────┐
        │ Sonarr  │  │         │ Radarr │
        │  :8989  │  │         │  :7878 │
        └────┬────┘  │         └───┬────┘
             │       │             │
        ┌────▼───────▼─────────────▼────┐
        │         Prowlarr :9696        │
        │     (indexer management)      │
        └────────────┬──────────────────┘
                     │
              ┌──────▼──────┐
              │ Flaresolverr│ :8191
              └─────────────┘

        ┌────────────┐  ┌────────┐  ┌──────────┐  ┌───────────────┐
        │Transmission│  │SABnzbd │  │  Bazarr  │  │LazyLibrarian  │
        │   :9091    │  │ :8080  │  │  :6767   │  │     :5299     │
        └─────┬──────┘  └───┬────┘  └────┬─────┘  └──┬─────────┬──┘
              │ torrents     │ usenet     │ subtitles  │ books   │ downloads
              ▼              ▼            ▼            ▼         ▼
        ~/Torrents      ~/Torrents   /mnt/media   /mnt/media  ~/Torrents

                    ┌──────────┐
                    │   Plex   │ :32400  (host network)
                    └────┬─────┘
                         │
                    /mnt/media
```

## Quick Start — Docker Compose (Big Sur+)

Requires [Docker Desktop](https://www.docker.com/products/docker-desktop/) (or any Docker Engine with Compose v2).

```bash
# 1. Create config directories
mkdir -p ~/docker/configs/{plex,transmission,sabnzbd,sonarr,radarr,prowlarr,bazarr,lazylibrarian,overseerr}

# 2. Ensure ~/.extra has media stack vars configured
#    See .extra.example for the full list (MEDIA_PATH, DOWNLOADS_PATH, etc.)
vim ~/.extra

# 3. Start the stack
cd ~/dotfiles/media
docker compose up -d

# 4. Check status
docker compose ps

# 5. View logs for a service
docker compose logs -f sonarr

# 6. Stop everything
docker compose down
```

## Quick Start — Kubernetes (Rancher Desktop)

Requires Rancher Desktop with Kubernetes enabled.

```bash
# 1. Create config directories
mkdir -p ~/docker/configs/{transmission,sabnzbd,sonarr,radarr,prowlarr,bazarr,lazylibrarian,overseerr}

# 2. (Optional) Create Plex claim secret
kubectl create secret generic media-secrets \
  --namespace media \
  --from-literal=plex-claim="claim-XXXX"

# 3. Deploy everything
media_up
# or: kubectl apply -f ~/dotfiles/media/k8s/

# 4. Check status
media_ps
media_svc

# 5. View logs for a service
media_logs plex

# 6. Clean up
media_down
```

## Shell Helpers

These are loaded from `.dockerfunc`:

### Docker Compose

| Command | Action |
|---|---|
| `docker compose up -d` | Start all services |
| `docker compose down` | Stop and remove containers |
| `docker compose ps` | List container status |
| `docker compose logs -f <svc>` | Tail logs for a service |

### Kubernetes

| Command | Action |
|---|---|
| `media_up` | `kubectl apply` all manifests |
| `media_down` | Delete the `media` namespace |
| `media_ps` | List pod status |
| `media_logs <svc>` | Tail logs for a service (e.g. `media_logs sonarr`) |
| `media_svc` | List service endpoints and ports |
| `media_update` | Pull latest images & rolling-restart all services |
| `media_update <svc>` | Update only the named service (e.g. `media_update sonarr`) |
| `media_restart <svc>` | Delete and recreate a service's pod |
| `media_shell <svc>` | Open a shell inside a running pod |
| `media_images` | Show running image versions for all pods |

## Public Access — Cloudflare Tunnel

Expose Overseerr (and optionally other services) to the internet **without opening any ports on your router**. All traffic flows through an encrypted outbound tunnel to Cloudflare's edge.

**Cost:** ~$10/yr for the domain. Tunnel, DNS, and auth are all free.

### Step 1 — Buy a domain on Cloudflare Registrar

1. Go to [dash.cloudflare.com](https://dash.cloudflare.com) → sign up (free)
2. Navigate to **Domain Registration → Register Domains**
3. Search for `hgrey.com` (or any domain you like)
4. Purchase it — Cloudflare sells at cost, no markup (~$10–12/yr for `.com`)
5. The domain is automatically added to your Cloudflare account with DNS managed

### Step 2 — Create a Cloudflare Tunnel

1. Go to [Cloudflare Zero Trust dashboard](https://one.dash.cloudflare.com)
2. Navigate to **Networks → Tunnels → Create a tunnel**
3. Choose **Cloudflared** connector type
4. Name the tunnel (e.g., `media-stack`)
5. On the install page, copy just the **tunnel token** (the long string after `--token`)
6. Save the token — you'll need it next

### Step 3 — Configure public hostnames

In the tunnel configuration, add these public hostnames:

| Public Hostname | Service URL (Docker Compose) | Service URL (Kubernetes) |
|---|---|---|
| `overseerr.hgrey.com` | `http://overseerr:5055` | `http://overseerr.media.svc:5055` |
| `radarr.hgrey.com` | `http://radarr:7878` | `http://radarr.media.svc:7878` |
| `sonarr.hgrey.com` | `http://sonarr:8989` | `http://sonarr.media.svc:8989` |
| `prowlarr.hgrey.com` | `http://prowlarr:9696` | `http://prowlarr.media.svc:9696` |
| `sabnzbd.hgrey.com` | `http://sabnzbd:8080` | `http://sabnzbd.media.svc:8080` |
| `bazarr.hgrey.com` | `http://bazarr:6767` | `http://bazarr.media.svc:6767` |
| `transmission.hgrey.com` | `http://transmission:9091` | `http://transmission.media.svc:9091` |
| `lazylibrarian.hgrey.com` | `http://lazylibrarian:5299` | `http://lazylibrarian.media.svc:5299` |

> **Note:** Plex is intentionally excluded — it uses host networking and has its own remote access feature. Streaming through Cloudflare adds latency and Plex apps can't handle Cloudflare Access login pages. Use Plex's built-in remote access (Settings → Remote Access) instead.

### Step 4 — Add Cloudflare Access policies (auth)

1. In Zero Trust dashboard, go to **Access → Applications → Add an application**
2. Select **Self-hosted**

**For Overseerr (public — friends can request):**

| Setting | Value |
|---|---|
| Application name | Overseerr |
| Session duration | 24 hours |
| Subdomain | `overseerr` |
| Domain | `hgrey.com` |
| Policy name | Allow friends |
| Action | Allow |
| Include rule | Emails — list your and your friends' email addresses |

> Overseerr also has built-in Plex auth. Cloudflare Access is the front door; Plex login is the second layer.

**For arr apps (admin only):**

| Setting | Value |
|---|---|
| Application name | Admin tools |
| Session duration | 24 hours |
| Subdomain | `*.hgrey.com` (wildcard catches everything) |
| Policy name | Admin only |
| Action | Allow |
| Include rule | Emails — just your email |

> Create the wildcard app **after** the Overseerr app. Cloudflare evaluates more specific matches first, so Overseerr friends won't be blocked by the wildcard.

### Step 5 — Deploy

**Docker Compose:**

```bash
# Add to ~/.extra
export CLOUDFLARE_TUNNEL_TOKEN="eyJhIjoiNGY5..."

# Start the stack with the tunnel
docker compose --profile tunnel up -d

# Verify cloudflared is connected
docker logs cloudflared
# Look for: "Connection registered" and "Registered tunnel connection"
```

**Kubernetes:**

```bash
# Create the tunnel token secret
kubectl create secret generic cloudflared \
  --namespace media \
  --from-literal=token="eyJhIjoiNGY5..."

# Deploy
kubectl apply -f ~/dotfiles/media/k8s/cloudflared.yaml

# Verify
kubectl logs -n media deploy/cloudflared
```

### Verify

After deploying, visit `https://overseerr.hgrey.com` — you should see a Cloudflare Access login page. After authenticating with your email, you'll be forwarded to Overseerr.

## Networking

- **Plex** uses `host` network mode (required for DLNA/local network discovery)
- **Docker Compose:** all other services are on the default bridge network and talk via container names (e.g., `http://sonarr:8989`)
- **Kubernetes:** services communicate via ClusterIP DNS (e.g., `http://sonarr:8989`); external access via NodePort
- **Cloudflare Tunnel:** `cloudflared` connects outbound to Cloudflare's edge — no inbound ports needed

## Paths

| Path | Purpose |
|---|---|
| `~/docker/configs/<service>` | Per-service configuration (bind-mount volumes) |
| `~/Torrents` | Download directory (Transmission, LazyLibrarian) |
| `/mnt/media` | Media library (movies, TV, music) |
| `/mnt/media/books` | Ebook/audiobook library (LazyLibrarian) |
| `/mnt/plexmediaserver` | Plex server config |

> **Note:** Paths are configured via environment variables in `~/.extra` (see `.extra.example`).
> These are picked up automatically by both Docker Compose and the K8s `media_up` helper.

## Service Configuration

After deploying, configure each service through its web UI:

1. **Plex** → `http://localhost:32400/web` — Complete initial setup
2. **Prowlarr** → `http://localhost:9696` — Add indexers, then connect to Sonarr/Radarr
   - For Usenet: add Newznab indexers (nzb.su, NZBgeek, althub.co.za, DrunkenSlug) under *Indexers → Add → Newznab*
   - For each, enter the URL and your API key (found in your indexer account settings)
3. **SABnzbd** → `http://localhost:8080` — Complete the setup wizard, then add your Usenet provider (server address, port, SSL, username, password)
4. **Sonarr** → `http://localhost:8989` — Add root folder `/mnt/media/tv`, connect download clients:
   - Usenet: `http://sabnzbd:8080` (API key from SABnzbd → Config → General)
   - Torrents: `http://transmission:9091`
5. **Radarr** → `http://localhost:7878` — Add root folder `/mnt/media/movies`, connect download clients:
   - Usenet: `http://sabnzbd:8080` (API key from SABnzbd → Config → General)
   - Torrents: `http://transmission:9091`
6. **Bazarr** → `http://localhost:6767` — Connect to Sonarr (`http://sonarr:8989`) and Radarr (`http://radarr:7878`)
7. **Overseerr** → `http://localhost:5055` — Connect to Plex, Sonarr, and Radarr
8. **LazyLibrarian** → `http://localhost:5299` — Add book root folder `/books`, connect download client `http://transmission:9091`
9. **Transmission** → `http://localhost:9091` — Default credentials in pod logs

> **Tip:** When configuring connections *between* services, use the service/container name (e.g., `http://sonarr:8989`) not `localhost`. This works with both Docker Compose and Kubernetes.
