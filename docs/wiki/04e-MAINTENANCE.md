# Updates and Scheduling

> **Last Updated**: 2026-02-11 01:00 UTC

[Home](INDEX.md) · [Pipeline](04-PIPELINE.md) · Updates and Scheduling

---

## Overview

The `scripts/update.sh` script re-runs the full pipeline (download, convert, load) for specified sources. It is designed for periodic data refreshes after the initial installation. All operations are logged with timestamps to `data/update.log`.

---

## Usage

```bash
# Update a single source
./scripts/update.sh --source osm-infrastructure

# Update all sources for an option
./scripts/update.sh --option e

# Update multiple sources
./scripts/update.sh --source basemap --source geonames

# Re-convert and reload without re-downloading
./scripts/update.sh --source census-us --skip-download

# Re-download and reload without re-converting
./scripts/update.sh --source osm-infrastructure --skip-convert

# Show help
./scripts/update.sh --help
```

Inside the converter container:

```bash
/scripts/update.sh --source osm-infrastructure
```

---

## What Update Does

The update script runs three sub-scripts in sequence:

1. **Download** (`download.sh`) -- Re-downloads source data. Existing files are overwritten because `wget -c` resumes; to get fresh data, delete existing files first or the download will skip them.
2. **Convert** (`convert.sh --force`) -- Re-converts data to tiles. The `--force` flag is added automatically so that existing tile files are overwritten with fresh conversions.
3. **Load** (`load.sh`) -- Validates tiles, restarts the tileserver, and verifies availability.

Each step is timed and the duration is logged. If a step fails, the pipeline continues to the next step (best-effort) and reports the failure count at the end.

---

## Timestamped Logging

All output is written to both the terminal and `data/update.log` with timestamps:

```
[INFO] 2026-02-11 02:00:15 ========================================
[INFO] 2026-02-11 02:00:15 OXOT Tileserver Update Pipeline
[INFO] 2026-02-11 02:00:15 Updating: sources: osm-infrastructure
[INFO] 2026-02-11 02:00:15 ========================================
[INFO] 2026-02-11 02:00:15 --- Step 1/3: Downloading data ---
...
[INFO] 2026-02-11 02:35:42 Download completed in 35m 27s
[INFO] 2026-02-11 02:35:42 --- Step 2/3: Converting data ---
...
[INFO] 2026-02-11 03:10:18 Conversion completed in 34m 36s
[INFO] 2026-02-11 03:10:18 --- Step 3/3: Loading tiles into tileserver ---
...
[INFO] 2026-02-11 03:10:45 Full update pipeline completed in 70m 30s
```

---

## Cron Schedule Recommendations

Different data sources have different update cadences based on how frequently the upstream providers refresh their data.

### Weekly: OSM Infrastructure

OpenStreetMap data on Geofabrik is updated daily. A weekly refresh captures community edits without excessive processing.

```cron
# Every Sunday at 2:00 AM
0 2 * * 0 cd /path/to/oxot_tileserver && docker compose --profile tools run converter /scripts/update.sh --source osm-infrastructure >> data/cron.log 2>&1
```

### Monthly: Basemap

The Protomaps basemap is rebuilt daily but changes slowly in aggregate. Monthly updates keep the basemap reasonably current.

```cron
# 1st of every month at 3:00 AM
0 3 1 * * cd /path/to/oxot_tileserver && docker compose --profile tools run converter /scripts/update.sh --source basemap >> data/cron.log 2>&1
```

### Quarterly: HIFLD, EIA, NID, EPA

Federal datasets are updated on a quarterly or annual basis. Quarterly checks catch incremental updates.

```cron
# 1st of January, April, July, October at 4:00 AM
0 4 1 1,4,7,10 * cd /path/to/oxot_tileserver && docker compose --profile tools run converter /scripts/update.sh --source hifld-infrastructure --source eia-powerplants >> data/cron.log 2>&1
```

For NID and EPA (manual downloads), the cron job runs but the download step prints instructions. Check `data/update.log` for manual action items.

