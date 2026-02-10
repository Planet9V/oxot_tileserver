# Troubleshooting Guide

> **Last Updated**: 2026-02-11 01:00 UTC

[Home](INDEX.md) > [Operations & Maintenance](08-OPERATIONS.md) > Troubleshooting Guide

---

## Overview

This page provides a symptom-to-solution lookup for common issues encountered when running the OXOT Tileserver. Each issue includes the symptom, likely cause, diagnostic steps, and resolution.

---

## Tileserver Won't Start

### Symptom

Container exits immediately or fails to reach `healthy` status.

### Diagnostic Steps

```bash
# Check container status
docker compose ps tileserver

# View startup logs
docker compose logs tileserver --tail 100
```

### Common Causes and Solutions

**Configuration file not found**

```
ERROR: Config file not found: /config/tileserver-config.json
```

Verify that the config volume mount is correct in `docker-compose.yml` and that the file exists:

```bash
ls -la config/tileserver-config.json
```

**Invalid JSON in configuration**

```
SyntaxError: Unexpected token } in JSON
```

Validate the configuration file:

```bash
cat config/tileserver-config.json | jq .
```

Fix any JSON syntax errors (trailing commas, missing quotes, unescaped characters).

**Tile file referenced but missing**

```
ERROR: MBTiles file not found: /data/nonexistent.mbtiles
```

List available tile files and compare against the configuration:

```bash
ls -la data/tiles/*.mbtiles data/tiles/*.pmtiles 2>/dev/null
cat config/tileserver-config.json | jq '.data'
```

Ensure every file referenced in the config exists in the mounted volume.

**Port already in use**

```
Error: listen EADDRINUSE: address already in use :::8080
```

Check what is using the port and either stop it or change `TILESERVER_PORT`:

```bash
lsof -i :8080
```

---

## Tiles Return 404

### Symptom

Requests to `/data/{tileset}/{z}/{x}/{y}.pbf` return HTTP 404.

### Diagnostic Steps

```bash
# Verify the tileset exists
curl -s http://localhost:8080/index.json | jq '.tilesets[].name'

# Check the exact tileset name
curl -s http://localhost:8080/data/osm-infrastructure.json
```

### Common Causes and Solutions

**Tileset name mismatch**

The tileset name in the URL must exactly match the name in `tileserver-config.json`. Names are case-sensitive.

```bash
# Wrong (hyphen vs underscore)
curl http://localhost:8080/data/osm_infrastructure/6/32/21.pbf  # 404

# Correct
curl http://localhost:8080/data/osm-infrastructure/6/32/21.pbf  # 200
```

**Coordinates out of range**

Tile coordinates must be valid for the requested zoom level. At zoom `z`, valid `x` and `y` values range from 0 to `2^z - 1`.

```bash
# Invalid: x=9999 at zoom 6 (max is 63)
curl -sI http://localhost:8080/data/osm-infrastructure/6/9999/21.pbf
```

**Tile data missing for requested area**

If the tileset covers a limited geographic area (e.g., US only), tiles outside that area return 204 (no content) or 404.

Check the tileset bounds:

```bash
curl -s http://localhost:8080/data/osm-infrastructure.json | jq '.bounds'
```

---

## Blank Tiles / Empty Map

### Symptom

The map renders but shows only the background color with no infrastructure features.

### Diagnostic Steps

```bash
# Verify tile contains data
curl -s http://localhost:8080/data/osm-infrastructure/6/32/21.pbf | wc -c
# Should be > 0 bytes for a populated area

# Check the style references the correct source-layer names
curl -s http://localhost:8080/styles/infrastructure/style.json | jq '.layers[].["source-layer"]'
```

### Common Causes and Solutions

**Wrong source-layer name**

The `source-layer` in the style must match the layer `id` inside the vector tile. Common mismatches:

| Style references | Tile actually contains | Fix |
|-----------------|----------------------|-----|
| `powerlines` | `power_lines` | Use `power_lines` (with underscore) |
| `water-treatment` | `water_treatment` | Use `water_treatment` |

Inspect layer names inside the tile:

```bash
curl -s http://localhost:8080/data/osm-infrastructure.json | jq '.vector_layers[].id'
```

**Zoom level mismatch**

Features may not be visible at the current zoom level. Each layer has a `minzoom`:

| Layer | minzoom | Visible from |
|-------|---------|-------------|
| `power_lines` | 4 | Regional view |
| `generators` | 6 | Sub-regional |
| `substations` | 8 | Metropolitan |
| `water_treatment` | 8 | Metropolitan |
| `telecom_masts` | 10 | City level |

