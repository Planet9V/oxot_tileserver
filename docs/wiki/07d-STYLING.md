# Custom Layer Styling

> **Last Updated**: 2026-02-11 01:00 UTC

[Home](INDEX.md) > [Custom Tiles](07-CUSTOM-TILES.md)

---

## Overview

Custom tile layers need styling rules to control how features appear on the map. The OXOT Tileserver serves vector tiles that are rendered client-side using the MapLibre GL Style Specification. This page covers paint properties by geometry type, data-driven styling with expressions, zoom-dependent styling, and practical examples for infrastructure visualization.

All styling code in this page uses MapLibre GL JS. The same style specification applies to any compatible client library.

---

## Paint Properties by Geometry Type

### Circle (Point Features)

Used for facilities, equipment, sensors, and other point features.

| Property | Type | Default | Description |
|----------|------|---------|-------------|
| `circle-color` | Color | `#000000` | Fill color of the circle |
| `circle-radius` | Number | `5` | Circle radius in pixels |
| `circle-stroke-color` | Color | `#000000` | Outline color |
| `circle-stroke-width` | Number | `0` | Outline width in pixels |
| `circle-opacity` | Number | `1` | Fill opacity (0 to 1) |
| `circle-stroke-opacity` | Number | `1` | Stroke opacity (0 to 1) |
| `circle-blur` | Number | `0` | Amount of blur (0 = sharp) |
| `circle-translate` | Array | `[0, 0]` | Offset in pixels [x, y] |

```javascript
paint: {
  'circle-color': '#3388ff',
  'circle-radius': 8,
  'circle-stroke-color': '#ffffff',
  'circle-stroke-width': 2,
  'circle-opacity': 0.9
}
```

### Line (LineString Features)

Used for pipelines, transmission lines, cable routes, and boundaries.

| Property | Type | Default | Description |
|----------|------|---------|-------------|
| `line-color` | Color | `#000000` | Line color |
| `line-width` | Number | `1` | Line width in pixels |
| `line-opacity` | Number | `1` | Line opacity (0 to 1) |
| `line-dasharray` | Array | none | Dash pattern [dash, gap, ...] |
| `line-cap` | String | `"butt"` | End cap style: butt, round, square |
| `line-join` | String | `"miter"` | Join style: miter, bevel, round |
| `line-blur` | Number | `0` | Blur amount |
| `line-gap-width` | Number | `0` | Gap between parallel lines (casing) |
| `line-translate` | Array | `[0, 0]` | Offset in pixels |

```javascript
paint: {
  'line-color': '#ff6600',
  'line-width': 3,
  'line-opacity': 0.8,
  'line-dasharray': [2, 1]
}
```

### Fill (Polygon Features)

Used for facility boundaries, service zones, risk areas, and administrative regions.

| Property | Type | Default | Description |
|----------|------|---------|-------------|
| `fill-color` | Color | `#000000` | Fill color |
| `fill-opacity` | Number | `1` | Fill opacity (0 to 1) |
| `fill-outline-color` | Color | none | Outline color (defaults to fill-color) |
| `fill-antialias` | Boolean | `true` | Antialiased rendering |
| `fill-translate` | Array | `[0, 0]` | Offset in pixels |
| `fill-pattern` | String | none | Name of an image sprite for fill pattern |

```javascript
paint: {
  'fill-color': '#3388ff',
  'fill-opacity': 0.3,
  'fill-outline-color': '#3388ff'
}
```

### Symbol (Text Labels and Icons)

Used for facility names, asset IDs, and icon markers.

| Property | Category | Description |
|----------|----------|-------------|
| `text-field` | Layout | Text content: `'{facility_name}'` or expression |
| `text-size` | Layout | Font size in pixels |
| `text-font` | Layout | Array of font stack names |
| `text-anchor` | Layout | Anchor position: center, top, bottom, left, right |
| `text-offset` | Layout | Offset from anchor [x, y] in ems |
| `text-color` | Paint | Text color |
| `text-halo-color` | Paint | Halo (outline) color for readability |
| `text-halo-width` | Paint | Halo width in pixels |
| `icon-image` | Layout | Name of icon from sprite sheet |
| `icon-size` | Layout | Icon scale factor |

```javascript
layout: {
  'text-field': ['get', 'facility_name'],
  'text-size': 12,
  'text-font': ['Open Sans Regular'],
  'text-anchor': 'top',
  'text-offset': [0, 1]
},
paint: {
  'text-color': '#333333',
  'text-halo-color': '#ffffff',
  'text-halo-width': 1.5
}
```

---

## Data-Driven Styling with Expressions

MapLibre GL expressions allow paint and layout properties to change based on feature properties or zoom level.

### match (Categorical)

Assign different values based on a discrete property:

```javascript
'circle-color': [
  'match', ['get', 'criticality'],
  'critical', '#ff0000',
  'high', '#ff8800',
  'medium', '#ffcc00',
  'low', '#00cc44',
  '#888888'  // fallback
]
```

The last value is the fallback for any value not listed.

### interpolate (Continuous)

Smoothly transition between values based on a numeric property:

```javascript
'circle-radius': [
  'interpolate', ['linear'],
  ['get', 'capacity_mw'],
  0, 4,       // 0 MW -> 4px
  100, 8,     // 100 MW -> 8px
  500, 14,    // 500 MW -> 14px
  1000, 20    // 1000 MW -> 20px
]
```

Interpolation types: `linear`, `exponential` (with base), `cubic-bezier`.

### step (Discrete Thresholds)

Assign values based on numeric thresholds without interpolation:

```javascript
'circle-color': [
  'step', ['get', 'voltage_kv'],
  '#66cc66',      // < 33
  33, '#ffcc00',  // 33-131
  132, '#ff8800', // 132-399
  400, '#ff0000'  // 400+
]
```

### case (Boolean Conditions)

Apply different values based on boolean conditions:

```javascript
'circle-color': [
  'case',
  ['==', ['get', 'status'], 'offline'], '#ff0000',
  ['==', ['get', 'status'], 'maintenance'], '#ffcc00',
  ['==', ['get', 'status'], 'active'], '#00cc44',
  '#888888'
]
```

### Combining Expressions

Expressions can be nested for complex styling logic:

```javascript
'circle-radius': [
  'case',
  ['==', ['get', 'condition'], 'critical'],
  ['interpolate', ['linear'], ['zoom'], 4, 6, 14, 14],
  ['interpolate', ['linear'], ['zoom'], 4, 4, 14, 8]
]
```

---

## Zoom-Dependent Styling

Use `interpolate` on `['zoom']` to make features respond to the current zoom level.

### Grow circles as the user zooms in

```javascript
'circle-radius': [
  'interpolate', ['linear'],
  ['zoom'],
  4, 3,    // zoom 4 -> 3px
  8, 6,    // zoom 8 -> 6px
  12, 10,  // zoom 12 -> 10px
  14, 14   // zoom 14 -> 14px
]
```

### Show labels only at high zoom

```javascript
layout: {
  'text-field': ['get', 'facility_name'],
  'text-size': [
    'interpolate', ['linear'],
    ['zoom'],
    10, 0,   // hidden below zoom 10
    11, 10,  // fade in
    14, 14   // full size at zoom 14
  ]
}
```

### Widen lines with zoom

```javascript
'line-width': [
  'interpolate', ['exponential', 1.5],
  ['zoom'],
  4, 1,
  8, 2,
  12, 4,
  16, 8
]
```

---

## Practical Examples

### Color by Criticality

Three-color traffic light for infrastructure risk:

```javascript
map.addLayer({
  id: 'facilities-by-risk',
  type: 'circle',
  source: 'facilities',
  'source-layer': 'facilities',
  paint: {
    'circle-color': [
      'match', ['get', 'criticality'],
      'critical', '#dc2626',
      'high', '#ea580c',
      'medium', '#ca8a04',
      'low', '#16a34a',
      '#6b7280'
    ],
    'circle-radius': 8,
    'circle-stroke-color': '#ffffff',
    'circle-stroke-width': 2
  }
});
```

### Size by Capacity or Importance

Larger features represent higher capacity:

```javascript
map.addLayer({
  id: 'plants-by-capacity',
  type: 'circle',
  source: 'power-plants',
  'source-layer': 'power_plants',
  paint: {
    'circle-color': '#3b82f6',
    'circle-radius': [
      'interpolate', ['linear'],
      ['get', 'capacity_mw'],
      10, 5,
      100, 10,
      500, 16,
      2000, 24
    ],
    'circle-opacity': 0.8
  }
});
```

### Dash Patterns for Pipeline Types

Distinguish pipeline types by dash pattern:

```javascript
// Water main (solid)
map.addLayer({
  id: 'water-main',
  type: 'line',
  source: 'pipelines',
  'source-layer': 'pipelines',
  filter: ['==', 'pipeline_type', 'Water Main'],
  paint: {
    'line-color': '#3399ff',
    'line-width': 3
  }
});

// Gas main (dashed)
map.addLayer({
  id: 'gas-main',
  type: 'line',
  source: 'pipelines',
  'source-layer': 'pipelines',
  filter: ['==', 'pipeline_type', 'Gas Main'],
  paint: {
    'line-color': '#ff9900',
    'line-width': 3,
    'line-dasharray': [4, 2]
  }
});

// Sewer (dotted)
map.addLayer({
  id: 'sewer-line',
  type: 'line',
  source: 'pipelines',
  'source-layer': 'pipelines',
  filter: ['==', 'pipeline_type', 'Sewer'],
  paint: {
    'line-color': '#996633',
    'line-width': 3,
    'line-dasharray': [1, 2]
  }
});
```

---

## Layer Ordering

MapLibre GL renders layers in the order they are added. The first layer added is drawn at the bottom; the last is drawn on top.

```
Top (drawn last):
  labels
  point features (equipment, facilities)
  line features (pipelines, routes)
  polygon features (zones, boundaries)
Bottom (drawn first):
  basemap
```

To control ordering, add layers in the correct sequence or use the `beforeId` parameter:

```javascript
map.addLayer(polygonLayer);
map.addLayer(lineLayer);
map.addLayer(pointLayer);
map.addLayer(labelLayer);

// Or insert before a specific layer
map.addLayer(newLayer, 'existing-layer-id');
```

---

## Related Pages

- [Custom Tiles](07-CUSTOM-TILES.md) -- parent page with workflow overview
- [Map Cards & Popups](07e-CARDS-DISPLAY.md) -- interactive feature display
- [Per-Customer Facility Layers](07b-CUSTOMER-LAYERS.md) -- customer-specific styling examples
- [Equipment & Fixed Asset Layers](07c-EQUIPMENT-LAYERS.md) -- condition-based styling
- [MapLibre GL JS](06a-MAPLIBRE.md) -- primary client integration
- [Style API](05d-STYLES.md) -- server-side style serving

---

*[Home](INDEX.md) | [Custom Tiles](07-CUSTOM-TILES.md) | [Cards & Popups](07e-CARDS-DISPLAY.md) | [Customer Layers](07b-CUSTOMER-LAYERS.md)*
