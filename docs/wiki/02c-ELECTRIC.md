> **Last Updated**: 2026-02-11 01:00 UTC

[Home](INDEX.md) > [Data Sources](02-DATA-SOURCES.md) > Electric Grid

# Electric Grid

This hub covers the six data sources that provide electric power infrastructure
layers for the OXOT Tileserver. These layers map generation assets (power plants),
transmission networks (high-voltage lines and substations), and distribution
infrastructure across four coverage regions: global (via OpenStreetMap), United States,
European Union, and Australia.

---

## Source Summary

| # | Source | Coverage | Features | Approx. Tile Size | License |
|---|--------|----------|----------|-------------------|---------|
| 1 | [OSM Power Infrastructure](02c1-OSM-POWER.md) | Global | Lines, substations, plants, generators | ~500 MB - 2 GB per region | ODbL |
| 2 | [EIA US Energy Atlas](02c2-EIA.md) | US | 10,000+ plants, transmission, pipelines | ~100 MB | Public Domain |
| 3 | [HIFLD Open Data](02c3-HIFLD.md) | US | Multi-sector incl. electric substations | ~3 GB (all sectors) | Public Domain |
| 4 | [ENTSO-E / GridKit](02c4-ENTSOE.md) | EU | HV grid >= 220 kV, network topology | ~200 MB | Various |
| 5 | [Geoscience Australia](02c5-GEOSCIENCE-AU.md) | AU | Transmission >= 66 kV, major plants | ~200 MB | CC BY 4.0 |
| 6 | [Awesome Electrical Grid Mapping](02c6-AWESOME-GRID-MAPPING.md) | Global | Curated catalog of 150+ country grid datasets | Varies by source | CC0-1.0 |

---

## Regional Coverage

| Region | Primary Source | Supplement | Quality |
|--------|---------------|------------|---------|
| United States | EIA Energy Atlas | HIFLD, OSM | Excellent (authoritative federal data) |
| European Union | ENTSO-E / GridKit | OSM | Good (HV authoritative; MV/LV via OSM) |
| Australia | Geoscience Australia | OSM | Good (transmission authoritative) |
| Rest of World | OSM Power | -- | Variable (depends on local mapping effort) |

---

## Layer Architecture

Electric sources are combined into a unified layer set within the OXOT Tileserver:

| Layer Name | Geometry | Source(s) | Min Zoom | Max Zoom |
|------------|----------|-----------|----------|----------|
| `power_plants` | Point | EIA, OSM, Geoscience AU | 2 | 14 |
| `power_lines` | LineString | OSM, EIA, ENTSO-E, Geoscience AU | 4 | 14 |
| `substations` | Point/Polygon | HIFLD, OSM, Geoscience AU | 6 | 14 |
| `generators` | Point | OSM, EIA | 6 | 14 |

Where multiple sources overlap (e.g., US plants in both EIA and OSM), the
authoritative government source takes precedence, with OSM filling gaps.

---

## Common Attributes

Regardless of source, all electric features are normalised to a common schema:

| Field | Type | Description |
|-------|------|-------------|
| `name` | String | Facility name |
| `operator` | String | Operating entity |
| `voltage_kv` | Number | Voltage in kilovolts |
| `fuel_type` | String | Primary fuel (coal, gas, nuclear, solar, wind, hydro) |
| `capacity_mw` | Number | Nameplate capacity in megawatts |
| `source` | String | Origin dataset (eia, osm, entsoe, geoscience_au) |
| `source_id` | String | Original feature ID from the source |

---

## Children Pages

| Page | Description |
|------|-------------|
| [02c1 - OSM Power Infrastructure](02c1-OSM-POWER.md) | Global power tags from Geofabrik PBF extracts |
| [02c2 - EIA US Energy Atlas](02c2-EIA.md) | US federal plant, transmission, and pipeline data |
| [02c3 - HIFLD Open Data](02c3-HIFLD.md) | DHS/CISA multi-sector infrastructure |
| [02c4 - ENTSO-E / GridKit](02c4-ENTSOE.md) | European high-voltage grid and network topology |
| [02c5 - Geoscience Australia](02c5-GEOSCIENCE-AU.md) | Australian transmission, substations, and plants |
| [02c6 - Awesome Electrical Grid Mapping](02c6-AWESOME-GRID-MAPPING.md) | Curated global catalog of grid data from 150+ countries |

---

## Related Pages

- **Parent**: [Data Sources](02-DATA-SOURCES.md)
- **Siblings**: [Basemap](02a-BASEMAP.md) | [Demographics](02b-DEMOGRAPHICS.md) | [Water](02d-WATER.md) | [Telecoms](02e-TELECOMS.md)
- **Pipeline**: [OSM Extraction](04b-EXTRACT.md) | [Conversion & Tippecanoe](04c-CONVERT.md)
- **Integration**: [OXOT Cyber DT](06d-OXOT-CYBERDT.md)
- **Supplementary**: [Awesome Electrical Grid Mapping](02c6-AWESOME-GRID-MAPPING.md) | [Cyber Attack Mapping](13a-CYBER-ATTACK-MAPPING.md)
