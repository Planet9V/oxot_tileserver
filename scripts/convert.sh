#!/usr/bin/env bash
# =============================================================================
# convert.sh - Universal conversion script for OXOT Tileserver
# =============================================================================
# Converts raw data sources to mbtiles/pmtiles in data/tiles/.
#
# Usage:
#   ./scripts/convert.sh --source osm-infrastructure
#   ./scripts/convert.sh --option e
#   ./scripts/convert.sh --source geonames --source eurostat
#
# Prerequisites:
#   - tippecanoe, ogr2ogr, osmium, pmtiles (all in converter container)
#   - Raw data already downloaded via download.sh
# =============================================================================
set -euo pipefail

# ---------------------------------------------------------------------------
# Configuration
# ---------------------------------------------------------------------------
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "${SCRIPT_DIR}/.." && pwd)"
RAW_DIR="${PROJECT_ROOT}/data/raw"
TILES_DIR="${PROJECT_ROOT}/data/tiles"

# Temporary working directory for intermediate files
WORK_DIR="${PROJECT_ROOT}/data/work"

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

ensure_dir() {
    local dir="$1"
    if [[ ! -d "${dir}" ]]; then
        mkdir -p "${dir}"
    fi
}

# Check that a required command is available
require_cmd() {
    local cmd="$1"
    if ! command -v "${cmd}" &>/dev/null; then
        log_error "Required command not found: ${cmd}"
        log_error "Run this script inside the converter container."
        return 1
    fi
}

# Check all toolchain prerequisites
check_prerequisites() {
    local missing=0
    for cmd in tippecanoe ogr2ogr; do
        if ! command -v "${cmd}" &>/dev/null; then
            log_error "Missing: ${cmd}"
            missing=$((missing + 1))
        fi
    done
    if [[ ${missing} -gt 0 ]]; then
        log_error "${missing} required tool(s) missing. Run inside the converter container."
        exit 1
    fi
    log_info "Prerequisites satisfied."
}

# Remove intermediate work files for a source
cleanup_work() {
    local source_name="$1"
    local work_subdir="${WORK_DIR}/${source_name}"
    if [[ -d "${work_subdir}" ]]; then
        log_info "Cleaning up work directory: ${work_subdir}"
        rm -rf "${work_subdir}"
    fi
}

# ---------------------------------------------------------------------------
# Conversion functions
# ---------------------------------------------------------------------------

