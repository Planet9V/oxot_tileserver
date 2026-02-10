> **Last Updated**: 2026-02-11 01:00 UTC

[Home](INDEX.md) > [Data Sources](02-DATA-SOURCES.md) > [Demographics](02b-DEMOGRAPHICS.md) > US Census TIGER/Line + ACS

# US Census TIGER/Line + ACS

The US Census Bureau publishes TIGER/Line shapefiles for every geographic unit in
the United States, from state boundaries down to individual census blocks. When
joined with American Community Survey (ACS) 5-year estimates, these boundaries
become rich demographic layers for population analysis, risk modelling, and
service-area characterisation.

---

## Quick Reference

| Attribute | Value |
|-----------|-------|
| **Provider** | United States Census Bureau |
| **URL** | https://www.census.gov/geographies/mapping-files/time-series/geo/tiger-line-file.html |
| **Coverage** | United States, Puerto Rico, US territories |
| **Format** | Shapefile (.shp) |
| **Size (raw)** | ~15 GB (all geographies) |
| **Size (tiles)** | ~5 GB (MBTiles, zooms 0-14) |
| **Update Cadence** | Annual (geometries); Annual (ACS 5-year estimates) |
| **License** | Public Domain (US Government work, 17 U.S.C. 105) |
| **OXOT Option** | B and above |

---

## Geographic Levels

TIGER/Line provides the following hierarchy of census geographies:

| Level | Count (approx.) | Typical Use | Recommended Zoom |
|-------|-----------------|-------------|------------------|
| State | 56 | National overview | 0-6 |
| County | 3,243 | Regional analysis | 4-10 |
| Census Tract | 85,000 | Metro-area demographics | 6-12 |
| Block Group | 240,000 | Neighbourhood analysis | 8-14 |
| ZCTA (ZIP Code) | 33,000 | Service-area modelling | 6-12 |
| Census Block | 8,200,000 | Fine-grained (rarely tiled) | 12-14 |

For the OXOT Tileserver, the standard build includes **tracts**, **block groups**,
and **ZCTAs**. County and state boundaries are included as lower-zoom context layers.

---

## ACS Data Fields

The American Community Survey 5-year estimates provide hundreds of data tables.
The OXOT pipeline joins a curated subset to TIGER geometries:

| ACS Table | Field | Description |
|-----------|-------|-------------|
| B01001 | B01001_001E | Total population |
| B01002 | B01002_001E | Median age |
| B19013 | B19013_001E | Median household income |
| B25001 | B25001_001E | Total housing units |
| B03002 | B03002_003E, _004E, _006E | Race/ethnicity (White, Black, Asian) |
| B25077 | B25077_001E | Median home value |
| B23025 | B23025_005E / _002E | Unemployment rate (derived) |

These fields are embedded as vector-tile properties, enabling client-side
choropleth rendering without additional API calls.

---

## GEOID Join Process

Each ACS record is keyed by a hierarchical GEOID:

```
State (2)  County (3)  Tract (6)  Block Group (1)
  06    +    037    +   101200  +       1
= GEOID 060371012001
```

The join workflow:

1. Download ACS CSV from the Census API or data.census.gov.
2. Download corresponding TIGER/Line shapefiles.
3. Join on `GEOID` (string match; preserve leading zeros).
4. Export joined GeoJSON with `ogr2ogr`.

---

## Download Automation

### FTP Bulk Download

```bash
# Download all tract shapefiles (one per state)
wget -r -np -nH --cut-dirs=4 \
  https://www2.census.gov/geo/tiger/TIGER2025/TRACT/
```

### Census API (ACS)

```bash
# Fetch population + income for all tracts in California (FIPS 06)
curl "https://api.census.gov/data/2024/acs/acs5?get=B01001_001E,B19013_001E&for=tract:*&in=state:06" \
  -o acs_ca_tracts.json
```

> **Tip**: The Census API requires a free API key for production use.
> Register at https://api.census.gov/data/key_signup.html.

---

## Conversion Pipeline

### Step 1: Merge State-Level Shapefiles

```bash
ogr2ogr -f GeoJSON tracts_merged.geojson \
  /vsicurl/https://www2.census.gov/geo/tiger/TIGER2025/TRACT/tl_2025_06_tract.shp \
  -append
# Repeat for each state or use a loop
```

### Step 2: Join ACS Data

```python
import geopandas as gpd
import pandas as pd

tracts = gpd.read_file("tracts_merged.geojson")
acs = pd.read_csv("acs_tracts_all.csv", dtype={"GEOID": str})
joined = tracts.merge(acs, on="GEOID", how="left")
joined.to_file("tracts_with_acs.geojson", driver="GeoJSON")
```

### Step 3: Generate Vector Tiles

```bash
tippecanoe \
  -o census_tracts.mbtiles \
  -z12 -Z6 \
  --drop-densest-as-needed \
  --extend-zooms-if-still-dropping \
  -l census_tracts \
  tracts_with_acs.geojson
```

### Step 4: Block Groups (Higher Resolution)

```bash
tippecanoe \
  -o census_blockgroups.mbtiles \
  -z14 -Z8 \
  --drop-densest-as-needed \
  -l census_blockgroups \
  blockgroups_with_acs.geojson
```

---

## Quality Notes

- **Leading zeros**: GEOIDs must be treated as strings. Integer parsing drops the
  leading zero for states 01-09, breaking the join.
- **ACS margins of error**: Every ACS estimate includes a margin of error (MOE)
  column. Consider including MOE fields for high-value attributes.
- **Vintage matching**: TIGER 2025 geometries align with ACS 2020-2024 5-year
  estimates. Mixing vintages can cause ~0.5% of tracts to fail the join due to
  boundary revisions.
- **Puerto Rico**: TIGER includes PR geometries; ACS coverage for PR is included
  in the national files.

---

## References

United States Census Bureau. (2025). *TIGER/Line shapefiles*. U.S. Department of Commerce. https://www.census.gov/geographies/mapping-files/time-series/geo/tiger-line-file.html

United States Census Bureau. (2025). *American Community Survey 5-year estimates*. U.S. Department of Commerce. https://data.census.gov/

United States Census Bureau. (2025). *Census API user guide*. https://www.census.gov/data/developers/guidance.html

---

## Related Pages

- **Parent**: [Demographics & Population](02b-DEMOGRAPHICS.md)
- **Siblings**: [Eurostat NUTS](02b2-EUROSTAT.md) | [ABS Census](02b3-ABS-AUSTRALIA.md) | [Stats NZ](02b4-STATS-NZ.md) | [GeoNames](02b5-GEONAMES.md)
- **Pipeline**: [Download Scripts](04a-DOWNLOAD.md) | [Conversion & Tippecanoe](04c-CONVERT.md)
- **Integration**: [OXOT Cyber DT](06d-OXOT-CYBERDT.md)
