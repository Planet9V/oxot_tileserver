# Equipment & Fixed Asset Layers

> **Last Updated**: 2026-02-11 01:00 UTC

[Home](INDEX.md) > [Custom Tiles](07-CUSTOM-TILES.md)

---

## The Use Case

Organizations track fixed assets -- railway signals, electrical transformers, water pumping stations, telecom towers -- in asset management systems (CMMS, EAM, spreadsheets). These assets have precise geographic coordinates that are essential for maintenance scheduling, inspection routing, and incident response.

This page covers how to transform equipment inventories into interactive map layers served by the OXOT Tileserver. The workflow reads from CMMS exports, produces GeoJSON with rich asset attributes, converts to vector tiles with clustering support, and renders with condition-based styling.

---

## Equipment Data Model

### Standard Equipment Feature

```json
{
  "type": "Feature",
  "geometry": {
    "type": "Point",
    "coordinates": [-1.5, 53.38]
  },
  "properties": {
    "asset_id": "SIG-2024-0451",
    "asset_type": "Railway Signal",
    "subtype": "Colour Light Signal (4-aspect)",
    "manufacturer": "Alstom",
    "model": "FS-4000",
    "install_date": "2019-06-15",
    "last_inspection": "2025-11-20",
    "condition": "good",
    "location_description": "Sheffield Station, Platform 3, Signal S451",
    "owner": "Network Rail",
    "sector": "TRAN"
  }
}
```

### Property Reference

| Property | Type | Required | Description |
|----------|------|----------|-------------|
| `asset_id` | String | Yes | Unique asset identifier from CMMS |
| `asset_type` | String | Yes | Primary classification for styling and filtering |
| `subtype` | String | No | Detailed classification within asset_type |
| `manufacturer` | String | No | Equipment manufacturer |
| `model` | String | No | Model number or designation |
| `install_date` | String | No | ISO 8601 installation date |
| `last_inspection` | String | No | ISO 8601 date of most recent inspection |
| `condition` | String | Yes | Asset condition: critical, poor, fair, good |
| `location_description` | String | No | Human-readable location text |
| `owner` | String | No | Asset owner or operating organization |
| `sector` | String | Yes | CISA sector code |
| `voltage_kv` | Number | No | For electrical equipment: voltage in kilovolts |
| `capacity` | Number | No | Throughput or capacity (units vary by type) |

---

## Equipment Categories

The following table lists common equipment categories with suggested icon shapes for map rendering. The `asset_type` property value determines styling.

| Category | Examples | Geometry | Suggested Icon |
|----------|----------|----------|----------------|
| Railway Signals | Colour light, semaphore, ground signal, shunt signal | Point | Triangle |
| Substations | 11 kV, 33 kV, 132 kV, 400 kV distribution and transmission | Point or Polygon | Square |
| Pumping Stations | Water supply, wastewater lift, stormwater, irrigation | Point | Circle |
| Telecom Towers | Macro cell, small cell, microwave relay, broadcast | Point | Diamond |
| Transformers | Pole-mounted, pad-mounted, substation, mobile | Point | Pentagon |
| Valves | Gate valve, check valve, pressure relief, butterfly | Point | Star |
| Generators | Diesel backup, gas turbine, solar inverter | Point | Hexagon |
| Meters | Flow meter, power meter, level sensor, pressure gauge | Point | Small circle |
| Bridges | Road bridge, rail bridge, footbridge, aqueduct | Point or LineString | Cross |
| Pipelines | Water main, gas main, sewer, cable duct | LineString | Dashed line |

---

## Converting CMMS Exports to GeoJSON

Most CMMS and EAM systems export to CSV or Excel. The conversion to GeoJSON requires mapping coordinate columns and asset attributes to the standard schema.

### Python Conversion Script

```python
import csv
import json
from datetime import datetime

def cmms_csv_to_geojson(csv_path, output_path):
    """Convert CMMS CSV export to GeoJSON FeatureCollection."""
    features = []
    skipped = 0

    with open(csv_path) as f:
        for row in csv.DictReader(f):
            # Skip rows without valid coordinates
            try:
                lon = float(row["longitude"])
                lat = float(row["latitude"])
            except (ValueError, KeyError):
                skipped += 1
                continue

            # Validate coordinate range
            if not (-180 <= lon <= 180 and -90 <= lat <= 90):
                skipped += 1
                continue

            feature = {
                "type": "Feature",
                "geometry": {
                    "type": "Point",
                    "coordinates": [lon, lat]
                },
                "properties": {
                    "asset_id": row.get("asset_id", ""),
                    "asset_type": row.get("asset_type", "Unknown"),
                    "subtype": row.get("subtype", ""),
                    "manufacturer": row.get("manufacturer", ""),
                    "model": row.get("model", ""),
                    "install_date": row.get("install_date", ""),
                    "last_inspection": row.get("last_inspection", ""),
                    "condition": row.get("condition", "unknown"),
                    "location_description": row.get("location", ""),
                    "owner": row.get("owner", ""),
                    "sector": row.get("sector", "")
                }
            }
            features.append(feature)

    collection = {"type": "FeatureCollection", "features": features}
    with open(output_path, "w") as f:
        json.dump(collection, f, indent=2)

    print(f"Converted {len(features)} assets ({skipped} skipped)")

cmms_csv_to_geojson("equipment_export.csv", "equipment.geojson")
```

