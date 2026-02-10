# OXOT Tileserver -- Source Catalog

Detailed reference for every data source available to the OXOT tileserver pipeline. Each entry documents the provider, download location, coverage, contents, format, size, update cadence, license, and known caveats.

---

## Basemap

### 1. Protomaps Basemap

- **Provider**: Protomaps (Brandon Liu)
- **URL**: https://maps.protomaps.com/builds/
- **Coverage**: Global (planet file) or per-region extracts
- **Contents**: Roads, buildings, land use, water bodies, place names, boundaries, points of interest. Full OpenStreetMap-derived basemap suitable for general-purpose cartography.
- **Key attributes**: name, kind (road/building/water/etc.), min_zoom, source
- **Format**: PMTiles (single file, HTTP range-request friendly)
- **Download size**: ~120 GB (planet); ~15 GB (3-region extract: Europe + North America + Australia-Oceania)
- **Update frequency**: Weekly builds
- **License**: ODbL (OpenStreetMap data license)
- **Notes**: PMTiles files can be served directly by tileserver-gl without conversion. Planet file is very large; use region extracts where possible. The `pmtiles extract` CLI can cut custom bounding boxes from the planet file.

### 2. OpenMapTiles / MapTiler

- **Provider**: MapTiler AG
- **URL**: https://www.maptiler.com/data/ (also https://openmaptiles.org/)
- **Coverage**: Global (planet) or country-level extracts
- **Contents**: Same general-purpose basemap as Protomaps but using the OpenMapTiles schema. Roads, buildings, land use, water, boundaries, POIs, terrain contours (in premium tiers).
- **Key attributes**: class, subclass, name, name_en, rank
- **Format**: MBTiles (SQLite-based)
- **Download size**: ~80 GB (planet); country extracts vary (US ~10 GB, Germany ~3 GB)
- **Update frequency**: Monthly (free tier); weekly (commercial)
- **License**: ODbL for OSM data; proprietary additions in commercial tiers
- **Notes**: Free planet download available from openmaptiles.org but may be behind the latest schema. Commercial downloads from maptiler.com include contours and hillshade. MBTiles is natively supported by tileserver-gl.

### 3. OpenFreeMap

- **Provider**: OpenFreeMap community project
- **URL**: https://openfreemap.org/
- **Coverage**: Global (planet)
- **Contents**: Complete OSM-derived basemap using a Mapbox-compatible vector tile schema. Roads, buildings, land use, water, place names, boundaries.
- **Key attributes**: Standard Mapbox vector tile fields
- **Format**: MBTiles (weekly builds)
- **Download size**: ~80 GB (planet)
- **Update frequency**: Weekly
- **License**: ODbL
- **Notes**: Designed as a free, self-hostable alternative to Mapbox. Weekly planet builds are large. No built-in region extraction; use `ogr2ogr` or `tile-join` with a bounding box to subset. MBTiles is natively supported by tileserver-gl.

---

## Demographics / Population

### 4. US Census TIGER/Line + ACS

- **Provider**: United States Census Bureau
- **URL**: https://www.census.gov/geographies/mapping-files/time-series/geo/tiger-line-file.html
- **ACS data**: https://data.census.gov/
- **Coverage**: United States (50 states + DC + territories)
- **Contents**: Census tract boundaries, block group boundaries, county boundaries, ZIP Code Tabulation Areas (ZCTAs), state boundaries. When joined with American Community Survey (ACS) data: total population, median household income, age distribution, race/ethnicity, housing units, poverty rate, educational attainment.
- **Key attributes**: GEOID, STATEFP, COUNTYFP, TRACTCE, ALAND, AWATER, population, median_income, housing_units
- **Format**: Shapefile (geometry); CSV (ACS tabular data). Must be joined by GEOID.
- **Download size**: ~15 GB raw (all shapefiles + ACS tables) -> ~5 GB tiles after conversion
- **Update frequency**: Annual (TIGER geometry updated yearly; ACS 5-year estimates updated annually with ~2 year lag)
- **License**: Public Domain (US Government work)
- **Notes**: ACS 5-year estimates are the most statistically reliable for small geographies (tracts, block groups). The join between TIGER shapefiles and ACS CSVs requires matching on GEOID. Download automation is possible via the Census FTP site or the census.gov API. Conversion pipeline: `ogr2ogr` (Shapefile to GeoJSON) then `tippecanoe`.

