# OpenLayers Integration

> **Last Updated**: 2026-02-11 01:00 UTC

[Home](INDEX.md) > [Application Integration](06-INTEGRATION.md) > OpenLayers Integration

---

## Overview

OpenLayers is a full-featured mapping library commonly used in enterprise GIS applications. It supports Mapbox Vector Tiles (MVT) natively through `ol/source/VectorTile` and `ol/format/MVT`. The `ol-mapbox-style` package bridges the gap between MapLibre GL style JSON and OpenLayers, allowing you to use the tileserver's style directly.

---

## Installation

```bash
npm install ol ol-mapbox-style
```

---

## Using ol-mapbox-style (Recommended)

The simplest approach uses the `apply` function from `ol-mapbox-style` to load the tileserver's style JSON directly:

```javascript
import { apply } from 'ol-mapbox-style';

const map = apply('map', 'http://localhost:8080/styles/infrastructure/style.json');
```

This creates an OpenLayers map with all sources, layers, and styles resolved from the tileserver's style JSON. The `apply` function handles source URL resolution, layer creation, and paint property translation.

---

## Manual Source and Layer Setup

For full control, create the vector tile source and layers manually:

```javascript
import Map from 'ol/Map';
import View from 'ol/View';
import VectorTileLayer from 'ol/layer/VectorTile';
import VectorTileSource from 'ol/source/VectorTile';
import MVT from 'ol/format/MVT';
import { Style, Stroke, Fill, Circle } from 'ol/style';
import { fromLonLat } from 'ol/proj';

const infraSource = new VectorTileSource({
  format: new MVT(),
  url: 'http://localhost:8080/data/osm-infrastructure/{z}/{x}/{y}.pbf',
  maxZoom: 14
});

const infraLayer = new VectorTileLayer({
  source: infraSource,
  style: function(feature) {
    const layer = feature.get('layer');

    switch (layer) {
      case 'power_lines':
        return new Style({
          stroke: new Stroke({ color: '#ff4444', width: 1.5 })
        });
      case 'pipelines':
        return new Style({
          stroke: new Stroke({ color: '#ff8800', width: 1, lineDash: [8, 4] })
        });
      case 'substations':
        return new Style({
          image: new Circle({
            radius: 5,
            fill: new Fill({ color: '#ffcc00' }),
            stroke: new Stroke({ color: '#ffffff', width: 1 })
          })
        });
      case 'generators':
        return new Style({
          image: new Circle({
            radius: 4,
            fill: new Fill({ color: '#00cc66' }),
            stroke: new Stroke({ color: '#ffffff', width: 1 })
          })
        });
      case 'water_treatment':
        return new Style({
          image: new Circle({
            radius: 5,
            fill: new Fill({ color: '#3399ff' }),
            stroke: new Stroke({ color: '#ffffff', width: 1 })
          })
        });
      case 'telecom_masts':
        return new Style({
          image: new Circle({
            radius: 3,
            fill: new Fill({ color: '#cc66ff' }),
            stroke: new Stroke({ color: '#ffffff', width: 1 })
          })
        });
      default:
        return null;
    }
  }
});

const map = new Map({
  target: 'map',
  layers: [infraLayer],
  view: new View({
    center: fromLonLat([-98.5, 39.8]),
    zoom: 4
  })
});
```

---

## Click Interaction

```javascript
import Overlay from 'ol/Overlay';

const popup = document.createElement('div');
popup.className = 'ol-popup';
const overlay = new Overlay({ element: popup, autoPan: true });
map.addOverlay(overlay);

map.on('click', function(evt) {
  const features = map.getFeaturesAtPixel(evt.pixel);
  if (features.length > 0) {
    const props = features[0].getProperties();
    delete props.geometry;

    const html = Object.entries(props)
      .filter(([, v]) => v != null)
      .map(([k, v]) => '<b>' + k + ':</b> ' + v)
      .join('<br>');

    popup.innerHTML = html;
    overlay.setPosition(evt.coordinate);
  } else {
    overlay.setPosition(undefined);
  }
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
  <title>OXOT Tileserver - OpenLayers</title>
  <style>
    body { margin: 0; }
    #map { height: 100vh; background-color: #1a1a2e; }
  </style>
</head>
<body>

<div id="map"></div>

<script type="module">
  import { apply } from 'https://esm.sh/ol-mapbox-style@12';

  const map = await apply('map', 'http://localhost:8080/styles/infrastructure/style.json');

  // Set background
  map.getTargetElement().style.backgroundColor = '#1a1a2e';
</script>

</body>
</html>
```

For production use, bundle with your build tool (Vite, Webpack) instead of using ESM imports from a CDN.

---

## Styling Differences from MapLibre

| Concept | MapLibre GL JS | OpenLayers |
|---------|---------------|------------|
| Style source | Style JSON URL | `ol-mapbox-style` or manual `Style` objects |
| Expressions | Full MapLibre expression support | Limited via `ol-mapbox-style`; manual with style function |
| Interpolation | Native | Implemented via resolution-based style functions |
| Layer type | `line`, `circle`, `symbol` | `VectorTileLayer` with style function dispatching |
| Text labels | `symbol` layer with `text-field` | `ol/style/Text` or via `ol-mapbox-style` |

The `ol-mapbox-style` package handles most translations automatically. For advanced expressions not supported by the bridge, use OpenLayers style functions.

---

## Performance Notes

- OpenLayers can use WebGL rendering via `ol/layer/WebGLTile` for raster layers, but vector tile rendering currently uses Canvas.
- For large datasets, ensure `maxZoom` on the source matches the tileset's `maxzoom` to enable proper overzooming.
- Declutter overlapping labels by setting `declutter: true` on the layer.

---

## References

OpenLayers. (2025). *OpenLayers: A high-performance, feature-packed library for all your mapping needs*. https://openlayers.org/

---

## Related Pages

- [Application Integration](06-INTEGRATION.md) -- parent page with library comparison
- [MapLibre GL JS](06a-MAPLIBRE.md) -- recommended alternative
- [REST API Endpoints](05a-REST-ENDPOINTS.md) -- PBF and style endpoints
- [Style API](05d-STYLES.md) -- style definitions consumed via ol-mapbox-style

---

*[Home](INDEX.md) | [Integration](06-INTEGRATION.md) | [MapLibre](06a-MAPLIBRE.md) | [Leaflet](06b-LEAFLET.md) | [OXOT DT](06d-OXOT-CYBERDT.md)*
