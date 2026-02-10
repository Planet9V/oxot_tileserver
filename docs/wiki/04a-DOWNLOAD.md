# Download Scripts

> **Last Updated**: 2026-02-11 01:00 UTC

[Home](INDEX.md) · [Pipeline](04-PIPELINE.md) · Download Scripts

---

## Overview

The `scripts/download.sh` script is the first stage of the data pipeline. It downloads raw geospatial data from authoritative sources into `data/raw/{source_name}/`. The script supports 12 source configurations, automatic resume for interrupted downloads, and both `--source` and `--option` selection modes.

---

## Usage

```bash
# Download a single source
./scripts/download.sh --source basemap

# Download multiple sources
./scripts/download.sh --source geonames --source natural-earth

# Download all sources for an option
./scripts/download.sh --option e

# Show help
./scripts/download.sh --help
```

Inside the converter container, prefix with `/scripts/`:

```bash
/scripts/download.sh --source osm-infrastructure
/scripts/download.sh --option a
```

---

## Source Download Configurations

The script defines 12 source download functions. Each source downloads to its own subdirectory under `data/raw/`.

### Automated Downloads

These sources are downloaded automatically with `wget`.

| Source Name | Destination | Description | Approx. Size |
|---|---|---|---|
| `basemap` | `data/raw/basemap/` | Protomaps planet PMTiles + regional bounding-box extracts | ~120 GB (planet) or ~3 GB (3 regional extracts) |
| `osm-infrastructure` | `data/raw/osm-infrastructure/` | Geofabrik PBF extracts for Europe, N. America, AU/Oceania | ~25 GB (3 regions combined) |
| `geonames` | `data/raw/geonames/` | GeoNames cities15000 (cities with population > 15,000) | ~10 MB |
| `natural-earth` | `data/raw/natural-earth/` | Natural Earth 1:10m populated places + urban areas | ~15 MB |
| `census-us` | `data/raw/census-us/` | US Census TIGER/Line 2024 states, counties, tracts (56 FIPS) | ~1.5 GB |
| `eurostat` | `data/raw/eurostat/` | Eurostat Nuts2json NUTS3 regions GeoJSON | ~5 MB |
| `eia-powerplants` | `data/raw/eia-powerplants/` | EIA US Power Plants via ArcGIS Feature Server query | ~50 MB |
| `hifld-infrastructure` | `data/raw/hifld-infrastructure/` | HIFLD electric transmission lines (direct GeoJSON) | ~200 MB (transmission only) |

### Manual Downloads

These sources require the user to visit a website, authenticate or accept terms, and download files manually. The script prints instructions and the target directory.

| Source Name | Destination | Why Manual |
|---|---|---|
| `abs-australia` | `data/raw/abs-australia/` | ABS website requires interactive download |
| `epa-water` | `data/raw/epa-water/` | EPA GeoPlatform requires search and format selection |
| `nid-dams` | `data/raw/nid-dams/` | USACE NID portal requires registration or interactive query |
| `eea-water` | `data/raw/eea-water/` | EEA DataHub requires dataset selection |

For HIFLD, the transmission lines GeoJSON downloads automatically, but hospitals, fire stations, and schools require manual download from the HIFLD Open Data portal. The script prints URLs and file placement instructions for each.

---

## Download URLs

### Basemap

| Resource | URL |
|---|---|
| Protomaps planet builds | `https://maps.protomaps.com/builds/` |

The script fetches the latest daily build URL from the builds index page. Regional extracts are created using `pmtiles extract` with bounding boxes:

- Europe: `-25,34,45,72`
- North America: `-170,15,-50,85`
- Australia/NZ: `110,-50,180,-8`

### OSM Infrastructure (Geofabrik)

| Region | URL |
|---|---|
| Europe | `https://download.geofabrik.de/europe-latest.osm.pbf` |
| North America | `https://download.geofabrik.de/north-america-latest.osm.pbf` |
| Australia/Oceania | `https://download.geofabrik.de/australia-oceania-latest.osm.pbf` |

### Demographics and Labels

