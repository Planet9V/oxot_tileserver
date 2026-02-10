# Awesome Electrical Grid Mapping

> **Last Updated**: 2026-02-11 02:30 UTC

[Home](INDEX.md) > [Data Sources](02-DATA-SOURCES.md) > [Electric Grid](02c-ELECTRIC.md) > Awesome Electrical Grid Mapping

---

## 1. Overview

The **Awesome Electrical Grid Mapping** repository is a curated, community-maintained catalog of global electrical grid maps, datasets, and resources maintained by the [MapYourGrid Initiative](https://mapyourgrid.org/) under the Open Energy Transition project. It aggregates transmission network data from national grid operators, international organizations, and open-data projects for nearly every country worldwide.

| Field | Value |
|-------|-------|
| **Repository** | https://github.com/open-energy-transition/Awesome-Electrical-Grid-Mapping |
| **Maintainer** | Open Energy Transition / MapYourGrid Initiative |
| **Coverage** | Global (entries for 150+ countries across all continents) |
| **License** | CC0-1.0 (Public Domain) |
| **Related Tools** | PyPSA, PyPSA-Eur, PyPSA-Earth, earth-osm, GridFinder |
| **Data Formats** | GeoJSON, Shapefile, CSV, KML (varies by source) |
| **Update Frequency** | Continuously maintained (454+ commits) |

---

## 2. What It Provides

Unlike a single downloadable dataset, this repository is a **curated directory** of grid data sources organized by continent and country. Each entry links to:

- National Transmission System Operator (TSO) grid maps
- Open-data grid topology datasets (lines, substations, generators)
- Capacity maps and development plans
- Research datasets with transmission network models

### Key Global Platforms Referenced

| Platform | URL | Data | License |
|----------|-----|------|---------|
| Open Infrastructure Map | https://openinframap.org/ | OSM-derived power grid visualization | ODbL |
| GridFinder | https://gridfinder.rdrn.me/ | Predicted grid extent using satellite/ML | CC BY 4.0 |
| FLOSM Power Grid | https://www.flosm.de/html/power-grid.html | OSM power grid rendering | ODbL |
| Global Energy Monitor | https://globalenergymonitor.org/ | Power plants, pipelines, terminals | CC BY 4.0 |
| Global Transmission Database | https://zenodo.org/records/10870603 | Network topology + capacity | MIT |
| ENERGYDATA.INFO | https://energydata.info/ | World Bank energy open data | Various |
| PyPSA-Eur | https://pypsa-eur.readthedocs.io/ | European transmission model (ENTSO-E cleaned) | MIT |
| PyPSA-Earth | https://pypsa-earth.readthedocs.io/ | Global transmission model from OSM | AGPL-3.0 |
| earth-osm | https://github.com/pypsa-meets-earth/earth-osm | Python CLI for OSM infrastructure extraction | MIT |

### Regional Highlights

| Region | Key Sources | Coverage Quality |
|--------|-------------|-----------------|
| **Europe** | ENTSO-E grid map, national TSO data (RTE, TenneT, Statnett, etc.), PyPSA-Eur | Excellent — detailed topology |
| **North America** | HIFLD, EIA, NERC maps, state PUC data | Excellent (US), Good (Canada) |
| **Australia/NZ** | Geoscience Australia, AEMO, Transpower NZ | Good |
| **Africa** | ECOWAS, SAPP, country-specific (Nigeria 50-bus, Kenya KETCO) | Variable — improving |
| **Asia** | India ICED, Japan OCCTO, China Baker Institute, ASEAN interconnections | Variable by country |
| **South America** | Country-specific TSO data (ONS Brazil, CAMMESA Argentina) | Good for major countries |

---

## 3. Download & Integration Pipeline

Since this is a curated list (not a single dataset), the integration approach depends on which sources you select. Below are the recommended approaches for the OXOT Tileserver.

### 3.1 Approach A: Use earth-osm (Recommended for Global Coverage)

The `earth-osm` Python tool extracts power infrastructure from OpenStreetMap and outputs clean GeoJSON files — the same pipeline used by PyPSA-Earth.

```bash
# Inside the converter container
docker compose --profile tools run converter bash

# Install earth-osm
pip3 install earth-osm

# Extract power lines for target regions
earth-osm --primary power --feature line --country DE FR GB US AU NZ \
  --data_dir /data/raw/earth-osm/

# Extract substations
earth-osm --primary power --feature substation --country DE FR GB US AU NZ \
  --data_dir /data/raw/earth-osm/

# Extract generators/power plants
earth-osm --primary power --feature generator --country DE FR GB US AU NZ \
  --data_dir /data/raw/earth-osm/

# Output: GeoJSON files in /data/raw/earth-osm/{country}/Elements/
```

#### Convert to Tiles

```bash
# Merge all country GeoJSON files per feature type
cat /data/raw/earth-osm/*/Elements/power_line_*.geojson | \
  jq -s '{type:"FeatureCollection", features:[.[].features[]]}' > /data/raw/grid-lines.geojson

cat /data/raw/earth-osm/*/Elements/power_substation_*.geojson | \
  jq -s '{type:"FeatureCollection", features:[.[].features[]]}' > /data/raw/grid-substations.geojson

cat /data/raw/earth-osm/*/Elements/power_generator_*.geojson | \
  jq -s '{type:"FeatureCollection", features:[.[].features[]]}' > /data/raw/grid-generators.geojson

# Convert to MBTiles
tippecanoe -o /data/tiles/grid-lines.mbtiles \
  -l grid_lines -z14 -Z3 \
  --drop-densest-as-needed \
  --extend-zooms-if-still-dropping \
  /data/raw/grid-lines.geojson

tippecanoe -o /data/tiles/grid-substations.mbtiles \
  -l grid_substations -z14 -Z5 \
  --cluster-distance=50 \
  /data/raw/grid-substations.geojson

tippecanoe -o /data/tiles/grid-generators.mbtiles \
  -l grid_generators -z14 -Z4 \
  --cluster-distance=40 \
  /data/raw/grid-generators.geojson
```

### 3.2 Approach B: Use Global Transmission Database (Research-Grade Topology)

For network topology analysis (which lines connect which substations):

```bash
# Download from Zenodo
wget "https://zenodo.org/records/10870603/files/global-transmission-database.zip" \
  -O /data/raw/global-transmission-db.zip
unzip /data/raw/global-transmission-db.zip -d /data/raw/global-transmission-db/

# Contains CSV with node/edge topology + coordinates
# Convert to GeoJSON
python3 -c "
import csv, json

# Parse nodes (substations)
nodes = []
with open('/data/raw/global-transmission-db/nodes.csv') as f:
    for row in csv.DictReader(f):
        nodes.append({
            'type': 'Feature',
            'geometry': {'type': 'Point', 'coordinates': [float(row['lon']), float(row['lat'])]},
            'properties': {'id': row['id'], 'name': row.get('name',''), 'voltage_kv': row.get('voltage','')}
        })

with open('/data/raw/gtdb-nodes.geojson', 'w') as f:
    json.dump({'type': 'FeatureCollection', 'features': nodes}, f)
print(f'Wrote {len(nodes)} nodes')
"

# Convert to tiles
tippecanoe -o /data/tiles/gtdb-nodes.mbtiles -l gtdb_substations -z14 -Z4 \
  /data/raw/gtdb-nodes.geojson
```

### 3.3 Approach C: Use PyPSA-Eur (European Transmission Network)

For the most accurate European transmission topology (cleaned ENTSO-E data):

```bash
# Clone PyPSA-Eur and extract network data
git clone --depth 1 https://github.com/PyPSA/pypsa-eur.git /data/raw/pypsa-eur

# The network topology is in the resources/ directory after running snakemake
# For pre-built data, use the Zenodo archive:
wget "https://zenodo.org/records/10356004/files/pypsa-eur-networks.tar.gz" \
  -O /data/raw/pypsa-eur-networks.tar.gz

# Extract and convert network files to GeoJSON using Python
pip3 install pypsa pandas geopandas
python3 -c "
import pypsa, geopandas as gpd
n = pypsa.Network('/data/raw/pypsa-eur/networks/elec_s_256.nc')
lines = gpd.GeoDataFrame(n.lines, geometry=gpd.points_from_xy(n.lines.x0, n.lines.y0))
lines.to_file('/data/raw/pypsa-eur-lines.geojson', driver='GeoJSON')
"
```

### 3.4 Approach D: Download Specific Country TSO Data

For authoritative country-specific data, consult the Awesome list for your target countries:

| Country | TSO | Data URL | Format |
|---------|-----|----------|--------|
| France | RTE | https://opendata.reseaux-energies.fr/ | GeoJSON, CSV (CC BY-SA 4.0) |
| Germany | Multiple TSOs | https://www.uebertragungsnetz.de/ | Shapefile, CSV |
| UK | National Grid ESO | https://data.nationalgrideso.com/ | GeoJSON, CSV |
| Australia | AEMO | https://www.aemo.com.au/ | Shapefile |
| New Zealand | Transpower | https://www.transpower.co.nz/ | PDF/KML |

```bash
# Example: Download French RTE grid data
wget "https://opendata.reseaux-energies.fr/api/datasets/1.0/lignes-aeriennes-rte/attachments/lignes_aeriennes_rte_geojson/" \
  -O /data/raw/rte-france-lines.geojson

tippecanoe -o /data/tiles/rte-france.mbtiles -l rte_lines -z14 -Z6 \
  /data/raw/rte-france-lines.geojson
```

---

## 4. Add to Tileserver Configuration

After generating tiles, add entries to `config/tileserver-config.json`:

```json
{
  "grid-lines": {
    "mbtiles": "/data/grid-lines.mbtiles"
  },
  "grid-substations": {
    "mbtiles": "/data/grid-substations.mbtiles"
  },
  "grid-generators": {
    "mbtiles": "/data/grid-generators.mbtiles"
  }
}
```

Restart tileserver:
```bash
docker compose restart tileserver
```

Verify:
```bash
curl http://localhost:8080/index.json | jq '.[].id'
```

---

## 5. MapLibre GL JS Visualization

```javascript
// Add grid lines source
map.addSource('grid', {
  type: 'vector',
  url: 'http://localhost:8080/data/grid-lines.json'
});

// Transmission lines colored by voltage
map.addLayer({
  id: 'transmission-lines',
  type: 'line',
  source: 'grid',
  'source-layer': 'grid_lines',
  paint: {
    'line-color': [
      'step', ['to-number', ['get', 'voltage'], 0],
      '#666666',     // Unknown
      110, '#2ca02c', // 110 kV — green
      220, '#ff7f0e', // 220 kV — orange
      345, '#d62728', // 345 kV — red
      500, '#9467bd', // 500 kV — purple
      765, '#1f77b4'  // 765 kV — blue
    ],
    'line-width': [
      'interpolate', ['linear'], ['zoom'],
      3, 0.5,
      8, 1.5,
      14, 3
    ],
    'line-opacity': 0.8
  }
});

// Substations
map.addSource('substations', {
  type: 'vector',
  url: 'http://localhost:8080/data/grid-substations.json'
});

map.addLayer({
  id: 'substations',
  type: 'circle',
  source: 'substations',
  'source-layer': 'grid_substations',
  paint: {
    'circle-color': '#ffcc00',
    'circle-radius': ['interpolate', ['linear'], ['zoom'], 5, 2, 14, 8],
    'circle-stroke-color': '#000',
    'circle-stroke-width': 1
  }
});
```

---

## 6. Comparison with Existing OSM Power Source

| Aspect | OSM via Geofabrik ([02c1](02c1-OSM-POWER.md)) | Awesome Grid Mapping (earth-osm) | Global Transmission DB |
|--------|------------------------------------------------|----------------------------------|----------------------|
| **Coverage** | Global (raw OSM tags) | Global (cleaned OSM extraction) | Global (research-grade) |
| **Data Quality** | Raw — includes incomplete/untagged | Cleaned — validated per feature type | Curated — network topology |
| **Attributes** | OSM tags (voltage, cables, operator) | Standardized (voltage, frequency, circuits) | Capacity, impedance, topology |
| **Network Topology** | No (just geometries) | Partial (per-country) | Yes (node-edge graph) |
| **Update** | Daily (Geofabrik mirrors) | Per extraction run | Periodic (Zenodo releases) |
| **Best For** | Broad infrastructure overlay | Country-specific analysis | Power flow / network modeling |

**Recommendation**: Use OSM via Geofabrik (source 11) for the general infrastructure overlay, and supplement with earth-osm or the Global Transmission Database for countries where you need validated, topology-aware grid data.

---

## 7. Related Pages

- **Parent**: [Electric Grid](02c-ELECTRIC.md)
- **Siblings**:
  - [OSM Power Infrastructure](02c1-OSM-POWER.md)
  - [EIA US Energy Atlas](02c2-EIA.md)
  - [HIFLD Open Data](02c3-HIFLD.md)
  - [ENTSO-E / GridKit](02c4-ENTSOE.md)
  - [Geoscience Australia](02c5-GEOSCIENCE-AU.md)
- **Related**:
  - [Data Pipeline](04-PIPELINE.md) — Download, convert, load workflow
  - [Conversion & Tippecanoe](04c-CONVERT.md) — Tippecanoe options for grid data
  - [Custom Layer Styling](07d-STYLING.md) — Voltage-based color schemes
  - [Cyber Attack Mapping](13a-CYBER-ATTACK-MAPPING.md) — Correlating attacks with grid infrastructure

---

## 8. References

Open Energy Transition. (2026). *Awesome Electrical Grid Mapping* [Data catalog]. GitHub. https://github.com/open-energy-transition/Awesome-Electrical-Grid-Mapping

MapYourGrid Initiative. (2026). *MapYourGrid: Global grid data*. https://mapyourgrid.org/global-grid-data/

Brown, T., Horsch, J., & Schlachtberger, D. (2018). PyPSA: Python for Power System Analysis. *Journal of Open Research Software*, 6(4). https://pypsa.org/

Parzen, M., et al. (2023). PyPSA-Earth: A new global open energy system optimization model demonstrated in Africa. *Applied Energy*, 341, 121096. https://pypsa-earth.readthedocs.io/

Arderne, C., et al. (2020). Predictive mapping of the global power system using open data. *Scientific Data*, 7, 19. https://gridfinder.rdrn.me/

Global Energy Monitor. (2026). *Global energy infrastructure tracker*. https://globalenergymonitor.org/
