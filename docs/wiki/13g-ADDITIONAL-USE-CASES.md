# Additional Use Cases

> **Last Updated**: 2026-02-11 02:00 UTC

[Home](INDEX.md) > [Use Cases](13-USE-CASES.md) > Additional Use Cases

---

## Overview

This page documents supplementary use cases for the OXOT Tileserver that extend beyond the primary categories of cyber attack mapping, threat intelligence, supply chain visualization, and simulation. Each use case follows the standard pipeline described in [Use Cases](13-USE-CASES.md): fetch data from an external source, transform to GeoJSON, convert to vector tiles with tippecanoe, and serve through tileserver-gl.

These use cases are presented as implementation-ready recipes. They assume a running tileserver deployment and familiarity with the [Custom Tile Creation](07-CUSTOM-TILES.md) workflow.

---

## Climate Risk Overlays

### FEMA National Flood Hazard Layer (NFHL)

The NFHL provides flood zone boundaries for the entire United States, classified by flood recurrence interval.

**URL**: https://www.fema.gov/flood-maps/national-flood-hazard-layer

**Data format**: Shapefile / GeoJSON via FEMA Map Service REST API

**Flood zone codes**:
| Zone | Description | Annual Probability |
|------|-------------|--------------------|
| A, AE, AH, AO | 100-year flood zone (Special Flood Hazard Area) | 1% annual chance |
| X (shaded) | 500-year flood zone | 0.2% annual chance |
| X (unshaded) | Minimal flood hazard | < 0.2% annual chance |
| V, VE | Coastal high-velocity wave action | 1% annual chance + waves |

```bash
# Download NFHL for a specific state (example: Virginia)
curl -o data/raw/nfhl-va.zip \
  "https://hazards.fema.gov/nfhlv2/output/State/NFHL_51_20260101.zip"

# Extract and convert to GeoJSON
ogr2ogr -f GeoJSON data/geojson/flood-zones-va.geojson \
  /vsizip/data/raw/nfhl-va.zip/NFHL_51_20260101.gdb \
  S_Fld_Haz_Ar \
  -t_srs EPSG:4326

# Generate tiles
tippecanoe -o data/tiles/flood-zones-va.mbtiles \
  -l flood_zones \
  -z14 -Z6 \
  --coalesce-densest-as-needed \
  data/geojson/flood-zones-va.geojson
```

### Wildfire Risk

The Wildland Fire Assessment System (WFAS) and USGS provide fire danger ratings and historical burn perimeters.

**URL**: https://www.wfas.net/

**Related sources**:
- NIFC InciWeb active incidents: https://inciweb.wildfire.gov/
- USGS GeoMAC historical perimeters: https://www.geomac.gov/ (archived; current data at NIFC)
- NASA FIRMS active fire detections: https://firms.modaps.eosdis.nasa.gov/

```python
import requests

def fetch_firms_active_fires(country="USA", days=1):
    """Fetch active fire detections from NASA FIRMS (MODIS/VIIRS)."""
    api_key = os.environ.get("NASA_FIRMS_API_KEY", "DEMO_KEY")
    url = (f"https://firms.modaps.eosdis.nasa.gov/api/country/csv/"
           f"{api_key}/VIIRS_SNPP_NRT/{country}/{days}")
    resp = requests.get(url)
    resp.raise_for_status()
    # Parse CSV response to GeoJSON
    lines = resp.text.strip().split('\n')
    # ... convert lat/lon columns to GeoJSON points
    return geojson
```

### Sea Level Rise Projections

Climate Central provides sea level rise projection data showing areas that would be inundated at various rise levels.

**URL**: https://coastal.climatecentral.org/

**Implementation**: Download projected inundation boundaries at 1m, 2m, and 3m rise levels. Overlay on infrastructure layers to identify which substations, water plants, and telecom towers fall within projected flood zones.

---

## Regulatory & Jurisdiction Mapping

### Compliance Zone Boundaries

| Source | URL | Data | Use Case |
|--------|-----|------|----------|
| US Census TIGER/Line | https://www.census.gov/geographies/mapping-files/time-series/geo/tiger-line-file.html | State, county, tract, block group boundaries | Jurisdictional authority for compliance |
| EPA Facility Registry | https://www.epa.gov/frs | Regulated facility locations and boundaries | Environmental compliance zones |
| NRC Emergency Planning Zones | https://www.nrc.gov/about-nrc/emerg-preparedness.html | 10-mile plume exposure and 50-mile ingestion pathway EPZs | Nuclear plant emergency zones |
| NERC Reliability Regions | https://www.nerc.com/AboutNERC/keyplayers/Pages/default.aspx | Six regional entity boundaries (MRO, NPCC, RF, SERC, Texas RE, WECC) | Electric grid regulatory jurisdiction |
| FERC Jurisdictional Boundaries | https://www.ferc.gov/ | Interstate pipeline and transmission boundaries | Energy regulatory mapping |

