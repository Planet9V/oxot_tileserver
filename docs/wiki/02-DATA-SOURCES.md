> **Last Updated**: 2026-02-11 01:00 UTC

[Home](INDEX.md) > Data Sources

# Data Sources

This hub page catalogues the 22 open-data sources consumed by the OXOT Tileserver.
Each source is downloaded, converted to vector tiles (MBTiles or PMTiles), and served
through tileserver-gl or a PMTiles-compatible endpoint. Sources are grouped into five
domain categories and mapped to the five installation options (A through E).

---

## Source Inventory

| # | Name | Coverage | Domain | Format | Native? | Approx. Size | License |
|---|------|----------|--------|--------|---------|-------------|---------|
| 1 | [Protomaps Basemap](02a-BASEMAP.md) | Global | Basemap | PMTiles | Yes | ~120 GB planet / ~15 GB 3-region | ODbL |
| 2 | [OpenMapTiles / MapTiler](02a-BASEMAP.md) | Global | Basemap | MBTiles | Yes | ~80 GB | ODbL |
| 3 | [OpenFreeMap](02a-BASEMAP.md) | Global | Basemap | MBTiles | Yes | ~80 GB | ODbL |
| 4 | [US Census TIGER/Line + ACS](02b1-CENSUS-US.md) | US | Demographics | SHP/GeoJSON | No | ~15 GB raw / ~5 GB tiles | Public Domain |
| 5 | [Eurostat NUTS + Nuts2json](02b2-EUROSTAT.md) | EU | Demographics | GeoJSON | No | ~50 MB - 2 GB | CC BY 4.0 |
| 6 | [ABS Census Boundaries](02b3-ABS-AUSTRALIA.md) | AU | Demographics | SHP/GeoJSON | No | ~1 GB raw / ~500 MB tiles | CC BY 4.0 |
| 7 | [Stats NZ Boundaries](02b4-STATS-NZ.md) | NZ | Demographics | SHP/GeoJSON | No | ~200 MB raw / ~100 MB tiles | CC BY 4.0 |
| 8 | [GeoNames Cities](02b5-GEONAMES.md) | Global | Demographics | TSV | No | ~1.5 MB / ~20 MB tiles | CC BY 4.0 |
| 9 | [Natural Earth Populated Places](02b5-GEONAMES.md) | Global | Demographics | SHP | No | ~5 MB / ~10 MB tiles | Public Domain |
| 10 | [OSM Power Infrastructure](02c1-OSM-POWER.md) | Global | Electric | PBF | No | ~4-12 GB per region | ODbL |
| 11 | [EIA US Energy Atlas](02c2-EIA.md) | US | Electric | SHP/GeoJSON | No | ~200 MB / ~100 MB tiles | Public Domain |
| 12 | [HIFLD Open Data](02c3-HIFLD.md) | US | Electric + Multi | SHP/GeoJSON | No | ~5 GB / ~3 GB tiles | Public Domain |
| 13 | [ENTSO-E / GridKit](02c4-ENTSOE.md) | EU | Electric | CSV/GeoJSON | No | ~200 MB | Various |
| 14 | [Geoscience Australia](02c5-GEOSCIENCE-AU.md) | AU | Electric | SHP/GeoJSON | No | ~500 MB / ~200 MB tiles | CC BY 4.0 |
| 22 | [Awesome Grid Mapping](02c6-AWESOME-GRID-MAPPING.md) | Global | Electric | Various | No | Varies by source | CC0-1.0 |
| 15 | [OSM Water Tags](02d1-OSM-WATER.md) | Global | Water | PBF | No | Shared with #10 | ODbL |
| 16 | [EPA SDWIS + WATERS](02d2-EPA-SDWIS.md) | US | Water | SHP/GeoJSON | No | ~3 GB / ~2 GB tiles | Public Domain |
| 17 | [EEA WISE](02d3-EEA-WISE.md) | EU | Water | SHP/GeoJSON | No | ~2 GB / ~1 GB tiles | EEA Standard |
| 18 | [National Inventory of Dams](02d4-NID-DAMS.md) | US | Water | CSV/SHP | No | ~50 MB / ~20 MB tiles | Public Domain |
| 19 | [Australian BoM Water](02d5-BOM-AUSTRALIA.md) | AU | Water | SHP/GeoJSON | No | ~1 GB / ~500 MB tiles | CC BY 4.0 |
| 20 | [OSM Telecoms](02e-TELECOMS.md) | Global | Telecoms | PBF | No | Shared with #10 | ODbL |
| 21 | GeoNames (duplicate count -- see #8) | Global | Demographics | TSV | No | ~1.5 MB | CC BY 4.0 |

> **Native?** indicates whether the source ships in a tile format that tileserver-gl
> can serve without conversion. Only basemap providers distribute pre-built MBTiles or PMTiles.

---

## Categories

### Basemap (3 sources)
Base cartography providing roads, buildings, land-use, and labels.
See **[Basemap Sources](02a-BASEMAP.md)**.

### Demographics (7 sources)
Census boundaries, population data, and city points for four countries plus a global gazetteer.
See **[Demographics & Population](02b-DEMOGRAPHICS.md)** and children
[02b1](02b1-CENSUS-US.md) | [02b2](02b2-EUROSTAT.md) | [02b3](02b3-ABS-AUSTRALIA.md) | [02b4](02b4-STATS-NZ.md) | [02b5](02b5-GEONAMES.md).

### Electric Grid (6 sources)
Generation, transmission, and distribution infrastructure.
See **[Electric Grid](02c-ELECTRIC.md)** and children
[02c1](02c1-OSM-POWER.md) | [02c2](02c2-EIA.md) | [02c3](02c3-HIFLD.md) | [02c4](02c4-ENTSOE.md) | [02c5](02c5-GEOSCIENCE-AU.md) | [02c6](02c6-AWESOME-GRID-MAPPING.md).

### Water Infrastructure (5 sources)
Treatment plants, dams, reservoirs, and regulatory data.
See **[Water Infrastructure](02d-WATER.md)** and children
[02d1](02d1-OSM-WATER.md) | [02d2](02d2-EPA-SDWIS.md) | [02d3](02d3-EEA-WISE.md) | [02d4](02d4-NID-DAMS.md) | [02d5](02d5-BOM-AUSTRALIA.md).

### Telecoms (1 source)
Cell towers, data centres, exchanges, and fibre routes.
See **[Telecoms Infrastructure](02e-TELECOMS.md)**.

---

## Source-to-Option Mapping

Installation options A through E progressively add layers. See [Installation Options](03b-OPTIONS.md).

| Source | A (Basemap) | B (+ Demographics) | C (+ Electric) | D (+ Water) | E (Full) |
|--------|:-----------:|:-------------------:|:---------------:|:-----------:|:--------:|
| Protomaps Basemap | X | X | X | X | X |
| OpenMapTiles (alt) | X | X | X | X | X |
| OpenFreeMap (alt) | X | X | X | X | X |
| US Census TIGER/ACS | | X | X | X | X |
| Eurostat NUTS | | X | X | X | X |
| ABS Census | | X | X | X | X |
| Stats NZ | | X | X | X | X |
| GeoNames / Natural Earth | | X | X | X | X |
| OSM Power | | | X | X | X |
| EIA Energy Atlas | | | X | X | X |
| HIFLD | | | X | X | X |
| ENTSO-E / GridKit | | | X | X | X |
| Geoscience AU | | | X | X | X |
| OSM Water | | | | X | X |
| EPA SDWIS | | | | X | X |
| EEA WISE | | | | X | X |
| NID Dams | | | | X | X |
| BoM Water AU | | | | X | X |
| OSM Telecoms | | | | | X |

---

## Overlap Analysis

Several sources share the same raw download (OSM PBF files). The table below
identifies reuse opportunities to minimise download and storage costs.

| Shared Download | Consumers | Implication |
|----------------|-----------|-------------|
| Geofabrik PBF (per region) | OSM Power, OSM Water, OSM Telecoms | One download, three `osmium tags-filter` passes |
| Natural Earth SHP | GeoNames supplement, Basemap supplement | One download, multiple layers |
| HIFLD ArcGIS Hub | Electric, Water, Emergency, Transport | Single portal, many feature services |

---

## Pipeline Summary

All non-native sources follow the same general pipeline:

1. **Download** -- scripted fetch from authoritative URL (see [Download Scripts](04a-DOWNLOAD.md))
2. **Extract / Filter** -- `osmium`, `ogr2ogr`, or custom parsers (see [OSM Extraction](04b-EXTRACT.md))
3. **Convert** -- `tippecanoe` to MBTiles (see [Conversion](04c-CONVERT.md))
4. **Load** -- copy to `data/` volume; restart tileserver-gl (see [Loading](04d-LOAD.md))

---

## Related Pages

- **Parent**: [Home](INDEX.md)
- **Children**: [02a Basemap](02a-BASEMAP.md) | [02b Demographics](02b-DEMOGRAPHICS.md) | [02c Electric](02c-ELECTRIC.md) | [02d Water](02d-WATER.md) | [02e Telecoms](02e-TELECOMS.md)
- **Use Cases**: [Use Cases & Implementation](13-USE-CASES.md)
- **Pipeline**: [Data Pipeline](04-PIPELINE.md)
- **Options**: [Installation Options A-E](03b-OPTIONS.md)
- **Glossary**: [Glossary](09-GLOSSARY.md)