### Annually: Census Demographics

The US Census Bureau releases TIGER/Line updates annually (typically in Q1). Eurostat and ABS follow similar annual cycles.

```cron
# January 15 at 5:00 AM
0 5 15 1 * cd /path/to/oxot_tileserver && docker compose --profile tools run converter /scripts/update.sh --source census-us --source eurostat >> data/cron.log 2>&1
```

### Summary Schedule

| Source | Frequency | Recommended Day/Time |
|---|---|---|
| OSM Infrastructure | Weekly | Sunday 02:00 |
| Basemap (Protomaps) | Monthly | 1st of month 03:00 |
| GeoNames | Monthly | 1st of month 03:30 |
| HIFLD Infrastructure | Quarterly | 1st of Jan/Apr/Jul/Oct 04:00 |
| EIA Power Plants | Quarterly | 1st of Jan/Apr/Jul/Oct 04:00 |
| NID Dams | Quarterly (manual) | Check log quarterly |
| EPA Water | Quarterly (manual) | Check log quarterly |
| Census TIGER/Line | Annually | January 15 05:00 |
| Eurostat NUTS | Annually | January 15 05:00 |
| ABS Australia | Annually (manual) | Check log annually |
| Natural Earth | Annually | January 15 05:30 |

---

## Monitoring Update Health

### Check the log file

```bash
tail -50 data/update.log
```

### Look for failures

```bash
grep -c "ERROR" data/update.log
grep "failure" data/update.log
```

### Check last update time per source

```bash
grep "complete" data/update.log | tail -20
```

### Verify tileserver is serving current data

```bash
curl -s http://localhost:8080/index.json | jq 'keys'
```

---

## Rollback Strategy

The update script does not automatically back up previous tile files before overwriting. To enable rollback, implement a manual backup step before running updates.

### Pre-update backup

```bash
# Create a timestamped backup directory
BACKUP_DIR="data/backups/$(date +%Y%m%d_%H%M%S)"
mkdir -p "$BACKUP_DIR"
cp data/tiles/*.mbtiles data/tiles/*.pmtiles "$BACKUP_DIR/"
```

### Rolling back

```bash
# Restore from backup
cp data/backups/20260211_020000/*.mbtiles data/tiles/
cp data/backups/20260211_020000/*.pmtiles data/tiles/
docker compose restart tileserver
```

### Automated backup in cron

```cron
# Backup before weekly OSM update
55 1 * * 0 BACKUP="data/backups/$(date +\%Y\%m\%d)" && mkdir -p "$BACKUP" && cp data/tiles/* "$BACKUP/"
0  2 * * 0 cd /path/to/oxot_tileserver && docker compose --profile tools run converter /scripts/update.sh --source osm-infrastructure
```

### Retention policy

Keep the two most recent backups and delete older ones to manage disk space:

```bash
# Keep only the 2 newest backup directories
ls -dt data/backups/*/ | tail -n +3 | xargs rm -rf
```

---

## Skipping Pipeline Steps

The `--skip-download` and `--skip-convert` flags allow partial pipeline runs:

| Flag | Effect | Use Case |
|---|---|---|
| (none) | Full pipeline: download + convert + load | Standard refresh |
| `--skip-download` | Convert + load only | Reprocess existing raw data with new tippecanoe settings |
| `--skip-convert` | Download + load only | Refresh raw data without regenerating tiles |

Both flags can be combined (`--skip-download --skip-convert`) to run only the load step, which validates tiles and restarts the tileserver.

---

## Related Pages

- [Pipeline](04-PIPELINE.md) -- parent page with pipeline overview
- [Loading and Verification](04d-LOAD.md) -- the load step in detail
- [Download Scripts](04a-DOWNLOAD.md) -- how re-downloads work
- [Health and Monitoring](08a-MONITORING.md) -- tileserver health monitoring
- [Backup and Restore](08d-BACKUP-RESTORE.md) -- comprehensive backup procedures

---

*[Back to Pipeline](04-PIPELINE.md)*
