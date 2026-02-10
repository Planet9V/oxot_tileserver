# Architecture & Components

> **Last Updated**: 2026-02-11 01:00 UTC

[Home](INDEX.md) > [System Overview](01-OVERVIEW.md) > Architecture & Components

---

## Overview

The OXOT Tileserver uses a two-container Docker architecture that separates data preparation from tile serving. This separation provides several benefits: the tileserver container stays lightweight and fast, the converter container can be upgraded independently, and the data volume persists across container restarts.

This page documents the container architecture, data flow pipeline, file system layout, Docker networking, configuration structure, and style system.

---

## Two-Container Architecture

### Container 1: tileserver-gl (Runtime)

The tileserver-gl container is the long-running service that clients connect to. It is based on the official `maptiler/tileserver-gl` Docker image and configured through a JSON configuration file.

| Property | Value |
|----------|-------|
| **Base image** | `maptiler/tileserver-gl:latest` |
| **Exposed port** | 8080 (configurable via `.env`) |
| **Volume mount** | `/data` (shared data volume) |
| **Config file** | `/data/config/tileserver-config.json` |
| **Restart policy** | `unless-stopped` |
| **Memory** | 512 MB minimum, 2 GB recommended |

The tileserver reads MBTiles and PMTiles files from the data volume and serves them as vector tiles over HTTP. It also serves MapLibre GL style JSON files and can render raster preview tiles on the server side.

### Container 2: converter (Tools Profile)

The converter container is an ephemeral container used during data preparation. It contains all the geospatial tools needed to download, extract, filter, and convert source data into vector tiles.

| Property | Value |
|----------|-------|
| **Dockerfile** | `Dockerfile.converter` |
| **Volume mount** | `/data` (shared data volume) |
| **Entrypoint** | `/bin/bash` (interactive or script execution) |
| **Installed tools** | tippecanoe, osmium-tool, ogr2ogr/GDAL, pmtiles CLI, curl, jq |
| **Lifecycle** | Runs on demand, exits when done |

The converter container is invoked via `docker compose run converter <command>`. It writes output to the shared data volume, which the tileserver container reads.

---

## Data Flow

The complete data flow from source to client follows this pipeline:

```
                        DOWNLOAD PHASE
                        ==============
  US Census  ----+
  Eurostat   ----+
  EIA        ----+--> download.sh --> data/raw/
  EPA        ----+       |               |
  OSM PBF    ----+       |         .pbf, .geojson,
  HIFLD      ----+       |         .shp, .csv, .zip
  ENTSO-E    ----+       |
  ...        ----+       v

                       EXTRACT PHASE
                       =============
                   extract-osm.sh --> data/extracted/
                        |                  |
                   (osmium filter     .geojson files
                    by tag sets)      per domain/source

                       CONVERT PHASE
                       =============
                     convert.sh --> data/tiles/
                        |               |
                   (tippecanoe,    .mbtiles and
                    ogr2ogr,       .pmtiles files
                    pmtiles)       per domain

                        LOAD PHASE
                        ==========
                     verify.sh --> data/config/
                        |               |
                   (inspect tiles, tileserver-config.json
                    generate        updated with new
                    config)         tileset entries

                       SERVE PHASE
                       ===========
                   tileserver-gl <-- data/config/tileserver-config.json
                        |
                   REST API on :8080
                        |
                   +----+----+----+
                   |    |    |    |
                  TileJSON  PBF  Style  Raster
                  metadata  tiles JSON  preview
                        |
                   Map clients
                   (MapLibre, Leaflet, OpenLayers)
```

### Phase Details

**Download phase**: `download.sh` fetches raw data from authoritative sources. Each source has a dedicated download function that handles authentication (if needed), URL construction, progress reporting, and checksum verification. Files are stored in `data/raw/<source>/`.

**Extract phase**: `extract-osm.sh` processes OpenStreetMap PBF files using osmium-tool. It filters features by tag sets relevant to each infrastructure domain (e.g., `power=line`, `power=substation` for electric grid). Non-OSM sources skip this phase since they arrive as GeoJSON or Shapefile. Output goes to `data/extracted/<domain>/`.

**Convert phase**: `convert.sh` transforms GeoJSON and Shapefile data into vector tiles using tippecanoe. It applies domain-specific settings for minimum/maximum zoom, feature simplification, attribute retention, and layer naming. For sources that provide Shapefile or CSV, ogr2ogr converts to GeoJSON first. Output tiles are written to `data/tiles/`.

**Load phase**: `verify.sh` inspects generated tile files, validates layer contents, and generates or updates `tileserver-config.json` to register new tilesets with tileserver-gl.

**Serve phase**: tileserver-gl reads the configuration and serves tiles. No further data processing occurs at runtime.

---

## File System Layout

