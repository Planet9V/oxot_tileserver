> **Last Updated**: 2026-02-11 01:00 UTC

[Home](INDEX.md) > [Data Sources](02-DATA-SOURCES.md) > [Demographics](02b-DEMOGRAPHICS.md) > GeoNames Cities

# GeoNames Cities

GeoNames provides a global gazetteer of geographic names and city locations.
The `cities15000` extract contains all cities with a population of 15,000 or more,
making it a compact yet comprehensive global city-point layer. As a supplement,
Natural Earth Populated Places offers a curated set of ~7,300 cities with
additional cartographic attributes.

---

## Quick Reference: GeoNames

| Attribute | Value |
|-----------|-------|
| **Provider** | GeoNames.org |
| **URL** | https://download.geonames.org/export/dump/ |
| **Coverage** | Global |
| **Format** | TSV (tab-separated, no header) |
| **Extract** | `cities15000.zip` (~25,000 cities with pop >= 15,000) |
| **Size (raw)** | ~1.5 MB (zipped) |
| **Size (tiles)** | ~20 MB (MBTiles) |
| **Update Cadence** | Daily |
| **License** | CC BY 4.0 |
| **OXOT Option** | B and above |

---

## GeoNames TSV Schema

The `cities15000.txt` file uses tab-separated fields with no header row:

| Column | Index | Description |
|--------|-------|-------------|
| geonameid | 0 | Integer ID |
| name | 1 | UTF-8 name |
| asciiname | 2 | ASCII name |
| alternatenames | 3 | Comma-separated alternates |
| latitude | 4 | WGS 84 latitude |
| longitude | 5 | WGS 84 longitude |
| feature class | 6 | P (populated place) |
| feature code | 7 | PPL, PPLA, PPLC, etc. |
| country code | 8 | ISO 3166-1 alpha-2 |
| population | 14 | Integer population |
| elevation | 15 | Metres above sea level |
| timezone | 17 | IANA timezone |

---

## Conversion Pipeline

### Step 1: Download

```bash
wget https://download.geonames.org/export/dump/cities15000.zip
unzip cities15000.zip
```

### Step 2: Convert TSV to GeoJSON

```bash
awk -F'\t' '{
  printf "{\"type\":\"Feature\",\"geometry\":{\"type\":\"Point\",\"coordinates\":[%s,%s]},\"properties\":{\"name\":\"%s\",\"country\":\"%s\",\"population\":%s,\"feature_code\":\"%s\"}}\n",
  $6, $5, $2, $9, $15, $8
}' cities15000.txt | \
  jq -s '{type:"FeatureCollection",features:.}' > cities15000.geojson
```

> **Note**: For production use, prefer a Python script to handle UTF-8 names
> with embedded quotes and special characters safely.

### Step 3: Generate Tiles

```bash
tippecanoe \
  -o geonames_cities.mbtiles \
  -z14 -Z0 \
  -r1 \
  --cluster-distance=10 \
  -l cities \
  cities15000.geojson
```

The `-r1` flag prevents feature dropping, ensuring all cities appear at max zoom.
`--cluster-distance=10` merges overlapping points at lower zooms for readability.

---

## Quick Reference: Natural Earth Populated Places

| Attribute | Value |
|-----------|-------|
| **Provider** | Natural Earth |
| **URL** | https://www.naturalearthdata.com/downloads/10m-cultural-vectors/ |
| **Coverage** | Global |
| **Format** | Shapefile |
| **Feature Count** | ~7,300 cities |
| **Size (raw)** | ~5 MB |
| **Size (tiles)** | ~10 MB (MBTiles) |
| **License** | Public Domain |
| **OXOT Option** | B and above |

### Natural Earth Key Attributes

| Field | Description |
|-------|-------------|
| NAME | City name |
| ADM0NAME | Country name |
| POP_MAX | Maximum population estimate |
| FEATURECLA | Admin-0/1 capital, populated place |
| SCALERANK | Cartographic prominence (0 = most prominent) |
| LATITUDE / LONGITUDE | WGS 84 coordinates |

### Natural Earth Conversion

```bash
ogr2ogr -f GeoJSON ne_cities.geojson ne_10m_populated_places_simple.shp

tippecanoe \
  -o ne_cities.mbtiles \
  -z14 -Z0 \
  -r1 \
  -l ne_cities \
  ne_cities.geojson
```

---

## GeoNames vs Natural Earth

| Attribute | GeoNames cities15000 | Natural Earth |
|-----------|---------------------|---------------|
| City count | ~25,000 | ~7,300 |
| Population threshold | >= 15,000 | Curated |
| Update frequency | Daily | ~Annual |
| Capital city flag | Feature code PPLC | FEATURECLA field |
| Cartographic ranking | None | SCALERANK 0-10 |
| License | CC BY 4.0 | Public Domain |

**Recommendation**: Use GeoNames as the primary city layer for completeness.
Use Natural Earth as a supplementary layer when `SCALERANK` is needed for
zoom-dependent label filtering.

---

## References

GeoNames. (2026). *GeoNames geographical database*. https://www.geonames.org/

Natural Earth. (2025). *Populated places: 1:10m cultural vectors*. https://www.naturalearthdata.com/downloads/10m-cultural-vectors/

---

## Related Pages

- **Parent**: [Demographics & Population](02b-DEMOGRAPHICS.md)
- **Siblings**: [US Census](02b1-CENSUS-US.md) | [Eurostat NUTS](02b2-EUROSTAT.md) | [ABS Census](02b3-ABS-AUSTRALIA.md) | [Stats NZ](02b4-STATS-NZ.md)
- **Pipeline**: [Conversion & Tippecanoe](04c-CONVERT.md)
