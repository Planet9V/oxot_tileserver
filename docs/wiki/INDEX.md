# OXOT Tileserver Documentation

> **Last Updated**: 2026-02-11 02:00 UTC

---

## Introduction

The OXOT Tileserver is a self-contained, Docker-deployed vector tile server purpose-built for critical infrastructure visualization. It aggregates geospatial data from 21 authoritative sources across four infrastructure domains -- electric grid, water systems, demographics, and telecommunications -- and serves them as high-performance vector tiles to any standards-compliant map client.

The system targets three geographic regions:

- **North America** -- US Census TIGER/Line boundaries, EIA energy atlas, EPA water systems, HIFLD infrastructure, and CISA-aligned sector data
- **Europe** -- Eurostat NUTS regions, ENTSO-E transmission grids, EEA water quality monitoring, and OpenStreetMap power infrastructure
- **Australia / New Zealand** -- ABS census boundaries, Geoscience Australia energy assets, Bureau of Meteorology water data, and Stats NZ geographic boundaries

All data is downloaded, extracted, converted to vector tiles, and served through a two-container Docker architecture. No external tile services are required at runtime. The system operates entirely within your network perimeter.

---

## Quick Start

Complete these four steps to have a running tileserver in under 30 minutes.

### Step 1: Clone and configure

```bash
git clone <repository-url> oxot_tileserver
cd oxot_tileserver
cp .env.example .env
# Edit .env to set CENSUS_API_KEY (optional, for ACS data)
```

### Step 2: Build containers

```bash
docker compose build
```

This builds two images: the runtime `tileserver-gl` container and the `converter` container with all data-processing tools (tippecanoe, osmium-tool, ogr2ogr/GDAL, pmtiles CLI).

### Step 3: Download and convert data

```bash
# Option A: Full dataset (~40 GB raw, ~8 GB tiles)
docker compose run converter ./scripts/download.sh --all
docker compose run converter ./scripts/convert.sh --all

# Option B: Minimal (basemap + one region)
docker compose run converter ./scripts/download.sh --basemap --region us
docker compose run converter ./scripts/convert.sh --basemap --region us
```

See [Installation Options A-E](03b-OPTIONS.md) for the full menu of installation profiles.

### Step 4: Start the tileserver

```bash
docker compose up -d tileserver
# Verify at http://localhost:8080
```

The tileserver exposes a REST API on port 8080 serving TileJSON metadata, vector tiles in PBF format, and styled raster previews.

---

## Quick Navigation