### NRC Emergency Planning Zones

Nuclear Regulatory Commission emergency planning zones (EPZs) define two concentric areas around each nuclear plant:

```python
import json
from shapely.geometry import Point, mapping

NRC_PLANTS = [
    {"name": "Surry", "lon": -76.698, "lat": 37.166},
    {"name": "North Anna", "lon": -77.790, "lat": 38.061},
    {"name": "Calvert Cliffs", "lon": -76.442, "lat": 38.435},
    # ... full list from NRC site
]

features = []
for plant in NRC_PLANTS:
    center = Point(plant['lon'], plant['lat'])

    # 10-mile (16 km) Plume Exposure Pathway EPZ
    # 50-mile (80 km) Ingestion Pathway EPZ
    for radius_km, epz_type in [(16, "plume_exposure"), (80, "ingestion_pathway")]:
        buffer = center.buffer(radius_km / 111.32)  # Rough degree conversion
        features.append({
            "type": "Feature",
            "geometry": mapping(buffer),
            "properties": {
                "plant_name": plant['name'],
                "epz_type": epz_type,
                "radius_km": radius_km
            }
        })

geojson = {"type": "FeatureCollection", "features": features}
```

### NERC Reliability Region Tiles

```bash
# Download NERC region boundaries (available as shapefiles from NERC)
ogr2ogr -f GeoJSON data/geojson/nerc-regions.geojson \
  data/raw/nerc-regions.shp \
  -t_srs EPSG:4326

tippecanoe -o data/tiles/nerc-regions.mbtiles \
  -l nerc_regions \
  -z10 -Z2 \
  --coalesce-densest-as-needed \
  data/geojson/nerc-regions.geojson
```

---

## RF Propagation & Wireless Coverage

### FCC Antenna Structure Registration

The FCC Antenna Structure Registration (ASR) database contains all registered antenna structures in the United States -- broadcast towers, cell towers, microwave relay stations, and amateur radio towers.

**URL**: https://www.fcc.gov/antenna-structure-registration

**Download**: https://www.fcc.gov/ors/asr/

```bash
# Download ASR data
curl -o data/raw/asr-data.zip \
  "https://www.fcc.gov/file/asr_en.dat"

# Parse and convert to GeoJSON
python scripts/convert-fcc-asr.py \
  --input data/raw/asr-data.zip \
  --output data/geojson/fcc-towers.geojson
```

### RF Propagation Modeling with SPLAT!

SPLAT! (Signal Propagation, Loss, And Terrain) is an open-source RF propagation analysis tool that generates coverage maps using the Longley-Rice Irregular Terrain Model.

**URL**: https://www.qsl.net/kd2bd/splat.html

```bash
# Generate RF coverage prediction for a transmitter
splat -t transmitter.qth -o coverage -R 50 -sc

# Convert SPLAT! output to GeoTIFF
gdal_translate -of GTiff coverage-site_name.ppm data/raw/rf-coverage.tif

# Convert raster to vector contours for tile generation
gdal_contour -a signal_dbm -i 10 \
  data/raw/rf-coverage.tif \
  data/geojson/rf-coverage-contours.geojson

# Generate tiles
tippecanoe -o data/tiles/rf-coverage.mbtiles \
  -l rf_coverage \
  -z14 -Z6 \
  data/geojson/rf-coverage-contours.geojson
```

### Coverage Visualization

```javascript
map.addLayer({
  id: 'rf-coverage-fill',
  type: 'fill',
  source: 'rf-coverage',
  'source-layer': 'rf_coverage',
  paint: {
    'fill-color': [
      'interpolate', ['linear'], ['get', 'signal_dbm'],
      -120, '#2c7bb6',    // Very weak: blue
      -100, '#abd9e9',    // Weak: light blue
      -80,  '#ffffbf',    // Moderate: yellow
      -60,  '#fdae61',    // Strong: orange
      -40,  '#d7191c'     // Very strong: red
    ],
    'fill-opacity': 0.4
  }
});
```

---

## Asset Tracking

### Mobile Equipment GPS Feeds

Organizations with mobile assets -- vehicles, portable generators, mobile command posts, inspection drones -- can feed real-time GPS positions to the tileserver.

