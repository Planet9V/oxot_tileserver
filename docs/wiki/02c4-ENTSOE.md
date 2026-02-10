> **Last Updated**: 2026-02-11 01:00 UTC

[Home](INDEX.md) > [Data Sources](02-DATA-SOURCES.md) > [Electric Grid](02c-ELECTRIC.md) > ENTSO-E / GridKit

# ENTSO-E / GridKit

The European Network of Transmission System Operators for Electricity (ENTSO-E)
coordinates the operation and development of Europe's high-voltage electricity
grid. GridKit is a research-grade extraction of the ENTSO-E interactive map that
provides cleaned, topologically consistent network data for academic and
operational use.

---

## Quick Reference

| Attribute | Value |
|-----------|-------|
| **Provider (Primary)** | ENTSO-E |
| **Provider (Extract)** | GridKit (Zenodo) |
| **URL (ENTSO-E Map)** | https://www.entsoe.eu/data/map/ |
| **URL (GridKit)** | https://zenodo.org/records/47317 |
| **Coverage** | ENTSO-E member countries (35 European TSOs) |
| **Format** | CSV with WKT geometry (GridKit); Interactive map (ENTSO-E) |
| **Voltage Threshold** | >= 220 kV (GridKit default) |
| **Size** | ~200 MB (GridKit extraction) |
| **Update Cadence** | Irregular (GridKit: research snapshots; ENTSO-E map: annual) |
| **License** | GridKit: CC0 / Public Domain; ENTSO-E data: Terms of use |
| **OXOT Option** | C and above |

---

## ENTSO-E Interactive Map

The ENTSO-E Transmission System Map shows:

- Cross-border interconnections
- High-voltage substations (>= 220 kV)
- Transmission lines with voltage and circuit count
- Planned infrastructure (TYNDP projects)

The map is interactive but does not offer bulk download. For geospatial extraction,
the OXOT pipeline uses GridKit.

---

## GridKit Dataset

GridKit was developed by Wiegmans (2016) as a cleaned extraction of ENTSO-E map
data, processed to produce topologically valid network graphs.

### Network Components

| Component | Description | Geometry | Count (approx.) |
|-----------|-------------|----------|-----------------|
| Buses (nodes) | Substations / switching stations | Point | ~5,000 |
| Links (edges) | Transmission lines / cables | LineString | ~7,000 |
| Generators | Power plants connected to grid | Point | ~3,000 |

### Key Attributes: Buses

| Field | Type | Description |
|-------|------|-------------|
| `bus_id` | Integer | Unique node identifier |
| `station_id` | Integer | Physical station identifier |
| `voltage` | Number | Nominal voltage (V) |
| `dc` | Boolean | DC interconnector |
| `symbol` | String | Substation symbol type |
| `under_construction` | Boolean | Planned / in build |
| `tags` | JSON | OSM-style key-value tags |
| `wkt_srid_4326` | WKT | Point geometry (WGS 84) |

### Key Attributes: Links

| Field | Type | Description |
|-------|------|-------------|
| `link_id` | Integer | Unique edge identifier |
| `bus0` / `bus1` | Integer | Start/end bus IDs |
| `voltage` | Number | Nominal voltage (V) |
| `circuits` | Integer | Number of circuits |
| `length_m` | Number | Length in metres |
| `dc` | Boolean | DC link |
| `under_construction` | Boolean | Planned |
| `wkt_srid_4326` | WKT | LineString geometry (WGS 84) |

---

## Network Topology

GridKit's primary value over raw OSM data is **topological consistency**:

- Every link connects exactly two buses.
- Bus locations are snapped to a consistent network graph.
- Duplicate and broken lines are removed.
- The resulting graph is suitable for network analysis (power flow, connectivity,
  cascade simulation).

This makes GridKit particularly valuable for the OXOT Cyber Digital Twin, which
models cascade failure scenarios.

---

## Conversion Pipeline

### Step 1: Download GridKit

```bash
wget https://zenodo.org/records/47317/files/gridkit-europe.zip
unzip gridkit-europe.zip
```

### Step 2: Convert WKT to GeoJSON

```python
import csv
import json

def wkt_to_geojson(wkt):
    """Convert WKT POINT or LINESTRING to GeoJSON geometry."""
    # Simplified; use shapely for production
    from shapely import wkt as swkt
    geom = swkt.loads(wkt)
    return json.loads(json.dumps(geom.__geo_interface__))

features = []
with open("gridkit-europe-buses.csv") as f:
    reader = csv.DictReader(f)
    for row in reader:
        features.append({
            "type": "Feature",
            "geometry": wkt_to_geojson(row["wkt_srid_4326"]),
            "properties": {
                "bus_id": int(row["bus_id"]),
                "voltage_kv": int(row["voltage"]) / 1000 if row["voltage"] else None,
                "dc": row["dc"] == "t",
                "name": row.get("tags", {}).get("name", "")
            }
        })

with open("gridkit_buses.geojson", "w") as f:
    json.dump({"type": "FeatureCollection", "features": features}, f)
```

Repeat for links.

### Step 3: Generate Tiles

```bash
tippecanoe \
  -o entsoe_grid.mbtiles \
  -z14 -Z2 \
  --drop-densest-as-needed \
  -l entsoe_buses gridkit_buses.geojson \
  -l entsoe_links gridkit_links.geojson
```

---

## Limitations

- **Vintage**: The Zenodo GridKit extraction is from 2016 data. For more recent
  data, consider extracting from OSM using the same tag filters with the
  `power=line` + `voltage>=220000` combination.
- **Coverage gaps**: Some TSOs (e.g., Turkey) have limited data in the ENTSO-E map.
- **Distribution grid**: GridKit only covers transmission (>= 220 kV). For lower
  voltages, use [OSM Power](02c1-OSM-POWER.md).

---

## References

European Network of Transmission System Operators for Electricity. (2025). *ENTSO-E transmission system map*. https://www.entsoe.eu/data/map/

Wiegmans, B. (2016). *GridKit: European and North American high-voltage power grid extraction* [Dataset]. Zenodo. https://doi.org/10.5281/zenodo.47317

---

## Related Pages

- **Parent**: [Electric Grid](02c-ELECTRIC.md)
- **Siblings**: [OSM Power](02c1-OSM-POWER.md) | [EIA](02c2-EIA.md) | [HIFLD](02c3-HIFLD.md) | [Geoscience AU](02c5-GEOSCIENCE-AU.md)
- **Pipeline**: [Conversion & Tippecanoe](04c-CONVERT.md)
- **Integration**: [OXOT Cyber DT](06d-OXOT-CYBERDT.md) (cascade modelling)
