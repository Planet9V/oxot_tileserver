> **Last Updated**: 2026-02-11 01:00 UTC

[Home](INDEX.md) > [Data Sources](02-DATA-SOURCES.md) > Telecoms Infrastructure

# OSM Telecoms Infrastructure

OpenStreetMap provides the primary open-data source for telecommunications
infrastructure worldwide. Mapped features include cell towers (masts), data
centres, telephone exchanges, and fibre-optic routes. These features are
extracted from the same Geofabrik PBF files used for
[OSM Power](02c1-OSM-POWER.md) and [OSM Water](02d1-OSM-WATER.md).

---

## Quick Reference

| Attribute | Value |
|-----------|-------|
| **Provider** | OpenStreetMap contributors (via Geofabrik) |
| **URL** | https://download.geofabrik.de/ |
| **Coverage** | Global |
| **Format** | PBF (shared with power/water) |
| **Key Features** | 600K+ masts, 3,500+ data centres, exchanges, fibre |
| **Size (PBF)** | Shared -- see [OSM Power](02c1-OSM-POWER.md) |
| **Size (tiles)** | ~100 MB - 500 MB per region (telecoms-only) |
| **License** | ODbL |
| **OXOT Option** | E (Full) only |

---

## Relevant OSM Tags

| Tag | Values | Feature Type | Global Count (est.) |
|-----|--------|-------------|---------------------|
| `man_made=mast` + `tower:type=communication` | -- | Cell/radio tower (Node) | ~600,000 |
| `man_made=tower` + `tower:type=communication` | -- | Communication tower (Node) | ~50,000 |
| `telecom=data_centre` | -- | Data centre (Node or Way) | ~3,500 |
| `telecom=exchange` | -- | Telephone exchange (Node or Way) | ~15,000 |
| `telecom=central_office` | -- | Central office (Node or Way) | ~2,000 |
| `man_made=street_cabinet` + `street_cabinet=telecom` | -- | Street cabinet (Node) | ~100,000 |
| `utility=telecom` + `location=underground` | -- | Fibre/cable route (Way) | Variable |
| `communication:mobile_phone` | yes | Mobile phone coverage indicator | Variable |
| `operator` | String | Network operator | ~40% tagged |
| `ref` | String | Site reference code | ~20% tagged |

---

## Extraction Pipeline

### Step 1: Filter Telecoms Tags from PBF

```bash
osmium tags-filter europe-latest.osm.pbf \
  nwr/telecom \
  n/man_made=mast,tower \
  n/man_made=street_cabinet \
  -o europe_telecoms.osm.pbf
```

> **Note**: The `man_made=mast` filter includes non-telecom masts (flagpoles,
> lighting). Post-filter with `tower:type=communication` to isolate cell towers.

### Step 2: Convert to GeoJSON

```bash
# Cell towers and masts
ogr2ogr -f GeoJSON telecoms_towers.geojson \
  europe_telecoms.osm.pbf points \
  -sql "SELECT name, operator, ref, osm_id FROM points WHERE (man_made='mast' OR man_made='tower') AND \"tower:type\"='communication'"

# Data centres
ogr2ogr -f GeoJSON telecoms_datacentres.geojson \
  europe_telecoms.osm.pbf multipolygons \
  -sql "SELECT name, operator, osm_id FROM multipolygons WHERE telecom='data_centre'"

# Exchanges
ogr2ogr -f GeoJSON telecoms_exchanges.geojson \
  europe_telecoms.osm.pbf points \
  -sql "SELECT name, operator, telecom, osm_id FROM points WHERE telecom IN ('exchange','central_office')"
```

### Step 3: Generate Tiles

```bash
tippecanoe \
  -o osm_telecoms.mbtiles \
  -z14 -Z4 \
  --drop-densest-as-needed \
  --extend-zooms-if-still-dropping \
  -l cell_towers telecoms_towers.geojson \
  -l data_centres telecoms_datacentres.geojson \
  -l exchanges telecoms_exchanges.geojson
```

---

## Data Quality and Coverage

### Quality by Feature Type

| Feature Type | Global Quality | Notes |
|-------------|---------------|-------|
| Cell towers / masts | Good in OECD | Many countries have systematic imports |
| Data centres | Moderate | Major facilities mapped; smaller colocation missing |
| Exchanges | Fair | Good in UK/DE/FR; sparse elsewhere |
| Fibre routes | Poor | Rarely mapped; use carrier data where available |
| Street cabinets | Variable | Very good in UK/NL; sparse elsewhere |

### Regional Notes

- **United Kingdom**: Excellent telecoms mapping. Ordnance Survey open data has
  driven comprehensive street cabinet and exchange mapping.
- **Germany**: Good mast coverage. Deutsche Telekom infrastructure well-mapped.
- **United States**: Moderate. FCC tower registrations not systematically imported
  into OSM. Consider supplementing with HIFLD cell tower data.
- **Australia**: Fair. Major towers mapped; regional gaps.

### Supplementary Sources

For US telecoms, consider supplementing OSM with:

- **HIFLD Cell Towers**: ~200,000 registered tower locations (see [HIFLD](02c3-HIFLD.md))
- **FCC Antenna Structure Registration**: https://www.fcc.gov/antenna-structure-registration
- **NTIA Broadband Map**: https://broadbandmap.fcc.gov/

These are not included in the standard OXOT pipeline but can be added as
custom layers.

---

## Layer Styling Recommendations

| Feature | Symbol | Min Zoom | Colour Suggestion |
|---------|--------|----------|-------------------|
| Cell tower | Triangle | 8 | Orange |
| Data centre | Square | 6 | Blue |
| Exchange | Circle | 8 | Purple |
| Fibre route | Dashed line | 10 | Cyan |
| Street cabinet | Small dot | 12 | Grey |

At lower zoom levels (4-7), cluster cell towers using `--cluster-distance=20`
in tippecanoe to avoid visual overload.

---

## References

OpenStreetMap contributors. (2026). *OpenStreetMap*. https://www.openstreetmap.org/

OpenStreetMap Wiki. (2026). *Key:telecom*. https://wiki.openstreetmap.org/wiki/Key:telecom

OpenStreetMap Wiki. (2026). *Tag:man_made=mast*. https://wiki.openstreetmap.org/wiki/Tag:man_made%3Dmast

Geofabrik GmbH. (2026). *OpenStreetMap data extracts*. https://download.geofabrik.de/

---

## Related Pages

- **Parent**: [Data Sources](02-DATA-SOURCES.md)
- **Siblings**: [Basemap](02a-BASEMAP.md) | [Demographics](02b-DEMOGRAPHICS.md) | [Electric](02c-ELECTRIC.md) | [Water](02d-WATER.md)
- **Shared PBF**: [OSM Power](02c1-OSM-POWER.md) | [OSM Water](02d1-OSM-WATER.md)
- **Cross-sector**: [HIFLD](02c3-HIFLD.md) (cell towers)
- **Pipeline**: [OSM Extraction](04b-EXTRACT.md) | [Conversion](04c-CONVERT.md)
- **Integration**: [OXOT Cyber DT](06d-OXOT-CYBERDT.md)
