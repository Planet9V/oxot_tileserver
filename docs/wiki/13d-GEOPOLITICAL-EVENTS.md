# Geopolitical News and Event Mapping

> **Last Updated**: 2026-02-11 02:00 UTC

[Home](INDEX.md) > [Use Cases](13-USE-CASES.md) > Geopolitical News and Event Mapping

---

## Overview

Infrastructure does not operate in geopolitical isolation. A pipeline bombing in one region, an election protest in another, or an earthquake swarm near a nuclear plant all have immediate relevance to operational security. This use case places global events -- armed conflicts, protests, elections, sanctions, natural disasters -- on the OXOT Tileserver map in near-real-time, exactly where they occur on the globe.

The core data sources are event databases that provide latitude, longitude, timestamp, event type, and narrative text for every recorded incident. The OXOT pipeline fetches these feeds on a schedule (15 minutes for GDELT, daily for ACLED), transforms them into GeoJSON FeatureCollections, converts to vector tiles, and serves them alongside existing infrastructure layers. Operators can then ask spatial questions such as "which substations are within 50 km of armed-conflict events in the last 30 days?" or "are there civil unrest patterns near our supply chain corridors?"

This page covers seven event and hazard data sources, implementation patterns for each, temporal animation, sanctions entity mapping, and correlation with OXOT infrastructure layers. Natural hazard overlays are documented in detail on the child page [Natural Hazard Overlays](13d1-NATURAL-HAZARDS.md).

---

## Data Sources

| Source | URL | Coverage | Update Cadence | Format | Access |
|--------|-----|----------|----------------|--------|--------|
| GDELT Project | https://www.gdeltproject.org/ | Global, 100+ languages | Every 15 minutes | GeoJSON API, CSV, BigQuery | Free |
| ACLED | https://acleddata.com/ | 200+ countries and territories | Weekly (real-time for subscribers) | JSON API, CSV | Free (registration required) |
| OCHA ReliefWeb | https://reliefweb.int/ | Global humanitarian crises | Continuous | JSON API | Free |
| USGS Earthquake Hazards | https://earthquake.usgs.gov/earthquakes/feed/v1.0/geojson.php | Global | Every minute | GeoJSON (native) | Free |
| NOAA Severe Weather | https://www.weather.gov/documentation/services-web-api | US, Atlantic, Pacific | Real-time | GeoJSON | Free |
| NASA FIRMS | https://firms.modaps.eosdis.nasa.gov/ | Global | Within 3 hours of satellite overpass | CSV, SHP, KML | Free (NASA Earthdata login) |
| OFAC Sanctions List | https://sanctionslist.ofac.treas.gov/ | Global entities | As updated | XML, CSV | Free |
| EU Sanctions Map | https://www.sanctionsmap.eu/ | Global entities | As updated | JSON | Free |

### Source Characteristics

| Source | Strengths | Limitations |
|--------|-----------|-------------|
| GDELT | Unmatched volume and temporal resolution; keyword search across global news | Geocoding derived from news text, not ground truth; duplicates possible |
| ACLED | Manually coded by trained researchers; high accuracy on conflict events | Weekly release for free tier; registration required |
| OCHA ReliefWeb | Authoritative humanitarian reporting from UN agencies | Lower geographic precision; narrative-heavy |
| USGS | Native GeoJSON; scientifically precise epicentre locations | Earthquakes only |
| NASA FIRMS | Satellite-validated fire detections; global daily coverage | 3-hour latency; thermal anomalies may include industrial sources |
| OFAC/EU Sanctions | Authoritative legal lists | Entity-based, not event-based; requires geocoding |

---

## GDELT Implementation

The GDELT Project monitors broadcast, print, and web news across 100+ languages, geocoding every event to a specific location. The GEO 2.0 API returns GeoJSON directly.

### Fetch Script (Python)

```python
import requests
import json
from datetime import datetime

def fetch_gdelt_events(query, timespan="24h", output_path="data/geojson/gdelt-events.geojson"):
    """Fetch geocoded GDELT events matching a keyword query."""
    url = "https://api.gdeltproject.org/api/v2/geo/geo"
    params = {
        "query": query,
        "mode": "PointData",
        "format": "GeoJSON",
        "timespan": timespan,
        "maxpoints": 5000
    }
    response = requests.get(url, params=params, timeout=30)
    response.raise_for_status()
    geojson = response.json()

    # Add fetch metadata
    geojson["properties"] = {
        "query": query,
        "timespan": timespan,
        "fetched_at": datetime.utcnow().isoformat() + "Z",
        "feature_count": len(geojson.get("features", []))
    }

    with open(output_path, "w") as f:
        json.dump(geojson, f)

    print(f"Wrote {geojson['properties']['feature_count']} features to {output_path}")
    return geojson


# Fetch events matching "cyberattack" in the last 24 hours
fetch_gdelt_events("cyberattack", timespan="24h")

# Fetch events matching "pipeline explosion" in the last 7 days
fetch_gdelt_events("pipeline explosion", timespan="7d",
                   output_path="data/geojson/gdelt-pipeline.geojson")
```

