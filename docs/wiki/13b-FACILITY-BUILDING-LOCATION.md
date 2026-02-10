# Physical Facility and Building Location

> **Last Updated**: 2026-02-11 02:00 UTC

[Home](INDEX.md) > [Use Cases](13-USE-CASES.md) > Physical Facility and Building Location

---

## Overview

Every operational-technology security programme begins with a question: *where are the assets?* This use case maps manufacturing facilities, data centres, water treatment plants, substations, and other physical buildings by combining open building-footprint datasets with proprietary facility metadata. The resulting tile layers support perimeter-security visualization, asset management dashboards, and rapid facility identification during incident response.

Building footprints provide the geometric envelope; the OXOT pipeline enriches those polygons with facility name, sector classification, criticality rating, employee count, and audit history. When rendered in MapLibre GL JS with 3D extrusion, operators can visually distinguish facility types at a glance and click any building to inspect its full operational profile.

This page covers the five authoritative building-footprint sources, a standardized data model for facility metadata, extraction and tiling workflows, 3D building extrusion, indoor mapping, and security-perimeter visualization.

---

## Data Sources

| Source | URL | Coverage | Features | Format | License |
|--------|-----|----------|----------|--------|---------|
| Microsoft Global Building Footprints | https://github.com/microsoft/GlobalMLBuildingFootprints | Global (1.2 billion footprints as of December 2025) | Building polygons, estimated heights | GeoJSON-L (gzipped) | ODbL |
| Overture Maps Buildings | https://overturemaps.org/ | Global | Building polygons fused from OSM, Microsoft, and Google | GeoParquet | ODbL + CDLA |
| OpenStreetMap Buildings | https://download.geofabrik.de/ | Global | `building=*` tag, name, height, levels | PBF | ODbL |
| Google Open Buildings | https://sites.research.google/open-buildings/ | Africa, South/SE Asia, Caribbean, Latin America | 1.8 billion footprints derived from satellite imagery | CSV / GeoJSON | CC BY 4.0 |
| Sentinel-2 Imagery | https://scihub.copernicus.eu/ | Global | 10 m multispectral satellite imagery | GeoTIFF (raster) | Free (Copernicus Open Access) |

### Source Selection Guidance

| Scenario | Recommended Source | Rationale |
|----------|-------------------|-----------|
| Global coverage, rapid deployment | Microsoft Global ML | Largest single dataset; GeoJSON-L ready for tippecanoe |
| Highest attribution quality | OpenStreetMap via Geofabrik | Community-curated names, types, and levels |
| Multi-source fusion | Overture Maps | Deduplicates and merges OSM + Microsoft + Google |
| Developing regions with sparse OSM | Google Open Buildings | Best coverage in Africa and South/SE Asia |
| Custom change detection | Sentinel-2 | 10 m imagery for before/after comparison |

---

## Data Model

Every facility is represented as a GeoJSON Feature. The property schema is designed to be compatible with the [Per-Customer Facility Layers](07b-CUSTOMER-LAYERS.md) schema so that building footprints and point-based customer layers can coexist in the same map application.

### Facility Feature Schema

```json
{
  "type": "Feature",
  "geometry": {
    "type": "Polygon",
    "coordinates": [
      [
        [-87.63, 41.88],
        [-87.63, 41.89],
        [-87.62, 41.89],
        [-87.62, 41.88],
        [-87.63, 41.88]
      ]
    ]
  },
  "properties": {
    "facility_id": "MFG-2024-0012",
    "facility_name": "Acme Manufacturing Plant",
    "facility_type": "Chemical Manufacturing",
    "sector": "CMAN",
    "address": "1200 Industrial Blvd, Gary, IN 46402",
    "company": "Acme Corp",
    "employee_count": 450,
    "area_sqm": 28500,
    "building_count": 7,
    "height": 18.5,
    "perimeter_secured": true,
    "last_audit": "2025-11-15",
    "criticality": "high"
  }
}
```

### Property Dictionary

