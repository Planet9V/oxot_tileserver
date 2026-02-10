#!/usr/bin/env bash
# Option B: US Federal Authority -- HIFLD + Census + EIA + NID + EPA (~10 GB)
# Sources: census-us, hifld-infrastructure, eia-powerplants, nid-dams, epa-water
set -euo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

echo "============================================"
echo "  OXOT Tileserver -- Option B: US Federal"
echo "  Authority"
echo "  Estimated size: ~10 GB"
echo "  Estimated time: ~3 hours"
echo "============================================"
echo ""
echo "Sources:"
echo "  - US Census TIGER/Line + ACS (tracts, demographics)"
echo "  - HIFLD (multi-sector critical infrastructure)"
echo "  - EIA Power Plants (capacity, fuel type, owner)"
echo "  - NID -- National Inventory of Dams (92K+ dams)"
echo "  - EPA SDWIS (community water systems)"
echo ""
read -p "Continue? [y/N] " -n 1 -r
echo
[[ $REPLY =~ ^[Yy]$ ]] || exit 0

"$SCRIPT_DIR/scripts/download.sh" --option b
"$SCRIPT_DIR/scripts/convert.sh" --option b
"$SCRIPT_DIR/scripts/load.sh"

echo ""
echo "Option B complete. Access tileserver at http://localhost:${TILESERVER_PORT:-8080}"
