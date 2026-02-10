> **Last Updated**: 2026-02-11 01:00 UTC

[Home](INDEX.md) > [Data Sources](02-DATA-SOURCES.md) > [Demographics](02b-DEMOGRAPHICS.md) > Eurostat NUTS + Nuts2json

# Eurostat NUTS + Nuts2json

The Nomenclature of Territorial Units for Statistics (NUTS) is the EU standard
for referencing the administrative and statistical regions of member states.
Eurostat publishes both the official GISCO boundary files and, through community
projects, simplified GeoJSON builds optimised for web mapping.

---

## Quick Reference

| Attribute | Value |
|-----------|-------|
| **Provider** | Eurostat (European Commission) |
| **URL (GISCO)** | https://ec.europa.eu/eurostat/web/gisco/geodata/reference-data/administrative-units-statistical-units |
| **URL (Nuts2json)** | https://github.com/eurostat/Nuts2json |
| **Coverage** | EU-27, EFTA, UK, candidate countries |
| **Format** | Shapefile / GeoJSON (GISCO); TopoJSON / GeoJSON (Nuts2json) |
| **Size** | ~50 MB (Nuts2json) / ~2 GB (full GISCO) |
| **Update Cadence** | Aligned with NUTS revision cycle (every ~3 years) |
| **License** | CC BY 4.0 (Eurostat reuse policy) |
| **OXOT Option** | B and above |

---

## NUTS Levels Explained

| Level | Approximate Equivalent | Count (2021) | Example |
|-------|----------------------|--------------|---------|
| NUTS 0 | Country | 37 | DE (Germany) |
| NUTS 1 | Major socio-economic region | 104 | DE1 (Baden-Wurttemberg) |
| NUTS 2 | Province / region | 283 | DE11 (Stuttgart) |
| NUTS 3 | District / county | 1,524 | DE111 (Stuttgart, Stadtkreis) |

NUTS codes follow a hierarchical pattern: each level appends one or two characters
to its parent code.

---

## Nuts2json: Simplified Boundaries

The `Nuts2json` project provides pre-simplified GeoJSON files at three scale
thresholds, significantly reducing file size compared to full GISCO boundaries:

| Scale | Resolution | File Size (NUTS 3) | Use Case |
|-------|-----------|-------------------|----------|
| 10M | 1:10,000,000 | ~5 MB | Continental overview |
| 20M | 1:20,000,000 | ~2 MB | Dashboard / thumbnail |
| 60M | 1:60,000,000 | ~0.5 MB | Small multiples |

For the OXOT Tileserver, the **10M** scale provides the best balance between
visual fidelity and tile performance at zooms 0-10.

### Nuts2json URL Pattern

```
https://raw.githubusercontent.com/eurostat/Nuts2json/master/pub/v2/2021/4326/10M/nutsrg_{level}.json
```

Replace `{level}` with `0`, `1`, `2`, or `3`.

---

## Statistical Data

Eurostat publishes hundreds of statistical tables that can be joined to NUTS
geometries by `NUTS_ID`. Key tables for the OXOT pipeline:

| Table Code | Description | Temporal |
|-----------|-------------|----------|
| `demo_pjan` | Population on 1 January | Annual |
| `nama_10r_2gdp` | GDP at current market prices | Annual |
| `lfst_r_lfu3rt` | Unemployment rate | Annual |
| `nama_10r_2hhinc` | Household income | Annual |
| `demo_r_d2jan` | Population density | Annual |

### API Access

```bash
# Fetch population for all NUTS 2 regions, 2023
curl "https://ec.europa.eu/eurostat/api/dissemination/sdmx/2.1/data/demo_pjan/A.NR.T.?format=JSON&sinceTimePeriod=2023" \
  -o eurostat_pop_nuts2.json
```

---

## Vintage Matching

NUTS boundaries are revised approximately every three years. Using mismatched
vintages between geometry and statistics causes join failures:

| NUTS Vintage | Valid Period | Statistical Years |
|--------------|------------|-------------------|
| NUTS 2016 | 2018-2020 | 2018, 2019, 2020 |
| NUTS 2021 | 2021-2023 | 2021, 2022, 2023 |
| NUTS 2024 | 2024-2026 | 2024, 2025, 2026 (est.) |

> **Recommendation**: Use the **NUTS 2021** vintage for current builds. The
> 2024 revision has limited statistical coverage as of early 2026.

---

## Conversion Pipeline

### Step 1: Download Nuts2json

```bash
for level in 0 1 2 3; do
  curl -L -o "nuts_${level}.json" \
    "https://raw.githubusercontent.com/eurostat/Nuts2json/master/pub/v2/2021/4326/10M/nutsrg_${level}.json"
done
```

### Step 2: Join Statistical Data

```python
import geopandas as gpd
import pandas as pd

nuts3 = gpd.read_file("nuts_3.json")
pop = pd.read_csv("eurostat_pop_nuts3.csv")
joined = nuts3.merge(pop, left_on="id", right_on="NUTS_ID", how="left")
joined.to_file("nuts3_with_stats.geojson", driver="GeoJSON")
```

### Step 3: Generate Tiles

```bash
tippecanoe \
  -o eurostat_nuts.mbtiles \
  -z10 -Z0 \
  --coalesce-densest-as-needed \
  -l nuts0 -L nuts_0.json \
  -l nuts1 -L nuts_1.json \
  -l nuts2 -L nuts_2.json \
  -l nuts3 -L nuts_3.json
```

---

## Full GISCO Boundaries

For higher-fidelity boundaries (e.g., zoom > 10), download the full GISCO dataset:

```bash
wget https://gisco-services.ec.europa.eu/distribution/v2/nuts/download/ref-nuts-2021-01m.shp.zip
unzip ref-nuts-2021-01m.shp.zip
```

Full GISCO boundaries are ~2 GB uncompressed and include overseas territories
(DOM-TOM, Canary Islands, Azores).

---

## References

European Commission, Eurostat. (2025). *GISCO: Geographical information and maps*. https://ec.europa.eu/eurostat/web/gisco

European Commission, Eurostat. (2025). *Nuts2json: Simplified NUTS boundaries for web mapping* [Software]. GitHub. https://github.com/eurostat/Nuts2json

European Commission, Eurostat. (2025). *NUTS -- Nomenclature of territorial units for statistics*. https://ec.europa.eu/eurostat/web/nuts/background

---

## Related Pages

- **Parent**: [Demographics & Population](02b-DEMOGRAPHICS.md)
- **Siblings**: [US Census](02b1-CENSUS-US.md) | [ABS Census](02b3-ABS-AUSTRALIA.md) | [Stats NZ](02b4-STATS-NZ.md) | [GeoNames](02b5-GEONAMES.md)
- **Pipeline**: [Conversion & Tippecanoe](04c-CONVERT.md)
- **Integration**: [OXOT Cyber DT](06d-OXOT-CYBERDT.md)
