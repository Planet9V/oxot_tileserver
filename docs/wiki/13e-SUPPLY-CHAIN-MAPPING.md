# Supply Chain Visualization

> **Last Updated**: 2026-02-11 02:00 UTC

[Home](INDEX.md) > [Use Cases](13-USE-CASES.md) > Supply Chain Visualization

---

## Overview

Supply chain mapping translates the abstract concept of a multi-hop supply chain into a geographic reality. Every product that reaches a consumer, a factory floor, or a military depot follows a spatial path -- raw materials extracted at one set of coordinates, processed at another, assembled at a third, shipped through maritime chokepoints, moved over rail and road corridors, and delivered to a final destination. When that spatial path is rendered on a map alongside critical infrastructure layers, supply chain risk becomes visible in a way that spreadsheets and ERP dashboards cannot replicate.

The OXOT Tileserver provides the geographic foundation for this visualization. By ingesting supply chain graph data, trade flow statistics, vessel tracking feeds, and logistics network geometries, the tileserver produces vector tile layers that overlay multi-hop supply chains on top of the existing infrastructure basemap. The result is a single map view that answers questions such as: "Which of our tier-2 suppliers are located within 50 km of a flood zone?", "How many of our inbound shipping routes transit the Strait of Malacca?", and "What happens to downstream production if this single refinery goes offline?"

This page covers the full supply chain visualization pipeline -- data sources, data model, GeoJSON transformation, tile generation, client-side rendering, chokepoint analysis, and supplier concentration risk scoring.

---

## Supply Chain Hops

A complete supply chain from extraction to consumption follows a sequence of geographic hops. Each hop represents a physical location where materials change form, ownership, or transport mode.

```
Raw Materials    Processing     Inputs /        Manufacturing    Assembly
(Mine, Farm,     (Refinery,     Components      (Factory,        (Final
 Well, Forest)    Smelter,       (Parts,          Fabrication      Product
                  Mill)          Chemicals)       Plant)           Plant)
     |               |               |                |               |
     +---> ship ---->+---> ship ---->+---> truck ---->+---> rail ---->+
                                                                      |
     +----------------------------------------------------------------+
     |
     v
Shipping /         Final Destination
Distribution       (Retail Store,
(Port, Warehouse,   Commercial Site,
 Distribution       Industrial
 Center)            Consumer)
     |               |
     +---> truck ---->+
```

Each node in this chain has a geographic coordinate. Each edge between nodes has a transport mode, a route geometry, a lead time, and a set of risk factors. The goal of supply chain visualization is to render all of these on the map simultaneously.

---

## Data Sources

| Source | URL | Coverage | Data | Format | Access |
|--------|-----|----------|------|--------|--------|
| Open Supply Chains (Sourcemap) | https://github.com/supplychainstudies/OpenSupplyChains | Global | Supply chain graphs, commodity origins, processing hops | JSON / GeoJSON | Free (open source) |
| UN Comtrade | https://comtradeplus.un.org/ | Global | Import/export flows between countries, HS commodity codes, bilateral trade values | JSON API | Free (registration required) |
| World Bank WITS | https://wits.worldbank.org/ | Global | Bilateral trade data, tariff schedules, trade indicators | CSV / API | Free |
| MarineTraffic AIS | https://www.marinetraffic.com/ | Global oceans | 550K+ vessels, real-time positions, routes, port calls, vessel details | JSON API | Free tier (limited) / Commercial |
| AISHub | https://www.aishub.net/ | Global | Free community AIS data exchange network | JSON / XML | Free (contribute a receiver) |
| Marine Cadastre (US) | https://hub.marinecadastre.gov/pages/vesseltraffic | US coastal waters | Historical vessel traffic density grids | GeoTIFF, CSV | Free (public domain) |
| OpenRailwayMap | https://www.openrailwaymap.org/ | Global | Railway lines, stations, freight facilities, gauges | OSM tags (PBF) | Free (ODbL) |
| OpenStreetMap Roads | https://download.geofabrik.de/ | Global | Highway network, road classifications | PBF | Free (ODbL) |
| World Port Index (NGA) | https://msi.nga.mil/Publications/WPI | Global | 3,700+ ports with depth, berths, facilities, anchorage, country | CSV | Free (public domain) |
| FreightWaves SONAR | https://www.freightwaves.com/sonar | US / Global | Freight market rates, tender volumes, capacity indices | API | Commercial |

