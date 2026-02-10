# OSM Extraction

> **Last Updated**: 2026-02-11 01:00 UTC

[Home](INDEX.md) · [Pipeline](04-PIPELINE.md) · OSM Extraction

---

## Overview

The `scripts/extract-osm.sh` script is the second stage of the pipeline, applicable only to the `osm-infrastructure` source. It filters full Geofabrik OSM PBF extracts down to infrastructure-relevant tags using `osmium tags-filter`, converts the filtered PBF files to GeoJSONSeq using `ogr2ogr`, and merges all regions into combined files ready for tippecanoe.

This script is called automatically by `convert.sh` when it detects that merged GeoJSONSeq files do not yet exist. It can also be run independently.

---

## Usage

```bash
# Run from inside the converter container
/scripts/extract-osm.sh
```

The script does not accept arguments. It processes all three regional PBF files found in `data/raw/osm-infrastructure/`.

### Prerequisites

- `osmium` (osmium-tool) -- installed in the converter container
- `ogr2ogr` (gdal-bin) -- installed in the converter container
- PBF files downloaded via `download.sh --source osm-infrastructure`

---

## Three-Step Process

### Step 1: Tag Filtering with osmium

For each regional PBF file, `osmium tags-filter` creates a smaller PBF containing only features matching the infrastructure tag filters.

**Input**: `data/raw/osm-infrastructure/{region}-latest.osm.pbf`
**Output**: `data/raw/osm-infrastructure/{region}-latest-infra.osm.pbf`

Regions processed:

- `europe-latest`
- `north-america-latest`
- `australia-oceania-latest`

### Step 2: PBF to GeoJSONSeq with ogr2ogr

Each filtered PBF is converted to GeoJSONSeq (newline-delimited GeoJSON) using `ogr2ogr`. Three OGR layers are extracted from each PBF:

| OGR Layer | Contains | Output File |
|---|---|---|
| `lines` | Power lines, cables, pipelines | `{region}-latest-infra-lines.geojsonseq` |
| `points` | Substations, generators, masts, towers | `{region}-latest-infra-points.geojsonseq` |
| `multipolygons` | Water treatment plants, large substations | `{region}-latest-infra-multipolygons.geojsonseq` |

### Step 3: Region Merging

All regional GeoJSONSeq files for each layer are concatenated into a single merged file. Because GeoJSONSeq is newline-delimited (one feature per line), concatenation with `cat` is valid.

**Output files**:

- `data/raw/osm-infrastructure/all-regions-infra-lines.geojsonseq`
- `data/raw/osm-infrastructure/all-regions-infra-points.geojsonseq`
- `data/raw/osm-infrastructure/all-regions-infra-multipolygons.geojsonseq`

These merged files are the input to `convert.sh` for the `osm-infrastructure` source.

---

## Osmium Tag Filters

The script applies the following tag filters. The prefix indicates the geometry type: `w/` = ways only, `nw/` = nodes and ways.

### Power Infrastructure

| Filter | Matches |
|---|---|
| `w/power=line,cable,minor_line` | High-voltage transmission lines, underground cables, distribution lines |
| `nw/power=substation,plant,generator,tower,pole` | Substations, power plants, generators, transmission towers, utility poles |

### Telecom Infrastructure

| Filter | Matches |
|---|---|
| `nw/man_made=mast,tower` | Communication masts and towers (cell towers, radio towers) |
| `nw/telecom=*` | Any feature tagged with `telecom=*` (exchanges, data centers, cabinets) |

### Water Infrastructure

| Filter | Matches |
|---|---|
| `nw/amenity=water_works,wastewater_plant` | Water treatment and wastewater treatment facilities (amenity tag) |
| `nw/man_made=wastewater_plant,water_works,reservoir_covered` | Water/wastewater plants and covered reservoirs (man_made tag) |
| `nw/waterway=dam` | Dams across waterways |

### Pipeline Infrastructure

| Filter | Matches |
|---|---|
| `w/man_made=pipeline` | Oil, gas, and water pipelines |

---

## How osmium tags-filter Works

The `osmium tags-filter` command reads an OSM PBF file and outputs a new PBF containing only the features that match at least one of the specified tag filters. It preserves the full OSM data model (nodes, ways, relations) for matching features, including referenced nodes for way geometry.

