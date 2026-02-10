#!/usr/bin/env bash
# Option C: Modern + Comprehensive -- Basemap + OSM + Census + HIFLD (~16 GB)
# Sources: basemap, osm-infrastructure, census-us, hifld-infrastructure
set -euo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

echo "============================================"
echo "  OXOT Tileserver -- Option C: Modern +"
echo "  Comprehensive"
echo "  Estimated size: ~16 GB"
echo "  Estimated time: ~5 hours"
echo "============================================"
echo ""
echo "Sources:"
echo "  - Protomaps Basemap (regional extract)"
echo "  - OSM Infrastructure (power, telecoms, water)"
echo "  - US Census TIGER/Line + ACS (tracts, demographics)"
echo "  - HIFLD (multi-sector critical infrastructure)"
echo ""
read -p "Continue? [y/N] " -n 1 -r
echo
[[ $REPLY =~ ^[Yy]$ ]] || exit 0

"$SCRIPT_DIR/scripts/download.sh" --option c
"$SCRIPT_DIR/scripts/convert.sh" --option c
"$SCRIPT_DIR/scripts/load.sh"

echo ""
echo "Option C complete. Access tileserver at http://localhost:${TILESERVER_PORT:-8080}"
