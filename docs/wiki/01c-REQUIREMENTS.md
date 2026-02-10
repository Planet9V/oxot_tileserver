# System Requirements

> **Last Updated**: 2026-02-11 01:00 UTC

[Home](INDEX.md) > [System Overview](01-OVERVIEW.md) > System Requirements

---

## Overview

This page documents the hardware, software, disk space, and network requirements for deploying the OXOT Tileserver. Requirements vary significantly depending on which installation option you choose (A through E). Start with the minimum requirements and scale up based on your selected option.

---

## Software Prerequisites

| Software | Minimum Version | Required For | Notes |
|----------|----------------|--------------|-------|
| **Docker Engine** | 24.0+ | All operations | Or Docker Desktop 4.25+ on macOS/Windows |
| **Docker Compose** | 2.20+ | Service orchestration | Included with Docker Desktop; install separately on Linux |
| **Git** | 2.30+ | Cloning the repository | Optional if downloading as archive |
| **bash** | 4.0+ | Running pipeline scripts | macOS ships bash 3.2; use Docker converter instead |

No other software is required on the host machine. All geospatial tools (tippecanoe, osmium, GDAL) run inside the converter container.

---

## Hardware Requirements by Installation Option

### Option A: Basemap Only

| Resource | Minimum | Recommended |
|----------|---------|-------------|
| **CPU** | 2 cores | 4 cores |
| **RAM** | 1 GB | 2 GB |
| **Disk (raw download)** | 2 GB | 3 GB |
| **Disk (tiles)** | 500 MB | 1 GB |
| **Disk (total)** | 3 GB | 5 GB |

Suitable for development, UI prototyping, and testing integration with map clients.

### Option B: Basemap + One Region

| Resource | Minimum | Recommended |
|----------|---------|-------------|
| **CPU** | 2 cores | 4 cores |
| **RAM** | 2 GB | 4 GB |
| **Disk (raw download)** | 5 GB | 8 GB |
| **Disk (tiles)** | 2 GB | 3 GB |
| **Disk (total)** | 8 GB | 12 GB |

Suitable for single-country deployments (e.g., US-only or Europe-only).

### Option C: Basemap + One Domain (All Regions)

| Resource | Minimum | Recommended |
|----------|---------|-------------|
| **CPU** | 4 cores | 8 cores |
| **RAM** | 4 GB | 8 GB |
| **Disk (raw download)** | 8 GB | 12 GB |
| **Disk (tiles)** | 3 GB | 5 GB |
| **Disk (total)** | 12 GB | 18 GB |

Suitable for domain-specific analysis (e.g., electric grid across all target regions).

### Option D: Basemap + Multiple Domains and Regions

| Resource | Minimum | Recommended |
|----------|---------|-------------|
| **CPU** | 4 cores | 8 cores |
| **RAM** | 4 GB | 8 GB |
| **Disk (raw download)** | 15 GB | 25 GB |
| **Disk (tiles)** | 6 GB | 10 GB |
| **Disk (total)** | 22 GB | 35 GB |

Suitable for multi-domain operational deployments.

### Option E: Full Dataset (All Sources, All Regions)

| Resource | Minimum | Recommended |
|----------|---------|-------------|
| **CPU** | 4 cores | 8+ cores |
| **RAM** | 8 GB | 16 GB |
| **Disk (raw download)** | 25 GB | 40 GB |
| **Disk (tiles)** | 8 GB | 15 GB |
| **Disk (total)** | 35 GB | 60 GB |

Suitable for complete infrastructure visualization across all regions and domains.

---

## Disk Space Breakdown by Source

The following table estimates raw download size for each data source. Actual sizes vary by version and update cycle.

