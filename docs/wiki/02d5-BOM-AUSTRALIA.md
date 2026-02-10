> **Last Updated**: 2026-02-11 01:00 UTC

[Home](INDEX.md) > [Data Sources](02-DATA-SOURCES.md) > [Water Infrastructure](02d-WATER.md) > Australian BoM Water

# Australian Bureau of Meteorology Water Data

The Australian Bureau of Meteorology (BoM) publishes the Australian Hydrological
Geospatial Fabric (Geofabric), which provides catchment boundaries, river
networks, and water storage data for all of Australia. Combined with real-time
water storage level APIs, this data enables both static infrastructure mapping
and dynamic water-level visualisation.

---

## Quick Reference

| Attribute | Value |
|-----------|-------|
| **Provider** | Bureau of Meteorology (Australian Government) |
| **URL (Geofabric)** | http://www.bom.gov.au/water/geofabric/ |
| **URL (Water Storage)** | http://www.bom.gov.au/water/dashboards/ |
| **Coverage** | Australia |
| **Format** | Shapefile, GeoDatabase (Geofabric); JSON (API) |
| **Size (raw)** | ~1 GB (Geofabric) |
| **Size (tiles)** | ~500 MB (MBTiles) |
| **Update Cadence** | Geofabric: periodic (multi-year); Storage levels: daily |
| **License** | CC BY 4.0 |
| **OXOT Option** | D and above |

---

## Geofabric Components

The Geofabric is organised into several product layers:

| Product | Geometry | Description |
|---------|----------|-------------|
| **Catchments** | Polygon | Hydrological catchment boundaries at multiple levels |
| **River Regions** | Polygon | 12 major drainage divisions + subdivisions |
| **Contracted Catchments** | Polygon | Catchments upstream of monitoring points |
| **AHGFNetworkStream** | LineString | River and stream network (AHD-referenced) |
| **AHGFWaterbody** | Polygon | Lakes, reservoirs, and wetlands |
| **AHGFNode** | Point | Confluences, gauging stations, inflows/outflows |

### Catchment Hierarchy

| Level | Name | Count | Description |
|-------|------|-------|-------------|
| Level 1 | Drainage Division | 12 | Top-level basins (e.g., Murray-Darling) |
| Level 2 | River Region | ~80 | Major river systems |
| Level 3 | River Basin | ~250 | Sub-basins |
| Level 4+ | Contracted Catchment | ~3,000+ | Upstream of monitoring points |

---

## Water Storage Levels (API)

BoM publishes daily water storage levels for major dams and reservoirs across
Australia. This data can be used for dynamic tile styling or OXOT Digital Twin
dashboard integration.

### API Endpoint

```bash
# Current storage levels (JSON)
curl "http://www.bom.gov.au/waterdata/services" \
  -d '{"service":"kisters","type":"queryServices","request":"getStationList","datasource":0,"format":"json"}' \
  -o bom_stations.json
```

### Key Fields

| Field | Type | Description |
|-------|------|-------------|
| `station_no` | String | BoM station identifier |
| `station_name` | String | Dam/reservoir name |
| `storage_volume_ml` | Number | Current storage (megalitres) |
| `storage_capacity_ml` | Number | Full supply capacity |
| `percent_full` | Number | Current percentage full |
| `date` | Date | Observation date |

---

## Download

### Geofabric

```bash
# Download from BoM
wget http://www.bom.gov.au/water/geofabric/download/SH_Catchments_GDB.zip
unzip SH_Catchments_GDB.zip

wget http://www.bom.gov.au/water/geofabric/download/SH_Network_Stream_GDB.zip
unzip SH_Network_Stream_GDB.zip
```

### Conversion Pipeline

#### Step 1: Extract and Reproject

```bash
# Convert from GDA94 to WGS 84
ogr2ogr -f GeoJSON -t_srs EPSG:4326 \
  catchments.geojson SH_Catchments.gdb AHGFCatchment

ogr2ogr -f GeoJSON -t_srs EPSG:4326 \
  rivers.geojson SH_Network_Stream.gdb AHGFNetworkStream

ogr2ogr -f GeoJSON -t_srs EPSG:4326 \
  waterbodies.geojson SH_Catchments.gdb AHGFWaterbody
```

#### Step 2: Generate Tiles

```bash
# Catchments (low-mid zoom)
tippecanoe \
  -o bom_catchments.mbtiles \
  -z10 -Z0 \
  --coalesce-densest-as-needed \
  -l catchments catchments.geojson

# River network (mid-high zoom)
tippecanoe \
  -o bom_rivers.mbtiles \
  -z14 -Z6 \
  --drop-densest-as-needed \
  -l rivers rivers.geojson

# Waterbodies
tippecanoe \
  -o bom_waterbodies.mbtiles \
  -z14 -Z4 \
  --drop-densest-as-needed \
  -l waterbodies waterbodies.geojson

# Merge
tile-join -o bom_water.mbtiles \
  bom_catchments.mbtiles bom_rivers.mbtiles bom_waterbodies.mbtiles
```

---

## Quality Notes

- **Geofabric version**: The current version is v3.0. Check the BoM website for
  the latest release.
- **CRS**: Geofabric uses GDA94 (EPSG:4283). Reproject to WGS 84 (EPSG:4326)
  before tiling.
- **River network size**: The full stream network is very large (~1.5 million
  features). Consider filtering to named streams or Strahler order >= 3 for
  manageable tile sizes.
- **Storage API**: Real-time storage data requires periodic polling. For static
  tiles, snapshot the data at build time.

---

## References

Bureau of Meteorology. (2025). *Australian hydrological geospatial fabric (Geofabric)*. Australian Government. http://www.bom.gov.au/water/geofabric/

Bureau of Meteorology. (2025). *Water dashboards*. Australian Government. http://www.bom.gov.au/water/dashboards/

---

## Related Pages

- **Parent**: [Water Infrastructure](02d-WATER.md)
- **Siblings**: [OSM Water](02d1-OSM-WATER.md) | [EPA SDWIS](02d2-EPA-SDWIS.md) | [EEA WISE](02d3-EEA-WISE.md) | [NID Dams](02d4-NID-DAMS.md)
- **Australian Data**: [ABS Census](02b3-ABS-AUSTRALIA.md) | [Geoscience AU](02c5-GEOSCIENCE-AU.md)
- **Pipeline**: [Conversion & Tippecanoe](04c-CONVERT.md)
