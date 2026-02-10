# Leaflet Integration

> **Last Updated**: 2026-02-11 01:00 UTC

[Home](INDEX.md) > [Application Integration](06-INTEGRATION.md) > Leaflet Integration

---

## Overview

Leaflet is a lightweight, widely adopted JavaScript map library. While it does not natively support vector tiles, the `leaflet.vectorgrid` plugin adds PBF vector tile rendering using HTML5 Canvas. This page documents how to connect Leaflet to the OXOT Tileserver.

For new projects, [MapLibre GL JS](06a-MAPLIBRE.md) is recommended over Leaflet for vector tile workloads. Use this guide when Leaflet is already established in your application.

---

## Dependencies

### npm

```bash
npm install leaflet leaflet.vectorgrid
```

```javascript
import L from 'leaflet';
import 'leaflet/dist/leaflet.css';
import 'leaflet.vectorgrid';
```

### CDN

```html
<link rel="stylesheet" href="https://unpkg.com/leaflet@1.9/dist/leaflet.css" />
<script src="https://unpkg.com/leaflet@1.9/dist/leaflet.js"></script>
<script src="https://unpkg.com/leaflet.vectorgrid@1.3/dist/Leaflet.VectorGrid.bundled.min.js"></script>
```

---

## Adding a PBF Vector Tile Layer

Use `L.vectorGrid.protobuf` to connect to the tileserver's PBF endpoint:

```javascript
const map = L.map('map').setView([39.8, -98.5], 4);

// Dark background tile layer (or use a solid color)
L.tileLayer('', {
  attribution: ''
}).addTo(map);

// Set map background to match the infrastructure style
document.getElementById('map').style.backgroundColor = '#1a1a2e';

const tileUrl = 'http://localhost:8080/data/osm-infrastructure/{z}/{x}/{y}.pbf';

const infraLayer = L.vectorGrid.protobuf(tileUrl, {
  vectorTileLayerStyles: {
    power_lines: {
      weight: 1.5,
      color: '#ff4444',
      opacity: 0.8
    },
    pipelines: {
      weight: 1,
      color: '#ff8800',
      opacity: 0.7,
      dashArray: '8, 4'
    },
    substations: {
      radius: 5,
      fillColor: '#ffcc00',
      fillOpacity: 0.8,
      color: '#ffffff',
      weight: 1,
      fill: true
    },
    generators: {
      radius: 4,
      fillColor: '#00cc66',
      fillOpacity: 0.8,
      color: '#ffffff',
      weight: 1,
      fill: true
    },
    water_treatment: {
      radius: 5,
      fillColor: '#3399ff',
      fillOpacity: 0.8,
      color: '#ffffff',
      weight: 1,
      fill: true
    },
    telecom_masts: {
      radius: 3,
      fillColor: '#cc66ff',
      fillOpacity: 0.7,
      color: '#ffffff',
      weight: 1,
      fill: true
    }
  },
  interactive: true,
  maxNativeZoom: 14,
  getFeatureId: function(f) {
    return f.properties.name || f.properties.id;
  }
}).addTo(map);
```

---

## Styling Differences from MapLibre

Leaflet uses its own styling system, not the MapLibre GL Style Specification. Key differences:

| Concept | MapLibre GL JS | Leaflet VectorGrid |
|---------|---------------|-------------------|
| Style source | Style JSON URL | Inline `vectorTileLayerStyles` object |
| Line width | `line-width` (supports expressions) | `weight` (static number) |
| Circle radius | `circle-radius` (supports expressions) | `radius` (static number) |
| Dash pattern | `line-dasharray` (unitless) | `dashArray` (CSS string, pixels) |
| Color | Paint properties | Leaflet path options |
| Zoom interpolation | Native expression support | Must use `setStyle()` on zoom change |

The main limitation is the absence of zoom-dependent interpolation expressions. Leaflet renders features with the same style at all zoom levels unless you manually update styles on zoom events.

---

## Click Interaction