| Property | Type | Required | Description |
|----------|------|----------|-------------|
| `facility_id` | string | yes | Unique identifier following `{SECTOR}-{YEAR}-{SEQ}` pattern |
| `facility_name` | string | yes | Human-readable facility name |
| `facility_type` | string | yes | Free-text classification (e.g., Chemical Manufacturing, Water Treatment) |
| `sector` | string | yes | CISA sector code (ENER, WATR, CMAN, HLTH, etc.) |
| `address` | string | no | Street address for geocoding verification |
| `company` | string | no | Operating company name |
| `employee_count` | integer | no | Approximate headcount |
| `area_sqm` | number | no | Building footprint area in square metres |
| `building_count` | integer | no | Number of buildings within the facility perimeter |
| `height` | number | no | Building height in metres (for 3D extrusion) |
| `perimeter_secured` | boolean | no | Whether the facility has monitored perimeter security |
| `last_audit` | string (ISO 8601 date) | no | Date of most recent physical security audit |
| `criticality` | string | yes | One of `critical`, `high`, `medium`, `low` |

---

## Building Footprint Extraction

### Microsoft Global Footprints

The Microsoft dataset is distributed as gzipped GeoJSON-L files partitioned by country and region. Each line is a single GeoJSON Feature.

```bash
# Step 1 -- Download the global dataset (or a country-specific file)
wget "https://minedbuildings.blob.core.windows.net/global-buildings/2025-02-28/global-buildings.geojsonl.gz" \
  -O data/raw/buildings-global.geojsonl.gz

# Step 2 -- Filter to an area of interest using ogr2ogr
ogr2ogr -f GeoJSONSeq data/geojson/buildings-chicago.geojson \
  data/raw/buildings-global.geojsonl.gz \
  -spat -87.7 41.8 -87.5 42.0

# Step 3 -- Convert to MBTiles with tippecanoe
tippecanoe -o data/tiles/buildings.mbtiles \
  -l buildings \
  -z16 -Z12 \
  --coalesce-densest-as-needed \
  data/geojson/buildings-chicago.geojson
```

### Overture Maps via DuckDB

Overture distributes data as GeoParquet on Amazon S3. DuckDB provides efficient SQL-based extraction.

```sql
-- Install spatial extension
INSTALL spatial; LOAD spatial;

-- Query Overture buildings for a bounding box
COPY (
  SELECT id, geometry, names, height, num_floors, class, sources
  FROM read_parquet('s3://overturemaps-us-west-2/release/2025-12/theme=buildings/type=building/*')
  WHERE bbox.xmin > -87.7 AND bbox.xmax < -87.5
    AND bbox.ymin > 41.8 AND bbox.ymax < 42.0
) TO 'data/geojson/overture-buildings.geojson'
WITH (FORMAT GDAL, DRIVER 'GeoJSON');
```

### OpenStreetMap via Geofabrik and osmium

```bash
# Download regional extract
wget "https://download.geofabrik.de/north-america/us/illinois-latest.osm.pbf" \
  -O data/raw/illinois.osm.pbf

# Extract buildings only
osmium tags-filter data/raw/illinois.osm.pbf w/building \
  -o data/raw/illinois-buildings.osm.pbf

# Convert to GeoJSON
ogr2ogr -f GeoJSON data/geojson/osm-buildings.geojson \
  data/raw/illinois-buildings.osm.pbf multipolygons
```

---

## Enrichment Pipeline

Building footprints from public datasets lack facility-specific metadata. The enrichment pipeline joins footprint polygons with proprietary facility records using spatial intersection.

### Spatial Join with GeoPandas

```python
import geopandas as gpd

# Load building footprints and facility points
buildings = gpd.read_file("data/geojson/buildings-chicago.geojson")
facilities = gpd.read_file("data/geojson/customer-facilities.geojson")

# Spatial join -- find the footprint polygon that contains each facility point
joined = gpd.sjoin(buildings, facilities, how="inner", predicate="contains")

# Carry forward facility properties onto the building polygon
enriched = joined[["geometry", "facility_id", "facility_name",
                    "facility_type", "sector", "criticality", "height"]]

enriched.to_file("data/geojson/enriched-facilities.geojson", driver="GeoJSON")
```

### Tile Generation from Enriched Data

