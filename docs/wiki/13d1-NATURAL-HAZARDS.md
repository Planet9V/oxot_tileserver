# Natural Hazard Overlays

> **Last Updated**: 2026-02-11 02:00 UTC

[Home](INDEX.md) > [Use Cases](13-USE-CASES.md) > [Geopolitical Events](13d-GEOPOLITICAL-EVENTS.md) > Natural Hazard Overlays

---

## Overview

Natural hazards -- earthquakes, hurricanes, wildfires, floods, volcanic eruptions, and tsunamis -- are among the most consequential threats to critical infrastructure. A single magnitude-7 earthquake can disable substations, rupture water mains, and sever fibre-optic cables across an entire metropolitan area. The value of mapping these hazards on the OXOT Tileserver is not the hazard layer alone but its spatial correlation with infrastructure: which assets are exposed, how many people depend on those assets, and what is the cascading failure potential?

This page documents nine natural hazard data sources, their extraction and tiling workflows, MapLibre visualization patterns, and infrastructure correlation methods.

---

## Data Sources

| Hazard | Source | URL | Format | Update Cadence |
|--------|--------|-----|--------|----------------|
| Earthquakes | USGS Earthquake Hazards Program | https://earthquake.usgs.gov/earthquakes/feed/v1.0/geojson.php | GeoJSON (native) | Every minute |
| Hurricanes and Tropical Storms | NOAA National Hurricane Center (NHC) | https://www.nhc.noaa.gov/gis/ | Shapefile, KML | 6-hourly during hurricane season |
| Wildfires (active) | NASA FIRMS | https://firms.modaps.eosdis.nasa.gov/ | CSV, SHP | Within 3 hours of satellite overpass |
| Wildfire Risk (static) | USDA Wildland Fire Assessment System (WFAS) | https://www.wfas.net/ | GeoTIFF | Daily |
| Floods (event-based) | Copernicus Emergency Management Service | https://emergency.copernicus.eu/ | GeoTIFF, SHP | Event-activated |
| Flood Zones (US, static) | FEMA National Flood Hazard Layer (NFHL) | https://www.fema.gov/flood-maps/national-flood-hazard-layer | Geodatabase | As updated |
| Volcanoes | Smithsonian Global Volcanism Program (GVP) | https://volcano.si.edu/ | CSV, KML | Daily (alerts); database updated monthly |
| Tsunamis | NOAA National Centers for Environmental Information (NCEI) | https://www.ngdc.noaa.gov/hazard/tsu_db.shtml | CSV | Historical archive + real-time alerts |
| Sea Level Rise Projections | Climate Central Coastal Risk Screening Tool | https://coastal.climatecentral.org/ | GeoTIFF | Projection-based (static) |

---

## Earthquakes (USGS)

The USGS Earthquake Hazards Program publishes real-time feeds in native GeoJSON, making earthquakes the simplest natural hazard to integrate with the tileserver.

### Available Feeds

| Feed | URL Suffix | Scope |
|------|-----------|-------|
| Past hour, significant | `summary/significant_hour.geojson` | M4.5+ or felt |
| Past day, all magnitudes | `summary/all_day.geojson` | All detected |
| Past 7 days, all magnitudes | `summary/all_week.geojson` | All detected |
| Past 30 days, M2.5+ | `summary/2.5_month.geojson` | M2.5 and above |

### Fetch and Convert

```bash
# Download past 7 days, all magnitudes
curl -o data/geojson/earthquakes.geojson \
  "https://earthquake.usgs.gov/earthquakes/feed/v1.0/summary/all_week.geojson"

# Convert to tiles -- no transformation needed, already valid GeoJSON
tippecanoe -o data/tiles/earthquakes.mbtiles \
  -l earthquakes \
  -z12 -Z2 \
  --drop-densest-as-needed \
  data/geojson/earthquakes.geojson
```

### MapLibre Visualization

Earthquake magnitude maps naturally to both circle radius and colour intensity.

```javascript
map.addSource('earthquakes', {
  type: 'vector',
  url: 'http://localhost:8080/data/earthquakes.json'
});

map.addLayer({
  id: 'earthquake-circles',
  type: 'circle',
  source: 'earthquakes',
  'source-layer': 'earthquakes',
  paint: {
    'circle-radius': [
      'interpolate', ['exponential', 2], ['get', 'mag'],
      1, 2,
      3, 6,
      5, 14,
      7, 30
    ],
    'circle-color': [
      'interpolate', ['linear'], ['get', 'mag'],
      1, '#fee08b',
      3, '#fc8d59',
      5, '#d73027',
      7, '#67001f'
    ],
    'circle-opacity': 0.7,
    'circle-stroke-width': 1,
    'circle-stroke-color': '#333333'
  }
});
```

