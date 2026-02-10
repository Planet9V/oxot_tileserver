#!/usr/bin/env bash
# =============================================================================
# extract-osm.sh - Filter OSM PBF files to infrastructure-only data
# =============================================================================
# Filters Geofabrik PBF extracts to power, telecoms, water, and pipeline
# infrastructure using osmium tags-filter, then converts to GeoJSONSeq
# via ogr2ogr and merges all regions.
#
# Usage:
#   ./scripts/extract-osm.sh
#
# Prerequisites:
#   - osmium (osmium-tool)
#   - ogr2ogr (gdal-bin)
#   - PBF files in data/raw/osm-infrastructure/
# =============================================================================
set -euo pipefail

# ---------------------------------------------------------------------------
# Configuration
# ---------------------------------------------------------------------------
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "${SCRIPT_DIR}/.." && pwd)"
RAW_DIR="${PROJECT_ROOT}/data/raw/osm-infrastructure"
OUTPUT_DIR="${RAW_DIR}"

# PBF files expected in the raw directory
REGIONS=(
    "europe-latest"
    "north-america-latest"
    "australia-oceania-latest"
)

# Osmium tag filters for infrastructure
# Format understood by osmium tags-filter:
#   w/ = ways, n/ = nodes, nw/ = nodes+ways, r/ = relations
OSMIUM_FILTERS=(
    "w/power=line,cable,minor_line"
    "nw/power=substation,plant,generator,tower,pole"
    "nw/man_made=mast,tower"
    "nw/telecom=*"
    "w/man_made=pipeline"
    "nw/amenity=water_works,wastewater_plant"
    "nw/man_made=wastewater_plant,water_works,reservoir_covered"
    "nw/waterway=dam"
)

# OGR layers to extract from filtered PBF (OSM driver layers)
OGR_LAYERS=("lines" "points" "multipolygons")

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

# Check that a required command is available
require_cmd() {
    local cmd="$1"
    if ! command -v "${cmd}" &>/dev/null; then
        log_error "Required command not found: ${cmd}"
        log_error "Run this script inside the converter container."
        exit 1
    fi
}

# Check prerequisites
check_prerequisites() {
    require_cmd osmium
    require_cmd ogr2ogr
    log_info "Prerequisites satisfied: osmium, ogr2ogr"
}

# ---------------------------------------------------------------------------
# Core functions
# ---------------------------------------------------------------------------

# Filter a single PBF file to infrastructure-only tags
# Arguments: region_name (without .osm.pbf suffix)
filter_region() {
    local region="$1"
    local input_pbf="${RAW_DIR}/${region}.osm.pbf"
    local output_pbf="${OUTPUT_DIR}/${region}-infra.osm.pbf"

    if [[ ! -f "${input_pbf}" ]]; then
        log_warn "PBF file not found, skipping: ${input_pbf}"
        return 1
    fi

    if [[ -f "${output_pbf}" ]]; then
        log_info "Filtered PBF already exists: ${output_pbf}"
        return 0
    fi

    log_info "Filtering ${region} to infrastructure tags..."
    log_info "Input:  ${input_pbf}"
    log_info "Output: ${output_pbf}"

    # Build the osmium tags-filter command
    # osmium tags-filter INPUT FILTER1 FILTER2 ... -o OUTPUT
    osmium tags-filter "${input_pbf}" \
        "${OSMIUM_FILTERS[@]}" \
        --overwrite \
        -o "${output_pbf}"

    local output_size
    output_size=$(stat -f%z "${output_pbf}" 2>/dev/null || stat -c%s "${output_pbf}" 2>/dev/null || echo "0")
    log_info "Filtered PBF size: ${output_size} bytes"
}

# Convert a filtered PBF to GeoJSONSeq using ogr2ogr
# Arguments: region_name (without -infra.osm.pbf suffix)
convert_region_to_geojsonseq() {
    local region="$1"
    local input_pbf="${OUTPUT_DIR}/${region}-infra.osm.pbf"

    if [[ ! -f "${input_pbf}" ]]; then
        log_warn "Filtered PBF not found, skipping conversion: ${input_pbf}"
        return 1
    fi

    for layer in "${OGR_LAYERS[@]}"; do
        local output_file="${OUTPUT_DIR}/${region}-infra-${layer}.geojsonseq"

        if [[ -f "${output_file}" ]]; then
            log_info "GeoJSONSeq already exists: ${output_file}"
            continue
        fi

        log_info "Converting ${region} layer '${layer}' to GeoJSONSeq..."

        # ogr2ogr reads the OSM PBF and extracts the specified layer
        # GeoJSONSeq = one GeoJSON feature per line (newline-delimited)
        if ! ogr2ogr -f "GeoJSONSeq" "${output_file}" "${input_pbf}" "${layer}" \
             -progress 2>/dev/null; then
            log_warn "Layer '${layer}' may be empty or failed for ${region}. Continuing."
            # Create empty file so we don't retry
            touch "${output_file}"
        fi

        if [[ -s "${output_file}" ]]; then
            local line_count
            line_count=$(wc -l < "${output_file}" | tr -d ' ')
            log_info "Extracted ${line_count} features from ${region}/${layer}"
        else
            log_info "No features in ${region}/${layer} (empty output)"
        fi
    done
}

