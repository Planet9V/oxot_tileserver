# Vector Tile Format

> **Last Updated**: 2026-02-11 01:00 UTC

[Home](INDEX.md) > [API Reference](05-API.md) > Vector Tile Format

---

## Overview

The OXOT Tileserver serves vector tiles encoded in the Mapbox Vector Tile (MVT) format, version 2. Vector tiles are binary Protocol Buffer files (`.pbf`) that contain geometry, attributes, and layer structure for a specific geographic area at a specific zoom level. Unlike raster tiles, vector tiles are rendered client-side, enabling dynamic styling, rotation, and interaction without re-fetching data.

---

## Mapbox Vector Tile Specification v2

The MVT specification defines how geographic features are encoded into a compact binary format:

1. **Tile coordinate system**: Each tile represents a 4096 x 4096 unit grid (the `extent`). Feature coordinates are encoded as integers within this grid.
2. **Geometry encoding**: Coordinates are delta-encoded using a cursor model with MoveTo, LineTo, and ClosePath commands. This produces compact representations of complex geometries.
3. **Property encoding**: Feature properties are stored in two shared lookup tables per layer -- one for keys (strings) and one for values (strings, integers, floats, booleans). Each feature references keys and values by index, reducing duplication.
4. **Compression**: Tiles are typically gzip-compressed before storage in MBTiles, reducing transfer size by 60--80%.

---

## Tile Coordinate System

Tiles follow the Slippy Map (XYZ) convention:

| Component | Description |
|-----------|-------------|
| `z` (zoom) | Zoom level. At zoom 0, the entire world is one tile. At zoom `z`, there are `2^z * 2^z` tiles. |
| `x` (column) | Horizontal position, 0 at the left (180 W), increasing eastward. Range: 0 to `2^z - 1`. |
| `y` (row) | Vertical position, 0 at the top (85.05 N), increasing southward. Range: 0 to `2^z - 1`. |

The URL pattern is:

```
/data/{tileset}/{z}/{x}/{y}.pbf
```

For example, `/data/osm-infrastructure/6/32/21.pbf` requests zoom level 6, column 32, row 21 from the `osm-infrastructure` tileset.

---

## Layer Structure

Each vector tile contains one or more named **layers**. A layer groups features of the same type (e.g., all power lines, all substations). Layers are identified by their `id` string, which must match the `source-layer` value used in style definitions.

The OXOT infrastructure tiles contain the following layers:

| Layer ID | Geometry Type | Min Zoom | Description |
|----------|--------------|----------|-------------|
| `power_lines` | LineString | 4 | High-voltage transmission and distribution lines |
| `pipelines` | LineString | 6 | Oil, gas, and water pipelines |
| `generators` | Point | 6 | Power generation facilities (plants, solar, wind) |
| `substations` | Point | 8 | Electrical substations and transformer stations |
| `water_treatment` | Point | 8 | Water and wastewater treatment facilities |
| `telecom_masts` | Point | 10 | Telecommunications towers and masts |

The GeoNames tileset contains:

| Layer ID | Geometry Type | Min Zoom | Description |
|----------|--------------|----------|-------------|
| `cities` | Point | 2 | Global city points with name and population |

---

## Feature Types

MVT supports three geometry types:

### Point

Encoded as a single MoveTo command. Used for discrete facilities such as substations, generators, and treatment plants.

```
Properties example:
{
  "name": "Riverside Substation",
  "operator": "PG&E",
  "voltage": 230000,
  "substation": "transmission"
}
```

### LineString

Encoded as a MoveTo followed by one or more LineTo commands. Used for linear infrastructure such as power lines and pipelines.

```
Properties example:
{
  "name": "Pacific Intertie",
  "voltage": 500000,
  "operator": "BPA",
  "cables": 3
}
```

### Polygon

Encoded as a MoveTo, one or more LineTo commands, and a ClosePath command. Used for area features such as facility boundaries, when present. Most infrastructure data in OXOT uses Point and LineString geometries.

---

## Properties and Attributes

Each feature carries a set of key-value properties derived from the source data. Properties are preserved through the conversion pipeline (download, extract, tippecanoe) and are available for:

- **Client-side filtering**: MapLibre `filter` expressions can select features by property values.
- **Styling**: Property-driven styling rules (e.g., line color by voltage class).
- **Popups and interaction**: Click handlers access feature properties for display.

Property types supported by MVT:

| Type | Example |
|------|---------|
| String | `"name": "Springfield WTP"` |
| Integer | `"voltage": 345000` |
| Float | `"capacity_mw": 1200.5` |
| Boolean | `"active": true` |

Properties that are `null` or empty are omitted from the tile to save space.

---

## Zoom Levels and Data Density

