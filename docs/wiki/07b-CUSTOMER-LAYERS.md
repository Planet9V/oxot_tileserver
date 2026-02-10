# Per-Customer Facility Layers

> **Last Updated**: 2026-02-11 01:00 UTC

[Home](INDEX.md) > [Custom Tiles](07-CUSTOM-TILES.md)

---

## The Use Case

You manage critical infrastructure visibility for multiple customers. Each customer operates facilities across different locations, and each needs to see their own assets rendered on the map alongside the standard infrastructure layers.

**Scenario**: Five customers with different facilities across 50 locations. Each customer needs their own layer with company name, address, facility type, and operational metadata. The map must support toggling individual customers on and off, styling each customer distinctly, and displaying facility details on click.

This page walks through the complete lifecycle: data modeling, three tileset approaches, client-side rendering, update procedures, and security considerations.

---

## Data Model

Every customer facility is represented as a GeoJSON Feature with a standardized property schema. Consistency across customers enables unified styling and filtering.

### Standard Property Schema

```json
{
  "type": "Feature",
  "geometry": {
    "type": "Point",
    "coordinates": [-87.6298, 41.8781]
  },
  "properties": {
    "customer_id": "ACME-001",
    "customer_name": "Acme Corporation",
    "facility_name": "Chicago Power Substation",
    "facility_type": "Electrical Substation",
    "address": "500 W Monroe St, Chicago, IL 60661",
    "sector": "ENER",
    "criticality": "high",
    "contact": "ops@acme.com"
  }
}
```

### Property Reference

| Property | Type | Required | Description |
|----------|------|----------|-------------|
| `customer_id` | String | Yes | Unique customer identifier for filtering |
| `customer_name` | String | Yes | Display name for cards and legends |
| `facility_name` | String | Yes | Facility display name |
| `facility_type` | String | Yes | Classification: Substation, Treatment Plant, etc. |
| `address` | String | Yes | Street address for display |
| `sector` | String | Yes | CISA sector code (ENER, WATR, TRAN, etc.) |
| `criticality` | String | No | Risk level: critical, high, medium, low |
| `contact` | String | No | Operations contact email or phone |
| `status` | String | No | Operational status: active, maintenance, offline |
| `install_date` | String | No | ISO 8601 date of installation |
| `capacity` | Number | No | Facility capacity (units vary by type) |

### Example: Multi-Customer FeatureCollection

```json
{
  "type": "FeatureCollection",
  "features": [
    {
      "type": "Feature",
      "geometry": { "type": "Point", "coordinates": [-87.6298, 41.8781] },
      "properties": {
        "customer_id": "ACME-001",
        "customer_name": "Acme Corporation",
        "facility_name": "Chicago Power Substation",
        "facility_type": "Electrical Substation",
        "address": "500 W Monroe St, Chicago, IL 60661",
        "sector": "ENER",
        "criticality": "high"
      }
    },
    {
      "type": "Feature",
      "geometry": { "type": "Point", "coordinates": [-118.2437, 34.0522] },
      "properties": {
        "customer_id": "GLOBEX-002",
        "customer_name": "Globex Corporation",
        "facility_name": "LA Water Treatment Facility",
        "facility_type": "Water Treatment",
        "address": "200 N Spring St, Los Angeles, CA 90012",
        "sector": "WATR",
        "criticality": "critical"
      }
    },
    {
      "type": "Feature",
      "geometry": { "type": "Point", "coordinates": [-95.3698, 29.7604] },
      "properties": {
        "customer_id": "INITECH-003",
        "customer_name": "Initech Industries",
        "facility_name": "Houston Refinery Control Center",
        "facility_type": "SCADA Control Center",
        "address": "800 Bell St, Houston, TX 77002",
        "sector": "CHEM",
        "criticality": "critical"
      }
    }
  ]
}
```

---

## Approach 1: One Tileset Per Customer

**Recommended for fewer than 10 customers.**

Each customer gets a separate GeoJSON file, a separate MBTiles tileset, and a separate entry in tileserver-config.json. The map client adds each as an independent source and layer, allowing simple toggle control.

### Step 1: Prepare per-customer GeoJSON files

```
data/extracted/
  customer-acme.geojson
  customer-globex.geojson
  customer-initech.geojson
  customer-umbrella.geojson
  customer-wayne.geojson
```

### Step 2: Convert each file

