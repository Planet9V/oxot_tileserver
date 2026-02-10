# Shipping & Logistics Visualization

> **Last Updated**: 2026-02-11 02:00 UTC

[Home](INDEX.md) > [Use Cases](13-USE-CASES.md) > [Supply Chain](13e-SUPPLY-CHAIN-MAPPING.md) > Shipping & Logistics

---

## Overview

Shipping and freight logistics represent the physical transport edges in any supply chain graph. While the parent page ([Supply Chain Visualization](13e-SUPPLY-CHAIN-MAPPING.md)) models the full multi-hop chain from raw materials to final delivery, this page focuses specifically on the transport layer -- vessel positions, port infrastructure, rail corridors, road freight networks, and intermodal connections.

The primary data source for maritime shipping is the Automatic Identification System (AIS), a transponder protocol required on all commercial vessels over 300 gross tonnage by the International Maritime Organization. AIS broadcasts vessel position, course, speed, and identity every 2--30 seconds, creating a real-time picture of global maritime traffic. Several providers aggregate this data and expose it through APIs or data feeds.

---

## AIS Vessel Tracking

### Data Sources

| Source | URL | Vessels | Coverage | Access |
|--------|-----|---------|----------|--------|
| MarineTraffic | https://www.marinetraffic.com/ | 550K+ tracked, 13K+ receivers | Global oceans | Free tier: 100 API calls/day; Commercial: unlimited |
| AISHub | https://www.aishub.net/ | Community-contributed | Global | Free (contribute an AIS receiver to join) |
| Marine Cadastre (US) | https://hub.marinecadastre.gov/pages/vesseltraffic | Historical density | US coastal waters | Free (public domain) |
| VesselFinder | https://www.vesselfinder.com/ | 120K+ live | Global | Free tier / Commercial API |
| Spire Maritime | https://spire.com/maritime/ | Global satellite AIS | Open ocean (satellite) | Commercial |

### Fetching Live Vessel Positions (MarineTraffic API)

```python
import os
import requests
import json

def fetch_vessel_positions(area=None, ship_type=None):
    """
    Fetch current vessel positions from MarineTraffic PS07 endpoint.
    area: [lon_min, lat_min, lon_max, lat_max] bounding box
    ship_type: integer vessel type code (7=cargo, 8=tanker, 6=passenger)
    """
    api_key = os.environ["MARINETRAFFIC_API_KEY"]
    url = f"https://services.marinetraffic.com/api/exportvessels/v:8/{api_key}"

    params = {"msgtype": "simple", "protocol": "jsono"}
    if area:
        params["MINLAT"] = area[1]
        params["MAXLAT"] = area[3]
        params["MINLON"] = area[0]
        params["MAXLON"] = area[2]
    if ship_type:
        params["SHIPTYPE"] = ship_type

    resp = requests.get(url, params=params)
    resp.raise_for_status()
    return resp.json()
```

### Converting Vessel Positions to GeoJSON

```python
def vessels_to_geojson(vessel_data):
    """Convert MarineTraffic vessel array to GeoJSON FeatureCollection."""
    features = []
    for v in vessel_data:
        if v.get("LON") is None or v.get("LAT") is None:
            continue
        feature = {
            "type": "Feature",
            "geometry": {
                "type": "Point",
                "coordinates": [float(v["LON"]), float(v["LAT"])]
            },
            "properties": {
                "mmsi": v.get("MMSI"),
                "ship_name": v.get("SHIPNAME", "Unknown"),
                "ship_type": v.get("SHIPTYPE"),
                "speed_knots": v.get("SPEED", 0) / 10.0,
                "course": v.get("COURSE"),
                "heading": v.get("HEADING"),
                "status": v.get("STATUS"),
                "destination": v.get("DESTINATION", ""),
                "eta": v.get("ETA", ""),
                "timestamp": v.get("TIMESTAMP"),
                "flag": v.get("FLAG"),
                "length": v.get("LENGTH"),
                "width": v.get("WIDTH"),
                "draught": v.get("DRAUGHT")
            }
        }
        features.append(feature)

    return {"type": "FeatureCollection", "features": features}
```

### Styling Vessels by Type

```javascript
map.addSource('vessels', {
  type: 'vector',
  url: 'http://localhost:8080/data/vessels.json'
});

map.addLayer({
  id: 'vessel-positions',
  type: 'circle',
  source: 'vessels',
  'source-layer': 'vessel_positions',
  paint: {
    'circle-color': [
      'match', ['get', 'ship_type'],
      6,  '#FFD700',   // Passenger: gold
      7,  '#4169E1',   // Cargo: blue
      8,  '#DC143C',   // Tanker: red
      9,  '#FF8C00',   // Unknown/Other: orange
      70, '#4169E1',   // Cargo (detailed code)
      71, '#4169E1',   // Cargo - hazardous A
      80, '#DC143C',   // Tanker
      81, '#DC143C',   // Tanker - hazardous A
      /* fallback */ '#888888'
    ],
    'circle-radius': [
      'interpolate', ['linear'], ['zoom'],
      2, 2,
      8, 5,
      14, 10
    ],
    'circle-stroke-width': 1,
    'circle-stroke-color': '#333333'
  }
});
```