| Section | Page | Description |
|---------|------|-------------|
| 01 | [System Overview](01-OVERVIEW.md) | What the system does, why it exists, high-level capabilities |
| 01a | [Architecture & Components](01a-ARCHITECTURE.md) | Two-container architecture, data flow, file layout |
| 01b | [Technology Stack](01b-STACK.md) | All technologies, versions, licenses, rationale |
| 01c | [System Requirements](01c-REQUIREMENTS.md) | Hardware, software, disk, network prerequisites |
| 02 | [Data Sources](02-DATA-SOURCES.md) | Catalog of all 21 data sources across 4 domains |
| 02a | [Basemap Sources](02a-BASEMAP.md) | OpenStreetMap, Natural Earth, and land cover |
| 02b | [Demographics & Population](02b-DEMOGRAPHICS.md) | Census, Eurostat, ABS, Stats NZ, GeoNames |
| 02b1 | [US Census TIGER/Line + ACS](02b1-CENSUS-US.md) | US state/county/tract boundaries and ACS variables |
| 02b2 | [Eurostat NUTS + Nuts2json](02b2-EUROSTAT.md) | European NUTS regions at multiple resolutions |
| 02b3 | [ABS Census Boundaries](02b3-ABS-AUSTRALIA.md) | Australian SA1-SA4 and LGA boundaries |
| 02b4 | [Stats NZ Boundaries](02b4-STATS-NZ.md) | New Zealand meshblock and area unit data |
| 02b5 | [GeoNames Cities](02b5-GEONAMES.md) | Global city point data with population |
| 02c | [Electric Grid](02c-ELECTRIC.md) | Power lines, substations, generation facilities |
| 02c1 | [OSM Power Infrastructure](02c1-OSM-POWER.md) | OpenStreetMap power=* tag extraction |
| 02c2 | [EIA US Energy Atlas](02c2-EIA.md) | US power plants, transmission lines, substations |
| 02c3 | [HIFLD Open Data](02c3-HIFLD.md) | Homeland Infrastructure Foundation-Level Data |
| 02c4 | [ENTSO-E / GridKit](02c4-ENTSOE.md) | European transmission network topology |
| 02c5 | [Geoscience Australia](02c5-GEOSCIENCE-AU.md) | Australian energy infrastructure assets |
| 02d | [Water Infrastructure](02d-WATER.md) | Treatment plants, distribution, dams, waterways |
| 02d1 | [OSM Water Tags](02d1-OSM-WATER.md) | OpenStreetMap water infrastructure extraction |
| 02d2 | [EPA SDWIS + WATERS](02d2-EPA-SDWIS.md) | US drinking water systems and watershed data |
| 02d3 | [EEA WISE](02d3-EEA-WISE.md) | European water information system |
| 02d4 | [National Inventory of Dams](02d4-NID-DAMS.md) | US Army Corps dam inventory |
| 02d5 | [Australian BoM Water](02d5-BOM-AUSTRALIA.md) | Bureau of Meteorology water resources |
| 02e | [Telecoms Infrastructure](02e-TELECOMS.md) | Cell towers, exchanges, fiber routes |
| 03 | [Installation & Setup](03-INSTALLATION.md) | Getting started with deployment |
| 03a | [Docker Deployment](03a-DOCKER-SETUP.md) | Docker Compose configuration and setup |
| 03b | [Installation Options A-E](03b-OPTIONS.md) | Five installation profiles by scope and size |
| 03c | [Converter Container](03c-CONVERTER.md) | Build tools container with tippecanoe and GDAL |
| 03d | [Environment Configuration](03d-ENVIRONMENT.md) | Environment variables and .env reference |
| 04 | [Data Pipeline](04-PIPELINE.md) | End-to-end download, extract, convert, load |
| 04a | [Download Scripts](04a-DOWNLOAD.md) | Source-specific download automation |
| 04b | [OSM Extraction](04b-EXTRACT.md) | Osmium filtering and tag extraction |
| 04c | [Conversion & Tippecanoe](04c-CONVERT.md) | GeoJSON to MBTiles/PMTiles conversion |
| 04d | [Loading & Verification](04d-LOAD.md) | Tile verification and tileserver config |
| 04e | [Updates & Scheduling](04e-MAINTENANCE.md) | Cron-based update automation |
| 05 | [API Reference](05-API.md) | Complete REST API documentation |
| 05a | [REST API Endpoints](05a-REST-ENDPOINTS.md) | All HTTP endpoints with examples |
| 05b | [TileJSON Metadata](05b-TILEJSON.md) | TileJSON spec and response format |
| 05c | [Vector Tile Format](05c-VECTOR-TILES.md) | PBF encoding, layers, properties |
| 05d | [Style API](05d-STYLES.md) | MapLibre style spec integration |
| 06 | [Application Integration](06-INTEGRATION.md) | Connecting map clients to tileserver |
| 06a | [MapLibre GL JS](06a-MAPLIBRE.md) | Primary client integration guide |
| 06b | [Leaflet Integration](06b-LEAFLET.md) | Leaflet with vector tile plugin |
| 06c | [OpenLayers Integration](06c-OPENLAYERS.md) | OpenLayers vector tile source |
| 06d | [OXOT Cyber DT Integration](06d-OXOT-CYBERDT.md) | Connecting to the OXOT digital twin |
| 06e | [Custom Application Guide](06e-CUSTOM-APPS.md) | Building your own tile consumer |
| 07 | [Custom Tile Creation](07-CUSTOM-TILES.md) | Creating bespoke tile layers |
| 07a | [GeoJSON Authoring](07a-GEOJSON-AUTHORING.md) | Writing and validating GeoJSON |
| 07b | [Per-Customer Facility Layers](07b-CUSTOMER-LAYERS.md) | Customer-specific facility overlays |
| 07c | [Equipment & Fixed Asset Layers](07c-EQUIPMENT-LAYERS.md) | Equipment BOM to map layer pipeline |
| 07d | [Custom Layer Styling](07d-STYLING.md) | Paint and layout properties |
| 07e | [Map Cards & Popups](07e-CARDS-DISPLAY.md) | Interactive feature display |
| 08 | [Operations & Maintenance](08-OPERATIONS.md) | Running the system in production |
| 08a | [Health & Monitoring](08a-MONITORING.md) | Health checks and alerting |
| 08b | [Troubleshooting Guide](08b-TROUBLESHOOTING.md) | Common issues and resolutions |
| 08c | [Performance Tuning](08c-PERFORMANCE.md) | Cache, concurrency, tile optimization |
| 08d | [Backup & Restore](08d-BACKUP-RESTORE.md) | Data and configuration backup |
| 09 | [Glossary of Terms](09-GLOSSARY.md) | Definitions for domain terminology |
| 10 | [References & Citations](10-REFERENCES.md) | APA-formatted source bibliography |
| 11 | [Changelog](11-CHANGELOG.md) | Version history and release notes |
| **13** | **[Use Cases & Implementation](13-USE-CASES.md)** | **Operational use case catalog with implementation guidance** |
| 13a | [Cyber Attack Origin & Destination](13a-CYBER-ATTACK-MAPPING.md) | Mapping attack traffic with GeoIP and arc layers |
| 13a1 | [IP Address Geolocation](13a1-IP-GEOLOCATION.md) | GeoLite2, GeoIP2, IP2Location lookup pipelines |
| 13a2 | [Threat Intelligence Feeds](13a2-THREAT-INTELLIGENCE-FEEDS.md) | OTX, MISP, GreyNoise, AbuseIPDB integration |
| 13b | [Facility & Building Location](13b-FACILITY-BUILDING-LOCATION.md) | ML building footprints and Overture Maps |
| 13c | [Socioeconomic & Demographic Analysis](13c-SOCIOECONOMIC-ANALYSIS.md) | CDC SVI, census choropleth, population density |
| 13d | [Geopolitical Events & News](13d-GEOPOLITICAL-EVENTS.md) | GDELT, ACLED, geocoded news overlays |
| 13d1 | [Natural Hazard Overlays](13d1-NATURAL-HAZARDS.md) | USGS earthquakes, FIRMS fires, FEMA flood zones |
| 13e | [Supply Chain Visualization](13e-SUPPLY-CHAIN-MAPPING.md) | UN Comtrade, Sourcemap, vendor dependency mapping |
| 13e1 | [Shipping & Logistics](13e1-SHIPPING-ROUTES.md) | AIS vessel tracking, port data, route visualization |
| 13f | [Simulation & War Gaming](13f-SIMULATION-WARGAMING.md) | Tabletop exercises, blast-radius, turf.js analysis |
| 13g | [Additional Use Cases](13g-ADDITIONAL-USE-CASES.md) | Insurance, regulatory, fleet, environmental overlays |

