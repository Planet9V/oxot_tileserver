# Custom Application Guide

> **Last Updated**: 2026-02-11 01:00 UTC

[Home](INDEX.md) > [Application Integration](06-INTEGRATION.md) > Custom Application Guide

---

## Overview

The OXOT Tileserver's REST API is consumed over standard HTTP, making it accessible from any programming language, framework, or deployment context. This page covers integration patterns beyond the three primary JavaScript map libraries: server-side tile fetching, iframe embedding, React component wrappers, mobile applications, and static map generation.

---

## REST API as Universal Interface

Any HTTP client can fetch tiles, metadata, and styles from the tileserver. The API requires no authentication, no SDK, and no special headers.

### Node.js (Server-Side)

```javascript
import fetch from 'node-fetch';

// Fetch TileJSON metadata
const metadata = await fetch('http://localhost:8080/data/osm-infrastructure.json');
const tileJson = await metadata.json();
console.log('Layers:', tileJson.vector_layers.map(l => l.id));

// Fetch a vector tile as a buffer
const tileResponse = await fetch('http://localhost:8080/data/osm-infrastructure/6/32/21.pbf');
const tileBuffer = await tileResponse.buffer();
console.log('Tile size:', tileBuffer.length, 'bytes');
```

### Python

```python
import requests

# Fetch TileJSON
response = requests.get('http://localhost:8080/data/osm-infrastructure.json')
tilejson = response.json()

for layer in tilejson['vector_layers']:
    print(f"Layer: {layer['id']} (zoom {layer['minzoom']}-{layer['maxzoom']})")

# Fetch a vector tile
tile = requests.get('http://localhost:8080/data/osm-infrastructure/6/32/21.pbf')
print(f"Tile size: {len(tile.content)} bytes")

# Save a raster tile as PNG
raster = requests.get('http://localhost:8080/styles/infrastructure/6/32/21.png')
with open('tile.png', 'wb') as f:
    f.write(raster.content)
```

### curl (Shell Scripts)

```bash
# List all tilesets
curl -s http://localhost:8080/index.json | jq '.tilesets[].name'

# Download a raster tile
curl -s -o tile.png http://localhost:8080/styles/infrastructure/8/128/85.png

# Batch-download a tile pyramid (zoom 4-6, for a bounding box)
for z in 4 5 6; do
  for x in $(seq 0 $((2**z - 1))); do
    for y in $(seq 0 $((2**z - 1))); do
      curl -sf -o "tiles/${z}_${x}_${y}.pbf" \
        "http://localhost:8080/data/osm-infrastructure/${z}/${x}/${y}.pbf"
    done
  done
done
```

---

## Embedding Maps in Iframes

For simple integration into existing web applications or CMS pages, embed the tileserver's built-in viewer in an iframe:

```html
<iframe
  src="http://localhost:8080"
  width="100%"
  height="600"
  frameborder="0"
  style="border: 1px solid #333; border-radius: 4px;"
  title="OXOT Infrastructure Map"
></iframe>
```

Tileserver-gl ships with a built-in web viewer at the root URL. The viewer supports zoom, pan, and tile inspection. For production embedding, build a dedicated MapLibre GL JS page for more control.

---

## React Components Wrapping MapLibre

Wrap MapLibre GL JS in a React component for use in React-based applications:

```jsx
import { useRef, useEffect } from 'react';
import maplibregl from 'maplibre-gl';
import 'maplibre-gl/dist/maplibre-gl.css';

export default function InfrastructureMap({
  center = [-98.5, 39.8],
  zoom = 4,
  tileserverUrl = 'http://localhost:8080'
}) {
  const mapContainer = useRef(null);
  const mapRef = useRef(null);

  useEffect(() => {
    if (mapRef.current) return;

    mapRef.current = new maplibregl.Map({
      container: mapContainer.current,
      style: `${tileserverUrl}/styles/infrastructure/style.json`,
      center,
      zoom
    });

    mapRef.current.addControl(new maplibregl.NavigationControl());

    return () => {
      mapRef.current.remove();
      mapRef.current = null;
    };
  }, [center, zoom, tileserverUrl]);

  return (
    <div
      ref={mapContainer}
      style={{ width: '100%', height: '100%', minHeight: '400px' }}
    />
  );
}
```

