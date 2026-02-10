> **Last Updated**: 2026-02-11 01:00 UTC

[Home](INDEX.md) > [Data Sources](02-DATA-SOURCES.md) > [Electric Grid](02c-ELECTRIC.md) > OSM Power Infrastructure

# OSM Power Infrastructure

OpenStreetMap (OSM) is the largest open geospatial database in the world. Its
power-infrastructure tags cover transmission lines, substations, power plants,
and individual generators across every continent. For the OXOT Tileserver, power
data is extracted from Geofabrik regional PBF files using `osmium` tag filters.

---

## Quick Reference

| Attribute | Value |
|-----------|-------|
| **Provider** | OpenStreetMap contributors (via Geofabrik) |
| **URL** | https://download.geofabrik.de/ |
| **Coverage** | Global |
| **Format** | PBF (Protobuf Binary Format) |
| **Key Features** | 7M+ km power lines, 1M+ substations, 125K+ generators |
| **Size (PBF)** | Europe ~28 GB, N. America ~12 GB, AU ~1 GB, Planet ~75 GB |
| **Size (tiles)** | ~500 MB - 2 GB per region (power-only) |
| **Update Cadence** | Daily (Geofabrik), Minutely (planet replication) |
| **License** | ODbL |
| **OXOT Option** | C and above |

---

## Relevant OSM Tags

| Tag | Values | Feature Type |
|-----|--------|-------------|
| `power=line` | -- | Transmission / distribution line (LineString) |
| `power=minor_line` | -- | Low-voltage distribution (LineString) |
| `power=cable` | -- | Underground / submarine cable (LineString) |
| `power=substation` | transmission, distribution | Substation (Node or Way) |
| `power=plant` | -- | Power plant (Way or Relation) |
| `power=generator` | -- | Individual generator (Node) |
| `voltage` | e.g., 400000, 132000 | Volts (semicolon-separated for multi-circuit) |
| `cables` | 1, 2, 3, 6 | Number of cables per circuit |
| `operator` | String | Operating company |
| `generator:source` | solar, wind, hydro, gas, coal, nuclear | Fuel type |
| `generator:output:electricity` | e.g., 100 MW | Nameplate capacity |

---

## Geofabrik Regional Extracts

Geofabrik publishes daily regional PBF extracts. The same file serves power, water,
and telecoms extraction (see [OSM Water](02d1-OSM-WATER.md) and [Telecoms](02e-TELECOMS.md)).

| Region | File | Size | URL |
|--------|------|------|-----|
| Europe | europe-latest.osm.pbf | ~28 GB | https://download.geofabrik.de/europe-latest.osm.pbf |
| North America | north-america-latest.osm.pbf | ~12 GB | https://download.geofabrik.de/north-america-latest.osm.pbf |
| Australia-Oceania | australia-oceania-latest.osm.pbf | ~1 GB | https://download.geofabrik.de/australia-oceania-latest.osm.pbf |
| Planet | planet-latest.osm.pbf | ~75 GB | https://planet.openstreetmap.org/pbf/ |

> **Tip**: Download one PBF per region and run three `osmium tags-filter` passes
> (power, water, telecoms) to minimise bandwidth and storage.

---

## Extraction Pipeline

### Step 1: Filter Power Tags

```bash
osmium tags-filter europe-latest.osm.pbf \
  nwr/power=line,minor_line,cable,substation,plant,generator \
  -o europe_power.osm.pbf
```

### Step 2: Convert to GeoJSON

```bash
ogr2ogr -f GeoJSON europe_power_lines.geojson \
  europe_power.osm.pbf lines \
  -sql "SELECT name, voltage, cables, operator, osm_id FROM lines WHERE power IN ('line','minor_line','cable')"

ogr2ogr -f GeoJSON europe_power_points.geojson \
  europe_power.osm.pbf points \
  -sql "SELECT name, power, voltage, operator, 'generator:source' as fuel_type, osm_id FROM points WHERE power IN ('substation','plant','generator')"
```

### Step 3: Generate Vector Tiles

```bash
tippecanoe \
  -o osm_power.mbtiles \
  -z14 -Z4 \
  --drop-densest-as-needed \
  --extend-zooms-if-still-dropping \
  -l power_lines europe_power_lines.geojson \
  -l power_points europe_power_points.geojson
```

---

## Data Quality by Region

OSM power mapping quality varies significantly by region. The table below provides
a qualitative assessment:

| Region | Transmission | Distribution | Substations | Plants | Overall |
|--------|-------------|-------------|-------------|--------|---------|
| Western Europe | Excellent | Good | Excellent | Good | Excellent |
| North America | Good | Fair | Good | Fair | Good |
| Australia / NZ | Good | Fair | Good | Fair | Good |
| Eastern Europe | Good | Fair | Fair | Fair | Fair |
| South America | Fair | Poor | Fair | Fair | Fair |
| Africa | Poor | Poor | Poor | Poor | Poor |
| East Asia | Variable | Variable | Variable | Variable | Variable |

### Quality Validation

Use [OpenInfraMap.org](https://openinframap.org/) to visually inspect OSM power
data coverage and quality for a specific region before committing to an OSM-only
approach.

---

## Voltage Parsing

OSM stores voltage as a string, often semicolon-separated for multi-voltage
substations:

```
voltage=400000;132000
```

The OXOT pipeline parses this into a numeric `max_voltage_kv` field:

```python
def parse_voltage(v):
    if not v:
        return None
    parts = str(v).replace(" ", "").split(";")
    voltages = [int(p) / 1000 for p in parts if p.isdigit()]
    return max(voltages) if voltages else None
```

---

## Overlap with Authoritative Sources

For the US, EU, and Australia, authoritative government sources (EIA, ENTSO-E,
Geoscience AU) provide higher-quality data for major infrastructure. The OXOT
pipeline uses a merge strategy:

1. Load authoritative source as the primary layer.
2. Buffer authoritative features by 500 m.
3. Exclude OSM features within the buffer to avoid duplicates.
4. Add remaining OSM features as gap-fillers (especially distribution-level assets).

---

## References

OpenStreetMap contributors. (2026). *OpenStreetMap*. https://www.openstreetmap.org/

Geofabrik GmbH. (2026). *OpenStreetMap data extracts*. https://download.geofabrik.de/

OpenStreetMap Wiki. (2026). *Key:power*. https://wiki.openstreetmap.org/wiki/Key:power

OpenInfraMap. (2026). *OpenInfraMap: Open infrastructure map*. https://openinframap.org/

---

## Related Pages

- **Parent**: [Electric Grid](02c-ELECTRIC.md)
- **Siblings**: [EIA](02c2-EIA.md) | [HIFLD](02c3-HIFLD.md) | [ENTSO-E](02c4-ENTSOE.md) | [Geoscience AU](02c5-GEOSCIENCE-AU.md)
- **Shared PBF**: [OSM Water](02d1-OSM-WATER.md) | [OSM Telecoms](02e-TELECOMS.md)
- **Pipeline**: [OSM Extraction](04b-EXTRACT.md) | [Conversion](04c-CONVERT.md)
