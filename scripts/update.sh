#!/usr/bin/env bash
# =============================================================================
# update.sh - Maintenance script for OXOT Tileserver data updates
# =============================================================================
# Re-downloads, re-converts, and reloads data sources for the tileserver.
# All operations are logged with timestamps to data/update.log.
#
# Usage:
#   ./scripts/update.sh --source osm-infrastructure
#   ./scripts/update.sh --option e
#   ./scripts/update.sh --source basemap --source geonames
# =============================================================================
set -euo pipefail

# ---------------------------------------------------------------------------
# Configuration
# ---------------------------------------------------------------------------
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "${SCRIPT_DIR}/.." && pwd)"
DATA_DIR="${PROJECT_ROOT}/data"
UPDATE_LOG="${DATA_DIR}/update.log"

# Scripts to invoke
DOWNLOAD_SCRIPT="${SCRIPT_DIR}/download.sh"
CONVERT_SCRIPT="${SCRIPT_DIR}/convert.sh"
LOAD_SCRIPT="${SCRIPT_DIR}/load.sh"

# ---------------------------------------------------------------------------
# Utility functions
# ---------------------------------------------------------------------------

log_info() {
    local msg="[INFO] $(date '+%Y-%m-%d %H:%M:%S') $*"
    echo "${msg}"
    echo "${msg}" >> "${UPDATE_LOG}"
}

log_warn() {
    local msg="[WARN] $(date '+%Y-%m-%d %H:%M:%S') $*"
    echo "${msg}"
    echo "${msg}" >> "${UPDATE_LOG}"
}

log_error() {
    local msg="[ERROR] $(date '+%Y-%m-%d %H:%M:%S') $*"
    echo "${msg}" >&2
    echo "${msg}" >> "${UPDATE_LOG}"
}

# Ensure data directory and log file exist
init_log() {
    if [[ ! -d "${DATA_DIR}" ]]; then
        mkdir -p "${DATA_DIR}"
    fi
    # Create log file if it does not exist
    touch "${UPDATE_LOG}"
}

# Check that a required script exists and is executable
require_script() {
    local script="$1"
    if [[ ! -f "${script}" ]]; then
        log_error "Required script not found: ${script}"
        return 1
    fi
}

# Record the duration of an operation
# Arguments: start_time description
log_duration() {
    local start="$1"
    local description="$2"
    local end
    end=$(date +%s)
    local elapsed=$((end - start))
    local minutes=$((elapsed / 60))
    local seconds=$((elapsed % 60))
    log_info "${description} completed in ${minutes}m ${seconds}s"
}

# ---------------------------------------------------------------------------
# Option and source handling
# ---------------------------------------------------------------------------

# Build the flags to pass through to download.sh / convert.sh
# Arguments: sources array, option string
build_flags() {
    local -n _sources=$1
    local _option="$2"
    local flags=()

    if [[ -n "${_option}" ]]; then
        flags+=("--option" "${_option}")
    fi

    for src in "${_sources[@]}"; do
        flags+=("--source" "${src}")
    done

    echo "${flags[@]}"
}

# ---------------------------------------------------------------------------
# Pipeline steps
# ---------------------------------------------------------------------------

# Step 1: Download
run_download() {
    local flags="$1"

    log_info "--- Step 1/3: Downloading data ---"
    require_script "${DOWNLOAD_SCRIPT}"

    local start
    start=$(date +%s)

    # shellcheck disable=SC2086
    if ! bash "${DOWNLOAD_SCRIPT}" ${flags}; then
        log_error "Download step failed."
        return 1
    fi

    log_duration "${start}" "Download"
}

# Step 2: Convert
run_convert() {
    local flags="$1"

    log_info "--- Step 2/3: Converting data ---"
    require_script "${CONVERT_SCRIPT}"

    # Force overwrite during updates so we regenerate tiles
    local convert_flags="${flags} --force"

    local start
    start=$(date +%s)

    # shellcheck disable=SC2086
    if ! bash "${CONVERT_SCRIPT}" ${convert_flags}; then
        log_error "Conversion step failed."
        return 1
    fi

    log_duration "${start}" "Conversion"
}

# Step 3: Load
run_load() {
    log_info "--- Step 3/3: Loading tiles into tileserver ---"
    require_script "${LOAD_SCRIPT}"

    local start
    start=$(date +%s)

    if ! bash "${LOAD_SCRIPT}"; then
        log_error "Load step failed."
        return 1
    fi

    log_duration "${start}" "Load"
}

