# Kraken NAS Setup

Debian 13 NAS with Incus containers running Jellyfin and an arr stack, exposed via Netbird reverse proxy.

## Hardware

```
953.9G NVMe (LVM: 55G root, 21G var, 32G swap, 3G tmp, 821G home)
3.6TB HDD → /mnt/hdd (media storage)
```

## 1. Incus

Install on Debian 13 host. Two storage pools:

```bash
incus storage create ssd-pool dir  # container rootfs
# default pool also exists (dir backend)
```

## 2. Jellyfin Container

```bash
incus launch images:ubuntu/noble jellyfin
incus config set jellyfin security.privileged=true

# GPU passthrough for hardware transcoding
incus config device add jellyfin gpu gpu gputype=drm

# Media mount
incus config device add jellyfin media disk source=/mnt/hdd/media path=/media

# SSD rootfs
incus config device add jellyfin root disk path=/ pool=ssd-pool

# Expose web UI
incus config device add jellyfin web proxy listen=tcp:0.0.0.0:8096 connect=tcp:127.0.0.1:8096
```

Install Jellyfin inside: https://jellyfin.org/docs/general/installation/linux

Jellyfin's own auth is disabled (auto-login enabled, password removed). Authentication is handled by Netbird SSO at `fin.jobin.wtf`. `LocalNetworkSubnets` set to `0.0.0.0/0` in `/etc/jellyfin/network.xml`.

## 3. Arr Stack Container

```bash
incus launch images:ubuntu/noble arr-stack
incus config set arr-stack security.nesting=true security.privileged=true

# Storage
incus config device add arr-stack root disk path=/ pool=ssd-pool
incus config device add arr-stack media disk source=/mnt/hdd/media path=/media

# Proxy devices (expose each service port from container to host)
incus config device add arr-stack radarr-web proxy listen=tcp:0.0.0.0:7878 connect=tcp:127.0.0.1:7878
incus config device add arr-stack sonarr-web proxy listen=tcp:0.0.0.0:8989 connect=tcp:127.0.0.1:8989
incus config device add arr-stack lidarr-web proxy listen=tcp:0.0.0.0:8686 connect=tcp:127.0.0.1:8686
incus config device add arr-stack prowlarr-web proxy listen=tcp:0.0.0.0:9696 connect=tcp:127.0.0.1:9696
incus config device add arr-stack bazarr-web proxy listen=tcp:0.0.0.0:6767 connect=tcp:127.0.0.1:6767
incus config device add arr-stack qbit-web proxy listen=tcp:0.0.0.0:8080 connect=tcp:127.0.0.1:8080
incus config device add arr-stack readarr-web proxy listen=tcp:0.0.0.0:8787 connect=tcp:127.0.0.1:8787
incus config device add arr-stack flaresolverr-web proxy listen=tcp:0.0.0.0:8191 connect=tcp:127.0.0.1:8191
incus config device add arr-stack whisparr-web proxy listen=tcp:0.0.0.0:6969 connect=tcp:127.0.0.1:6969
```

Install Docker inside the container, then create `/opt/arr-stack/docker-compose.yml`:

```yaml
services:
  radarr:
    image: lscr.io/linuxserver/radarr:latest
    container_name: radarr
    environment: &env
      PUID: 1000
      PGID: 1000
      TZ: Asia/Kolkata
    volumes:
      - /opt/arr-stack/radarr:/config
      - /media:/media
    ports: ["7878:7878"]
    restart: unless-stopped

  sonarr:
    image: lscr.io/linuxserver/sonarr:latest
    container_name: sonarr
    environment: *env
    volumes:
      - /opt/arr-stack/sonarr:/config
      - /media:/media
    ports: ["8989:8989"]
    restart: unless-stopped

  lidarr:
    image: lscr.io/linuxserver/lidarr:latest
    container_name: lidarr
    environment: *env
    volumes:
      - /opt/arr-stack/lidarr:/config
      - /media:/media
    ports: ["8686:8686"]
    restart: unless-stopped

  prowlarr:
    image: lscr.io/linuxserver/prowlarr:latest
    container_name: prowlarr
    environment: *env
    volumes:
      - /opt/arr-stack/prowlarr:/config
    ports: ["9696:9696"]
    restart: unless-stopped

  bazarr:
    image: lscr.io/linuxserver/bazarr:latest
    container_name: bazarr
    environment: *env
    volumes:
      - /opt/arr-stack/bazarr:/config
      - /media:/media
    ports: ["6767:6767"]
    restart: unless-stopped

  qbittorrent:
    image: lscr.io/linuxserver/qbittorrent:latest
    container_name: qbittorrent
    environment:
      <<: *env
      WEBUI_PORT: 8080
    volumes:
      - /opt/arr-stack/qbittorrent:/config
      - /media/downloads:/downloads
    ports: ["8080:8080", "6881:6881", "6881:6881/udp"]
    restart: unless-stopped

  whisparr:
    image: ghcr.io/hotio/whisparr:v3
    container_name: whisparr
    environment: *env
    volumes:
      - /opt/arr-stack/whisparr:/config
      - /media:/media
    ports: ["6969:6969"]
    restart: unless-stopped

  flaresolverr:
    image: ghcr.io/flaresolverr/flaresolverr:latest
    container_name: flaresolverr
    environment:
      TZ: Asia/Kolkata
    ports: ["8191:8191"]
    restart: unless-stopped
```

