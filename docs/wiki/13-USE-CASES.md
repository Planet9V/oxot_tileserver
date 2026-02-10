# Use Cases

> **Last Updated**: 2026-02-11 02:00 UTC


[Home](INDEX.md)

---

## Overview

The OXOT Tileserver serves as the geographic intelligence backbone for multiple operational domains beyond static infrastructure visualization. While sections 02 through 07 of this wiki document the standard data pipeline -- downloading, converting, and serving authoritative infrastructure data -- this section documents eight primary use case categories that extend the tileserver into an active operational platform.

Each use case follows a common pattern: external data sources are fetched through APIs or feeds, transformed into GeoJSON, converted to vector tiles with tippecanoe, and served through tileserver-gl alongside existing infrastructure layers. The value of these use cases comes from overlaying dynamic, domain-specific intelligence on top of the static infrastructure basemap -- answering questions such as "which substations are near the origin of this attack?" or "what is the socioeconomic profile of the population served by this water treatment plant?"

This section assumes the reader has a running OXOT Tileserver deployment (see [Installation & Setup](03-INSTALLATION.md)) and is comfortable with the custom tile creation workflow documented in [Custom Tile Creation](07-CUSTOM-TILES.md).

---

## Use Case Categories

| # | Use Case | Domain | Key Data Sources | Child Page | Complexity |
|---|----------|--------|------------------|------------|------------|
| 1 | Cyber Attack Origin/Destination Mapping | Cybersecurity | MaxMind, AbuseIPDB, GreyNoise, OTX AlienVault | [13a](13a-CYBER-ATTACK-MAPPING.md) | Medium |
| 2 | IP Address Geolocation | Network Intelligence | MaxMind GeoLite2/GeoIP2, IP2Location, BGP/ASN data | [13a1](13a1-IP-GEOLOCATION.md) | Low--Medium |
| 3 | Threat Intelligence Feeds | Cybersecurity | OTX, MISP, Abuse.ch, Emerging Threats, GreyNoise | [13a2](13a2-THREAT-INTELLIGENCE-FEEDS.md) | Medium |
| 4 | Facility and Building Location | Physical Security | OSM, Microsoft Building Footprints, Overture Maps | [13b](13b-FACILITY-BUILDING-LOCATION.md) | Medium |
| 5 | Socioeconomic Risk Analysis | Risk Assessment | US Census ACS, Eurostat, World Bank Open Data | [13c](13c-SOCIOECONOMIC-ANALYSIS.md) | Medium |
| 6 | Geopolitical Event Tracking | Situational Awareness | GDELT, ACLED, OCHA ReliefWeb | [13d](13d-GEOPOLITICAL-EVENTS.md) | Medium--High |
| 7 | Natural Hazard Overlays | Resilience Planning | USGS Earthquake Hazards, NOAA Storm Events, NASA FIRMS | [13d1](13d1-NATURAL-HAZARDS.md) | Low--Medium |
| 8 | Supply Chain Mapping | Logistics / SCRM | MarineTraffic AIS, UN Comtrade, Open Supply Hub | Planned | High |

---

## Common Implementation Pattern

Every use case in this section follows the same five-stage pipeline:

```
External Source       Fetch Script        GeoJSON            tippecanoe          tileserver-gl
(API / Feed / File)   (Python / Node)     (FeatureCollection) (.mbtiles output)   (serves PBF tiles)
       |                    |                    |                    |                    |
       +-----> fetch ------>+-----> transform -->+-----> convert ---->+-----> reload ----->+
                                                                                          |
                                                                               MapLibre GL JS client
```

### Stage 1 -- Fetch

Retrieve raw data from the external source. This is typically an HTTP GET to a REST API with an API key, or a download of a static file. Most sources in this section offer JSON or CSV responses. Store the raw response in `data/raw/` for auditability.

### Stage 2 -- Transform

Parse the raw data, extract geographic coordinates, and construct a GeoJSON FeatureCollection. Each Feature should include:

- **geometry** -- Point, LineString, or Polygon with WGS 84 coordinates
- **properties** -- all relevant attributes for filtering, styling, and display

Write the output to `data/geojson/` using a descriptive filename such as `attack-sources-2026-02-11.geojson`.

### Stage 3 -- Convert

Run tippecanoe to produce an MBTiles file:

```bash
tippecanoe -o data/tiles/<layer-name>.mbtiles \
  -l <layer_name> \
  -z14 -Z2 \
  --drop-densest-as-needed \
  data/geojson/<input>.geojson
```