```bash
tippecanoe -o data/tiles/facilities.mbtiles \
  -l facilities \
  -z16 -Z8 \
  --coalesce-densest-as-needed \
  --extend-zooms-if-still-dropping \
  data/geojson/enriched-facilities.geojson
```

After generation, add the tileset to `tileserver-config.json` and reload. See [Loading & Verification](04d-LOAD.md).

---

## 3D Building Extrusion

MapLibre GL JS supports `fill-extrusion` layers that render polygons as 3D volumes. When building height data is present, each polygon extrudes to its real-world height, creating an intuitive cityscape view.

```javascript
map.addSource('facilities', {
  type: 'vector',
  url: 'http://localhost:8080/data/facilities.json'
});

map.addLayer({
  id: 'buildings-3d',
  type: 'fill-extrusion',
  source: 'facilities',
  'source-layer': 'facilities',
  paint: {
    'fill-extrusion-color': [
      'match', ['get', 'facility_type'],
      'Chemical Manufacturing', '#ff6600',
      'Water Treatment',       '#3399ff',
      'Power Generation',      '#ffcc00',
      'Data Centre',           '#9966ff',
      'Healthcare',            '#33cc33',
      '#888888'
    ],
    'fill-extrusion-height': [
      'case',
      ['has', 'height'], ['get', 'height'],
      12  // default 12 m when height is unknown
    ],
    'fill-extrusion-base': 0,
    'fill-extrusion-opacity': 0.7
  }
});
```

### Criticality-Based Styling

In addition to colour-coding by sector, operators may want to highlight high-criticality facilities with a distinct outline or glow effect.

```javascript
map.addLayer({
  id: 'critical-facilities-outline',
  type: 'line',
  source: 'facilities',
  'source-layer': 'facilities',
  filter: ['==', ['get', 'criticality'], 'critical'],
  paint: {
    'line-color': '#ff0000',
    'line-width': 3,
    'line-dasharray': [2, 1]
  }
});
```

---

## Indoor Mapping

For high-security or high-value facilities, the tileserver can host floor-plan overlays that allow operators to navigate individual rooms and zones within a building.

### Approach

1. **Author floor plans as GeoJSON polygons** -- each room or zone is a Polygon Feature with a `level` property indicating the floor number. See [GeoJSON Authoring](07a-GEOJSON-AUTHORING.md) for geometry conventions.
2. **Convert to tiles** -- run tippecanoe with a single layer per building, or combine all buildings into one layer filtered by `facility_id`.
3. **Filter by level** -- in MapLibre GL JS, apply a filter expression to show only the selected floor.

```javascript
// Level selector
const floorSelector = document.getElementById('floor-select');
floorSelector.addEventListener('change', (e) => {
  const selectedFloor = parseInt(e.target.value, 10);
  map.setFilter('indoor-rooms', ['==', ['get', 'level'], selectedFloor]);
});
```

### Integration with Building Management Systems

Indoor map zones can carry properties that correspond to BACnet object identifiers or Modbus register addresses. This enables click-to-inspect workflows where selecting a room on the map opens a panel showing live temperature, humidity, or access-control status.

| Protocol | Use | Integration Point |
|----------|-----|-------------------|
| BACnet | HVAC, lighting, fire | Zone properties include `bacnet_device_id` and `bacnet_object_id` |
| Modbus | Industrial equipment, PLCs | Zone properties include `modbus_unit_id` and `modbus_register` |
| OPC UA | SCADA and DCS | Zone properties include `opcua_node_id` |

---

## Security Perimeter Visualization

Physical security data layers complement the building footprints by showing fence lines, camera fields of view, and access points.

### Feature Types

| Feature | Geometry | Key Properties |
|---------|----------|----------------|
| Fence line | LineString | `type`, `material`, `height_m`, `electrified` |
| Camera | Point | `camera_id`, `model`, `coverage_angle_deg`, `coverage_radius_m`, `status` |
| Access point | Point | `gate_id`, `type` (vehicle, pedestrian, loading), `status` (open, secured, alarm) |
| Patrol route | LineString | `route_id`, `shift`, `frequency_min` |

### Camera Coverage Arc

To render camera fields of view, generate a sector polygon from the camera point, bearing, and coverage angle using Turf.js.