### Convert to Tiles

```bash
tippecanoe -o data/tiles/gdelt-events.mbtiles \
  -l gdelt_events \
  -z12 -Z2 \
  --drop-densest-as-needed \
  data/geojson/gdelt-events.geojson
```

### MapLibre Layer

```javascript
map.addSource('gdelt', {
  type: 'vector',
  url: 'http://localhost:8080/data/gdelt-events.json'
});

map.addLayer({
  id: 'gdelt-events-heat',
  type: 'heatmap',
  source: 'gdelt',
  'source-layer': 'gdelt_events',
  maxzoom: 9,
  paint: {
    'heatmap-weight': 1,
    'heatmap-intensity': ['interpolate', ['linear'], ['zoom'], 0, 1, 9, 3],
    'heatmap-color': [
      'interpolate', ['linear'], ['heatmap-density'],
      0, 'rgba(0,0,0,0)',
      0.2, '#ffffb2',
      0.4, '#fecc5c',
      0.6, '#fd8d3c',
      0.8, '#f03b20',
      1.0, '#bd0026'
    ],
    'heatmap-radius': ['interpolate', ['linear'], ['zoom'], 0, 2, 9, 20],
    'heatmap-opacity': 0.7
  }
});
```

---

## ACLED Implementation

The Armed Conflict Location and Event Data Project (ACLED) provides researcher-coded conflict events with precise geolocation, event type, actors, and fatality counts.

### Fetch Script (Python)

```python
import requests
import json

def fetch_acled_events(api_key, email, start_date, end_date,
                       output_path="data/geojson/acled-events.geojson"):
    """Fetch ACLED conflict events for a date range."""
    url = "https://api.acleddata.com/acled/read"
    params = {
        "key": api_key,
        "email": email,
        "event_date": f"{start_date}|{end_date}",
        "event_date_where": "BETWEEN",
        "limit": 5000
    }
    response = requests.get(url, params=params, timeout=60)
    response.raise_for_status()
    events = response.json().get("data", [])

    features = []
    for e in events:
        if not e.get("latitude") or not e.get("longitude"):
            continue
        features.append({
            "type": "Feature",
            "geometry": {
                "type": "Point",
                "coordinates": [float(e["longitude"]), float(e["latitude"])]
            },
            "properties": {
                "event_type": e.get("event_type", ""),
                "sub_event_type": e.get("sub_event_type", ""),
                "actor1": e.get("actor1", ""),
                "actor2": e.get("actor2", ""),
                "fatalities": int(e.get("fatalities", 0)),
                "country": e.get("country", ""),
                "admin1": e.get("admin1", ""),
                "date": e.get("event_date", ""),
                "notes": (e.get("notes", "") or "")[:200]
            }
        })

    geojson = {"type": "FeatureCollection", "features": features}
    with open(output_path, "w") as f:
        json.dump(geojson, f)

    print(f"Wrote {len(features)} ACLED events to {output_path}")
    return geojson
```

### MapLibre Layer -- Conflict Events by Type

```javascript
map.addLayer({
  id: 'acled-conflicts',
  type: 'circle',
  source: 'acled',
  'source-layer': 'acled_events',
  paint: {
    'circle-radius': [
      'interpolate', ['linear'], ['get', 'fatalities'],
      0, 4,
      10, 8,
      50, 14,
      100, 20
    ],
    'circle-color': [
      'match', ['get', 'event_type'],
      'Battles',                       '#e41a1c',
      'Violence against civilians',    '#ff7f00',
      'Explosions/Remote violence',    '#984ea3',
      'Protests',                      '#4daf4a',
      'Riots',                         '#ffff33',
      'Strategic developments',        '#377eb8',
      '#999999'
    ],
    'circle-opacity': 0.75,
    'circle-stroke-width': 1,
    'circle-stroke-color': '#ffffff'
  }
});
```

---

## USGS Earthquake Feed

The USGS Earthquake Hazards Program provides real-time earthquake data in native GeoJSON, making it the simplest source to integrate. No transformation is required.

### Fetch and Convert

