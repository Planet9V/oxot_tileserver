#!/usr/bin/env bash
# =============================================================================
# download.sh - Universal download script for OXOT Tileserver data sources
# =============================================================================
# Usage:
#   ./scripts/download.sh --source basemap
#   ./scripts/download.sh --option e
#   ./scripts/download.sh --source basemap --source geonames
#
# All downloads are placed in data/raw/{source_name}/ with resume support.
# =============================================================================
set -euo pipefail

# ---------------------------------------------------------------------------
# Configuration
# ---------------------------------------------------------------------------
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "${SCRIPT_DIR}/.." && pwd)"
RAW_DIR="${PROJECT_ROOT}/data/raw"

# Bounding boxes for Protomaps regional extracts
BBOX_EUROPE="-25,34,45,72"
BBOX_NORTH_AMERICA="-170,15,-50,85"
BBOX_AUSTRALIA_NZ="110,-50,180,-8"

# Protomaps basemap daily build URL
PROTOMAPS_BASE_URL="https://maps.protomaps.com/builds/"

# Geofabrik PBF URLs
GEOFABRIK_EUROPE="https://download.geofabrik.de/europe-latest.osm.pbf"
GEOFABRIK_NORTH_AMERICA="https://download.geofabrik.de/north-america-latest.osm.pbf"
GEOFABRIK_AUSTRALIA="https://download.geofabrik.de/australia-oceania-latest.osm.pbf"

# GeoNames
GEONAMES_URL="https://download.geonames.org/export/dump/cities15000.zip"

# Natural Earth
NE_POPULATED_PLACES="https://naciscdn.org/naturalearth/10m/cultural/ne_10m_populated_places_simple.zip"
NE_URBAN_AREAS="https://naciscdn.org/naturalearth/10m/cultural/ne_10m_urban_areas.zip"

# US Census TIGER/Line 2024 (national files)
TIGER_BASE="https://www2.census.gov/geo/tiger/TIGER2024"
TIGER_STATES="${TIGER_BASE}/STATE/tl_2024_us_state.zip"
TIGER_COUNTIES="${TIGER_BASE}/COUNTY/tl_2024_us_county.zip"
TIGER_TRACTS="${TIGER_BASE}/TRACT/"

# Eurostat Nuts2json NUTS3 regions
EUROSTAT_NUTS3="https://raw.githubusercontent.com/eurostat/Nuts2json/master/pub/v2/2021/4326/20M/nutsrg_3.json"

# EIA Power Plants GeoJSON
EIA_POWERPLANTS="https://services7.arcgis.com/FGr1D95XCGALKXqM/arcgis/rest/services/US_Power_Plants1/FeatureServer/0/query?where=1%3D1&outFields=*&f=geojson"

# HIFLD Electric Transmission Lines
HIFLD_TRANSMISSION="https://opendata.arcgis.com/api/v3/datasets/70512b03fe994c6393107cc9946e5c22_0/downloads/data?format=geojson&spatialRefId=4326"

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

# Ensure a directory exists
ensure_dir() {
    local dir="$1"
    if [[ ! -d "${dir}" ]]; then
        mkdir -p "${dir}"
        log_info "Created directory: ${dir}"
    fi
}

# Download a file with wget, resume support, and existence check
# Arguments: url dest_dir [filename]
download_file() {
    local url="$1"
    local dest_dir="$2"
    local filename="${3:-$(basename "${url}" | sed 's/?.*//')}"
    local dest="${dest_dir}/${filename}"

    ensure_dir "${dest_dir}"

    if [[ -f "${dest}" ]]; then
        local size
        size=$(stat -f%z "${dest}" 2>/dev/null || stat -c%s "${dest}" 2>/dev/null || echo "0")
        if [[ "${size}" -gt 0 ]]; then
            log_info "File already exists (${size} bytes): ${dest}"
            log_info "Use --continue to resume partial downloads. Skipping."
            return 0
        fi
    fi

    log_info "Downloading: ${url}"
    log_info "Destination: ${dest}"

    if ! wget --continue --show-progress --progress=bar:force:noscroll \
         -O "${dest}" "${url}"; then
        log_error "Download failed: ${url}"
        return 1
    fi

    log_info "Download complete: ${dest}"
}

# Print manual download instructions
print_manual_instructions() {
    local source_name="$1"
    local instructions="$2"
    log_warn "=== MANUAL DOWNLOAD REQUIRED: ${source_name} ==="
    echo "${instructions}"
    log_warn "Place downloaded files in: ${RAW_DIR}/${source_name}/"
    echo ""
}