```bash
docker compose run converter tippecanoe \
  -o /data/tiles/customer-acme.mbtiles \
  -l acme_facilities \
  -z14 -Z4 \
  /data/extracted/customer-acme.geojson

docker compose run converter tippecanoe \
  -o /data/tiles/customer-globex.mbtiles \
  -l globex_facilities \
  -z14 -Z4 \
  /data/extracted/customer-globex.geojson

# Repeat for each customer
```

### Step 3: Register in tileserver-config.json

```json
{
  "data": {
    "customer-acme": { "mbtiles": "customer-acme.mbtiles" },
    "customer-globex": { "mbtiles": "customer-globex.mbtiles" },
    "customer-initech": { "mbtiles": "customer-initech.mbtiles" },
    "customer-umbrella": { "mbtiles": "customer-umbrella.mbtiles" },
    "customer-wayne": { "mbtiles": "customer-wayne.mbtiles" }
  }
}
```

### Step 4: Add layers in the map client

```javascript
// Add each customer as a separate source and layer
const customers = ['acme', 'globex', 'initech', 'umbrella', 'wayne'];

customers.forEach(customer => {
  map.addSource(`customer-${customer}`, {
    type: 'vector',
    url: `http://localhost:8080/data/customer-${customer}.json`
  });

  map.addLayer({
    id: `${customer}-facilities`,
    type: 'circle',
    source: `customer-${customer}`,
    'source-layer': `${customer}_facilities`,
    paint: {
      'circle-color': customerColors[customer],
      'circle-radius': 8,
      'circle-stroke-color': '#ffffff',
      'circle-stroke-width': 2
    }
  });
});
```

### Step 5: Toggle visibility

```javascript
function toggleCustomer(customer, visible) {
  map.setLayoutProperty(
    `${customer}-facilities`,
    'visibility',
    visible ? 'visible' : 'none'
  );
}
```

### Pros and Cons

| Aspect | Assessment |
|--------|------------|
| Layer toggling | Simple -- each customer is an independent layer |
| Data isolation | Strong -- separate tilesets per customer |
| Scalability | Poor beyond 10 customers -- many tilesets to manage |
| Disk usage | Higher -- metadata overhead per tileset |
| Configuration | Verbose -- one entry per customer in config |

---

## Approach 2: One Tileset with Customer Filter

**Recommended for 10 or more customers.**

All customer facilities are merged into a single GeoJSON file and converted into one tileset. The `customer_id` property enables client-side filtering to show only the selected customer's features.

### Step 1: Merge all customer data

Combine all customer GeoJSON files into a single FeatureCollection:

```bash
# Using jq to merge
jq -s '{type: "FeatureCollection", features: [.[].features[]]}' \
  customer-acme.geojson \
  customer-globex.geojson \
  customer-initech.geojson \
  > all-customers.geojson
```

Or use a Python script for more control:

```python
import json, glob

all_features = []
for path in glob.glob("data/extracted/customer-*.geojson"):
    with open(path) as f:
        data = json.load(f)
        all_features.extend(data["features"])

merged = {"type": "FeatureCollection", "features": all_features}
with open("data/extracted/all-customers.geojson", "w") as f:
    json.dump(merged, f)
```

### Step 2: Convert the merged file

```bash
docker compose run converter tippecanoe \
  -o /data/tiles/customer-facilities.mbtiles \
  -l facilities \
  -z14 -Z4 \
  /data/extracted/all-customers.geojson
```

### Step 3: Register one tileset

```json
{
  "data": {
    "customer-facilities": { "mbtiles": "customer-facilities.mbtiles" }
  }
}
```

### Step 4: Filter by customer on the client

```javascript
map.addSource('customers', {
  type: 'vector',
  url: 'http://localhost:8080/data/customer-facilities.json'
});

// Show only Acme facilities
map.addLayer({
  id: 'acme-facilities',
  type: 'circle',
  source: 'customers',
  'source-layer': 'facilities',
  filter: ['==', 'customer_id', 'ACME-001'],
  paint: {
    'circle-color': '#ff0000',
    'circle-radius': 8,
    'circle-stroke-color': '#ffffff',
    'circle-stroke-width': 2
  }
});

