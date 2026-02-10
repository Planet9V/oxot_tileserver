> **Last Updated**: 2026-02-11 01:00 UTC

[Home](INDEX.md) > [Data Sources](02-DATA-SOURCES.md) > [Electric Grid](02c-ELECTRIC.md) > HIFLD Open Data

# HIFLD Open Data

The Homeland Infrastructure Foundation-Level Data (HIFLD) programme, managed by
the Department of Homeland Security (DHS) and the Cybersecurity and Infrastructure
Security Agency (CISA), publishes geospatial data for critical infrastructure
across the United States. HIFLD is the only source that spans multiple CISA
sectors in a single portal, making it particularly valuable for cross-sector
analysis in the OXOT Tileserver.

---

## Quick Reference

| Attribute | Value |
|-----------|-------|
| **Provider** | Department of Homeland Security / CISA |
| **URL** | https://hifld-geoplatform.opendata.arcgis.com/ |
| **Coverage** | United States |
| **Format** | Shapefile, GeoJSON, CSV (via ArcGIS Hub) |
| **Datasets** | 30+ open datasets (some restricted) |
| **Size (raw)** | ~5 GB (all open datasets) |
| **Size (tiles)** | ~3 GB (MBTiles) |
| **Update Cadence** | Variable (quarterly to annual per dataset) |
| **License** | Public Domain (US Government work) |
| **OXOT Option** | C and above |

---

## Dataset Catalogue

### Open Datasets (Publicly Available)

| Dataset | Sector | Geometry | Features | Key Attributes |
|---------|--------|----------|----------|----------------|
| Electric Substations | Energy | Point | ~70,000 | Type, voltage, status |
| Electric Power Transmission Lines | Energy | LineString | ~70,000 | Voltage, owner |
| Power Plants | Energy | Point | ~10,000 | Fuel, capacity MW |
| Natural Gas Compressor Stations | Energy | Point | ~1,600 | Operator |
| Hospitals | Healthcare | Point | ~7,500 | Beds, trauma level |
| Urgent Care Facilities | Healthcare | Point | ~10,000 | Type |
| Emergency Medical Services | Emergency | Point | ~27,000 | Type |
| Fire Stations | Emergency | Point | ~55,000 | Type, department |
| Law Enforcement | Emergency | Point | ~18,000 | Type |
| Colleges and Universities | Education | Point | ~7,500 | Type, enrollment |
| Public Schools | Education | Point | ~100,000 | Grade, students |
| Wastewater Treatment Plants | Water | Point | ~15,000 | Capacity MGD |
| Dams | Water | Point | ~92,000 | Hazard, type |
| Airports | Transportation | Point | ~19,000 | Class, runways |
| Ports | Transportation | Point | ~3,000 | Type |
| Cell Towers | Communications | Point | ~200,000 | Type |
| TV Analog/Digital Transmitters | Communications | Point | ~30,000 | Power, frequency |

### Restricted Datasets (Require .gov/.mil Email)

Some HIFLD datasets are restricted to government personnel:

- Water treatment plants (detailed)
- Chemical facilities
- Nuclear facilities
- Defence installations
- Petroleum storage
- Natural gas processing

> **Note**: The OXOT pipeline only uses open (unrestricted) HIFLD datasets.
> For restricted infrastructure, use OSM or state-level open-data portals.

---

## CISA Sector Alignment

HIFLD datasets map directly to the CISA 16 Critical Infrastructure Sectors.
This alignment enables cross-sector risk analysis in the OXOT Cyber Digital Twin.

| CISA Sector | HIFLD Datasets | OXOT Sector Code |
|-------------|----------------|------------------|
| Energy | Substations, Transmission, Plants, Gas | ENER |
| Water and Wastewater | Dams, Wastewater | WATR |
| Healthcare | Hospitals, Urgent Care | HLTH |
| Emergency Services | Fire, EMS, Law Enforcement | EMER |
| Transportation | Airports, Ports | TRAN |
| Communications | Cell Towers, Transmitters | COMM |
| Education | Schools, Universities | (via GOVT) |

---

## Download Methods

### ArcGIS Hub Portal