# Check if a command is available
require_cmd() {
    local cmd="$1"
    if ! command -v "${cmd}" &>/dev/null; then
        log_error "Required command not found: ${cmd}"
        log_error "This script should be run inside the converter container."
        return 1
    fi
}

# ---------------------------------------------------------------------------
# Source download functions
# ---------------------------------------------------------------------------

download_basemap() {
    log_info "=== Downloading Protomaps Basemap ==="
    local dest_dir="${RAW_DIR}/basemap"
    ensure_dir "${dest_dir}"

    # Download the planet PMTiles file
    local planet_file="${dest_dir}/planet.pmtiles"

    if [[ -f "${planet_file}" ]]; then
        log_info "Planet file already exists: ${planet_file}"
    else
        log_info "Downloading Protomaps planet basemap (this is ~120 GB and will take a long time)..."
        log_info "Source: ${PROTOMAPS_BASE_URL}"

        # Get the latest daily build URL
        local latest_url
        latest_url=$(wget -qO- "${PROTOMAPS_BASE_URL}" \
            | grep -oP 'href="[^"]*planet[^"]*\.pmtiles"' \
            | tail -1 \
            | sed 's/href="//;s/"//' || true)

        if [[ -z "${latest_url}" ]]; then
            # Fallback: try a direct known path pattern
            log_warn "Could not parse latest build URL. Trying known pattern..."
            latest_url="${PROTOMAPS_BASE_URL}planet.pmtiles"
        else
            # Make relative URL absolute if needed
            if [[ ! "${latest_url}" =~ ^https?:// ]]; then
                latest_url="${PROTOMAPS_BASE_URL}${latest_url}"
            fi
        fi

        download_file "${latest_url}" "${dest_dir}" "planet.pmtiles"
    fi

    # Create regional extracts using pmtiles extract
    if command -v pmtiles &>/dev/null; then
        log_info "Creating regional extracts with pmtiles..."

        if [[ ! -f "${dest_dir}/europe.pmtiles" ]]; then
            log_info "Extracting Europe (bbox: ${BBOX_EUROPE})..."
            pmtiles extract "${planet_file}" "${dest_dir}/europe.pmtiles" \
                --bbox="${BBOX_EUROPE}"
        else
            log_info "Europe extract already exists."
        fi

        if [[ ! -f "${dest_dir}/north-america.pmtiles" ]]; then
            log_info "Extracting North America (bbox: ${BBOX_NORTH_AMERICA})..."
            pmtiles extract "${planet_file}" "${dest_dir}/north-america.pmtiles" \
                --bbox="${BBOX_NORTH_AMERICA}"
        else
            log_info "North America extract already exists."
        fi

        if [[ ! -f "${dest_dir}/australia-nz.pmtiles" ]]; then
            log_info "Extracting Australia/NZ (bbox: ${BBOX_AUSTRALIA_NZ})..."
            pmtiles extract "${planet_file}" "${dest_dir}/australia-nz.pmtiles" \
                --bbox="${BBOX_AUSTRALIA_NZ}"
        else
            log_info "Australia/NZ extract already exists."
        fi
    else
        log_warn "pmtiles CLI not found. Skipping regional extracts."
        log_warn "Run inside the converter container or install pmtiles manually."
    fi

    log_info "=== Basemap download complete ==="
}

download_osm_infrastructure() {
    log_info "=== Downloading Geofabrik OSM PBF Extracts ==="
    local dest_dir="${RAW_DIR}/osm-infrastructure"
    ensure_dir "${dest_dir}"

    download_file "${GEOFABRIK_EUROPE}" "${dest_dir}" "europe-latest.osm.pbf"
    download_file "${GEOFABRIK_NORTH_AMERICA}" "${dest_dir}" "north-america-latest.osm.pbf"
    download_file "${GEOFABRIK_AUSTRALIA}" "${dest_dir}" "australia-oceania-latest.osm.pbf"

    log_info "=== OSM infrastructure download complete ==="
}

download_geonames() {
    log_info "=== Downloading GeoNames cities15000 ==="
    local dest_dir="${RAW_DIR}/geonames"
    ensure_dir "${dest_dir}"

    download_file "${GEONAMES_URL}" "${dest_dir}" "cities15000.zip"

    # Unzip if not already extracted
    if [[ ! -f "${dest_dir}/cities15000.txt" ]]; then
        log_info "Extracting cities15000.zip..."
        unzip -o "${dest_dir}/cities15000.zip" -d "${dest_dir}"
    else
        log_info "cities15000.txt already extracted."
    fi

    log_info "=== GeoNames download complete ==="
}

download_natural_earth() {
    log_info "=== Downloading Natural Earth Datasets ==="
    local dest_dir="${RAW_DIR}/natural-earth"
    ensure_dir "${dest_dir}"

    download_file "${NE_POPULATED_PLACES}" "${dest_dir}" "ne_10m_populated_places_simple.zip"
    download_file "${NE_URBAN_AREAS}" "${dest_dir}" "ne_10m_urban_areas.zip"

    # Unzip each archive
    for zipfile in "${dest_dir}"/*.zip; do
        local base
        base=$(basename "${zipfile}" .zip)
        if [[ ! -d "${dest_dir}/${base}" ]]; then
            log_info "Extracting ${zipfile}..."
            unzip -o "${zipfile}" -d "${dest_dir}/${base}"
        else
            log_info "Already extracted: ${base}"
        fi
    done

    log_info "=== Natural Earth download complete ==="
}

download_census_us() {
    log_info "=== Downloading US Census TIGER/Line 2024 ==="
    local dest_dir="${RAW_DIR}/census-us"
    ensure_dir "${dest_dir}"

    # National state boundaries
    download_file "${TIGER_STATES}" "${dest_dir}" "tl_2024_us_state.zip"

    # National county boundaries
    download_file "${TIGER_COUNTIES}" "${dest_dir}" "tl_2024_us_county.zip"

    # Tracts are per-state; download the national index and then per-state files
    log_info "Downloading TIGER/Line tract shapefiles..."
    log_info "Note: Tracts are distributed per-state FIPS code."

    # State FIPS codes (50 states + DC + territories)
    local fips_codes=(
        01 02 04 05 06 08 09 10 11 12 13 15 16 17 18 19 20 21 22 23
        24 25 26 27 28 29 30 31 32 33 34 35 36 37 38 39 40 41 42 44
        45 46 47 48 49 50 51 53 54 55 56 60 66 69 72 78
    )

    local tracts_dir="${dest_dir}/tracts"
    ensure_dir "${tracts_dir}"

    for fips in "${fips_codes[@]}"; do
        local tract_url="${TIGER_TRACTS}tl_2024_${fips}_tract.zip"
        local tract_file="tl_2024_${fips}_tract.zip"
        if [[ -f "${tracts_dir}/${tract_file}" ]]; then
            continue  # Skip already downloaded
        fi
        # Some territories may not have tract files; allow failure
        download_file "${tract_url}" "${tracts_dir}" "${tract_file}" || \
            log_warn "Could not download tracts for FIPS ${fips} (may not exist)"
    done

    # Unzip all shapefiles
    for zipfile in "${dest_dir}"/*.zip "${tracts_dir}"/*.zip; do
        [[ -f "${zipfile}" ]] || continue
        local base
        base=$(basename "${zipfile}" .zip)
        local parent
        parent=$(dirname "${zipfile}")
        if [[ ! -f "${parent}/${base}.shp" ]]; then
            log_info "Extracting ${zipfile}..."
            unzip -o "${zipfile}" -d "${parent}"
        fi
    done

    log_info "=== US Census download complete ==="
}

download_eurostat() {
    log_info "=== Downloading Eurostat Nuts2json (NUTS3 regions) ==="
    local dest_dir="${RAW_DIR}/eurostat"
    ensure_dir "${dest_dir}"

    download_file "${EUROSTAT_NUTS3}" "${dest_dir}" "nutsrg_3.json"

    log_info "=== Eurostat download complete ==="
}

download_abs_australia() {
    log_info "=== ABS Australian Statistical Boundaries ==="
    local dest_dir="${RAW_DIR}/abs-australia"
    ensure_dir "${dest_dir}"

    print_manual_instructions "abs-australia" \
"The Australian Bureau of Statistics (ABS) requires manual download:

1. Visit: https://www.abs.gov.au/statistics/standards/australian-statistical-geography-standard-asgs-edition-3/jul2021-jun2026/access-and-downloads/digital-boundary-files
2. Download the following shapefiles:
   - Statistical Area Level 2 (SA2) ASGS Ed 3
   - Statistical Area Level 3 (SA3) ASGS Ed 3
   - Statistical Area Level 4 (SA4) ASGS Ed 3
3. Place the downloaded ZIP files in: ${dest_dir}/
4. Re-run this script or proceed to conversion."

    log_info "=== ABS Australia download step complete ==="
}

download_eia_powerplants() {
    log_info "=== Downloading EIA US Power Plants ==="
    local dest_dir="${RAW_DIR}/eia-powerplants"
    ensure_dir "${dest_dir}"

    download_file "${EIA_POWERPLANTS}" "${dest_dir}" "us_power_plants.geojson"

    log_info "=== EIA Power Plants download complete ==="
}

download_hifld_infrastructure() {
    log_info "=== Downloading HIFLD Infrastructure Data ==="
    local dest_dir="${RAW_DIR}/hifld-infrastructure"
    ensure_dir "${dest_dir}"

    # Electric transmission lines (direct GeoJSON download)
    download_file "${HIFLD_TRANSMISSION}" "${dest_dir}" "electric_transmission_lines.geojson"

    # Hospitals, fire stations, schools -- URLs change frequently on HIFLD hub
    print_manual_instructions "hifld-infrastructure (hospitals)" \
"HIFLD Hospitals GeoJSON:
1. Visit: https://hifld-geoplatform.opendata.arcgis.com/datasets/hospitals
2. Click 'Download' -> 'GeoJSON'
3. Save as: ${dest_dir}/hospitals.geojson"

    print_manual_instructions "hifld-infrastructure (fire stations)" \
"HIFLD Fire Stations GeoJSON:
1. Visit: https://hifld-geoplatform.opendata.arcgis.com/datasets/fire-stations
2. Click 'Download' -> 'GeoJSON'
3. Save as: ${dest_dir}/fire_stations.geojson"

    print_manual_instructions "hifld-infrastructure (schools)" \
"HIFLD Public Schools GeoJSON:
1. Visit: https://hifld-geoplatform.opendata.arcgis.com/datasets/public-schools
2. Click 'Download' -> 'GeoJSON'
3. Save as: ${dest_dir}/schools.geojson"

    log_info "=== HIFLD Infrastructure download complete ==="
}

download_epa_water() {
    log_info "=== EPA Community Water System Boundaries ==="
    local dest_dir="${RAW_DIR}/epa-water"
    ensure_dir "${dest_dir}"

    print_manual_instructions "epa-water" \
"EPA Community Water System boundaries require manual download:

1. Visit: https://www.epa.gov/ground-water-and-drinking-water/community-water-system-service-area-boundaries
   OR: https://geopub.epa.gov/EDWGeoServiceSearch/
2. Search for 'Community Water System Service Area Boundaries'
3. Download the GeoJSON or Shapefile version
4. Place downloaded files in: ${dest_dir}/
5. Re-run this script or proceed to conversion."

    log_info "=== EPA Water download step complete ==="
}

download_nid_dams() {
    log_info "=== NID (National Inventory of Dams) ==="
    local dest_dir="${RAW_DIR}/nid-dams"
    ensure_dir "${dest_dir}"

    print_manual_instructions "nid-dams" \
"NID dam data requires manual download from the USACE portal:

1. Visit: https://nid.sec.usace.army.mil/#/
2. Click 'Download Data' or use the query interface
3. Select 'Export as GeoJSON' for the full national dataset
4. Save as: ${dest_dir}/nid_dams.geojson
5. Re-run this script or proceed to conversion.

Alternative: Use the NID API (requires registration):
  curl 'https://nid.sec.usace.army.mil/api/nation/geojson' -o ${dest_dir}/nid_dams.geojson"

    log_info "=== NID Dams download step complete ==="
}

download_eea_water() {
    log_info "=== EEA WISE Water Data ==="
    local dest_dir="${RAW_DIR}/eea-water"
    ensure_dir "${dest_dir}"

    print_manual_instructions "eea-water" \
"EEA WISE (Water Information System for Europe) data requires manual download:

1. Visit: https://www.eea.europa.eu/en/datahub/datahubitem-view/c2c99dcc-ebe2-4dd7-9248-0219a82f6eb3
2. Select the datasets you need:
   - WISE Large Rivers (river basins)
   - WISE Water Bodies (lakes, coastal waters)
   - WISE Monitoring Stations
3. Download as GeoPackage or GeoJSON
4. Place downloaded files in: ${dest_dir}/
5. Re-run this script or proceed to conversion."

    log_info "=== EEA Water download step complete ==="
}

# ---------------------------------------------------------------------------
# Option mappings
# ---------------------------------------------------------------------------

# Map option letter to array of source names
get_sources_for_option() {
    local option="$1"
    case "${option}" in
        a|A)
            echo "basemap osm-infrastructure natural-earth"
            ;;
        b|B)
            echo "census-us hifld-infrastructure eia-powerplants nid-dams epa-water"
            ;;
        c|C)
            echo "basemap osm-infrastructure census-us hifld-infrastructure"
            ;;
        d|D)
            echo "hifld-infrastructure census-us"
            ;;
        e|E)
            echo "basemap osm-infrastructure geonames eurostat census-us abs-australia"
            ;;
        *)
            log_error "Unknown option: ${option}. Valid options: a, b, c, d, e"
            return 1
            ;;
    esac
}

# Dispatch download for a single source name
download_source() {
    local source="$1"
    case "${source}" in
        basemap)              download_basemap ;;
        osm-infrastructure)   download_osm_infrastructure ;;
        geonames)             download_geonames ;;
        natural-earth)        download_natural_earth ;;
        census-us)            download_census_us ;;
        eurostat)             download_eurostat ;;
        abs-australia)        download_abs_australia ;;
        eia-powerplants)      download_eia_powerplants ;;
        hifld-infrastructure) download_hifld_infrastructure ;;
        epa-water)            download_epa_water ;;
        nid-dams)             download_nid_dams ;;
        eea-water)            download_eea_water ;;
        *)
            log_error "Unknown source: ${source}"
            log_error "Valid sources: basemap, osm-infrastructure, geonames, natural-earth,"
            log_error "  census-us, eurostat, abs-australia, eia-powerplants,"
            log_error "  hifld-infrastructure, epa-water, nid-dams, eea-water"
            return 1
            ;;
    esac
}

# ---------------------------------------------------------------------------
# Usage / help
# ---------------------------------------------------------------------------

usage() {
    cat <<'USAGE'
Usage: download.sh [OPTIONS]

Download geospatial data sources for the OXOT Tileserver.

OPTIONS:
  --source NAME     Download a specific source (can be repeated)
  --option LETTER   Download all sources for an option (A through E)
  --help            Show this help message

SOURCES:
  basemap              Protomaps basemap (planet PMTiles + regional extracts)
  osm-infrastructure   Geofabrik OSM PBF extracts (Europe, N. America, AU/NZ)
  geonames             GeoNames cities15000 (global cities with population)
  natural-earth        Natural Earth populated places + urban areas
  census-us            US Census TIGER/Line 2024 (states, counties, tracts)
  eurostat             Eurostat Nuts2json NUTS3 regions (Europe)
  abs-australia        ABS statistical area boundaries (manual download)
  eia-powerplants      EIA US Power Plants GeoJSON
  hifld-infrastructure HIFLD infrastructure datasets (transmission, hospitals, etc.)
  epa-water            EPA community water system boundaries (manual download)
  nid-dams             National Inventory of Dams (manual download)
  eea-water            EEA WISE water data (manual download)

OPTIONS (A-E):
  A  basemap, osm-infrastructure, natural-earth
  B  census-us, hifld-infrastructure, eia-powerplants, nid-dams, epa-water
  C  basemap, osm-infrastructure, census-us, hifld-infrastructure
  D  hifld-infrastructure, census-us
  E  basemap, osm-infrastructure, geonames, eurostat, census-us, abs-australia

EXAMPLES:
  ./scripts/download.sh --source basemap
  ./scripts/download.sh --source geonames --source natural-earth
  ./scripts/download.sh --option e
USAGE
}

# ---------------------------------------------------------------------------
# Main entry point
# ---------------------------------------------------------------------------

main() {
    local sources=()
    local option=""

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

    # Validate: must have at least --source or --option
    if [[ ${#sources[@]} -eq 0 && -z "${option}" ]]; then
        log_error "No source or option specified."
        usage
        exit 1
    fi

    # If option specified, expand to source list
    if [[ -n "${option}" ]]; then
        local option_sources
        option_sources=$(get_sources_for_option "${option}")
        # shellcheck disable=SC2206
        sources+=(${option_sources})
    fi

    # Remove duplicates while preserving order
    local unique_sources=()
    local seen=""
    for src in "${sources[@]}"; do
        if [[ ! " ${seen} " =~ " ${src} " ]]; then
            unique_sources+=("${src}")
            seen="${seen} ${src}"
        fi
    done

    log_info "========================================"
    log_info "OXOT Tileserver Data Download"
    log_info "Sources: ${unique_sources[*]}"
    log_info "Data directory: ${RAW_DIR}"
    log_info "========================================"

    # Ensure base data directories exist
    ensure_dir "${RAW_DIR}"

    # Download each source
    local failed=0
    for src in "${unique_sources[@]}"; do
        log_info "----------------------------------------"
        if ! download_source "${src}"; then
            log_error "Failed to download source: ${src}"
            failed=$((failed + 1))
        fi
    done

    log_info "========================================"
    if [[ ${failed} -gt 0 ]]; then
        log_warn "Download completed with ${failed} failure(s)."
        exit 1
    else
        log_info "All downloads completed successfully."
    fi
}

main "$@"