---

## Data Model

The supply chain data model consists of two entity types: **nodes** (locations where materials are sourced, processed, manufactured, stored, or consumed) and **edges** (transport links between nodes).

### Node Schema

```json
{
  "id": "mine-001",
  "type": "raw_material",
  "name": "Lithium Mine (Salar de Atacama)",
  "coordinates": [-68.85, -23.45],
  "country": "CL",
  "country_name": "Chile",
  "product": "Lithium carbonate",
  "supplier": "SQM S.A.",
  "tier": 3,
  "annual_capacity_mt": 70000,
  "certifications": ["ISO 14001"],
  "risk_score": 42
}
```

**Node types** follow the hop sequence: `raw_material`, `processing`, `component`, `manufacturing`, `assembly`, `distribution`, `retail`.

### Edge Schema

```json
{
  "from": "mine-001",
  "to": "refinery-001",
  "transport_mode": "ship",
  "route_description": "Port of Antofagasta --> Port of Busan",
  "route_geometry": {
    "type": "LineString",
    "coordinates": [[-70.40, -23.65], [-109.0, -10.0], [-160.0, 5.0], [170.0, 20.0], [129.05, 35.08]]
  },
  "lead_time_days": 28,
  "distance_km": 18200,
  "cost_per_unit_usd": 0.12,
  "chokepoints_crossed": ["Panama Canal"],
  "risk_factors": ["maritime chokepoint", "weather disruption", "port congestion"]
}
```

### Full Supply Chain Example

The following represents a simplified EV battery supply chain spanning four countries:

```json
{
  "supply_chain_id": "ev-battery-2026",
  "product": "EV Battery Pack (75 kWh NMC)",
  "nodes": [
    {
      "id": "mine-001",
      "type": "raw_material",
      "name": "Lithium Mine (Atacama)",
      "coordinates": [-68.85, -23.45],
      "country": "CL",
      "product": "Lithium carbonate",
      "supplier": "SQM S.A.",
      "tier": 3
    },
    {
      "id": "mine-002",
      "type": "raw_material",
      "name": "Cobalt Mine (Kolwezi)",
      "coordinates": [25.47, -10.98],
      "country": "CD",
      "product": "Cobalt ore",
      "supplier": "Glencore",
      "tier": 3
    },
    {
      "id": "refinery-001",
      "type": "processing",
      "name": "Cathode Material Refinery",
      "coordinates": [126.98, 37.57],
      "country": "KR",
      "product": "NMC cathode material",
      "supplier": "LG Chem",
      "tier": 2
    },
    {
      "id": "factory-001",
      "type": "manufacturing",
      "name": "Battery Cell Factory",
      "coordinates": [126.73, 37.41],
      "country": "KR",
      "product": "Battery cells (pouch)",
      "supplier": "LG Energy Solution",
      "tier": 1
    },
    {
      "id": "assembly-001",
      "type": "assembly",
      "name": "EV Battery Pack Assembly",
      "coordinates": [-83.58, 35.95],
      "country": "US",
      "product": "75 kWh battery pack",
      "supplier": "Gigafactory US",
      "tier": 0
    }
  ],
  "edges": [
    {
      "from": "mine-001",
      "to": "refinery-001",
      "transport_mode": "ship",
      "route_description": "Antofagasta --> Busan",
      "lead_time_days": 28,
      "chokepoints_crossed": ["Panama Canal"]
    },
    {
      "from": "mine-002",
      "to": "refinery-001",
      "transport_mode": "ship",
      "route_description": "Durban --> Busan",
      "lead_time_days": 32,
      "chokepoints_crossed": ["Strait of Malacca"]
    },
    {
      "from": "refinery-001",
      "to": "factory-001",
      "transport_mode": "truck",
      "route_description": "Incheon --> Ochang",
      "lead_time_days": 1,
      "chokepoints_crossed": []
    },
    {
      "from": "factory-001",
      "to": "assembly-001",
      "transport_mode": "ship",
      "route_description": "Busan --> Charleston --> Knoxville",
      "lead_time_days": 21,
      "chokepoints_crossed": ["Panama Canal"]
    }
  ]
}
```

