#!/usr/bin/env bash
# Option A: Quick Start -- Lightweight Global Overview (~5 GB)
# Sources: Protomaps basemap, OSM infrastructure, Natural Earth places
set -euo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

echo "============================================"
echo "  OXOT Tileserver -- Option A: Quick Start"
echo "  Estimated size: ~5 GB"
echo "  Estimated time: ~40 minutes"
echo "============================================"
echo ""
echo "Sources:"
echo "  - Protomaps Basemap (regional extract)"
echo "  - OSM Infrastructure (power, telecoms, water)"
echo "  - Natural Earth Populated Places"
echo ""
read -p "Continue? [y/N] " -n 1 -r
echo
[[ $REPLY =~ ^[Yy]$ ]] || exit 0

"$SCRIPT_DIR/scripts/download.sh" --option a
"$SCRIPT_DIR/scripts/convert.sh" --option a
"$SCRIPT_DIR/scripts/load.sh"

echo ""
echo "Option A complete. Access tileserver at http://localhost:${TILESERVER_PORT:-8080}"
