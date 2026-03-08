#!/bin/bash
# Add public torrent indexers to Prowlarr + FlareSolverr proxy
# Run inside the arr-stack container after Prowlarr is up
set -euo pipefail

PROWLARR_KEY="${PROWLARR_KEY:-$(grep -oP '<ApiKey>\K[^<]+' /opt/arr-stack/prowlarr/config.xml)}"
PROWLARR_URL="http://prowlarr:9696"

# Add FlareSolverr as indexer proxy (needed for cloudflare-protected sites)
echo "--- Adding FlareSolverr proxy ---"
curl -s -X POST "$PROWLARR_URL/api/v1/indexerProxy" \
  -H "X-Api-Key: $PROWLARR_KEY" -H "Content-Type: application/json" \
  -d '{"name":"FlareSolverr","implementation":"FlareSolverr","configContract":"FlareSolverrSettings","fields":[{"name":"host","value":"http://flaresolverr:8191/"},{"name":"requestTimeout","value":60}],"tags":[]}'
echo ""

# Create a tag for flaresolverr-required indexers
echo "--- Creating flaresolverr tag ---"
FLARESOLVERR_TAG_ID=$(curl -s -X POST "$PROWLARR_URL/api/v1/tag" \
  -H "X-Api-Key: $PROWLARR_KEY" -H "Content-Type: application/json" \
  -d '{"label":"flaresolverr"}' | grep -o '"id":[0-9]*' | head -1 | cut -d: -f2)
echo "Tag ID: $FLARESOLVERR_TAG_ID"

add_indexer() {
  local name="$1"
  local def="$2"
  local tags="$3"
  echo "--- Adding $name ---"
  curl -s -o /dev/null -w "%{http_code}" -X POST "$PROWLARR_URL/api/v1/indexer" \
    -H "X-Api-Key: $PROWLARR_KEY" -H "Content-Type: application/json" \
    -d "{
      \"name\": \"$name\",
      \"implementation\": \"Cardigann\",
      \"configContract\": \"CardigannSettings\",
      \"protocol\": \"torrent\",
      \"enable\": true,
      \"appProfileId\": 1,
      \"priority\": 25,
      \"tags\": [$tags],
      \"fields\": [
        {\"name\": \"definitionFile\", \"value\": \"$def\"},
        {\"name\": \"baseUrl\"},
        {\"name\": \"baseSettings.limitsUnit\", \"value\": 0},
        {\"name\": \"torrentBaseSettings.preferMagnetUrl\", \"value\": true}
      ]
    }"
  echo " $name"
}

# Add indexers (1337x needs FlareSolverr for cloudflare bypass)
add_indexer "1337x" "1337x" "$FLARESOLVERR_TAG_ID"
add_indexer "YTS" "yts" ""
add_indexer "The Pirate Bay" "thepiratebay" ""
add_indexer "EZTV" "eztv" ""
add_indexer "LimeTorrents" "limetorrents" ""
add_indexer "TorrentGalaxy" "torrentgalaxyclone" ""
add_indexer "Nyaa.si" "nyaasi" ""
add_indexer "KickassTorrents" "kickasstorrentsws" ""

echo ""
echo "--- Syncing indexers to apps ---"
curl -s -X POST "$PROWLARR_URL/api/v1/applications/action/sync" \
  -H "X-Api-Key: $PROWLARR_KEY"
echo ""

echo "=== Listing indexers ==="
curl -s "$PROWLARR_URL/api/v1/indexer" \
  -H "X-Api-Key: $PROWLARR_KEY" | grep -o '"name":"[^"]*"' | sed 's/"name":"//;s/"//'

echo ""
echo "=== DONE ==="