### 5. Eurostat NUTS + Nuts2json

- **Provider**: Eurostat (European Commission) + Nuts2json project
- **URL**: https://ec.europa.eu/eurostat/web/gisco/geodata/reference-data/administrative-units-statistical-units
- **Nuts2json**: https://github.com/eurostat/Nuts2json
- **Coverage**: European Union + EFTA countries (37 countries)
- **Contents**: NUTS Level 0 (countries), NUTS Level 1 (major regions), NUTS Level 2 (basic regions), NUTS Level 3 (small regions). Statistical data: population, GDP, employment rate, education, health indicators.
- **Key attributes**: NUTS_ID, LEVL_CODE, CNTR_CODE, NAME_LATN, population, gdp_per_capita
- **Format**: GeoJSON (Nuts2json provides pre-simplified, web-ready files); GeoPackage (full resolution from Eurostat GISCO)
- **Download size**: ~2 GB raw (full GISCO) or ~50 MB (Nuts2json simplified) -> ~1 GB tiles
- **Update frequency**: NUTS boundaries revised every 3 years; statistical data updated annually
- **License**: CC BY 4.0 (Eurostat reuse policy)
- **Notes**: Nuts2json is the recommended starting point -- it provides pre-simplified GeoJSON files at multiple resolutions (10M, 20M, 60M scale) that can go directly into tippecanoe. Full-resolution GISCO data is available as GeoPackage for detailed work. NUTS boundary revisions (e.g., NUTS 2021 vs NUTS 2024) must match the statistical vintage.

### 6. ABS (Australian Bureau of Statistics) Census Boundaries

- **Provider**: Australian Bureau of Statistics
- **URL**: https://www.abs.gov.au/statistics/standards/australian-statistical-geography-standard-asgs-edition-3
- **Data downloads**: https://www.abs.gov.au/census/find-census-data/datapacks
- **Coverage**: Australia
- **Contents**: Statistical Area boundaries at levels SA1, SA2, SA3, SA4, plus state/territory boundaries. Census data: population, age, income, dwelling type, household composition, education, employment.
- **Key attributes**: SA2_CODE21, SA2_NAME21, STE_CODE21, population, median_income, dwellings
- **Format**: Shapefile, GeoPackage (boundaries); CSV (census DataPacks)
- **Download size**: ~1 GB raw (boundaries + census data) -> ~500 MB tiles
- **Update frequency**: Census every 5 years (last: 2021; next: 2026). Boundaries updated with each census.
- **License**: CC BY 4.0 (Australian Government)
- **Notes**: SA2 is the most useful level for demographic analysis -- roughly equivalent to US census tracts (2,000-25,000 people). DataPacks provide pre-packaged census tables keyed by geography code. Join on SA2_CODE21. Conversion: `ogr2ogr` then `tippecanoe`.

### 7. Stats NZ Geographic Boundaries

- **Provider**: Stats NZ (Statistics New Zealand)
- **URL**: https://www.stats.govt.nz/
- **Downloads**: https://datafinder.stats.govt.nz/
- **Coverage**: New Zealand
- **Contents**: Meshblock boundaries (smallest census unit, ~100 people), Statistical Area 1 (SA1), Statistical Area 2 (SA2), Territorial Authority, Regional Council. Census data: population, ethnicity, income, housing, employment.
- **Key attributes**: MB2023_V1, SA12023_V, SA22023_V, TA2023_V1, population, median_income
- **Format**: Shapefile, GeoJSON, GeoPackage
- **Download size**: ~500 MB raw
- **Update frequency**: Census every 5 years (last: 2023). Boundaries updated with each census.
- **License**: CC BY 4.0 (New Zealand Government)
- **Notes**: Meshblocks are very fine-grained (~100 people each, 53,000+ nationwide). For tile generation, SA2 level is usually sufficient. Available from the Stats NZ DataFinder portal. Conversion: `ogr2ogr` then `tippecanoe`.

