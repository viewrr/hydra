#!/bin/bash
# Configure arr stack: download clients, root folders, app connections, Bazarr
# Run inside the arr-stack container after all services are up
#
# API keys are auto-generated on first start. Extract them:
#   grep -oP '<ApiKey>\K[^<]+' /opt/arr-stack/radarr/config.xml
#   grep -oP '<ApiKey>\K[^<]+' /opt/arr-stack/sonarr/config.xml
#   grep -oP '<ApiKey>\K[^<]+' /opt/arr-stack/lidarr/config.xml
#   grep -oP '<ApiKey>\K[^<]+' /opt/arr-stack/prowlarr/config.xml
set -euo pipefail

RADARR_KEY="${RADARR_KEY:-$(grep -oP '<ApiKey>\K[^<]+' /opt/arr-stack/radarr/config.xml)}"
SONARR_KEY="${SONARR_KEY:-$(grep -oP '<ApiKey>\K[^<]+' /opt/arr-stack/sonarr/config.xml)}"
LIDARR_KEY="${LIDARR_KEY:-$(grep -oP '<ApiKey>\K[^<]+' /opt/arr-stack/lidarr/config.xml)}"
PROWLARR_KEY="${PROWLARR_KEY:-$(grep -oP '<ApiKey>\K[^<]+' /opt/arr-stack/prowlarr/config.xml)}"

ok() { python3 -c "import sys,json; d=json.load(sys.stdin); print(d.get('name','') or d.get('path','') or d)" 2>/dev/null || echo "done"; }

# === RADARR ===
echo "--- Radarr: qBittorrent ---"
curl -s -X POST "http://radarr:7878/api/v3/downloadclient" \
  -H "X-Api-Key: $RADARR_KEY" -H "Content-Type: application/json" \
  -d '{"name":"qBittorrent","implementation":"QBittorrent","configContract":"QBittorrentSettings","enable":true,"protocol":"torrent","priority":1,"fields":[{"name":"host","value":"qbittorrent"},{"name":"port","value":8080},{"name":"useSsl","value":false},{"name":"movieCategory","value":"radarr"}]}' | ok

echo "--- Radarr: Root folder ---"
curl -s -X POST "http://radarr:7878/api/v3/rootfolder" \
  -H "X-Api-Key: $RADARR_KEY" -H "Content-Type: application/json" \
  -d '{"path":"/media/movies"}' | ok

# === SONARR ===
echo "--- Sonarr: qBittorrent ---"
curl -s -X POST "http://sonarr:8989/api/v3/downloadclient" \
  -H "X-Api-Key: $SONARR_KEY" -H "Content-Type: application/json" \
  -d '{"name":"qBittorrent","implementation":"QBittorrent","configContract":"QBittorrentSettings","enable":true,"protocol":"torrent","priority":1,"fields":[{"name":"host","value":"qbittorrent"},{"name":"port","value":8080},{"name":"useSsl","value":false},{"name":"tvCategory","value":"sonarr"}]}' | ok

echo "--- Sonarr: Root folder ---"
curl -s -X POST "http://sonarr:8989/api/v3/rootfolder" \
  -H "X-Api-Key: $SONARR_KEY" -H "Content-Type: application/json" \
  -d '{"path":"/media/tv"}' | ok

# === LIDARR ===
echo "--- Lidarr: qBittorrent ---"
curl -s -X POST "http://lidarr:8686/api/v1/downloadclient" \
  -H "X-Api-Key: $LIDARR_KEY" -H "Content-Type: application/json" \
  -d '{"name":"qBittorrent","implementation":"QBittorrent","configContract":"QBittorrentSettings","enable":true,"protocol":"torrent","priority":1,"fields":[{"name":"host","value":"qbittorrent"},{"name":"port","value":8080},{"name":"useSsl","value":false},{"name":"musicCategory","value":"lidarr"}]}' | ok

echo "--- Lidarr: Root folder ---"
META_ID=$(curl -s "http://lidarr:8686/api/v1/metadataprofile" -H "X-Api-Key: $LIDARR_KEY" | python3 -c "import sys,json; print(json.load(sys.stdin)[0]['id'])" 2>/dev/null)
QUAL_ID=$(curl -s "http://lidarr:8686/api/v1/qualityprofile" -H "X-Api-Key: $LIDARR_KEY" | python3 -c "import sys,json; print(json.load(sys.stdin)[0]['id'])" 2>/dev/null)
curl -s -X POST "http://lidarr:8686/api/v1/rootfolder" \
  -H "X-Api-Key: $LIDARR_KEY" -H "Content-Type: application/json" \
  -d "{\"path\":\"/media/music\",\"name\":\"Music\",\"defaultMetadataProfileId\":${META_ID:-1},\"defaultQualityProfileId\":${QUAL_ID:-1}}" | ok