### Expected CSV Format

```csv
asset_id,asset_type,subtype,manufacturer,model,latitude,longitude,install_date,last_inspection,condition,location,owner,sector
SIG-2024-0451,Railway Signal,Colour Light (4-aspect),Alstom,FS-4000,53.38,-1.50,2019-06-15,2025-11-20,good,Sheffield Station Platform 3,Network Rail,TRAN
SUB-2023-0089,Substation,132kV/33kV,Siemens,8DA10,51.51,-0.13,2010-03-22,2025-08-15,fair,Central London Grid,UK Power Networks,ENER
PMP-2024-0212,Pumping Station,Wastewater Lift,Xylem,Flygt CP3300,52.48,-1.89,2018-09-10,2025-10-01,good,Birmingham South Lift,Severn Trent,WATR
```

### Using ogr2ogr for CSV Conversion

For simple CSV-to-GeoJSON conversion without custom logic:

```bash
docker compose run converter ogr2ogr \
  -f GeoJSON /data/extracted/equipment.geojson \
  /data/raw/equipment.csv \
  -oo X_POSSIBLE_NAMES=longitude \
  -oo Y_POSSIBLE_NAMES=latitude \
  -oo KEEP_GEOM_COLUMNS=NO
```

---

## Conversion Pipeline

### Standard Conversion (No Clustering)

For datasets under 10,000 features, convert directly:

```bash
docker compose run converter tippecanoe \
  -o /data/tiles/equipment.mbtiles \
  -l equipment \
  -z14 -Z4 \
  /data/extracted/equipment.geojson
```

### Conversion with Clustering

For datasets over 10,000 features, enable clustering to prevent overcrowding at low zoom levels:

```bash
docker compose run converter tippecanoe \
  -o /data/tiles/equipment.mbtiles \
  -l equipment \
  -z14 -Z6 \
  --cluster-distance=40 \
  --accumulate-attribute=asset_count:sum \
  --drop-densest-as-needed \
  /data/extracted/equipment.geojson
```

| Flag | Purpose |
|------|---------|
| `--cluster-distance=40` | Cluster features within 40 pixels at each zoom level |
| `--accumulate-attribute=asset_count:sum` | Sum a numeric attribute across clustered features |
| `--drop-densest-as-needed` | Drop overlapping features at low zoom to maintain readability |

Before running tippecanoe with clustering, add an `asset_count` property set to `1` on each feature so the accumulation produces a meaningful total.

### Separate Tilesets by Category

For large, diverse equipment inventories, consider splitting by category:

```bash
# Filter by asset_type, then convert each
jq '{type: "FeatureCollection", features: [.features[] | select(.properties.asset_type == "Railway Signal")]}' \
  equipment.geojson > railway-signals.geojson

jq '{type: "FeatureCollection", features: [.features[] | select(.properties.asset_type == "Substation")]}' \
  equipment.geojson > substations.geojson

# Convert each
docker compose run converter tippecanoe \
  -o /data/tiles/railway-signals.mbtiles \
  -l railway_signals -z14 -Z4 railway-signals.geojson

docker compose run converter tippecanoe \
  -o /data/tiles/substations.mbtiles \
  -l substations -z14 -Z4 substations.geojson
```

---

## Styling by Asset Type

### Color by Equipment Category

```javascript
map.addLayer({
  id: 'equipment-layer',
  type: 'circle',
  source: 'equipment',
  'source-layer': 'equipment',
  paint: {
    'circle-color': [
      'match', ['get', 'asset_type'],
      'Railway Signal', '#ff9900',
      'Substation', '#ffcc00',
      'Pumping Station', '#3399ff',
      'Telecom Tower', '#cc66ff',
      'Transformer', '#ff4444',
      'Valve', '#66cc66',
      '#666666'  // default
    ],
    'circle-stroke-color': '#ffffff',
    'circle-stroke-width': 1.5
  }
});
```

### Size by Condition

Assets in worse condition appear larger to draw attention:

```javascript
paint: {
  'circle-radius': [
    'match', ['get', 'condition'],
    'critical', 12,
    'poor', 10,
    'fair', 8,
    'good', 6,
    6  // default
  ]
}
```

### Combined: Color by Type, Size by Condition