---

## GeoJSON Transformation

### Converting Nodes to GeoJSON Points

```python
import json

def nodes_to_geojson(supply_chain):
    """Convert supply chain nodes to a GeoJSON FeatureCollection."""
    features = []
    for node in supply_chain['nodes']:
        feature = {
            "type": "Feature",
            "geometry": {
                "type": "Point",
                "coordinates": node['coordinates']
            },
            "properties": {
                "id": node['id'],
                "type": node['type'],
                "name": node['name'],
                "country": node['country'],
                "product": node['product'],
                "supplier": node['supplier'],
                "tier": node.get('tier', -1),
                "supply_chain_id": supply_chain['supply_chain_id']
            }
        }
        features.append(feature)

    return {
        "type": "FeatureCollection",
        "features": features
    }
```

### Converting Edges to GeoJSON Lines (Great Circle Arcs)

For edges that lack explicit route geometry, generate great circle arcs between the source and destination coordinates:

```python
from geographiclib.geodesic import Geodesic

def edge_to_arc(from_coords, to_coords, num_points=64):
    """Generate a great circle arc as a list of [lon, lat] pairs."""
    geod = Geodesic.WGS84
    line = geod.InverseLine(from_coords[1], from_coords[0],
                            to_coords[1], to_coords[0])
    coordinates = []
    for i in range(num_points + 1):
        s = line.s13 * i / num_points
        point = line.Position(s, Geodesic.STANDARD | Geodesic.LONG_UNROLL)
        coordinates.append([point['lon2'], point['lat2']])
    return coordinates

def edges_to_geojson(supply_chain, node_lookup):
    """Convert supply chain edges to a GeoJSON FeatureCollection of LineStrings."""
    features = []
    for edge in supply_chain['edges']:
        from_node = node_lookup[edge['from']]
        to_node = node_lookup[edge['to']]

        if 'route_geometry' in edge:
            geometry = edge['route_geometry']
        else:
            arc_coords = edge_to_arc(from_node['coordinates'],
                                     to_node['coordinates'])
            geometry = {"type": "LineString", "coordinates": arc_coords}

        feature = {
            "type": "Feature",
            "geometry": geometry,
            "properties": {
                "from_id": edge['from'],
                "to_id": edge['to'],
                "from_name": from_node['name'],
                "to_name": to_node['name'],
                "transport_mode": edge['transport_mode'],
                "lead_time_days": edge.get('lead_time_days', 0),
                "chokepoints": ",".join(edge.get('chokepoints_crossed', [])),
                "risk_factors": ",".join(edge.get('risk_factors', []))
            }
        }
        features.append(feature)

    return {
        "type": "FeatureCollection",
        "features": features
    }
```

---

## Tile Generation

Run tippecanoe separately for nodes and edges, then composite them into a single MBTiles file:

```bash
# Generate node tiles
tippecanoe -o data/tiles/supply-nodes.mbtiles \
  -l supply_nodes \
  -z12 -Z0 \
  --drop-densest-as-needed \
  data/geojson/supply-chain-nodes.geojson

# Generate edge tiles
tippecanoe -o data/tiles/supply-edges.mbtiles \
  -l supply_edges \
  -z12 -Z0 \
  --no-simplification-of-shared-nodes \
  data/geojson/supply-chain-edges.geojson

# Merge into a single tileset
tile-join -o data/tiles/supply-chain.mbtiles \
  data/tiles/supply-nodes.mbtiles \
  data/tiles/supply-edges.mbtiles
```

Add to `tileserver-config.json`:

```json
{
  "data": {
    "supply-chain": {
      "mbtiles": "data/tiles/supply-chain.mbtiles"
    }
  }
}
```

---

## Client-Side Rendering

### MapLibre GL JS: Node Layer by Supply Chain Stage