```javascript
import * as turf from '@turf/turf';

function cameraCoverageArc(camera, radiusKm, bearing, angle, steps) {
  const center = turf.point(camera.coordinates);
  const startBearing = bearing - angle / 2;
  const endBearing = bearing + angle / 2;

  const arcPoints = [];
  arcPoints.push(camera.coordinates);
  for (let i = 0; i <= steps; i++) {
    const b = startBearing + (endBearing - startBearing) * (i / steps);
    const dest = turf.destination(center, radiusKm, b);
    arcPoints.push(dest.geometry.coordinates);
  }
  arcPoints.push(camera.coordinates);

  return turf.polygon([arcPoints]);
}
```

### Access Point Status Colours

```javascript
map.addLayer({
  id: 'access-points',
  type: 'circle',
  source: 'security-perimeter',
  'source-layer': 'access_points',
  paint: {
    'circle-radius': 8,
    'circle-color': [
      'match', ['get', 'status'],
      'secured', '#33cc33',
      'open',    '#ffcc00',
      'alarm',   '#ff0000',
      '#888888'
    ],
    'circle-stroke-width': 2,
    'circle-stroke-color': '#ffffff'
  }
});
```

---

## Automation and Refresh Cadence

Building footprints change infrequently. The recommended refresh schedule is:

| Layer | Refresh | Rationale |
|-------|---------|-----------|
| Microsoft / Overture footprints | Quarterly | New releases roughly every 3 months |
| Facility metadata (proprietary) | On change | Event-driven: new facility, audit completed, decommission |
| Security perimeter | On change | Camera relocations, gate additions |
| Indoor floor plans | On renovation | Structural changes only |

See [Updates & Scheduling](04e-MAINTENANCE.md) for cron configuration and the `tileserver-reload.sh` helper script.

---

## Correlating Buildings with Other Layers

Building footprint layers gain analytical value when spatially correlated with other OXOT layers.

| Correlation | Method | Insight |
|-------------|--------|---------|
| Facilities + Electric grid ([EIA](02c2-EIA.md)) | Buffer around substation, intersect with facilities | Which facilities lose power if substation X fails? |
| Facilities + Census demographics ([US Census](02b1-CENSUS-US.md)) | Point-in-polygon join | Workforce demographics around each facility |
| Facilities + Flood zones ([Natural Hazards](13d1-NATURAL-HAZARDS.md)) | Polygon intersection | Facilities in FEMA 100-year flood zones |
| Facilities + Cyber attack origins ([Cyber Mapping](13-USE-CASES.md)) | Proximity analysis | Attack sources near critical facilities |

---

## References

Copernicus. (2026). *Sentinel-2 data access*. European Space Agency. https://scihub.copernicus.eu/

Google Research. (2023). *Open Buildings: A dataset of building footprints to support social good applications*. https://sites.research.google/open-buildings/

Microsoft. (2025). *Global ML building footprints*. GitHub. https://github.com/microsoft/GlobalMLBuildingFootprints

OpenStreetMap contributors. (2026). *Geofabrik download server*. https://download.geofabrik.de/

Overture Maps Foundation. (2026). *Overture Maps: Open map data*. https://overturemaps.org/

Sirko, W., Kashubin, S., Ritter, M., Annkah, A., Bouber, Y., Choe, Y., Desai, N., Deseada, A., Faber, R., Genzel, D., Giber, L., Gober, S., Hannan, T., Jovicich, S., Ju, E., Koch, D., Kopp, M., Krause, J., Labzunov, V., ... Bauer, A. (2023). Continental-scale building detection from high resolution satellite imagery. *arXiv preprint arXiv:2107.12283*. https://arxiv.org/abs/2107.12283

Turf.js. (2026). *Turf: Advanced geospatial analysis for browsers and Node.js*. https://turfjs.org/

---

*[Home](INDEX.md) | [Use Cases](13-USE-CASES.md) | [Customer Layers](07b-CUSTOMER-LAYERS.md) | [Equipment Layers](07c-EQUIPMENT-LAYERS.md) | [Socioeconomic Analysis](13c-SOCIOECONOMIC-ANALYSIS.md)*
