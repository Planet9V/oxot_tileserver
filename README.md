# OXOT Tileserver

## Overview

Self-contained Docker deployment of tileserver-gl with automated data pipelines for critical infrastructure visualization. Serves vector tiles for demographics, electric grid, water infrastructure, and telecoms across Europe, North America, Australia, and New Zealand.

## Quick Start

```bash
git clone https://github.com/Planet9V/oxot_tileserver.git
cd oxot_tileserver
cp .env.example .env
# Choose an option (A through E)
./options/option-e.sh    # Full multi-region build
docker compose up -d
# Access at http://localhost:8080
```

## Architecture

- tileserver-gl container (port 8080) -- serves .mbtiles and .pmtiles
- converter container -- has osmium, tippecanoe, ogr2ogr, pmtiles CLI for data processing
- data/tiles/ -- generated tile files auto-discovered by tileserver
- data/raw/ -- downloaded source data (intermediate, can be deleted after conversion)

## Data Sources

### Basemap (Cities, Places, Names, Roads, Buildings)

| Source | Coverage | Format | Size | Native? |
|--------|----------|--------|------|---------|
| Protomaps Basemap | Global | PMTiles | ~120 GB planet; ~15 GB 3-region extract | YES -- drop in |
| OpenMapTiles / MapTiler | Global | MBTiles | ~80 GB planet or country extracts | YES -- drop in |
| OpenFreeMap | Global | MBTiles | ~80 GB planet (weekly builds) | YES -- drop in |

### Demographics / Population

| Source | Coverage | What You Get | Format | Size | Conversion |
|--------|----------|-------------|--------|------|------------|
| US Census TIGER/Line + ACS | United States | Tracts, block groups, zip codes + population, income, housing, age, race | Shapefile + CSV | ~15 GB raw -> ~5 GB tiles | ogr2ogr -> tippecanoe |
| Eurostat NUTS + Nuts2json | Europe | NUTS 0/1/2/3 regions + population, GDP, employment | GeoJSON, GeoPackage | ~2 GB raw -> ~1 GB tiles | tippecanoe |
| ABS Census Boundaries | Australia | SA1/SA2/SA3/SA4 + census data | Shapefile, GeoPackage | ~1 GB raw -> ~500 MB tiles | ogr2ogr -> tippecanoe |
| Stats NZ Geographic Boundaries | New Zealand | Meshblocks, area units + census | Shapefile, GeoJSON | ~500 MB raw | ogr2ogr -> tippecanoe |
| GeoNames cities15000 | Global | 25,000+ cities with population | TSV (1.5 MB) | ~20 MB tiles | awk -> tippecanoe |
| Natural Earth Populated Places | Global | ~7,300 cities with population (coarse) | Shapefile | ~50 MB | ogr2ogr -> tippecanoe |
| WorldPop | Global | 100m population grid raster (2015-2030) | GeoTIFF | ~10 GB/continent | gdal2tiles (raster) |

### Electric Grid

| Source | Coverage | What You Get | Format | Size | Conversion |
|--------|----------|-------------|--------|------|------------|
| OSM via Geofabrik (power tags) | Global | Power lines (7M+ km), substations (1M+), generators (125K+) | PBF -> GeoJSON | 50 GB raw -> ~500 MB tiles | osmium -> ogr2ogr -> tippecanoe |
| EIA US Energy Atlas | United States | Power plants >=1 MW (fuel, capacity, owner), transmission lines | Shapefile, GeoJSON | ~200 MB raw -> ~100 MB tiles | ogr2ogr -> tippecanoe |
| HIFLD (DHS/CISA) | United States | Transmission lines, substations, power plants + hospitals, fire stations, schools | Shapefile, GeoJSON | ~5 GB raw -> ~3 GB tiles | ogr2ogr -> tippecanoe |
| ENTSO-E Grid Map / GridKit | Europe | High-voltage transmission (>=220kV), generation (>=100MW) | CSV, Shapefile | ~200 MB | ogr2ogr -> tippecanoe |
| Geoscience Australia Digital Atlas | Australia | Transmission lines, substations, major generators | Shapefile | ~100 MB | ogr2ogr -> tippecanoe |

### Water Infrastructure

