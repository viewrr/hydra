#!/bin/bash
# Install Recyclarr and run initial TRaSH Guides sync
# Run inside the arr-stack container
set -euo pipefail

ARCH=$(uname -m)
case "$ARCH" in
  x86_64)  RECYCLARR_ARCH="linux-x64" ;;
  aarch64) RECYCLARR_ARCH="linux-arm64" ;;
  *)       echo "Unsupported arch: $ARCH"; exit 1 ;;
esac

echo "--- Installing Recyclarr ($RECYCLARR_ARCH) ---"
curl -fsSL "https://github.com/recyclarr/recyclarr/releases/latest/download/recyclarr-${RECYCLARR_ARCH}.tar.xz" \
  | tar xJ -C /usr/local/bin

recyclarr --version

echo "--- Setting up config ---"
mkdir -p /opt/arr-stack/recyclarr
if [ ! -f /opt/arr-stack/recyclarr/recyclarr.yml ]; then
  cp "$(dirname "$0")/recyclarr.yml" /opt/arr-stack/recyclarr/recyclarr.yml
  echo "Copied recyclarr.yml — edit API keys before syncing!"
  echo "  vi /opt/arr-stack/recyclarr/recyclarr.yml"
else
  echo "Config already exists at /opt/arr-stack/recyclarr/recyclarr.yml"
fi

echo ""
echo "--- Syncing ---"
recyclarr sync --config /opt/arr-stack/recyclarr/recyclarr.yml

echo ""
echo "=== Recyclarr setup complete ==="
echo "Also set in Radarr & Sonarr UI:"
echo "  Media Management > Proper & Repacks → Do Not Prefer"
