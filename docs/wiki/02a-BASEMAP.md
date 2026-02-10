> **Last Updated**: 2026-02-11 01:00 UTC

[Home](INDEX.md) > [Data Sources](02-DATA-SOURCES.md) > Basemap Sources

# Basemap Sources

The OXOT Tileserver supports three interchangeable basemap providers. Each delivers
a global vector-tile tileset containing roads, buildings, land-use, water bodies,
boundaries, and labels. Only one is required at runtime; the choice depends on
format preference (PMTiles vs MBTiles), commercial requirements, and update cadence.

---

## Comparison Table

| Attribute | Protomaps Basemap | OpenMapTiles / MapTiler | OpenFreeMap |
|-----------|-------------------|------------------------|-------------|
| **Format** | PMTiles | MBTiles | MBTiles |
| **Coverage** | Global | Global | Global |
| **Planet Size** | ~120 GB | ~80 GB | ~80 GB |
| **3-Region Extract** | ~15 GB | ~15-20 GB (manual) | ~15-20 GB (manual) |
| **Update Cadence** | Weekly | Monthly (free) / Weekly (commercial) | Weekly |
| **Schema** | Protomaps schema v4 | OpenMapTiles schema | OpenMapTiles schema |
| **License** | ODbL (data) + BSD (code) | ODbL (data) + BSD (schema) | ODbL |
| **Commercial Use** | Yes, free | Free tier limited; paid for SLA | Yes, free |
| **Bounding-Box Extract** | `pmtiles extract` CLI | Planet extract + `osmium` | Planet or regional |
| **tileserver-gl Native** | PMTiles reader plugin | Yes (MBTiles native) | Yes (MBTiles native) |
| **Best For** | Smallest custom extracts | Widest ecosystem support | Self-hosted Mapbox replacement |

---

## 1. Protomaps Basemap

**Provider**: Protomaps Project
**URL**: https://protomaps.com/downloads
**Format**: PMTiles (single-file, cloud-native)

### Description

Protomaps publishes a weekly planet build in PMTiles format. PMTiles is a
cloud-optimised archive that supports HTTP range requests, making it usable
directly from object storage (S3, GCS, R2) without a tile server. For the
OXOT Tileserver, the file can also be served through a PMTiles-aware middleware
or converted to MBTiles.

### Custom Bounding-Box Extraction

The `pmtiles` CLI enables extraction of arbitrary regions without downloading the
full planet file:

```bash
pmtiles extract \
  https://build.protomaps.com/20260210.pmtiles \
  north-america.pmtiles \
  --bbox="-130,24,-60,52"
```

This produces a self-contained PMTiles file for the specified bounding box,
typically reducing planet size by 80-90%.

### Sizing

- **Planet**: ~120 GB
- **3-Region Extract** (North America + Europe + Oceania): ~15 GB
- **Single Country** (e.g., Australia): ~1-2 GB

### License

Data licensed under the Open Data Commons Open Database License (ODbL).
Tooling licensed under BSD-3-Clause.

### Reference

Protomaps. (2026). *Protomaps basemap downloads*. https://protomaps.com/downloads

---

## 2. OpenMapTiles / MapTiler

**Provider**: MapTiler AG (open-source schema), community builds
**URL**: https://openmaptiles.org/ | https://data.maptiler.com/downloads/planet/
**Format**: MBTiles

### Description

OpenMapTiles defines the most widely adopted open vector-tile schema. The schema
is open source (BSD); MapTiler provides commercial planet downloads with SLA.
Community-built planet files are also available under ODbL. The MBTiles format
is natively supported by tileserver-gl.

### Tiers

| Tier | Planet Download | Updates | Attribution | Price |
|------|----------------|---------|-------------|-------|
| Free | Yes (with key) | Monthly | Required | $0 |
| Plus | Yes | Weekly | Optional | Subscription |
| Custom | Regional / on-demand | Daily available | Negotiable | Quote |

### Sizing

- **Planet**: ~80 GB (MBTiles, zoom 0-14)
- **Europe extract**: ~15 GB
- **Updates**: ~2-5 GB diff per month

### License

Data: ODbL. Schema: BSD-3-Clause. MapTiler commercial terms apply to hosted downloads.

### Reference

OpenMapTiles contributors. (2026). *OpenMapTiles: Open-source maps made for developers*. https://openmaptiles.org/

MapTiler AG. (2026). *MapTiler data downloads*. https://data.maptiler.com/downloads/planet/

---

## 3. OpenFreeMap

**Provider**: OpenFreeMap Project
**URL**: https://openfreemap.org/
**Format**: MBTiles

### Description

OpenFreeMap is a self-hostable Mapbox/MapLibre alternative that bundles the
OpenMapTiles schema with optimised builds for self-hosting. It focuses on
simplicity: download the MBTiles file, point tileserver-gl at it, and serve.
No API keys or usage limits.

### Key Differentiators

- No API key required for self-hosted deployments.
- Pre-configured MapLibre GL styles included.
- Optimised for tileserver-gl and Martin tile server.

### Sizing

- **Planet**: ~80 GB
- **Regional builds**: Available through Geofabrik + tippecanoe pipeline

### License

ODbL (data). MIT (styles and tooling).

### Reference

OpenFreeMap. (2026). *OpenFreeMap: Free and open vector tile hosting*. https://openfreemap.org/

---

## Selection Guidance

| Scenario | Recommended Source |
|----------|--------------------|
| Cloud deployment (S3/GCS) without tile server | Protomaps (PMTiles + range requests) |
| Standard self-hosted tileserver-gl | OpenMapTiles or OpenFreeMap (MBTiles) |
| Need smallest possible custom extract | Protomaps (`pmtiles extract` CLI) |
| Require commercial SLA and support | MapTiler (OpenMapTiles commercial tier) |
| Maximum simplicity, no API keys | OpenFreeMap |

---

## Related Pages

- **Parent**: [Data Sources](02-DATA-SOURCES.md)
- **Siblings**: [Demographics](02b-DEMOGRAPHICS.md) | [Electric](02c-ELECTRIC.md) | [Water](02d-WATER.md) | [Telecoms](02e-TELECOMS.md)
- **Pipeline**: [Conversion & Tippecanoe](04c-CONVERT.md)
- **Styles**: [Style API](05d-STYLES.md)
- **Integration**: [MapLibre GL JS](06a-MAPLIBRE.md)