| Source | Coverage | What You Get | Format | Size | Conversion |
|--------|----------|-------------|--------|------|------------|
| OSM via Geofabrik (water tags) | Global | Water treatment plants, wastewater facilities, reservoirs, dams, pumping stations | PBF -> GeoJSON | Included in OSM extract | osmium -> tippecanoe |
| EPA SDWIS + WATERS | United States | Community water system service areas + violations + contaminants | Geodatabase | ~3 GB -> ~2 GB tiles | ogr2ogr -> tippecanoe |
| EEA WISE | Europe | River basins, water bodies, monitoring stations | GeoPackage | ~2 GB -> ~1 GB tiles | ogr2ogr -> tippecanoe |
| NID (National Inventory of Dams) | United States | 92,075 dams with 70+ attributes (hazard class, capacity, inspection date) | GeoJSON | ~50 MB -> ~20 MB tiles | tippecanoe |
| Australian BoM Water Data | Australia | Water storage, catchments, major dams | Shapefile | ~500 MB | ogr2ogr -> tippecanoe |

### Telecoms

| Source | Coverage | What You Get | Format | Size | Conversion |
|--------|----------|-------------|--------|------|------------|
| OSM via Geofabrik (telecom tags) | Global | Telecoms masts (600K+), data centers (3,500+), fiber cables, exchanges | PBF -> GeoJSON | Included in OSM extract | osmium -> tippecanoe |

## Installation Options

### Option A: "Quick Start" -- Lightweight Global Overview (~1-5 GB)

Best for: Demos, presentations, quick exploration

| Layer | Source | Tile Size |
|-------|--------|-----------|
| Basemap | Protomaps (regional extract) | ~1-5 GB |
| Infrastructure | OpenInfraMap/OSM extract | ~200 MB |
| Cities | Natural Earth Populated Places | ~30 MB |

Pros: Small, fast to set up, global coverage, all free/open
Cons: Demographics are coarse (city-level only). Infrastructure quality varies. No water treatment data. No generation attributes.

```bash
./options/option-a.sh
```

### Option B: "US Federal Authority" -- HIFLD + Census + EIA + NID (~10 GB)

Best for: US-focused CISA sector analysis with authoritative federal data

| Layer | Source | Tile Size |
|-------|--------|-----------|
| Demographics | TIGER/Line + ACS | ~5 GB |
| Infrastructure | HIFLD (multi-sector) | ~3 GB |
| Energy detail | EIA Power Plants | ~200 MB |
| Dams | NID | ~20 MB |
| Water | EPA SDWIS | ~2 GB |

Pros: All federal/authoritative. Rich attributes (MW capacity, hazard levels, violations). Covers demographics + electric + water deeply. CISA-aligned.
Cons: US-only. 5 separate conversions. Some HIFLD datasets need DHS registration. Larger storage. Annual updates.

```bash
./options/option-b.sh
```

### Option C: "Modern + Comprehensive" -- Overture + OpenInfraMap + Census + HIFLD (~16 GB)

Best for: Global building footprints + US deep detail

| Layer | Source | Tile Size |
|-------|--------|-----------|
| Buildings | Overture Maps (buildings + divisions) | ~10 GB (US extract) |
| Infrastructure | OpenInfraMap/OSM | ~200 MB |
| Demographics | TIGER/Line + ACS | ~5 GB |
| Water + Dams | HIFLD subset | ~1 GB |

Pros: Global base (Overture buildings anywhere), US deep detail, monthly OSM updates, building density as population proxy.
Cons: Overlap between Overture and OpenInfraMap (both OSM). Census doesn't extend outside US. Most complex pipeline (4 formats). Overture buildings are massive.

```bash
./options/option-c.sh
```

### Option D: "Minimum Viable OXOT" -- HIFLD + Census (~8 GB)

Best for: Fastest path to CISA sector analysis

| Layer | Source | Tile Size |
|-------|--------|-----------|
| Infrastructure | HIFLD (electric + water + emergency) | ~3 GB |
| Demographics | TIGER/Line + ACS | ~5 GB |

Pros: Two sources cover all CISA needs. Both authoritative. HIFLD organized by sectors. Minimal pipeline (2 conversions). Maps directly to 16 sector model.
Cons: US-only. No real-time. No building footprints. Less detailed power plant attributes than EIA.

