#!/usr/bin/env bash
# Option D: Minimum Viable OXOT -- HIFLD + Census (~8 GB)
# Sources: hifld-infrastructure, census-us
set -euo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

echo "============================================"
echo "  OXOT Tileserver -- Option D: Minimum"
echo "  Viable OXOT"
echo "  Estimated size: ~8 GB"
echo "  Estimated time: ~1.5 hours"
echo "============================================"
echo ""
echo "Sources:"
echo "  - HIFLD (electric, water, emergency infrastructure)"
echo "  - US Census TIGER/Line + ACS (tracts, demographics)"
echo ""
read -p "Continue? [y/N] " -n 1 -r
echo
[[ $REPLY =~ ^[Yy]$ ]] || exit 0

"$SCRIPT_DIR/scripts/download.sh" --option d
"$SCRIPT_DIR/scripts/convert.sh" --option d
"$SCRIPT_DIR/scripts/load.sh"

echo ""
echo "Option D complete. Access tileserver at http://localhost:${TILESERVER_PORT:-8080}"