// Show only Globex facilities
map.addLayer({
  id: 'globex-facilities',
  type: 'circle',
  source: 'customers',
  'source-layer': 'facilities',
  filter: ['==', 'customer_id', 'GLOBEX-002'],
  paint: {
    'circle-color': '#00ff00',
    'circle-radius': 8,
    'circle-stroke-color': '#ffffff',
    'circle-stroke-width': 2
  }
});
```

### Dynamic customer selection

```javascript
function showCustomer(customerId) {
  map.setFilter('customer-layer', ['==', 'customer_id', customerId]);
}

function showAllCustomers() {
  map.setFilter('customer-layer', null);
}

function showMultipleCustomers(customerIds) {
  map.setFilter('customer-layer', ['in', 'customer_id', ...customerIds]);
}
```

### Pros and Cons

| Aspect | Assessment |
|--------|------------|
| Layer toggling | Filter-based -- slightly more complex client code |
| Data isolation | Weak -- all customers in one tileset (see Security below) |
| Scalability | Good -- handles hundreds of customers in one tileset |
| Disk usage | Lower -- single tileset with shared metadata |
| Configuration | Minimal -- one tileset entry |

---

## Approach 3: Combined Tileset with Per-Customer Styling

**Recommended when you want all customers visible simultaneously with distinct colors.**

Uses the same merged tileset as Approach 2 but applies a MapLibre `match` expression to assign each customer a unique color.

### Color assignment with match expression

```javascript
map.addLayer({
  id: 'all-customer-facilities',
  type: 'circle',
  source: 'customers',
  'source-layer': 'facilities',
  paint: {
    'circle-color': [
      'match', ['get', 'customer_id'],
      'ACME-001', '#ff4444',
      'GLOBEX-002', '#44ff44',
      'INITECH-003', '#4444ff',
      'UMBRELLA-004', '#ff44ff',
      'WAYNE-005', '#ffff44',
      '#888888'  // default fallback
    ],
    'circle-radius': [
      'match', ['get', 'criticality'],
      'critical', 12,
      'high', 10,
      'medium', 8,
      'low', 6,
      6  // default
    ],
    'circle-stroke-color': '#ffffff',
    'circle-stroke-width': 2
  }
});
```

### Dynamic legend

Generate a legend from the customer-color mapping:

```javascript
const customerColors = {
  'ACME-001': { name: 'Acme Corporation', color: '#ff4444' },
  'GLOBEX-002': { name: 'Globex Corporation', color: '#44ff44' },
  'INITECH-003': { name: 'Initech Industries', color: '#4444ff' },
  'UMBRELLA-004': { name: 'Umbrella Corp', color: '#ff44ff' },
  'WAYNE-005': { name: 'Wayne Enterprises', color: '#ffff44' }
};
```

---

## Complete Workflow: End to End

### 1. Collect facility data

Receive facility data from each customer. Typical source formats include CSV, Excel, or database export with these minimum columns:

| Column | Example |
|--------|---------|
| customer_id | ACME-001 |
| customer_name | Acme Corporation |
| facility_name | Chicago Power Substation |
| facility_type | Electrical Substation |
| address | 500 W Monroe St, Chicago, IL 60661 |
| latitude | 41.8781 |
| longitude | -87.6298 |
| sector | ENER |
| criticality | high |

### 2. Convert to GeoJSON

Use the Python conversion script:

```python
import csv, json

def csv_to_geojson(csv_path, output_path):
    features = []
    with open(csv_path) as f:
        for row in csv.DictReader(f):
            feature = {
                "type": "Feature",
                "geometry": {
                    "type": "Point",
                    "coordinates": [
                        float(row["longitude"]),
                        float(row["latitude"])
                    ]
                },
                "properties": {
                    "customer_id": row["customer_id"],
                    "customer_name": row["customer_name"],
                    "facility_name": row["facility_name"],
                    "facility_type": row["facility_type"],
                    "address": row["address"],
                    "sector": row["sector"],
                    "criticality": row.get("criticality", "medium")
                }
            }
            features.append(feature)

    collection = {"type": "FeatureCollection", "features": features}
    with open(output_path, "w") as f:
        json.dump(collection, f, indent=2)
    print(f"Wrote {len(features)} features to {output_path}")

csv_to_geojson("facilities.csv", "all-customers.geojson")
```

### 3. Run tippecanoe

```bash
docker compose run converter tippecanoe \
  -o /data/tiles/customer-facilities.mbtiles \
  -l facilities \
  -z14 -Z4 \
  --drop-densest-as-needed \
  /data/extracted/all-customers.geojson