```javascript
map.addSource('supply-chain', {
  type: 'vector',
  url: 'http://localhost:8080/data/supply-chain.json'
});

// Nodes: colored by stage in the supply chain
map.addLayer({
  id: 'supply-chain-nodes',
  type: 'circle',
  source: 'supply-chain',
  'source-layer': 'supply_nodes',
  paint: {
    'circle-color': [
      'match', ['get', 'type'],
      'raw_material',   '#8B4513',   // Brown: extraction
      'processing',     '#FF8C00',   // Orange: refinery / smelter
      'component',      '#FFD700',   // Gold: parts / chemicals
      'manufacturing',  '#4169E1',   // Blue: factory
      'assembly',       '#32CD32',   // Green: assembly plant
      'distribution',   '#9370DB',   // Purple: warehouse / port
      'retail',         '#DC143C',   // Red: final destination
      /* fallback */    '#888888'
    ],
    'circle-radius': [
      'interpolate', ['linear'], ['zoom'],
      0, 4,
      6, 8,
      12, 14
    ],
    'circle-stroke-width': 2,
    'circle-stroke-color': '#ffffff'
  }
});
```

### MapLibre GL JS: Edge Layer (Route Lines)

```javascript
map.addLayer({
  id: 'supply-chain-edges',
  type: 'line',
  source: 'supply-chain',
  'source-layer': 'supply_edges',
  paint: {
    'line-color': [
      'match', ['get', 'transport_mode'],
      'ship',   '#1E90FF',
      'rail',   '#FF4500',
      'truck',  '#228B22',
      'air',    '#9932CC',
      /* fallback */ '#888888'
    ],
    'line-width': [
      'interpolate', ['linear'], ['zoom'],
      0, 1,
      6, 2,
      12, 4
    ],
    'line-dasharray': [
      'match', ['get', 'transport_mode'],
      'ship', ['literal', [4, 2]],
      'air',  ['literal', [2, 4]],
      /* solid for land */ ['literal', [1, 0]]
    ]
  }
});
```

### deck.gl: Animated Arc Layer for High-Volume Routes

For richer 3D visualization, use deck.gl's `ArcLayer` on top of the MapLibre base:

```javascript
import { ArcLayer } from '@deck.gl/layers';
import { MapboxOverlay } from '@deck.gl/mapbox';

const STAGE_COLORS = {
  raw_material:  [139, 69, 19],
  processing:    [255, 140, 0],
  component:     [255, 215, 0],
  manufacturing: [65, 105, 225],
  assembly:      [50, 205, 50],
  distribution:  [147, 112, 219],
  retail:        [220, 20, 60]
};

const arcLayer = new ArcLayer({
  id: 'supply-routes-arc',
  data: supplyChain.edges,
  getSourcePosition: d => nodeIndex[d.from].coordinates,
  getTargetPosition: d => nodeIndex[d.to].coordinates,
  getSourceColor: d => STAGE_COLORS[nodeIndex[d.from].type] || [128, 128, 128],
  getTargetColor: d => STAGE_COLORS[nodeIndex[d.to].type] || [128, 128, 128],
  getWidth: d => Math.max(1, d.volume / 1000),
  greatCircle: true,
  widthMinPixels: 1,
  widthMaxPixels: 8
});

const overlay = new MapboxOverlay({ layers: [arcLayer] });
map.addControl(overlay);
```

---

## Chokepoint Analysis

Global shipping routes funnel through a small number of geographic chokepoints. A supply chain that depends on multiple routes transiting the same chokepoint carries concentrated risk.

### Major Maritime Chokepoints

