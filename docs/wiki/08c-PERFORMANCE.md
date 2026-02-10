# Performance Tuning

> **Last Updated**: 2026-02-11 01:00 UTC

[Home](INDEX.md) > [Operations & Maintenance](08-OPERATIONS.md) > Performance Tuning

---

## Overview

The OXOT Tileserver's performance depends on two factors: the size and density of the generated tiles, and the efficiency of serving those tiles to clients. This page covers tippecanoe optimization for tile generation, tileserver-gl caching, reverse proxy configuration, and CDN considerations.

---

## Tile Size Optimization

### tippecanoe Settings

The primary tool for controlling tile performance is tippecanoe, which converts GeoJSON to MBTiles. Key flags:

| Flag | Purpose | Recommended Value |
|------|---------|-------------------|
| `--drop-densest-as-needed` | Drop features in dense areas at low zoom | Always use |
| `--extend-zooms-if-still-dropping` | Add zoom levels if features are still being dropped | Use for dense datasets |
| `--maximum-tile-bytes=500000` | Cap uncompressed tile size at 500 KB | Default target |
| `-z14` | Maximum zoom level | 14 for most infrastructure |
| `-Z0` | Minimum zoom level | 0 for global coverage |
| `--no-tile-compression` | Disable gzip in MBTiles (if tileserver-gl compresses on the fly) | Generally leave enabled |
| `--simplification=10` | Simplify geometries at low zoom | Use for complex line geometries |
| `--coalesce-densest-as-needed` | Merge nearby features | Useful for point clusters |

### Example Optimized Conversion

```bash
tippecanoe \
  -o data/tiles/osm-infrastructure.mbtiles \
  -n "osm-infrastructure" \
  -N "OpenStreetMap critical infrastructure" \
  -z14 -Z0 \
  --drop-densest-as-needed \
  --extend-zooms-if-still-dropping \
  --maximum-tile-bytes=500000 \
  --simplification=10 \
  --force \
  data/extracted/power_lines.geojson \
  data/extracted/substations.geojson \
  data/extracted/generators.geojson \
  data/extracted/pipelines.geojson \
  data/extracted/water_treatment.geojson \
  data/extracted/telecom_masts.geojson
```

### TIPPECANOE_THREADS

Control CPU parallelism during conversion:

```bash
# Use 4 threads (default: number of CPU cores)
export TIPPECANOE_THREADS=4

# Single-threaded (useful for debugging)
export TIPPECANOE_THREADS=1
```

More threads accelerate conversion but increase memory usage. For machines with limited RAM (< 8 GB), reduce thread count.

---

## Zoom Level Strategy

Not all layers need data at all zoom levels. Setting appropriate `minzoom` per layer reduces tile size and improves rendering performance.

| Layer | Recommended minzoom | Rationale |
|-------|-------------------|-----------|
| `power_lines` | 4 | Major transmission lines visible at regional scale |
| `pipelines` | 6 | Visible at sub-regional scale |
| `generators` | 6 | Large plants visible at sub-regional |
| `substations` | 8 | Metro-level detail |
| `water_treatment` | 8 | Metro-level detail |
| `telecom_masts` | 10 | City-level, very dense data |

Set per-layer minzoom during conversion:

```bash
tippecanoe \
  -L power_lines:data/extracted/power_lines.geojson \
  -L'{"file":"data/extracted/telecom_masts.geojson","layer":"telecom_masts","minzoom":10}' \
  ...
```

---

## Tileserver-gl Caching

### Default Cache Headers

Tileserver-gl sets `Cache-Control: public, max-age=86400` (24 hours) on tile responses by default. This instructs browsers and proxies to cache tiles locally.

### Configuring Cache Duration

Cache duration is controlled via the tileserver-gl configuration or command-line flags:

```bash
# Start with custom cache max-age (in seconds)
tileserver-gl --config /config/tileserver-config.json --cache-max-age 604800
```

A value of 604800 (7 days) is appropriate for infrastructure tiles that change infrequently.

---

## Reverse Proxy with nginx

Place nginx in front of tileserver-gl for caching, compression, rate limiting, and TLS termination.

### nginx Configuration

