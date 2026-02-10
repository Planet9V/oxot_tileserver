> **Last Updated**: 2026-02-11 01:00 UTC

[Home](INDEX.md) > [Data Sources](02-DATA-SOURCES.md) > [Demographics](02b-DEMOGRAPHICS.md) > ABS Census Boundaries

# ABS Census Boundaries

The Australian Bureau of Statistics (ABS) publishes the Australian Statistical
Geography Standard (ASGS), a hierarchical system of geographic boundaries used
for census data collection and dissemination. These boundaries, combined with
Census DataPacks, provide population and socio-economic data for all of Australia.

---

## Quick Reference

| Attribute | Value |
|-----------|-------|
| **Provider** | Australian Bureau of Statistics (ABS) |
| **URL** | https://www.abs.gov.au/statistics/standards/australian-statistical-geography-standard-asgs-edition-3 |
| **Coverage** | Australia (all states and territories) |
| **Format** | Shapefile, GeoPackage, GeoJSON |
| **Size (raw)** | ~1 GB (all ASGS levels) |
| **Size (tiles)** | ~500 MB (MBTiles, zooms 0-14) |
| **Update Cadence** | Census cycle (every 5 years; current: 2021) |
| **License** | CC BY 4.0 |
| **OXOT Option** | B and above |

---

## ASGS Hierarchy

The ASGS defines a nested hierarchy of statistical areas:

| Level | Name | Count (2021) | Typical Population | Recommended Zoom |
|-------|------|-------------|-------------------|------------------|
| SA4 | Statistical Area Level 4 | 107 | 100,000-500,000 | 0-6 |
| SA3 | Statistical Area Level 3 | 358 | 30,000-130,000 | 4-8 |
| SA2 | Statistical Area Level 2 | 2,473 | 3,000-25,000 | 6-12 |
| SA1 | Statistical Area Level 1 | 61,845 | 200-800 | 8-14 |
| Meshblock | Meshblock | 368,286 | 30-60 | 12-14 |

SA2 is the primary analysis unit for most OXOT use cases, providing a balance
between geographic resolution and data reliability.

---

## Census DataPacks

ABS distributes census results as "DataPacks" -- pre-packaged CSV files aggregated
to each ASGS level. Key tables for the OXOT pipeline:

| DataPack | Key Variables | Join Field |
|----------|--------------|------------|
| General Community Profile (GCP) | Population, age, sex, ancestry, language | SA2_CODE21 |
| Aboriginal and Torres Strait Islander Peoples Profile | Indigenous population, language, employment | SA2_CODE21 |
| Place of Enumeration Profile (PEP) | Daytime population, commuting | SA2_CODE21 |
| Working Population Profile (WPP) | Industry of employment, occupation | SA2_CODE21 |

### Download DataPacks

DataPacks are available from the ABS Data by Region portal:

```
https://www.abs.gov.au/census/find-census-data/datapacks
```

Select the desired profile, geography level, and download as CSV.

---

## Join Process

All census tables use the `SA2_CODE21` (or equivalent level code) as the primary key.

```python
import geopandas as gpd
import pandas as pd

# Load boundaries
sa2 = gpd.read_file("SA2_2021_AUST_SHP_GDA2020/SA2_2021_AUST_GDA2020.shp")

# Load census data
gcp = pd.read_csv("2021Census_G01_AUST_SA2.csv")

# Join on SA2 code
joined = sa2.merge(gcp, left_on="SA2_CODE21", right_on="SA2_CODE_2021", how="left")
joined.to_file("sa2_with_census.geojson", driver="GeoJSON")
```

> **Important**: Use string types for all code columns. SA2 codes are numeric-looking
> but must retain formatting consistency for reliable joins.

---

## Coordinate Reference System

ABS boundaries are published in GDA2020 (EPSG:7844). For vector tiles, reproject
to WGS 84 (EPSG:4326):

```bash
ogr2ogr -f GeoJSON -t_srs EPSG:4326 \
  sa2_wgs84.geojson SA2_2021_AUST_GDA2020.shp
```

---

## Conversion Pipeline

### Step 1: Download Boundaries

```bash
wget https://www.abs.gov.au/statistics/standards/australian-statistical-geography-standard-asgs-edition-3/jul2021-jun2026/access-and-downloads/digital-boundary-files/SA2_2021_AUST_SHP_GDA2020.zip
unzip SA2_2021_AUST_SHP_GDA2020.zip
```

### Step 2: Reproject and Join

```bash
ogr2ogr -f GeoJSON -t_srs EPSG:4326 sa2.geojson SA2_2021_AUST_GDA2020.shp
# Then join census CSV as shown above
```

### Step 3: Generate Tiles

```bash
tippecanoe \
  -o abs_census.mbtiles \
  -z14 -Z0 \
  --drop-densest-as-needed \
  --extend-zooms-if-still-dropping \
  -l sa2 sa2_with_census.geojson \
  -l sa1 sa1_with_census.geojson \
  -l sa3 sa3_with_census.geojson
```

---

## Quality Notes

- **ASGS Edition**: The current edition is ASGS Edition 3 (July 2021 -- June 2026).
  Edition 4 boundaries are expected with the 2026 Census.
- **Meshblock tiling**: Meshblocks generate very large tile files. Consider tiling
  only SA1 and above unless meshblock granularity is specifically required.
- **Offshore territories**: Christmas Island, Cocos Islands, Norfolk Island, and
  Antarctic territories have SA2 codes but sparse census data.
- **Population weighting**: Some SA1 areas are large but sparsely populated
  (outback regions). Consider `--drop-densest-as-needed` in tippecanoe.

---

## References

Australian Bureau of Statistics. (2021). *Australian Statistical Geography Standard (ASGS): Edition 3*. Australian Government. https://www.abs.gov.au/statistics/standards/australian-statistical-geography-standard-asgs-edition-3

Australian Bureau of Statistics. (2022). *2021 Census DataPacks*. Australian Government. https://www.abs.gov.au/census/find-census-data/datapacks

---

## Related Pages

- **Parent**: [Demographics & Population](02b-DEMOGRAPHICS.md)
- **Siblings**: [US Census](02b1-CENSUS-US.md) | [Eurostat NUTS](02b2-EUROSTAT.md) | [Stats NZ](02b4-STATS-NZ.md) | [GeoNames](02b5-GEONAMES.md)
- **Pipeline**: [Conversion & Tippecanoe](04c-CONVERT.md)
- **See Also**: [Geoscience Australia](02c5-GEOSCIENCE-AU.md) | [BoM Water](02d5-BOM-AUSTRALIA.md)