### 8. GeoNames

- **Provider**: GeoNames community project
- **URL**: https://www.geonames.org/
- **Downloads**: https://download.geonames.org/export/dump/
- **Coverage**: Global
- **Contents**: 25,000+ cities and towns (cities15000 extract: all places with population >= 15,000). Fields include name, latitude, longitude, country code, admin divisions, population, elevation, timezone.
- **Key attributes**: geonameid, name, asciiname, latitude, longitude, country_code, population, elevation, feature_class, feature_code
- **Format**: TSV (tab-separated values, no header row)
- **Download size**: ~1.5 MB (cities15000.zip); ~400 MB (allCountries.zip)
- **Update frequency**: Daily updates to the full database; cities15000 rebuilt weekly
- **License**: CC BY 4.0
- **Notes**: The cities15000 file is an excellent lightweight option for global city labels. Conversion is straightforward: parse TSV, emit GeoJSON points, run through `tippecanoe`. The full allCountries dump includes 12M+ features (mountains, rivers, administrative areas) and is much larger. Use `awk` or a script to convert TSV to GeoJSON.

### 9. Natural Earth Populated Places

- **Provider**: Natural Earth (community-maintained)
- **URL**: https://www.naturalearthdata.com/downloads/10m-cultural-vectors/10m-populated-places/
- **Coverage**: Global
- **Contents**: ~7,300 cities and towns with population estimates, capital status, country, max/min population estimates, and Wikipedia links. Available at 1:10m, 1:50m, and 1:110m scales.
- **Key attributes**: NAME, ADM0NAME, SOV0NAME, POP_MAX, POP_MIN, LATITUDE, LONGITUDE, FEATURECLA, ADM0_A3
- **Format**: Shapefile, GeoJSON
- **Download size**: ~50 MB (10m cultural vectors package)
- **Update frequency**: Irregular (major releases every 1-2 years)
- **License**: Public Domain
- **Notes**: Good for coarse city labeling when GeoNames detail is not needed. The 1:10m scale is the most detailed. Population figures are estimates and may lag actual census counts. Conversion: `ogr2ogr` (Shapefile to GeoJSON) then `tippecanoe`.

### 10. WorldPop

- **Provider**: WorldPop, University of Southampton
- **URL**: https://www.worldpop.org/
- **Downloads**: https://hub.worldpop.org/
- **Coverage**: Global (individual country downloads or continental aggregates)
- **Contents**: Gridded population estimates at ~100m resolution. Modeled from census data, satellite imagery, and ancillary datasets. Available for multiple years (2000-2020) and projections (to 2030). Age/sex disaggregation available.
- **Key attributes**: population_count (per grid cell), year, admin_level
- **Format**: GeoTIFF (raster)
- **Download size**: ~10 GB per continent (100m resolution); ~1 GB per large country
- **Update frequency**: Annual model updates
- **License**: CC BY 4.0
- **Notes**: This is raster data, not vector. It cannot go through the standard tippecanoe pipeline. Options: (1) use `gdal2tiles.py` to produce raster tiles, (2) convert to vector by aggregating into grid polygons with `gdal_polygonize`, or (3) use as a population weighting raster alongside vector demographics. Most useful when census boundaries are unavailable for a region.

---

## Electric Grid

### 11. OSM Power Infrastructure (via Geofabrik)

