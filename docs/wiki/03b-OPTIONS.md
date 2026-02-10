# Installation Options A-E

> **Last Updated**: 2026-02-11 01:00 UTC

[Home](INDEX.md) · [Installation](03-INSTALLATION.md) · Installation Options A-E

---

## Overview

The OXOT Tileserver provides five pre-configured installation options. Each option bundles a specific set of data sources tuned for a particular use case, balancing download size, processing time, and geographic/thematic coverage.

All options use the same pipeline: download raw data, convert to vector tiles, and load into tileserver-gl. The option scripts in `options/` automate this entire sequence.

---

## Quick Comparison

| Option | Name | Sources | Disk | Download | Convert | Total | Regions |
|---|---|---|---|---|---|---|---|
| **A** | Quick Start | 3 | ~5 GB | ~20 min | ~20 min | ~40 min | Global (basemap) + 3 regions (infra) |
| **B** | US Federal Authority | 5 | ~10 GB | ~1.5 hrs | ~1.5 hrs | ~3 hrs | US only |
| **C** | Modern + Comprehensive | 4 | ~16 GB | ~3 hrs | ~2 hrs | ~5 hrs | Global (basemap) + US detail |
| **D** | Minimum Viable OXOT | 2 | ~8 GB | ~45 min | ~45 min | ~1.5 hrs | US only |
| **E** | Multi-Region Full | 6 | ~22 GB | ~3.5 hrs | ~2.5 hrs | ~6 hrs | Europe + N. America + AU/NZ |

Times are approximate and depend on internet speed and CPU performance. Download times assume a 50 Mbps connection.

---

## Option A: Quick Start

**Best for**: Demos, proof-of-concept, visual testing.

**Estimated size**: ~5 GB | **Estimated time**: ~40 minutes

### Sources

| Source | Description | Layer Types |
|---|---|---|
| Protomaps Basemap | Regional PMTiles extracts for 3 regions | Roads, buildings, land use, water |
| OSM Infrastructure | Geofabrik PBF filtered to power/water/telecom tags | Lines, points, polygons |
| Natural Earth | Populated places and urban areas (1:10m) | Points, polygons |

### What You Get

A global basemap with infrastructure overlays for power lines, substations, generators, telecom masts, water treatment plants, and pipelines across Europe, North America, and Australia/Oceania. Natural Earth provides city labels at lower zoom levels.

### How to Run

```bash
./options/option-a.sh
```

Or manually:

```bash
docker compose --profile tools run converter /scripts/download.sh --option a
docker compose --profile tools run converter /scripts/convert.sh --option a
./scripts/load.sh
```

---

## Option B: US Federal Authority

**Best for**: US-focused CISA critical infrastructure analysis, federal authority data only.

**Estimated size**: ~10 GB | **Estimated time**: ~3 hours

### Sources

| Source | Description | Layer Types |
|---|---|---|
| US Census TIGER/Line 2024 | State, county, and tract boundaries + ACS demographics | Polygons |
| HIFLD Infrastructure | Transmission lines, hospitals, fire stations, schools | Lines, points |
| EIA Power Plants | US generating facilities with capacity and fuel type | Points |
| NID Dams | National Inventory of Dams (92,000+ structures) | Points |
| EPA SDWIS | Community water system service area boundaries | Polygons |

Note: NID and EPA data require manual download. The download script prints instructions for these sources.

### What You Get

A US-centric dataset aligned with CISA critical infrastructure sectors. Census tract boundaries enable demographic overlay analysis. No basemap is included -- pair with an external tile source or add Option A sources later for a basemap.

### How to Run

```bash
./options/option-b.sh
```

---

## Option C: Modern + Comprehensive

**Best for**: Production deployments needing a global basemap plus detailed US infrastructure and demographics.

**Estimated size**: ~16 GB | **Estimated time**: ~5 hours

### Sources

| Source | Description | Layer Types |
|---|---|---|
| Protomaps Basemap | Regional PMTiles extracts for 3 regions | Roads, buildings, land use, water |
| OSM Infrastructure | Geofabrik PBF filtered to power/water/telecom tags | Lines, points, polygons |
| US Census TIGER/Line 2024 | State, county, and tract boundaries + ACS demographics | Polygons |
| HIFLD Infrastructure | Transmission lines, hospitals, fire stations, schools | Lines, points |

### What You Get

Combines Option A's global basemap and OSM infrastructure with Option B's Census and HIFLD data (minus NID, EPA, and EIA). This gives you a complete visual context with US infrastructure detail.

### How to Run

```bash
./options/option-c.sh
```

---

## Option D: Minimum Viable OXOT

**Best for**: Fastest path to CISA-aligned infrastructure data. Useful when you already have a basemap from another source.

**Estimated size**: ~8 GB | **Estimated time**: ~1.5 hours

### Sources

| Source | Description | Layer Types |
|---|---|---|
| HIFLD Infrastructure | Transmission lines, hospitals, fire stations, schools | Lines, points |
| US Census TIGER/Line 2024 | State, county, and tract boundaries + ACS demographics | Polygons |

