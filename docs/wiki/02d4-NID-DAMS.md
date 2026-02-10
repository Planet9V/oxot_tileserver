> **Last Updated**: 2026-02-11 01:00 UTC

[Home](INDEX.md) > [Data Sources](02-DATA-SOURCES.md) > [Water Infrastructure](02d-WATER.md) > National Inventory of Dams

# National Inventory of Dams (NID)

The U.S. Army Corps of Engineers (USACE) maintains the National Inventory of Dams
(NID), the most comprehensive database of dams in the United States. The NID
contains records for over 92,000 dams with more than 70 attributes per record,
including hazard classification, structural type, purpose, and condition assessment.

---

## Quick Reference

| Attribute | Value |
|-----------|-------|
| **Provider** | U.S. Army Corps of Engineers (USACE) |
| **URL** | https://nid.sec.usace.army.mil/ |
| **Coverage** | United States, Puerto Rico, US territories |
| **Format** | CSV, Shapefile, GeoJSON (via NID portal) |
| **Feature Count** | 92,075+ dams |
| **Attributes** | 70+ per dam |
| **Size (raw)** | ~50 MB (CSV) / ~100 MB (Shapefile) |
| **Size (tiles)** | ~20 MB (MBTiles) |
| **Update Cadence** | Annual (federal dams); Biennial (state-inspected dams) |
| **License** | Public Domain (US Government work) |
| **OXOT Option** | D and above |

---

## Hazard Classification

The NID classifies every dam by potential downstream consequences of failure.
This is the most critical attribute for OXOT risk modelling.

| Classification | Code | Meaning | Dam Count |
|---------------|------|---------|-----------|
| **High** | H | Loss of life probable if dam fails | ~15,600 |
| **Significant** | S | No probable loss of life, but economic/environmental damage | ~12,400 |
| **Low** | L | No probable loss of life and low economic damage | ~58,000 |
| **Undetermined** | U | Not yet classified | ~6,000 |

---

## Key Attributes

| Field | Type | Description |
|-------|------|-------------|
| `NID_ID` | String | Unique NID identifier (e.g., TX00001) |
| `DAM_NAME` | String | Official dam name |
| `OTHER_DAM_NAME` | String | Alternate name |
| `STATE` | String | Two-letter state code |
| `COUNTY` | String | County name |
| `RIVER` | String | River / stream name |
| `CITY` | String | Nearest city |
| `OWNER_NAME` | String | Dam owner |
| `OWNER_TYPE` | String | Federal, State, Local, Private, Utility |
| `DAM_TYPE` | String | RE (Earth), PG (Gravity), VA (Arch), etc. |
| `DAM_PURPOSE` | String | I (Irrigation), S (Water Supply), H (Hydro), C (Flood Control), R (Recreation) |
| `DAM_LENGTH_FT` | Number | Crest length in feet |
| `DAM_HEIGHT_FT` | Number | Structural height in feet |
| `NID_HEIGHT_FT` | Number | Maximum height in feet |
| `MAX_STORAGE_ACRE_FT` | Number | Maximum storage in acre-feet |
| `NORMAL_STORAGE_ACRE_FT` | Number | Normal storage in acre-feet |
| `SURFACE_AREA_ACRES` | Number | Reservoir surface area |
| `YEAR_COMPLETED` | Number | Year of original construction |
| `YEAR_MODIFIED` | Number | Year of last major modification |
| `HAZARD` | String | H (High), S (Significant), L (Low), U (Undetermined) |
| `CONDITION_ASSESSMENT` | String | Satisfactory, Fair, Poor, Unsatisfactory, Not Rated |
| `INSPECTION_DATE` | Date | Last inspection date |
| `LATITUDE` / `LONGITUDE` | Number | WGS 84 coordinates |

---

## Dam Types

| Code | Type | Description |
|------|------|-------------|
| RE | Earth | Compacted earth fill |
| ER | Rockfill | Rock or riprap fill |
| PG | Gravity | Concrete gravity |
| VA | Arch | Concrete arch |
| CB | Buttress | Concrete buttress |
| TC | Timber Crib | Wood crib structure |
| CN | Concrete | Other concrete |
| MS | Masonry | Stone masonry |
| OT | Other | All other types |

---

## Download Methods

### NID Portal (Interactive)

1. Navigate to https://nid.sec.usace.army.mil/
2. Click **Download NID Data**
3. Select format (CSV, Shapefile, or GeoJSON)
4. Accept terms and download

### Direct Download

```bash
# CSV (entire inventory)
wget -O nid_all.csv \
  "https://nid.sec.usace.army.mil/api/nation/csv"

# GeoJSON (high-hazard only)
wget -O nid_high_hazard.geojson \
  "https://nid.sec.usace.army.mil/api/nation/geojson?hazard=H"
```

### API Queries

```bash
# All high-hazard dams in California
curl "https://nid.sec.usace.army.mil/api/nation/dams?state=CA&hazard=H&format=geojson" \
  -o nid_ca_high.geojson
```

---

## Conversion Pipeline

### Step 1: Download and Filter

```bash
# Download full inventory as GeoJSON
wget -O nid_all.geojson \
  "https://nid.sec.usace.army.mil/api/nation/geojson"
```

### Step 2: Categorise for Styling

```python
import geopandas as gpd

dams = gpd.read_file("nid_all.geojson")

# Add risk score for tile styling
def risk_score(row):
    hazard_score = {"H": 3, "S": 2, "L": 1, "U": 0}.get(row.get("HAZARD", "U"), 0)
    condition_score = {"Poor": 3, "Unsatisfactory": 4, "Fair": 2, "Satisfactory": 1, "Not Rated": 0}.get(row.get("CONDITION_ASSESSMENT", "Not Rated"), 0)
    return hazard_score + condition_score

dams["risk_score"] = dams.apply(risk_score, axis=1)
dams.to_file("nid_with_risk.geojson", driver="GeoJSON")
```

### Step 3: Generate Tiles

```bash
tippecanoe \
  -o nid_dams.mbtiles \
  -z14 -Z4 \
  -r1 \
  --cluster-distance=10 \
  -l dams \
  nid_with_risk.geojson
```

---

## Quality Notes

- **Coordinate accuracy**: Most dam locations are accurate to < 100 m. Some older
  records have coordinates snapped to river confluences rather than the dam
  structure itself.
- **Condition assessment**: Not all dams have current condition ratings. Federal
  dams are inspected regularly; some state-regulated dams lag in inspection
  currency.
- **Height threshold**: The NID includes dams >= 25 feet high (or >= 6 feet high
  with storage >= 50 acre-feet). Smaller dams and weirs are not included.
- **Private dams**: Approximately 65% of NID dams are privately owned. Some
  private dam records have limited attribute completeness.

---

## References

U.S. Army Corps of Engineers. (2025). *National inventory of dams*. U.S. Department of Defense. https://nid.sec.usace.army.mil/

Association of State Dam Safety Officials. (2025). *Dam safety resources*. https://damsafety.org/

---

## Related Pages

- **Parent**: [Water Infrastructure](02d-WATER.md)
- **Siblings**: [OSM Water](02d1-OSM-WATER.md) | [EPA SDWIS](02d2-EPA-SDWIS.md) | [EEA WISE](02d3-EEA-WISE.md) | [BoM Water](02d5-BOM-AUSTRALIA.md)
- **Cross-sector**: [HIFLD](02c3-HIFLD.md) (also lists dams)
- **Pipeline**: [Conversion & Tippecanoe](04c-CONVERT.md)
- **Integration**: [OXOT Cyber DT](06d-OXOT-CYBERDT.md) (dam failure cascades)