- **Provider**: OpenStreetMap contributors, distributed by Geofabrik GmbH
- **URL**: https://download.geofabrik.de/
- **Visualization**: https://openinframap.org/
- **Coverage**: Global (quality varies by region; best in Europe and North America)
- **Contents**: Power lines (7M+ km), substations (1M+), generators/power plants (125K+), transformers, towers, poles. Also includes telecom and water infrastructure tags (see sources 16 and 21).
- **Key attributes**: power=line/substation/plant/generator, voltage, cables, operator, name, plant:source (solar/wind/gas/etc.), plant:output:electricity
- **Format**: PBF (Protocolbuffer Binary Format). Must be filtered with `osmium` to extract power/water/telecom tags, then converted.
- **Download size**: ~70 GB (planet PBF); ~4 GB (Europe); ~12 GB (North America); ~1 GB (Australia-Oceania). After filtering and conversion: ~500 MB tiles.
- **Update frequency**: Daily (Geofabrik mirrors updated daily from OSM)
- **License**: ODbL
- **Notes**: This is the single most important source for global infrastructure. One download covers power, water, and telecoms. The pipeline is: (1) download regional PBF extracts from Geofabrik, (2) filter with `osmium tags-filter` for power/water/telecom tags, (3) convert to GeoJSON with `ogr2ogr`, (4) tile with `tippecanoe`. OpenInfraMap.org is a live visualization of this data and useful for quality-checking. Coverage quality varies: Germany and UK are excellent; parts of Africa and Asia are sparse.

### 12. EIA US Energy Atlas

- **Provider**: U.S. Energy Information Administration (Department of Energy)
- **URL**: https://atlas.eia.gov/
- **API**: https://api.eia.gov/
- **Coverage**: United States
- **Contents**: Power plants >= 1 MW nameplate capacity (10,000+ facilities) with detailed attributes: fuel type (primary + secondary), nameplate capacity (MW), net generation (MWh), operating status, operator, owner, balancing authority, NERC region. Also: transmission lines, natural gas pipelines, coal mines, refineries.
- **Key attributes**: Plant_Code, Plant_Name, PrimSource, Total_MW, Net_Gen, Latitude, Longitude, State, Sector, Operating_Year
- **Format**: Shapefile, GeoJSON, CSV (downloadable layers from the Atlas)
- **Download size**: ~200 MB raw -> ~100 MB tiles
- **Update frequency**: Annual (EIA-860 and EIA-923 forms, released ~Q4 each year)
- **License**: Public Domain (US Government work)
- **Notes**: The most authoritative US source for power generation attributes. Richer than HIFLD for energy-specific data (generation output, fuel details, ownership). Transmission line data includes voltage and status. Download individual layers from the Atlas UI or use the EIA API for programmatic access. Conversion: `ogr2ogr` then `tippecanoe`.

### 13. HIFLD (Homeland Infrastructure Foundation-Level Data)

- **Provider**: Department of Homeland Security / CISA, hosted on ArcGIS Open Data
- **URL**: https://hifld-geoplatform.opendata.arcgis.com/
- **Coverage**: United States
- **Contents**: Multi-sector critical infrastructure organized by CISA sectors. Includes:
  - Electric: transmission lines, substations, power plants
  - Water: water treatment plants, wastewater facilities
  - Emergency: fire stations, EMS stations, hospitals
  - Transportation: airports, rail lines, ports
  - Education: schools, colleges
  - Communications: cell towers, broadcast towers
  - Government: federal buildings, military installations
  - And more (30+ datasets)
- **Key attributes**: Vary by dataset. Common: NAME, ADDRESS, CITY, STATE, LATITUDE, LONGITUDE, NAICS_CODE, STATUS
- **Format**: Shapefile, GeoJSON (direct download from ArcGIS portal)
- **Download size**: ~5 GB raw (all datasets) -> ~3 GB tiles
- **Update frequency**: Annual (some datasets quarterly)
- **License**: Public Domain (US Government work). Some datasets require DHS registration for access (marked "Restricted" on the portal).
- **Notes**: The broadest single source for US critical infrastructure. Organized by CISA sector, making it directly aligned with the OXOT 16-sector model. Some high-value datasets (e.g., detailed substations, cell towers with backhaul info) are restricted and require a .gov/.mil email or HSIN account. The publicly available datasets cover most needs. Conversion: `ogr2ogr` then `tippecanoe`.

### 14. ENTSO-E Grid Map / GridKit