The zoom level controls how much of the world is visible and how many features are included per tile.

| Zoom Range | Approximate Scale | Typical Content |
|-----------|-------------------|-----------------|
| 0--3 | Continent / world | Country boundaries, major cities |
| 4--6 | Regional | Major transmission lines, large generators |
| 7--9 | Metropolitan | Substations, medium-voltage lines, treatment plants |
| 10--12 | City / district | Telecom masts, distribution lines, small facilities |
| 13--14 | Neighborhood | Maximum detail, all features visible |

Tippecanoe applies feature dropping at lower zoom levels using `--drop-densest-as-needed` to keep tile sizes within target limits. At the maximum zoom level, all features are preserved.

---

## Tile Size Considerations

Target tile sizes for optimal performance:

| Metric | Target | Concern |
|--------|--------|---------|
| Uncompressed tile | < 500 KB | Larger tiles slow client-side parsing |
| Compressed tile (gzip) | < 100 KB | Larger tiles increase transfer time |
| Features per tile | < 200,000 | Excessive features cause rendering lag |

Tippecanoe settings that control tile size:

```bash
tippecanoe \
  --maximum-tile-bytes=500000 \
  --drop-densest-as-needed \
  --extend-zooms-if-still-dropping \
  -z14 -Z0 \
  -o output.mbtiles \
  input.geojson
```

See [Performance Tuning](08c-PERFORMANCE.md) for detailed tippecanoe optimization.

---

## Overzooming Behavior

When a client requests a tile at a zoom level beyond the tileset's `maxzoom`, tileserver-gl returns the tile from `maxzoom` and the client **overzooms** -- it scales the returned geometry to fit the requested zoom level.

For the OXOT tileserver:

- Tiles are generated up to zoom 14.
- Requests at zoom 15+ return zoom 14 tiles, which the client scales.
- Overzoomed tiles appear less detailed but remain functional.

This is standard behavior in all MapLibre GL, Leaflet, and OpenLayers clients. The TileJSON `maxzoom` field informs clients when overzooming begins.

---

## Inspecting Vector Tiles

Use these tools to inspect tile contents during development and debugging.

### Using tileserver-gl built-in viewer

Navigate to `http://localhost:8080` in a browser. The tileserver-gl web UI provides an interactive tile inspector.

### Using vt-pbf and tippecanoe-decode

```bash
# Decode a PBF tile to GeoJSON (requires tippecanoe)
tippecanoe-decode tile.pbf 6 32 21

# Or fetch and decode in one command
curl -s http://localhost:8080/data/osm-infrastructure/6/32/21.pbf | \
  tippecanoe-decode /dev/stdin 6 32 21 | jq .
```

### Using mbview

```bash
# Install mbview
npm install -g @mapbox/mbview

# View an MBTiles file interactively
mbview data/tiles/osm-infrastructure.mbtiles
```

---

## Protocol Buffer Encoding Details

For developers building custom tile consumers, the MVT binary format uses the following protobuf schema (simplified):

```protobuf
message Tile {
  repeated Layer layers = 3;

  message Layer {
    required string name = 1;
    repeated Feature features = 2;
    repeated string keys = 3;
    repeated Value values = 4;
    optional uint32 extent = 5 [default = 4096];
    optional uint32 version = 15 [default = 2];
  }

  message Feature {
    optional uint64 id = 1;
    repeated uint32 tags = 2;  // alternating key/value indices
    optional GeomType type = 3;
    repeated uint32 geometry = 4;  // encoded commands
  }

  message Value {
    optional string string_value = 1;
    optional float float_value = 2;
    optional double double_value = 3;
    optional int64 int_value = 4;
    optional uint64 uint_value = 5;
    optional sint64 sint_value = 6;
    optional bool bool_value = 7;
  }

  enum GeomType {
    UNKNOWN = 0;
    POINT = 1;
    LINESTRING = 2;
    POLYGON = 3;
  }
}
```

---

## References

Mapbox. (2024). *Mapbox Vector Tile specification (Version 2.1)*. GitHub. https://github.com/mapbox/vector-tile-spec

---

## Related Pages

- [API Reference](05-API.md) -- parent page
- [REST API Endpoints](05a-REST-ENDPOINTS.md) -- PBF tile endpoint details
- [TileJSON Metadata](05b-TILEJSON.md) -- metadata describing the layers inside tiles
- [Style API](05d-STYLES.md) -- how styles reference vector tile layers
- [Conversion & Tippecanoe](04c-CONVERT.md) -- how tiles are generated

---

*[Home](INDEX.md) | [API Reference](05-API.md) | [REST Endpoints](05a-REST-ENDPOINTS.md) | [TileJSON](05b-TILEJSON.md) | [Styles](05d-STYLES.md)*
