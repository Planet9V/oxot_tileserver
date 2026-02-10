# OXOT Cyber Digital Twin Integration

> **Last Updated**: 2026-02-11 01:00 UTC

[Home](INDEX.md) > [Application Integration](06-INTEGRATION.md) > OXOT Cyber DT Integration

---

## Overview

The OXOT Cyber Digital Twin application is a React 18 + Vite front end served by Express on port 5000. It includes a full equipment management system, risk scoring, AI agents, and a Knowledge Graph backed by Neon PostgreSQL and Neo4j. The application already provisions a tileserver-gl service in its Docker Compose stack. This page documents how to connect the Cyber DT to the standalone OXOT Tileserver for enhanced or dedicated tile serving.

---

## Existing Architecture

The Cyber DT's `docker-compose.yml` defines five services:

| Service | Port | Purpose |
|---------|------|---------|
| `app` | 5000 | Express + Vite + React front end and API |
| `db` | 5432 | PostgreSQL with pgvector extension |
| `neo4j` | 7474 / 7687 | Knowledge Graph database |
| `redis` | 6379 | Caching layer |
| `tileserver` | 8080 | tileserver-gl for map visualization |

The standalone OXOT Tileserver documented in this wiki can either replace the built-in tileserver service or run alongside it as a secondary tile source with additional data layers.

---

## Configuration

### Option A: Standalone Tileserver (Separate Network)

When the standalone tileserver runs outside the DT's Docker network, configure the front end to connect via localhost or an external hostname.

Add to the Cyber DT's `.env` file:

```bash
TILESERVER_URL=http://localhost:8080
```

In the React client code, reference this URL:

```javascript
const TILESERVER_URL = import.meta.env.VITE_TILESERVER_URL || 'http://localhost:8080';

const map = new maplibregl.Map({
  container: 'map',
  style: `${TILESERVER_URL}/styles/infrastructure/style.json`,
  center: [-98.5, 39.8],
  zoom: 4
});
```

### Option B: Same Docker Compose Network

When running the standalone tileserver on the same Docker network as the Cyber DT, use the Docker service hostname:

```bash
TILESERVER_URL=http://tileserver:8080
```