---

## What's in This Wiki

This wiki is organized into eight major sections, plus supporting reference material.

### 01 -- System Overview

Introduces the OXOT Tileserver, its purpose, and its place within the broader OXOT digital twin ecosystem. Covers the high-level architecture, the technology stack, and the hardware and software prerequisites for deployment. Start here if you are evaluating the system or planning a deployment.

- [Architecture & Components](01a-ARCHITECTURE.md) -- two-container design, data flow, file system layout
- [Technology Stack](01b-STACK.md) -- tileserver-gl, tippecanoe, osmium, GDAL, Docker
- [System Requirements](01c-REQUIREMENTS.md) -- CPU, RAM, disk, network per installation option

### 02 -- Data Sources

Catalogs all 21 geospatial data sources organized into four infrastructure domains. Each source page documents the provider, update frequency, geographic coverage, license terms, download procedure, and conversion notes. This section is the authoritative reference for understanding what data the tileserver can serve.

- [Basemap Sources](02a-BASEMAP.md) -- OpenStreetMap, Natural Earth, land cover
- [Demographics & Population](02b-DEMOGRAPHICS.md) -- five sub-sources covering US, Europe, Australia, NZ, global
- [Electric Grid](02c-ELECTRIC.md) -- five sub-sources covering OSM, EIA, HIFLD, ENTSO-E, Geoscience AU
- [Water Infrastructure](02d-WATER.md) -- five sub-sources covering OSM, EPA, EEA, NID, BoM
- [Telecoms Infrastructure](02e-TELECOMS.md) -- cell towers, exchanges, fiber routes

