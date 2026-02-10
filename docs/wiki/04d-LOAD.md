# Loading and Verification

> **Last Updated**: 2026-02-11 01:00 UTC

[Home](INDEX.md) · [Pipeline](04-PIPELINE.md) · Loading and Verification

---

## Overview

The `scripts/load.sh` script is the fourth and final stage of the pipeline. It validates all tile files in `data/tiles/`, restarts the tileserver container, waits for the healthcheck to pass, and queries the tileserver to confirm that all tilesets are available.

This script should be run from the host machine (not inside the converter container) because it needs access to Docker Compose to restart the tileserver service.

---

## Usage

```bash
# Standard: validate, restart, verify
./scripts/load.sh

# Custom port
./scripts/load.sh --port 9090

# Validate only (no restart)
./scripts/load.sh --no-restart

# Show help
./scripts/load.sh --help
```

---

## What Load Does

### Step 1: Tile File Validation

The script scans `data/tiles/` for all `.mbtiles` and `.pmtiles` files. For each file it reports the filename, size, and status (OK or EMPTY).

```
  FILE                                          SIZE         STATUS
  ----                                          ----         ------
  europe.pmtiles                                1 GiB        OK
  north-america.pmtiles                         890 MiB      OK
  osm-infrastructure.mbtiles                    234 MiB      OK
  demographics-us.mbtiles                       156 MiB      OK
  geonames-cities.mbtiles                       12 MiB       OK
```

If no tile files are found, the script exits with an error and suggests running `download.sh` and `convert.sh` first. Empty (0-byte) files are flagged with a warning.

### Step 2: Tileserver Restart

The script detects whether Docker Compose v2 (`docker compose`) or v1 (`docker-compose`) is available and runs:

```bash
docker compose restart tileserver
```

This triggers tileserver-gl to re-scan its data directory and discover any new or updated tile files.

Skip this step with `--no-restart` if you only want to validate files without restarting the service.

### Step 3: Health Check Polling

After restarting, the script polls `http://localhost:{port}/health` every 3 seconds, waiting up to 60 seconds for a successful response.

```
[INFO] Waiting for tileserver health check at http://localhost:8080/health ...
[INFO] Tileserver is healthy after 6s.
```

If the healthcheck does not pass within 60 seconds, the script exits with an error and suggests checking container logs:

```bash
docker compose logs tileserver
```

### Step 4: Tileset Listing

Once healthy, the script queries `http://localhost:{port}/index.json` and lists all available tilesets by name.

```
[INFO] === Available Tilesets ===
  europe: europe
  north-america: north-america
  osm-infrastructure: osm-infrastructure
  demographics-us: demographics-us
  geonames-cities: geonames-cities

[INFO] Tileserver URL: http://localhost:8080
[INFO] Tile endpoint:  http://localhost:8080/data/{tileset}/{z}/{x}/{y}.pbf
[INFO] TileJSON:       http://localhost:8080/data/{tileset}.json
[INFO] Viewer:         http://localhost:8080/
```

---

## Verifying Tiles Manually

### Check the index

```bash
curl -s http://localhost:8080/index.json | jq .
```

### Check a specific tileset's TileJSON metadata

```bash
curl -s http://localhost:8080/data/osm-infrastructure.json | jq .
```

This returns the TileJSON metadata including bounds, min/max zoom, and available layers.

### Request a specific tile

```bash
curl -sf http://localhost:8080/data/osm-infrastructure/8/131/85.pbf -o /dev/null && echo "OK" || echo "FAIL"
```

Replace the z/x/y coordinates with values within the tileset's bounds and zoom range.

### Open the built-in viewer

Navigate to `http://localhost:8080` in a browser. Tileserver-gl provides an interactive map viewer for each tileset and style.

---

## Troubleshooting Failed Loads

| Symptom | Cause | Solution |
|---|---|---|
| "No tile files found" | Pipeline stages not run | Run `download.sh` and `convert.sh` first |
| Empty (0 byte) tile files | Conversion failed silently | Check `convert.sh` output logs; re-run with `--force` |
| Health check timeout | Tileserver container crashed | Run `docker compose logs tileserver` for error details |
| Tileset missing from index.json | File not in `data/tiles/` or wrong extension | Verify file exists and is `.mbtiles` or `.pmtiles` |
| "Neither docker compose nor docker-compose found" | Docker not installed or not in PATH | Install Docker Desktop or add docker to PATH |
| Tileserver shows old data | Container cached old files | Run `docker compose restart tileserver` or `load.sh` |

### Checking container status

```bash
# Is the tileserver running?
docker compose ps tileserver

# What is the health status?
docker inspect --format='{{.State.Health.Status}}' \
  $(docker compose ps -q tileserver)

# View recent logs
docker compose logs --tail 50 tileserver
```

---

## Configuration Reference

`load.sh` respects these configuration values:

| Setting | Source | Default |
|---|---|---|
| Tileserver port | `--port` flag or `TILESERVER_PORT` env var | `8080` |
| Health check timeout | Hardcoded in script | 60 seconds |
| Health check interval | Hardcoded in script | 3 seconds |
| Tiles directory | `TILES_DIR` or script default | `data/tiles/` |

---

## Related Pages

- [Pipeline](04-PIPELINE.md) -- parent page with pipeline overview
- [Conversion and Tippecanoe](04c-CONVERT.md) -- previous stage: creating tile files
- [Updates and Scheduling](04e-MAINTENANCE.md) -- automated refresh pipeline
- [Docker Deployment](03a-DOCKER-SETUP.md) -- container architecture and healthcheck
- [REST API Endpoints](05a-REST-ENDPOINTS.md) -- tileserver HTTP API reference

---

*[Back to Pipeline](04-PIPELINE.md)*
