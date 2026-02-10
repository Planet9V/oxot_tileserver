# Changelog

> **Last Updated**: 2026-02-11 02:00 UTC

[Home](INDEX.md)

---

All notable changes to the OXOT Tileserver project and its documentation are recorded in this file. The format follows [Keep a Changelog](https://keepachangelog.com/en/1.1.0/). This project uses [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

---

## v1.1.0 -- 2026-02-11

### Added

- Section 13: Use Cases & Implementation (12 new pages)
- 8 use case categories: Cyber Attack Mapping, IP Geolocation, Facility Location, Socioeconomic Analysis, Geopolitical Events, Natural Hazards, Supply Chain, Simulation
- Enhanced glossary with 25+ new terms
- Added 25+ APA citations for use case data sources
- Updated manifest to v1.1.0

---

## v1.0.0 -- 2026-02-11

### Added

- Initial release of the OXOT Tileserver
- 21 data sources cataloged across 4 infrastructure domains (electric grid, water, demographics, telecoms)
- 5 installation options (A through E) scaling from 2 GB basemap-only to 40 GB full dataset
- Two-container Docker architecture (tileserver-gl runtime + converter tools)
- Automated data pipeline: download, extract, convert, load, verify
- 3 default styles: infrastructure (color-coded by domain), basemap-light, basemap-dark
- REST API serving TileJSON metadata, vector tiles (PBF), style JSON, and raster previews
- Full documentation wiki with 50+ pages covering all system aspects
- Support for 3 geographic regions: North America, Europe, Australia/New Zealand
- MapLibre GL JS, Leaflet, and OpenLayers integration guides
- Custom tile creation pipeline for per-customer facility layers
- Equipment and fixed asset layer generation from OXOT BOM data
- OXOT Cyber Digital Twin integration documentation
- Health monitoring endpoint and operational troubleshooting guide
- Backup and restore procedures for data and configuration
- Glossary of 100+ domain terms
- APA-formatted references and citations for all data sources

---

*[Home](INDEX.md)*
