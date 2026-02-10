# Installation and Setup

> **Last Updated**: 2026-02-11 01:00 UTC

[Home](INDEX.md) · Installation and Setup

---

## Overview

This section covers everything required to deploy the OXOT Tileserver, from prerequisites through a running tileserver with loaded tiles. The system uses a two-container Docker architecture: a runtime **tileserver** serving vector tiles, and a **converter** container with all the geospatial processing tools needed to download and transform raw data into tiles.

Choose an installation path based on your use case, available disk space, and the geographic regions you need to cover. The five pre-configured options range from a lightweight demo deployment (~5 GB) to a full multi-region deployment (~22 GB).

---

## Prerequisites Checklist

Before you begin, confirm that the following are available on the host machine.

| Requirement | Minimum | Recommended | Check Command |
|---|---|---|---|
| Docker Engine | 20.10+ | 24.0+ | `docker --version` |
| Docker Compose | v2.0+ | v2.20+ | `docker compose version` |
| Git | 2.30+ | 2.40+ | `git --version` |
| Free disk space | 10 GB | 50 GB | `df -h .` |
| RAM | 4 GB | 8 GB | `free -h` or Activity Monitor |
| Internet | Required for download | Broadband recommended | -- |

Docker Desktop for macOS or Windows includes both Docker Engine and Docker Compose. On Linux, install them separately if needed.

---

## Quick Start

Complete these four steps to have a running tileserver. For the fastest path, use Option A (Quick Start) which downloads approximately 5 GB and finishes in about 40 minutes.

### Step 1 -- Clone and configure

```bash
git clone <repository-url> oxot_tileserver
cd oxot_tileserver
cp .env.example .env
```

Edit `.env` if you need to change the default port (8080) or set a Census API key. See [Environment Configuration](03d-ENVIRONMENT.md) for details.

### Step 2 -- Build the converter container

```bash
docker compose build
```

This builds the converter image from `Dockerfile.converter`. The tileserver image (`maptiler/tileserver-gl`) is pulled from Docker Hub automatically.

### Step 3 -- Download and convert data

```bash
./options/option-a.sh
```

This runs the full pipeline for Option A: download, convert, and load. See [Installation Options A-E](03b-OPTIONS.md) for other choices.

### Step 4 -- Verify

```bash
curl http://localhost:8080/health
curl http://localhost:8080/index.json
```

Open `http://localhost:8080` in a browser to access the built-in tile viewer.

---

## Child Pages

| Page | Description |
|---|---|
| [Docker Deployment](03a-DOCKER-SETUP.md) | `docker-compose.yml` structure, services, volumes, networking |
| [Installation Options A-E](03b-OPTIONS.md) | Five installation profiles by scope, size, and use case |
| [Converter Container](03c-CONVERTER.md) | `Dockerfile.converter` breakdown, installed tools, usage |
| [Environment Configuration](03d-ENVIRONMENT.md) | `.env.example` field-by-field reference |

---

## Option Decision Matrix

Use this matrix to choose the right installation option for your situation.

| If you need... | Choose | Size | Time |
|---|---|---|---|
| A quick demo with global basemap | [Option A](03b-OPTIONS.md#option-a-quick-start) | ~5 GB | ~40 min |
| US-only CISA sector analysis | [Option B](03b-OPTIONS.md#option-b-us-federal-authority) | ~10 GB | ~3 hrs |
| Global basemap + US infrastructure detail | [Option C](03b-OPTIONS.md#option-c-modern--comprehensive) | ~16 GB | ~5 hrs |
| Fastest path to US CISA/HIFLD data | [Option D](03b-OPTIONS.md#option-d-minimum-viable-oxot) | ~8 GB | ~1.5 hrs |
| Full 3-region production deployment | [Option E](03b-OPTIONS.md#option-e-multi-region-full) | ~22 GB | ~6 hrs |

Options are additive. You can start with Option D and later add Option A sources to gain a basemap without re-downloading existing data.

---

## Next Steps

After installation is complete, proceed to:

- [Data Pipeline](04-PIPELINE.md) -- understand the download-extract-convert-load workflow
- [API Reference](05-API.md) -- query the tileserver REST API
- [Application Integration](06-INTEGRATION.md) -- connect MapLibre or other map clients

---

*[Back to Home](INDEX.md)*