```

The `--drop-densest-as-needed` flag prevents overcrowding at low zoom levels by dropping overlapping features.

### 4. Add to tileserver-config.json

```json
{
  "data": {
    "customer-facilities": {
      "mbtiles": "customer-facilities.mbtiles"
    }
  }
}
```

### 5. Restart tileserver

```bash
docker compose restart tileserver
```

### 6. Add layer in the client application

See the code examples in Approach 2 or Approach 3 above, depending on your chosen strategy.

---

## Updating Customer Data

When customer facility data changes -- new sites added, existing sites updated, sites decommissioned -- follow this update procedure:

### Full rebuild (simplest)

```bash
# 1. Re-export from source database
python scripts/export_facilities.py > data/extracted/all-customers.geojson

# 2. Re-run tippecanoe (overwrites existing .mbtiles)
docker compose run converter tippecanoe \
  -o /data/tiles/customer-facilities.mbtiles \
  -l facilities \
  -z14 -Z4 \
  --drop-densest-as-needed \
  -f \
  /data/extracted/all-customers.geojson

# 3. Restart tileserver to pick up changes
docker compose restart tileserver
```

The `-f` flag forces overwrite of the existing MBTiles file.

### Incremental updates

For large datasets where full rebuilds are slow, consider maintaining a master GeoJSON file and applying diffs. However, tippecanoe does not support incremental updates natively, so the final conversion step always processes the full dataset.

---

## Security Considerations

Data isolation is the most critical concern when serving multiple customers from the same tileserver.

### Client-side filtering is not a security boundary

Approaches 2 and 3 place all customer data in a single tileset. The `filter` expression runs in the browser. Any user with access to the tile endpoint can inspect the raw tile data and extract all customers' facilities, regardless of which filter is displayed.

**Client-side filtering is a convenience feature, not a security control.**

### True data isolation strategies

| Strategy | Isolation Level | Complexity | Use When |
|----------|----------------|------------|----------|
| Approach 1 (separate tilesets) | Tileset-level | Low | Fewer than 10 customers; different access controls per customer |
| Auth proxy per tileset | Endpoint-level | Medium | Separate tilesets with per-customer authentication |
| Server-side tile generation | Feature-level | High | Strict data isolation with dynamic tile generation |
| Separate tileserver instances | Instance-level | High | Regulatory or contractual isolation requirements |

### Recommended security model

For most OXOT deployments, use Approach 1 (separate tilesets per customer) combined with an authentication proxy that restricts access to each customer's tile endpoint based on the requesting user's identity.

```
Client --> Auth Proxy --> Tileserver
              |
              +--> /data/customer-acme/* --> only for ACME users
              +--> /data/customer-globex/* --> only for GLOBEX users
```

---

## Approach Comparison Summary

| Factor | Approach 1 (Separate) | Approach 2 (Merged + Filter) | Approach 3 (Merged + Styling) |
|--------|----------------------|------------------------------|-------------------------------|
| Best for | < 10 customers | 10+ customers | All customers visible |
| Data isolation | Strong | Weak | Weak |
| Disk usage | Higher | Lower | Lower |
| Config complexity | Higher | Lower | Lower |
| Client complexity | Lower | Medium | Medium |
| Toggle control | Layer visibility | Filter expression | Filter expression |
| Update procedure | Per-customer rebuild | Single rebuild | Single rebuild |

---

## Related Pages

- [Custom Tiles](07-CUSTOM-TILES.md) -- parent page with workflow overview
- [GeoJSON Authoring](07a-GEOJSON-AUTHORING.md) -- creating valid GeoJSON source data
- [Equipment & Fixed Asset Layers](07c-EQUIPMENT-LAYERS.md) -- equipment-specific tile layers
- [Custom Layer Styling](07d-STYLING.md) -- paint and layout property reference
- [Map Cards & Popups](07e-CARDS-DISPLAY.md) -- displaying facility details on click
- [Conversion & Tippecanoe](04c-CONVERT.md) -- detailed tippecanoe options

---

*[Home](INDEX.md) | [Custom Tiles](07-CUSTOM-TILES.md) | [GeoJSON Authoring](07a-GEOJSON-AUTHORING.md) | [Equipment Layers](07c-EQUIPMENT-LAYERS.md)*