| Chokepoint | Coordinates | Annual Traffic | Risk Profile |
|------------|-------------|----------------|--------------|
| Strait of Malacca | [101.7, 2.5] | ~100,000 transits/year | Piracy, congestion, geopolitical (China/ASEAN) |
| Suez Canal | [32.34, 30.46] | ~20,000 transits/year | Blockage (Ever Given 2021), conflict (Houthi attacks 2024) |
| Panama Canal | [-79.92, 9.08] | ~14,000 transits/year | Drought (2023--2024 restrictions), capacity limits |
| Strait of Hormuz | [56.27, 26.57] | ~21,000 transits/year | Geopolitical (Iran), oil/LNG dependency |
| Bab el-Mandeb | [43.38, 12.58] | ~20,000 transits/year | Conflict (Yemen/Houthi), piracy, rerouting |
| Cape of Good Hope | [18.50, -34.35] | Overflow route | Longer transit time (+7-10 days from Suez), weather |
| Turkish Straits | [29.06, 41.07] | ~42,000 transits/year | Congestion, grain/energy exports (Black Sea) |

### Chokepoint Overlay

Create a GeoJSON layer of chokepoint locations with buffer zones:

```python
import json
from shapely.geometry import Point, mapping
from shapely.ops import transform
import pyproj
from functools import partial

chokepoints = [
    {"name": "Strait of Malacca", "lon": 101.7, "lat": 2.5, "radius_km": 50},
    {"name": "Suez Canal",        "lon": 32.34, "lat": 30.46, "radius_km": 20},
    {"name": "Panama Canal",      "lon": -79.92, "lat": 9.08, "radius_km": 15},
    {"name": "Strait of Hormuz",  "lon": 56.27, "lat": 26.57, "radius_km": 40},
    {"name": "Bab el-Mandeb",     "lon": 43.38, "lat": 12.58, "radius_km": 30},
    {"name": "Cape of Good Hope", "lon": 18.50, "lat": -34.35, "radius_km": 60},
    {"name": "Turkish Straits",   "lon": 29.06, "lat": 41.07, "radius_km": 20},
]

features = []
for cp in chokepoints:
    # Create buffered polygon around chokepoint
    project = partial(pyproj.transform,
                      pyproj.Proj('EPSG:4326'),
                      pyproj.Proj(proj='aeqd', lat_0=cp['lat'], lon_0=cp['lon']))
    unproject = partial(pyproj.transform,
                        pyproj.Proj(proj='aeqd', lat_0=cp['lat'], lon_0=cp['lon']),
                        pyproj.Proj('EPSG:4326'))
    point = transform(project, Point(cp['lon'], cp['lat']))
    buffer = point.buffer(cp['radius_km'] * 1000)
    polygon = transform(unproject, buffer)

    features.append({
        "type": "Feature",
        "geometry": mapping(polygon),
        "properties": {"name": cp['name'], "radius_km": cp['radius_km']}
    })

geojson = {"type": "FeatureCollection", "features": features}
with open("data/geojson/chokepoints.geojson", "w") as f:
    json.dump(geojson, f)
```

### Route-Chokepoint Intersection Scoring

For each supply chain, count how many edges transit each chokepoint and produce a risk score:

```python
def score_chokepoint_risk(supply_chain):
    """Return a risk score based on chokepoint exposure."""
    chokepoint_counts = {}
    for edge in supply_chain['edges']:
        for cp in edge.get('chokepoints_crossed', []):
            chokepoint_counts[cp] = chokepoint_counts.get(cp, 0) + 1

    total_edges = len(supply_chain['edges'])
    if total_edges == 0:
        return 0.0

    unique_chokepoints = len(chokepoint_counts)
    total_crossings = sum(chokepoint_counts.values())

    # Score: weighted combination of unique chokepoints and crossing frequency
    score = min(100, (unique_chokepoints * 15) + (total_crossings / total_edges * 20))
    return round(score, 1)
```

---

## Supplier Concentration Risk

Supplier concentration -- when a large share of a critical input comes from a single country or region -- is one of the most common supply chain vulnerabilities.

### Aggregation by Country

```python
from collections import Counter

def concentration_by_country(supply_chain):
    """Aggregate suppliers by country and flag concentration risk."""
    country_counts = Counter(node['country'] for node in supply_chain['nodes'])
    total = sum(country_counts.values())

    results = []
    for country, count in country_counts.most_common():
        share = count / total * 100
        risk = "HIGH" if share > 60 else "MEDIUM" if share > 30 else "LOW"
        results.append({
            "country": country,
            "supplier_count": count,
            "share_pct": round(share, 1),
            "concentration_risk": risk
        })
    return results
```

