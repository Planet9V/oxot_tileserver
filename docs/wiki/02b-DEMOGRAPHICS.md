> **Last Updated**: 2026-02-11 01:00 UTC

[Home](INDEX.md) > [Data Sources](02-DATA-SOURCES.md) > Demographics & Population

# Demographics & Population

This hub covers the seven demographic data sources used by the OXOT Tileserver.
These layers provide census boundaries, population statistics, and city-point
gazetteers for four countries (US, EU member states, Australia, New Zealand) plus
global city coverage.

---

## Source Summary

| # | Source | Coverage | Geometry Type | Key Attributes | Approx. Tile Size | License |
|---|--------|----------|---------------|----------------|-------------------|---------|
| 1 | [US Census TIGER/Line + ACS](02b1-CENSUS-US.md) | US | Polygon (tracts, block groups, ZCTAs) | Population, income, age, race, housing | ~5 GB | Public Domain |
| 2 | [Eurostat NUTS + Nuts2json](02b2-EUROSTAT.md) | EU (27+) | Polygon (NUTS 0-3) | Population, GDP, employment | ~50 MB - 200 MB | CC BY 4.0 |
| 3 | [ABS Census Boundaries](02b3-ABS-AUSTRALIA.md) | Australia | Polygon (SA1-SA4) | Population, income, age, ancestry | ~500 MB | CC BY 4.0 |
| 4 | [Stats NZ Boundaries](02b4-STATS-NZ.md) | New Zealand | Polygon (meshblock-TA) | Population, dwellings, ethnicity | ~100 MB | CC BY 4.0 |
| 5 | [GeoNames Cities](02b5-GEONAMES.md) | Global | Point (25,000+ cities) | Name, population, country, elevation | ~20 MB | CC BY 4.0 |
| 6 | [Natural Earth Populated Places](02b5-GEONAMES.md) | Global | Point (~7,300 cities) | Name, population, capital status | ~10 MB | Public Domain |

> Source 6 (Natural Earth) is documented alongside GeoNames in [02b5-GEONAMES.md](02b5-GEONAMES.md)
> because both serve a similar role as global city-point layers.

---

## Regional Coverage Matrix

| Region | Boundary Source | Finest Unit | City Points |
|--------|----------------|-------------|-------------|
| United States | TIGER/Line | Block group (~220K polygons) | GeoNames |
| European Union | Eurostat NUTS | NUTS 3 (~1,500 regions) | GeoNames |
| Australia | ABS ASGS | SA1 (~60K mesh areas) | GeoNames |
| New Zealand | Stats NZ | Meshblock (~53K areas) | GeoNames |
| Rest of World | -- | -- | GeoNames + Natural Earth |

---

## Common Pipeline Pattern

All demographic sources follow the same conversion workflow:

1. **Download** shapefiles or GeoJSON from the authoritative provider.
2. **Join** statistical attributes to boundary geometries using the official identifier
   (GEOID, NUTS_ID, SA2_CODE, etc.).
3. **Convert** to GeoJSON with `ogr2ogr` if necessary.
4. **Tile** with `tippecanoe` using appropriate zoom ranges.
5. **Load** the resulting MBTiles into the tileserver-gl `data/` volume.

See [Conversion & Tippecanoe](04c-CONVERT.md) for detailed parameters.

---

## Zoom-Level Strategy

| Layer | Min Zoom | Max Zoom | Rationale |
|-------|----------|----------|-----------|
| Country / State / NUTS 0-1 | 0 | 6 | Visible at globe/continent view |
| County / SA3 / NUTS 2 | 4 | 10 | Regional planning scale |
| Tract / SA2 / NUTS 3 | 6 | 12 | Metro-area analysis |
| Block group / SA1 / Meshblock | 8 | 14 | Neighbourhood-level detail |
| City points | 0 | 14 | Always visible, density-filtered by zoom |

---

## Attribute Normalisation

To enable cross-country comparison, the OXOT Tileserver normalises key demographic
fields into a common schema within the vector tiles:

| Normalised Field | US (TIGER) | EU (Eurostat) | AU (ABS) | NZ (Stats NZ) |
|------------------|-----------|---------------|----------|----------------|
| `pop_total` | B01001_001E | demo_pjan | Tot_P_P | Census_usually_resident |
| `median_income` | B19013_001E | nama_10r_2hhinc | Median_tot_prsnl_inc_weekly | Median_income |
| `geo_id` | GEOID | NUTS_ID | SA2_CODE21 | SA2_code |
| `geo_name` | NAME | NUTS_NAME | SA2_NAME21 | SA2_name |

---

## Children Pages

| Page | Description |
|------|-------------|
| [02b1 - US Census TIGER/Line + ACS](02b1-CENSUS-US.md) | US tracts, block groups, ZCTAs with ACS statistics |
| [02b2 - Eurostat NUTS + Nuts2json](02b2-EUROSTAT.md) | EU NUTS levels 0-3 with population and economic data |
| [02b3 - ABS Census Boundaries](02b3-ABS-AUSTRALIA.md) | Australian SA1-SA4 with Census DataPacks |
| [02b4 - Stats NZ Boundaries](02b4-STATS-NZ.md) | New Zealand meshblocks through TA with census data |
| [02b5 - GeoNames Cities](02b5-GEONAMES.md) | Global city points plus Natural Earth supplement |

---

## Related Pages

- **Parent**: [Data Sources](02-DATA-SOURCES.md)
- **Siblings**: [Basemap](02a-BASEMAP.md) | [Electric](02c-ELECTRIC.md) | [Water](02d-WATER.md) | [Telecoms](02e-TELECOMS.md)
- **Pipeline**: [Data Pipeline](04-PIPELINE.md) | [Conversion & Tippecanoe](04c-CONVERT.md)
- **Integration**: [OXOT Cyber DT Integration](06d-OXOT-CYBERDT.md)
