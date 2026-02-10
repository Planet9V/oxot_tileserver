# TileJSON Metadata

> **Last Updated**: 2026-02-11 01:00 UTC

[Home](INDEX.md) > [API Reference](05-API.md) > TileJSON Metadata

---

## Overview

TileJSON is a lightweight JSON specification that describes the metadata and access patterns for a tileset. Tileserver-gl automatically generates a TileJSON response for every configured tileset, exposing it at `/data/{tileset}.json`. Map clients such as MapLibre GL JS, Leaflet, and OpenLayers use TileJSON to discover tile URLs, zoom ranges, geographic bounds, and available vector layers without any manual configuration.

The OXOT Tileserver implements TileJSON 3.0.

---

## TileJSON 3.0 Fields

The following table lists all fields present in a TileJSON response from tileserver-gl.

| Field | Type | Required | Description |
|-------|------|----------|-------------|
| `tilejson` | string | Yes | Specification version. Always `"3.0.0"`. |
| `name` | string | No | Human-readable tileset name. |
| `description` | string | No | Tileset description. |
| `tiles` | array of strings | Yes | URL template(s) for fetching tiles. Uses `{z}`, `{x}`, `{y}` placeholders. |
| `vector_layers` | array of objects | Yes (for vector) | Describes each vector layer in the tileset. |
| `bounds` | array of 4 numbers | No | Geographic bounding box: `[west, south, east, north]` in WGS84. |
| `center` | array of 3 numbers | No | Default map center: `[longitude, latitude, zoom]`. |
| `minzoom` | integer | No | Minimum zoom level available. |
| `maxzoom` | integer | No | Maximum zoom level available. |
| `attribution` | string | No | Attribution text for display in map UI. |
| `scheme` | string | No | Tile indexing scheme. Default is `"xyz"`. |
| `format` | string | No | Tile format: `"pbf"` for vector, `"png"` or `"jpg"` for raster. |

---

## vector_layers Object

Each entry in `vector_layers` describes one named layer within the tileset.

| Field | Type | Description |
|-------|------|-------------|
| `id` | string | Layer name used in style definitions (e.g., `"power_lines"`) |
| `description` | string | Human-readable description of the layer |
| `minzoom` | integer | Minimum zoom at which data exists for this layer |
| `maxzoom` | integer | Maximum zoom at which data exists for this layer |
| `fields` | object | Property names and their data types (e.g., `{ "voltage": "Number", "name": "String" }`) |

---

## Example TileJSON Response

Request:

```bash
curl -s http://localhost:8080/data/osm-infrastructure.json | jq .
```

Response:

```json
{
  "tilejson": "3.0.0",
  "name": "osm-infrastructure",
  "description": "OpenStreetMap critical infrastructure features",
  "tiles": [
    "http://localhost:8080/data/osm-infrastructure/{z}/{x}/{y}.pbf"
  ],
  "bounds": [-180, -85.0511, 180, 85.0511],
  "center": [0, 30, 3],
  "minzoom": 0,
  "maxzoom": 14,
  "format": "pbf",
  "scheme": "xyz",
  "vector_layers": [
    {
      "id": "power_lines",
      "description": "High-voltage transmission and distribution lines",
      "minzoom": 4,
      "maxzoom": 14,
      "fields": {
        "voltage": "Number",
        "name": "String",
        "operator": "String",
        "cables": "Number",
        "frequency": "Number"
      }
    },
    {
      "id": "substations",
      "description": "Electrical substations and transformer stations",
      "minzoom": 8,
      "maxzoom": 14,
      "fields": {
        "name": "String",
        "operator": "String",
        "voltage": "Number",
        "substation": "String"
      }
    },
    {
      "id": "generators",
      "description": "Power generation facilities",
      "minzoom": 6,
      "maxzoom": 14,
      "fields": {
        "name": "String",
        "source": "String",
        "output": "String",
        "operator": "String"
      }
    },
    {
      "id": "pipelines",
      "description": "Oil, gas, and water pipelines",
      "minzoom": 6,
      "maxzoom": 14,
      "fields": {
        "substance": "String",
        "operator": "String",
        "diameter": "Number"
      }
    },
    {
      "id": "water_treatment",
      "description": "Water and wastewater treatment facilities",
      "minzoom": 8,
      "maxzoom": 14,
      "fields": {
        "name": "String",
        "operator": "String",
        "type": "String"
      }
    },
    {
      "id": "telecom_masts",
      "description": "Telecommunications towers and masts",
      "minzoom": 10,
      "maxzoom": 14,
      "fields": {
        "name": "String",
        "operator": "String",
        "height": "Number",
        "communication_type": "String"
      }
    }
  ]
}
```

---

## Auto-Generation from MBTiles

Tileserver-gl reads the `metadata` table inside each `.mbtiles` file and constructs the TileJSON response automatically. The metadata table typically contains:

| Key | Source |
|-----|--------|
| `name` | Set during tippecanoe conversion with `-n` flag |
| `description` | Set during tippecanoe conversion with `-N` flag |
| `minzoom` / `maxzoom` | Detected from tile data or set with `-z` and `-Z` flags |
| `bounds` | Computed from tile extent or set with `-B` flag |
| `center` | Computed as center of bounds at average zoom |
| `json` (vector_layers) | Generated by tippecanoe from input GeoJSON properties |

If a `.pmtiles` file is used instead of `.mbtiles`, tileserver-gl reads the equivalent metadata from the PMTiles header.

---

## Using TileJSON in MapLibre GL JS

MapLibre GL JS can consume TileJSON directly as a source URL:

```javascript
const map = new maplibregl.Map({
  container: 'map',
  style: {
    version: 8,
    sources: {
      'osm-infra': {
        type: 'vector',
        url: 'http://localhost:8080/data/osm-infrastructure.json'
      }
    },
    layers: [
      // Layers referencing source 'osm-infra'
    ]
  }
});
```

When the `url` property is a TileJSON endpoint, MapLibre automatically resolves the `tiles` array, `bounds`, `minzoom`, and `maxzoom` from the response. This eliminates the need to hardcode tile URL templates in client code.

---

## Inspecting TileJSON

Use `jq` to inspect specific fields:

```bash
# List all vector layer names
curl -s http://localhost:8080/data/osm-infrastructure.json | jq '.vector_layers[].id'

# Show bounds and zoom range
curl -s http://localhost:8080/data/osm-infrastructure.json | jq '{bounds, minzoom, maxzoom}'

# Show fields for a specific layer
curl -s http://localhost:8080/data/osm-infrastructure.json | \
  jq '.vector_layers[] | select(.id == "power_lines") | .fields'
```

---

## References

Mapbox. (2024). *TileJSON specification (Version 3.0.0)*. GitHub. https://github.com/mapbox/tilejson-spec

---

## Related Pages

- [API Reference](05-API.md) -- parent page
- [REST API Endpoints](05a-REST-ENDPOINTS.md) -- the `/data/{tileset}.json` endpoint
- [Vector Tile Format](05c-VECTOR-TILES.md) -- PBF encoding of the tiles referenced in TileJSON
- [MapLibre GL JS](06a-MAPLIBRE.md) -- consuming TileJSON in the primary client

---

*[Home](INDEX.md) | [API Reference](05-API.md) | [REST Endpoints](05a-REST-ENDPOINTS.md) | [Vector Tiles](05c-VECTOR-TILES.md) | [Styles](05d-STYLES.md)*