| Source | URL |
|---|---|
| GeoNames cities15000 | `https://download.geonames.org/export/dump/cities15000.zip` |
| Natural Earth places | `https://naciscdn.org/naturalearth/10m/cultural/ne_10m_populated_places_simple.zip` |
| Natural Earth urban areas | `https://naciscdn.org/naturalearth/10m/cultural/ne_10m_urban_areas.zip` |
| US Census states | `https://www2.census.gov/geo/tiger/TIGER2024/STATE/tl_2024_us_state.zip` |
| US Census counties | `https://www2.census.gov/geo/tiger/TIGER2024/COUNTY/tl_2024_us_county.zip` |
| US Census tracts | `https://www2.census.gov/geo/tiger/TIGER2024/TRACT/tl_2024_{FIPS}_tract.zip` (per state) |
| Eurostat NUTS3 | `https://raw.githubusercontent.com/eurostat/Nuts2json/master/pub/v2/2021/4326/20M/nutsrg_3.json` |

### Infrastructure

| Source | URL |
|---|---|
| EIA Power Plants | ArcGIS Feature Server query (GeoJSON, `where=1=1`) |
| HIFLD Transmission | ArcGIS Open Data download endpoint (GeoJSON, EPSG:4326) |

---

## Resume Support

All automated downloads use `wget --continue` (the `-c` flag). If a download is interrupted, re-running the script resumes from where it left off rather than starting over. This is particularly important for the large Geofabrik PBF files and the Protomaps planet file.

---

## Skip Logic

The download function checks whether a destination file already exists and has a non-zero size before attempting to download. Existing files are skipped with an informational message:

```
[INFO] File already exists (1234567 bytes): data/raw/geonames/cities15000.zip
[INFO] Use --continue to resume partial downloads. Skipping.
```

To force a re-download, delete the existing file first:

```bash
rm data/raw/geonames/cities15000.zip
/scripts/download.sh --source geonames
```

---

## Error Handling

- If a `wget` download fails, the script logs an error and continues to the next source.
- The exit code reflects whether any sources failed (exit 1 if any failures, exit 0 if all succeeded).
- For per-state Census tract downloads, individual FIPS codes that fail (some territories may not have tract files) are logged as warnings without halting the entire Census download.

---

## Option-to-Source Mapping

| Option | Sources |
|---|---|
| A | `basemap`, `osm-infrastructure`, `natural-earth` |
| B | `census-us`, `hifld-infrastructure`, `eia-powerplants`, `nid-dams`, `epa-water` |
| C | `basemap`, `osm-infrastructure`, `census-us`, `hifld-infrastructure` |
| D | `hifld-infrastructure`, `census-us` |
| E | `basemap`, `osm-infrastructure`, `geonames`, `eurostat`, `census-us`, `abs-australia` |

---

## Estimated Download Times

Times below assume a 50 Mbps internet connection. Actual times vary with server load and geographic distance.

| Source | Approx. Download Size | Approx. Time |
|---|---|---|
| Protomaps basemap (planet) | ~120 GB | ~5.5 hrs |
| Protomaps basemap (3 regional extracts) | ~3 GB | ~8 min |
| Geofabrik Europe PBF | ~12 GB | ~30 min |
| Geofabrik N. America PBF | ~10 GB | ~25 min |
| Geofabrik AU/Oceania PBF | ~1 GB | ~3 min |
| US Census TIGER/Line (all) | ~1.5 GB | ~4 min |
| HIFLD transmission lines | ~200 MB | ~30 sec |
| EIA Power Plants | ~50 MB | ~10 sec |
| GeoNames cities15000 | ~10 MB | ~5 sec |
| Natural Earth (2 datasets) | ~15 MB | ~5 sec |
| Eurostat NUTS3 | ~5 MB | ~5 sec |

---

## Related Pages

- [Pipeline](04-PIPELINE.md) -- parent page with pipeline overview
- [Data Sources](02-DATA-SOURCES.md) -- detailed source documentation
- [OSM Extraction](04b-EXTRACT.md) -- next pipeline stage for OSM data
- [Conversion and Tippecanoe](04c-CONVERT.md) -- next pipeline stage for all sources
- [Environment Configuration](03d-ENVIRONMENT.md) -- `REGIONS` and `CENSUS_API_KEY` variables

---

*[Back to Pipeline](04-PIPELINE.md)*
