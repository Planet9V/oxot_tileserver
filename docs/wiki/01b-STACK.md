# Technology Stack

> **Last Updated**: 2026-02-11 01:00 UTC

[Home](INDEX.md) > [System Overview](01-OVERVIEW.md) > Technology Stack

---

## Overview

The OXOT Tileserver is built on a focused set of open-source tools, each selected for a specific role in the data pipeline or serving layer. This page documents every technology used, its version, license, purpose, and why it was chosen over alternatives.

---

## Runtime Dependencies

These tools are required to serve tiles at runtime.

| Technology | Version | License | Purpose |
|------------|---------|---------|---------|
| **tileserver-gl** | 4.x | BSD-2-Clause | Serves vector and raster tiles over HTTP from MBTiles/PMTiles files |
| **Docker Engine** | 24.0+ | Apache 2.0 | Container runtime for both tileserver and converter |
| **Docker Compose** | 2.20+ | Apache 2.0 | Multi-container orchestration |

### tileserver-gl

tileserver-gl is the core serving component. It reads MBTiles files and serves their contents as vector tiles (PBF), raster tiles (PNG), TileJSON metadata, and MapLibre GL style JSON. It was chosen because:

- It is the most widely deployed open-source vector tile server
- It supports both MBTiles and PMTiles formats
- It implements the TileJSON and MapLibre GL style specifications
- It provides server-side raster rendering for clients that cannot render vector tiles
- It has a minimal runtime footprint (Node.js-based, single process)
- The Docker image is maintained by MapTiler and regularly updated

### Docker

Docker provides the isolation and portability layer. The two-container design allows the tileserver to run with minimal dependencies while the converter container carries the full geospatial toolchain. Docker was chosen over bare-metal installation because:

- Reproducible environments across development, staging, and production
- Dependency isolation (GDAL, tippecanoe, osmium have complex build requirements)
- Simple deployment via `docker compose up`
- Compatible with air-gapped environments (images can be pre-pulled)

---

## Build-Time Dependencies (Converter Container)

These tools are installed in the converter container via `Dockerfile.converter`. They are used during data preparation and are not needed at runtime.

| Technology | Version | License | Purpose |
|------------|---------|---------|---------|
| **tippecanoe** | 2.x | BSD-2-Clause | Converts GeoJSON to MBTiles vector tiles with zoom-level optimization |
| **osmium-tool** | 1.16+ | GPL-3.0 | Filters and extracts features from OpenStreetMap PBF files |
| **ogr2ogr (GDAL)** | 3.8+ | MIT | Converts between geospatial formats (Shapefile, GeoJSON, CSV, GeoPackage) |
| **pmtiles CLI** | 3.x | BSD-3-Clause | Converts MBTiles to PMTiles cloud-optimized format |
| **curl** | 8.x | MIT-like | Downloads source data files |
| **jq** | 1.7+ | MIT | JSON processing for GeoJSON manipulation and config generation |
| **sqlite3** | 3.40+ | Public domain | Inspects MBTiles files (which are SQLite databases) |
| **Node.js** | 20 LTS | MIT | Runs helper scripts for complex data transformations |

### tippecanoe

tippecanoe is the vector tile generation engine. It takes GeoJSON input and produces MBTiles output with intelligent simplification at each zoom level. It was chosen because:

- Felt/Mapbox maintains it as the industry standard for vector tile generation
- It handles multi-gigabyte GeoJSON inputs efficiently via streaming
- It provides fine-grained control over feature dropping, simplification, and attribute retention at each zoom level
- It produces optimally compressed PBF tiles
- It supports parallel tile generation for large datasets

Key tippecanoe flags used in the pipeline:

| Flag | Purpose |
|------|---------|
| `-z` / `-Z` | Maximum and minimum zoom level |
| `--drop-densest-as-needed` | Feature thinning at low zooms |
| `--extend-zooms-if-still-dropping` | Prevents premature feature dropping |
| `-l` | Layer name within the tileset |
| `--no-tile-compression` | For PMTiles output compatibility |
| `-o` | Output MBTiles file path |

### osmium-tool

osmium-tool processes OpenStreetMap PBF extracts. OSM data is the backbone of the basemap and contributes power and water infrastructure features globally. osmium was chosen because:

- It is the fastest OSM data processing tool available
- It supports tag-based filtering to extract domain-specific features
- It outputs GeoJSON directly, feeding into tippecanoe
- It handles planet-scale PBF files with bounded memory

### ogr2ogr (GDAL)

ogr2ogr is the Swiss Army knife of geospatial format conversion. Many government data sources provide Shapefile, GeoPackage, or CSV formats that must be converted to GeoJSON before tippecanoe processing. GDAL was chosen because:

- It supports over 80 vector formats
- It handles coordinate reference system (CRS) reprojection
- It can filter features by attribute or spatial extent
- It is the most mature and widely tested geospatial library

### pmtiles CLI

pmtiles is a cloud-optimized tile format that stores all tiles in a single file with an internal index, enabling HTTP range-request access without a tile server. The CLI converts MBTiles to PMTiles for deployments that prefer static file hosting over tileserver-gl.

---

## Client-Side Dependencies

These libraries are used by applications consuming tiles from the OXOT Tileserver. They are not part of the tileserver itself but are documented here for integration reference.

| Technology | Version | License | Purpose |
|------------|---------|---------|---------|
| **MapLibre GL JS** | 4.x | BSD-3-Clause | Primary vector tile rendering library for web applications |
| **Leaflet** | 1.9+ | BSD-2-Clause | Alternative map library with vector tile plugin |
| **OpenLayers** | 9.x | BSD-2-Clause | Alternative map library with MVT support |

MapLibre GL JS is the recommended client. It provides hardware-accelerated vector tile rendering, full style specification support, and the richest interaction model (hover, click, filter, 3D terrain). See [MapLibre GL JS Integration](06a-MAPLIBRE.md) for implementation details.

---

## Build Tool Versions in Dockerfile.converter

The converter Dockerfile installs specific tool versions to ensure reproducible builds:

```dockerfile
# Dockerfile.converter (key sections)
FROM ubuntu:24.04

# System packages
RUN apt-get update && apt-get install -y \
    curl jq sqlite3 \
    gdal-bin \
    osmium-tool \
    build-essential libsqlite3-dev zlib1g-dev

# Tippecanoe (built from source for latest features)
RUN git clone https://github.com/felt/tippecanoe.git /tmp/tippecanoe && \
    cd /tmp/tippecanoe && \
    make -j$(nproc) && \
    make install

# PMTiles CLI
RUN curl -L https://github.com/protomaps/go-pmtiles/releases/download/v3.2.0/go-pmtiles_3.2.0_Linux_x86_64.tar.gz | \
    tar -xz -C /usr/local/bin pmtiles

# Node.js (for helper scripts)
RUN curl -fsSL https://deb.nodesource.com/setup_20.x | bash - && \
    apt-get install -y nodejs
```

---

## License Summary

All technologies used in the OXOT Tileserver are available under permissive open-source licenses. No proprietary dependencies exist.

| License | Technologies |
|---------|-------------|
| **BSD-2-Clause** | tileserver-gl, tippecanoe, Leaflet, OpenLayers |
| **BSD-3-Clause** | pmtiles, MapLibre GL JS |
| **Apache 2.0** | Docker Engine, Docker Compose |
| **MIT** | GDAL/ogr2ogr, curl, jq, Node.js |
| **GPL-3.0** | osmium-tool (build-time only, not linked into runtime) |
| **Public domain** | sqlite3 |

The GPL-3.0 license on osmium-tool applies only to the converter container, which is a standalone tool invoked as a subprocess. It does not impose licensing requirements on the tileserver or consuming applications.

---

## Why These Tools?

The selection criteria for every tool in the stack:

1. **Open source** -- No vendor lock-in, no license fees, auditable code
2. **Proven at scale** -- Used in production by organizations handling planetary-scale geospatial data
3. **Active maintenance** -- Regular releases, responsive issue tracking, community support
4. **Docker-friendly** -- Clean installation in container environments, no GUI dependencies
5. **Standards compliance** -- Implements open specifications (TileJSON, MVT, MapLibre GL style spec, GeoJSON)

---

## Next Steps

- [System Requirements](01c-REQUIREMENTS.md) -- hardware and software prerequisites
- [Architecture & Components](01a-ARCHITECTURE.md) -- how these tools fit together
- [Converter Container](03c-CONVERTER.md) -- detailed converter build instructions

---

*[Home](INDEX.md) > [System Overview](01-OVERVIEW.md) > Technology Stack*