Browse and download at: https://hifld-geoplatform.opendata.arcgis.com/

### ArcGIS REST API (Bulk)

```bash
# Download electric substations as GeoJSON (paginated, 2000 per request)
OFFSET=0
while true; do
  curl -s "https://services1.arcgis.com/Hp6G80Pky0om6HgQ/arcgis/rest/services/Electric_Substations/FeatureServer/0/query?where=1=1&outFields=*&resultOffset=${OFFSET}&resultRecordCount=2000&f=geojson" \
    -o "substations_${OFFSET}.geojson"
  COUNT=$(jq '.features | length' "substations_${OFFSET}.geojson")
  [ "$COUNT" -lt 2000 ] && break
  OFFSET=$((OFFSET + 2000))
done
```

### OGR Direct Access

```bash
ogr2ogr -f GeoJSON hifld_substations.geojson \
  "https://services1.arcgis.com/Hp6G80Pky0om6HgQ/arcgis/rest/services/Electric_Substations/FeatureServer/0/query?where=1=1&outFields=*&f=geojson"
```

---

## Conversion Pipeline

### Step 1: Download Selected Datasets

```bash
#!/bin/bash
DATASETS=(
  "Electric_Substations"
  "Electric_Power_Transmission_Lines"
  "Hospitals"
  "Fire_Stations"
  "Wastewater_Treatment_Plants"
)
for ds in "${DATASETS[@]}"; do
  ogr2ogr -f GeoJSON "hifld_${ds}.geojson" \
    "https://services1.arcgis.com/Hp6G80Pky0om6HgQ/arcgis/rest/services/${ds}/FeatureServer/0/query?where=1=1&outFields=*&f=geojson"
done
```

### Step 2: Generate Tiles per Sector

```bash
# Energy sector
tippecanoe \
  -o hifld_energy.mbtiles \
  -z14 -Z4 \
  --drop-densest-as-needed \
  -l substations hifld_Electric_Substations.geojson \
  -l transmission hifld_Electric_Power_Transmission_Lines.geojson

# Emergency sector
tippecanoe \
  -o hifld_emergency.mbtiles \
  -z14 -Z4 \
  --drop-densest-as-needed \
  -l hospitals hifld_Hospitals.geojson \
  -l fire_stations hifld_Fire_Stations.geojson
```

### Step 3: Merge All Sectors

```bash
tile-join \
  -o hifld_all.mbtiles \
  hifld_energy.mbtiles \
  hifld_emergency.mbtiles \
  hifld_water.mbtiles
```

---

## Quality Notes

- **Currency**: Dataset update frequencies vary. Electric substations are updated
  quarterly; some education datasets lag by 1-2 years.
- **Coordinate quality**: Most points are geocoded to street address, accurate to
  ~50 m. Some rural facilities use ZIP centroid.
- **Overlap with EIA**: HIFLD electric substations and plants overlap with EIA
  data. The OXOT pipeline deduplicates by matching on lat/lon proximity (< 500 m)
  and facility name similarity.

---

## References

Department of Homeland Security. (2025). *Homeland infrastructure foundation-level data (HIFLD)*. https://hifld-geoplatform.opendata.arcgis.com/

Cybersecurity and Infrastructure Security Agency. (2025). *Critical infrastructure sectors*. https://www.cisa.gov/topics/critical-infrastructure-security-and-resilience/critical-infrastructure-sectors

---

## Related Pages

- **Parent**: [Electric Grid](02c-ELECTRIC.md)
- **Siblings**: [OSM Power](02c1-OSM-POWER.md) | [EIA](02c2-EIA.md) | [ENTSO-E](02c4-ENTSOE.md) | [Geoscience AU](02c5-GEOSCIENCE-AU.md)
- **Cross-sector**: [EPA SDWIS](02d2-EPA-SDWIS.md) | [NID Dams](02d4-NID-DAMS.md)
- **Pipeline**: [Download Scripts](04a-DOWNLOAD.md) | [Conversion](04c-CONVERT.md)
- **Integration**: [OXOT Cyber DT](06d-OXOT-CYBERDT.md)
