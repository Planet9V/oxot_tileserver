# Data Pipeline

> **Last Updated**: 2026-02-11 01:00 UTC

[Home](INDEX.md) · Data Pipeline

---

## Overview

The OXOT Tileserver data pipeline transforms raw geospatial data from 21 sources into optimized vector tiles served by tileserver-gl. The pipeline has four stages, each implemented as a standalone shell script in the `scripts/` directory.

---

## Pipeline Stages

```
 +-------------+     +-------------+     +-------------+     +-------------+
 |  DOWNLOAD   | --> |   EXTRACT   | --> |   CONVERT   | --> |    LOAD     |
 | download.sh |     |extract-osm  |     | convert.sh  |     |  load.sh    |
 +------+------+     +------+------+     +------+------+     +------+------+
        |                    |                   |                   |
   Raw files            Filtered            MBTiles /           Tileserver
   data/raw/           GeoJSONSeq           PMTiles            restart +
                       data/raw/           data/tiles/          verify
```

### Stage 1: Download

**Script**: `scripts/download.sh`

Downloads raw data from authoritative sources into `data/raw/{source}/`. Supports 12 source configurations with both automated (wget) and manual download paths. Skips files that already exist. Supports resume with `wget -c`.

### Stage 2: Extract

**Script**: `scripts/extract-osm.sh`

Filters OpenStreetMap PBF files to infrastructure-only tags using `osmium tags-filter`, then converts the filtered PBF to GeoJSONSeq using `ogr2ogr`. Merges all regions (Europe, North America, Australia/Oceania) into combined files per geometry type (lines, points, polygons).

This stage only applies to the `osm-infrastructure` source. Other sources (Census shapefiles, GeoJSON files, TSV) are converted directly in Stage 3.

### Stage 3: Convert

**Script**: `scripts/convert.sh`

Transforms raw or extracted data into MBTiles vector tiles using `tippecanoe`. Each source has its own conversion function with tuned zoom levels, density dropping, and layer naming. Some sources require intermediate format conversion via `ogr2ogr` (shapefile to GeoJSON) before tippecanoe can process them.

### Stage 4: Load

**Script**: `scripts/load.sh`

Validates all tile files in `data/tiles/`, restarts the tileserver container, waits for the healthcheck to pass, and queries `/index.json` to list available tilesets. This stage confirms the pipeline output is being served correctly.

---

## Script Locations

All scripts live in the `scripts/` directory at the repository root. Inside the converter container, they are mounted read-only at `/scripts/`.

| Script | Host Path | Container Path | Purpose |
|---|---|---|---|
| `download.sh` | `scripts/download.sh` | `/scripts/download.sh` | Download raw data |
| `extract-osm.sh` | `scripts/extract-osm.sh` | `/scripts/extract-osm.sh` | Filter OSM PBF to infrastructure |
| `convert.sh` | `scripts/convert.sh` | `/scripts/convert.sh` | Convert raw data to tiles |
| `load.sh` | `scripts/load.sh` | `/scripts/load.sh` | Validate and load tiles |
| `update.sh` | `scripts/update.sh` | `/scripts/update.sh` | Re-run full pipeline for updates |

---

## Running the Pipeline

### Full pipeline via option script

The simplest way to run the pipeline is through an option script, which chains all four stages:

```bash
./options/option-a.sh
```

### Full pipeline manually

```bash
# Inside the converter container
docker compose --profile tools run converter bash

# Stage 1: Download
/scripts/download.sh --option e

# Stage 2: Extract (called automatically by convert.sh if needed)
/scripts/extract-osm.sh

# Stage 3: Convert
/scripts/convert.sh --option e

# Exit the converter
exit

# Stage 4: Load (run from the host to restart the tileserver)
./scripts/load.sh
```

### Single-source pipeline

```bash
docker compose --profile tools run converter /scripts/download.sh --source geonames
docker compose --profile tools run converter /scripts/convert.sh --source geonames
./scripts/load.sh
```

### Update pipeline

The `update.sh` script re-runs download, convert (with `--force`), and load for specified sources:

```bash
docker compose --profile tools run converter /scripts/update.sh --source osm-infrastructure
```

---

## Data Flow by Source Type

| Source Type | Download | Extract | Convert | Output |
|---|---|---|---|---|
| OSM PBF | Geofabrik wget | osmium filter + ogr2ogr | tippecanoe | `.mbtiles` |
| Protomaps PMTiles | wget planet | pmtiles extract | Copy regional files | `.pmtiles` |
| GeoJSON (HIFLD, EIA) | wget / ArcGIS API | -- | tippecanoe | `.mbtiles` |
| Shapefile (Census, NE) | wget ZIP | -- | ogr2ogr + tippecanoe | `.mbtiles` |
| TSV (GeoNames) | wget ZIP | -- | python3 + tippecanoe | `.mbtiles` |
| Manual (NID, EPA, EEA, ABS) | User downloads | -- | ogr2ogr + tippecanoe | `.mbtiles` |

---

## Child Pages

| Page | Description |
|---|---|
| [Download Scripts](04a-DOWNLOAD.md) | Source-specific download automation and URL catalog |
| [OSM Extraction](04b-EXTRACT.md) | Osmium tag filtering and region merging |
| [Conversion and Tippecanoe](04c-CONVERT.md) | Per-source tippecanoe options and layer naming |
| [Loading and Verification](04d-LOAD.md) | Tile validation, tileserver restart, health checks |
| [Updates and Scheduling](04e-MAINTENANCE.md) | Cron-based refresh automation and rollback |

---

## Related Pages

- [Installation](03-INSTALLATION.md) -- prerequisites and initial setup
- [Installation Options A-E](03b-OPTIONS.md) -- pre-configured source bundles
- [Converter Container](03c-CONVERTER.md) -- the toolchain container
- [Data Sources](02-DATA-SOURCES.md) -- authoritative source documentation

---

*[Back to Home](INDEX.md)*