# Merge all regional GeoJSONSeq files into combined files per layer
merge_all_regions() {
    log_info "Merging all regional GeoJSONSeq files..."

    for layer in "${OGR_LAYERS[@]}"; do
        local merged_file="${OUTPUT_DIR}/all-regions-infra-${layer}.geojsonseq"

        # Collect all regional files for this layer
        local region_files=()
        for region in "${REGIONS[@]}"; do
            local region_file="${OUTPUT_DIR}/${region}-infra-${layer}.geojsonseq"
            if [[ -s "${region_file}" ]]; then
                region_files+=("${region_file}")
            fi
        done

        if [[ ${#region_files[@]} -eq 0 ]]; then
            log_warn "No data files for layer '${layer}'. Skipping merge."
            continue
        fi

        log_info "Merging ${#region_files[@]} files for layer '${layer}'..."

        # Concatenate all region files (GeoJSONSeq is newline-delimited, so cat works)
        cat "${region_files[@]}" > "${merged_file}"

        local total_lines
        total_lines=$(wc -l < "${merged_file}" | tr -d ' ')
        log_info "Merged ${layer}: ${total_lines} total features -> ${merged_file}"
    done
}

# Print a summary of all output files
print_summary() {
    log_info "========================================"
    log_info "OSM Infrastructure Extraction Summary"
    log_info "========================================"

    for region in "${REGIONS[@]}"; do
        local infra_pbf="${OUTPUT_DIR}/${region}-infra.osm.pbf"
        if [[ -f "${infra_pbf}" ]]; then
            local size
            size=$(stat -f%z "${infra_pbf}" 2>/dev/null || stat -c%s "${infra_pbf}" 2>/dev/null || echo "?")
            log_info "  ${region}-infra.osm.pbf: ${size} bytes"
        fi
    done

    echo ""
    log_info "Merged GeoJSONSeq files:"
    for layer in "${OGR_LAYERS[@]}"; do
        local merged="${OUTPUT_DIR}/all-regions-infra-${layer}.geojsonseq"
        if [[ -s "${merged}" ]]; then
            local lines
            lines=$(wc -l < "${merged}" | tr -d ' ')
            log_info "  all-regions-infra-${layer}.geojsonseq: ${lines} features"
        fi
    done
}

# ---------------------------------------------------------------------------
# Main entry point
# ---------------------------------------------------------------------------

main() {
    log_info "========================================"
    log_info "OSM Infrastructure Extraction Pipeline"
    log_info "========================================"

    check_prerequisites

    if [[ ! -d "${RAW_DIR}" ]]; then
        log_error "Raw data directory not found: ${RAW_DIR}"
        log_error "Run download.sh --source osm-infrastructure first."
        exit 1
    fi

    # Step 1: Filter each region PBF to infrastructure tags
    log_info "--- Step 1: Tag filtering ---"
    local filtered_count=0
    for region in "${REGIONS[@]}"; do
        if filter_region "${region}"; then
            filtered_count=$((filtered_count + 1))
        fi
    done

    if [[ ${filtered_count} -eq 0 ]]; then
        log_error "No PBF files were filtered. Ensure OSM data is downloaded."
        exit 1
    fi

    # Step 2: Convert filtered PBFs to GeoJSONSeq
    log_info "--- Step 2: PBF to GeoJSONSeq conversion ---"
    for region in "${REGIONS[@]}"; do
        convert_region_to_geojsonseq "${region}"
    done

    # Step 3: Merge all regions
    log_info "--- Step 3: Merging regions ---"
    merge_all_regions

    # Summary
    print_summary

    log_info "========================================"
    log_info "OSM extraction pipeline complete."
    log_info "Output directory: ${OUTPUT_DIR}"
    log_info "========================================"
}

main "$@"
