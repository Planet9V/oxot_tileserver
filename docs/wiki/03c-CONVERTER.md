# Converter Container

> **Last Updated**: 2026-02-11 01:00 UTC

[Home](INDEX.md) · [Installation](03-INSTALLATION.md) · Converter Container

---

## Overview

The converter is a custom Docker container built from `Dockerfile.converter`. It packages every tool the OXOT Tileserver pipeline needs to download, filter, transform, and tile geospatial data. The container is only started on demand using the Docker Compose `tools` profile -- it does not run as a persistent service.

---

## Dockerfile Breakdown

The Dockerfile uses a single-stage build based on Ubuntu 24.04.

### Base Image

```dockerfile
FROM ubuntu:24.04
ENV DEBIAN_FRONTEND=noninteractive
```

Ubuntu 24.04 (Noble Numbat) LTS provides recent versions of system packages including GDAL 3.8+ and osmium-tool 1.16+.

### System Packages (apt)

```dockerfile
RUN apt-get update && apt-get install -y \
    build-essential \
    cmake \
    git \
    wget \
    curl \
    jq \
    unzip \
    python3 \
    python3-pip \
    osmium-tool \
    gdal-bin \
    libsqlite3-dev \
    zlib1g-dev \
    && rm -rf /var/lib/apt/lists/*
```

| Package | Purpose |
|---|---|
| `build-essential`, `cmake` | Build toolchain for compiling tippecanoe |
| `git` | Clone tippecanoe source repository |
| `wget`, `curl` | Download data sources with resume support |
| `jq` | Parse JSON responses (GitHub API, tileserver API) |
| `unzip` | Extract ZIP archives (Census, GeoNames, Natural Earth) |
| `python3`, `python3-pip` | TSV-to-GeoJSON conversion (GeoNames), general scripting |
| `osmium-tool` | Filter OSM PBF files by tag (power, water, telecom) |
| `gdal-bin` | Provides `ogr2ogr` for format conversion (PBF to GeoJSONSeq, SHP to GeoJSON) |
| `libsqlite3-dev`, `zlib1g-dev` | Build dependencies for tippecanoe |

### Tippecanoe (built from source)

```dockerfile
RUN git clone https://github.com/felt/tippecanoe.git /tmp/tippecanoe \
    && cd /tmp/tippecanoe \
    && make -j$(nproc) \
    && make install \
    && rm -rf /tmp/tippecanoe
```

Tippecanoe is the core tool for converting GeoJSON to MBTiles vector tiles. Building from source ensures the latest version with all features. The build uses all available CPU cores (`-j$(nproc)`) and cleans up the source tree afterward.

### PMTiles CLI

```dockerfile
RUN PMTILES_VERSION=$(curl -s https://api.github.com/repos/protomaps/go-pmtiles/releases/latest \
      | jq -r '.tag_name') \
    && wget -q "https://github.com/protomaps/go-pmtiles/releases/download/${PMTILES_VERSION}/go-pmtiles_${PMTILES_VERSION#v}_Linux_x86_64.tar.gz" \
        -O /tmp/pmtiles.tar.gz \
    && tar -xzf /tmp/pmtiles.tar.gz -C /usr/local/bin pmtiles \
    && chmod +x /usr/local/bin/pmtiles \
    && rm /tmp/pmtiles.tar.gz
```

The PMTiles CLI is used to create regional extracts from the Protomaps planet basemap file. The version is resolved dynamically from the GitHub releases API.

### Working Directory

```dockerfile
WORKDIR /data
CMD ["bash"]
```

The container starts in `/data`, which is the mount point for the host `./data` directory. The default command opens a bash shell.

---

## Tool Inventory

| Tool | Version Source | Command | What It Does |
|---|---|---|---|
| osmium-tool | Ubuntu 24.04 apt | `osmium tags-filter` | Filters OSM PBF files to specific tags (power, water, telecom) |
| ogr2ogr | Ubuntu 24.04 apt (GDAL) | `ogr2ogr -f GeoJSON` | Converts between geospatial formats (PBF to GeoJSONSeq, SHP to GeoJSON) |
| tippecanoe | Built from source (latest) | `tippecanoe -o out.mbtiles` | Converts GeoJSON/GeoJSONSeq to MBTiles vector tiles with zoom/density control |
| pmtiles | GitHub release (latest) | `pmtiles extract` | Creates regional bounding-box extracts from planet PMTiles files |
| wget | Ubuntu 24.04 apt | `wget -c` | Downloads files with resume support |
| curl | Ubuntu 24.04 apt | `curl -sf` | HTTP requests for API queries and health checks |
| jq | Ubuntu 24.04 apt | `jq -r '.key'` | Parses JSON from APIs and configuration files |
| python3 | Ubuntu 24.04 apt | `python3 -c "..."` | Inline data transformation (GeoNames TSV to GeoJSON) |

---

## Entering the Container

### Interactive shell

```bash
docker compose --profile tools run converter bash
```

This creates a new container instance, mounts all volumes, and drops you into a bash prompt. The working directory is `/data`.

### Running a single command

```bash
docker compose --profile tools run converter /scripts/download.sh --source basemap
```

The container exits when the command finishes.

### Running scripts inside the shell

Once inside the container, scripts are accessible at `/scripts/`:

```bash
# From inside the converter container
/scripts/download.sh --source osm-infrastructure
/scripts/extract-osm.sh
/scripts/convert.sh --source osm-infrastructure
/scripts/load.sh --no-restart
```

Note: `load.sh --no-restart` is appropriate inside the converter because the converter cannot restart the tileserver container. Run `load.sh` (without `--no-restart`) from the host to restart tileserver-gl.

---

## Directory Layout Inside the Container

```
/data/                   Working directory (host: ./data)
  raw/                   Downloaded raw data files
    basemap/             Protomaps planet + regional extracts
    osm-infrastructure/  Geofabrik PBF files + filtered outputs
    geonames/            cities15000.txt
    census-us/           TIGER/Line shapefiles
    ...
  work/                  Intermediate conversion files (cleaned up after)
  tiles/                 Final MBTiles and PMTiles output files
  update.log             Update pipeline log

/scripts/                Pipeline scripts (host: ./scripts, read-only)
/sources/                Source configuration (host: ./sources, read-only)
/config/                 Configuration files (host: ./config, read-only)
```

---

## Building a Custom Converter Image

If you modify `Dockerfile.converter` (for example, to add a new tool or pin a specific tippecanoe version):

```bash
docker compose --profile tools build converter
```

To force a full rebuild without cache:

```bash
docker compose --profile tools build --no-cache converter
```

The image is built locally and tagged by Docker Compose. It is not pushed to any registry.

---

## Related Pages

- [Installation](03-INSTALLATION.md) -- parent page with quick start
- [Docker Deployment](03a-DOCKER-SETUP.md) -- docker-compose.yml structure
- [OSM Extraction](04b-EXTRACT.md) -- how osmium-tool filters PBF files
- [Conversion and Tippecanoe](04c-CONVERT.md) -- tippecanoe options per source
- [Technology Stack](01b-STACK.md) -- full technology inventory

---

*[Back to Installation](03-INSTALLATION.md)*