---

## Hurricanes and Tropical Storms (NOAA NHC)

The National Hurricane Center publishes GIS data for active and historical tropical cyclones, including forecast track lines, wind-speed probability cones, and watches/warnings.

### Available Datasets

| Dataset | Description | Geometry |
|---------|-------------|----------|
| Forecast Track | Predicted storm path (5-day cone) | LineString + Polygon |
| Wind Speed Probabilities | Probability of sustained winds exceeding thresholds | Polygon |
| Watches and Warnings | Coastal segments under watch or warning | LineString |
| Best Track (HURDAT2) | Historical storm tracks since 1851 | LineString + Point |

### Fetch and Convert

```bash
# Download active storm advisory shapefile (during hurricane season)
wget "https://www.nhc.noaa.gov/gis/forecast/archive/latest_forecasttrack.zip" \
  -O data/raw/storm-track.zip

unzip data/raw/storm-track.zip -d data/raw/storm-track/

# Convert Shapefile to GeoJSON
ogr2ogr -f GeoJSON data/geojson/storm-track.geojson \
  data/raw/storm-track/*.shp

# Convert to tiles
tippecanoe -o data/tiles/storm-track.mbtiles \
  -l storm_track \
  -z10 -Z2 \
  data/geojson/storm-track.geojson
```

### MapLibre Visualization -- Storm Track

```javascript
map.addLayer({
  id: 'storm-track-line',
  type: 'line',
  source: 'storms',
  'source-layer': 'storm_track',
  paint: {
    'line-color': [
      'match', ['get', 'STORMTYPE'],
      'HU', '#e41a1c',   // Hurricane
      'TS', '#ff7f00',   // Tropical Storm
      'TD', '#ffff33',   // Tropical Depression
      '#999999'
    ],
    'line-width': 3
  }
});
```

---

## Wildfires -- Active Detections (NASA FIRMS)

See the [Geopolitical Events](13d-GEOPOLITICAL-EVENTS.md) page for the full FIRMS fetch-and-convert workflow. The summary below covers the MapLibre heatmap rendering optimized for fire data.

### Heatmap Layer

```javascript
map.addLayer({
  id: 'fire-heatmap',
  type: 'heatmap',
  source: 'active-fires',
  'source-layer': 'active_fires',
  maxzoom: 12,
  paint: {
    'heatmap-weight': [
      'interpolate', ['linear'], ['get', 'bright_ti4'],
      300, 0,
      400, 1
    ],
    'heatmap-intensity': ['interpolate', ['linear'], ['zoom'], 0, 1, 12, 3],
    'heatmap-color': [
      'interpolate', ['linear'], ['heatmap-density'],
      0, 'rgba(0,0,0,0)',
      0.2, '#fed976',
      0.4, '#feb24c',
      0.6, '#fd8d3c',
      0.8, '#fc4e2a',
      1.0, '#b10026'
    ],
    'heatmap-radius': ['interpolate', ['linear'], ['zoom'], 0, 4, 12, 20],
    'heatmap-opacity': 0.8
  }
});
```

---

## Wildfires -- Static Risk (USDA WFAS)

The Wildland Fire Assessment System provides daily fire-danger rating maps as raster GeoTIFFs. These can be converted to vector tiles by reclassifying the raster into polygons.

### Raster-to-Vector Workflow

```bash
# Download fire danger rating GeoTIFF
wget "https://www.wfas.net/images/firedanger/fd_class.tif" \
  -O data/raw/fire-danger.tif

# Polygonize raster classes
gdal_polygonize.py data/raw/fire-danger.tif \
  -f GeoJSON data/geojson/fire-danger.geojson

# Simplify and convert to tiles
tippecanoe -o data/tiles/fire-danger.mbtiles \
  -l fire_danger \
  -z10 -Z2 \
  --simplification=10 \
  data/geojson/fire-danger.geojson
```

---

## Floods -- Event-Based (Copernicus EMS)

The Copernicus Emergency Management Service produces flood-extent maps when activated for a specific disaster. These are distributed as shapefiles and GeoTIFFs.

### Workflow

1. Browse activations at https://emergency.copernicus.eu/.
2. Download the delineation product (shapefile) for the relevant activation.
3. Convert with `ogr2ogr` and tile with `tippecanoe`.

