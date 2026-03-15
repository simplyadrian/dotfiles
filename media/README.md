# Media Stack

Self-hosted media stack deployed as **Kubernetes** manifests on **Rancher Desktop**.

## Services

| Service | Port | Purpose |
|---|---|---|
| **Plex** | 32400 | Media streaming server |
| **Transmission** | 9091 | Torrent client |
| **Sonarr** | 8989 | TV show management |
| **Radarr** | 7878 | Movie management |
| **Prowlarr** | 9696 | Indexer manager (feeds Sonarr/Radarr) |
| **Bazarr** | 6767 | Subtitle management |
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

        ┌────────────┐     ┌──────────┐
        │Transmission│     │  Bazarr  │
        │   :9091    │     │  :6767   │
        └─────┬──────┘     └────┬─────┘
              │ downloads       │ subtitles
              ▼                 ▼
        ~/Torrents          /mnt/media

                    ┌──────────┐
                    │   Plex   │ :32400  (host network)
                    └────┬─────┘
                         │
                    /mnt/media
```

## Quick Start

Requires Rancher Desktop with Kubernetes enabled.

```bash
# 1. Create config directories
mkdir -p ~/docker/configs/{transmission,sonarr,radarr,prowlarr,bazarr,overseerr}

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

| Command | Action |
|---|---|
| `media_up` | `kubectl apply` all manifests |
| `media_down` | Delete the `media` namespace |
| `media_ps` | List pod status |
| `media_logs <svc>` | Tail logs for a service (e.g. `media_logs sonarr`) |
| `media_svc` | List service endpoints and ports |

## Networking

- **Plex** uses `hostNetwork: true` (required for DLNA/local network discovery)
- All other services use ClusterIP Services for internal communication (services talk via DNS, e.g., `http://sonarr:8989`)
- External access via NodePort services

## Paths

| Path | Purpose |
|---|---|
| `~/docker/configs/<service>` | Per-service configuration (hostPath volumes) |
| `~/Torrents` | Download directory (Transmission) |
| `/mnt/media` | Media library (movies, TV, music) |
| `/mnt/plexmediaserver` | Plex server config |

> **Note:** The k8s manifests use `hostPath` volumes with paths for user `aherrera`. Edit the YAML files if your username or paths differ.

## Service Configuration

After deploying, configure each service through its web UI:

1. **Plex** → `http://localhost:32400/web` — Complete initial setup
2. **Prowlarr** → `http://localhost:9696` — Add indexers, then connect to Sonarr/Radarr
3. **Sonarr** → `http://localhost:8989` — Add root folder `/mnt/media/tv`, connect download client `http://transmission:9091`
4. **Radarr** → `http://localhost:7878` — Add root folder `/mnt/media/movies`, connect download client `http://transmission:9091`
5. **Bazarr** → `http://localhost:6767` — Connect to Sonarr (`http://sonarr:8989`) and Radarr (`http://radarr:7878`)
6. **Overseerr** → `http://localhost:5055` — Connect to Plex, Sonarr, and Radarr
7. **Transmission** → `http://localhost:9091` — Default credentials in pod logs

> **Tip:** When configuring connections *between* services, use the Kubernetes service name (e.g., `http://sonarr:8989`) not `localhost`.