This is the internal hostname that Docker DNS resolves within the compose network. The front end (running in the user's browser) still needs the external URL for client-side requests, so expose the tileserver port in `docker-compose.yml`:

```yaml
services:
  tileserver:
    image: maptiler/tileserver-gl:latest
    ports:
      - "8080:8080"
    volumes:
      - ./data/tiles:/data
      - ./config:/config
```

Configure the client-side URL as `http://localhost:8080` and the server-side (Express proxy) URL as `http://tileserver:8080`.

### Option C: Replace the Built-In Tileserver

To replace the DT's built-in tileserver with the standalone version:

1. Remove or comment out the `tileserver` service from the DT's `docker-compose.yml`.
2. Start the standalone tileserver separately.
3. Update `TILESERVER_URL` in the DT's `.env` to point to the standalone instance.

---

## Using Infrastructure Layers in the DT Map View

The DT's map component can load infrastructure layers from the tileserver alongside its own equipment and facility data.

### Adding the Vector Source

```javascript
map.on('load', () => {
  // Add OXOT infrastructure source from the standalone tileserver
  map.addSource('oxot-infra', {
    type: 'vector',
    url: `${TILESERVER_URL}/data/osm-infrastructure.json`
  });

  // Add power lines layer
  map.addLayer({
    id: 'dt-power-lines',
    type: 'line',
    source: 'oxot-infra',
    'source-layer': 'power_lines',
    minzoom: 4,
    paint: {
      'line-color': '#ff4444',
      'line-width': ['interpolate', ['linear'], ['zoom'], 4, 0.5, 12, 3],
      'line-opacity': 0.6
    }
  });

  // Add substations layer
  map.addLayer({
    id: 'dt-substations',
    type: 'circle',
    source: 'oxot-infra',
    'source-layer': 'substations',
    minzoom: 8,
    paint: {
      'circle-color': '#ffcc00',
      'circle-radius': ['interpolate', ['linear'], ['zoom'], 8, 3, 14, 10],
      'circle-stroke-color': '#ffffff',
      'circle-stroke-width': 1
    }
  });
});
```

---

## Correlating Tile Features with Equipment Data

The Cyber DT manages equipment and templates in PostgreSQL. Tile features can be correlated with DT equipment records using geographic proximity or shared identifiers.

### By Geographic Proximity

When a user clicks a tile feature, query nearby DT equipment:

```javascript
map.on('click', 'dt-substations', async (e) => {
  const coords = e.lngLat;

  // Query DT API for equipment near these coordinates
  const response = await fetch(
    `/api/equipment/nearby?lat=${coords.lat}&lng=${coords.lng}&radius=1000`
  );
  const equipment = await response.json();

  // Show correlation in popup
  const tileProps = e.features[0].properties;
  new maplibregl.Popup()
    .setLngLat(coords)
    .setHTML(`
      <h3>${tileProps.name || 'Infrastructure Feature'}</h3>
      <p><strong>Source:</strong> OSM Infrastructure Tiles</p>
      <hr>
      <p><strong>Nearby DT Equipment:</strong></p>
      <ul>
        ${equipment.map(eq => `<li>${eq.name} (${eq.template_name})</li>`).join('')}
      </ul>
    `)
    .addTo(map);
});
```

### By Shared Identifier

If DT equipment records include an `osm_id` or facility identifier that matches tile feature properties, filter directly:

```javascript
// Highlight the tile feature matching a selected DT equipment record
function highlightInfraFeature(osmId) {
  map.setFilter('dt-substations-highlight', ['==', ['get', 'osm_id'], osmId]);
}
```

---

## Sector-Based Layer Filtering

The Cyber DT organizes infrastructure by CISA sector (16 sectors). Tile layers can be toggled based on the active sector selection.

### Sector-to-Layer Mapping

| CISA Sector | Tile Layers |
|-------------|-------------|
| Energy | `power_lines`, `substations`, `generators`, `pipelines` |
| Water and Wastewater | `water_treatment`, `pipelines` |
| Communications | `telecom_masts` |
| Transportation | (future: roads, rail, ports) |
| Dams | (future: dam points from NID) |
| Chemical | `pipelines` |
| All others | No tile layers (DT equipment only) |

### Implementation

```javascript
const SECTOR_LAYERS = {
  'Energy': ['power-lines', 'substations', 'generators', 'pipelines'],
  'Water and Wastewater Systems': ['water-treatment', 'pipelines'],
  'Communications': ['telecom-masts'],
};

function showSectorLayers(sectorName) {
  // Hide all infrastructure layers
  const allLayers = ['power-lines', 'substations', 'generators',
                     'pipelines', 'water-treatment', 'telecom-masts'];
  allLayers.forEach(id => {
    if (map.getLayer('dt-' + id)) {
      map.setLayoutProperty('dt-' + id, 'visibility', 'none');
    }
  });

  // Show layers for the selected sector
  const layers = SECTOR_LAYERS[sectorName] || [];
  layers.forEach(id => {
    if (map.getLayer('dt-' + id)) {
      map.setLayoutProperty('dt-' + id, 'visibility', 'visible');
    }
  });
}
```

---

## Express Proxy (Optional)

If CORS restrictions or network topology prevent direct browser-to-tileserver connections, proxy tile requests through the DT's Express server:

```javascript
// server/routes.ts
import { createProxyMiddleware } from 'http-proxy-middleware';

app.use('/tiles', createProxyMiddleware({
  target: process.env.TILESERVER_URL || 'http://tileserver:8080',
  changeOrigin: true,
  pathRewrite: { '^/tiles': '' }
}));
```

Then configure the client to use `/tiles` as the base URL:

```javascript
const TILESERVER_URL = '/tiles';
```

---

## Related Pages

- [Application Integration](06-INTEGRATION.md) -- parent page
- [MapLibre GL JS](06a-MAPLIBRE.md) -- client library used by the DT
- [Style API](05d-STYLES.md) -- infrastructure style definition
- [REST API Endpoints](05a-REST-ENDPOINTS.md) -- tileserver API consumed by the DT
- [Custom Application Guide](06e-CUSTOM-APPS.md) -- React component patterns

---

*[Home](INDEX.md) | [Integration](06-INTEGRATION.md) | [MapLibre](06a-MAPLIBRE.md) | [Custom Apps](06e-CUSTOM-APPS.md)*
