# API Reference

> **Last Updated**: 2026-02-11 01:00 UTC

[Home](INDEX.md)

---

## Overview

The OXOT Tileserver exposes a read-only REST API that serves vector tiles, raster tile previews, style definitions, metadata, and health status. The API is provided by tileserver-gl and conforms to standard tile-serving conventions used by MapLibre GL JS, Leaflet, OpenLayers, and any other client that consumes the TileJSON or Mapbox Vector Tile specifications.

All endpoints use HTTP GET. There are no write endpoints -- content is managed through the data pipeline and configuration files, not through the API.

---

## Base URL

```
http://localhost:8080
```

The port is configurable through the `TILESERVER_PORT` environment variable in your `.env` file. When running inside a Docker network alongside other services, the internal hostname is typically `tileserver` and the port remains `8080` unless overridden.

```bash
# Default
TILESERVER_PORT=8080

# Custom
TILESERVER_PORT=9090
```

---

## Authentication

The tileserver does not implement authentication. It is designed for deployment behind a network boundary -- a private Docker network, a VPN, or a reverse proxy that provides its own access control.

If you need to restrict access in production, place the tileserver behind a reverse proxy such as nginx, Caddy, or Traefik and configure authentication at that layer. See [Performance Tuning](08c-PERFORMANCE.md) for reverse proxy guidance.

---

## Response Formats

| Format | Content Type | Used By |
|--------|-------------|---------|
| JSON | `application/json` | `/index.json`, TileJSON, style JSON, sprite JSON |
| PBF (Protocol Buffers) | `application/x-protobuf` | Vector tiles, font glyphs |
| PNG | `image/png` | Raster tile previews, sprite sheets |

---

## CORS

Tileserver-gl enables CORS (Cross-Origin Resource Sharing) by default. All responses include the `Access-Control-Allow-Origin: *` header. This permits any browser-based application to consume tiles directly from the tileserver without proxy configuration.

If you need to restrict CORS origins, configure this at the reverse proxy layer.

---

## Rate Limiting

Tileserver-gl does not implement rate limiting. For production deployments serving multiple concurrent users, apply rate limiting through your reverse proxy or a CDN. See [Performance Tuning](08c-PERFORMANCE.md) for configuration examples.

---

## Error Handling

All error responses use standard HTTP status codes:

| Code | Meaning | Common Cause |
|------|---------|--------------|
| `200` | OK | Successful request |
| `204` | No Content | Valid tile coordinates with no data at that location |
| `400` | Bad Request | Malformed URL or invalid parameters |
| `404` | Not Found | Tileset, style, or font not configured |
| `500` | Internal Server Error | Tile file corruption or server misconfiguration |

Error responses for JSON endpoints return a JSON body with a `message` field. Tile and image endpoints return the status code with no body.

---

## Endpoint Summary

| Endpoint Pattern | Description | Reference |
|-----------------|-------------|-----------|
| `GET /index.json` | List all available tilesets | [REST Endpoints](05a-REST-ENDPOINTS.md) |
| `GET /data/{tileset}/{z}/{x}/{y}.pbf` | Fetch a vector tile | [REST Endpoints](05a-REST-ENDPOINTS.md) |
| `GET /data/{tileset}.json` | TileJSON metadata for a tileset | [TileJSON Metadata](05b-TILEJSON.md) |
| `GET /styles/{style}/{z}/{x}/{y}.png` | Style-rendered raster tile | [REST Endpoints](05a-REST-ENDPOINTS.md) |
| `GET /styles/{style}/style.json` | MapLibre-compatible style JSON | [Style API](05d-STYLES.md) |
| `GET /styles/{style}/sprite.json` | Sprite metadata | [REST Endpoints](05a-REST-ENDPOINTS.md) |
| `GET /styles/{style}/sprite.png` | Sprite sheet image | [REST Endpoints](05a-REST-ENDPOINTS.md) |
| `GET /fonts/{fontstack}/{range}.pbf` | Glyph PBF for text rendering | [REST Endpoints](05a-REST-ENDPOINTS.md) |
| `GET /health` | Health check | [Health & Monitoring](08a-MONITORING.md) |

---

## Quick Verification

After starting the tileserver, verify the API is responding:

```bash
# Check health
curl -s http://localhost:8080/health

# List tilesets
curl -s http://localhost:8080/index.json | jq .

# Fetch TileJSON for a specific tileset
curl -s http://localhost:8080/data/osm-infrastructure.json | jq .
```

---

## Children Pages

| Page | Description |
|------|-------------|
| [REST API Endpoints](05a-REST-ENDPOINTS.md) | Complete endpoint reference with parameters, headers, and curl examples |
| [TileJSON Metadata](05b-TILEJSON.md) | TileJSON 3.0 specification and response schema |
| [Vector Tile Format](05c-VECTOR-TILES.md) | PBF encoding, coordinate system, layer structure |
| [Style API](05d-STYLES.md) | MapLibre GL style specification and infrastructure.json walkthrough |

---

## Next Steps

- **Need specific endpoint details?** See [REST API Endpoints](05a-REST-ENDPOINTS.md).
- **Building a map client?** Start with [MapLibre GL JS](06a-MAPLIBRE.md).
- **Troubleshooting API responses?** Check [Troubleshooting Guide](08b-TROUBLESHOOTING.md).

---

*[Home](INDEX.md) | [REST Endpoints](05a-REST-ENDPOINTS.md) | [TileJSON](05b-TILEJSON.md) | [Vector Tiles](05c-VECTOR-TILES.md) | [Styles](05d-STYLES.md)*
