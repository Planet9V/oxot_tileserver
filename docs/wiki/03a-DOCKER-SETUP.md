# Docker Deployment

> **Last Updated**: 2026-02-11 01:00 UTC

[Home](INDEX.md) · [Installation](03-INSTALLATION.md) · Docker Deployment

---

## Overview

The OXOT Tileserver runs as a two-service Docker Compose application. The **tileserver** service runs continuously and serves vector tiles. The **converter** service is an on-demand tools container used to download, extract, and convert geospatial data. It does not run by default.

---

## docker-compose.yml Structure

The compose file defines two services with no external dependencies beyond Docker itself.

```yaml
services:
  tileserver:
    image: maptiler/tileserver-gl
    ports:
      - "${TILESERVER_PORT:-8080}:8080"
    volumes:
      - ./data/tiles:/data
      - ./config/tileserver-config.json:/data/config.json:ro
      - ./styles:/data/styles:ro
    restart: unless-stopped
    healthcheck:
      test: ["CMD", "wget", "--spider", "-q", "http://localhost:8080/health"]
      interval: 30s
      timeout: 10s
      retries: 3

  converter:
    build:
      context: .
      dockerfile: Dockerfile.converter
    volumes:
      - ./data:/data
      - ./scripts:/scripts:ro
      - ./sources:/sources:ro
      - ./config:/config:ro
    environment:
      - REGIONS=${REGIONS:-europe,north-america,australia-oceania}
    profiles:
      - tools
    stdin_open: true
    tty: true
```

---

## Tileserver Service

The tileserver uses the official `maptiler/tileserver-gl` Docker image.

### Port Mapping

The container listens on port 8080 internally. The host port is configurable through the `TILESERVER_PORT` environment variable, defaulting to 8080.

```
Host port (configurable) --> Container port 8080
```

### Volume Mounts

| Host Path | Container Path | Mode | Purpose |
|---|---|---|---|
| `./data/tiles` | `/data` | read-write | MBTiles and PMTiles tile files |
| `./config/tileserver-config.json` | `/data/config.json` | read-only | Tileserver configuration |
| `./styles` | `/data/styles` | read-only | MapLibre GL style JSON files |

The `data/tiles` directory is where converted tile files are placed by the pipeline. Tileserver-gl discovers all `.mbtiles` and `.pmtiles` files in `/data` and serves them automatically. The `config.json` file provides explicit tileset declarations and style assignments.

### Healthcheck

The built-in healthcheck hits the `/health` endpoint every 30 seconds with a 10-second timeout. After 3 consecutive failures, Docker marks the container as unhealthy. The `unless-stopped` restart policy ensures the service recovers from crashes.

### Starting the Tileserver

```bash
docker compose up -d
```

This starts only the tileserver service. The converter service is excluded because it uses the `tools` profile.

### Viewing Logs

```bash
docker compose logs -f tileserver
```

---

## Converter Service

The converter is a custom image built from `Dockerfile.converter`. It contains all the tools needed to download raw geospatial data, filter and extract features, and convert them to vector tiles.

### Profile: tools

The converter uses the Docker Compose `profiles` feature with the `tools` profile. It does not start with a regular `docker compose up`. You must explicitly request the profile.

### Volume Mounts

| Host Path | Container Path | Mode | Purpose |
|---|---|---|---|
| `./data` | `/data` | read-write | Raw downloads, work files, and output tiles |
| `./scripts` | `/scripts` | read-only | Pipeline scripts (download, extract, convert, load) |
| `./sources` | `/sources` | read-only | Source configuration files |
| `./config` | `/config` | read-only | Environment and tileserver configuration |

The converter mounts the entire `./data` directory, not just `./data/tiles`. This gives it access to `data/raw/` (downloads), `data/work/` (intermediates), and `data/tiles/` (output).

### Environment Variables

The `REGIONS` variable is passed from the host `.env` file and defaults to `europe,north-america,australia-oceania`. Scripts inside the converter use this to determine which geographic regions to process.

### Entering the Converter Shell

```bash
docker compose --profile tools run converter bash
```

This drops you into an interactive bash shell inside the converter container at the `/data` working directory. From here you can run any pipeline script:

```bash
/scripts/download.sh --source basemap
/scripts/extract-osm.sh
/scripts/convert.sh --source osm-infrastructure
```

### Running a Single Command

To run a script without entering an interactive shell:

```bash
docker compose --profile tools run converter /scripts/download.sh --option a
```

### Building the Converter Image

```bash
docker compose --profile tools build converter
```

Rebuild after modifying `Dockerfile.converter`. See [Converter Container](03c-CONVERTER.md) for the full Dockerfile breakdown.

---

## Volume Layout

The following directory tree shows how host directories map into both containers.

```
Host filesystem                   tileserver (/data)   converter (/data)
---------------------------------+-----------------+------------------
./data/tiles/                     /data/             /data/tiles/
./data/raw/                       --                 /data/raw/
./data/work/                      --                 /data/work/
./config/tileserver-config.json   /data/config.json  /config/tileserver-config.json
./styles/                         /data/styles/      --
./scripts/                        --                 /scripts/
./sources/                        --                 /sources/
```

The tileserver only sees the `tiles` subdirectory (mounted at `/data`). The converter sees the full `data` tree.

---

## Networking

Both services share the default Docker Compose network. The converter can reach the tileserver by its service name:

```bash
# From inside the converter container
curl http://tileserver:8080/health
```

This is used by `load.sh` when verifying that tiles are served correctly after a restart.

---

## Common Operations

### Start tileserver only (default)

```bash
docker compose up -d
```

### Stop everything

```bash
docker compose down
```

### Rebuild converter after Dockerfile changes

```bash
docker compose --profile tools build converter
```

### View tileserver health status

```bash
docker inspect --format='{{.State.Health.Status}}' \
  $(docker compose ps -q tileserver)
```

### Pull latest tileserver-gl image

```bash
docker compose pull tileserver
docker compose up -d tileserver
```

---

## Related Pages

- [Installation](03-INSTALLATION.md) -- parent page with quick start
- [Converter Container](03c-CONVERTER.md) -- Dockerfile breakdown and tool inventory
- [Environment Configuration](03d-ENVIRONMENT.md) -- `.env` variable reference
- [Loading and Verification](04d-LOAD.md) -- post-conversion tile loading

---

*[Back to Installation](03-INSTALLATION.md)*
