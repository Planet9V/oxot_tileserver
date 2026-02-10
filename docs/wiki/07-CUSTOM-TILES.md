# Custom Tile Creation

> **Last Updated**: 2026-02-11 01:00 UTC

[Home](INDEX.md)

---

## Why Custom Tiles?

The OXOT Tileserver ships with 21 authoritative data sources covering electric grid, water, demographics, and telecoms. These layers serve the general-purpose infrastructure visualization use case well. But most deployments eventually need layers that are specific to the organization, its customers, or its operational context.

Custom tiles address three requirements that standard data sources cannot:

### Proprietary Facility Data

Your organization tracks assets that do not appear in any public dataset. Power substations owned by a specific utility, private water treatment plants, proprietary pipeline routes, or classified facility locations all require tiles built from internal data. Custom tiles keep this data within your network while rendering it alongside public infrastructure layers.

### Customer-Specific Overlays

When serving multiple customers, each needs to see their own facilities on the map. A managed security service provider monitoring five utilities needs five separate facility layers -- one per customer -- each showing that customer's sites, equipment, and operational boundaries. Custom tiles enable per-customer overlays with appropriate data isolation.

### Operational Asset Tracking

Fixed assets such as railway signals, transformers, pumping stations, and telecom towers have precise geographic coordinates that matter for maintenance, inspection, and incident response. Custom tiles transform equipment inventories from spreadsheets and CMMS systems into interactive map layers with full attribute detail.

---

## The Custom Tile Workflow

Every custom tile follows the same five-step process:

```
1. Create GeoJSON    -->  2. Run tippecanoe    -->  3. Produce .mbtiles
                                                          |
4. Add to tileserver-config.json  <-----------------------+
                                                          |
5. Restart tileserver  <----------------------------------+
```

### Step 1: Create GeoJSON

Author a valid GeoJSON file containing your geographic features. Each feature has a geometry (point, line, or polygon) and a properties object with arbitrary key-value pairs describing the feature.

See: [GeoJSON Authoring](07a-GEOJSON-AUTHORING.md)

### Step 2: Run tippecanoe

Use the converter container to run tippecanoe against your GeoJSON file. Tippecanoe builds a multi-zoom-level vector tileset optimized for web rendering.

```bash
docker compose run converter tippecanoe \
  -o /data/tiles/my-custom-layer.mbtiles \
  -l my_layer_name \
  -z14 -Z4 \
  /data/extracted/my-data.geojson
```

The `-l` flag sets the source-layer name used by the map client. The `-z` and `-Z` flags set the maximum and minimum zoom levels.

See: [Conversion & Tippecanoe](04c-CONVERT.md)

### Step 3: Verify the output

Inspect the resulting MBTiles file to confirm layer names, zoom levels, and feature counts:

```bash
docker compose run converter tippecanoe-decode \
  /data/tiles/my-custom-layer.mbtiles \
  --stats
```

### Step 4: Add to tileserver-config.json

Register the new tileset in the tileserver configuration:

```json
{
  "data": {
    "my-custom-layer": {
      "mbtiles": "my-custom-layer.mbtiles"
    }
  }
}
```

See: [Loading & Verification](04d-LOAD.md)

### Step 5: Restart tileserver

```bash
docker compose restart tileserver
```

The new tileset is now available at `http://localhost:8080/data/my-custom-layer/{z}/{x}/{y}.pbf` with TileJSON metadata at `http://localhost:8080/data/my-custom-layer.json`.

---

## Choosing an Approach

The five child pages below cover the full lifecycle of custom tile creation, from data authoring through interactive display.

| Page | Purpose | Start Here If... |
|------|---------|------------------|
| [GeoJSON Authoring](07a-GEOJSON-AUTHORING.md) | Creating and validating source data | You need to create GeoJSON from scratch or convert from another format |
| [Per-Customer Facility Layers](07b-CUSTOMER-LAYERS.md) | Multi-tenant facility overlays | You serve multiple customers who each need their own facility layer |
| [Equipment & Fixed Asset Layers](07c-EQUIPMENT-LAYERS.md) | BOM-to-tile pipeline | You have equipment inventories (CMMS, spreadsheets) to visualize |
| [Custom Layer Styling](07d-STYLING.md) | Paint and layout properties | You need to control colors, sizes, and labels for your layers |
| [Map Cards & Popups](07e-CARDS-DISPLAY.md) | Interactive feature display | You want click-to-inspect cards showing feature details |

---

## Data Formats Supported

The converter container accepts the following input formats for tile generation:

| Format | Extension | Tool | Notes |
|--------|-----------|------|-------|
| GeoJSON | `.geojson`, `.json` | tippecanoe (direct) | Preferred input format |
| Shapefile | `.shp` | ogr2ogr then tippecanoe | Convert to GeoJSON first |
| GeoPackage | `.gpkg` | ogr2ogr then tippecanoe | Convert to GeoJSON first |
| CSV with coordinates | `.csv` | Python/ogr2ogr then tippecanoe | Requires lat/lon columns |
| KML | `.kml` | ogr2ogr then tippecanoe | Convert to GeoJSON first |

For any format other than GeoJSON, convert to GeoJSON first using ogr2ogr:

```bash
docker compose run converter ogr2ogr \
  -f GeoJSON /data/extracted/output.geojson \
  /data/raw/input.shp
```

---

## Children Pages

| Page | Description |
|------|-------------|
| [GeoJSON Authoring](07a-GEOJSON-AUTHORING.md) | GeoJSON specification, feature types, coordinate systems, authoring tools, validation |
| [Per-Customer Facility Layers](07b-CUSTOMER-LAYERS.md) | Multi-customer data model, per-customer vs. merged tilesets, client-side filtering, security |
| [Equipment & Fixed Asset Layers](07c-EQUIPMENT-LAYERS.md) | Equipment data model, asset categories, clustering, condition-based styling |
| [Custom Layer Styling](07d-STYLING.md) | MapLibre paint and layout properties, data-driven expressions, zoom-dependent styling |
| [Map Cards & Popups](07e-CARDS-DISPLAY.md) | Popup implementation, side panel cards, card templates, API-driven detail loading |

---

## Related Pages

- [Data Pipeline](04-PIPELINE.md) -- the standard pipeline that custom tiles extend
- [Conversion & Tippecanoe](04c-CONVERT.md) -- detailed tippecanoe options and flags
- [Application Integration](06-INTEGRATION.md) -- connecting map clients to consume tiles
- [MapLibre GL JS](06a-MAPLIBRE.md) -- primary client for rendering custom layers
- [API Reference](05-API.md) -- REST endpoints for accessing tile data

---

*[Home](INDEX.md) | [GeoJSON Authoring](07a-GEOJSON-AUTHORING.md) | [Customer Layers](07b-CUSTOMER-LAYERS.md) | [Equipment Layers](07c-EQUIPMENT-LAYERS.md) | [Styling](07d-STYLING.md) | [Cards & Popups](07e-CARDS-DISPLAY.md)*