### Animating Vessel Movement

For near-real-time display, poll the API at intervals and animate position transitions:

```javascript
const POLL_INTERVAL_MS = 60000; // 1 minute

let previousPositions = {};

async function updateVesselPositions() {
  const resp = await fetch('/api/proxy/marinetraffic/positions');
  const geojson = await resp.json();

  // Animate each vessel from previous to new position
  for (const feature of geojson.features) {
    const mmsi = feature.properties.mmsi;
    const prev = previousPositions[mmsi];
    if (prev) {
      // Interpolate position over 1 second for smooth animation
      animatePoint(mmsi, prev, feature.geometry.coordinates, 1000);
    }
    previousPositions[mmsi] = feature.geometry.coordinates;
  }

  map.getSource('vessels-live').setData(geojson);
}

setInterval(updateVesselPositions, POLL_INTERVAL_MS);
```

---

## Port Infrastructure Mapping

### World Port Index

The World Port Index (WPI), published by the National Geospatial-Intelligence Agency, catalogs 3,700+ ports worldwide with standardized attributes.

**Download**: https://msi.nga.mil/Publications/WPI

### WPI Fields of Interest

| Field | Description | Use |
|-------|-------------|-----|
| PORT_NAME | Port name | Label |
| LATITUDE / LONGITUDE | Location | Geometry |
| COUNTRY_CODE | ISO country code | Filtering |
| HARBOR_SIZE | Very Small / Small / Medium / Large | Symbol sizing |
| MAX_VESSEL_LENGTH | Maximum vessel length (meters) | Capacity indicator |
| CHANNEL_DEPTH | Approach channel depth (meters) | Accessibility |
| CARGO_WHARF_DEPTH | Depth at cargo wharf (meters) | Tanker/bulk access |
| SHELTER | Shelter afforded (Excellent / Good / Fair / Poor) | Risk factor |
| CRANES | Crane availability | Container handling |
| DRYDOCK | Drydock size | Ship repair capability |

### Converting WPI to GeoJSON

```python
import csv
import json

def wpi_to_geojson(csv_path):
    """Convert World Port Index CSV to GeoJSON."""
    features = []
    with open(csv_path, 'r', encoding='utf-8') as f:
        reader = csv.DictReader(f)
        for row in reader:
            try:
                lon = float(row['LONGITUDE'])
                lat = float(row['LATITUDE'])
            except (ValueError, KeyError):
                continue

            feature = {
                "type": "Feature",
                "geometry": {"type": "Point", "coordinates": [lon, lat]},
                "properties": {
                    "name": row.get('PORT_NAME', ''),
                    "country": row.get('COUNTRY_CODE', ''),
                    "harbor_size": row.get('HARBOR_SIZE', ''),
                    "max_vessel_length": row.get('MAX_VESSEL_LENGTH', ''),
                    "channel_depth": row.get('CHANNEL_DEPTH', ''),
                    "shelter": row.get('SHELTER', ''),
                    "cranes": row.get('CRANES', ''),
                    "drydock": row.get('DRYDOCK', '')
                }
            }
            features.append(feature)

    return {"type": "FeatureCollection", "features": features}
```

### Port Tile Generation

```bash
tippecanoe -o data/tiles/ports.mbtiles \
  -l world_ports \
  -z14 -Z0 \
  --drop-densest-as-needed \
  --cluster-distance=50 \
  data/geojson/world-ports.geojson
```

### Port Styling by Size

```javascript
map.addLayer({
  id: 'port-markers',
  type: 'circle',
  source: 'ports',
  'source-layer': 'world_ports',
  paint: {
    'circle-color': '#1E90FF',
    'circle-radius': [
      'match', ['get', 'harbor_size'],
      'Large',      12,
      'Medium',     8,
      'Small',      5,
      'Very Small', 3,
      /* fallback */ 4
    ],
    'circle-stroke-width': 2,
    'circle-stroke-color': '#ffffff'
  }
});
```

---

## Rail Freight Corridors

### OpenRailwayMap Data

OpenRailwayMap extracts railway infrastructure from OpenStreetMap tags. Relevant tags for freight corridors:

| OSM Tag | Value | Meaning |
|---------|-------|---------|
| `railway` | `rail` | Standard gauge railway line |
| `railway` | `narrow_gauge` | Narrow gauge line |
| `usage` | `main` / `branch` / `industrial` | Line classification |
| `service` | `yard` / `spur` | Yard tracks, industrial spurs |
| `electrified` | `yes` / `no` / `contact_line` | Electrification status |
| `maxspeed` | numeric | Speed limit (km/h) |
| `gauge` | numeric | Track gauge (mm) |

### Extracting Rail Data with osmium

```bash
# Extract railway lines from a regional PBF
osmium tags-filter north-america-latest.osm.pbf \
  w/railway=rail,narrow_gauge \
  -o data/raw/railways-na.osm.pbf

# Convert to GeoJSON with ogr2ogr
ogr2ogr -f GeoJSON data/geojson/railways.geojson \
  data/raw/railways-na.osm.pbf lines \
  -sql "SELECT * FROM lines WHERE other_tags LIKE '%railway%'"
```