### Choropleth Visualization

Generate a country-level choropleth where darker shading indicates higher supplier concentration:

```javascript
// Assume a GeoJSON source of country polygons with a "supplier_share_pct" property
map.addLayer({
  id: 'supplier-concentration',
  type: 'fill',
  source: 'country-boundaries',
  paint: {
    'fill-color': [
      'interpolate', ['linear'], ['get', 'supplier_share_pct'],
      0,  '#f7fbff',
      10, '#c6dbef',
      30, '#6baed6',
      50, '#2171b5',
      70, '#08306b'
    ],
    'fill-opacity': 0.6
  }
});
```

### Alert Thresholds

| Metric | Threshold | Severity | Action |
|--------|-----------|----------|--------|
| Single-country share | > 60% of suppliers | High | Diversify sourcing immediately |
| Single-country share | 30%--60% of suppliers | Medium | Develop alternative suppliers |
| Single-region share | > 80% of suppliers | Critical | Strategic sourcing review |
| Tier-1 single-source | Any critical input from 1 supplier | High | Qualify backup supplier |

---

## UN Comtrade Integration

UN Comtrade provides bilateral trade flow data by HS commodity code between every pair of reporting countries. This data drives country-level trade flow maps.

### Fetching Trade Data

```python
import requests

def fetch_comtrade(reporter="842", partner="410", hs_code="850760",
                   period="2025", flow="M"):
    """Fetch bilateral trade data from UN Comtrade Plus API."""
    url = "https://comtradeapi.un.org/data/v1/get/C/A"
    params = {
        "reporterCode": reporter,   # US = 842
        "partnerCode": partner,     # South Korea = 410
        "cmdCode": hs_code,         # 850760 = lithium-ion batteries
        "period": period,
        "flowCode": flow,           # M = imports
        "maxRecords": 500
    }
    headers = {"Ocp-Apim-Subscription-Key": os.environ["COMTRADE_API_KEY"]}
    resp = requests.get(url, params=params, headers=headers)
    resp.raise_for_status()
    return resp.json()
```

### Trade Flow Arrows

Render country-to-country trade flows as directed arcs on the map, with width proportional to trade value:

```javascript
// trade_flows: [{from: [lon,lat], to: [lon,lat], value_usd: 1234567}, ...]
new ArcLayer({
  id: 'trade-flows',
  data: tradeFlows,
  getSourcePosition: d => d.from,
  getTargetPosition: d => d.to,
  getSourceColor: [255, 140, 0],
  getTargetColor: [65, 105, 225],
  getWidth: d => Math.log10(d.value_usd),
  greatCircle: true
});
```

---

## Child Pages

| Page | Title | Description |
|------|-------|-------------|
| [13e1-SHIPPING-ROUTES.md](13e1-SHIPPING-ROUTES.md) | Shipping & Logistics Visualization | AIS vessel tracking, port mapping, rail and road freight corridors |

---

## References

MarineTraffic. (2026). *Global ship tracking intelligence: AIS marine traffic*. https://www.marinetraffic.com/

National Geospatial-Intelligence Agency. (2026). *World port index (Pub. 150)*. https://msi.nga.mil/Publications/WPI

OpenRailwayMap. (2026). *OpenRailwayMap: An OpenStreetMap-based project for railway infrastructure*. https://www.openrailwaymap.org/

Sourcemap. (2026). *Open Supply Chains: Open-source supply chain data*. https://github.com/supplychainstudies/OpenSupplyChains

United Nations. (2026). *UN Comtrade: International trade statistics database*. https://comtradeplus.un.org/

U.S. Bureau of the Census, Marine Cadastre. (2026). *Vessel traffic data*. https://hub.marinecadastre.gov/pages/vesseltraffic

World Bank. (2026). *World Integrated Trade Solution (WITS)*. https://wits.worldbank.org/

---

*[Home](INDEX.md) | [Use Cases](13-USE-CASES.md) | [Custom Tiles](07-CUSTOM-TILES.md) | [Shipping Routes](13e1-SHIPPING-ROUTES.md)*