```bash
osmium tags-filter input.osm.pbf \
    "w/power=line,cable,minor_line" \
    "nw/power=substation,plant,generator,tower,pole" \
    "nw/man_made=mast,tower" \
    "nw/telecom=*" \
    "w/man_made=pipeline" \
    "nw/amenity=water_works,wastewater_plant" \
    "nw/man_made=wastewater_plant,water_works,reservoir_covered" \
    "nw/waterway=dam" \
    --overwrite \
    -o output-infra.osm.pbf
```

The `--overwrite` flag allows replacing an existing output file.

---

## ogr2ogr PBF to GeoJSONSeq Conversion

After filtering, `ogr2ogr` reads the filtered PBF using GDAL's OSM driver. The OSM driver exposes data through five fixed layers: `points`, `lines`, `multilinestrings`, `multipolygons`, and `other_relations`. The script extracts three of these.

```bash
ogr2ogr -f "GeoJSONSeq" output.geojsonseq input-infra.osm.pbf lines
ogr2ogr -f "GeoJSONSeq" output.geojsonseq input-infra.osm.pbf points
ogr2ogr -f "GeoJSONSeq" output.geojsonseq input-infra.osm.pbf multipolygons
```

GeoJSONSeq format writes one GeoJSON Feature object per line, making the files streamable and suitable for concatenation.

---

## Region Merging

GeoJSONSeq files from all three regions are concatenated per layer:

```
europe-latest-infra-lines.geojsonseq     \
north-america-latest-infra-lines.geojsonseq  > all-regions-infra-lines.geojsonseq
australia-oceania-latest-infra-lines.geojsonseq /
```

This approach works because GeoJSONSeq is newline-delimited -- there is no enclosing array or object to merge. Each line is a standalone GeoJSON Feature.

---

## Output File Naming

| File | Content | Typical Size |
|---|---|---|
| `{region}-latest-infra.osm.pbf` | Filtered PBF (intermediate) | 50-500 MB per region |
| `{region}-latest-infra-lines.geojsonseq` | Lines per region (intermediate) | 100-800 MB per region |
| `{region}-latest-infra-points.geojsonseq` | Points per region (intermediate) | 50-400 MB per region |
| `{region}-latest-infra-multipolygons.geojsonseq` | Polygons per region (intermediate) | 10-100 MB per region |
| `all-regions-infra-lines.geojsonseq` | Merged lines (final) | 200 MB - 2 GB |
| `all-regions-infra-points.geojsonseq` | Merged points (final) | 100 MB - 1 GB |
| `all-regions-infra-multipolygons.geojsonseq` | Merged polygons (final) | 20-300 MB |

Sizes vary depending on the density of tagged infrastructure in each region.

---

## Skip Logic

The script checks for existing output files at each step:

- If a filtered PBF already exists, the filtering step is skipped.
- If a GeoJSONSeq file already exists, the conversion step is skipped.
- Merged files are always regenerated (overwritten) to ensure they reflect the latest regional data.

To force a full re-extraction, delete the intermediate files:

```bash
rm data/raw/osm-infrastructure/*-infra*
/scripts/extract-osm.sh
```

---

## Troubleshooting

| Symptom | Cause | Solution |
|---|---|---|
| "PBF file not found, skipping" | PBF not downloaded for that region | Run `download.sh --source osm-infrastructure` |
| "Layer may be empty" | No features match in that geometry type for that region | Normal for some layers (e.g., few `multipolygons` in small regions) |
| Out of memory during ogr2ogr | Europe PBF is very large | Increase container memory limit or process regions sequentially |

---

## Related Pages

- [Pipeline](04-PIPELINE.md) -- parent page with pipeline overview
- [Download Scripts](04a-DOWNLOAD.md) -- how OSM PBF files are downloaded
- [Conversion and Tippecanoe](04c-CONVERT.md) -- next stage: GeoJSONSeq to MBTiles
- [OSM Power Infrastructure](02c1-OSM-POWER.md) -- detailed power tag documentation
- [OSM Water Tags](02d1-OSM-WATER.md) -- detailed water tag documentation

---

*[Back to Pipeline](04-PIPELINE.md)*
