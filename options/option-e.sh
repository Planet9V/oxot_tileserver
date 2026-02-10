#!/usr/bin/env bash
# Option E: Multi-Region Full Coverage -- Europe + N. America + AU/NZ (~22 GB)
# Sources: basemap, osm-infrastructure, geonames, eurostat, census-us, abs-australia
# [RECOMMENDED]
set -euo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

echo "============================================"
echo "  OXOT Tileserver -- Option E: Multi-Region"
echo "  Full Coverage  [RECOMMENDED]"
echo "  Estimated size: ~22 GB"
echo "  Estimated time: ~6 hours"
echo "============================================"
echo ""
echo "Sources:"
echo "  - Protomaps Basemap (3-region extract)"
echo "  - OSM Infrastructure (power, telecoms, water)"
echo "  - GeoNames cities15000 (25K+ cities, global)"
echo "  - Eurostat NUTS + Nuts2json (European demographics)"
echo "  - US Census TIGER/Line + ACS (US demographics)"
echo "  - ABS Census Boundaries (Australian demographics)"
echo ""
echo "Regions: Europe, North America, Australia/Oceania"
echo ""
read -p "Continue? [y/N] " -n 1 -r
echo
[[ $REPLY =~ ^[Yy]$ ]] || exit 0

"$SCRIPT_DIR/scripts/download.sh" --option e
"$SCRIPT_DIR/scripts/convert.sh" --option e
"$SCRIPT_DIR/scripts/load.sh"

echo ""
echo "Option E complete. Access tileserver at http://localhost:${TILESERVER_PORT:-8080}"