### What You Get

The two highest-value US datasets for OXOT digital twin integration. HIFLD provides multi-sector critical infrastructure points and lines. Census provides the geographic boundary framework and demographic context. No basemap, no international data.

### How to Run

```bash
./options/option-d.sh
```

---

## Option E: Multi-Region Full

**RECOMMENDED** for production deployments.

**Best for**: Full 3-region coverage with basemap, infrastructure, demographics, and city labels across Europe, North America, and Australia/New Zealand.

**Estimated size**: ~22 GB | **Estimated time**: ~6 hours

### Sources

| Source | Description | Layer Types |
|---|---|---|
| Protomaps Basemap | Regional PMTiles extracts for 3 regions | Roads, buildings, land use, water |
| OSM Infrastructure | Geofabrik PBF filtered to power/water/telecom tags | Lines, points, polygons |
| GeoNames cities15000 | 25,000+ cities worldwide with population | Points |
| Eurostat NUTS3 | European statistical regions | Polygons |
| US Census TIGER/Line 2024 | State, county, and tract boundaries | Polygons |
| ABS Census Boundaries | Australian SA2/SA3/SA4 statistical areas | Polygons |

Note: ABS data requires manual download from the Australian Bureau of Statistics website. The download script prints instructions.

### What You Get

The most complete dataset the tileserver supports. All three target regions have basemap context, infrastructure overlays, demographic boundaries, and city labels. This is the recommended option for production OXOT deployments.

### How to Run

```bash
./options/option-e.sh
```

---

## Source-to-Option Matrix

This table shows which sources are included in each option.

| Source | A | B | C | D | E |
|---|---|---|---|---|---|
| Protomaps Basemap | yes | -- | yes | -- | yes |
| OSM Infrastructure | yes | -- | yes | -- | yes |
| Natural Earth | yes | -- | -- | -- | -- |
| US Census TIGER/Line | -- | yes | yes | yes | yes |
| HIFLD Infrastructure | -- | yes | yes | yes | -- |
| EIA Power Plants | -- | yes | -- | -- | -- |
| NID Dams | -- | yes | -- | -- | -- |
| EPA SDWIS | -- | yes | -- | -- | -- |
| GeoNames cities15000 | -- | -- | -- | -- | yes |
| Eurostat NUTS3 | -- | -- | -- | -- | yes |
| ABS Australia | -- | -- | -- | -- | yes |

---

## Mixing Options

Options are additive because the download and convert scripts skip sources that already exist on disk.

### Adding sources to an existing installation

If you installed Option D and later want to add a basemap and OSM infrastructure (from Option A):

```bash
docker compose --profile tools run converter /scripts/download.sh --source basemap --source osm-infrastructure --source natural-earth
docker compose --profile tools run converter /scripts/convert.sh --source basemap --source osm-infrastructure --source natural-earth
./scripts/load.sh
```

### Running a second option after the first

```bash
# Already installed Option B
./options/option-a.sh
# download.sh skips sources already present; convert.sh skips existing tiles
```

The only exception is the `--force` flag on `convert.sh`, which overwrites existing tile files. The option scripts do not use `--force` by default.

### Removing sources

Delete the tile file from `data/tiles/` and restart the tileserver:

```bash
rm data/tiles/natural-earth-places.mbtiles
docker compose restart tileserver
```

---

## Output Tile Files by Option

| Option | Tile Files Generated |
|---|---|
| A | `europe.pmtiles`, `north-america.pmtiles`, `australia-nz.pmtiles`, `osm-infrastructure.mbtiles`, `natural-earth-places.mbtiles` |
| B | `demographics-us.mbtiles`, `hifld-infrastructure.mbtiles`, `eia-powerplants.mbtiles`, `nid-dams.mbtiles`, `epa-water.mbtiles` |
| C | `europe.pmtiles`, `north-america.pmtiles`, `australia-nz.pmtiles`, `osm-infrastructure.mbtiles`, `demographics-us.mbtiles`, `hifld-infrastructure.mbtiles` |
| D | `hifld-infrastructure.mbtiles`, `demographics-us.mbtiles` |
| E | `europe.pmtiles`, `north-america.pmtiles`, `australia-nz.pmtiles`, `osm-infrastructure.mbtiles`, `geonames-cities.mbtiles`, `demographics-europe.mbtiles`, `demographics-us.mbtiles`, `demographics-australia.mbtiles` |

---

## Related Pages

- [Installation](03-INSTALLATION.md) -- parent page with prerequisites and quick start
- [Docker Deployment](03a-DOCKER-SETUP.md) -- container architecture
- [Data Sources](02-DATA-SOURCES.md) -- detailed documentation for each source
- [Download Scripts](04a-DOWNLOAD.md) -- how the download stage works
- [Conversion and Tippecanoe](04c-CONVERT.md) -- how raw data becomes tiles

---

*[Back to Installation](03-INSTALLATION.md)*
