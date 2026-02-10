# Operations & Maintenance

> **Last Updated**: 2026-02-11 01:00 UTC

[Home](INDEX.md)

---

## Overview

This section covers the operational aspects of running the OXOT Tileserver in a production or long-running deployment. It addresses health monitoring, troubleshooting common issues, performance optimization, and backup/restore procedures.

The tileserver is designed to be low-maintenance once deployed. The primary runtime service (tileserver-gl) reads tile files from disk and serves them over HTTP. There are no databases to manage, no write operations during normal operation, and no background jobs. Operational concerns center on monitoring availability, managing disk space, and updating tile data periodically.

---

## System Health at a Glance

| Check | Command | Expected |
|-------|---------|----------|
| Container running | `docker compose ps tileserver` | Status: `Up` |
| Health endpoint | `curl -s http://localhost:8080/health` | `{"status":"ok"}` |
| Tileset count | `curl -s http://localhost:8080/index.json \| jq '.tilesets \| length'` | >= 1 |
| Disk usage | `du -sh data/tiles/` | Varies by install option |
| Memory usage | `docker stats tileserver --no-stream` | Typically < 512 MB |

---

## Key Operational Concerns

### Disk Space

Tile files are the largest assets. Monitor `data/tiles/` for unexpected growth, especially after conversion runs. Raw data in `data/raw/` can be deleted after successful conversion to reclaim space.

### Tile Freshness

Source data (OSM, EIA, EPA, etc.) is updated on varying schedules. See [Updates & Scheduling](04e-MAINTENANCE.md) for cron-based refresh automation.

### Container Updates

The tileserver-gl Docker image is updated periodically by the MapTiler team. Pin versions in production and test upgrades in staging before promoting.

### Log Volume

Tileserver-gl logs every tile request at the default log level. In high-traffic environments, configure log rotation or reduce verbosity.

---

## Children Pages

| Page | Description |
|------|-------------|
| [Health & Monitoring](08a-MONITORING.md) | Health endpoint, Docker healthcheck, log inspection, alerting |
| [Troubleshooting Guide](08b-TROUBLESHOOTING.md) | Symptom-to-solution lookup for common issues |
| [Performance Tuning](08c-PERFORMANCE.md) | Tippecanoe optimization, caching, reverse proxy, CDN |
| [Backup & Restore](08d-BACKUP-RESTORE.md) | Backup procedures, restore steps, versioning strategy |

---

## Next Steps

- **Is the tileserver running?** Check [Health & Monitoring](08a-MONITORING.md).
- **Something broken?** See [Troubleshooting Guide](08b-TROUBLESHOOTING.md).
- **Tiles loading slowly?** Review [Performance Tuning](08c-PERFORMANCE.md).
- **Need to back up before an upgrade?** Follow [Backup & Restore](08d-BACKUP-RESTORE.md).

---

*[Home](INDEX.md) | [Monitoring](08a-MONITORING.md) | [Troubleshooting](08b-TROUBLESHOOTING.md) | [Performance](08c-PERFORMANCE.md) | [Backup](08d-BACKUP-RESTORE.md)*
