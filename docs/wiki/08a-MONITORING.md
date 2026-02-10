# Health & Monitoring

> **Last Updated**: 2026-02-11 01:00 UTC

[Home](INDEX.md) > [Operations & Maintenance](08-OPERATIONS.md) > Health & Monitoring

---

## Overview

The OXOT Tileserver provides a health check endpoint and standard Docker container monitoring capabilities. This page covers the health endpoint, Docker healthcheck configuration, log inspection, disk usage monitoring, and integration with external monitoring tools.

---

## Health Endpoint

### GET /health

```bash
curl -s http://localhost:8080/health
```

**Healthy response** (HTTP 200):

```json
{
  "status": "ok"
}
```

**Unhealthy response** (HTTP 503):

Returned when the server is starting up or has encountered a fatal configuration error.

### Scripted Health Check

```bash
#!/bin/bash
STATUS=$(curl -s -o /dev/null -w "%{http_code}" http://localhost:8080/health)
if [ "$STATUS" -eq 200 ]; then
  echo "Tileserver: healthy"
else
  echo "Tileserver: unhealthy (HTTP $STATUS)"
  exit 1
fi
```

---

## Docker Healthcheck

Configure a health check in `docker-compose.yml` to let Docker automatically monitor the tileserver and restart it on failure:

```yaml
services:
  tileserver:
    image: maptiler/tileserver-gl:latest
    ports:
      - "8080:8080"
    volumes:
      - ./data/tiles:/data
      - ./config:/config
    healthcheck:
      test: ["CMD", "curl", "-f", "http://localhost:8080/health"]
      interval: 30s
      timeout: 10s
      retries: 3
      start_period: 15s
    restart: unless-stopped
```

| Parameter | Value | Purpose |
|-----------|-------|---------|
| `interval` | 30s | Time between health checks |
| `timeout` | 10s | Max time to wait for response |
| `retries` | 3 | Consecutive failures before marking unhealthy |
| `start_period` | 15s | Grace period during startup |

---

## Container Status

### Check Running State

```bash
docker compose ps tileserver
```

Expected output:

```
NAME         IMAGE                         STATUS                    PORTS
tileserver   maptiler/tileserver-gl:latest  Up 2 hours (healthy)     0.0.0.0:8080->8080/tcp
```

### Resource Usage

```bash
# One-shot resource snapshot
docker stats tileserver --no-stream

# Continuous monitoring
docker stats tileserver
```

Typical resource usage:

| Metric | Idle | Under Load |
|--------|------|-----------|
| CPU | < 1% | 5--20% (depending on raster rendering) |
| Memory | 100--200 MB | 200--512 MB |
| Network I/O | Minimal | Proportional to tile requests |

---

## Log Inspection

### View Recent Logs

```bash
# Last 50 lines
docker compose logs tileserver --tail 50

# Follow live
docker compose logs tileserver -f

# With timestamps
docker compose logs tileserver --tail 50 -t
```

### Log Patterns

**Normal startup**:

```
Starting tileserver-gl v4.x.x
Listening at http://0.0.0.0:8080/
Serving data/osm-infrastructure.mbtiles
Serving data/geonames.mbtiles
```

**Configuration error**:

```
ERROR: Config file not found: /config/tileserver-config.json
```

**Missing tile file**:

```
ERROR: MBTiles file not found: /data/nonexistent.mbtiles
```

**Normal request log**:

```
GET /data/osm-infrastructure/6/32/21.pbf 200 1.234ms
GET /styles/infrastructure/style.json 200 0.456ms
```

### Log Filtering

```bash
# Show only errors
docker compose logs tileserver --tail 200 2>&1 | grep -i error

# Show only 404 responses
docker compose logs tileserver --tail 500 2>&1 | grep " 404 "

# Show slow requests (>500ms)
docker compose logs tileserver --tail 500 2>&1 | grep -E '[5-9][0-9]{2,}\.[0-9]+ms|[0-9]{4,}\.[0-9]+ms'
```

---

## Disk Usage Monitoring

### Tile Directory Size

```bash
# Total tile storage
du -sh data/tiles/

# Per-file breakdown
du -sh data/tiles/*.mbtiles data/tiles/*.pmtiles 2>/dev/null | sort -rh

# Raw data (can be deleted after conversion)
du -sh data/raw/
```

### Disk Space Alert Script

```bash
#!/bin/bash
TILE_DIR="data/tiles"
THRESHOLD_GB=50
USAGE_KB=$(du -sk "$TILE_DIR" | cut -f1)
USAGE_GB=$((USAGE_KB / 1048576))

if [ "$USAGE_GB" -ge "$THRESHOLD_GB" ]; then
  echo "WARNING: Tile directory using ${USAGE_GB}GB (threshold: ${THRESHOLD_GB}GB)"
  exit 1
fi
echo "Tile directory: ${USAGE_GB}GB (OK)"
```

---

## Tileset Count Verification

Verify that all expected tilesets are loaded:

```bash
# Count tilesets
curl -s http://localhost:8080/index.json | jq '.tilesets | length'

# List tileset names
curl -s http://localhost:8080/index.json | jq '.tilesets[].name'

# List style names
curl -s http://localhost:8080/index.json | jq '.styles[].name'
```

Compare against the expected count for your installation option:

| Install Option | Expected Tilesets |
|---------------|-------------------|
| A (Basemap) | 1--2 |
| B (Single region) | 3--5 |
| C (Single domain) | 5--8 |
| D (Multi-domain) | 8--12 |
| E (Full) | 12--20 |

---

## External Monitoring Integration

### Prometheus / Grafana

Tileserver-gl does not expose a Prometheus metrics endpoint natively. Use a sidecar or reverse proxy metrics:

```yaml
# Example: nginx exporter for tile request metrics
services:
  nginx:
    image: nginx:alpine
    # ... proxy config with metrics
  nginx-exporter:
    image: nginx/nginx-prometheus-exporter:latest
    command: ["-nginx.scrape-uri", "http://nginx/status"]
```

### Uptime Monitoring

Point any HTTP uptime monitor (Uptime Kuma, Pingdom, Healthchecks.io) at:

```
http://your-server:8080/health
```

Expected: HTTP 200 with body `{"status":"ok"}`.

### Docker Events

Monitor container lifecycle events:

```bash
docker events --filter container=tileserver --filter event=health_status
```

---

## Related Pages

- [Operations & Maintenance](08-OPERATIONS.md) -- parent page
- [Troubleshooting Guide](08b-TROUBLESHOOTING.md) -- resolving issues found during monitoring
- [Performance Tuning](08c-PERFORMANCE.md) -- optimizing metrics observed during monitoring
- [Docker Deployment](03a-DOCKER-SETUP.md) -- Docker Compose configuration

---

*[Home](INDEX.md) | [Operations](08-OPERATIONS.md) | [Troubleshooting](08b-TROUBLESHOOTING.md) | [Performance](08c-PERFORMANCE.md) | [Backup](08d-BACKUP-RESTORE.md)*
