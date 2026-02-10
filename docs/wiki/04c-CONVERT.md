# Conversion and Tippecanoe

> **Last Updated**: 2026-02-11 01:00 UTC

[Home](INDEX.md) · [Pipeline](04-PIPELINE.md) · Conversion and Tippecanoe

---

## Overview

The `scripts/convert.sh` script is the third stage of the pipeline. It transforms raw or extracted data into MBTiles vector tiles using `tippecanoe`, with intermediate format conversion via `ogr2ogr` where needed. Each source has its own conversion function with tuned parameters for zoom levels, density management, and layer naming.

---

## Usage

```bash
# Convert a single source
./scripts/convert.sh --source osm-infrastructure

# Convert multiple sources
./scripts/convert.sh --source geonames --source eurostat

# Convert all sources for an option
./scripts/convert.sh --option e

# Force overwrite existing tile files
./scripts/convert.sh --source census-us --force

# Show help
./scripts/convert.sh --help
```

The `--force` flag deletes existing output files before conversion. Without it, the script skips sources whose output file already exists in `data/tiles/`.

---

## Conversion Pipeline by Source

Each source follows one of these conversion paths.

### Path 1: GeoJSON to tippecanoe (direct)

Sources that are already in GeoJSON format:

```
GeoJSON --> tippecanoe --> .mbtiles
```

Used by: `eia-powerplants`, `hifld-infrastructure`, `nid-dams`, `eurostat`

### Path 2: Shapefile to GeoJSON to tippecanoe

Sources in Shapefile format need `ogr2ogr` conversion first:

```
.shp --> ogr2ogr --> GeoJSON --> tippecanoe --> .mbtiles
```

Used by: `census-us`, `natural-earth`, `abs-australia`

### Path 3: GeoJSONSeq to tippecanoe

OSM data extracted by `extract-osm.sh`:

```
GeoJSONSeq --> tippecanoe --> .mbtiles
```

Used by: `osm-infrastructure`

### Path 4: TSV to GeoJSON to tippecanoe

GeoNames cities need Python-based format conversion:

```
.tsv --> python3 --> GeoJSON --> tippecanoe --> .mbtiles
```

Used by: `geonames`

### Path 5: PMTiles copy (no conversion)

Protomaps basemap files are already tiled:

```
.pmtiles --> cp --> data/tiles/
```

Used by: `basemap`

---

## Per-Source Tippecanoe Options

### OSM Infrastructure

**Output**: `data/tiles/osm-infrastructure.mbtiles`

```bash
tippecanoe \
    -o osm-infrastructure.mbtiles \
    -Z4 -z14 \
    --drop-densest-as-needed \
    --extend-zooms-if-still-dropping \
    --force \
    -L "power_lines:all-regions-infra-lines.geojsonseq" \
    -L "substations:all-regions-infra-points.geojsonseq" \
    -L "water_treatment:all-regions-infra-multipolygons.geojsonseq"
```

| Parameter | Purpose |
|---|---|
| `-Z4 -z14` | Zoom range: visible from zoom 4 (country level) to zoom 14 (street level) |
| `--drop-densest-as-needed` | At lower zooms, drop features in dense areas to keep tile sizes manageable |
| `--extend-zooms-if-still-dropping` | If features are still being dropped at z14, extend to higher zooms |
| `-L "name:file"` | Named layers: `power_lines`, `substations`, `water_treatment` |

The extract stage (`extract-osm.sh`) runs automatically if the merged GeoJSONSeq files are not found.

### GeoNames Cities

**Output**: `data/tiles/geonames-cities.mbtiles`

```bash
tippecanoe \
    -o geonames-cities.mbtiles \
    -Z2 -z12 \
    -l cities \
    --drop-densest-as-needed \
    --force \
    cities15000.geojson
```

| Parameter | Purpose |
|---|---|
| `-Z2 -z12` | Zoom 2 (continental) to zoom 12 (neighborhood). No street-level detail needed for city labels |
| `-l cities` | Single layer name: `cities` |
| `--drop-densest-as-needed` | At low zooms, keep only the largest cities by dropping dense clusters |

The GeoNames TSV file is converted to GeoJSON by an inline Python script that maps columns (name, country, population, elevation, timezone) to GeoJSON Feature properties.

### Natural Earth

**Output**: `data/tiles/natural-earth-places.mbtiles`

```bash
tippecanoe \
    -o natural-earth-places.mbtiles \
    -Z0 -z10 \
    --drop-densest-as-needed \
    --force \
    -L "populated_places:populated_places.geojson" \
    -L "urban_areas:urban_areas.geojson"
```

| Parameter | Purpose |
|---|---|
| `-Z0 -z10` | Zoom 0 (world view) to zoom 10. Natural Earth data is 1:10m scale -- not useful at street level |
| Two `-L` layers | `populated_places` (points) and `urban_areas` (polygons) |

Shapefiles are converted to GeoJSON with `ogr2ogr` before tippecanoe processes them.

### US Census TIGER/Line

**Output**: `data/tiles/demographics-us.mbtiles`

```bash
tippecanoe \
    -o demographics-us.mbtiles \
    -Z4 -z14 \
    --drop-densest-as-needed \
    --extend-zooms-if-still-dropping \
    --coalesce-densest-as-needed \
    --force \
    -L "states:states.geojson" \
    -L "counties:counties.geojson" \
    -L "tracts:tracts_merged.geojson"
```