```nginx
proxy_cache_path /var/cache/nginx/tiles
  levels=1:2
  keys_zone=tiles:10m
  max_size=5g
  inactive=7d
  use_temp_path=off;

server {
  listen 443 ssl http2;
  server_name tiles.example.com;

  ssl_certificate     /etc/ssl/certs/tiles.pem;
  ssl_certificate_key /etc/ssl/private/tiles.key;

  location / {
    proxy_pass http://tileserver:8080;
    proxy_set_header Host $host;
    proxy_set_header X-Real-IP $remote_addr;

    # Cache tile responses
    proxy_cache tiles;
    proxy_cache_valid 200 7d;
    proxy_cache_valid 204 1h;
    proxy_cache_valid 404 1m;
    proxy_cache_use_stale error timeout updating;

    # Add cache status header for debugging
    add_header X-Cache-Status $upstream_cache_status;

    # Compression (tiles are pre-compressed, so skip .pbf)
    gzip on;
    gzip_types application/json;
  }
}
```

### Reverse Proxy with Caddy

Caddy provides automatic TLS and simpler configuration:

```
tiles.example.com {
  reverse_proxy tileserver:8080
  header Cache-Control "public, max-age=604800"
}
```

---

## CDN Considerations

For deployments serving tiles to geographically distributed users, a CDN can reduce latency and server load.

### CDN Requirements

- Support for `Cache-Control` headers from origin
- Pass-through of `Content-Encoding: gzip` for PBF tiles
- URL-based cache keys (tile URLs are naturally unique per z/x/y)
- No query string normalization (tile URLs have no query strings)

### CDN Configuration Notes

| CDN | Configuration |
|-----|--------------|
| CloudFlare | Set cache rule for `*.pbf` and `*.png` with edge TTL of 7 days |
| AWS CloudFront | Origin pointing to tileserver, default TTL from origin headers |
| Fastly | VCL with `beresp.ttl = 7d` for tile paths |

### Cache Invalidation

When tiles are regenerated, invalidate the CDN cache:

```bash
# CloudFlare purge
curl -X POST "https://api.cloudflare.com/client/v4/zones/{zone_id}/purge_cache" \
  -H "Authorization: Bearer {api_token}" \
  -H "Content-Type: application/json" \
  --data '{"purge_everything":true}'
```

---

## Memory Usage

Tileserver-gl's memory consumption depends on the number of loaded MBTiles files and raster rendering activity.

| Factor | Impact |
|--------|--------|
| Number of MBTiles files | Each file uses ~10--50 MB for SQLite index caching |
| Raster rendering | PNG tile rendering uses temporary buffers; ~50--200 MB per concurrent render |
| Font loading | Glyph PBFs are loaded on demand; ~20--50 MB |

### Limiting Memory

Set Docker memory limits to prevent runaway usage:

```yaml
services:
  tileserver:
    image: maptiler/tileserver-gl:latest
    deploy:
      resources:
        limits:
          memory: 1g
        reservations:
          memory: 256m
```

---

## Benchmarking

Measure tile serving performance with standard HTTP benchmarking tools:

```bash
# Simple throughput test with ab (Apache Bench)
ab -n 1000 -c 10 http://localhost:8080/data/osm-infrastructure/6/32/21.pbf

# More detailed with wrk
wrk -t4 -c20 -d30s http://localhost:8080/data/osm-infrastructure/6/32/21.pbf
```

Expected throughput for a single tileserver-gl instance:

| Tile Type | Requests/sec | Notes |
|-----------|-------------|-------|
| PBF (vector) | 500--2000 | Pre-compressed, fast I/O |
| PNG (raster) | 50--200 | Server-side rendering, CPU-bound |
| JSON (metadata) | 1000--5000 | Static responses |

---

## Related Pages

- [Operations & Maintenance](08-OPERATIONS.md) -- parent page
- [Conversion & Tippecanoe](04c-CONVERT.md) -- tile generation settings
- [Health & Monitoring](08a-MONITORING.md) -- monitoring the performance impact
- [Troubleshooting Guide](08b-TROUBLESHOOTING.md) -- diagnosing performance issues

---

*[Home](INDEX.md) | [Operations](08-OPERATIONS.md) | [Monitoring](08a-MONITORING.md) | [Troubleshooting](08b-TROUBLESHOOTING.md) | [Backup](08d-BACKUP-RESTORE.md)*
