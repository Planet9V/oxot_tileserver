> **Last Updated**: 2026-02-11 01:00 UTC

[Home](INDEX.md) > [Data Sources](02-DATA-SOURCES.md) > [Water Infrastructure](02d-WATER.md) > OSM Water Tags

# OSM Water Infrastructure

OpenStreetMap contains globally crowd-sourced data on water treatment plants,
wastewater facilities, reservoirs, dams, pumping stations, and water towers.
These features are extracted from the same Geofabrik PBF files used for
[OSM Power](02c1-OSM-POWER.md) and [OSM Telecoms](02e-TELECOMS.md), using
different `osmium tags-filter` expressions.

---

## Quick Reference

| Attribute | Value |
|-----------|-------|
| **Provider** | OpenStreetMap contributors (via Geofabrik) |
| **URL** | https://download.geofabrik.de/ |
| **Coverage** | Global |
| **Format** | PBF (shared with power/telecoms) |
| **Size (PBF)** | Shared -- see [OSM Power](02c1-OSM-POWER.md) |
| **Size (tiles)** | ~200 MB - 1 GB per region (water-only) |
| **License** | ODbL |
| **OXOT Option** | D and above |

---

## Relevant OSM Tags

| Tag | Values | Feature Type |
|-----|--------|-------------|
| `man_made=water_works` | -- | Drinking water treatment plant (Way) |
| `man_made=wastewater_plant` | -- | Wastewater treatment plant (Way) |
| `man_made=pumping_station` | -- | Pumping station (Node or Way) |
| `man_made=water_tower` | -- | Water tower (Node) |
| `man_made=reservoir_covered` | -- | Covered reservoir (Way) |
| `waterway=dam` | -- | Dam structure (Way) |
| `waterway=weir` | -- | Weir (Way or Node) |
| `natural=water` + `water=reservoir` | -- | Open reservoir (Way) |
| `natural=water` + `water=basin` | -- | Retention/detention basin (Way) |
| `amenity=drinking_water` | -- | Drinking water fountain (Node) |
| `operator` | String | Operating entity |
| `capacity` | Number | Treatment capacity (where tagged) |

---

## Extraction Pipeline

### Step 1: Filter Water Tags from PBF

```bash
osmium tags-filter europe-latest.osm.pbf \
  nwr/man_made=water_works,wastewater_plant,pumping_station,water_tower,reservoir_covered \
  nwr/waterway=dam,weir \
  nw/natural=water \
  -o europe_water.osm.pbf
```

> **Note**: The `natural=water` filter is broad. Post-filter with `ogr2ogr` to
> select only `water=reservoir` and `water=basin`, excluding lakes and rivers
> (which are already in the basemap layer).

### Step 2: Convert to GeoJSON

```bash
# Treatment plants and facilities (polygons)
ogr2ogr -f GeoJSON water_facilities.geojson \
  europe_water.osm.pbf multipolygons \
  -sql "SELECT name, man_made, operator, capacity, osm_id FROM multipolygons WHERE man_made IN ('water_works','wastewater_plant')"

# Dams and point features
ogr2ogr -f GeoJSON water_points.geojson \
  europe_water.osm.pbf points \
  -sql "SELECT name, man_made, waterway, operator, osm_id FROM points WHERE man_made IN ('pumping_station','water_tower') OR waterway IN ('dam','weir')"

# Dam linestrings
ogr2ogr -f GeoJSON water_dams_lines.geojson \
  europe_water.osm.pbf lines \
  -sql "SELECT name, waterway, operator, osm_id FROM lines WHERE waterway='dam'"
```

### Step 3: Generate Tiles

```bash
tippecanoe \
  -o osm_water.mbtiles \
  -z14 -Z4 \
  --drop-densest-as-needed \
  -l water_facilities water_facilities.geojson \
  -l water_points water_points.geojson \
  -l water_dams water_dams_lines.geojson
```

---

## Data Quality

| Feature Type | Global Coverage | Attribute Completeness |
|-------------|----------------|----------------------|
| Treatment plants | Moderate (well-mapped in OECD countries) | Name: ~70%, Operator: ~40%, Capacity: ~10% |
| Dams | Good (major dams globally mapped) | Name: ~80%, Operator: ~30% |
| Pumping stations | Variable | Name: ~50%, Operator: ~20% |
| Reservoirs | Good (large reservoirs) | Name: ~60% |

For the United States and Australia, authoritative sources ([EPA SDWIS](02d2-EPA-SDWIS.md),
[NID](02d4-NID-DAMS.md), [BoM](02d5-BOM-AUSTRALIA.md)) provide higher-quality data.
OSM fills gaps globally and adds features not present in official datasets (e.g.,
small pumping stations, weirs).

---

## References

OpenStreetMap contributors. (2026). *OpenStreetMap*. https://www.openstreetmap.org/

OpenStreetMap Wiki. (2026). *Tag:man_made=water_works*. https://wiki.openstreetmap.org/wiki/Tag:man_made%3Dwater_works

OpenStreetMap Wiki. (2026). *Tag:man_made=wastewater_plant*. https://wiki.openstreetmap.org/wiki/Tag:man_made%3Dwastewater_plant

---

## Related Pages

- **Parent**: [Water Infrastructure](02d-WATER.md)
- **Siblings**: [EPA SDWIS](02d2-EPA-SDWIS.md) | [EEA WISE](02d3-EEA-WISE.md) | [NID Dams](02d4-NID-DAMS.md) | [BoM Water](02d5-BOM-AUSTRALIA.md)
- **Shared PBF**: [OSM Power](02c1-OSM-POWER.md) | [OSM Telecoms](02e-TELECOMS.md)
- **Pipeline**: [OSM Extraction](04b-EXTRACT.md) | [Conversion](04c-CONVERT.md)