# ---------------------------------------------------------------------------
# Usage
# ---------------------------------------------------------------------------

usage() {
    cat <<'USAGE'
Usage: update.sh [OPTIONS]

Re-download, re-convert, and reload data for the OXOT Tileserver.

This script runs the full pipeline: download -> convert -> load,
and logs all operations with timestamps to data/update.log.

OPTIONS:
  --source NAME     Update a specific source (can be repeated)
  --option LETTER   Update all sources for an option (A through E)
  --skip-download   Skip the download step (re-convert and reload only)
  --skip-convert    Skip the convert step (re-download and reload only)
  --help            Show this help message

SOURCES:
  basemap, osm-infrastructure, geonames, natural-earth, census-us,
  eurostat, abs-australia, eia-powerplants, hifld-infrastructure,
  epa-water, nid-dams, eea-water

OPTIONS (A-E):
  A  basemap, osm-infrastructure, natural-earth
  B  census-us, hifld-infrastructure, eia-powerplants, nid-dams, epa-water
  C  basemap, osm-infrastructure, census-us, hifld-infrastructure
  D  hifld-infrastructure, census-us
  E  basemap, osm-infrastructure, geonames, eurostat, census-us, abs-australia

EXAMPLES:
  ./scripts/update.sh --source osm-infrastructure
  ./scripts/update.sh --option e
  ./scripts/update.sh --source basemap --skip-download
USAGE
}

# ---------------------------------------------------------------------------
# Main entry point
# ---------------------------------------------------------------------------

main() {
    local sources=()
    local option=""
    local skip_download=0
    local skip_convert=0

    # Parse arguments
    while [[ $# -gt 0 ]]; do
        case "$1" in
            --source)
                shift
                if [[ $# -eq 0 ]]; then
                    log_error "--source requires an argument"
                    usage
                    exit 1
                fi
                sources+=("$1")
                shift
                ;;
            --option)
                shift
                if [[ $# -eq 0 ]]; then
                    log_error "--option requires an argument"
                    usage
                    exit 1
                fi
                option="$1"
                shift
                ;;
            --skip-download)
                skip_download=1
                shift
                ;;
            --skip-convert)
                skip_convert=1
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

    # Validate arguments
    if [[ ${#sources[@]} -eq 0 && -z "${option}" ]]; then
        log_error "No source or option specified."
        usage
        exit 1
    fi

    # Initialize logging
    init_log

    # Build flags string to pass through to sub-scripts
    local flags
    flags=$(build_flags sources "${option}")

    # Determine description for logging
    local description=""
    if [[ -n "${option}" ]]; then
        description="option ${option}"
    fi
    if [[ ${#sources[@]} -gt 0 ]]; then
        if [[ -n "${description}" ]]; then
            description="${description} + sources: ${sources[*]}"
        else
            description="sources: ${sources[*]}"
        fi
    fi

    log_info "========================================"
    log_info "OXOT Tileserver Update Pipeline"
    log_info "Updating: ${description}"
    log_info "========================================"

    local pipeline_start
    pipeline_start=$(date +%s)
    local failed=0

    # Step 1: Download
    if [[ ${skip_download} -eq 0 ]]; then
        if ! run_download "${flags}"; then
            log_error "Download step failed. Continuing with conversion..."
            failed=$((failed + 1))
        fi
    else
        log_info "Skipping download step (--skip-download)."
    fi

    # Step 2: Convert
    if [[ ${skip_convert} -eq 0 ]]; then
        if ! run_convert "${flags}"; then
            log_error "Conversion step failed. Continuing with load..."
            failed=$((failed + 1))
        fi
    else
        log_info "Skipping conversion step (--skip-convert)."
    fi

    # Step 3: Load (always runs -- restarts tileserver and validates)
    if ! run_load; then
        log_error "Load step failed."
        failed=$((failed + 1))
    fi

    # Final summary
    log_duration "${pipeline_start}" "Full update pipeline"

    log_info "========================================"
    if [[ ${failed} -gt 0 ]]; then
        log_warn "Update completed with ${failed} step failure(s)."
        log_warn "Review the log for details: ${UPDATE_LOG}"
        exit 1
    else
        log_info "Update completed successfully."
        log_info "Log file: ${UPDATE_LOG}"
    fi
    log_info "========================================"
}

main "$@"
