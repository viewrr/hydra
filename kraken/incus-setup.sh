#!/bin/bash
# Incus container setup for Kraken NAS
# Run on the Debian 13 host after installing Incus
set -euo pipefail

# --- Storage ---
incus storage create ssd-pool dir

# --- Jellyfin Container ---
incus launch images:ubuntu/noble jellyfin
incus config set jellyfin security.privileged=true
incus config device add jellyfin gpu gpu gputype=drm
incus config device add jellyfin media disk source=/mnt/hdd/media path=/media
incus config device add jellyfin root disk path=/ pool=ssd-pool
incus config device add jellyfin web proxy listen=tcp:0.0.0.0:8096 connect=tcp:127.0.0.1:8096

# --- Arr Stack Container ---
incus launch images:ubuntu/noble arr-stack
incus config set arr-stack security.nesting=true security.privileged=true
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

echo "=== Containers created ==="
echo "Next steps:"
echo "  1. Install Jellyfin inside jellyfin container"
echo "  2. Install Docker inside arr-stack container"
echo "  3. Deploy arr-stack/docker-compose.yml"
