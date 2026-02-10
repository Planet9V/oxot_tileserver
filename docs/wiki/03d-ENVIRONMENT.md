# Environment Configuration

> **Last Updated**: 2026-02-11 01:00 UTC

[Home](INDEX.md) · [Installation](03-INSTALLATION.md) · Environment Configuration

---

## Overview

The OXOT Tileserver is configured through environment variables defined in a `.env` file at the repository root. A template is provided as `.env.example`. Copy it to `.env` and edit as needed before starting the stack.

```bash
cp .env.example .env
```

---

## Variable Reference

### TILESERVER_PORT

| Property | Value |
|---|---|
| Default | `8080` |
| Required | No |
| Used by | `docker-compose.yml` (tileserver port mapping) |

The host port on which the tileserver is accessible. The container always listens on internal port 8080. Change this if port 8080 is already in use.

```bash
TILESERVER_PORT=9090
```

After changing this value, restart the tileserver:

```bash
docker compose down && docker compose up -d
```

---

### REGIONS

| Property | Value |
|---|---|
| Default | `europe,north-america,australia-oceania` |
| Required | No |
| Used by | `docker-compose.yml` (converter environment), download/extract scripts |

Comma-separated list of geographic regions to process. The pipeline scripts use this to determine which Geofabrik PBF extracts to download and which Protomaps basemap regions to extract.

Valid values: `europe`, `north-america`, `australia-oceania`

```bash
# Process all three regions (default)
REGIONS=europe,north-america,australia-oceania

# Process North America only
REGIONS=north-america
```

---

### BASEMAP_MODE

| Property | Value |
|---|---|
| Default | `extract` |
| Required | No |
| Used by | `download.sh` (basemap source) |

Controls how the Protomaps basemap is handled.

- `extract` -- Download the planet PMTiles file and create regional bounding-box extracts. This is the recommended mode and produces smaller tile files.
- `planet` -- Use the full planet file directly. Requires approximately 120 GB of disk space. Only useful if you need global coverage at all zoom levels.

```bash
BASEMAP_MODE=extract
```

---

### DATA_DIR

| Property | Value |
|---|---|
| Default | `./data` |
| Required | No |
| Used by | Pipeline scripts |

Root directory for all data storage. Contains subdirectories for raw downloads (`raw/`), intermediate work files (`work/`), and final tile output (`tiles/`).

```bash
DATA_DIR=./data
```

---

### RAW_DIR

| Property | Value |
|---|---|
| Default | `./data/raw` |
| Required | No |
| Used by | `download.sh`, `extract-osm.sh`, `convert.sh` |

Directory where raw downloaded files are stored, organized by source name. Each source has its own subdirectory (for example, `data/raw/osm-infrastructure/`, `data/raw/census-us/`).

```bash
RAW_DIR=./data/raw
```

---

### TILES_DIR

| Property | Value |
|---|---|
| Default | `./data/tiles` |
| Required | No |
| Used by | `convert.sh`, `load.sh`, `docker-compose.yml` (tileserver volume) |

Directory where final MBTiles and PMTiles files are written. This directory is mounted into the tileserver container at `/data`.

```bash
TILES_DIR=./data/tiles
```

---

### CENSUS_API_KEY

| Property | Value |
|---|---|
| Default | (empty) |
| Required | No (optional) |
| Used by | Census download scripts (ACS data enrichment) |

An API key for the US Census Bureau data API. Required only if you want to enrich TIGER/Line boundaries with American Community Survey (ACS) demographic attributes. The key is free.

**How to obtain a key:**

1. Visit [https://api.census.gov/data/key_signup.html](https://api.census.gov/data/key_signup.html).
2. Fill in your name and email address.
3. You will receive the key by email within minutes.

```bash
CENSUS_API_KEY=your_api_key_here
```

If left blank, the pipeline downloads TIGER/Line boundary geometry without ACS attribute enrichment.

---

### TIPPECANOE_THREADS

| Property | Value |
|---|---|
| Default | `4` |
| Required | No |
| Used by | `convert.sh` (tippecanoe parallelism) |

Number of threads tippecanoe uses for tile generation. Higher values speed up conversion on multi-core machines but increase memory usage. A reasonable starting point is the number of CPU cores minus one.

```bash
# Use 8 threads on a machine with 10+ cores
TIPPECANOE_THREADS=8
```

---

## Complete .env.example

```bash
# OXOT Tileserver Configuration

# Tileserver port
TILESERVER_PORT=8080

# Regions to process (comma-separated)
# Options: europe, north-america, australia-oceania
REGIONS=europe,north-america,australia-oceania

# Protomaps basemap (set to "planet" for full, or "extract" for region-only)
BASEMAP_MODE=extract

# Data storage paths
DATA_DIR=./data
RAW_DIR=./data/raw
TILES_DIR=./data/tiles

# Optional: Census API key (for US Census Bureau data)
# Get one at: https://api.census.gov/data/key_signup.html
CENSUS_API_KEY=

# Optional: increase tippecanoe parallelism
TIPPECANOE_THREADS=4
```

---

## Related Pages

- [Installation](03-INSTALLATION.md) -- parent page with quick start
- [Docker Deployment](03a-DOCKER-SETUP.md) -- how `.env` values flow into docker-compose.yml
- [Download Scripts](04a-DOWNLOAD.md) -- how `REGIONS` and `CENSUS_API_KEY` are used
- [Conversion and Tippecanoe](04c-CONVERT.md) -- how `TIPPECANOE_THREADS` affects performance

---

*[Back to Installation](03-INSTALLATION.md)*