Zoom in to verify features appear at higher zoom levels.

**Source URL wrong**

If using manual source configuration, verify the URL resolves:

```bash
curl -s http://localhost:8080/data/osm-infrastructure.json | jq '.tiles'
```

---

## Conversion Fails

### Symptom

The `converter` container exits with errors during `convert.sh`.

### Diagnostic Steps

```bash
docker compose logs converter --tail 200
```

### Common Causes and Solutions

**tippecanoe out of memory**

```
tippecanoe: Out of memory
```

Increase Docker memory allocation or reduce the dataset scope:

```bash
# In Docker Desktop: Settings > Resources > Memory > increase to 8+ GB

# Or limit tippecanoe's zoom range
tippecanoe -z12 -Z0 ...  # instead of -z14
```

**Invalid GeoJSON input**

```
tippecanoe: Invalid GeoJSON
```

Validate the input file:

```bash
cat data/extracted/power_lines.geojson | jq . > /dev/null
# If jq fails, the file has syntax errors
```

Check for truncated downloads:

```bash
wc -c data/raw/some-file.geojson
# Compare against expected size
```

**Disk space exhausted**

```
No space left on device
```

Check available space and clean up:

```bash
df -h
# Remove raw data after successful conversion
rm -rf data/raw/*
# Prune Docker images
docker system prune -f
```

---

## Download Interrupted

### Symptom

Download script fails partway through a large file.

### Resolution

Re-run the download with resume support:

```bash
# wget supports resume with -c
wget -c https://example.com/large-file.osm.pbf -O data/raw/large-file.osm.pbf

# curl supports resume with -C -
curl -C - -o data/raw/large-file.osm.pbf https://example.com/large-file.osm.pbf
```

The download scripts use `wget -c` by default. Re-running `download.sh` for a specific source will resume interrupted downloads.

---

## Docker Out of Disk

### Symptom

Docker commands fail with disk space errors.

### Resolution

```bash
# Check Docker disk usage
docker system df

# Remove unused images, containers, and volumes
docker system prune -f

# Remove dangling volumes (caution: destroys orphaned data)
docker volume prune -f

# Check if raw data can be removed
du -sh data/raw/
# If conversion is complete, raw data is safe to delete
rm -rf data/raw/*
```

---

## Style Rendering Issues

### Symptom

Raster tile endpoints (`/styles/{name}/{z}/{x}/{y}.png`) return errors or incorrect rendering.

### Diagnostic Steps

```bash
# Check style JSON validity
curl -s http://localhost:8080/styles/infrastructure/style.json | jq . > /dev/null

# Check for missing fonts
docker compose logs tileserver --tail 100 2>&1 | grep -i font

# Check for missing sprites
curl -sI http://localhost:8080/styles/infrastructure/sprite.json
```

### Common Causes and Solutions

**Missing font files**

If the style references fonts not present in the fonts directory:

```
ERROR: Font "Noto Sans Regular" not found
```

Download the required font PBFs or update the style to use available fonts.

**Broken sprite reference**

If sprite.json returns 404, verify the sprite files exist in the style directory.

---

## Diagnostic Command Reference

| Purpose | Command |
|---------|---------|
| Container status | `docker compose ps tileserver` |
| Container logs | `docker compose logs tileserver --tail 100` |
| Health check | `curl -s http://localhost:8080/health` |
| List tilesets | `curl -s http://localhost:8080/index.json \| jq .` |
| Tile file listing | `ls -lah data/tiles/` |
| Config validation | `cat config/tileserver-config.json \| jq .` |
| Style validation | `curl -s http://localhost:8080/styles/infrastructure/style.json \| jq . > /dev/null` |
| Layer names | `curl -s http://localhost:8080/data/osm-infrastructure.json \| jq '.vector_layers[].id'` |
| Disk usage | `du -sh data/tiles/ data/raw/ data/extracted/` |
| Port check | `lsof -i :8080` |
| Docker resources | `docker stats tileserver --no-stream` |

---

## Related Pages

- [Operations & Maintenance](08-OPERATIONS.md) -- parent page
- [Health & Monitoring](08a-MONITORING.md) -- proactive monitoring setup
- [Performance Tuning](08c-PERFORMANCE.md) -- optimizing slow operations
- [Data Pipeline](04-PIPELINE.md) -- understanding the conversion process
- [Environment Configuration](03d-ENVIRONMENT.md) -- configuration variables

---

*[Home](INDEX.md) | [Operations](08-OPERATIONS.md) | [Monitoring](08a-MONITORING.md) | [Performance](08c-PERFORMANCE.md) | [Backup](08d-BACKUP-RESTORE.md)*
