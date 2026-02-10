> **Last Updated**: 2026-02-11 01:00 UTC

[Home](INDEX.md) > [Data Sources](02-DATA-SOURCES.md) > Water Infrastructure

# Water Infrastructure

This hub covers the five data sources that provide water and wastewater
infrastructure layers for the OXOT Tileserver. These layers map treatment plants,
dams, reservoirs, distribution networks, and regulatory compliance data across
four coverage regions: global (via OpenStreetMap), United States, European Union,
and Australia.

---

## Source Summary

| # | Source | Coverage | Features | Approx. Tile Size | License |
|---|--------|----------|----------|-------------------|---------|
| 1 | [OSM Water Tags](02d1-OSM-WATER.md) | Global | Treatment plants, dams, reservoirs, pumping | Shared with OSM PBF | ODbL |
| 2 | [EPA SDWIS + WATERS](02d2-EPA-SDWIS.md) | US | 50,000+ water systems, violations, boundaries | ~2 GB | Public Domain |
| 3 | [EEA WISE](02d3-EEA-WISE.md) | EU | River basins, water bodies, WFD status | ~1 GB | EEA Standard |
| 4 | [National Inventory of Dams](02d4-NID-DAMS.md) | US | 92,075+ dams with hazard classification | ~20 MB | Public Domain |
| 5 | [Australian BoM Water](02d5-BOM-AUSTRALIA.md) | AU | Catchments, rivers, storage levels | ~500 MB | CC BY 4.0 |

---

## Regional Coverage

| Region | Primary Source | Supplement | Quality |
|--------|---------------|------------|---------|
| United States | EPA SDWIS + NID | HIFLD, OSM | Excellent (authoritative federal data) |
| European Union | EEA WISE | OSM | Good (WFD compliance data) |
| Australia | BoM Geofabric | OSM | Good (catchment-level; plant-level via OSM) |
| Rest of World | OSM Water | -- | Variable |

---

## Layer Architecture

Water sources are combined into a unified layer set:

| Layer Name | Geometry | Source(s) | Min Zoom | Max Zoom |
|------------|----------|-----------|----------|----------|
| `water_treatment` | Point/Polygon | EPA, OSM, HIFLD | 4 | 14 |
| `wastewater` | Point/Polygon | EPA, OSM, HIFLD | 4 | 14 |
| `dams` | Point | NID, OSM, BoM | 4 | 14 |
| `reservoirs` | Polygon | OSM, BoM | 6 | 14 |
| `river_basins` | Polygon | EEA WISE, BoM | 0 | 10 |
| `water_systems` | Polygon | EPA SDWIS | 6 | 14 |

---

## Common Attributes

| Field | Type | Description |
|-------|------|-------------|
| `name` | String | Facility / feature name |
| `operator` | String | Operating entity |
| `capacity` | Number | Treatment capacity (MGD, ML/d, or m3/d) |
| `type` | String | Drinking water, wastewater, dam, reservoir |
| `hazard_class` | String | Dam hazard: high, significant, low (NID only) |
| `source` | String | Origin dataset |

---

## Children Pages

| Page | Description |
|------|-------------|
| [02d1 - OSM Water Tags](02d1-OSM-WATER.md) | Global water infrastructure from OpenStreetMap |
| [02d2 - EPA SDWIS + WATERS](02d2-EPA-SDWIS.md) | US drinking water systems and service areas |
| [02d3 - EEA WISE](02d3-EEA-WISE.md) | European water bodies and WFD compliance |
| [02d4 - National Inventory of Dams](02d4-NID-DAMS.md) | US dam inventory with hazard classification |
| [02d5 - Australian BoM Water](02d5-BOM-AUSTRALIA.md) | Australian catchments, rivers, and storage |

---

## Related Pages

- **Parent**: [Data Sources](02-DATA-SOURCES.md)
- **Siblings**: [Basemap](02a-BASEMAP.md) | [Demographics](02b-DEMOGRAPHICS.md) | [Electric](02c-ELECTRIC.md) | [Telecoms](02e-TELECOMS.md)
- **Cross-sector**: [HIFLD](02c3-HIFLD.md) (wastewater, dams)
- **Pipeline**: [OSM Extraction](04b-EXTRACT.md) | [Conversion](04c-CONVERT.md)
- **Integration**: [OXOT Cyber DT](06d-OXOT-CYBERDT.md)
