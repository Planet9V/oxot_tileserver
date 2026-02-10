> **Last Updated**: 2026-02-11 01:00 UTC

[Home](INDEX.md) > [Data Sources](02-DATA-SOURCES.md) > [Water Infrastructure](02d-WATER.md) > EEA WISE

# EEA WISE (Water Information System for Europe)

The European Environment Agency (EEA) operates the Water Information System for
Europe (WISE), which consolidates water-related data reported by EU member states
under the Water Framework Directive (WFD). WISE provides river basin boundaries,
surface water bodies, groundwater bodies, and ecological/chemical status
assessments across the European Union.

---

## Quick Reference

| Attribute | Value |
|-----------|-------|
| **Provider** | European Environment Agency (EEA) |
| **URL** | https://www.eea.europa.eu/en/datahub?topic=water |
| **Coverage** | EU-27, EFTA, UK (historical) |
| **Format** | Shapefile, GeoJSON, GeoDatabase |
| **Key Features** | River basins, water bodies, monitoring stations |
| **Size (raw)** | ~2 GB |
| **Size (tiles)** | ~1 GB (MBTiles) |
| **Update Cadence** | Aligned with WFD reporting cycles (every 6 years) |
| **License** | EEA standard re-use policy (free, attribution required) |
| **OXOT Option** | D and above |

---

## Available Layers

| Layer | Geometry | Features (approx.) | Description |
|-------|----------|--------------------|-------------|
| River Basin Districts | Polygon | ~130 | Top-level management units under WFD |
| Sub-basins | Polygon | ~1,100 | Hydrological sub-divisions |
| Surface Water Bodies | Polygon/LineString | ~130,000 | Rivers, lakes, transitional, coastal |
| Groundwater Bodies | Polygon | ~13,000 | Aquifer delineations |
| Monitoring Stations | Point | ~60,000 | Ecological and chemical monitoring sites |
| Urban Wastewater Treatment Plants | Point | ~23,000 | UWWTD reported plants |

---

## Water Framework Directive Status

The WFD requires member states to achieve "good status" for all water bodies.
WISE reports both ecological and chemical status:

| Status | Meaning |
|--------|---------|
| High | Near-natural conditions |
| Good | Slight deviation from natural |
| Moderate | Moderate deviation |
| Poor | Major deviation |
| Bad | Severely altered |

These status classifications are included as vector-tile properties, enabling
choropleth visualisation of water body health.

---

## Key Attributes

### River Basin Districts

| Field | Type | Description |
|-------|------|-------------|
| `rbdCode` | String | River basin district code (e.g., EU17 = Danube) |
| `rbdName` | String | Full name |
| `countryCode` | String | ISO 3166-1 alpha-2 |
| `areaKm2` | Number | Basin area in square kilometres |

### Surface Water Bodies

| Field | Type | Description |
|-------|------|-------------|
| `swBodyCode` | String | Unique water body identifier |
| `swBodyName` | String | Name |
| `category` | String | River, Lake, Transitional, Coastal |
| `ecologicalStatus` | String | High, Good, Moderate, Poor, Bad |
| `chemicalStatus` | String | Good, Failing to achieve good |
| `rbdCode` | String | Parent river basin district |

### Urban Wastewater Treatment Plants

| Field | Type | Description |
|-------|------|-------------|
| `uwwCode` | String | Unique plant identifier |
| `uwwName` | String | Plant name |
| `uwwCapacity` | Number | Design capacity (population equivalents) |
| `uwwTreatmentLevel` | String | Primary, Secondary, Tertiary |
| `uwwLoadEntering` | Number | Actual load (PE) |

---

## Download Methods

### EEA Data Hub

```bash
# River basin districts
wget -O rbd.zip \
  "https://www.eea.europa.eu/data-and-maps/data/wise-wfd-4/river-basin-districts/river-basin-districts-shapefile/download"
unzip rbd.zip

# Surface water bodies
wget -O swb.zip \
  "https://www.eea.europa.eu/data-and-maps/data/wise-wfd-4/surface-water-bodies/surface-water-bodies-shapefile/download"
unzip swb.zip
```

### UWWTD (Urban Waste Water Treatment)

```bash
wget -O uwwtd.zip \
  "https://www.eea.europa.eu/data-and-maps/data/waterbase-uwwtd-urban-waste-water-treatment-directive/download"
unzip uwwtd.zip
```

---

## Conversion Pipeline

### Step 1: Prepare GeoJSON

```bash
ogr2ogr -f GeoJSON rbd.geojson River_Basin_Districts.shp
ogr2ogr -f GeoJSON swb.geojson Surface_Water_Bodies.shp
ogr2ogr -f GeoJSON uwwtd_plants.geojson UWWTD_Agglomeration.shp
```

### Step 2: Generate Tiles

```bash
# River basins (low zoom)
tippecanoe \
  -o wise_basins.mbtiles \
  -z10 -Z0 \
  --coalesce-densest-as-needed \
  -l river_basins rbd.geojson \
  -l sub_basins sub_basins.geojson

# Water bodies (mid-high zoom)
tippecanoe \
  -o wise_water_bodies.mbtiles \
  -z14 -Z6 \
  --drop-densest-as-needed \
  -l water_bodies swb.geojson

# Treatment plants (points)
tippecanoe \
  -o wise_uwwtd.mbtiles \
  -z14 -Z4 \
  -r1 \
  -l uwwtd_plants uwwtd_plants.geojson

# Merge
tile-join -o eea_wise.mbtiles \
  wise_basins.mbtiles wise_water_bodies.mbtiles wise_uwwtd.mbtiles
```

---

## Quality Notes

- **Reporting lag**: WFD status data reflects the most recent reporting cycle
  (typically 2-3 years behind current date).
- **Completeness**: Some member states report more detailed data than others.
  Northern and Western European coverage is generally more complete.
- **Coastal waters**: Coastal water bodies extend to 1 nautical mile from baseline.
  These polygons are large and may dominate tile sizes at lower zoom levels.
- **UWWTD vs OSM**: The UWWTD plant list is authoritative for EU wastewater
  treatment. OSM supplements with smaller plants not captured in UWWTD reporting.

---

## References

European Environment Agency. (2025). *Water Information System for Europe (WISE)*. https://www.eea.europa.eu/en/datahub?topic=water

European Environment Agency. (2025). *Waterbase: UWWTD -- Urban Waste Water Treatment Directive*. https://www.eea.europa.eu/data-and-maps/data/waterbase-uwwtd-urban-waste-water-treatment-directive

European Parliament & Council. (2000). *Directive 2000/60/EC establishing a framework for Community action in the field of water policy* (Water Framework Directive). Official Journal of the European Communities, L 327, 1-73.

---

## Related Pages

- **Parent**: [Water Infrastructure](02d-WATER.md)
- **Siblings**: [OSM Water](02d1-OSM-WATER.md) | [EPA SDWIS](02d2-EPA-SDWIS.md) | [NID Dams](02d4-NID-DAMS.md) | [BoM Water](02d5-BOM-AUSTRALIA.md)
- **European Data**: [Eurostat NUTS](02b2-EUROSTAT.md) | [ENTSO-E](02c4-ENTSOE.md)
- **Pipeline**: [Download Scripts](04a-DOWNLOAD.md) | [Conversion](04c-CONVERT.md)
