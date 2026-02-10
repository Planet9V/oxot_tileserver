# Style API

> **Last Updated**: 2026-02-11 01:00 UTC

[Home](INDEX.md) > [API Reference](05-API.md) > Style API

---

## Overview

Tileserver-gl serves MapLibre GL-compatible style JSON documents that define how vector tile data is rendered. The OXOT Tileserver ships with an `infrastructure` style optimized for dark-background visualization of critical infrastructure across electric grid, water, pipeline, and telecommunications domains.

Styles are served at `/styles/{style}/style.json` and can be consumed directly by MapLibre GL JS, OpenLayers (via ol-mapbox-style), and Leaflet (via maplibre-gl-leaflet).

---

## MapLibre GL Style Specification

The style JSON follows the MapLibre GL Style Specification, which defines:

- **Version**: Always `8` (the current specification version).
- **Sources**: Named tile data sources with type, URL, and attribution.
- **Layers**: Ordered array of rendering rules, each targeting a source layer with paint and layout properties.
- **Glyphs**: URL template for font glyph PBFs used for text labels.
- **Sprite**: URL base for icon sprite sheets.

---

## Endpoints

| Endpoint | Description |
|----------|-------------|
| `GET /styles/{style}/style.json` | Full style document |
| `GET /styles/{style}/sprite.json` | Sprite metadata |
| `GET /styles/{style}/sprite.png` | Sprite sheet image |
| `GET /styles/{style}/sprite@2x.json` | Retina sprite metadata |
| `GET /styles/{style}/sprite@2x.png` | Retina sprite sheet |

```bash
# Fetch the infrastructure style
curl -s http://localhost:8080/styles/infrastructure/style.json | jq .
```

---

## infrastructure.json Walkthrough

The default style `infrastructure.json` is structured as follows.

### Root Properties

```json
{
  "version": 8,
  "name": "OXOT Infrastructure",
  "sources": { ... },
  "layers": [ ... ],
  "glyphs": "{fontstack}/{range}.pbf",
  "sprite": ""
}
```

### Sources

The style defines two vector tile sources:

```json
"sources": {
  "osm-infra": {
    "type": "vector",
    "url": "mbtiles://{osm-infrastructure}"
  },
  "geonames": {
    "type": "vector",
    "url": "mbtiles://{geonames}"
  }
}
```

When served by tileserver-gl, the `mbtiles://` protocol references are resolved to the actual tile files. The `/styles/infrastructure/style.json` endpoint rewrites these to absolute HTTP URLs pointing to the appropriate TileJSON endpoints.

### Layer Definitions

Layers are rendered bottom to top. The first layer in the array is drawn first (at the back), and the last layer is drawn on top.

---

#### background

The base layer fills the entire tile with a dark navy background.

```json
{
  "id": "background",
  "type": "background",
  "paint": {
    "background-color": "#1a1a2e"
  }
}
```

---

#### power-lines

Red lines representing high-voltage transmission and distribution infrastructure. Visible from zoom 4 (regional view) with width increasing at higher zooms.

```json
{
  "id": "power-lines",
  "type": "line",
  "source": "osm-infra",
  "source-layer": "power_lines",
  "minzoom": 4,
  "paint": {
    "line-color": "#ff4444",
    "line-width": [
      "interpolate", ["linear"], ["zoom"],
      4, 0.5,
      8, 1.5,
      12, 3
    ],
    "line-opacity": 0.8
  }
}
```

The `interpolate` expression scales line width smoothly from 0.5 pixels at zoom 4 to 3 pixels at zoom 12, keeping lines visible but not overwhelming at any zoom level.

---

#### pipelines

Orange dashed lines for oil, gas, and water pipelines. Visible from zoom 6.

```json
{
  "id": "pipelines",
  "type": "line",
  "source": "osm-infra",
  "source-layer": "pipelines",
  "minzoom": 6,
  "paint": {
    "line-color": "#ff8800",
    "line-width": [
      "interpolate", ["linear"], ["zoom"],
      6, 0.5,
      10, 2,
      14, 4
    ],
    "line-dasharray": [4, 2],
    "line-opacity": 0.7
  }
}
```

The `line-dasharray` of `[4, 2]` creates a dash pattern of 4 units on, 2 units off, distinguishing pipelines from power lines.

---

#### substations

Yellow circles marking electrical substations. Visible from zoom 8.

```json
{
  "id": "substations",
  "type": "circle",
  "source": "osm-infra",
  "source-layer": "substations",
  "minzoom": 8,
  "paint": {
    "circle-color": "#ffcc00",
    "circle-radius": [
      "interpolate", ["linear"], ["zoom"],
      8, 3,
      12, 6,
      14, 10
    ],
    "circle-stroke-color": "#ffffff",
    "circle-stroke-width": 1,
    "circle-opacity": 0.8
  }
}
```