- **Provider**: ENTSO-E (European Network of Transmission System Operators for Electricity); GridKit is an open research extraction
- **URL**: https://www.entsoe.eu/data/map/
- **GridKit**: https://zenodo.org/records/5765505 (or search Zenodo for "GridKit")
- **Coverage**: Europe (EU + EFTA + UK + Balkans)
- **Contents**: High-voltage transmission lines (>= 220 kV), substations, HVDC links, interconnectors, major generation plants (>= 100 MW). GridKit provides a cleaned, research-ready extraction with network topology.
- **Key attributes**: voltage_kV, circuits, length_km, from_station, to_station, capacity_MW, fuel_type
- **Format**: CSV (GridKit nodes + links); Shapefile (ENTSO-E direct). GridKit also available as GeoJSON.
- **Download size**: ~200 MB
- **Update frequency**: ENTSO-E map updated quarterly; GridKit snapshots are periodic (check Zenodo for latest)
- **License**: ENTSO-E data: restricted use (check terms); GridKit: Open Data (CC BY 4.0 or similar -- check Zenodo record)
- **Notes**: GridKit is the recommended starting point for programmatic use -- it provides clean node/edge CSV files with coordinates. ENTSO-E's own map is interactive but does not offer easy bulk download. For transmission-level European grid analysis, this is the authoritative source. Does not include distribution-level infrastructure. Conversion: parse CSV to GeoJSON then `tippecanoe`.

### 15. Geoscience Australia Digital Atlas

- **Provider**: Geoscience Australia (Australian Government)
- **URL**: https://digital.atlas.gov.au/
- **Also**: https://ecat.ga.gov.au/ (data catalog)
- **Coverage**: Australia
- **Contents**: High-voltage transmission lines, substations, major power stations. Also: pipelines (gas, oil, water), mining facilities, geological features.
- **Key attributes**: NAME, FEATURE_TYPE, VOLTAGE, OWNER, STATE, STATUS
- **Format**: Shapefile, GeoPackage
- **Download size**: ~100 MB
- **Update frequency**: Irregular (typically annual or when major infrastructure changes occur)
- **License**: CC BY 4.0 (Australian Government)
- **Notes**: The authoritative source for Australian electricity transmission infrastructure. Coverage is focused on transmission (>= 66 kV) and major generation. Distribution networks are not included. For more detailed data, combine with OSM (source 11) which has better coverage of lower-voltage and distribution infrastructure. Conversion: `ogr2ogr` then `tippecanoe`.

---

## Water Infrastructure

### 16. OSM Water Infrastructure (via Geofabrik)

- **Provider**: OpenStreetMap contributors, distributed by Geofabrik GmbH
- **URL**: https://download.geofabrik.de/ (same download as source 11)
- **Coverage**: Global (quality varies)
- **Contents**: Water treatment plants, wastewater treatment plants, reservoirs, dams, pumping stations, water towers, pipelines. Extracted from the same PBF files as power infrastructure using different tag filters.
- **Key attributes**: man_made=water_works/wastewater_plant/reservoir_covered, waterway=dam/weir, natural=water, water=reservoir
- **Format**: PBF (extracted via osmium tag filtering from the same regional extracts as source 11)
- **Download size**: Included in source 11 downloads. Filtered water data: ~50-200 MB tiles depending on region.
- **Update frequency**: Daily (same as source 11)
- **License**: ODbL
- **Notes**: Extracted from the same Geofabrik PBF files as power and telecoms. The `osmium tags-filter` step uses water-specific tags. Quality varies significantly: European water infrastructure is well-mapped; other regions may have gaps for treatment plants and pipelines. Dams and reservoirs are generally well-covered globally.

### 17. EPA SDWIS + WATERS