```javascript
infraLayer.on('click', function(e) {
  const props = e.layer.properties;
  const content = Object.entries(props)
    .filter(([k, v]) => v !== null && v !== '')
    .map(([k, v]) => '<strong>' + k + ':</strong> ' + v)
    .join('<br>');

  L.popup()
    .setLatLng(e.latlng)
    .setContent(content || 'No properties')
    .openOn(map);
});
```

---

## Complete Example

```html
<!DOCTYPE html>
<html lang="en">
<head>
  <meta charset="UTF-8" />
  <meta name="viewport" content="width=device-width, initial-scale=1.0" />
  <title>OXOT Tileserver - Leaflet</title>
  <link rel="stylesheet" href="https://unpkg.com/leaflet@1.9/dist/leaflet.css" />
  <script src="https://unpkg.com/leaflet@1.9/dist/leaflet.js"></script>
  <script src="https://unpkg.com/leaflet.vectorgrid@1.3/dist/Leaflet.VectorGrid.bundled.min.js"></script>
  <style>
    body { margin: 0; }
    #map { height: 100vh; background-color: #1a1a2e; }
  </style>
</head>
<body>

<div id="map"></div>

<script>
  const map = L.map('map').setView([39.8, -98.5], 4);

  const tileUrl = 'http://localhost:8080/data/osm-infrastructure/{z}/{x}/{y}.pbf';

  const infraLayer = L.vectorGrid.protobuf(tileUrl, {
    vectorTileLayerStyles: {
      power_lines: { weight: 1.5, color: '#ff4444', opacity: 0.8 },
      pipelines: { weight: 1, color: '#ff8800', opacity: 0.7, dashArray: '8, 4' },
      substations: { radius: 5, fillColor: '#ffcc00', fillOpacity: 0.8, color: '#fff', weight: 1, fill: true },
      generators: { radius: 4, fillColor: '#00cc66', fillOpacity: 0.8, color: '#fff', weight: 1, fill: true },
      water_treatment: { radius: 5, fillColor: '#3399ff', fillOpacity: 0.8, color: '#fff', weight: 1, fill: true },
      telecom_masts: { radius: 3, fillColor: '#cc66ff', fillOpacity: 0.7, color: '#fff', weight: 1, fill: true }
    },
    interactive: true,
    maxNativeZoom: 14
  }).addTo(map);

  infraLayer.on('click', function(e) {
    const props = e.layer.properties;
    const html = Object.entries(props)
      .filter(([, v]) => v != null)
      .map(([k, v]) => '<b>' + k + ':</b> ' + v)
      .join('<br>');
    L.popup().setLatLng(e.latlng).setContent(html || 'No data').openOn(map);
  });
</script>

</body>
</html>
```

---

## Limitations Compared to MapLibre

| Limitation | Impact | Workaround |
|-----------|--------|------------|
| No WebGL rendering | Slower with many features | Reduce feature density via tippecanoe |
| No zoom interpolation | Fixed symbol sizes | Manual `setStyle()` on zoom events |
| No style JSON support | Cannot use tileserver style directly | Define styles inline |
| No map rotation or tilt | 2D only | Use MapLibre if 3D is needed |
| No text labels from style | Labels require separate plugin | Use `L.marker` with `divIcon` |
| Canvas rendering only | Lower visual quality at high DPI | Use retina detection for line widths |

---

## References

Agafonkin, V. (2024). *Leaflet: An open-source JavaScript library for interactive maps*. https://leafletjs.com/

---

## Related Pages

- [Application Integration](06-INTEGRATION.md) -- parent page with library comparison
- [MapLibre GL JS](06a-MAPLIBRE.md) -- recommended alternative with native vector tile support
- [REST API Endpoints](05a-REST-ENDPOINTS.md) -- PBF endpoint used by vectorgrid
- [Style API](05d-STYLES.md) -- style definitions (not directly usable in Leaflet)

---

*[Home](INDEX.md) | [Integration](06-INTEGRATION.md) | [MapLibre](06a-MAPLIBRE.md) | [OpenLayers](06c-OPENLAYERS.md) | [OXOT DT](06d-OXOT-CYBERDT.md)*