```bash
incus exec arr-stack -- bash -c "cd /opt/arr-stack && docker compose up -d"
```

## 4. Netbird (Mesh VPN + Reverse Proxy)

Self-hosted on hydra VPS (`hydra.jobin.wtf`). Provides:
- Mesh connectivity between peers (hydra, kraken, mac)
- Reverse proxy with auto-TLS for all services
- SSO authentication via embedded IDP

### Register kraken as peer

```bash
netbird up --management-url https://birdy.jobin.wtf --setup-key <SETUP_KEY>
```

### Reverse proxy services

All exposed via Netbird reverse proxy with custom domain `jobin.wtf`:

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

## 5. Firewall

On the NAS host, restrict arr ports to only accept traffic from the Netbird subnet:

```bash
iptables -A INPUT -i lo -j ACCEPT
iptables -A INPUT -m state --state RELATED,ESTABLISHED -j ACCEPT
iptables -A INPUT -p tcp --dport 22 -j ACCEPT

for port in 6767 6969 7878 8080 8096 8191 8686 8787 8989 9696; do
  iptables -A INPUT -i wt0 -p tcp -s 100.115.0.0/16 --dport $port -j ACCEPT
  iptables -A INPUT -p tcp --dport $port -j DROP
done

apt install -y iptables-persistent
netfilter-persistent save
```

## 6. Prowlarr Proxy (ISP DPI Bypass)

Tinyproxy runs on hydra (`100.115.14.107:8888`) to bypass ISP deep packet inspection for indexer requests. Configure in Prowlarr under Settings > General > Proxy.

## 7. TRaSH Guides (Recyclarr)

[Recyclarr](https://recyclarr.dev) v8.4.0 syncs TRaSH Guides quality profiles, custom formats, and naming conventions to Radarr and Sonarr.

Binary: `/usr/local/bin/recyclarr` (inside arr-stack container)
Config: `/opt/arr-stack/recyclarr/recyclarr.yml`

### What gets synced

**Radarr:**
- Quality profile: `HD Bluray + WEB` (Bluray-1080p, WEB 1080p, Bluray-720p)
- Quality sizes: TRaSH recommended limits for movie
- Custom formats (48): Golden Rule HD (BR-DISK, LQ, x265 HD, 3D, Upscaled penalties), Movie Versions (Hybrid, Remaster, Criterion bonuses), Streaming Services (AMZN, NF, DSNP, etc.), Miscellaneous (Repack/Proper)
- Media naming: Jellyfin-compatible TMDB format

**Sonarr:**
- Quality profile: `WEB-1080p` (WEBRip-1080p, WEBDL-1080p)
- Quality sizes: TRaSH recommended limits for series
- Custom formats (32): Golden Rule HD, Streaming Services, Miscellaneous (Repack/Proper)
- Media naming: Jellyfin-compatible TVDB format

### Additional TRaSH settings

- **Radarr & Sonarr**: Media Management > Proper & Repacks set to **"Do Not Prefer"** (custom format scores handle this instead)

### Run sync

```bash
incus exec arr-stack -- recyclarr sync --config /opt/arr-stack/recyclarr/recyclarr.yml
```

### Config

```yaml
radarr:
  movies:
    base_url: http://localhost:7878
    api_key: <RADARR_KEY>
    quality_definition:
      type: movie
    quality_profiles:
      - trash_id: d1d67249d3890e49bc12e275d989a7e9  # HD Bluray + WEB
        reset_unmatched_scores:
          enabled: true
    custom_format_groups:
      add:
        - trash_id: f8bf8eab4617f12dfdbd16303d8da245  # [Required] Golden Rule HD
        - trash_id: f4f1474b963b24cf983455743aa9906c  # [Optional] Movie Versions
        - trash_id: 9337080378236ce4c0b183e35790d2a7  # [Optional] Miscellaneous
        - trash_id: d9cc9a504e5ede6294c8b973aad4f028  # [Streaming Services] General
    media_naming:
      folder: jellyfin-tmdb
      movie:
        rename: true
        standard: jellyfin-tmdb

sonarr:
  series:
    base_url: http://localhost:8989
    api_key: <SONARR_KEY>
    quality_definition:
      type: series
    quality_profiles:
      - trash_id: 72dae194fc92bf828f32cde7744e51a1  # WEB-1080p
        reset_unmatched_scores:
          enabled: true
    custom_format_groups:
      add:
        - trash_id: 158188097a58d7687dee647e04af0da3  # [Required] Golden Rule HD
        - trash_id: f4a0410a1df109a66d6e47dcadcce014  # [Optional] Miscellaneous
        - trash_id: abe720fab2d27682adc2a735136cec02  # [Streaming Services] General
    media_naming:
      series: jellyfin-tvdb
      season: default
      episodes:
        rename: true
        standard: default
```