Consult [Conversion & Tippecanoe](04c-CONVERT.md) for the full set of tippecanoe flags relevant to the OXOT pipeline.

### Stage 4 -- Load

Add the new tileset to `tileserver-config.json`:

```json
{
  "data": {
    "layer-name": {
      "mbtiles": "data/tiles/layer-name.mbtiles"
    }
  }
}
```

See [Loading & Verification](04d-LOAD.md) for the complete configuration reference.

### Stage 5 -- Serve and Visualize

Restart tileserver-gl to pick up the new tileset, then add the source and layer in MapLibre GL JS:

```javascript
map.addSource('layer-name', {
  type: 'vector',
  url: 'http://localhost:8080/data/layer-name.json'
});

map.addLayer({
  id: 'layer-name-points',
  type: 'circle',
  source: 'layer-name',
  'source-layer': 'layer_name',
  paint: {
    'circle-radius': 5,
    'circle-color': '#e63946'
  }
});
```

---

## Pre-conditions for All Use Cases

Before implementing any use case in this section, verify the following:

| Pre-condition | How to Verify | Reference |
|---------------|---------------|-----------|
| OXOT Tileserver running | `curl http://localhost:8080/health` returns `200 OK` | [Docker Deployment](03a-DOCKER-SETUP.md) |
| At least one basemap installed | TileJSON endpoint returns tileset metadata | [Installation Options](03b-OPTIONS.md) |
| tippecanoe available in converter | `docker compose run converter tippecanoe --version` | [Converter Container](03c-CONVERTER.md) |
| MapLibre GL JS client app | A web page loading `maplibre-gl` v4.x or later | [MapLibre GL JS](06a-MAPLIBRE.md) |
| Python 3.10+ or Node.js 20+ | For fetch and transform scripts | [System Requirements](01c-REQUIREMENTS.md) |

---

## Integration Architecture

The following diagram shows how use case data flows from external sources through the OXOT pipeline to the client.

```
+---------------------------+     +---------------------------+     +---------------------+
|   EXTERNAL DATA SOURCES   |     |   OXOT DATA PIPELINE      |     |   CLIENT APPS       |
|                           |     |                           |     |                     |
|  AbuseIPDB API      ---+  |     |  data/raw/          ---+  |     |  MapLibre GL JS     |
|  MaxMind GeoLite2   ---+--+---->|  data/geojson/      ---+--+---->|  deck.gl overlays   |
|  OTX AlienVault     ---+  |     |  data/tiles/*.mbtiles  |  |     |  OXOT Cyber DT      |
|  MISP / STIX feeds  ---+  |     |                        |  |     |  Leaflet / OL       |
|  GreyNoise          ---+  |     |  tileserver-config.json|  |     |                     |
|  USGS / NOAA        ---+  |     |  tileserver-gl :8080   |  |     |                     |
|  GDELT / ACLED      ---+  |     +------------------------+--+     +---------------------+
+---------------------------+              |
                                           v
                                   +---------------+
                                   | docker compose|
                                   | tileserver    |
                                   | converter     |
                                   +---------------+
```

---

## Automation and Scheduling

Most use cases benefit from periodic data refresh. The recommended approach uses cron (or a container-native scheduler) to re-run the fetch-transform-convert pipeline at an interval appropriate to the data source.

| Refresh Cadence | Use Cases | Rationale |
|-----------------|-----------|-----------|
| Every 15 minutes | Cyber attack mapping, threat feeds | Near-real-time threat visibility |
| Hourly | IP geolocation aggregates, Tor exit nodes | Moderate change frequency |
| Daily | Natural hazards, geopolitical events | Event-driven but not real-time |
| Weekly | Socioeconomic data, facility data | Census and registry update cycles |

See [Updates & Scheduling](04e-MAINTENANCE.md) for cron configuration and the `tileserver-reload.sh` script.

---

## Correlating Use Case Layers with Infrastructure

The primary analytical value of these use cases comes from spatial correlation with the existing infrastructure layers documented in [Data Sources](02-DATA-SOURCES.md). For example:

- **Cyber attacks + Electric grid**: Which substations (from [EIA](02c2-EIA.md) or [HIFLD](02c3-HIFLD.md)) are in cities that are frequent attack targets?
- **Threat intelligence + Water**: Are any known command-and-control servers geolocated near water treatment facilities (from [EPA SDWIS](02d2-EPA-SDWIS.md))?
- **Natural hazards + Telecoms**: Which cell towers (from [OSM Telecoms](02e-TELECOMS.md)) are inside a flood zone or earthquake risk area?

MapLibre GL JS provides `queryRenderedFeatures()` and `querySourceFeatures()` for client-side spatial queries across multiple layers. For server-side correlation, export GeoJSON from both layers and use a spatial join library such as Turf.js (`@turf/turf` on npm) or GeoPandas (`geopandas` on PyPI).

---

## Security Considerations

Several use cases in this section involve API keys and sensitive operational data. Observe the following:

- **API keys**: Store all API keys in the `.env` file. Never commit keys to version control. See [Environment Configuration](03d-ENVIRONMENT.md).
- **Rate limits**: Respect source API rate limits. AbuseIPDB allows 1,000 checks per day on the free tier. OTX AlienVault allows 10,000 requests per hour. Build fetch scripts with retry logic and exponential backoff.
- **Data sensitivity**: Threat intelligence data may contain indicators tied to active investigations. Apply appropriate access controls to `data/raw/` and `data/geojson/` directories.
- **Network isolation**: The tileserver serves data within your network. Do not expose port 8080 to the public internet without authentication. See [Operations & Maintenance](08-OPERATIONS.md).

---

## Child Pages

| Page | Title | Description |
|------|-------|-------------|
| [13a-CYBER-ATTACK-MAPPING.md](13a-CYBER-ATTACK-MAPPING.md) | Cyber Attack Origin and Destination Mapping | Flagship cybersecurity use case: visualize attack sources, destinations, and arcs |
| [13a1-IP-GEOLOCATION.md](13a1-IP-GEOLOCATION.md) | IP Address Geolocation | Deep-dive on IP-to-location databases, accuracy, and VPN/proxy detection |
| [13a2-THREAT-INTELLIGENCE-FEEDS.md](13a2-THREAT-INTELLIGENCE-FEEDS.md) | Threat Intelligence Feeds | Deep-dive on open and commercial TI feeds with geographic data |
| [13b-FACILITY-BUILDING-LOCATION.md](13b-FACILITY-BUILDING-LOCATION.md) | Physical Facility and Building Location | Building footprints, facility metadata, 3D extrusion, indoor mapping, security perimeters |
| [13c-SOCIOECONOMIC-ANALYSIS.md](13c-SOCIOECONOMIC-ANALYSIS.md) | Socioeconomic and Demographic Analysis | Census demographics, vulnerability indices, impact radius, environmental justice |
| [13d-GEOPOLITICAL-EVENTS.md](13d-GEOPOLITICAL-EVENTS.md) | Geopolitical News and Event Mapping | GDELT, ACLED, OCHA ReliefWeb, sanctions mapping, temporal animation |
| [13d1-NATURAL-HAZARDS.md](13d1-NATURAL-HAZARDS.md) | Natural Hazard Overlays | Earthquakes, hurricanes, wildfires, floods, volcanoes, tsunamis, sea-level rise |

---

## References

AbuseIPDB. (2026). *AbuseIPDB: IP address abuse reports and blocklist*. https://www.abuseipdb.com/

ACLED. (2026). *Armed Conflict Location and Event Data*. https://acleddata.com/

GDELT Project. (2026). *GDELT: Global Database of Events, Language, and Tone*. https://www.gdeltproject.org/

GreyNoise Intelligence. (2026). *GreyNoise: Internet-wide scanner and attack telemetry*. https://www.greynoise.io/

LevelBlue. (2026). *Open Threat Exchange (OTX)*. https://otx.alienvault.com/

MapLibre. (2026). *MapLibre GL JS documentation*. https://maplibre.org/maplibre-gl-js/docs/

MaxMind. (2026). *GeoLite2 free geolocation data*. https://dev.maxmind.com/geoip/geolite2-free-geolocation-data

Felt. (2026). *Tippecanoe: Build vector tilesets from large collections of GeoJSON features*. https://github.com/felt/tippecanoe

Turf.js. (2026). *Turf: Advanced geospatial analysis for browsers and Node.js*. https://turfjs.org/

---

*[Home](INDEX.md) | [Custom Tile Creation](07-CUSTOM-TILES.md) | [API Reference](05-API.md) | [Data Sources](02-DATA-SOURCES.md)*