---

#### generators

Green circles for power generation facilities. Visible from zoom 6.

```json
{
  "id": "generators",
  "type": "circle",
  "source": "osm-infra",
  "source-layer": "generators",
  "minzoom": 6,
  "paint": {
    "circle-color": "#00cc66",
    "circle-radius": [
      "interpolate", ["linear"], ["zoom"],
      6, 2,
      10, 5,
      14, 8
    ],
    "circle-stroke-color": "#ffffff",
    "circle-stroke-width": 1,
    "circle-opacity": 0.8
  }
}
```

---

#### water-treatment

Blue circles for water and wastewater treatment facilities. Visible from zoom 8.

```json
{
  "id": "water-treatment",
  "type": "circle",
  "source": "osm-infra",
  "source-layer": "water_treatment",
  "minzoom": 8,
  "paint": {
    "circle-color": "#3399ff",
    "circle-radius": [
      "interpolate", ["linear"], ["zoom"],
      8, 3,
      12, 6,
      14, 10
    ],
    "circle-stroke-color": "#ffffff",
    "circle-stroke-width": 1,
    "circle-opacity": 0.8
  }
}
```

---

#### telecom-masts

Purple circles for telecommunications towers. Visible from zoom 10 (city-level detail).

```json
{
  "id": "telecom-masts",
  "type": "circle",
  "source": "osm-infra",
  "source-layer": "telecom_masts",
  "minzoom": 10,
  "paint": {
    "circle-color": "#cc66ff",
    "circle-radius": [
      "interpolate", ["linear"], ["zoom"],
      10, 2,
      14, 6
    ],
    "circle-stroke-color": "#ffffff",
    "circle-stroke-width": 1,
    "circle-opacity": 0.7
  }
}
```

---

#### cities-label

White text labels for city names, sourced from the GeoNames tileset.

```json
{
  "id": "cities-label",
  "type": "symbol",
  "source": "geonames",
  "source-layer": "cities",
  "layout": {
    "text-field": "{name}",
    "text-font": ["Noto Sans Regular"],
    "text-size": [
      "interpolate", ["linear"], ["zoom"],
      3, 10,
      8, 14,
      12, 18
    ],
    "text-anchor": "top",
    "text-offset": [0, 0.5]
  },
  "paint": {
    "text-color": "#ffffff",
    "text-halo-color": "#000000",
    "text-halo-width": 1.5
  }
}
```

---

## Layer Ordering Summary

Layers render from bottom to top in this order:

| Order | Layer ID | Color | Type |
|-------|----------|-------|------|
| 1 | `background` | `#1a1a2e` (dark navy) | background |
| 2 | `power-lines` | `#ff4444` (red) | line |
| 3 | `pipelines` | `#ff8800` (orange, dashed) | line |
| 4 | `substations` | `#ffcc00` (yellow) | circle |
| 5 | `generators` | `#00cc66` (green) | circle |
| 6 | `water-treatment` | `#3399ff` (blue) | circle |
| 7 | `telecom-masts` | `#cc66ff` (purple) | circle |
| 8 | `cities-label` | `#ffffff` (white) | symbol |

---

## Creating Custom Styles

To create a new style:

1. Copy `infrastructure.json` as a starting point.
2. Modify sources, layers, and paint properties.
3. Place the new style file in the `data/styles/` directory.
4. Add an entry to `tileserver-config.json` under the `styles` section.
5. Restart the tileserver to load the new style.

```json
// tileserver-config.json excerpt
{
  "styles": {
    "infrastructure": {
      "style": "infrastructure.json"
    },
    "my-custom-style": {
      "style": "my-custom-style.json"
    }
  }
}
```

The new style is then available at `/styles/my-custom-style/style.json`.

---

## References

MapLibre. (2025). *MapLibre GL Style Specification*. https://maplibre.org/maplibre-style-spec/

---

## Related Pages

- [API Reference](05-API.md) -- parent page
- [REST API Endpoints](05a-REST-ENDPOINTS.md) -- style endpoint details
- [Vector Tile Format](05c-VECTOR-TILES.md) -- the tile data that styles render
- [Custom Layer Styling](07d-STYLING.md) -- advanced paint and layout properties
- [MapLibre GL JS](06a-MAPLIBRE.md) -- consuming styles in the primary client

---

*[Home](INDEX.md) | [API Reference](05-API.md) | [REST Endpoints](05a-REST-ENDPOINTS.md) | [TileJSON](05b-TILEJSON.md) | [Vector Tiles](05c-VECTOR-TILES.md)*