```bash
./options/option-d.sh
```

### Option E: "Multi-Region Full Coverage" -- Europe + N. America + AU/NZ (~22 GB) [RECOMMENDED]

Best for: Full coverage across all three target regions

| # | Source | Covers | Regions | Native? | Tile Size |
|---|--------|--------|---------|---------|-----------|
| 1 | Protomaps Basemap | Cities, places, names, roads, buildings | All 3 | YES | ~15 GB |
| 2 | Geofabrik OSM (filtered) | Power lines, substations, generators, telecoms, pipelines, water treatment | All 3 | No | ~1 GB |
| 3 | GeoNames cities15000 | 25,000+ populated places with population | All 3 | No | ~20 MB |
| 4 | Eurostat Nuts2json | European demographics (NUTS regions) | Europe | No | ~50 MB |
| 5 | US Census TIGER + ACS | US demographics at tract level | N. America | No | ~5 GB |
| 6 | ABS Census Boundaries | Australian demographics at SA2 level | AU/NZ | No | ~500 MB |

Pros: Complete coverage of all 3 regions. Electric + water + demographics + telecoms. Mix of authoritative sources per region. 6 sources only.
Cons: 22 GB total. Only source #1 is native drop-in. Others need conversion (but #3 and #4 are trivial).

```bash
./options/option-e.sh
```

## Effort / Time Per Option

| Option | Sources | Download | Convert | Total | Disk |
|--------|---------|----------|---------|-------|------|
| A | 3 | ~30 min | ~10 min | ~40 min | ~5 GB |
| B | 5 | ~2 hours | ~1 hour | ~3 hours | ~10 GB |
| C | 4 | ~3 hours | ~2 hours | ~5 hours | ~16 GB |
| D | 2 | ~1 hour | ~30 min | ~1.5 hours | ~8 GB |
| E | 6 | ~4 hours | ~2 hours | ~6 hours | ~22 GB |

## Directory Structure

```
oxot_tileserver/
├── README.md                    # This file
├── docker-compose.yml           # Tileserver + converter containers
├── Dockerfile                   # Tileserver-gl image
├── Dockerfile.converter         # Conversion tools image
├── .env.example                 # Environment configuration
├── .gitignore                   # Ignore data/ and raw downloads
├── scripts/
│   ├── download.sh              # Universal download script
│   ├── convert.sh               # Universal conversion script
│   ├── load.sh                  # Load tiles into tileserver
│   ├── update.sh                # Periodic maintenance
│   └── extract-osm.sh           # OSM-specific tag filtering
├── sources/
│   ├── README.md                # Detailed source catalog
│   ├── basemap/                 # Basemap source configs
│   ├── demographics/            # Census/Eurostat/ABS configs
│   ├── electric/                # Power grid source configs
│   ├── water/                   # Water infrastructure configs
│   └── telecoms/                # Telecoms source configs
├── styles/
│   └── infrastructure.json      # MapLibre GL style for infrastructure
├── config/
│   ├── tileserver-config.json   # Tileserver-gl configuration
│   └── tippecanoe-opts.json     # Per-layer conversion options
├── options/
│   ├── option-a.sh              # Quick Start
│   ├── option-b.sh              # US Federal Authority
│   ├── option-c.sh              # Modern + Comprehensive
│   ├── option-d.sh              # Minimum Viable OXOT
│   └── option-e.sh              # Multi-Region Full Coverage
└── data/
    ├── tiles/                   # Generated tiles (served by tileserver)
    └── raw/                     # Downloaded source data (can be deleted)
```

## Maintenance

### Updating Data

```bash
# Re-download and reconvert all sources for your option
./scripts/update.sh --option e

# Update just one source
./scripts/download.sh --source osm-infrastructure
./scripts/convert.sh --source osm-infrastructure
docker compose restart tileserver
```

### Schedule (cron)

```cron
# Weekly OSM infrastructure update (Sundays at 2 AM)
0 2 * * 0 cd /path/to/oxot_tileserver && ./scripts/update.sh --source osm-infrastructure

# Monthly basemap update (1st of month at 3 AM)
0 3 1 * * cd /path/to/oxot_tileserver && ./scripts/update.sh --source basemap

# Annual census update (January 15 at 4 AM)
0 4 15 1 * cd /path/to/oxot_tileserver && ./scripts/update.sh --source demographics
```

