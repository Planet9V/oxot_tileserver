#!/usr/bin/env bash
# =============================================================================
# load.sh - Load tile files into tileserver-gl and verify availability
# =============================================================================
# Lists all .mbtiles and .pmtiles files in data/tiles/, validates them,
# restarts the tileserver container, waits for health check, and prints
# available tilesets.
#
# Usage:
#   ./scripts/load.sh
#   ./scripts/load.sh --port 8080
#   ./scripts/load.sh --no-restart
# =============================================================================
set -euo pipefail

# ---------------------------------------------------------------------------
# Configuration
# ---------------------------------------------------------------------------
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "${SCRIPT_DIR}/.." && pwd)"
TILES_DIR="${PROJECT_ROOT}/data/tiles"

TILESERVER_PORT="${TILESERVER_PORT:-8080}"
TILESERVER_URL="http://localhost:${TILESERVER_PORT}"
HEALTH_TIMEOUT=60         # seconds to wait for health check
HEALTH_INTERVAL=3         # seconds between health check attempts
COMPOSE_PROJECT=""        # auto-detected from docker-compose.yml

# ---------------------------------------------------------------------------
# Utility functions
# ---------------------------------------------------------------------------

log_info() {
    echo "[INFO] $(date '+%Y-%m-%d %H:%M:%S') $*"
}

log_warn() {
    echo "[WARN] $(date '+%Y-%m-%d %H:%M:%S') $*"
}

log_error() {
    echo "[ERROR] $(date '+%Y-%m-%d %H:%M:%S') $*" >&2
}

# Get file size in human-readable format (cross-platform)
file_size_human() {
    local file="$1"
    if command -v numfmt &>/dev/null; then
        stat -c%s "${file}" 2>/dev/null | numfmt --to=iec-i --suffix=B
    elif [[ "$(uname)" == "Darwin" ]]; then
        local bytes
        bytes=$(stat -f%z "${file}" 2>/dev/null || echo "0")
        # Simple human-readable conversion
        if [[ ${bytes} -ge 1073741824 ]]; then
            echo "$((bytes / 1073741824)) GiB"
        elif [[ ${bytes} -ge 1048576 ]]; then
            echo "$((bytes / 1048576)) MiB"
        elif [[ ${bytes} -ge 1024 ]]; then
            echo "$((bytes / 1024)) KiB"
        else
            echo "${bytes} B"
        fi
    else
        ls -lh "${file}" | awk '{print $5}'
    fi
}

# Get raw file size in bytes (cross-platform)
file_size_bytes() {
    local file="$1"
    stat -f%z "${file}" 2>/dev/null || stat -c%s "${file}" 2>/dev/null || echo "0"
}

# ---------------------------------------------------------------------------
# Core functions
# ---------------------------------------------------------------------------