### Rail Tile Generation

```bash
tippecanoe -o data/tiles/railways.mbtiles \
  -l railways \
  -z14 -Z4 \
  --no-simplification-of-shared-nodes \
  --simplification=5 \
  data/geojson/railways.geojson
```

### Rail Corridor Styling

```javascript
map.addLayer({
  id: 'rail-lines',
  type: 'line',
  source: 'railways',
  'source-layer': 'railways',
  paint: {
    'line-color': [
      'match', ['get', 'usage'],
      'main',       '#B22222',
      'branch',     '#CD853F',
      'industrial', '#696969',
      /* fallback */ '#A0A0A0'
    ],
    'line-width': [
      'interpolate', ['linear'], ['zoom'],
      4, 1,
      10, 2,
      14, 4
    ]
  }
});
```

---

## Intermodal Connections

The highest-value logistics visualization shows how cargo transitions between transport modes at intermodal points -- ports where containers move from ship to rail, rail terminals where freight transfers to truck, and airports with cargo facilities.

### Identifying Intermodal Nodes

```python
def find_intermodal_connections(ports_geojson, rail_geojson, buffer_km=5):
    """Find ports within buffer_km of a railway line (intermodal candidates)."""
    import geopandas as gpd
    from shapely.geometry import Point

    ports = gpd.GeoDataFrame.from_features(ports_geojson['features'],
                                            crs="EPSG:4326")
    rails = gpd.GeoDataFrame.from_features(rail_geojson['features'],
                                            crs="EPSG:4326")

    # Project to meters for buffering
    ports_m = ports.to_crs("EPSG:3857")
    rails_m = rails.to_crs("EPSG:3857")

    # Buffer rail lines by 5 km
    rail_buffer = rails_m.geometry.buffer(buffer_km * 1000).unary_union

    # Find ports within the buffer
    intermodal = ports_m[ports_m.geometry.within(rail_buffer)]
    return intermodal.to_crs("EPSG:4326")
```

### Intermodal Node Styling

```javascript
map.addLayer({
  id: 'intermodal-nodes',
  type: 'symbol',
  source: 'intermodal',
  'source-layer': 'intermodal_points',
  layout: {
    'icon-image': 'intermodal-icon',
    'icon-size': 0.8,
    'text-field': ['get', 'name'],
    'text-font': ['Open Sans Semibold'],
    'text-offset': [0, 1.2],
    'text-size': 11
  }
});
```

---

## Marine Cadastre: Historical Vessel Density

For long-term traffic pattern analysis, the Bureau of Ocean Energy Management (BOEM) and NOAA publish historical vessel traffic density rasters through the Marine Cadastre.

### Data Characteristics

- **Format**: GeoTIFF raster grids (100m x 100m cells)
- **Coverage**: US Exclusive Economic Zone (EEZ)
- **Temporal**: Annual or monthly aggregates
- **Values**: Vessel transit count per cell

### Converting Density Raster to Vector Tiles

```bash
# Convert GeoTIFF to contour polygons using GDAL
gdal_contour -a density -i 50 \
  data/raw/vessel-density-2025.tif \
  data/geojson/vessel-density-contours.geojson

# Generate tiles
tippecanoe -o data/tiles/vessel-density.mbtiles \
  -l vessel_density \
  -z12 -Z2 \
  --coalesce-densest-as-needed \
  data/geojson/vessel-density-contours.geojson
```

---

## Refresh Strategy

| Data Layer | Source | Refresh Interval | Rationale |
|------------|--------|------------------|-----------|
| Live vessel positions | MarineTraffic API | 1--5 minutes | Near-real-time situational awareness |
| Port infrastructure | World Port Index | Quarterly | WPI publishes updates every 3--6 months |
| Rail network | OpenRailwayMap | Monthly | OSM edit frequency for railway tags |
| Vessel density (historical) | Marine Cadastre | Annually | Published as annual summaries |
| AIS community feed | AISHub | Continuous (streaming) | Push-based data exchange |

---

## References

AISHub. (2026). *AISHub: Free AIS data sharing*. https://www.aishub.net/

Bureau of Ocean Energy Management & NOAA. (2026). *Marine Cadastre: Vessel traffic data*. https://hub.marinecadastre.gov/pages/vesseltraffic

MarineTraffic. (2026). *MarineTraffic API services*. https://www.marinetraffic.com/en/ais-api-services

National Geospatial-Intelligence Agency. (2026). *World port index (Pub. 150)*. https://msi.nga.mil/Publications/WPI

OpenRailwayMap Contributors. (2026). *OpenRailwayMap*. https://www.openrailwaymap.org/

Spire Global. (2026). *Spire Maritime: Satellite AIS data*. https://spire.com/maritime/

VesselFinder. (2026). *VesselFinder: Free AIS vessel tracking*. https://www.vesselfinder.com/

---

*[Home](INDEX.md) | [Use Cases](13-USE-CASES.md) | [Supply Chain](13e-SUPPLY-CHAIN-MAPPING.md) | [Simulation & War Gaming](13f-SIMULATION-WARGAMING.md)*