```javascript
map.addLayer({
  id: 'equipment-styled',
  type: 'circle',
  source: 'equipment',
  'source-layer': 'equipment',
  paint: {
    'circle-color': [
      'match', ['get', 'asset_type'],
      'Railway Signal', '#ff9900',
      'Substation', '#ffcc00',
      'Pumping Station', '#3399ff',
      'Telecom Tower', '#cc66ff',
      'Transformer', '#ff4444',
      '#666666'
    ],
    'circle-radius': [
      'match', ['get', 'condition'],
      'critical', 12,
      'poor', 10,
      'fair', 8,
      'good', 6,
      6
    ],
    'circle-stroke-color': [
      'match', ['get', 'condition'],
      'critical', '#ff0000',
      'poor', '#ff8800',
      '#ffffff'
    ],
    'circle-stroke-width': [
      'match', ['get', 'condition'],
      'critical', 3,
      'poor', 2,
      1.5
    ]
  }
});
```

---

## Clustered View at Low Zoom

When tippecanoe generates clustered tiles, the resulting features at low zoom levels contain a `point_count` property (or an accumulated attribute) indicating how many source features are grouped together.

### Cluster circle layer

```javascript
// Clustered points (low zoom)
map.addLayer({
  id: 'equipment-clusters',
  type: 'circle',
  source: 'equipment',
  'source-layer': 'equipment',
  filter: ['has', 'point_count'],
  paint: {
    'circle-color': [
      'step', ['get', 'point_count'],
      '#51bbd6',    // 1-9 features
      10, '#f1f075', // 10-49
      50, '#f28cb1'  // 50+
    ],
    'circle-radius': [
      'step', ['get', 'point_count'],
      15,          // 1-9
      10, 20,      // 10-49
      50, 25       // 50+
    ]
  }
});

// Cluster count label
map.addLayer({
  id: 'equipment-cluster-count',
  type: 'symbol',
  source: 'equipment',
  'source-layer': 'equipment',
  filter: ['has', 'point_count'],
  layout: {
    'text-field': '{point_count}',
    'text-font': ['Open Sans Bold'],
    'text-size': 12
  }
});

// Individual points (high zoom)
map.addLayer({
  id: 'equipment-individual',
  type: 'circle',
  source: 'equipment',
  'source-layer': 'equipment',
  filter: ['!', ['has', 'point_count']],
  paint: {
    'circle-color': '#ff9900',
    'circle-radius': 8,
    'circle-stroke-color': '#ffffff',
    'circle-stroke-width': 2
  }
});
```

At low zoom levels, the cluster circles show aggregate counts. As the user zooms in, clusters break apart and individual assets appear with full attribute detail.

---

## Filtering Equipment

### By asset type

```javascript
map.setFilter('equipment-layer', ['==', 'asset_type', 'Substation']);
```

### By condition

```javascript
// Show only critical and poor condition assets
map.setFilter('equipment-layer', [
  'in', 'condition', 'critical', 'poor'
]);
```

### By sector

```javascript
map.setFilter('equipment-layer', ['==', 'sector', 'ENER']);
```

### Combined filters

```javascript
map.setFilter('equipment-layer', [
  'all',
  ['==', 'asset_type', 'Substation'],
  ['in', 'condition', 'critical', 'poor'],
  ['==', 'sector', 'ENER']
]);
```

---

## Update Procedure

Equipment data changes as assets are installed, inspected, or decommissioned. Follow this cycle:

1. **Export** updated data from CMMS/EAM system (CSV)
2. **Convert** to GeoJSON using the Python script or ogr2ogr
3. **Validate** the GeoJSON (coordinate ranges, required properties)
4. **Run tippecanoe** with the `-f` flag to overwrite existing MBTiles
5. **Restart** tileserver to serve the updated tiles

```bash
python scripts/cmms_to_geojson.py
docker compose run converter tippecanoe \
  -o /data/tiles/equipment.mbtiles \
  -l equipment -z14 -Z6 \
  --cluster-distance=40 -f \
  /data/extracted/equipment.geojson
docker compose restart tileserver
```

For scheduled updates, add this to a cron job or CI/CD pipeline. See [Updates & Scheduling](04e-MAINTENANCE.md).

---

## Related Pages

- [Custom Tiles](07-CUSTOM-TILES.md) -- parent page with workflow overview
- [GeoJSON Authoring](07a-GEOJSON-AUTHORING.md) -- creating and validating GeoJSON
- [Per-Customer Facility Layers](07b-CUSTOMER-LAYERS.md) -- customer-specific facility overlays
- [Custom Layer Styling](07d-STYLING.md) -- comprehensive paint and layout property reference
- [Map Cards & Popups](07e-CARDS-DISPLAY.md) -- displaying equipment details on click
- [Conversion & Tippecanoe](04c-CONVERT.md) -- detailed tippecanoe options and flags
- [Updates & Scheduling](04e-MAINTENANCE.md) -- automating data refresh

---

*[Home](INDEX.md) | [Custom Tiles](07-CUSTOM-TILES.md) | [Customer Layers](07b-CUSTOMER-LAYERS.md) | [Styling](07d-STYLING.md)*