```bash
ogr2ogr -f GeoJSON data/geojson/flood-extent.geojson \
  data/raw/copernicus-flood/observed_event_a.shp

tippecanoe -o data/tiles/flood-extent.mbtiles \
  -l flood_extent \
  -z14 -Z6 \
  data/geojson/flood-extent.geojson
```

### MapLibre Visualization

```javascript
map.addLayer({
  id: 'flood-extent',
  type: 'fill',
  source: 'floods',
  'source-layer': 'flood_extent',
  paint: {
    'fill-color': '#1d91c0',
    'fill-opacity': 0.4
  }
});
```

---

## Flood Zones -- Static (FEMA NFHL)

The FEMA National Flood Hazard Layer provides regulatory flood zones for the entire United States. These zones (A, AE, V, X, etc.) determine insurance requirements and building codes.

### Download and Convert

```bash
# Download NFHL geodatabase for a state (example: Texas)
wget "https://hazards.fema.gov/nfhlv2/output/State/NFHL_48_20260101.zip" \
  -O data/raw/nfhl-texas.zip

unzip data/raw/nfhl-texas.zip -d data/raw/nfhl-texas/

# Extract flood hazard areas
ogr2ogr -f GeoJSON data/geojson/fema-flood-zones.geojson \
  data/raw/nfhl-texas/NFHL_48.gdb \
  S_Fld_Haz_Ar \
  -spat -97.5 29.5 -97.0 30.0  # Clip to Austin area

# Convert to tiles
tippecanoe -o data/tiles/fema-flood-zones.mbtiles \
  -l fema_flood_zones \
  -z14 -Z8 \
  --coalesce-densest-as-needed \
  data/geojson/fema-flood-zones.geojson
```

### MapLibre Visualization

```javascript
map.addLayer({
  id: 'fema-flood-zones',
  type: 'fill',
  source: 'fema-floods',
  'source-layer': 'fema_flood_zones',
  paint: {
    'fill-color': [
      'match', ['get', 'FLD_ZONE'],
      'A',  '#08519c',
      'AE', '#3182bd',
      'AH', '#6baed6',
      'AO', '#9ecae1',
      'V',  '#08306b',
      'VE', '#08519c',
      'X',  '#deebf7',
      '#f0f0f0'
    ],
    'fill-opacity': 0.5
  }
});
```

---

## Volcanoes (Smithsonian GVP)

The Smithsonian Global Volcanism Program maintains a database of Holocene volcanoes worldwide with eruption history, alert levels, and precise summit coordinates.

### Fetch and Convert

```bash
# Download the GVP volcano list (CSV export)
curl -o data/raw/gvp-volcanoes.csv \
  "https://volcano.si.edu/database/list_volcano_holocene.cfm?format=csv"

# Convert to GeoJSON using the CSV converter
python scripts/csv_to_geojson.py \
  --input data/raw/gvp-volcanoes.csv \
  --output data/geojson/volcanoes.geojson \
  --lat-col Latitude \
  --lon-col Longitude

# Convert to tiles
tippecanoe -o data/tiles/volcanoes.mbtiles \
  -l volcanoes \
  -z12 -Z2 \
  data/geojson/volcanoes.geojson
```

### MapLibre Visualization

```javascript
map.addLayer({
  id: 'volcano-points',
  type: 'circle',
  source: 'volcanoes',
  'source-layer': 'volcanoes',
  paint: {
    'circle-radius': 6,
    'circle-color': '#e63946',
    'circle-stroke-width': 2,
    'circle-stroke-color': '#ffffff'
  }
});
```

---

## Tsunamis (NOAA NCEI)

The NOAA National Centers for Environmental Information maintains a historical tsunami database and issues real-time tsunami alerts through the Tsunami Warning Centers.

### Historical Data

```bash
curl -o data/raw/tsunami-events.csv \
  "https://www.ngdc.noaa.gov/hazel/hazard-service/api/v1/tsunamis/events?format=csv"

python scripts/csv_to_geojson.py \
  --input data/raw/tsunami-events.csv \
  --output data/geojson/tsunami-events.geojson \
  --lat-col LATITUDE \
  --lon-col LONGITUDE

tippecanoe -o data/tiles/tsunamis.mbtiles \
  -l tsunamis \
  -z10 -Z2 \
  data/geojson/tsunami-events.geojson
```

---

## Sea Level Rise (Climate Central)

Climate Central provides modelled inundation zones for various sea-level-rise scenarios (1 m, 2 m, 3 m). These GeoTIFF rasters can be polygonized and tiled.

### Workflow