```python
import json
import time

def gps_feed_to_geojson(mqtt_topic="fleet/gps/#"):
    """
    Subscribe to MQTT GPS feed and write GeoJSON at intervals.
    Each message: {"vehicle_id": "V-042", "lat": 38.9, "lon": -77.0,
                   "speed_kmh": 45, "heading": 270, "timestamp": "..."}
    """
    import paho.mqtt.client as mqtt

    positions = {}

    def on_message(client, userdata, msg):
        data = json.loads(msg.payload)
        positions[data['vehicle_id']] = data

    client = mqtt.Client()
    client.on_message = on_message
    client.connect("mqtt-broker.internal", 1883)
    client.subscribe(mqtt_topic)
    client.loop_start()

    while True:
        # Write current positions to GeoJSON every 10 seconds
        features = [{
            "type": "Feature",
            "geometry": {
                "type": "Point",
                "coordinates": [p['lon'], p['lat']]
            },
            "properties": {
                "vehicle_id": p['vehicle_id'],
                "speed_kmh": p.get('speed_kmh', 0),
                "heading": p.get('heading', 0),
                "timestamp": p.get('timestamp', '')
            }
        } for p in positions.values()]

        geojson = {"type": "FeatureCollection", "features": features}
        with open("data/geojson/fleet-positions.geojson", "w") as f:
            json.dump(geojson, f)

        time.sleep(10)
```

### Historical Track Visualization

Render historical GPS tracks as animated lines:

```javascript
// Load track history as LineString features
map.addSource('vehicle-tracks', {
  type: 'geojson',
  data: trackHistoryGeoJSON
});

map.addLayer({
  id: 'vehicle-track-lines',
  type: 'line',
  source: 'vehicle-tracks',
  paint: {
    'line-color': '#4169E1',
    'line-width': 2,
    'line-gradient': [
      'interpolate', ['linear'], ['line-progress'],
      0, 'rgba(65, 105, 225, 0.2)',   // Faded at start (oldest)
      1, 'rgba(65, 105, 225, 1.0)'    // Solid at end (newest)
    ]
  },
  layout: {
    'line-cap': 'round',
    'line-join': 'round'
  }
});
```

---

## Insurance & Actuarial Mapping

### Catastrophe Model Overlays