# === PROWLARR ===
echo "--- Prowlarr: qBittorrent ---"
curl -s -X POST "http://prowlarr:9696/api/v1/downloadclient" \
  -H "X-Api-Key: $PROWLARR_KEY" -H "Content-Type: application/json" \
  -d '{"name":"qBittorrent","implementation":"QBittorrent","configContract":"QBittorrentSettings","enable":true,"protocol":"torrent","priority":1,"categories":[],"fields":[{"name":"host","value":"qbittorrent"},{"name":"port","value":8080},{"name":"useSsl","value":false},{"name":"category","value":"prowlarr"},{"name":"username","value":""},{"name":"password","value":""}]}' | ok

# === PROWLARR -> APP CONNECTIONS ===
echo "--- Prowlarr: Connect Radarr ---"
curl -s -X POST "http://prowlarr:9696/api/v1/applications" \
  -H "X-Api-Key: $PROWLARR_KEY" -H "Content-Type: application/json" \
  -d "{\"name\":\"Radarr\",\"implementation\":\"Radarr\",\"configContract\":\"RadarrSettings\",\"syncLevel\":\"fullSync\",\"fields\":[{\"name\":\"prowlarrUrl\",\"value\":\"http://prowlarr:9696\"},{\"name\":\"baseUrl\",\"value\":\"http://radarr:7878\"},{\"name\":\"apiKey\",\"value\":\"$RADARR_KEY\"},{\"name\":\"syncCategories\",\"value\":[2000,2010,2020,2030,2040,2045,2050,2060,2070,2080,2090]}]}" | ok

echo "--- Prowlarr: Connect Sonarr ---"
curl -s -X POST "http://prowlarr:9696/api/v1/applications" \
  -H "X-Api-Key: $PROWLARR_KEY" -H "Content-Type: application/json" \
  -d "{\"name\":\"Sonarr\",\"implementation\":\"Sonarr\",\"configContract\":\"SonarrSettings\",\"syncLevel\":\"fullSync\",\"fields\":[{\"name\":\"prowlarrUrl\",\"value\":\"http://prowlarr:9696\"},{\"name\":\"baseUrl\",\"value\":\"http://sonarr:8989\"},{\"name\":\"apiKey\",\"value\":\"$SONARR_KEY\"},{\"name\":\"syncCategories\",\"value\":[5000,5010,5020,5030,5040,5045,5050,5060,5070,5080,5090]}]}" | ok

echo "--- Prowlarr: Connect Lidarr ---"
curl -s -X POST "http://prowlarr:9696/api/v1/applications" \
  -H "X-Api-Key: $PROWLARR_KEY" -H "Content-Type: application/json" \
  -d "{\"name\":\"Lidarr\",\"implementation\":\"Lidarr\",\"configContract\":\"LidarrSettings\",\"syncLevel\":\"fullSync\",\"fields\":[{\"name\":\"prowlarrUrl\",\"value\":\"http://prowlarr:9696\"},{\"name\":\"baseUrl\",\"value\":\"http://lidarr:8686\"},{\"name\":\"apiKey\",\"value\":\"$LIDARR_KEY\"},{\"name\":\"syncCategories\",\"value\":[3000,3010,3020,3030,3040]}]}" | ok

# === BAZARR ===
echo "--- Bazarr: Configure Radarr + Sonarr ---"
BAZARR_KEY=$(python3 -c "import yaml; print(yaml.safe_load(open('/opt/arr-stack/bazarr/config/config.yaml'))['auth']['apikey'])" 2>/dev/null || true)
if [ -n "$BAZARR_KEY" ]; then
  curl -s -X PATCH "http://bazarr:6767/api/system/settings/radarr" \
    -H "X-API-KEY: $BAZARR_KEY" -H "Content-Type: application/json" \
    -d "{\"ip\":\"radarr\",\"port\":7878,\"apikey\":\"$RADARR_KEY\",\"enabled\":true}" | ok
  curl -s -X PATCH "http://bazarr:6767/api/system/settings/sonarr" \
    -H "X-API-KEY: $BAZARR_KEY" -H "Content-Type: application/json" \
    -d "{\"ip\":\"sonarr\",\"port\":8989,\"apikey\":\"$SONARR_KEY\",\"enabled\":true}" | ok
else
  echo "Could not get Bazarr API key (start Bazarr first)"
fi

echo ""
echo "=== ALL DONE ==="