convert_basemap() {
    log_info "=== Converting Basemap (PMTiles) ==="
    local src_dir="${RAW_DIR}/basemap"

    if [[ ! -d "${src_dir}" ]]; then
        log_error "Basemap raw data not found: ${src_dir}"
        return 1
    fi

    # PMTiles files are already tile-ready -- copy regional extracts to tiles/
    local copied=0
    for pmtiles_file in "${src_dir}"/*.pmtiles; do
        [[ -f "${pmtiles_file}" ]] || continue
        local basename
        basename=$(basename "${pmtiles_file}")

        # Skip the full planet file; only copy regional extracts
        if [[ "${basename}" == "planet.pmtiles" ]]; then
            log_info "Skipping planet.pmtiles (use regional extracts instead)."
            continue
        fi

        local dest="${TILES_DIR}/${basename}"
        if [[ -f "${dest}" ]]; then
            log_info "Already exists: ${dest}"
        else
            log_info "Copying ${basename} to tiles directory..."
            cp "${pmtiles_file}" "${dest}"
        fi
        copied=$((copied + 1))
    done

    if [[ ${copied} -eq 0 ]]; then
        log_warn "No PMTiles regional extracts found."
        log_warn "If you have the planet file, run download.sh with pmtiles CLI to create extracts."
    fi

    log_info "=== Basemap conversion complete ==="
}

convert_osm_infrastructure() {
    log_info "=== Converting OSM Infrastructure ==="
    local src_dir="${RAW_DIR}/osm-infrastructure"
    local output="${TILES_DIR}/osm-infrastructure.mbtiles"

    if [[ -f "${output}" ]]; then
        log_info "Output already exists: ${output}"
        return 0
    fi

    # Step 1: Run the OSM extraction pipeline if merged files do not exist
    local merged_lines="${src_dir}/all-regions-infra-lines.geojsonseq"
    local merged_points="${src_dir}/all-regions-infra-points.geojsonseq"
    local merged_polys="${src_dir}/all-regions-infra-multipolygons.geojsonseq"

    if [[ ! -s "${merged_lines}" && ! -s "${merged_points}" && ! -s "${merged_polys}" ]]; then
        log_info "Merged GeoJSONSeq files not found. Running extract-osm.sh..."
        if ! bash "${SCRIPT_DIR}/extract-osm.sh"; then
            log_error "extract-osm.sh failed."
            return 1
        fi
    fi

    require_cmd tippecanoe

    # Step 2: Build tippecanoe inputs
    # We pass different zoom ranges for lines vs points
    local tc_args=()

    if [[ -s "${merged_lines}" ]]; then
        # Lines layer: power lines, pipelines (Z4-Z14)
        tc_args+=("-L" "power_lines:${merged_lines}")
    fi

    if [[ -s "${merged_points}" ]]; then
        # Points layer: substations, generators, masts (Z8-Z14)
        tc_args+=("-L" "substations:${merged_points}")
    fi

    if [[ -s "${merged_polys}" ]]; then
        # Polygon layer: water treatment plants, large substations
        tc_args+=("-L" "water_treatment:${merged_polys}")
    fi

    if [[ ${#tc_args[@]} -eq 0 ]]; then
        log_error "No GeoJSONSeq data found for OSM infrastructure."
        return 1
    fi

    log_info "Running tippecanoe to create ${output}..."
    tippecanoe \
        -o "${output}" \
        -Z4 -z14 \
        --drop-densest-as-needed \
        --extend-zooms-if-still-dropping \
        --force \
        "${tc_args[@]}"

    log_info "=== OSM Infrastructure conversion complete: ${output} ==="
}

convert_geonames() {
    log_info "=== Converting GeoNames cities15000 ==="
    local src_dir="${RAW_DIR}/geonames"
    local tsv_file="${src_dir}/cities15000.txt"
    local output="${TILES_DIR}/geonames-cities.mbtiles"

    if [[ -f "${output}" ]]; then
        log_info "Output already exists: ${output}"
        return 0
    fi

    if [[ ! -f "${tsv_file}" ]]; then
        log_error "GeoNames TSV not found: ${tsv_file}"
        return 1
    fi

    require_cmd tippecanoe

    local work_subdir="${WORK_DIR}/geonames"
    ensure_dir "${work_subdir}"
    local geojson_file="${work_subdir}/cities15000.geojson"

    # Convert TSV to GeoJSON using Python (available in converter container)
    # GeoNames TSV columns (tab-separated, no header):
    #  0: geonameid, 1: name, 2: asciiname, 3: alternatenames,
    #  4: latitude, 5: longitude, 6: feature_class, 7: feature_code,
    #  8: country_code, 9: cc2, 10: admin1, 11: admin2, 12: admin3, 13: admin4,
    #  14: population, 15: elevation, 16: dem, 17: timezone, 18: modification_date
    log_info "Converting GeoNames TSV to GeoJSON..."

    python3 -c "
import json, sys

features = []
with open('${tsv_file}', 'r', encoding='utf-8') as f:
    for line in f:
        parts = line.strip().split('\t')
        if len(parts) < 19:
            continue
        try:
            lat = float(parts[4])
            lon = float(parts[5])
            pop = int(parts[14]) if parts[14] else 0
            elev = int(parts[15]) if parts[15] and parts[15] != '' else 0
        except (ValueError, IndexError):
            continue
        feature = {
            'type': 'Feature',
            'geometry': {
                'type': 'Point',
                'coordinates': [lon, lat]
            },
            'properties': {
                'geonameid': parts[0],
                'name': parts[1],
                'country': parts[8],
                'population': pop,
                'elevation': elev,
                'timezone': parts[17]
            }
        }
        features.append(feature)

geojson = {
    'type': 'FeatureCollection',
    'features': features
}

with open('${geojson_file}', 'w') as out:
    json.dump(geojson, out)

print(f'Converted {len(features)} cities to GeoJSON')
"

    log_info "Running tippecanoe..."
    tippecanoe \
        -o "${output}" \
        -Z2 -z12 \
        -l cities \
        --drop-densest-as-needed \
        --force \
        "${geojson_file}"

    cleanup_work "geonames"
    log_info "=== GeoNames conversion complete: ${output} ==="
}

convert_natural_earth() {
    log_info "=== Converting Natural Earth ==="
    local src_dir="${RAW_DIR}/natural-earth"
    local output="${TILES_DIR}/natural-earth-places.mbtiles"

    if [[ -f "${output}" ]]; then
        log_info "Output already exists: ${output}"
        return 0
    fi

    require_cmd tippecanoe
    require_cmd ogr2ogr

    local work_subdir="${WORK_DIR}/natural-earth"
    ensure_dir "${work_subdir}"

    local geojson_files=()

    # Convert populated places shapefile to GeoJSON
    local places_shp
    places_shp=$(find "${src_dir}" -name "ne_10m_populated_places_simple.shp" 2>/dev/null | head -1)
    if [[ -n "${places_shp}" ]]; then
        local places_geojson="${work_subdir}/populated_places.geojson"
        log_info "Converting populated places shapefile to GeoJSON..."
        ogr2ogr -f "GeoJSON" "${places_geojson}" "${places_shp}"
        geojson_files+=("-L" "populated_places:${places_geojson}")
    else
        log_warn "Populated places shapefile not found."
    fi

    # Convert urban areas shapefile to GeoJSON
    local urban_shp
    urban_shp=$(find "${src_dir}" -name "ne_10m_urban_areas.shp" 2>/dev/null | head -1)
    if [[ -n "${urban_shp}" ]]; then
        local urban_geojson="${work_subdir}/urban_areas.geojson"
        log_info "Converting urban areas shapefile to GeoJSON..."
        ogr2ogr -f "GeoJSON" "${urban_geojson}" "${urban_shp}"
        geojson_files+=("-L" "urban_areas:${urban_geojson}")
    else
        log_warn "Urban areas shapefile not found."
    fi

    if [[ ${#geojson_files[@]} -eq 0 ]]; then
        log_error "No Natural Earth shapefiles found for conversion."
        return 1
    fi

    log_info "Running tippecanoe..."
    tippecanoe \
        -o "${output}" \
        -Z0 -z10 \
        --drop-densest-as-needed \
        --force \
        "${geojson_files[@]}"

    cleanup_work "natural-earth"
    log_info "=== Natural Earth conversion complete: ${output} ==="
}

convert_census_us() {
    log_info "=== Converting US Census TIGER/Line ==="
    local src_dir="${RAW_DIR}/census-us"
    local output="${TILES_DIR}/demographics-us.mbtiles"

    if [[ -f "${output}" ]]; then
        log_info "Output already exists: ${output}"
        return 0
    fi

    require_cmd tippecanoe
    require_cmd ogr2ogr

    local work_subdir="${WORK_DIR}/census-us"
    ensure_dir "${work_subdir}"

    local tc_inputs=()

    # Convert state boundaries
    local state_shp="${src_dir}/tl_2024_us_state.shp"
    if [[ -f "${state_shp}" ]]; then
        local state_geojson="${work_subdir}/states.geojson"
        log_info "Converting state boundaries..."
        ogr2ogr -f "GeoJSON" "${state_geojson}" "${state_shp}"
        tc_inputs+=("-L" "states:${state_geojson}")
    else
        log_warn "State shapefile not found."
    fi

    # Convert county boundaries
    local county_shp="${src_dir}/tl_2024_us_county.shp"
    if [[ -f "${county_shp}" ]]; then
        local county_geojson="${work_subdir}/counties.geojson"
        log_info "Converting county boundaries..."
        ogr2ogr -f "GeoJSON" "${county_geojson}" "${county_shp}"
        tc_inputs+=("-L" "counties:${county_geojson}")
    else
        log_warn "County shapefile not found."
    fi

    # Convert tract boundaries (per-state files)
    local tracts_dir="${src_dir}/tracts"
    if [[ -d "${tracts_dir}" ]]; then
        local merged_tracts="${work_subdir}/tracts_merged.geojson"
        local first=1

        log_info "Converting and merging tract shapefiles..."
        for tract_shp in "${tracts_dir}"/tl_2024_*_tract.shp; do
            [[ -f "${tract_shp}" ]] || continue
            local tract_geojson="${work_subdir}/$(basename "${tract_shp}" .shp).geojson"
            ogr2ogr -f "GeoJSON" "${tract_geojson}" "${tract_shp}"

            if [[ ${first} -eq 1 ]]; then
                cp "${tract_geojson}" "${merged_tracts}"
                first=0
            else
                # Merge using ogr2ogr append
                ogr2ogr -f "GeoJSON" -append -update \
                    "${merged_tracts}" "${tract_geojson}"
            fi
            # Clean up individual tract GeoJSON to save disk
            rm -f "${tract_geojson}"
        done

        if [[ -f "${merged_tracts}" ]]; then
            tc_inputs+=("-L" "tracts:${merged_tracts}")
        fi
    else
        log_warn "Tracts directory not found."
    fi

    if [[ ${#tc_inputs[@]} -eq 0 ]]; then
        log_error "No Census shapefiles found for conversion."
        return 1
    fi

    log_info "Running tippecanoe..."
    tippecanoe \
        -o "${output}" \
        -Z4 -z14 \
        --drop-densest-as-needed \
        --extend-zooms-if-still-dropping \
        --coalesce-densest-as-needed \
        --force \
        "${tc_inputs[@]}"

    cleanup_work "census-us"
    log_info "=== US Census conversion complete: ${output} ==="
}

convert_eurostat() {
    log_info "=== Converting Eurostat Nuts2json ==="
    local src_dir="${RAW_DIR}/eurostat"
    local input="${src_dir}/nutsrg_3.json"
    local output="${TILES_DIR}/demographics-europe.mbtiles"

    if [[ -f "${output}" ]]; then
        log_info "Output already exists: ${output}"
        return 0
    fi

    if [[ ! -f "${input}" ]]; then
        log_error "Eurostat GeoJSON not found: ${input}"
        return 1
    fi

    require_cmd tippecanoe

    log_info "Running tippecanoe..."
    tippecanoe \
        -o "${output}" \
        -Z2 -z12 \
        -l nuts3_regions \
        --drop-densest-as-needed \
        --force \
        "${input}"

    log_info "=== Eurostat conversion complete: ${output} ==="
}

convert_abs_australia() {
    log_info "=== Converting ABS Australia Boundaries ==="
    local src_dir="${RAW_DIR}/abs-australia"
    local output="${TILES_DIR}/demographics-australia.mbtiles"

    if [[ -f "${output}" ]]; then
        log_info "Output already exists: ${output}"
        return 0
    fi

    require_cmd tippecanoe
    require_cmd ogr2ogr

    # Look for shapefile or geopackage files
    local found_input=0
    local work_subdir="${WORK_DIR}/abs-australia"
    ensure_dir "${work_subdir}"

    local tc_inputs=()

    # Try to find and convert any shapefiles or GeoPackages
    for shp_file in "${src_dir}"/*.shp "${src_dir}"/**/*.shp; do
        [[ -f "${shp_file}" ]] || continue
        found_input=1
        local base
        base=$(basename "${shp_file}" .shp)
        local geojson="${work_subdir}/${base}.geojson"
        log_info "Converting ${base}..."
        ogr2ogr -f "GeoJSON" "${geojson}" "${shp_file}"
        tc_inputs+=("-L" "${base}:${geojson}")
    done

    for gpkg_file in "${src_dir}"/*.gpkg; do
        [[ -f "${gpkg_file}" ]] || continue
        found_input=1
        local base
        base=$(basename "${gpkg_file}" .gpkg)
        local geojson="${work_subdir}/${base}.geojson"
        log_info "Converting ${base}..."
        ogr2ogr -f "GeoJSON" "${geojson}" "${gpkg_file}"
        tc_inputs+=("-L" "${base}:${geojson}")
    done

    if [[ ${found_input} -eq 0 ]]; then
        log_warn "No ABS data files found in: ${src_dir}"
        log_warn "Download ABS boundaries manually and place in: ${src_dir}/"
        return 1
    fi

    log_info "Running tippecanoe..."
    tippecanoe \
        -o "${output}" \
        -Z4 -z14 \
        --drop-densest-as-needed \
        --force \
        "${tc_inputs[@]}"

    cleanup_work "abs-australia"
    log_info "=== ABS Australia conversion complete: ${output} ==="
}

convert_eia_powerplants() {
    log_info "=== Converting EIA Power Plants ==="
    local src_dir="${RAW_DIR}/eia-powerplants"
    local input="${src_dir}/us_power_plants.geojson"
    local output="${TILES_DIR}/eia-powerplants.mbtiles"

    if [[ -f "${output}" ]]; then
        log_info "Output already exists: ${output}"
        return 0
    fi

    if [[ ! -f "${input}" ]]; then
        log_error "EIA Power Plants GeoJSON not found: ${input}"
        return 1
    fi

    require_cmd tippecanoe

    log_info "Running tippecanoe..."
    tippecanoe \
        -o "${output}" \
        -Z4 -z14 \
        -l power_plants \
        --drop-densest-as-needed \
        --force \
        "${input}"

    log_info "=== EIA Power Plants conversion complete: ${output} ==="
}

convert_hifld_infrastructure() {
    log_info "=== Converting HIFLD Infrastructure ==="
    local src_dir="${RAW_DIR}/hifld-infrastructure"
    local output="${TILES_DIR}/hifld-infrastructure.mbtiles"

    if [[ -f "${output}" ]]; then
        log_info "Output already exists: ${output}"
        return 0
    fi

    require_cmd tippecanoe

    local tc_inputs=()

    # Electric transmission lines
    local transmission="${src_dir}/electric_transmission_lines.geojson"
    if [[ -f "${transmission}" ]]; then
        tc_inputs+=("-L" "transmission_lines:${transmission}")
    else
        log_warn "Transmission lines GeoJSON not found."
    fi

    # Hospitals
    local hospitals="${src_dir}/hospitals.geojson"
    if [[ -f "${hospitals}" ]]; then
        tc_inputs+=("-L" "hospitals:${hospitals}")
    else
        log_warn "Hospitals GeoJSON not found. Download manually from HIFLD."
    fi

    # Fire stations
    local fire_stations="${src_dir}/fire_stations.geojson"
    if [[ -f "${fire_stations}" ]]; then
        tc_inputs+=("-L" "fire_stations:${fire_stations}")
    else
        log_warn "Fire stations GeoJSON not found. Download manually from HIFLD."
    fi

    # Schools
    local schools="${src_dir}/schools.geojson"
    if [[ -f "${schools}" ]]; then
        tc_inputs+=("-L" "schools:${schools}")
    else
        log_warn "Schools GeoJSON not found. Download manually from HIFLD."
    fi

    if [[ ${#tc_inputs[@]} -eq 0 ]]; then
        log_error "No HIFLD data files found for conversion."
        return 1
    fi

    log_info "Running tippecanoe with ${#tc_inputs[@]} layer arguments..."
    tippecanoe \
        -o "${output}" \
        -Z4 -z14 \
        --drop-densest-as-needed \
        --extend-zooms-if-still-dropping \
        --force \
        "${tc_inputs[@]}"

    log_info "=== HIFLD Infrastructure conversion complete: ${output} ==="
}

convert_nid_dams() {
    log_info "=== Converting NID Dams ==="
    local src_dir="${RAW_DIR}/nid-dams"
    local input="${src_dir}/nid_dams.geojson"
    local output="${TILES_DIR}/nid-dams.mbtiles"

    if [[ -f "${output}" ]]; then
        log_info "Output already exists: ${output}"
        return 0
    fi

    if [[ ! -f "${input}" ]]; then
        log_error "NID dams GeoJSON not found: ${input}"
        log_error "Download manually from https://nid.sec.usace.army.mil/"
        return 1
    fi

    require_cmd tippecanoe

    log_info "Running tippecanoe..."
    tippecanoe \
        -o "${output}" \
        -Z4 -z14 \
        -l dams \
        --drop-densest-as-needed \
        --force \
        "${input}"

    log_info "=== NID Dams conversion complete: ${output} ==="
}

convert_epa_water() {
    log_info "=== Converting EPA Water ==="
    local src_dir="${RAW_DIR}/epa-water"
    local output="${TILES_DIR}/epa-water.mbtiles"

    if [[ -f "${output}" ]]; then
        log_info "Output already exists: ${output}"
        return 0
    fi

    require_cmd tippecanoe
    require_cmd ogr2ogr

    # Look for whatever format the user downloaded (GeoJSON, shapefile, geodatabase)
    local work_subdir="${WORK_DIR}/epa-water"
    ensure_dir "${work_subdir}"
    local geojson_input=""

    # Check for GeoJSON first
    for f in "${src_dir}"/*.geojson "${src_dir}"/*.json; do
        if [[ -f "${f}" ]]; then
            geojson_input="${f}"
            break
        fi
    done

    # Try shapefile
    if [[ -z "${geojson_input}" ]]; then
        for shp in "${src_dir}"/*.shp; do
            if [[ -f "${shp}" ]]; then
                geojson_input="${work_subdir}/epa_water.geojson"
                log_info "Converting shapefile to GeoJSON..."
                ogr2ogr -f "GeoJSON" "${geojson_input}" "${shp}"
                break
            fi
        done
    fi

    # Try geodatabase
    if [[ -z "${geojson_input}" ]]; then
        for gdb in "${src_dir}"/*.gdb; do
            if [[ -d "${gdb}" ]]; then
                geojson_input="${work_subdir}/epa_water.geojson"
                log_info "Converting geodatabase to GeoJSON..."
                ogr2ogr -f "GeoJSON" "${geojson_input}" "${gdb}"
                break
            fi
        done
    fi

    if [[ -z "${geojson_input}" || ! -f "${geojson_input}" ]]; then
        log_error "No EPA water data files found in: ${src_dir}"
        log_error "Download manually from EPA GeoPlatform."
        return 1
    fi

    log_info "Running tippecanoe..."
    tippecanoe \
        -o "${output}" \
        -Z4 -z14 \
        -l water_systems \
        --drop-densest-as-needed \
        --force \
        "${geojson_input}"

    cleanup_work "epa-water"
    log_info "=== EPA Water conversion complete: ${output} ==="
}

# ---------------------------------------------------------------------------
# Option mappings (same as download.sh)
# ---------------------------------------------------------------------------

get_sources_for_option() {
    local option="$1"
    case "${option}" in
        a|A) echo "basemap osm-infrastructure natural-earth" ;;
        b|B) echo "census-us hifld-infrastructure eia-powerplants nid-dams epa-water" ;;
        c|C) echo "basemap osm-infrastructure census-us hifld-infrastructure" ;;
        d|D) echo "hifld-infrastructure census-us" ;;
        e|E) echo "basemap osm-infrastructure geonames eurostat census-us abs-australia" ;;
        *)
            log_error "Unknown option: ${option}. Valid options: a, b, c, d, e"
            return 1
            ;;
    esac
}

# Dispatch conversion for a single source
convert_source() {
    local source="$1"
    case "${source}" in
        basemap)              convert_basemap ;;
        osm-infrastructure)   convert_osm_infrastructure ;;
        geonames)             convert_geonames ;;
        natural-earth)        convert_natural_earth ;;
        census-us)            convert_census_us ;;
        eurostat)             convert_eurostat ;;
        abs-australia)        convert_abs_australia ;;
        eia-powerplants)      convert_eia_powerplants ;;
        hifld-infrastructure) convert_hifld_infrastructure ;;
        epa-water)            convert_epa_water ;;
        nid-dams)             convert_nid_dams ;;
        *)
            log_error "Unknown source: ${source}"
            log_error "Valid sources: basemap, osm-infrastructure, geonames, natural-earth,"
            log_error "  census-us, eurostat, abs-australia, eia-powerplants,"
            log_error "  hifld-infrastructure, epa-water, nid-dams"
            return 1
            ;;
    esac
}

# ---------------------------------------------------------------------------
# Usage
# ---------------------------------------------------------------------------

usage() {
    cat <<'USAGE'
Usage: convert.sh [OPTIONS]

Convert raw geospatial data to vector tiles (mbtiles/pmtiles).

OPTIONS:
  --source NAME     Convert a specific source (can be repeated)
  --option LETTER   Convert all sources for an option (A through E)
  --force           Overwrite existing output files
  --help            Show this help message

SOURCES:
  basemap              Copy PMTiles regional extracts to tiles/
  osm-infrastructure   Filter OSM PBF + tippecanoe -> osm-infrastructure.mbtiles
  geonames             TSV -> GeoJSON -> tippecanoe -> geonames-cities.mbtiles
  natural-earth        Shapefile -> GeoJSON -> tippecanoe -> natural-earth-places.mbtiles
  census-us            Shapefile -> GeoJSON -> tippecanoe -> demographics-us.mbtiles
  eurostat             GeoJSON -> tippecanoe -> demographics-europe.mbtiles
  abs-australia        Shapefile -> GeoJSON -> tippecanoe -> demographics-australia.mbtiles
  eia-powerplants      GeoJSON -> tippecanoe -> eia-powerplants.mbtiles
  hifld-infrastructure GeoJSON -> tippecanoe -> hifld-infrastructure.mbtiles
  nid-dams             GeoJSON -> tippecanoe -> nid-dams.mbtiles

OPTIONS (A-E):
  A  basemap, osm-infrastructure, natural-earth
  B  census-us, hifld-infrastructure, eia-powerplants, nid-dams, epa-water
  C  basemap, osm-infrastructure, census-us, hifld-infrastructure
  D  hifld-infrastructure, census-us
  E  basemap, osm-infrastructure, geonames, eurostat, census-us, abs-australia

EXAMPLES:
  ./scripts/convert.sh --source osm-infrastructure
  ./scripts/convert.sh --option e
  ./scripts/convert.sh --source geonames --source eurostat
USAGE
}

# ---------------------------------------------------------------------------
# Main entry point
# ---------------------------------------------------------------------------

main() {
    local sources=()
    local option=""
    local force=0

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
            --force)
                force=1
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

    # Expand option to source list
    if [[ -n "${option}" ]]; then
        local option_sources
        option_sources=$(get_sources_for_option "${option}")
        # shellcheck disable=SC2206
        sources+=(${option_sources})
    fi

    # Deduplicate
    local unique_sources=()
    local seen=""
    for src in "${sources[@]}"; do
        if [[ ! " ${seen} " =~ " ${src} " ]]; then
            unique_sources+=("${src}")
            seen="${seen} ${src}"
        fi
    done

    log_info "========================================"
    log_info "OXOT Tileserver Data Conversion"
    log_info "Sources: ${unique_sources[*]}"
    log_info "Output directory: ${TILES_DIR}"
    log_info "========================================"

    check_prerequisites
    ensure_dir "${TILES_DIR}"
    ensure_dir "${WORK_DIR}"

    # If force mode, remove existing outputs
    if [[ ${force} -eq 1 ]]; then
        log_info "Force mode enabled: will overwrite existing outputs."
    fi

    # Convert each source
    local failed=0
    for src in "${unique_sources[@]}"; do
        log_info "----------------------------------------"
        if ! convert_source "${src}"; then
            log_error "Failed to convert source: ${src}"
            failed=$((failed + 1))
        fi
    done

    # Clean up work directory if empty
    if [[ -d "${WORK_DIR}" ]]; then
        rmdir "${WORK_DIR}" 2>/dev/null || true
    fi

    log_info "========================================"
    if [[ ${failed} -gt 0 ]]; then
        log_warn "Conversion completed with ${failed} failure(s)."
        exit 1
    else
        log_info "All conversions completed successfully."
        log_info "Tile files in: ${TILES_DIR}/"
        ls -lh "${TILES_DIR}"/ 2>/dev/null || true
    fi
}

main "$@"
