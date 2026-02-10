# REST API Endpoints

> **Last Updated**: 2026-02-11 01:00 UTC

[Home](INDEX.md) > [API Reference](05-API.md) > REST API Endpoints

---

## Overview

This page documents every HTTP endpoint exposed by tileserver-gl. All endpoints accept GET requests only. The base URL defaults to `http://localhost:8080` and is configurable via the `TILESERVER_PORT` environment variable.

---

## GET /index.json

Returns a JSON object listing all configured tilesets and styles.

**Response**: `application/json`

```bash
curl -s http://localhost:8080/index.json | jq .
```

**Example response**:

```json
{
  "tilesets": [
    {
      "name": "osm-infrastructure",
      "url": "http://localhost:8080/data/osm-infrastructure.json"
    },
    {
      "name": "geonames",
      "url": "http://localhost:8080/data/geonames.json"
    }
  ],
  "styles": [
    {
      "name": "infrastructure",
      "url": "http://localhost:8080/styles/infrastructure/style.json"
    }
  ]
}
```

**Status codes**:

| Code | Meaning |
|------|---------|
| `200` | Tileset and style listing returned |
| `500` | Server configuration error |

---

## GET /data/{tileset}/{z}/{x}/{y}.pbf

Returns a single vector tile in Mapbox Vector Tile (MVT) format, encoded as a Protocol Buffer.

**Path parameters**:

| Parameter | Type | Description |
|-----------|------|-------------|
| `tileset` | string | Tileset name as registered in tileserver-config.json (e.g., `osm-infrastructure`) |
| `z` | integer | Zoom level (typically 0--14) |
| `x` | integer | Tile column (0 to 2^z - 1) |
| `y` | integer | Tile row (0 to 2^z - 1) |

**Response headers**:

| Header | Value |
|--------|-------|
| `Content-Type` | `application/x-protobuf` |
| `Content-Encoding` | `gzip` (tiles are pre-compressed in MBTiles) |
| `Access-Control-Allow-Origin` | `*` |
| `Cache-Control` | `public, max-age=86400` |

```bash
# Fetch zoom 6, tile column 32, row 21 from osm-infrastructure
curl -s -o tile.pbf http://localhost:8080/data/osm-infrastructure/6/32/21.pbf

# Check response headers
curl -sI http://localhost:8080/data/osm-infrastructure/6/32/21.pbf
```

**Status codes**:

| Code | Meaning |
|------|---------|
| `200` | Tile data returned |
| `204` | Valid coordinates, no data at this location |
| `404` | Tileset not found or coordinates out of range |

---

## GET /data/{tileset}/{z}/{x}/{y}.png

Returns a server-rendered raster image of the vector tile. This endpoint is available when a style referencing the tileset is configured.

**Path parameters**: Same as the PBF endpoint above.

**Query parameters**:

| Parameter | Type | Default | Description |
|-----------|------|---------|-------------|
| (none currently) | -- | -- | Retina support may use `@2x` suffix: `/data/{tileset}/{z}/{x}/{y}@2x.png` |

**Response**: `image/png`

```bash
# Fetch a raster preview tile
curl -s -o preview.png http://localhost:8080/data/osm-infrastructure/6/32/21.png

# Retina (2x) version
curl -s -o preview_2x.png http://localhost:8080/data/osm-infrastructure/6/32/21@2x.png
```

**Status codes**:

| Code | Meaning |
|------|---------|
| `200` | Rendered PNG returned |
| `404` | Tileset or style not configured for raster rendering |

---

## GET /styles/{style}/{z}/{x}/{y}.png

Returns a raster tile rendered using the named style definition. This combines all sources referenced by the style into a single composited image.

**Path parameters**:

| Parameter | Type | Description |
|-----------|------|-------------|
| `style` | string | Style name (e.g., `infrastructure`) |
| `z` | integer | Zoom level |
| `x` | integer | Tile column |
| `y` | integer | Tile row |

**Response**: `image/png`

```bash
# Rendered raster tile from the infrastructure style
curl -s -o styled.png http://localhost:8080/styles/infrastructure/8/128/85.png

# Retina version
curl -s -o styled_2x.png http://localhost:8080/styles/infrastructure/8/128/85@2x.png
```

**Status codes**:

| Code | Meaning |
|------|---------|
| `200` | Styled raster tile returned |
| `404` | Style not found |
| `500` | Rendering error (missing fonts, broken style JSON) |

---

## GET /data/{tileset}.json

Returns TileJSON metadata for the specified tileset. This endpoint is the primary mechanism for map clients to discover tile URLs, zoom ranges, bounds, and available vector layers.

**Path parameters**:

| Parameter | Type | Description |
|-----------|------|-------------|
| `tileset` | string | Tileset name (e.g., `osm-infrastructure`) |

**Response**: `application/json`

```bash
curl -s http://localhost:8080/data/osm-infrastructure.json | jq .
```

See [TileJSON Metadata](05b-TILEJSON.md) for the full response schema and field descriptions.

**Status codes**:

| Code | Meaning |
|------|---------|
| `200` | TileJSON metadata returned |
| `404` | Tileset not found |

---

## GET /styles/{style}/style.json