- **Provider**: United States Environmental Protection Agency
- **URL (SDWIS)**: https://www.epa.gov/ground-water-and-drinking-water/safe-drinking-water-information-system-sdwis-federal-reporting
- **URL (WATERS/CWS)**: https://www.epa.gov/ground-water-and-drinking-water/community-water-system-service-area-boundaries
- **Coverage**: United States
- **Contents**: Community Water System (CWS) service area boundaries (polygons showing which areas each water system serves). SDWIS database: violation history, contaminant monitoring, system characteristics, population served. 50,000+ community water systems.
- **Key attributes**: PWSID (water system ID), PWS_NAME, POPULATION_SERVED, SOURCE_TYPE (ground/surface), VIOLATION_COUNT, SERVICE_AREA_GEOMETRY
- **Format**: Geodatabase (GDB) for service area boundaries; CSV/API for SDWIS violation data
- **Download size**: ~3 GB raw -> ~2 GB tiles
- **Update frequency**: Quarterly (violation data); service area boundaries updated annually
- **License**: Public Domain (US Government work)
- **Notes**: The CWS service area boundary file is large but extremely valuable -- it shows which water utility serves each area. SDWIS violation data must be joined by PWSID. For tile generation, the service area polygons go through `ogr2ogr` (GDB to GeoJSON) then `tippecanoe`. Violation attributes can be pre-joined before tiling. The EPA Envirofacts API provides programmatic access to SDWIS data.

### 18. EEA WISE (Water Information System for Europe)