```bash
# Download last 7 days, all magnitudes -- already valid GeoJSON
curl -o data/geojson/earthquakes.geojson \
  "https://earthquake.usgs.gov/earthquakes/feed/v1.0/summary/all_week.geojson"

# Convert directly to tiles
tippecanoe -o data/tiles/earthquakes.mbtiles \
  -l earthquakes \
  -z12 -Z2 \
  --drop-densest-as-needed \
  data/geojson/earthquakes.geojson
```

### MapLibre Layer -- Magnitude-Scaled Circles

```javascript
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

## NASA FIRMS Active Fire Data

The Fire Information for Resource Management System (FIRMS) distributes active fire detections from the VIIRS and MODIS satellite sensors. Detections are available within 3 hours of satellite overpass.

### Fetch and Convert

```bash
# Download VIIRS active fires for the last 24 hours (requires NASA Earthdata MAP_KEY)
curl -o data/raw/fires.csv \
  "https://firms.modaps.eosdis.nasa.gov/api/area/csv/YOUR_MAP_KEY/VIIRS_SNPP_NRT/world/1"

# Convert CSV to GeoJSON
python scripts/csv_to_geojson.py \
  --input data/raw/fires.csv \
  --output data/geojson/active-fires.geojson \
  --lat-col latitude \
  --lon-col longitude

# Convert to tiles
tippecanoe -o data/tiles/active-fires.mbtiles \
  -l active_fires \
  -z14 -Z2 \
  --drop-densest-as-needed \
  data/geojson/active-fires.geojson
```

The CSV-to-GeoJSON converter script is documented on the [Natural Hazard Overlays](13d1-NATURAL-HAZARDS.md) child page. Use `scripts/csv_to_geojson.py` for any CSV source with latitude and longitude columns.

---

## OCHA ReliefWeb Humanitarian Events

ReliefWeb provides structured disaster and crisis reports from UN agencies. Use the `/v1/disasters` endpoint with `appname=oxot-tileserver` to fetch recent disasters. ReliefWeb events are country-level; geocode them using a country-centroid lookup table (see `scripts/country_centroids.json`). The API documentation is at https://apidoc.rwlabs.org/.

---

## Temporal Animation

Events are most useful when viewed in temporal context. A time slider lets operators scrub through days or hours to observe event patterns.

### Time Slider Implementation

```html
<div id="time-control">
  <label for="time-slider">Event Timeline</label>
  <input type="range" id="time-slider" min="0" max="100" value="100">
  <span id="time-display"></span>
</div>
```

```javascript
// Set up temporal bounds from the data
const minDate = new Date('2026-01-01').getTime();
const maxDate = new Date('2026-02-11').getTime();

const slider = document.getElementById('time-slider');
const display = document.getElementById('time-display');

slider.addEventListener('input', (e) => {
  const pct = parseInt(e.target.value, 10) / 100;
  const cutoffMs = minDate + pct * (maxDate - minDate);
  const cutoffISO = new Date(cutoffMs).toISOString().slice(0, 10);

  display.textContent = cutoffISO;

  // Filter GDELT events by date
  map.setFilter('gdelt-events-heat', ['<=', ['get', 'date'], cutoffISO]);

  // Filter ACLED events by date
  map.setFilter('acled-conflicts', ['<=', ['get', 'date'], cutoffISO]);

  // Filter earthquakes by time (USGS uses millisecond epoch)
  map.setFilter('earthquake-circles', ['<=', ['get', 'time'], cutoffMs]);
});
```

For animated playback, use `requestAnimationFrame` to increment the slider value over a configurable duration (e.g., 30 seconds to replay 30 days). Call `slider.dispatchEvent(new Event('input'))` on each frame to trigger the filter update.

---

## Sanctions Entity Mapping

OFAC and EU sanctions lists are entity-based (persons, companies, vessels) rather than event-based. To place them on a map, the pipeline extracts addresses and countries from the sanctions data and geocodes them.

### OFAC SDN List Workflow

```bash
# Download the OFAC Specially Designated Nationals list
curl -o data/raw/sdn.xml \
  "https://sanctionslist.ofac.treas.gov/api/PublicationPreview/exports/SDN_ENHANCED.XML"
```

```python
import xml.etree.ElementTree as ET
import json