| Parameter | Purpose |
|---|---|
| `-Z4 -z14` | States visible from zoom 4; tracts visible at higher zooms |
| `--coalesce-densest-as-needed` | Merge adjacent small polygons (tract boundaries) at lower zooms |
| `--extend-zooms-if-still-dropping` | Ensure tracts are visible at maximum zoom |
| Three `-L` layers | `states`, `counties`, `tracts` |

Census tract shapefiles are per-state (56 FIPS codes). The script converts each state's shapefile to GeoJSON and merges them into a single `tracts_merged.geojson` before running tippecanoe.

### Eurostat NUTS3

**Output**: `data/tiles/demographics-europe.mbtiles`

```bash
tippecanoe \
    -o demographics-europe.mbtiles \
    -Z2 -z12 \
    -l nuts3_regions \
    --drop-densest-as-needed \
    --force \
    nutsrg_3.json
```

| Parameter | Purpose |
|---|---|
| `-Z2 -z12` | Continental to city zoom range |
| `-l nuts3_regions` | Single layer: `nuts3_regions` |

The Nuts2json source is already GeoJSON -- no intermediate conversion needed.

### ABS Australia

**Output**: `data/tiles/demographics-australia.mbtiles`

```bash
tippecanoe \
    -o demographics-australia.mbtiles \
    -Z4 -z14 \
    --drop-densest-as-needed \
    --force \
    -L "{basename}:{file}.geojson" ...
```

The script auto-discovers shapefiles and GeoPackage files in `data/raw/abs-australia/` and creates a tippecanoe layer for each. Layer names match the input file basenames.

### EIA Power Plants

**Output**: `data/tiles/eia-powerplants.mbtiles`

```bash
tippecanoe \
    -o eia-powerplants.mbtiles \
    -Z4 -z14 \
    -l power_plants \
    --drop-densest-as-needed \
    --force \
    us_power_plants.geojson
```

| Parameter | Purpose |
|---|---|
| `-Z4 -z14` | Country to street level |
| `-l power_plants` | Single layer: `power_plants` |

### HIFLD Infrastructure

**Output**: `data/tiles/hifld-infrastructure.mbtiles`

```bash
tippecanoe \
    -o hifld-infrastructure.mbtiles \
    -Z4 -z14 \
    --drop-densest-as-needed \
    --extend-zooms-if-still-dropping \
    --force \
    -L "transmission_lines:electric_transmission_lines.geojson" \
    -L "hospitals:hospitals.geojson" \
    -L "fire_stations:fire_stations.geojson" \
    -L "schools:schools.geojson"
```

Layers are created conditionally -- if a GeoJSON file is not present (e.g., hospitals were not manually downloaded), that layer is skipped with a warning.

### NID Dams

**Output**: `data/tiles/nid-dams.mbtiles`

```bash
tippecanoe \
    -o nid-dams.mbtiles \
    -Z4 -z14 \
    -l dams \
    --drop-densest-as-needed \
    --force \
    nid_dams.geojson
```

### EPA Water

**Output**: `data/tiles/epa-water.mbtiles`

The script auto-detects the input format (GeoJSON, Shapefile, or Geodatabase) and converts to GeoJSON if needed before running tippecanoe with `-l water_systems`.

---

## Zoom Level Strategy

| Data Type | Min Zoom | Max Zoom | Rationale |
|---|---|---|---|
| Basemap (PMTiles) | 0 | 14+ | Full context at all levels |
| Country/state boundaries | 0-4 | 10-14 | Visible at continental scale |
| Lines (power, transmission) | 4 | 14 | Too dense below zoom 4 |
| Points (plants, substations) | 4-6 | 14 | Cluster at low zoom |
| Polygons (census tracts) | 4 | 14 | Coalesce at low zoom |
| City labels (GeoNames) | 2 | 12 | Major cities at low zoom; labels not needed at street level |
| Natural Earth | 0 | 10 | 1:10m scale data, unusable at high zoom |

---

## Layer Naming Conventions

All tippecanoe layer names use lowercase with underscores:

| Layer Name | Source | Geometry |
|---|---|---|
| `power_lines` | OSM Infrastructure | Lines |
| `substations` | OSM Infrastructure | Points |
| `water_treatment` | OSM Infrastructure | Polygons |
| `cities` | GeoNames | Points |
| `populated_places` | Natural Earth | Points |
| `urban_areas` | Natural Earth | Polygons |
| `states` | US Census | Polygons |
| `counties` | US Census | Polygons |
| `tracts` | US Census | Polygons |
| `nuts3_regions` | Eurostat | Polygons |
| `power_plants` | EIA | Points |
| `transmission_lines` | HIFLD | Lines |
| `hospitals` | HIFLD | Points |
| `fire_stations` | HIFLD | Points |
| `schools` | HIFLD | Points |
| `dams` | NID | Points |
| `water_systems` | EPA | Polygons |

---

## Intermediate File Cleanup

The script uses `data/work/{source}/` for intermediate files (GeoJSON converted from shapefiles or TSV). These directories are automatically cleaned up after successful conversion. If conversion fails, intermediate files remain for debugging.

---

## Related Pages

- [Pipeline](04-PIPELINE.md) -- parent page with pipeline overview
- [OSM Extraction](04b-EXTRACT.md) -- previous stage: PBF to GeoJSONSeq
- [Loading and Verification](04d-LOAD.md) -- next stage: tile loading
- [Installation Options A-E](03b-OPTIONS.md) -- which sources each option converts
- [Technology Stack](01b-STACK.md) -- tippecanoe version and capabilities

---

*[Back to Pipeline](04-PIPELINE.md)*
