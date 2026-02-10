# MapLibre GL JS Integration

> **Last Updated**: 2026-02-11 01:00 UTC

[Home](INDEX.md) > [Application Integration](06-INTEGRATION.md) > MapLibre GL JS

---

## Overview

MapLibre GL JS is the recommended map client for the OXOT Tileserver. It provides native WebGL-accelerated vector tile rendering, full support for the MapLibre GL Style Specification, and automatic TileJSON discovery. This page covers installation, basic map setup, adding sources and layers, user interaction, and a complete working example.

---

## Installation

### npm

```bash
npm install maplibre-gl
```

```javascript
import maplibregl from 'maplibre-gl';
import 'maplibre-gl/dist/maplibre-gl.css';
```

### CDN

```html
<link rel="stylesheet" href="https://unpkg.com/maplibre-gl@4/dist/maplibre-gl.css" />
<script src="https://unpkg.com/maplibre-gl@4/dist/maplibre-gl.js"></script>
```

---

## Basic Map with Tileserver Style

The simplest integration points the map directly at the tileserver's style URL. MapLibre fetches the style JSON, resolves all sources and layers automatically, and renders the map.

```javascript
const map = new maplibregl.Map({
  container: 'map',
  style: 'http://localhost:8080/styles/infrastructure/style.json',
  center: [-98.5, 39.8],  // Center of the US
  zoom: 4
});
```

This single line of configuration renders the full infrastructure map with all layers, colors, and zoom-dependent styling defined in the `infrastructure.json` style.

---

## Adding Vector Tile Sources Manually

If you need more control, add sources and layers individually instead of using the pre-built style.

```javascript
const map = new maplibregl.Map({
  container: 'map',
  style: {
    version: 8,
    sources: {
      'osm-infra': {
        type: 'vector',
        url: 'http://localhost:8080/data/osm-infrastructure.json'
      },
      'geonames': {
        type: 'vector',
        url: 'http://localhost:8080/data/geonames.json'
      }
    },
    layers: [
      {
        id: 'background',
        type: 'background',
        paint: { 'background-color': '#1a1a2e' }
      }
    ]
  },
  center: [0, 30],
  zoom: 3
});
```

The `url` property pointing to a TileJSON endpoint causes MapLibre to auto-resolve tile URLs, bounds, and zoom ranges.

---

## Adding Layers Programmatically

After the map loads, add layers that reference the vector tile sources:

```javascript
map.on('load', () => {
  // Power lines
  map.addLayer({
    id: 'power-lines',
    type: 'line',
    source: 'osm-infra',
    'source-layer': 'power_lines',
    minzoom: 4,
    paint: {
      'line-color': '#ff4444',
      'line-width': ['interpolate', ['linear'], ['zoom'], 4, 0.5, 8, 1.5, 12, 3],
      'line-opacity': 0.8
    }
  });

  // Substations
  map.addLayer({
    id: 'substations',
    type: 'circle',
    source: 'osm-infra',
    'source-layer': 'substations',
    minzoom: 8,
    paint: {
      'circle-color': '#ffcc00',
      'circle-radius': ['interpolate', ['linear'], ['zoom'], 8, 3, 12, 6, 14, 10],
      'circle-stroke-color': '#ffffff',
      'circle-stroke-width': 1
    }
  });

  // Generators
  map.addLayer({
    id: 'generators',
    type: 'circle',
    source: 'osm-infra',
    'source-layer': 'generators',
    minzoom: 6,
    paint: {
      'circle-color': '#00cc66',
      'circle-radius': ['interpolate', ['linear'], ['zoom'], 6, 2, 10, 5, 14, 8],
      'circle-stroke-color': '#ffffff',
      'circle-stroke-width': 1
    }
  });
});
```

---

## Popups and Click Handlers

Add interactive popups that display feature properties on click:

```javascript
map.on('click', 'substations', (e) => {
  const feature = e.features[0];
  const props = feature.properties;

  new maplibregl.Popup()
    .setLngLat(e.lngLat)
    .setHTML(`
      <h3>${props.name || 'Unnamed Substation'}</h3>
      <p><strong>Operator:</strong> ${props.operator || 'Unknown'}</p>
      <p><strong>Voltage:</strong> ${props.voltage ? (props.voltage / 1000) + ' kV' : 'N/A'}</p>
    `)
    .addTo(map);
});

// Change cursor on hover
map.on('mouseenter', 'substations', () => {
  map.getCanvas().style.cursor = 'pointer';
});
map.on('mouseleave', 'substations', () => {
  map.getCanvas().style.cursor = '';
});
```

---

## Layer Visibility Toggles

Toggle layer visibility from UI controls:

```javascript
function toggleLayer(layerId) {
  const visibility = map.getLayoutProperty(layerId, 'visibility');
  if (visibility === 'visible' || visibility === undefined) {
    map.setLayoutProperty(layerId, 'visibility', 'none');
  } else {
    map.setLayoutProperty(layerId, 'visibility', 'visible');
  }
}

// Usage
document.getElementById('toggle-power').addEventListener('click', () => {
  toggleLayer('power-lines');
});
```