### 03 -- Installation and Setup

Provides step-by-step deployment instructions for five installation profiles ranging from a minimal basemap-only deployment (Option A, approximately 2 GB) to a full multi-region deployment with all data sources (Option E, approximately 40 GB). Covers Docker configuration, the converter container build, and environment variable reference.

- [Docker Deployment](03a-DOCKER-SETUP.md) -- docker-compose.yml walkthrough
- [Installation Options A-E](03b-OPTIONS.md) -- scope, size, and use case for each option
- [Converter Container](03c-CONVERTER.md) -- Dockerfile.converter and included tools
- [Environment Configuration](03d-ENVIRONMENT.md) -- .env variable reference

### 04 -- Data Pipeline

Documents the automated pipeline that downloads raw data, extracts relevant features, converts them to vector tiles, and loads them into tileserver-gl. Each stage has its own page with script usage, configuration options, and troubleshooting notes.

- [Download Scripts](04a-DOWNLOAD.md) -- per-source download automation
- [OSM Extraction](04b-EXTRACT.md) -- osmium-tool tag filtering
- [Conversion & Tippecanoe](04c-CONVERT.md) -- GeoJSON to MBTiles with tippecanoe
- [Loading & Verification](04d-LOAD.md) -- tile inspection and config generation
- [Updates & Scheduling](04e-MAINTENANCE.md) -- cron-based refresh automation

### 05 -- API Reference

Complete REST API documentation for tileserver-gl. Covers tile endpoints, TileJSON metadata, vector tile format specification, and the style API. Each endpoint is documented with URL pattern, parameters, response format, and curl examples.

- [REST API Endpoints](05a-REST-ENDPOINTS.md) -- GET routes with parameters
- [TileJSON Metadata](05b-TILEJSON.md) -- metadata response schema
- [Vector Tile Format](05c-VECTOR-TILES.md) -- PBF encoding and layer schema
- [Style API](05d-STYLES.md) -- MapLibre GL style JSON serving

### 06 -- Application Integration

Guides for connecting front-end map clients to the tileserver. Includes working code examples for MapLibre GL JS (the primary client), Leaflet, and OpenLayers, plus dedicated integration instructions for the OXOT Cyber Digital Twin application.

- [MapLibre GL JS](06a-MAPLIBRE.md) -- primary integration with full examples
- [Leaflet Integration](06b-LEAFLET.md) -- leaflet-maplibre-gl plugin
- [OpenLayers Integration](06c-OPENLAYERS.md) -- ol-mapbox-style bridge
- [OXOT Cyber DT Integration](06d-OXOT-CYBERDT.md) -- digital twin map layer
- [Custom Application Guide](06e-CUSTOM-APPS.md) -- building a bespoke consumer

### 07 -- Custom Tile Creation

Instructions for creating bespoke tile layers beyond the standard data sources. Covers GeoJSON authoring, per-customer facility overlays, equipment and fixed asset layers derived from the OXOT equipment BOM, custom styling, and interactive map cards.

- [GeoJSON Authoring](07a-GEOJSON-AUTHORING.md) -- creating and validating GeoJSON
- [Per-Customer Facility Layers](07b-CUSTOMER-LAYERS.md) -- customer-specific overlays
- [Equipment & Fixed Asset Layers](07c-EQUIPMENT-LAYERS.md) -- BOM-to-tile pipeline
- [Custom Layer Styling](07d-STYLING.md) -- paint and layout property reference
- [Map Cards & Popups](07e-CARDS-DISPLAY.md) -- interactive feature popups

### 08 -- Operations and Maintenance

Production operations guidance including health monitoring, troubleshooting, performance tuning, and backup/restore procedures.

