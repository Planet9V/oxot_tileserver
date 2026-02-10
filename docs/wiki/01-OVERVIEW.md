# System Overview

> **Last Updated**: 2026-02-11 01:00 UTC

[Home](INDEX.md)

---

## What is the OXOT Tileserver?

The OXOT Tileserver is a self-contained vector tile server that provides geographic visualization of critical infrastructure across Europe, North America, and Australia/New Zealand. It runs entirely within your network perimeter as a Docker-deployed service, requiring no external tile providers or third-party map APIs at runtime.

The system ingests data from 21 authoritative geospatial sources -- government agencies, open data platforms, and international organizations -- transforms that data into optimized vector tiles, and serves them over a standard REST API compatible with any MapLibre GL JS, Leaflet, or OpenLayers client.

---

## The Problem It Solves

Organizations responsible for critical infrastructure face a common visualization challenge:

1. **Data fragmentation** -- Electric grid data comes from EIA and ENTSO-E, water systems from EPA and EEA, demographics from Census Bureau and Eurostat, telecoms from regulatory filings and OSM. Each source has different formats, projections, update cycles, and access methods.

2. **External dependency** -- Commercial tile services (Mapbox, Google Maps) require internet connectivity, ongoing subscription fees, and transmit queries about infrastructure locations to third parties.

3. **Scale mismatch** -- Displaying a single substation on a world map requires data at multiple zoom levels, from country-level overview down to facility-level detail. Raster tile approaches produce enormous datasets; vector tiles solve this through client-side rendering.

4. **Operational isolation** -- Security-sensitive environments need map services that operate within air-gapped or restricted networks without phoning home.

The OXOT Tileserver eliminates these problems by consolidating all data acquisition, transformation, and serving into a reproducible Docker pipeline that produces a single, portable tile service.

---

## Key Capabilities

### 21 Data Sources Across 4 Domains

| Domain | Sources | Coverage |
|--------|---------|----------|
| **Demographics** | US Census TIGER/Line + ACS, Eurostat NUTS, ABS (Australia), Stats NZ, GeoNames | Global cities; boundaries for US, EU, AU, NZ |
| **Electric Grid** | OSM power tags, EIA Energy Atlas, HIFLD, ENTSO-E / GridKit, Geoscience Australia | Power lines, substations, generators across all target regions |
| **Water** | OSM water tags, EPA SDWIS + WATERS, EEA WISE, NID (Dams), BoM Australia | Treatment plants, distribution systems, dams, watersheds |
| **Telecoms** | OSM telecom tags, regulatory datasets | Cell towers, exchanges, fiber routes |
| **Basemap** | OpenStreetMap, Natural Earth | Roads, buildings, land use, political boundaries |

### 5 Installation Options

| Option | Scope | Approx. Disk | Use Case |
|--------|-------|-------------|----------|
| **A** | Basemap only | 2 GB | Development, UI prototyping |
| **B** | Basemap + one region | 8 GB | Single-country deployment |
| **C** | Basemap + one domain (all regions) | 12 GB | Domain-specific analysis |
| **D** | Basemap + multiple domains + regions | 25 GB | Multi-domain operational use |
| **E** | Full dataset (all sources, all regions) | 40 GB | Complete infrastructure visualization |

### Automated Data Pipeline

The pipeline is fully scripted and runs inside the converter container:

```
download.sh  -->  extract-osm.sh  -->  convert.sh  -->  verify.sh
  (fetch raw)     (filter tags)       (tippecanoe)     (check tiles)
```

Each stage is idempotent. Re-running a stage skips already-processed files. The pipeline supports selective execution by source, domain, or region.

### Standards-Based API

The tileserver exposes:

- **TileJSON** metadata at `/data/<tileset>.json`
- **Vector tiles** in PBF format at `/data/<tileset>/{z}/{x}/{y}.pbf`
- **Style JSON** at `/styles/<style>/style.json`
- **Raster preview** tiles at `/styles/<style>/{z}/{x}/{y}.png`
- **Health endpoint** at `/health`

Any client that speaks the MapLibre GL style specification can consume these tiles without modification.

---

## Component Architecture

The system consists of two Docker containers sharing a data volume:

```
+-------------------------------------------------------------------+
|                        Docker Host                                 |
|                                                                    |
|  +-----------------------------+   +---------------------------+   |
|  |   tileserver-gl             |   |   converter               |   |
|  |   (runtime)                 |   |   (tools profile)         |   |
|  |                             |   |                           |   |
|  |   - Serves vector tiles     |   |   - tippecanoe            |   |
|  |   - REST API on :8080       |   |   - osmium-tool           |   |
|  |   - Style rendering         |   |   - ogr2ogr / GDAL        |   |
|  |   - TileJSON metadata       |   |   - pmtiles CLI           |   |
|  |   - Health monitoring       |   |   - download scripts      |   |
|  |                             |   |   - convert scripts       |   |
|  +-------------|---------------+   +-------------|-------------+   |
|                |                                 |                 |
|                +--------+    +-------------------+                 |
|                         |    |                                     |
|                   +-----|----|---------+                           |
|                   |     v    v         |                           |
|                   |   data volume      |                           |
|                   |                    |                           |
|                   |   data/            |                           |
|                   |   +-- raw/         |  <-- downloaded files     |
|                   |   +-- extracted/   |  <-- filtered GeoJSON     |
|                   |   +-- tiles/       |  <-- MBTiles / PMTiles    |
|                   |   +-- styles/      |  <-- MapLibre style JSON  |
|                   |   +-- config/      |  <-- tileserver config    |
|                   |                    |                           |
|                   +--------------------+                           |
+-------------------------------------------------------------------+
```

The **tileserver-gl** container is the long-running service. It reads tile files and configuration from the shared data volume and serves them over HTTP.

The **converter** container is an ephemeral, run-on-demand container used during data preparation. It contains all the geospatial tools needed to download, extract, and convert source data into vector tiles. Once conversion is complete, the converter container exits.

Both containers mount the same Docker volume at `/data`, providing a clean separation between the data pipeline (converter) and the serving layer (tileserver).

---

## Infrastructure Domains

### Electric Grid

Visualization of power generation, transmission, and distribution infrastructure. Sources include OSM power tags (global coverage with community-maintained detail), EIA Energy Atlas (US-specific authoritative data), HIFLD (US homeland infrastructure), ENTSO-E/GridKit (European transmission topology), and Geoscience Australia (Australian energy assets).

Typical layers: power lines (by voltage class), substations, power plants (by fuel type), solar farms, wind farms.

See: [Electric Grid](02c-ELECTRIC.md)

### Water Infrastructure

Visualization of water treatment, distribution, storage, and dam infrastructure. Sources include OSM water tags, EPA SDWIS (US drinking water systems), EPA WATERS (US watersheds), EEA WISE (European water monitoring), NID (US dam inventory), and Australian BoM water resources.

Typical layers: water treatment plants, pumping stations, reservoirs, dams (by hazard class), watersheds.

See: [Water Infrastructure](02d-WATER.md)

### Demographics and Population

Visualization of population density, administrative boundaries, and settlement patterns. Sources include US Census TIGER/Line with ACS demographic variables, Eurostat NUTS regions, ABS Australian census boundaries, Stats NZ geographic boundaries, and GeoNames global city data.

Typical layers: administrative boundaries (multi-level), population density choropleth, city points with population.

See: [Demographics & Population](02b-DEMOGRAPHICS.md)

### Telecoms

Visualization of telecommunications infrastructure including cell towers, telephone exchanges, and fiber optic routes extracted from OpenStreetMap and regulatory datasets.

See: [Telecoms Infrastructure](02e-TELECOMS.md)

---

## Children Pages

| Page | Description |
|------|-------------|
| [Architecture & Components](01a-ARCHITECTURE.md) | Detailed two-container architecture, data flow diagrams, file system layout, Docker networking, config structure |
| [Technology Stack](01b-STACK.md) | All technologies with versions, licenses, purpose, and selection rationale |
| [System Requirements](01c-REQUIREMENTS.md) | Hardware, software, disk space, and network prerequisites per installation option |

---

## Next Steps

- **Evaluating the system?** Continue to [Architecture & Components](01a-ARCHITECTURE.md) for the detailed design.
- **Ready to deploy?** Jump to [Installation & Setup](03-INSTALLATION.md).
- **Looking for a specific data source?** See the [Data Sources](02-DATA-SOURCES.md) catalog.
- **Integrating with an application?** Start with [MapLibre GL JS](06a-MAPLIBRE.md).

---

*[Home](INDEX.md) | [Architecture](01a-ARCHITECTURE.md) | [Stack](01b-STACK.md) | [Requirements](01c-REQUIREMENTS.md)*