- **Provider**: European Environment Agency
- **URL**: https://www.eea.europa.eu/en/datahub/datahubitem-view/c2c99dcc-ebe2-4dd7-9248-0219a82f6eb3
- **Also**: https://water.europa.eu/
- **Coverage**: EU + EEA member countries
- **Contents**: River Basin Districts, sub-basins, water bodies (rivers, lakes, coastal, groundwater), monitoring stations, water quality status (ecological, chemical), WFD (Water Framework Directive) compliance status.
- **Key attributes**: waterBodyId, waterBodyName, rbdName, ecologicalStatus, chemicalStatus, waterBodyCategory
- **Format**: GeoPackage, Shapefile
- **Download size**: ~2 GB raw -> ~1 GB tiles
- **Update frequency**: Annual (aligned with WFD reporting cycles)
- **License**: EEA standard re-use policy (essentially CC BY 4.0; see https://www.eea.europa.eu/en/legal-notice for terms)
- **Notes**: The primary authoritative source for European water body delineation and quality status. Data is organized around the Water Framework Directive reporting structure. Useful for understanding watershed boundaries and which water bodies are failing environmental standards. Conversion: `ogr2ogr` then `tippecanoe`.

### 19. NID (National Inventory of Dams)

- **Provider**: U.S. Army Corps of Engineers
- **URL**: https://nid.sec.usace.army.mil/
- **Coverage**: United States
- **Contents**: 92,075+ dams with 70+ attributes including: dam name, height, length, storage capacity, surface area, year completed, hazard potential classification (high/significant/low), condition assessment, dam type (earth, gravity, arch, etc.), purposes (flood control, water supply, hydroelectric, recreation, etc.), owner type, inspection date, EAP (Emergency Action Plan) status, downstream population at risk.
- **Key attributes**: DAM_NAME, STATE, HAZARD, DAM_TYPE, MAX_STORAGE, NID_STORAGE, YEAR_COMPLETED, PURPOSES, CONDITION_ASSESSMENT, LATITUDE, LONGITUDE
- **Format**: GeoJSON (direct download from NID portal); also CSV
- **Download size**: ~50 MB -> ~20 MB tiles
- **Update frequency**: Annual (federal dams quarterly; state dams annually)
- **License**: Public Domain (US Government work)
- **Notes**: The definitive US dam inventory. Hazard classification is critical for risk assessment: "High" means loss of life is probable if the dam fails. The NID is the upstream source for dam data in HIFLD -- if using both, avoid double-counting. GeoJSON download can go directly into `tippecanoe` without intermediate conversion. Some fields (e.g., condition assessment) have limited coverage.

### 20. Australian Bureau of Meteorology (BoM) Water Data

- **Provider**: Bureau of Meteorology (Australian Government)
- **URL**: http://www.bom.gov.au/water/
- **Data portal**: http://www.bom.gov.au/water/geofabric/
- **Coverage**: Australia
- **Contents**: Australian Hydrological Geospatial Fabric (Geofabric): catchment boundaries, river network, water storage facilities (major dams and reservoirs), monitoring stations. Water storage data includes current storage levels as a percentage of capacity.
- **Key attributes**: STATION_NAME, CATCHMENT_ID, STORAGE_NAME, CAPACITY_ML, CURRENT_STORAGE_PCT, DAM_HEIGHT, LONGITUDE, LATITUDE
- **Format**: Shapefile, GeoPackage (Geofabric); CSV/API (water storage levels)
- **Download size**: ~500 MB (Geofabric); storage level data is small (CSV)
- **Update frequency**: Geofabric updated irregularly (major releases); storage levels updated weekly
- **License**: CC BY 4.0 (Australian Government)
- **Notes**: The Geofabric provides the authoritative Australian catchment and river network delineation. Water storage data is particularly useful for drought monitoring and water security assessment. Real-time storage levels can be fetched via the BoM water data API. For tile generation, use the Geofabric shapefiles through `ogr2ogr` then `tippecanoe`.

---

## Telecoms

### 21. OSM Telecoms (via Geofabrik)

- **Provider**: OpenStreetMap contributors, distributed by Geofabrik GmbH
- **URL**: https://download.geofabrik.de/ (same download as sources 11 and 16)
- **Coverage**: Global (quality varies)
- **Contents**: Telecommunications masts and towers (600K+), data centers (3,500+), telephone exchanges, fiber optic cables (mapped routes), radio relay links, satellite ground stations. Extracted from the same PBF files as power and water infrastructure.
- **Key attributes**: man_made=mast/tower, telecom=data_centre/exchange, communication=line, tower:type=communication, operator, ref
- **Format**: PBF (extracted via osmium tag filtering from the same regional extracts as source 11)
- **Download size**: Included in source 11 downloads. Filtered telecoms data: ~30-100 MB tiles depending on region.
- **Update frequency**: Daily (same as source 11)
- **License**: ODbL
- **Notes**: Telecoms infrastructure is the least consistently mapped category in OSM. Cell tower coverage is reasonable in developed countries but patchy elsewhere. Data center mapping has improved significantly since 2020. Fiber optic cable routes are mapped where they follow visible infrastructure (e.g., along roads or railways) but underground routes are often unmapped. This is currently the only freely available global telecoms infrastructure dataset. For US-specific cell tower data, HIFLD (source 13) may have restricted datasets with better coverage.

---

## Conversion Pipeline Summary

All non-native sources follow one of these conversion paths:

| Source Format | Pipeline | Tools Required |
|---------------|----------|----------------|
| PBF (OSM) | osmium tags-filter -> ogr2ogr -> tippecanoe | osmium, GDAL, tippecanoe |
| Shapefile | ogr2ogr -> tippecanoe | GDAL, tippecanoe |
| GeoPackage | ogr2ogr -> tippecanoe | GDAL, tippecanoe |
| Geodatabase (GDB) | ogr2ogr -> tippecanoe | GDAL, tippecanoe |
| GeoJSON | tippecanoe | tippecanoe |
| CSV/TSV (with coords) | script (to GeoJSON) -> tippecanoe | awk/python, tippecanoe |
| GeoTIFF (raster) | gdal2tiles.py | GDAL |
| PMTiles | (native -- no conversion) | -- |
| MBTiles | (native -- no conversion) | -- |

All conversion tools are included in the `converter` Docker container defined in `Dockerfile.converter`.

---

## Source-to-Option Mapping

| Source | Option A | Option B | Option C | Option D | Option E |
|--------|----------|----------|----------|----------|----------|
| 1. Protomaps Basemap | x | | x | | x |
| 4. US Census TIGER/ACS | | x | x | x | x |
| 5. Eurostat NUTS | | | | | x |
| 6. ABS Census | | | | | x |
| 8. GeoNames | | | | | x |
| 9. Natural Earth Places | x | | | | |
| 11. OSM Infrastructure | x | | x | | x |
| 12. EIA Power Plants | | x | | | |
| 13. HIFLD | | x | x | x | |
| 17. EPA SDWIS | | x | | | |
| 19. NID | | x | | | |