- [Health & Monitoring](08a-MONITORING.md) -- health endpoint and alerting
- [Troubleshooting Guide](08b-TROUBLESHOOTING.md) -- symptom-to-solution lookup
- [Performance Tuning](08c-PERFORMANCE.md) -- caching, concurrency, tile size
- [Backup & Restore](08d-BACKUP-RESTORE.md) -- data and config preservation

### 13 -- Use Cases and Implementation

Catalogs eight categories of operational use cases that demonstrate how the OXOT Tileserver serves real-world cybersecurity, risk management, and infrastructure analysis workflows. Each use case page documents the data sources, integration architecture, visualization approach, and implementation steps.

- [Cyber Attack Origin & Destination](13a-CYBER-ATTACK-MAPPING.md) -- mapping attack traffic using GeoIP resolution and deck.gl arc layers to visualize source-to-destination connections
- [IP Address Geolocation](13a1-IP-GEOLOCATION.md) -- GeoLite2, GeoIP2, and IP2Location lookup pipelines for resolving IP addresses to geographic coordinates
- [Threat Intelligence Feeds](13a2-THREAT-INTELLIGENCE-FEEDS.md) -- integrating OTX, MISP, GreyNoise, AbuseIPDB, and Shodan feeds as real-time map overlays
- [Facility & Building Location](13b-FACILITY-BUILDING-LOCATION.md) -- Microsoft Global ML Building Footprints and Overture Maps for identifying and mapping physical facilities
- [Socioeconomic & Demographic Analysis](13c-SOCIOECONOMIC-ANALYSIS.md) -- CDC Social Vulnerability Index, census choropleth maps, and population density layers for risk context
- [Geopolitical Events & News](13d-GEOPOLITICAL-EVENTS.md) -- GDELT and ACLED geocoded event data for monitoring political violence, protests, and news near critical infrastructure
- [Natural Hazard Overlays](13d1-NATURAL-HAZARDS.md) -- USGS earthquake feeds, NASA FIRMS fire detections, and FEMA flood zone polygons
- [Supply Chain Visualization](13e-SUPPLY-CHAIN-MAPPING.md) -- UN Comtrade trade flows, Sourcemap open supply chains, and vendor dependency mapping
- [Shipping & Logistics](13e1-SHIPPING-ROUTES.md) -- AIS vessel tracking, World Port Index data, and shipping route visualization
- [Simulation & War Gaming](13f-SIMULATION-WARGAMING.md) -- tabletop exercise support, blast-radius modeling with turf.js, and scenario playback
- [Additional Use Cases](13g-ADDITIONAL-USE-CASES.md) -- insurance risk overlays, regulatory boundary mapping, fleet tracking, and environmental monitoring

---

## Target Audience

This documentation serves four primary audiences:

| Audience | Starting Point | Key Sections |
|----------|---------------|--------------|
| **DevOps / Infrastructure** | [Installation & Setup](03-INSTALLATION.md) | 03, 04, 08 |
| **Front-End Developers** | [Application Integration](06-INTEGRATION.md) | 05, 06, 07 |
| **Data Engineers** | [Data Sources](02-DATA-SOURCES.md) | 02, 04 |
| **Project Evaluators** | [System Overview](01-OVERVIEW.md) | 01, 09, 10 |

---

## Conventions Used in This Wiki

- **Code blocks** contain exact commands or configuration snippets that can be copied and executed.
- **File paths** are relative to the repository root unless otherwise noted.
- **Port numbers** default to 8080 for tileserver-gl; override via `.env`.
- **Data sizes** are approximate and vary by geographic region and source version.
- All data sources are documented with their license terms. Consult [References & Citations](10-REFERENCES.md) for the full bibliography.

---

## Related Resources

- [OXOT Cyber Digital Twin](https://github.com/oxot) -- the parent platform consuming tile data
- [tileserver-gl Documentation](https://tileserver.readthedocs.io/) -- upstream tileserver-gl reference
- [MapLibre GL JS](https://maplibre.org/maplibre-gl-js/docs/) -- primary front-end map client
- [Tippecanoe](https://github.com/felt/tippecanoe) -- vector tile generation tool

---

*Generated for OXOT Tileserver v1.1 -- Last updated 2026-02-11 02:00 UTC*