def parse_ofac_sdn(xml_path, output_path):
    tree = ET.parse(xml_path)
    root = tree.getroot()
    ns = {'sdn': root.tag.split('}')[0] + '}'}

    entities = []
    for entry in root.findall('.//sdn:sdnEntry', ns):
        name = entry.findtext('sdn:firstName', '', ns) + ' ' + \
               entry.findtext('sdn:lastName', '', ns)
        sdn_type = entry.findtext('sdn:sdnType', '', ns)

        for addr in entry.findall('.//sdn:address', ns):
            country = addr.findtext('sdn:country', '', ns)
            city = addr.findtext('sdn:city', '', ns)
            if country:
                entities.append({
                    "name": name.strip(),
                    "type": sdn_type,
                    "country": country,
                    "city": city or ""
                })

    # Geocoding step uses country/city centroids (batch geocoder or lookup table)
    # Output as GeoJSON after geocoding
    print(f"Parsed {len(entities)} sanctioned entities with addresses")
```

### Sanctions Display

```javascript
map.addLayer({
  id: 'sanctions-entities',
  type: 'circle',
  source: 'sanctions',
  'source-layer': 'ofac_sdn',
  paint: {
    'circle-radius': 6,
    'circle-color': [
      'match', ['get', 'type'],
      'Individual', '#e63946',
      'Entity',     '#457b9d',
      'Vessel',     '#2a9d8f',
      '#999999'
    ],
    'circle-stroke-width': 1.5,
    'circle-stroke-color': '#ffffff'
  }
});
```

---

## Correlating Events with Infrastructure

The analytical value of event mapping comes from spatial proximity queries against infrastructure layers.

| Query | Layers | Method |
|-------|--------|--------|
| Armed conflict near power plants | ACLED + [EIA](02c2-EIA.md) power plants | Buffer EIA plants by 50 km, intersect with ACLED points |
| Earthquakes near dams | USGS + [NID Dams](02d4-NID-DAMS.md) | Buffer dam locations, count earthquakes >= M4.0 in last year |
| Active fires near telecom towers | NASA FIRMS + [Telecoms](02e-TELECOMS.md) | 10 km buffer around towers, intersect with fire hotspots |
| Sanctions entities in supply chain countries | OFAC + supply chain routes | Country-level join to identify sanctioned-country exposure |
| Civil unrest near facilities | GDELT + [Facility Location](13b-FACILITY-BUILDING-LOCATION.md) | Buffer facility polygons, count protest events |

---

## Refresh Schedule

| Source | Recommended Cadence | Method |
|--------|---------------------|--------|
| GDELT | Every 15 minutes | Cron job calling fetch script |
| ACLED | Daily (free tier) or real-time (subscriber) | Daily cron job |
| USGS Earthquakes | Every 15 minutes | Cron job downloading GeoJSON feed |
| NASA FIRMS | Every 6 hours | Cron job with NASA Earthdata MAP_KEY |
| OCHA ReliefWeb | Daily | Cron job |
| OFAC Sanctions | Weekly | Cron job |

See [Updates & Scheduling](04e-MAINTENANCE.md) for cron configuration and the `tileserver-reload.sh` helper.

---

## Child Pages

| Page | Title | Description |
|------|-------|-------------|
| [13d1-NATURAL-HAZARDS.md](13d1-NATURAL-HAZARDS.md) | Natural Hazard Overlays | Detailed implementation for earthquakes, hurricanes, wildfires, floods, volcanoes, tsunamis, sea-level rise, and flood zones |

---

## References

ACLED. (2026). *Armed Conflict Location and Event Data Project*. https://acleddata.com/

GDELT Project. (2026). *GDELT: Global Database of Events, Language, and Tone*. https://www.gdeltproject.org/

Leetaru, K., & Schrodt, P. A. (2013). GDELT: Global data on events, location and tone, 1979-2012. *International Studies Association Annual Convention*. https://www.gdeltproject.org/

NASA. (2026). *Fire Information for Resource Management System (FIRMS)*. https://firms.modaps.eosdis.nasa.gov/

Raleigh, C., Linke, A., Hegre, H., & Karlsen, J. (2010). Introducing ACLED: An armed conflict location and event dataset. *Journal of Peace Research*, 47(5), 651-660. https://doi.org/10.1177/0022343310378914

U.S. Department of the Treasury. (2026). *Office of Foreign Assets Control (OFAC) sanctions list*. https://sanctionslist.ofac.treas.gov/

U.S. Geological Survey. (2026). *Earthquake Hazards Program real-time feeds*. https://earthquake.usgs.gov/earthquakes/feed/

United Nations Office for the Coordination of Humanitarian Affairs. (2026). *ReliefWeb*. https://reliefweb.int/

---

*[Home](INDEX.md) | [Use Cases](13-USE-CASES.md) | [Natural Hazards](13d1-NATURAL-HAZARDS.md) | [Facility Location](13b-FACILITY-BUILDING-LOCATION.md) | [Glossary](09-GLOSSARY.md)*
