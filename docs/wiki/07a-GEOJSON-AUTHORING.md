# GeoJSON Authoring Guide

> **Last Updated**: 2026-02-11 01:00 UTC

[Home](INDEX.md) > [Custom Tiles](07-CUSTOM-TILES.md)

---

## Overview

GeoJSON is the primary input format for creating custom vector tiles with the OXOT Tileserver. All custom data -- whether facility locations, pipeline routes, or zone boundaries -- must be expressed as valid GeoJSON before conversion to MBTiles with tippecanoe. This page covers the GeoJSON specification, supported geometry types, coordinate conventions, authoring tools, and validation procedures.

---

## GeoJSON Specification (RFC 7946)

GeoJSON is an open standard format for encoding geographic data structures. It is defined by RFC 7946 (Butler et al., 2016) and uses JSON as its underlying encoding. Every GeoJSON object is a valid JSON object with a `type` property indicating whether it is a Feature, a FeatureCollection, or a bare Geometry.

The OXOT Tileserver pipeline expects **FeatureCollection** objects as input -- a top-level JSON object containing an array of Feature objects.

### FeatureCollection Structure

```json
{
  "type": "FeatureCollection",
  "features": [
    {
      "type": "Feature",
      "geometry": {
        "type": "Point",
        "coordinates": [-73.985, 40.748]
      },
      "properties": {
        "name": "Example Facility",
        "sector": "WATR"
      }
    }
  ]
}
```

Every Feature has three required members:

| Member | Type | Description |
|--------|------|-------------|
| `type` | String | Always `"Feature"` |
| `geometry` | Object | A Geometry object with `type` and `coordinates` |
| `properties` | Object | Arbitrary key-value pairs describing the feature |

---

## Geometry Types

GeoJSON supports seven geometry types. The first three cover most custom tile use cases.

### Point

Represents a single location. Use for facilities, equipment, sensors, wells, towers.

```json
{
  "type": "Point",
  "coordinates": [-73.985, 40.748]
}
```

Coordinates are `[longitude, latitude]` in decimal degrees. An optional third element specifies altitude in meters.

### LineString

Represents a path. Use for pipelines, transmission lines, roads, cable routes.

```json
{
  "type": "LineString",
  "coordinates": [
    [-73.985, 40.748],
    [-73.990, 40.752],
    [-73.995, 40.755]
  ]
}
```

A LineString must have at least two coordinate positions.

### Polygon

Represents an enclosed area. Use for facility boundaries, service zones, flood plains, exclusion areas.

```json
{
  "type": "Polygon",
  "coordinates": [[
    [-73.990, 40.745],
    [-73.980, 40.745],
    [-73.980, 40.755],
    [-73.990, 40.755],
    [-73.990, 40.745]
  ]]
}
```

The first and last coordinates must be identical (closing the ring). The outer ring is the first array; subsequent arrays represent holes.

### MultiPoint

Multiple unconnected points in a single feature. Use when a single logical entity has multiple locations.

```json
{
  "type": "MultiPoint",
  "coordinates": [
    [-73.985, 40.748],
    [-74.005, 40.730]
  ]
}
```

### MultiLineString

Multiple line segments in a single feature. Use for branching pipeline networks or multi-segment routes.

```json
{
  "type": "MultiLineString",
  "coordinates": [
    [[-73.985, 40.748], [-73.990, 40.752]],
    [[-73.990, 40.752], [-73.995, 40.755]]
  ]
}
```

### MultiPolygon

Multiple polygons in a single feature. Use for facilities with non-contiguous parcels.

```json
{
  "type": "MultiPolygon",
  "coordinates": [
    [[[-73.990, 40.745], [-73.980, 40.745], [-73.980, 40.755], [-73.990, 40.755], [-73.990, 40.745]]],
    [[[-74.010, 40.730], [-74.000, 40.730], [-74.000, 40.740], [-74.010, 40.740], [-74.010, 40.730]]]
  ]
}
```

### GeometryCollection

A heterogeneous collection of geometry objects. Rarely used for tile generation; prefer separate features instead.

---

## Coordinate Reference System

GeoJSON uses **WGS84** (EPSG:4326) exclusively. All coordinates must be in decimal degrees with longitude first, latitude second:

```
[longitude, latitude]
[longitude, latitude, altitude]
```

Common mistakes:

| Mistake | Symptom | Fix |
|---------|---------|-----|
| Latitude first | Features appear in wrong location | Swap to `[lon, lat]` |
| Projected coordinates (meters) | Features off-screen or at null island | Reproject with ogr2ogr |
| Degrees-minutes-seconds | tippecanoe error or misplaced features | Convert to decimal degrees |

To reproject from a non-WGS84 source:

```bash
ogr2ogr -f GeoJSON -t_srs EPSG:4326 output.geojson input.shp
```

---

## Properties

The `properties` object in each Feature accepts arbitrary key-value pairs. These properties become attributes in the vector tile and are available for styling, filtering, and popup display.

### Recommended Property Conventions

| Property | Type | Description |
|----------|------|-------------|
| `name` | String | Human-readable feature name |
| `id` | String | Unique identifier |
| `sector` | String | CISA sector code (ENER, WATR, TRAN, etc.) |
| `facility_type` | String | Classification for styling and filtering |
| `customer_id` | String | Customer identifier for multi-tenant layers |
| `address` | String | Street address for display |
| `criticality` | String | Risk level: critical, high, medium, low |

### Property Type Constraints

tippecanoe preserves the following JSON types in vector tiles:

- **String** -- preserved as-is
- **Number** -- preserved as integer or float
- **Boolean** -- converted to 0 or 1
- **null** -- property omitted from the tile

Nested objects and arrays are serialized to strings. Avoid nesting; flatten your properties for optimal tile performance.

