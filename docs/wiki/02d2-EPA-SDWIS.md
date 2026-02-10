> **Last Updated**: 2026-02-11 01:00 UTC

[Home](INDEX.md) > [Data Sources](02-DATA-SOURCES.md) > [Water Infrastructure](02d-WATER.md) > EPA SDWIS + WATERS

# EPA SDWIS + WATERS

The U.S. Environmental Protection Agency (EPA) maintains two complementary
systems for drinking water infrastructure: the Safe Drinking Water Information
System (SDWIS) for regulatory data, and the Watershed Assessment, Tracking &
Environmental Results System (WATERS) for geospatial boundaries. Together, they
provide the most comprehensive picture of community water systems in the
United States.

---

## Quick Reference

| Attribute | Value |
|-----------|-------|
| **Provider** | U.S. Environmental Protection Agency (EPA) |
| **URL (SDWIS)** | https://www.epa.gov/ground-water-and-drinking-water/safe-drinking-water-information-system-sdwis-federal-reporting |
| **URL (WATERS)** | https://www.epa.gov/waterdata/waters-geospatial-data-downloads |
| **Coverage** | United States, Puerto Rico, US territories |
| **Format** | CSV (SDWIS), Shapefile/GeoJSON (WATERS) |
| **Key Features** | 50,000+ community water systems, service area boundaries |
| **Size (raw)** | ~3 GB (combined) |
| **Size (tiles)** | ~2 GB (MBTiles) |
| **Update Cadence** | Quarterly (SDWIS); Annual (WATERS boundaries) |
| **License** | Public Domain (US Government work) |
| **OXOT Option** | D and above |

---

## SDWIS: Regulatory Data

SDWIS tracks every public water system (PWS) in the United States. Each system
is identified by a unique PWSID (Public Water System Identifier).

### System Types

| Type | Code | Count (approx.) | Description |
|------|------|-----------------|-------------|
| Community Water System | CWS | ~50,000 | Serves year-round residential population |
| Non-Transient NCWS | NTNCWS | ~18,000 | Serves same non-residential population (e.g., schools) |
| Transient NCWS | TNCWS | ~80,000 | Serves transient population (e.g., rest stops) |

### Key Fields

| Field | Type | Description |
|-------|------|-------------|
| `PWSID` | String | 9-character system identifier (SS + 7 digits) |
| `PWS_NAME` | String | System name |
| `PWS_TYPE_CODE` | String | CWS, NTNCWS, TNCWS |
| `PRIMARY_SOURCE_CODE` | String | GW (groundwater), SW (surface water), GU, SWP |
| `POPULATION_SERVED_COUNT` | Number | Population served |
| `SERVICE_CONNECTIONS_COUNT` | Number | Number of connections |
| `STATE_CODE` | String | FIPS state code |
| `COUNTY_SERVED` | String | County name |
| `CITY_SERVED` | String | City name |

### Violation Data

SDWIS also tracks regulatory violations:

| Field | Type | Description |
|-------|------|-------------|
| `VIOLATION_ID` | String | Unique violation identifier |
| `VIOLATION_TYPE_CODE` | String | MCL, TT, MON, RPT |
| `CONTAMINANT_CODE` | String | EPA contaminant code |
| `COMPLIANCE_PERIOD_BEGIN_DATE` | Date | Violation start |
| `IS_HEALTH_BASED` | Boolean | Health-based violation flag |

---

## WATERS: Service Area Boundaries

WATERS provides polygon boundaries for community water system service areas.
Not all systems have boundaries; coverage is approximately 60% of CWS systems.

### Boundary Join

Service area polygons are joined to SDWIS data using the `PWSID` field:

```python
import geopandas as gpd
import pandas as pd

boundaries = gpd.read_file("cws_service_areas.shp")
sdwis = pd.read_csv("sdwis_water_systems.csv", dtype={"PWSID": str})

joined = boundaries.merge(sdwis, on="PWSID", how="left")
joined.to_file("water_systems_with_data.geojson", driver="GeoJSON")
```

---

## Download Methods

### SDWIS Data (CSV)