### Checking Health

```bash
# Tileserver health
curl http://localhost:8080/health

# List served tilesets
curl http://localhost:8080/index.json

# Container status
docker compose ps
docker compose logs tileserver --tail 20
```

## Querying from Applications

### REST API (tileserver-gl)

```
GET http://localhost:8080/index.json                          # List all tilesets
GET http://localhost:8080/data/{tileset}/{z}/{x}/{y}.pbf      # Vector tile
GET http://localhost:8080/styles/{style}/{z}/{x}/{y}.png      # Rendered raster
GET http://localhost:8080/data/{tileset}.json                 # TileJSON metadata
```

### MapLibre GL JS (frontend)

```javascript
const map = new maplibregl.Map({
  container: 'map',
  style: 'http://localhost:8080/styles/infrastructure/style.json',
  center: [-98.5, 39.8],
  zoom: 4
});

// Add infrastructure overlay
map.addSource('infra', {
  type: 'vector',
  url: 'http://localhost:8080/data/osm-infrastructure.json'
});
map.addLayer({
  id: 'power-lines',
  type: 'line',
  source: 'infra',
  'source-layer': 'power_lines',
  paint: { 'line-color': '#ff4444', 'line-width': 2 }
});
```

### From OXOT Cyber DT (your existing app)

Point your existing tileserver config at this standalone instance:

```env
TILESERVER_URL=http://localhost:8080
```

## Overlap Analysis

| Source Pair | Overlap | Resolution |
|-------------|---------|------------|
| HIFLD <-> EIA | Power plants, transmission | EIA richer generation attributes; HIFLD broader. Use EIA for energy, HIFLD for multi-sector |
| HIFLD <-> NID | Dams | NID is upstream source for HIFLD dams. Pick one (NID more current) |
| HIFLD <-> EPA | Water systems | HIFLD = facility points; EPA = service area polygons + violations. Complementary |
| OpenInfraMap <-> EIA | Power plants | Different sources (OSM vs federal). EIA authoritative for US; OSM for global |
| Overture <-> Natural Earth | Cities | Heavy overlap. Overture for detail, Natural Earth for simplicity |
| Overture <-> OpenInfraMap | Both from OSM | Different themes (buildings vs power). Minimal overlap |

## License

Data sources have their own licenses:

- OpenStreetMap data: ODbL
- US Federal data (Census, EIA, HIFLD, NID, EPA): Public Domain
- Eurostat: CC BY 4.0
- Natural Earth: Public Domain
- GeoNames: CC BY 4.0
- Protomaps Basemap: ODbL
- Overture Maps: ODbL + CDLA Permissive 2.0

This repository (scripts and configuration): MIT License

## Links

- [Protomaps Basemap Builds](https://maps.protomaps.com/builds/)
- [Geofabrik Downloads](https://download.geofabrik.de/)
- [GeoNames Download](https://download.geonames.org/export/dump/)
- [Eurostat Nuts2json](https://github.com/eurostat/Nuts2json)
- [US Census TIGER/Line](https://www.census.gov/geographies/mapping-files/time-series/geo/tiger-line-file.html)
- [ABS Census Geography](https://www.abs.gov.au/statistics/standards/australian-statistical-geography-standard-asgs-edition-3)
- [EIA US Energy Atlas](https://atlas.eia.gov/)
- [HIFLD Open Data](https://hifld-geoplatform.opendata.arcgis.com/)
- [EPA Community Water Systems](https://www.epa.gov/ground-water-and-drinking-water/community-water-system-service-area-boundaries)
- [NID (Dams)](https://nid.sec.usace.army.mil/)
- [EEA WISE Water Data](https://www.eea.europa.eu/en/datahub/datahubitem-view/c2c99dcc-ebe2-4dd7-9248-0219a82f6eb3)
- [Open Infrastructure Map](https://openinframap.org/)
- [Tippecanoe](https://github.com/felt/tippecanoe)
- [Osmium Tool](https://osmcode.org/osmium-tool/)
- [Tileserver-GL](https://github.com/maptiler/tileserver-gl)