---

## Filter Expressions

Filter features by property values at runtime:

```javascript
// Show only high-voltage lines (>= 230kV)
map.setFilter('power-lines', ['>=', ['get', 'voltage'], 230000]);

// Show only solar generators
map.setFilter('generators', ['==', ['get', 'source'], 'solar']);

// Reset filter to show all
map.setFilter('power-lines', null);
```

---

## Complete Working Example

Save as `index.html` and open in a browser (with tileserver running on port 8080):

```html
<!DOCTYPE html>
<html lang="en">
<head>
  <meta charset="UTF-8" />
  <meta name="viewport" content="width=device-width, initial-scale=1.0" />
  <title>OXOT Infrastructure Map</title>
  <link rel="stylesheet" href="https://unpkg.com/maplibre-gl@4/dist/maplibre-gl.css" />
  <script src="https://unpkg.com/maplibre-gl@4/dist/maplibre-gl.js"></script>
  <style>
    body { margin: 0; padding: 0; }
    #map { position: absolute; top: 0; bottom: 0; width: 100%; }
    #controls {
      position: absolute; top: 10px; left: 10px; z-index: 1;
      background: rgba(0,0,0,0.7); color: #fff;
      padding: 10px; border-radius: 4px; font-family: sans-serif;
    }
    #controls label { display: block; margin: 4px 0; cursor: pointer; }
  </style>
</head>
<body>

<div id="controls">
  <strong>Layers</strong>
  <label><input type="checkbox" checked onchange="toggle('power-lines')"> Power Lines</label>
  <label><input type="checkbox" checked onchange="toggle('pipelines')"> Pipelines</label>
  <label><input type="checkbox" checked onchange="toggle('substations')"> Substations</label>
  <label><input type="checkbox" checked onchange="toggle('generators')"> Generators</label>
  <label><input type="checkbox" checked onchange="toggle('water-treatment')"> Water Treatment</label>
  <label><input type="checkbox" checked onchange="toggle('telecom-masts')"> Telecom Masts</label>
</div>

<div id="map"></div>

<script>
  const TILESERVER = 'http://localhost:8080';

  const map = new maplibregl.Map({
    container: 'map',
    style: TILESERVER + '/styles/infrastructure/style.json',
    center: [-98.5, 39.8],
    zoom: 4
  });

  map.addControl(new maplibregl.NavigationControl());

  // Popup on click for all circle layers
  const circleLayers = ['substations', 'generators', 'water-treatment', 'telecom-masts'];

  circleLayers.forEach(layerId => {
    map.on('click', layerId, (e) => {
      const props = e.features[0].properties;
      const html = Object.entries(props)
        .map(([k, v]) => '<strong>' + k + ':</strong> ' + v)
        .join('<br>');
      new maplibregl.Popup()
        .setLngLat(e.lngLat)
        .setHTML(html)
        .addTo(map);
    });

    map.on('mouseenter', layerId, () => {
      map.getCanvas().style.cursor = 'pointer';
    });
    map.on('mouseleave', layerId, () => {
      map.getCanvas().style.cursor = '';
    });
  });

  function toggle(layerId) {
    const vis = map.getLayoutProperty(layerId, 'visibility');
    map.setLayoutProperty(layerId, 'visibility',
      (vis === 'visible' || vis === undefined) ? 'none' : 'visible'
    );
  }
</script>

</body>
</html>
```

---

## Navigation Controls

MapLibre provides built-in controls:

```javascript
// Zoom and rotation controls
map.addControl(new maplibregl.NavigationControl());

// Scale bar
map.addControl(new maplibregl.ScaleControl({ unit: 'metric' }));

// Fullscreen
map.addControl(new maplibregl.FullscreenControl());

// Geolocate (centers map on user's location)
map.addControl(new maplibregl.GeolocateControl());
```

---

## Performance Tips

1. **Use the style URL** instead of manually adding layers -- tileserver-gl rewrites source URLs for optimal resolution.
2. **Set `minzoom` on layers** to avoid rendering features that are too small to see at low zoom levels.
3. **Use `maxzoom` on sources** to enable overzooming instead of requesting non-existent tile zoom levels.
4. **Limit popups** to a single instance to avoid DOM buildup.

---

## References

MapLibre. (2025). *MapLibre GL JS documentation*. https://maplibre.org/maplibre-gl-js/docs/

---

## Related Pages

- [Application Integration](06-INTEGRATION.md) -- parent page
- [Style API](05d-STYLES.md) -- the infrastructure style consumed by MapLibre
- [TileJSON Metadata](05b-TILEJSON.md) -- auto-discovery used by MapLibre sources
- [OXOT Cyber DT Integration](06d-OXOT-CYBERDT.md) -- using MapLibre in the digital twin
- [Custom Application Guide](06e-CUSTOM-APPS.md) -- React wrappers and mobile

---

*[Home](INDEX.md) | [Integration](06-INTEGRATION.md) | [Leaflet](06b-LEAFLET.md) | [OpenLayers](06c-OPENLAYERS.md) | [OXOT DT](06d-OXOT-CYBERDT.md)*