# List and validate all tile files in data/tiles/
list_and_validate_tiles() {
    log_info "Scanning for tile files in: ${TILES_DIR}"

    if [[ ! -d "${TILES_DIR}" ]]; then
        log_error "Tiles directory not found: ${TILES_DIR}"
        return 1
    fi

    local total_files=0
    local valid_files=0
    local invalid_files=0

    echo ""
    printf "  %-45s %-12s %-8s\n" "FILE" "SIZE" "STATUS"
    printf "  %-45s %-12s %-8s\n" "----" "----" "------"

    for tile_file in "${TILES_DIR}"/*.mbtiles "${TILES_DIR}"/*.pmtiles; do
        [[ -f "${tile_file}" ]] || continue
        total_files=$((total_files + 1))

        local basename
        basename=$(basename "${tile_file}")
        local size_human
        size_human=$(file_size_human "${tile_file}")
        local size_bytes
        size_bytes=$(file_size_bytes "${tile_file}")

        if [[ "${size_bytes}" -gt 0 ]]; then
            printf "  %-45s %-12s %-8s\n" "${basename}" "${size_human}" "OK"
            valid_files=$((valid_files + 1))
        else
            printf "  %-45s %-12s %-8s\n" "${basename}" "0 B" "EMPTY"
            invalid_files=$((invalid_files + 1))
        fi
    done

    echo ""
    log_info "Found ${total_files} tile file(s): ${valid_files} valid, ${invalid_files} empty/invalid"

    if [[ ${total_files} -eq 0 ]]; then
        log_warn "No tile files found. Run download.sh and convert.sh first."
        return 1
    fi

    if [[ ${invalid_files} -gt 0 ]]; then
        log_warn "${invalid_files} file(s) are empty (0 bytes) and will not serve correctly."
    fi

    return 0
}

# Restart the tileserver container
restart_tileserver() {
    log_info "Restarting tileserver container..."

    # Determine docker compose command (v2 vs v1)
    local compose_cmd=""
    if docker compose version &>/dev/null 2>&1; then
        compose_cmd="docker compose"
    elif command -v docker-compose &>/dev/null; then
        compose_cmd="docker-compose"
    else
        log_error "Neither 'docker compose' nor 'docker-compose' found."
        return 1
    fi

    # Restart tileserver service
    cd "${PROJECT_ROOT}"
    ${compose_cmd} restart tileserver

    log_info "Tileserver container restarted."
}

# Wait for the tileserver health check to pass
wait_for_health() {
    log_info "Waiting for tileserver health check at ${TILESERVER_URL}/health ..."

    local elapsed=0
    while [[ ${elapsed} -lt ${HEALTH_TIMEOUT} ]]; do
        if curl -sf "${TILESERVER_URL}/health" &>/dev/null; then
            log_info "Tileserver is healthy after ${elapsed}s."
            return 0
        fi

        sleep "${HEALTH_INTERVAL}"
        elapsed=$((elapsed + HEALTH_INTERVAL))
    done

    log_error "Tileserver did not become healthy within ${HEALTH_TIMEOUT}s."
    log_error "Check logs: docker compose logs tileserver"
    return 1
}

# Query and display available tilesets from tileserver
print_available_tilesets() {
    log_info "Querying available tilesets..."

    local index_json
    index_json=$(curl -sf "${TILESERVER_URL}/index.json" 2>/dev/null || true)

    if [[ -z "${index_json}" ]]; then
        log_warn "Could not fetch /index.json from tileserver."
        log_warn "The tileserver may still be initializing, or no tiles are configured."
        return 1
    fi

    echo ""
    log_info "=== Available Tilesets ==="

    # Parse the index.json to list tilesets
    # tileserver-gl returns a JSON object where keys are tileset names
    if command -v jq &>/dev/null; then
        echo "${index_json}" | jq -r 'keys[] as $k | "  \($k): \(.[$k].name // $k)"'
    else
        # Fallback: just print the raw JSON formatted
        echo "${index_json}" | python3 -c "
import json, sys
data = json.load(sys.stdin)
if isinstance(data, dict):
    for key, val in data.items():
        name = val.get('name', key) if isinstance(val, dict) else key
        print(f'  {key}: {name}')
elif isinstance(data, list):
    for item in data:
        if isinstance(item, dict):
            print(f'  {item.get(\"id\", \"unknown\")}: {item.get(\"name\", \"\")}')
" 2>/dev/null || echo "  (Could not parse index.json -- install jq for better output)"
    fi

    echo ""
    log_info "Tileserver URL: ${TILESERVER_URL}"
    log_info "Tile endpoint:  ${TILESERVER_URL}/data/{tileset}/{z}/{x}/{y}.pbf"
    log_info "TileJSON:       ${TILESERVER_URL}/data/{tileset}.json"
    log_info "Viewer:         ${TILESERVER_URL}/"
}

# ---------------------------------------------------------------------------
# Usage
# ---------------------------------------------------------------------------

usage() {
    cat <<'USAGE'
Usage: load.sh [OPTIONS]

Validate tile files, restart tileserver, and list available tilesets.

OPTIONS:
  --port PORT       Tileserver port (default: 8080, or TILESERVER_PORT env)
  --no-restart      Skip container restart (just list and validate)
  --help            Show this help message

EXAMPLES:
  ./scripts/load.sh
  ./scripts/load.sh --port 9090
  ./scripts/load.sh --no-restart
USAGE
}

# ---------------------------------------------------------------------------
# Main entry point
# ---------------------------------------------------------------------------

main() {
    local do_restart=1

    # Parse arguments
    while [[ $# -gt 0 ]]; do
        case "$1" in
            --port)
                shift
                if [[ $# -eq 0 ]]; then
                    log_error "--port requires an argument"
                    exit 1
                fi
                TILESERVER_PORT="$1"
                TILESERVER_URL="http://localhost:${TILESERVER_PORT}"
                shift
                ;;
            --no-restart)
                do_restart=0
                shift
                ;;
            --help|-h)
                usage
                exit 0
                ;;
            *)
                log_error "Unknown argument: $1"
                usage
                exit 1
                ;;
        esac
    done

    log_info "========================================"
    log_info "OXOT Tileserver - Load & Verify"
    log_info "========================================"

    # Step 1: List and validate tile files
    if ! list_and_validate_tiles; then
        log_error "Tile validation failed. Cannot proceed."
        exit 1
    fi

    # Step 2: Restart tileserver container
    if [[ ${do_restart} -eq 1 ]]; then
        if ! restart_tileserver; then
            log_error "Failed to restart tileserver container."
            exit 1
        fi

        # Step 3: Wait for health check
        if ! wait_for_health; then
            exit 1
        fi
    else
        log_info "Skipping container restart (--no-restart)."
    fi

    # Step 4: Print available tilesets
    print_available_tilesets

    log_info "========================================"
    log_info "Tileserver load complete."
    log_info "========================================"
}

main "$@"