Insurance and reinsurance companies use catastrophe models (RMS RiskLink, Moody's AIR, CoreLogic) to estimate probable maximum loss (PML) for natural catastrophe events. The geographic output of these models -- hazard zones, loss contours, portfolio exposure heat maps -- can be converted to vector tiles for overlay on infrastructure.

### Property Value Overlay

Geocoded property value data from public tax assessor records or aggregated sources enables loss estimation when combined with hazard layers.

```python
# Example: aggregate property values by census tract
import geopandas as gpd

tracts = gpd.read_file("data/raw/census-tracts.geojson")
properties = gpd.read_file("data/raw/property-values.csv")  # with lat/lon

# Spatial join: assign each property to a tract
joined = gpd.sjoin(properties, tracts, how="left", predicate="within")

# Aggregate by tract
tract_values = joined.groupby("GEOID").agg(
    total_value=("assessed_value", "sum"),
    property_count=("assessed_value", "count"),
    avg_value=("assessed_value", "mean")
).reset_index()

# Merge back to tract geometry for choropleth
result = tracts.merge(tract_values, on="GEOID")
result.to_file("data/geojson/property-values-by-tract.geojson", driver="GeoJSON")
```

### Loss History Geocoding

Historical insurance loss events can be geocoded and converted to a heat map layer showing loss density:

```bash
tippecanoe -o data/tiles/loss-history.mbtiles \
  -l loss_events \
  -z14 -Z4 \
  --cluster-distance=100 \
  --accumulate-attribute=loss_usd:sum \
  --accumulate-attribute=claim_count:sum \
  data/geojson/loss-events.geojson
```

---

## Underground Utility Mapping

### Data Sources

| Source | URL | Data | Coverage |
|--------|-----|------|----------|
| 811 "Call Before You Dig" | https://call811.com/ | Utility locate requests and mapped underground lines | US (state-by-state) |
| ASCE Subsurface Utility Engineering (SUE) | https://www.asce.org/ | Quality Level A--D underground mapping standards | Professional standard |
| OpenInfraMap | https://openinframap.org/ | OSM-derived underground utilities (limited) | Global (OSM coverage) |

### Combining Above-Ground and Below-Ground Layers

When underground utility data is available, display it alongside above-ground infrastructure to create a complete picture:

```javascript
// Underground utilities: dashed line styling to distinguish from surface
map.addLayer({
  id: 'underground-utilities',
  type: 'line',
  source: 'underground',
  'source-layer': 'utilities_underground',
  paint: {
    'line-color': [
      'match', ['get', 'utility_type'],
      'gas',      '#FFD700',
      'water',    '#4169E1',
      'sewer',    '#228B22',
      'electric', '#DC143C',
      'telecom',  '#FF8C00',
      /* fallback */ '#888888'
    ],
    'line-width': 3,
    'line-dasharray': [2, 2]
  }
});
```

Underground utility lines use the APWA (American Public Works Association) Uniform Color Code:

| Color | Utility |
|-------|---------|
| Red | Electric power |
| Yellow | Gas, oil, petroleum |
| Blue | Drinking water |
| Green | Sewer, storm drain |
| Orange | Telecommunications |
| Purple | Reclaimed water |
| White | Proposed excavation |
| Pink | Temporary survey markings |

---

## Historical Event Timelines

### Time-Slider UI

Add a time dimension to any data layer by filtering features based on a timestamp property:

```javascript
// Add time slider control
const slider = document.getElementById('time-slider');
const label = document.getElementById('time-label');

slider.addEventListener('input', function () {
  const year = parseInt(this.value);
  label.textContent = year;

  // Filter infrastructure layer to show only features existing in that year
  map.setFilter('infrastructure-points', [
    'all',
    ['<=', ['get', 'year_built'], year],
    ['any',
      ['!', ['has', 'year_decommissioned']],
      ['>=', ['get', 'year_decommissioned'], year]
    ]
  ]);
});
```

### Before/After Disaster Visualization

Use split-screen or swipe comparison to show infrastructure before and after a disaster event:

```javascript
import { Compare } from 'maplibre-gl-compare';

// Two map instances: before and after
const beforeMap = new maplibregl.Map({
  container: 'before',
  style: 'http://localhost:8080/styles/infrastructure-2024/style.json'
});

const afterMap = new maplibregl.Map({
  container: 'after',
  style: 'http://localhost:8080/styles/infrastructure-post-event/style.json'
});

new Compare(beforeMap, afterMap, '#comparison-container', {
  mousemove: true
});
```

---

## Implementation Priority Matrix

| Use Case | Data Availability | Implementation Effort | Operational Value | Priority |
|----------|-------------------|-----------------------|-------------------|----------|
| FEMA Flood Zones | High (free, authoritative) | Low | High | 1 |
| NRC Emergency Planning Zones | High (public data) | Low | High (nuclear sector) | 2 |
| Active Fire Detections (FIRMS) | High (free API) | Low | High (wildfire season) | 3 |
| Asset Tracking (GPS) | Depends on org | Medium | High (mobile ops) | 4 |
| FCC Tower Locations | High (public data) | Low | Medium | 5 |
| NERC Reliability Regions | Medium (requires download) | Low | Medium | 6 |
| Sea Level Rise | Medium (Climate Central) | Medium | Medium (coastal) | 7 |
| Insurance Loss Mapping | Low (proprietary) | Medium | High (actuarial) | 8 |
| Underground Utilities | Low (restricted) | High | High (excavation safety) | 9 |
| RF Propagation | Medium (requires SPLAT!) | High | Medium (telecom) | 10 |

---

## References

Climate Central. (2026). *Surging seas: Sea level rise analysis*. https://coastal.climatecentral.org/

FEMA. (2026). *National Flood Hazard Layer (NFHL)*. https://www.fema.gov/flood-maps/national-flood-hazard-layer

NASA. (2026). *Fire Information for Resource Management System (FIRMS)*. https://firms.modaps.eosdis.nasa.gov/

NERC. (2026). *Regional entities*. https://www.nerc.com/AboutNERC/keyplayers/Pages/default.aspx

NRC. (2026). *Emergency preparedness and response*. https://www.nrc.gov/about-nrc/emerg-preparedness.html

U.S. Census Bureau. (2026). *TIGER/Line shapefiles*. https://www.census.gov/geographies/mapping-files/time-series/geo/tiger-line-file.html

U.S. EPA. (2026). *Facility Registry Service (FRS)*. https://www.epa.gov/frs

U.S. FCC. (2026). *Antenna structure registration*. https://www.fcc.gov/antenna-structure-registration

---

*[Home](INDEX.md) | [Use Cases](13-USE-CASES.md) | [Simulation & War Gaming](13f-SIMULATION-WARGAMING.md) | [Data Sources](02-DATA-SOURCES.md)*