| Source | Raw Size | Tile Size | Update Frequency |
|--------|----------|-----------|-----------------|
| OpenStreetMap (regional PBF) | 2-15 GB | 500 MB-2 GB | Weekly |
| Natural Earth | 250 MB | 100 MB | Annual |
| US Census TIGER/Line | 1.5 GB | 400 MB | Annual |
| US Census ACS | 200 MB | 50 MB | Annual |
| Eurostat NUTS / Nuts2json | 100 MB | 30 MB | Annual |
| ABS Census Boundaries | 300 MB | 80 MB | 5-yearly |
| Stats NZ Boundaries | 150 MB | 40 MB | 5-yearly |
| GeoNames | 350 MB | 50 MB | Monthly |
| EIA Energy Atlas | 500 MB | 150 MB | Quarterly |
| HIFLD | 400 MB | 120 MB | Quarterly |
| ENTSO-E / GridKit | 200 MB | 60 MB | Annual |
| Geoscience Australia | 300 MB | 80 MB | Annual |
| EPA SDWIS | 100 MB | 30 MB | Quarterly |
| EPA WATERS | 800 MB | 200 MB | Annual |
| EEA WISE | 250 MB | 70 MB | Annual |
| NID (Dams) | 50 MB | 15 MB | Annual |
| BoM Australia Water | 200 MB | 50 MB | Annual |

---

## Network Requirements

### Download Bandwidth

Data downloads are the most network-intensive operation. Estimates for a full Option E download:

| Metric | Value |
|--------|-------|
| **Total download size** | 25-40 GB |
| **Estimated time at 100 Mbps** | 35-55 minutes |
| **Estimated time at 10 Mbps** | 6-9 hours |
| **Concurrent connections** | 1-3 per source (rate-limit respectful) |

Downloads are resumable. If interrupted, re-running `download.sh` continues from where it left off.

### Runtime Network

At runtime, the tileserver requires no outbound internet access. All data is local. Inbound access to port 8080 (configurable) is needed for clients to request tiles.

| Metric | Value |
|--------|-------|
| **Inbound port** | 8080 (configurable via `TILESERVER_PORT`) |
| **Outbound connections** | None required at runtime |
| **Tile response size** | 10-200 KB per tile (typical) |
| **TileJSON response size** | 2-5 KB |

---

## Optional: Census API Key

To download American Community Survey (ACS) demographic variables with the US Census data, you need a free Census API key. This is optional -- the system works without it, but ACS population and income data will not be included.

To obtain a key:

1. Visit https://api.census.gov/data/key_signup.html
2. Fill in name and organization
3. Receive key via email (usually within minutes)
4. Set `CENSUS_API_KEY=<your-key>` in your `.env` file

---

## Operating System Compatibility

| OS | Supported | Notes |
|----|-----------|-------|
| **Linux** (Ubuntu 22.04+, Debian 12+, RHEL 9+) | Full support | Primary target platform |
| **macOS** (13 Ventura+) | Full support | Via Docker Desktop; converter scripts run in container |
| **Windows** (10/11 with WSL2) | Full support | Via Docker Desktop with WSL2 backend |
| **Air-gapped / restricted networks** | Supported | Pre-pull Docker images; pre-download data on connected machine |

For air-gapped deployments, see [Environment Configuration](03d-ENVIRONMENT.md) for instructions on pre-staging Docker images and data files.

---

## Resource Monitoring

During data conversion (the most resource-intensive phase), monitor:

| Metric | Healthy Range | Action if Exceeded |
|--------|--------------|-------------------|
| **CPU usage** | <90% sustained | Reduce tippecanoe parallelism (`-P` flag) |
| **RAM usage** | <85% of available | Process sources sequentially rather than in parallel |
| **Disk I/O** | <80% of throughput | Use SSD instead of HDD; reduce concurrent writes |
| **Disk space** | >20% free | Delete `data/raw/` after successful conversion |

The converter container does not limit its own resource usage by default. To constrain it, add `deploy.resources.limits` to the Docker Compose service definition. See [Performance Tuning](08c-PERFORMANCE.md).

---

## Next Steps

- [Installation & Setup](03-INSTALLATION.md) -- begin the deployment process
- [Installation Options A-E](03b-OPTIONS.md) -- choose your installation profile
- [Architecture & Components](01a-ARCHITECTURE.md) -- understand the system design

---

*[Home](INDEX.md) > [System Overview](01-OVERVIEW.md) > System Requirements*