Returns a MapLibre GL-compatible style JSON document. Map clients use this URL as the `style` parameter to render the complete styled map.

**Path parameters**:

| Parameter | Type | Description |
|-----------|------|-------------|
| `style` | string | Style name (e.g., `infrastructure`) |

**Response**: `application/json`

```bash
curl -s http://localhost:8080/styles/infrastructure/style.json | jq .
```

The returned style JSON contains tile source URLs rewritten to use the request's host and port, so clients receive correct absolute URLs regardless of how the tileserver is accessed.

See [Style API](05d-STYLES.md) for a full walkthrough of the infrastructure style.

**Status codes**:

| Code | Meaning |
|------|---------|
| `200` | Style JSON returned |
| `404` | Style not found |

---

## GET /health

Returns a health status response. Used by Docker healthcheck, load balancers, and monitoring systems.

**Response**: `application/json`

```bash
curl -s http://localhost:8080/health
```

**Example response**:

```json
{
  "status": "ok"
}
```

**Status codes**:

| Code | Meaning |
|------|---------|
| `200` | Server is healthy |
| `503` | Server is starting or unhealthy |

See [Health & Monitoring](08a-MONITORING.md) for Docker healthcheck configuration.

---

## GET /styles/{style}/sprite.json

Returns sprite metadata for the named style. Sprites are used for icon rendering on the map.

**Path parameters**:

| Parameter | Type | Description |
|-----------|------|-------------|
| `style` | string | Style name |

**Response**: `application/json`

```bash
curl -s http://localhost:8080/styles/infrastructure/sprite.json | jq .
```

**Example response** (partial):

```json
{
  "substation-icon": {
    "width": 24,
    "height": 24,
    "x": 0,
    "y": 0,
    "pixelRatio": 1
  }
}
```

---

## GET /styles/{style}/sprite.png

Returns the sprite sheet image for the named style.

**Response**: `image/png`

```bash
curl -s -o sprite.png http://localhost:8080/styles/infrastructure/sprite.png

# Retina version
curl -s -o sprite_2x.png http://localhost:8080/styles/infrastructure/sprite@2x.png
```

---

## GET /fonts/{fontstack}/{range}.pbf

Returns glyph data (font glyphs) in PBF format for text rendering on the map. MapLibre GL JS requests these automatically when rendering text labels.

**Path parameters**:

| Parameter | Type | Description |
|-----------|------|-------------|
| `fontstack` | string | Font name(s), comma-separated and URL-encoded (e.g., `Noto Sans Regular`) |
| `range` | string | Unicode range in the format `{start}-{end}` (e.g., `0-255`) |

**Response**: `application/x-protobuf`

```bash
# Fetch glyphs for Noto Sans Regular, Unicode range 0-255
curl -s -o glyphs.pbf "http://localhost:8080/fonts/Noto%20Sans%20Regular/0-255.pbf"
```

**Status codes**:

| Code | Meaning |
|------|---------|
| `200` | Glyph data returned |
| `404` | Font not found -- verify font files exist in the fonts directory |

---

## HTTP Status Code Summary

| Code | Meaning | Action |
|------|---------|--------|
| `200` | OK | Request succeeded |
| `204` | No Content | Valid tile request, no data at these coordinates |
| `400` | Bad Request | Check URL format and parameter types |
| `404` | Not Found | Verify tileset/style name against `/index.json` |
| `500` | Internal Server Error | Check tileserver logs: `docker compose logs tileserver` |
| `503` | Service Unavailable | Server starting up; retry after a few seconds |

---

## Complete Verification Script

Run this script after deployment to verify all endpoint categories are functioning:

```bash
#!/bin/bash
BASE="http://localhost:8080"

echo "=== Health ==="
curl -s "$BASE/health" | jq .

echo "=== Index ==="
curl -s "$BASE/index.json" | jq '.tilesets | length'

echo "=== TileJSON ==="
curl -s "$BASE/data/osm-infrastructure.json" | jq '.name, .minzoom, .maxzoom'

echo "=== Vector Tile (PBF) ==="
curl -sI "$BASE/data/osm-infrastructure/6/32/21.pbf" | head -3

echo "=== Style JSON ==="
curl -s "$BASE/styles/infrastructure/style.json" | jq '.name, .sources | keys'

echo "=== Raster Tile (PNG) ==="
curl -sI "$BASE/styles/infrastructure/6/32/21.png" | head -3

echo "=== Done ==="
```

---

## Related Pages

- [API Reference](05-API.md) -- parent page with base URL and CORS details
- [TileJSON Metadata](05b-TILEJSON.md) -- full TileJSON response schema
- [Vector Tile Format](05c-VECTOR-TILES.md) -- PBF encoding details
- [Style API](05d-STYLES.md) -- style.json specification
- [Health & Monitoring](08a-MONITORING.md) -- health endpoint usage
- [Troubleshooting Guide](08b-TROUBLESHOOTING.md) -- resolving API errors

---

*[Home](INDEX.md) | [API Reference](05-API.md) | [TileJSON](05b-TILEJSON.md) | [Vector Tiles](05c-VECTOR-TILES.md) | [Styles](05d-STYLES.md)*
