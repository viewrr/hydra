# Kraken NAS Setup

Debian 13 NAS with Incus containers running Jellyfin and an arr stack, exposed via Netbird reverse proxy with SSO.

```
kraken/                          # NAS host (Debian 13)
├── incus-setup.sh               # Create Incus containers + proxy devices
├── firewall.sh                  # iptables rules (Netbird subnet only)
└── arr-stack/
    ├── docker-compose.yml       # Radarr, Sonarr, Lidarr, Prowlarr, Bazarr, qBit, Whisparr, FlareSolverr
    ├── setup-arr.sh             # Configure download clients, root folders, app connections
    ├── add-indexers.sh          # Add public torrent indexers to Prowlarr
    ├── recyclarr.yml            # TRaSH Guides quality profiles + custom formats
    └── install-recyclarr.sh     # Install Recyclarr binary + run initial sync

hydra/                           # VPS (reverse proxy + auth)
├── docker-compose.yml           # Netbird server, Traefik, PocketID
├── .env.example                 # Domain config
├── dashboard.env.example        # Netbird dashboard OIDC config
├── proxy.env.example            # Netbird reverse proxy config
└── tinyproxy.conf               # ISP DPI bypass proxy
```

## Hardware

```
953.9G NVMe (LVM: 55G root, 21G var, 32G swap, 3G tmp, 821G home)
3.6TB HDD → /mnt/hdd (media storage)
```

## Quick Start

### 1. Incus containers (on NAS host)

```bash
# Install Incus on Debian 13, then:
bash kraken/incus-setup.sh
```

Creates two containers:
- **jellyfin** — GPU passthrough, media mount, SSD rootfs
- **arr-stack** — Docker nested inside, media mount, proxy devices for all service ports

### 2. Jellyfin

```bash
incus exec jellyfin -- bash
# Install Jellyfin: https://jellyfin.org/docs/general/installation/linux
```

Auth is disabled (auto-login, no password). Authentication handled by Netbird SSO. `LocalNetworkSubnets` set to `0.0.0.0/0` in `/etc/jellyfin/network.xml`.

### 3. Arr stack

```bash
# Install Docker inside container
incus exec arr-stack -- bash
apt update && apt install -y docker.io docker-compose-v2

# Deploy services
mkdir -p /opt/arr-stack
# Copy kraken/arr-stack/docker-compose.yml to /opt/arr-stack/
cd /opt/arr-stack && docker compose up -d

# Wait for services to start and generate API keys, then:
bash setup-arr.sh        # download clients + root folders + app connections
bash add-indexers.sh     # public torrent indexers
bash install-recyclarr.sh  # TRaSH Guides sync
```

#### Media directories

```bash
# Create inside container (owned by PUID:PGID 1000:1000)
mkdir -p /media/{movies,tv,music,downloads,xxx}
chown -R 1000:1000 /media
```

### 4. Hydra VPS (Netbird + reverse proxy)

```bash
# On VPS
cp hydra/.env.example hydra/.env        # edit domains
cp hydra/dashboard.env.example hydra/dashboard.env
cp hydra/proxy.env.example hydra/proxy.env
# Create hydra/config.yaml (Netbird server config)
docker compose -f hydra/docker-compose.yml up -d

# ISP DPI bypass proxy
apt install tinyproxy
cp hydra/tinyproxy.conf /etc/tinyproxy/tinyproxy.conf
systemctl restart tinyproxy
```

### 5. Connect NAS to Netbird

```bash
# On NAS host
netbird up --management-url https://birdy.example.com --setup-key <SETUP_KEY>
```

### 6. Firewall

```bash
bash kraken/firewall.sh
```

## Services

| Domain | Service | Port | Auth |
|---|---|---|---|
| fin.jobin.wtf | Jellyfin | 8096 | SSO |
| radarr.jobin.wtf | Radarr | 7878 | SSO |
| sonarr.jobin.wtf | Sonarr | 8989 | SSO |
| prowlarr.jobin.wtf | Prowlarr | 9696 | SSO |
| lidarr.jobin.wtf | Lidarr | 8686 | SSO |
| bazarr.jobin.wtf | Bazarr | 6767 | SSO |
| whisparr.jobin.wtf | Whisparr | 6969 | SSO |
| qbit.jobin.wtf | qBittorrent | 8080 | SSO |
| pocket.jobin.wtf | PocketID | 1411 | None |

All exposed via Netbird reverse proxy with auto-TLS and bearer auth (OIDC/SSO).

## TRaSH Guides (Recyclarr)

[Recyclarr](https://recyclarr.dev) v8.4.0 syncs TRaSH Guides to Radarr and Sonarr. Config at [`kraken/arr-stack/recyclarr.yml`](kraken/arr-stack/recyclarr.yml).

**Radarr** — `HD Bluray + WEB` profile, 48 custom formats (Golden Rule HD, Movie Versions, Streaming Services, Miscellaneous), Jellyfin-TMDB naming.

**Sonarr** — `WEB-1080p` profile, 32 custom formats (Golden Rule HD, Streaming Services, Miscellaneous), Jellyfin-TVDB naming.

**Additional settings:** Media Management > Proper & Repacks → "Do Not Prefer" (custom format scores handle this).

```bash
incus exec arr-stack -- recyclarr sync --config /opt/arr-stack/recyclarr/recyclarr.yml
```

## Prowlarr Proxy (ISP DPI Bypass)

Tinyproxy on hydra VPS bypasses ISP deep packet inspection for indexer requests. Configure in Prowlarr: Settings > General > Proxy → `http://<hydra-netbird-ip>:8888`.
