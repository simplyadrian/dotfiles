# Media Stack

Self-hosted media stack with two deployment options:

- **Docker Compose** — works on macOS Big Sur and later (no Rancher Desktop required)
- **Kubernetes** — manifests for Rancher Desktop with K8s enabled

## Services

| Service | Port | Purpose |
|---|---|---|
| **Plex** | 32400 | Media streaming server |
| **Transmission** | 9091 | Torrent client |
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

        ┌────────────┐     ┌──────────┐     ┌───────────────┐
        │Transmission│     │  Bazarr  │     │LazyLibrarian  │
        │   :9091    │     │  :6767   │     │     :5299     │
        └─────┬──────┘     └────┬─────┘     └──┬─────────┬──┘
              │ downloads       │ subtitles     │ books   │ downloads
              ▼                 ▼               ▼         ▼
        ~/Torrents          /mnt/media    /mnt/media   ~/Torrents

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
mkdir -p ~/docker/configs/{plex,transmission,sonarr,radarr,prowlarr,bazarr,lazylibrarian,overseerr}

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
mkdir -p ~/docker/configs/{transmission,sonarr,radarr,prowlarr,bazarr,lazylibrarian,overseerr}

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

## Networking

- **Plex** uses `host` network mode (required for DLNA/local network discovery)
- **Docker Compose:** all other services are on the default bridge network and talk via container names (e.g., `http://sonarr:8989`)
- **Kubernetes:** services communicate via ClusterIP DNS (e.g., `http://sonarr:8989`); external access via NodePort

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
3. **Sonarr** → `http://localhost:8989` — Add root folder `/mnt/media/tv`, connect download client `http://transmission:9091`
4. **Radarr** → `http://localhost:7878` — Add root folder `/mnt/media/movies`, connect download client `http://transmission:9091`
5. **Bazarr** → `http://localhost:6767` — Connect to Sonarr (`http://sonarr:8989`) and Radarr (`http://radarr:7878`)
6. **Overseerr** → `http://localhost:5055` — Connect to Plex, Sonarr, and Radarr
7. **LazyLibrarian** → `http://localhost:5299` — Add book root folder `/books`, connect download client `http://transmission:9091`
8. **Transmission** → `http://localhost:9091` — Default credentials in pod logs

> **Tip:** When configuring connections *between* services, use the service/container name (e.g., `http://sonarr:8989`) not `localhost`. This works with both Docker Compose and Kubernetes.
