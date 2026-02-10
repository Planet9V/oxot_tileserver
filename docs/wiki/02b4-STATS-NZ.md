> **Last Updated**: 2026-02-11 01:00 UTC

[Home](INDEX.md) > [Data Sources](02-DATA-SOURCES.md) > [Demographics](02b-DEMOGRAPHICS.md) > Stats NZ Boundaries

# Stats NZ Geographic Boundaries

Stats NZ publishes the Statistical Standard for Geographic Areas, providing a
hierarchical set of boundaries aligned with the New Zealand Census. These boundaries
enable population analysis and service-area characterisation across all of
New Zealand.

---

## Quick Reference

| Attribute | Value |
|-----------|-------|
| **Provider** | Stats NZ / Tatauranga Aotearoa |
| **URL** | https://datafinder.stats.govt.nz/ |
| **Coverage** | New Zealand (North Island, South Island, offshore) |
| **Format** | Shapefile, GeoJSON, GeoPackage |
| **Size (raw)** | ~200 MB (all levels) |
| **Size (tiles)** | ~100 MB (MBTiles, zooms 0-14) |
| **Update Cadence** | Census cycle (every 5 years; current: 2023) |
| **License** | CC BY 4.0 |
| **OXOT Option** | B and above |

---

## Geographic Hierarchy

| Level | Name | Count (2023) | Typical Population | Recommended Zoom |
|-------|------|-------------|-------------------|------------------|
| Regional Council | Regional Council | 16 | 50,000-1,700,000 | 0-6 |
| Territorial Authority | TA / City / District | 67 | 10,000-500,000 | 4-8 |
| SA2 | Statistical Area 2 | ~2,200 | 1,000-4,000 | 6-12 |
| SA1 | Statistical Area 1 | ~30,000 | 100-200 | 8-14 |
| Meshblock | Meshblock | ~53,000 | 0-120 | 10-14 |

SA2 is the primary unit for census output. Meshblocks are the finest publicly
available geography.

---

## Census 2023 Data

The 2023 Census provides population counts, dwelling counts, ethnicity, income,
and employment data. Key variables:

| Variable | Dataset | Join Field |
|----------|---------|------------|
| Usually resident population | Census usually resident population count | SA2_code |
| Dwellings | Dwelling counts | SA2_code |
| Ethnicity | Ethnic group (total responses) | SA2_code |
| Median income | Median personal income | SA2_code |
| Employment status | Labour force status | SA2_code |

---

## DataFinder Portal

All geographic and statistical data is available through the Stats NZ DataFinder:

```
https://datafinder.stats.govt.nz/
```

### Download Steps

1. Navigate to **Geographic boundaries** in the left menu.
2. Select the desired level (e.g., "Statistical Area 2 2023").
3. Choose format: GeoJSON recommended for the pipeline.
4. Download and unzip.

### API Access

Stats NZ provides an ArcGIS-compatible REST API:

```bash
curl "https://datafinder.stats.govt.nz/services;key=YOUR_KEY/wfs?service=WFS&version=2.0.0&request=GetFeature&typeNames=layer-xxxxx&outputFormat=json" \
  -o sa2_boundaries.geojson
```

---

## Conversion Pipeline

### Step 1: Download

```bash
# Direct download from DataFinder (requires free API key)
wget -O sa2_2023.geojson \
  "https://datafinder.stats.govt.nz/services;key=${STATS_NZ_KEY}/wfs?service=WFS&version=2.0.0&request=GetFeature&typeNames=layer-106668&outputFormat=json"
```

### Step 2: Join Census Data

```python
import geopandas as gpd
import pandas as pd

sa2 = gpd.read_file("sa2_2023.geojson")
census = pd.read_csv("census_2023_sa2.csv", dtype={"SA2_code": str})
joined = sa2.merge(census, left_on="SA22023_V1_00", right_on="SA2_code", how="left")
joined.to_file("sa2_with_census.geojson", driver="GeoJSON")
```

### Step 3: Generate Tiles

```bash
tippecanoe \
  -o stats_nz.mbtiles \
  -z14 -Z0 \
  --drop-densest-as-needed \
  -l sa2 sa2_with_census.geojson
```

---

## Quality Notes

- **Coordinate system**: Stats NZ publishes in NZGD2000 (EPSG:2193). Reproject
  to WGS 84 (EPSG:4326) before tiling.
- **Chatham Islands**: Included in SA2 but located east of the antimeridian
  (longitude ~-176). Verify rendering at the dateline.
- **Census 2023 availability**: Final census data release is staged; some tables
  may lag boundary releases.

---

## References

Stats NZ / Tatauranga Aotearoa. (2024). *Geographic boundaries: Statistical Area 2 2023*. New Zealand Government. https://datafinder.stats.govt.nz/

Stats NZ / Tatauranga Aotearoa. (2024). *2023 Census data*. New Zealand Government. https://www.stats.govt.nz/census/

---

## Related Pages

- **Parent**: [Demographics & Population](02b-DEMOGRAPHICS.md)
- **Siblings**: [US Census](02b1-CENSUS-US.md) | [Eurostat NUTS](02b2-EUROSTAT.md) | [ABS Census](02b3-ABS-AUSTRALIA.md) | [GeoNames](02b5-GEONAMES.md)
- **Pipeline**: [Conversion & Tippecanoe](04c-CONVERT.md)