```
oxot_tileserver/
|
+-- docker-compose.yml          # Service definitions
+-- Dockerfile.converter         # Converter container build
+-- .env                         # Environment variables
+-- .env.example                 # Template environment file
|
+-- scripts/
|   +-- download.sh              # Source data download automation
|   +-- extract-osm.sh           # OSM tag extraction
|   +-- convert.sh               # Tippecanoe conversion
|   +-- verify.sh                # Tile verification and config gen
|   +-- update.sh                # Scheduled update orchestrator
|   +-- lib/
|       +-- sources.sh           # Source URL definitions
|       +-- regions.sh           # Region boundary definitions
|       +-- common.sh            # Shared utility functions
|
+-- config/
|   +-- tileserver-config.json   # Tileserver-gl configuration (generated)
|   +-- styles/
|       +-- infrastructure.json  # Primary MapLibre GL style
|       +-- basemap-light.json   # Light basemap style
|       +-- basemap-dark.json    # Dark basemap style
|
+-- data/                        # Docker volume (mounted in both containers)
|   +-- raw/                     # Downloaded source files
|   |   +-- census/
|   |   +-- eurostat/
|   |   +-- eia/
|   |   +-- osm/
|   |   +-- ...
|   +-- extracted/               # Filtered GeoJSON
|   |   +-- electric/
|   |   +-- water/
|   |   +-- demographics/
|   |   +-- telecoms/
|   +-- tiles/                   # Generated MBTiles / PMTiles
|   |   +-- basemap.mbtiles
|   |   +-- electric-grid.mbtiles
|   |   +-- water-infra.mbtiles
|   |   +-- demographics.mbtiles
|   |   +-- telecoms.mbtiles
|   +-- config/                  # Runtime configuration
|   +-- styles/                  # Runtime styles (copied from config/)
|
+-- docs/
    +-- wiki/                    # This documentation
        +-- manifest.json
        +-- INDEX.md
        +-- ...
```

### Directory Purposes

| Directory | Purpose | Lifecycle |
|-----------|---------|-----------|
| `scripts/` | Pipeline automation scripts | Version-controlled, read-only at runtime |
| `config/` | Style files and config templates | Version-controlled, templates for generation |
| `data/raw/` | Downloaded source files | Created by download.sh, can be deleted after conversion |
| `data/extracted/` | Filtered GeoJSON intermediates | Created by extract-osm.sh, can be deleted after conversion |
| `data/tiles/` | Final tile files served by tileserver | Created by convert.sh, required at runtime |
| `data/config/` | Generated tileserver configuration | Created by verify.sh, required at runtime |

---

## Docker Networking

The tileserver container exposes a single HTTP port (default 8080). The converter container does not expose any ports since it only performs batch processing.

```yaml
# docker-compose.yml (simplified)
services:
  tileserver:
    image: maptiler/tileserver-gl:latest
    ports:
      - "${TILESERVER_PORT:-8080}:8080"
    volumes:
      - tile-data:/data
    restart: unless-stopped
    command: --config /data/config/tileserver-config.json

  converter:
    build:
      context: .
      dockerfile: Dockerfile.converter
    volumes:
      - tile-data:/data
    profiles:
      - tools
    entrypoint: /bin/bash

volumes:
  tile-data:
```

The `converter` service uses the `tools` profile, meaning it does not start with `docker compose up` but must be explicitly invoked with `docker compose run converter <command>`. This prevents unnecessary resource consumption.

---

## Tileserver Configuration Structure

The `tileserver-config.json` file tells tileserver-gl which tile files to serve and which styles to offer. It is generated by `verify.sh` but can be manually edited.

```json
{
  "options": {
    "paths": {
      "root": "/data",
      "mbtiles": "/data/tiles",
      "styles": "/data/styles"
    }
  },
  "data": {
    "basemap": {
      "mbtiles": "basemap.mbtiles"
    },
    "electric-grid": {
      "mbtiles": "electric-grid.mbtiles"
    },
    "water-infra": {
      "mbtiles": "water-infra.mbtiles"
    },
    "demographics": {
      "mbtiles": "demographics.mbtiles"
    },
    "telecoms": {
      "mbtiles": "telecoms.mbtiles"
    }
  },
  "styles": {
    "infrastructure": {
      "style": "infrastructure.json",
      "tilejson": {
        "bounds": [-180, -85, 180, 85]
      }
    }
  }
}
```

Each entry in the `data` object registers a tileset. The key becomes the tileset identifier used in API URLs (e.g., `/data/electric-grid/{z}/{x}/{y}.pbf`).

---

## Style System

Styles are MapLibre GL style specification JSON files that define how vector tile data is rendered. The OXOT Tileserver ships with three default styles:

| Style | File | Purpose |
|-------|------|---------|
| `infrastructure` | `infrastructure.json` | Primary style with all infrastructure layers color-coded by domain |
| `basemap-light` | `basemap-light.json` | Light basemap for printing and high-contrast overlays |
| `basemap-dark` | `basemap-dark.json` | Dark basemap for operational dashboards |

Each style references one or more tilesets as sources and defines layers with paint and layout properties. The `infrastructure.json` style uses a color scheme that distinguishes domains:

| Domain | Primary Color | Rationale |
|--------|--------------|-----------|
| Electric grid | `#FFB300` (amber) | Standard power/energy color |
| Water | `#1E88E5` (blue) | Natural water association |
| Demographics | `#7CB342` (green) | Population/land use |
| Telecoms | `#E53935` (red) | High-visibility for sparse features |
| Basemap | `#9E9E9E` (grey) | Background context |

See [Custom Layer Styling](07d-STYLING.md) for instructions on creating and modifying styles.

---

## Security Considerations

The tileserver serves pre-generated static tiles. There is no database, no user authentication, and no query language exposed. The attack surface is limited to the HTTP server and the tile files themselves.

For deployments in sensitive environments:

- Run behind a reverse proxy (nginx, Traefik) with TLS termination
- Restrict access to the Docker socket
- Use read-only volume mounts for the tileserver container
- Run the converter container only during maintenance windows
- Validate downloaded source data checksums before processing

---

## Next Steps

- [Technology Stack](01b-STACK.md) -- detailed tool specifications and selection rationale
- [System Requirements](01c-REQUIREMENTS.md) -- hardware and software prerequisites
- [Docker Deployment](03a-DOCKER-SETUP.md) -- step-by-step Docker setup guide

---

*[Home](INDEX.md) > [System Overview](01-OVERVIEW.md) > Architecture & Components*
