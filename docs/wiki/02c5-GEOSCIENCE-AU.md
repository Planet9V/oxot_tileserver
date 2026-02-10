> **Last Updated**: 2026-02-11 01:00 UTC

[Home](INDEX.md) > [Data Sources](02-DATA-SOURCES.md) > [Electric Grid](02c-ELECTRIC.md) > Geoscience Australia

# Geoscience Australia Digital Atlas

Geoscience Australia (GA) publishes authoritative geospatial data for Australia's
energy and resource infrastructure. The Digital Atlas includes high-voltage
transmission lines, substations, major power stations, pipelines, and mining
operations. For the OXOT Tileserver, the energy infrastructure layers provide
the definitive Australian electric grid coverage.

---

## Quick Reference

| Attribute | Value |
|-----------|-------|
| **Provider** | Geoscience Australia (Australian Government) |
| **URL** | https://www.ga.gov.au/digital-publication/aecr2024/energy-resources |
| **Data Portal** | https://data.gov.au/ (search "Geoscience Australia energy") |
| **Coverage** | Australia |
| **Format** | Shapefile, GeoJSON, GeoPackage |
| **Voltage Threshold** | >= 66 kV (transmission) |
| **Size (raw)** | ~500 MB (energy infrastructure layers) |
| **Size (tiles)** | ~200 MB (MBTiles) |
| **Update Cadence** | Annual (Australian Energy and Critical Resources report) |
| **License** | CC BY 4.0 |
| **OXOT Option** | C and above |

---

## Available Layers

| Layer | Geometry | Features | Key Attributes |
|-------|----------|----------|----------------|
| Transmission lines | LineString | ~5,000 segments | Voltage kV, owner, status |
| Substations | Point | ~1,500 | Name, voltage kV, type |
| Major power stations | Point | ~400 | Fuel type, capacity MW, owner |
| Pipelines (gas/oil) | LineString | ~3,000 segments | Type, operator, diameter |
| Mining operations | Point | ~2,000 | Commodity, operator, status |

---

## Key Attributes

### Transmission Lines

| Field | Type | Description |
|-------|------|-------------|
| `LINE_NAME` | String | Line designation |
| `VOLTAGE_KV` | Number | Nominal voltage in kilovolts |
| `OWNER` | String | Network owner (e.g., TransGrid, ElectraNet) |
| `STATUS` | String | Operational, planned, decommissioned |
| `STATE` | String | State/territory code |

### Major Power Stations

| Field | Type | Description |
|-------|------|-------------|
| `STATION_NAME` | String | Facility name |
| `FUEL_TYPE` | String | Primary fuel (coal, gas, hydro, wind, solar) |
| `CAPACITY_MW` | Number | Nameplate capacity |
| `OWNER` | String | Operating company |
| `STATE` | String | State/territory code |
| `LATITUDE` / `LONGITUDE` | Number | WGS 84 coordinates |

---

## Download

### Data.gov.au

```bash
# Search and download from data.gov.au
wget -O ga_transmission.zip \
  "https://data.gov.au/data/dataset/XXXX/resource/YYYY/download/transmission_lines.zip"
unzip ga_transmission.zip
```

> **Note**: Dataset URLs change with each annual release. Search for
> "Geoscience Australia electricity transmission" on data.gov.au for the
> current download link.

### Direct from GA

Geoscience Australia also provides a WFS service:

```bash
ogr2ogr -f GeoJSON ga_transmission.geojson \
  "WFS:https://services.ga.gov.au/gis/services/Energy_Infrastructure/MapServer/WFSServer" \
  Electricity_Transmission_Lines
```

---

## Conversion Pipeline

### Step 1: Reproject (if Needed)

GA data is typically published in GDA2020 (EPSG:7844). Reproject to WGS 84:

```bash
ogr2ogr -f GeoJSON -t_srs EPSG:4326 \
  ga_transmission_wgs84.geojson ga_transmission.geojson
```

### Step 2: Generate Tiles

```bash
tippecanoe \
  -o geoscience_au.mbtiles \
  -z14 -Z2 \
  --drop-densest-as-needed \
  -l au_transmission ga_transmission_wgs84.geojson \
  -l au_substations ga_substations_wgs84.geojson \
  -l au_power_stations ga_power_stations_wgs84.geojson
```

---

## Overlap with OSM

For Australia, Geoscience Australia provides the authoritative layer for
transmission-level infrastructure (>= 66 kV). OSM adds value at the
distribution level (< 66 kV) and for features GA does not publish (e.g.,
solar farms < 10 MW, small wind installations). The OXOT pipeline merges
both using the proximity-based deduplication described in
[OSM Power Infrastructure](02c1-OSM-POWER.md).

---

## Quality Notes

- **Completeness**: GA covers all major (>= 66 kV) transmission infrastructure.
  Medium-voltage (11-33 kV) distribution is not included.
- **Currency**: The annual release typically reflects data from the prior financial
  year (ending June 30).
- **Mining data**: While included in the download, mining operations are outside
  the scope of the standard OXOT Tileserver electric grid layers. They can be
  optionally enabled for resource-sector analysis.

---

## References

Geoscience Australia. (2024). *Australian energy and critical resources 2024*. Australian Government. https://www.ga.gov.au/digital-publication/aecr2024

Geoscience Australia. (2024). *Energy infrastructure spatial data*. Australian Government. https://data.gov.au/

---

## Related Pages

- **Parent**: [Electric Grid](02c-ELECTRIC.md)
- **Siblings**: [OSM Power](02c1-OSM-POWER.md) | [EIA](02c2-EIA.md) | [HIFLD](02c3-HIFLD.md) | [ENTSO-E](02c4-ENTSOE.md)
- **Australian Data**: [ABS Census](02b3-ABS-AUSTRALIA.md) | [BoM Water](02d5-BOM-AUSTRALIA.md)
- **Pipeline**: [Conversion & Tippecanoe](04c-CONVERT.md)