```bash
# Polygonize the 1-metre rise scenario
gdal_polygonize.py data/raw/slr-1m.tif \
  -f GeoJSON data/geojson/slr-1m.geojson

tippecanoe -o data/tiles/sea-level-rise.mbtiles \
  -l sea_level_rise \
  -z12 -Z4 \
  --simplification=10 \
  data/geojson/slr-1m.geojson
```

---

## Correlating Hazards with Infrastructure

The following table summarises the most valuable spatial overlays between hazard layers and OXOT infrastructure layers.

| Hazard Layer | Infrastructure Layer | Wiki Page | Analytical Question |
|-------------|---------------------|-----------|---------------------|
| Earthquake epicentres | Electric grid (substations, transmission lines) | [EIA](02c2-EIA.md), [HIFLD](02c3-HIFLD.md) | Which substations have experienced M5.0+ events within 25 km in the past decade? |
| FEMA flood zones | Water treatment plants | [EPA SDWIS](02d2-EPA-SDWIS.md) | Which drinking water systems are in 100-year flood zones? |
| Active wildfires | Telecom towers | [Telecoms](02e-TELECOMS.md) | Are any active fire hotspots within 5 km of cell towers? |
| Storm tracks | Dams | [NID Dams](02d4-NID-DAMS.md) | Which dams are in the forecast cone of an active hurricane? |
| Sea level rise | All coastal infrastructure | [Data Sources](02-DATA-SOURCES.md) | What percentage of coastal infrastructure is at risk from 1 m sea-level rise? |
| Volcanic alerts | Nearby facilities | [Facility Location](13b-FACILITY-BUILDING-LOCATION.md) | Which customer facilities are within 100 km of a volcano with elevated alert level? |

### Spatial Query Pattern (Turf.js)

```javascript
import * as turf from '@turf/turf';

// Find all substations within 25 km of M5.0+ earthquakes
function findExposedSubstations(earthquakes, substations, radiusKm, minMagnitude) {
  const significant = earthquakes.features.filter(
    f => f.properties.mag >= minMagnitude
  );

  const exposed = [];
  substations.features.forEach(sub => {
    for (const eq of significant) {
      const dist = turf.distance(
        turf.point(sub.geometry.coordinates),
        turf.point(eq.geometry.coordinates),
        { units: 'kilometers' }
      );
      if (dist <= radiusKm) {
        exposed.push({
          substation: sub.properties,
          earthquake: eq.properties,
          distance_km: Math.round(dist * 10) / 10
        });
        break;
      }
    }
  });

  return exposed;
}
```

---

## Refresh Schedule

| Hazard | Refresh | Rationale |
|--------|---------|-----------|
| USGS Earthquakes | Every 15 minutes | Near-real-time seismic monitoring |
| NASA FIRMS fires | Every 6 hours | Satellite revisit cadence |
| NOAA NHC storms | 6-hourly during season | Advisory cycle |
| Copernicus flood extent | On activation | Event-driven |
| FEMA NFHL flood zones | Annually | Regulatory map updates |
| GVP Volcanoes | Monthly | Database update cycle |
| NOAA Tsunamis | On alert | Event-driven |
| Climate Central SLR | Static | Projection-based, no refresh needed |

---

## References

Climate Central. (2025). *Coastal Risk Screening Tool*. https://coastal.climatecentral.org/

Copernicus Emergency Management Service. (2026). *Rapid mapping activations*. European Commission. https://emergency.copernicus.eu/

Federal Emergency Management Agency. (2026). *National Flood Hazard Layer (NFHL)*. https://www.fema.gov/flood-maps/national-flood-hazard-layer

NASA. (2026). *Fire Information for Resource Management System (FIRMS)*. https://firms.modaps.eosdis.nasa.gov/

National Oceanic and Atmospheric Administration. (2026). *National Hurricane Center GIS data*. https://www.nhc.noaa.gov/gis/

National Oceanic and Atmospheric Administration. (2026). *NCEI historical tsunami database*. https://www.ngdc.noaa.gov/hazard/tsu_db.shtml

Smithsonian Institution. (2026). *Global Volcanism Program*. https://volcano.si.edu/

U.S. Department of Agriculture. (2026). *Wildland Fire Assessment System*. https://www.wfas.net/

U.S. Geological Survey. (2026). *Earthquake Hazards Program real-time feeds*. https://earthquake.usgs.gov/earthquakes/feed/

---

*[Home](INDEX.md) | [Use Cases](13-USE-CASES.md) | [Geopolitical Events](13d-GEOPOLITICAL-EVENTS.md) | [Facility Location](13b-FACILITY-BUILDING-LOCATION.md) | [Socioeconomic Analysis](13c-SOCIOECONOMIC-ANALYSIS.md)*