```bash
# Download from EPA Envirofacts
curl "https://data.epa.gov/efservice/WATER_SYSTEM/STATE_CODE/=/CA/CSV" \
  -o sdwis_california.csv
```

### WATERS Boundaries (Shapefile)

```bash
wget https://www.epa.gov/sites/default/files/waters/cws_service_areas.zip
unzip cws_service_areas.zip
```

### EPA ECHO API (Alternative)

```bash
# Query water systems with recent violations
curl "https://echodata.epa.gov/echo/sdw_rest_services.get_systems?output=JSON&p_st=CA&p_viol=Y" \
  -o echo_violations_ca.json
```

---

## Conversion Pipeline

### Step 1: Download and Join

```bash
# Download boundaries
wget -O cws_boundaries.zip \
  "https://www.epa.gov/sites/default/files/waters/cws_service_areas.zip"
unzip cws_boundaries.zip

# Download SDWIS data
curl "https://data.epa.gov/efservice/WATER_SYSTEM/PWS_TYPE_CODE/CWS/CSV" \
  -o sdwis_cws.csv
```

### Step 2: Merge and Enrich

```python
import geopandas as gpd
import pandas as pd

gdf = gpd.read_file("cws_service_areas.shp")
sdwis = pd.read_csv("sdwis_cws.csv", dtype={"PWSID": str})
violations = pd.read_csv("sdwis_violations.csv", dtype={"PWSID": str})

# Count violations per system
viol_count = violations.groupby("PWSID").size().reset_index(name="violation_count")

merged = gdf.merge(sdwis, on="PWSID", how="left")
merged = merged.merge(viol_count, on="PWSID", how="left")
merged["violation_count"] = merged["violation_count"].fillna(0).astype(int)

merged.to_file("water_systems_enriched.geojson", driver="GeoJSON")
```

### Step 3: Generate Tiles

```bash
# Service area polygons
tippecanoe \
  -o epa_water_systems.mbtiles \
  -z14 -Z6 \
  --drop-densest-as-needed \
  --extend-zooms-if-still-dropping \
  -l water_systems \
  water_systems_enriched.geojson

# Point centroids for low-zoom display
ogr2ogr -f GeoJSON water_system_centroids.geojson \
  water_systems_enriched.geojson \
  -sql "SELECT ST_Centroid(geometry) as geometry, PWSID, PWS_NAME, POPULATION_SERVED_COUNT, violation_count FROM water_systems_enriched"

tippecanoe \
  -o epa_water_points.mbtiles \
  -z8 -Z4 \
  -r1 \
  -l water_system_points \
  water_system_centroids.geojson
```

---

## Quality Notes

- **Boundary coverage**: Not all 50,000 CWS have mapped service areas. Systems
  without boundaries appear only as centroids (geocoded to city/ZIP).
- **PWSID format**: Always 9 characters. The first two are the state FIPS code.
  Treat as string to preserve formatting.
- **Violation currency**: SDWIS is updated quarterly. Recent violations may have
  a 1-3 month reporting lag.
- **Population accuracy**: `POPULATION_SERVED_COUNT` is self-reported by the
  system and may differ from census population within the service area.

---

## References

U.S. Environmental Protection Agency. (2025). *Safe Drinking Water Information System (SDWIS)*. https://www.epa.gov/ground-water-and-drinking-water/safe-drinking-water-information-system-sdwis-federal-reporting

U.S. Environmental Protection Agency. (2025). *WATERS geospatial data downloads*. https://www.epa.gov/waterdata/waters-geospatial-data-downloads

U.S. Environmental Protection Agency. (2025). *ECHO: Enforcement and Compliance History Online*. https://echo.epa.gov/

---

## Related Pages

- **Parent**: [Water Infrastructure](02d-WATER.md)
- **Siblings**: [OSM Water](02d1-OSM-WATER.md) | [EEA WISE](02d3-EEA-WISE.md) | [NID Dams](02d4-NID-DAMS.md) | [BoM Water](02d5-BOM-AUSTRALIA.md)
- **Cross-sector**: [HIFLD](02c3-HIFLD.md) (wastewater plants)
- **Pipeline**: [Download Scripts](04a-DOWNLOAD.md) | [Conversion](04c-CONVERT.md)