Usage:

```jsx
<InfrastructureMap
  center={[-122.4, 37.8]}
  zoom={10}
  tileserverUrl="http://localhost:8080"
/>
```

For production React applications, consider `react-map-gl` (compatible with MapLibre) or `@vis.gl/react-maplibre` for declarative layer management.

---

## Mobile: React Native

Use `@maplibre/maplibre-react-native` to render tileserver maps in React Native applications:

```bash
npm install @maplibre/maplibre-react-native
```

```jsx
import MapLibreGL from '@maplibre/maplibre-react-native';

export default function MobileMap() {
  return (
    <MapLibreGL.MapView
      style={{ flex: 1 }}
      styleURL="http://YOUR_SERVER_IP:8080/styles/infrastructure/style.json"
    >
      <MapLibreGL.Camera
        defaultSettings={{ centerCoordinate: [-98.5, 39.8], zoomLevel: 4 }}
      />
    </MapLibreGL.MapView>
  );
}
```

Replace `YOUR_SERVER_IP` with the actual IP address or hostname reachable from the mobile device. `localhost` will not work on physical devices.

---

## Static Map Generation

Use the style-rendered raster tile endpoint to generate static map images for reports, emails, or PDFs without a browser:

```bash
# Single tile at zoom 6
curl -s -o map_z6.png http://localhost:8080/styles/infrastructure/6/32/21.png

# Higher resolution (retina)
curl -s -o map_z6_2x.png http://localhost:8080/styles/infrastructure/6/32/21@2x.png
```

For composite static maps covering a specific bounding box, fetch multiple tiles and stitch them together:

```python
from PIL import Image
import requests
from io import BytesIO

def fetch_tile(style, z, x, y, base_url='http://localhost:8080'):
    url = f'{base_url}/styles/{style}/{z}/{x}/{y}.png'
    resp = requests.get(url)
    return Image.open(BytesIO(resp.content))

# Stitch a 3x3 grid at zoom 6, starting at tile (31, 20)
grid = Image.new('RGB', (256 * 3, 256 * 3))
for dx in range(3):
    for dy in range(3):
        tile = fetch_tile('infrastructure', 6, 31 + dx, 20 + dy)
        grid.paste(tile, (dx * 256, dy * 256))

grid.save('composite_map.png')
```

---

## WebSocket and Real-Time Updates

The tileserver itself does not support WebSocket connections. For real-time updates (e.g., live equipment status overlay):

1. Serve tile data from the tileserver (static infrastructure).
2. Overlay dynamic data from a separate WebSocket or SSE endpoint using MapLibre's `GeoJSONSource` with `setData()`.

```javascript
// Static infrastructure from tileserver
map.addSource('infra', {
  type: 'vector',
  url: 'http://localhost:8080/data/osm-infrastructure.json'
});

// Dynamic overlay from your application server
map.addSource('live-status', {
  type: 'geojson',
  data: { type: 'FeatureCollection', features: [] }
});

// Update live data via WebSocket
const ws = new WebSocket('ws://localhost:5000/api/equipment/live');
ws.onmessage = (event) => {
  const geojson = JSON.parse(event.data);
  map.getSource('live-status').setData(geojson);
};
```

---

## Related Pages

- [Application Integration](06-INTEGRATION.md) -- parent page
- [MapLibre GL JS](06a-MAPLIBRE.md) -- full MapLibre integration guide
- [REST API Endpoints](05a-REST-ENDPOINTS.md) -- all HTTP endpoints
- [OXOT Cyber DT Integration](06d-OXOT-CYBERDT.md) -- DT-specific integration

---

*[Home](INDEX.md) | [Integration](06-INTEGRATION.md) | [MapLibre](06a-MAPLIBRE.md) | [OXOT DT](06d-OXOT-CYBERDT.md)*