---

## Tools for Creating GeoJSON

### geojson.io (Web Editor)

The fastest way to create small GeoJSON files. Open [geojson.io](https://geojson.io) in a browser, draw features on the map, edit properties in the table, and export as `.geojson`. Best for prototyping and creating small datasets (under 100 features).

### QGIS (Desktop GIS)

Full-featured desktop GIS application. Import data from CSV, Shapefile, GeoPackage, or database. Edit geometries with snapping and topological tools. Export as GeoJSON via Layer > Export > Save Features As > GeoJSON. Best for complex spatial editing and large datasets.

### Python (geojson and shapely libraries)

Programmatic GeoJSON creation for automated pipelines:

```python
import json

features = []
for row in csv_reader:
    feature = {
        "type": "Feature",
        "geometry": {
            "type": "Point",
            "coordinates": [float(row["longitude"]), float(row["latitude"])]
        },
        "properties": {
            "name": row["facility_name"],
            "customer_id": row["customer_id"],
            "sector": row["sector"]
        }
    }
    features.append(feature)

collection = {"type": "FeatureCollection", "features": features}
with open("facilities.geojson", "w") as f:
    json.dump(collection, f)
```

Best for converting CSV, database exports, and API responses to GeoJSON.

### ogr2ogr (Format Conversion)

GDAL command-line utility available in the converter container. Converts between 80+ geospatial formats:

```bash
# Shapefile to GeoJSON
ogr2ogr -f GeoJSON output.geojson input.shp

# GeoPackage to GeoJSON
ogr2ogr -f GeoJSON output.geojson input.gpkg

# CSV with lat/lon to GeoJSON
ogr2ogr -f GeoJSON output.geojson input.csv \
  -oo X_POSSIBLE_NAMES=longitude \
  -oo Y_POSSIBLE_NAMES=latitude
```

Best for bulk format conversion from any supported geospatial format.

---

## Validating GeoJSON

Always validate GeoJSON before running tippecanoe. Invalid GeoJSON produces missing features, incorrect geometries, or conversion errors.

### Online Validation

- **geojsonlint.com** -- paste or upload GeoJSON for RFC 7946 compliance checking
- **geojson.io** -- visual validation; malformed features display as errors

### Command-Line Validation

Using the `check-jsonschema` Python tool:

```bash
pip install check-jsonschema
check-jsonschema --schemafile geojson-schema.json my-data.geojson
```

Using `jq` for structural validation:

```bash
# Check that every feature has a geometry
jq '[.features[] | select(.geometry == null)] | length' my-data.geojson
# Should return 0
```

### Common Validation Errors

| Error | Cause | Fix |
|-------|-------|-----|
| `Invalid type` | Missing or misspelled `type` field | Ensure `"type": "Feature"` on every feature |
| `Coordinates out of range` | Longitude > 180 or latitude > 90 | Check coordinate order and projection |
| `Ring not closed` | First and last polygon coordinates differ | Duplicate the first coordinate at the end |
| `Self-intersecting polygon` | Polygon edges cross each other | Simplify geometry or fix in QGIS |

---

## Complete Example: Facility Point Feature

```json
{
  "type": "Feature",
  "geometry": {
    "type": "Point",
    "coordinates": [-73.985, 40.748]
  },
  "properties": {
    "name": "Water Treatment Plant Alpha",
    "customer": "AcmeCorp",
    "facility_type": "Water Treatment",
    "address": "123 Industrial Way, Newark, NJ 07102",
    "capacity_mgd": 150,
    "sector": "WATR"
  }
}
```

## Complete Example: Pipeline Route (LineString)

```json
{
  "type": "Feature",
  "geometry": {
    "type": "LineString",
    "coordinates": [
      [-73.985, 40.748],
      [-73.990, 40.752],
      [-73.998, 40.760],
      [-74.005, 40.768]
    ]
  },
  "properties": {
    "name": "Newark-Hoboken Water Main",
    "pipeline_type": "Transmission",
    "diameter_inches": 36,
    "material": "Ductile Iron",
    "install_year": 2015,
    "operator": "AcmeCorp",
    "sector": "WATR"
  }
}
```

## Complete Example: Facility Boundary (Polygon)

```json
{
  "type": "Feature",
  "geometry": {
    "type": "Polygon",
    "coordinates": [[
      [-73.990, 40.745],
      [-73.982, 40.745],
      [-73.982, 40.752],
      [-73.990, 40.752],
      [-73.990, 40.745]
    ]]
  },
  "properties": {
    "name": "Water Treatment Plant Alpha - Site Boundary",
    "customer": "AcmeCorp",
    "facility_type": "Water Treatment",
    "area_acres": 12.5,
    "zoning": "Industrial",
    "sector": "WATR"
  }
}
```

---

## References

Butler, H., Daly, M., Doyle, A., Gillies, S., Hagen, S., & Schaub, T. (2016). *The GeoJSON format* (RFC 7946). Internet Engineering Task Force. https://tools.ietf.org/html/rfc7946

---

## Related Pages

- [Custom Tiles](07-CUSTOM-TILES.md) -- parent page with workflow overview
- [Per-Customer Facility Layers](07b-CUSTOMER-LAYERS.md) -- applying GeoJSON to multi-tenant scenarios
- [Equipment & Fixed Asset Layers](07c-EQUIPMENT-LAYERS.md) -- equipment-specific data models
- [Conversion & Tippecanoe](04c-CONVERT.md) -- converting GeoJSON to vector tiles

---

*[Home](INDEX.md) | [Custom Tiles](07-CUSTOM-TILES.md) | [Customer Layers](07b-CUSTOMER-LAYERS.md) | [Equipment Layers](07c-EQUIPMENT-LAYERS.md)*
