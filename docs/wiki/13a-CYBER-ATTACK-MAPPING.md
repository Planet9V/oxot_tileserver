# Cyber Attack Origin and Destination Mapping

> **Last Updated**: 2026-02-11 02:00 UTC

[Home](INDEX.md) > [Use Cases](13-USE-CASES.md) > Cyber Attack Mapping

---

## Executive Summary

This use case visualizes the geographic origin and destination of cyber attacks on the OXOT Tileserver map. Attack source IPs are geolocated using MaxMind databases, enriched with threat intelligence from AbuseIPDB and OTX AlienVault, and rendered as heatmaps at low zoom levels and discrete points at high zoom levels. Attack arcs connecting source and destination can be drawn with deck.gl. When overlaid on the tileserver's existing infrastructure layers -- electric grid substations, water treatment plants, telecom towers -- the result is an operational picture that answers: "Who is attacking what, and from where?"

This is the flagship cybersecurity use case for the OXOT Tileserver and the primary reason for the tileserver's integration into the [OXOT Cyber Digital Twin](06d-OXOT-CYBERDT.md).

---

## Data Sources

### Free and Open Source

| Source | URL | Data Provided | Update Frequency | Format | API Key |
|--------|-----|---------------|------------------|--------|---------|
| MaxMind GeoLite2 City | https://dev.maxmind.com/geoip/geolite2-free-geolocation-data | IP to city, country, coordinates; approximately 68% city-level accuracy | Weekly (Tuesdays) | MMDB binary | Free with registration |
| AbuseIPDB | https://www.abuseipdb.com/ | IP abuse reports with confidence scores (0--100), abuse categories, reporter counts | Real-time API | JSON REST | Free: 1,000 checks/day |
| OTX AlienVault | https://otx.alienvault.com/ | Threat Pulses containing IOCs (IPs, domains, URLs, hashes); 19M+ indicators per day from 140+ countries | Real-time API | JSON REST | Free with registration |
| MISP | https://www.misp-project.org/ | Community threat intelligence; structured events with attributes including ip-src, ip-dst, geolocation | Real-time API | STIX 2.1, MISP JSON | Self-hosted |
| Emerging Threats (Proofpoint) | https://rules.emergingthreats.net/ | IP reputation lists, Suricata/Snort rule sets with IP indicators | Daily | Text IP lists | Free (open ruleset) |
| Abuse.ch Feodo Tracker | https://feodotracker.abuse.ch/ | Botnet C2 server IPs (Dridex, Emotet, TrickBot, QakBot families) | Real-time | CSV, JSON | Free, no key |

### Commercial

| Source | URL | Data Provided | Pricing |
|--------|-----|---------------|---------|
| MaxMind GeoIP2 City | https://www.maxmind.com/en/geoip2-city | Approximately 83% city accuracy, confidence radius, ISP/organization, connection type | From $100/month |
| GreyNoise Enterprise | https://www.greynoise.io/ | Internet scanning and exploitation intelligence; geo-destination data; 8,000+ IPs/day classified as benign/malicious | Community (free, limited) / Enterprise |
| Shodan | https://www.shodan.io/ | Exposed devices (IoT, ICS/SCADA), geolocation, service banners, CVE mapping | Free (limited) / $69/month member |
| Recorded Future | https://www.recordedfuture.com/ | Comprehensive threat intelligence with geographic attribution, APT tracking | Enterprise pricing |
| CrowdStrike Falcon Intelligence | https://www.crowdstrike.com/ | Adversary profiles with nation-state attribution, campaign tracking with geographic origin | Enterprise pricing |

---

## Implementation

### Step 1: Fetch Attack Data

The following Python script fetches the AbuseIPDB blocklist and geolocates each IP using the MaxMind GeoLite2 City database. The output is a GeoJSON FeatureCollection ready for tippecanoe.

**Prerequisites**:
- `pip install requests geoip2`
- Download `GeoLite2-City.mmdb` from https://dev.maxmind.com/geoip/geolite2-free-geolocation-data and place it in `data/raw/`.
- Set `ABUSEIPDB_API_KEY` in your `.env` file.

```python
#!/usr/bin/env python3
"""Fetch AbuseIPDB blocklist and geolocate IPs to GeoJSON."""

import json
import os
from datetime import datetime, timezone

import geoip2.database
import requests

API_KEY = os.environ["ABUSEIPDB_API_KEY"]
MMDB_PATH = "data/raw/GeoLite2-City.mmdb"
OUTPUT_PATH = "data/geojson/attack-sources.geojson"

# Fetch the AbuseIPDB blocklist (top 10,000 IPs with >=90 confidence)
headers = {"Key": API_KEY, "Accept": "application/json"}
response = requests.get(
    "https://api.abuseipdb.com/api/v2/blacklist",
    headers=headers,
    params={"confidenceMinimum": 90, "limit": 10000},
    timeout=30,
)
response.raise_for_status()
blacklist = response.json()["data"]

# Geolocate each IP
reader = geoip2.database.Reader(MMDB_PATH)
features = []

for entry in blacklist:
    ip = entry["ipAddress"]
    try:
        geo = reader.city(ip)
        if geo.location.latitude is None or geo.location.longitude is None:
            continue
        features.append({
            "type": "Feature",
            "geometry": {
                "type": "Point",
                "coordinates": [geo.location.longitude, geo.location.latitude],
            },
            "properties": {
                "ip": ip,
                "abuse_score": entry["abuseConfidenceScore"],
                "country_iso": geo.country.iso_code or "",
                "country_name": geo.country.name or "",
                "city": geo.city.name or "Unknown",
                "latitude": geo.location.latitude,
                "longitude": geo.location.longitude,
                "accuracy_radius_km": geo.location.accuracy_radius,
                "isp": entry.get("isp", ""),
                "total_reports": entry.get("totalReports", 0),
                "last_reported": entry.get("lastReportedAt", ""),
                "category": "attack_source",
                "fetched_at": datetime.now(timezone.utc).isoformat(),
            },
        })
    except geoip2.errors.AddressNotFoundError:
        continue

reader.close()

geojson = {"type": "FeatureCollection", "features": features}
with open(OUTPUT_PATH, "w") as f:
    json.dump(geojson, f, indent=2)

print(f"Wrote {len(features)} features to {OUTPUT_PATH}")
```

### Step 2: Convert to Vector Tiles

Run tippecanoe to produce an MBTiles file. The flags below enable point clustering at low zoom levels and preserve all attributes for popup display at high zoom levels.

```bash
tippecanoe -o data/tiles/attack-sources.mbtiles \
  -l attack_sources \
  -z14 -Z2 \
  --cluster-distance=50 \
  --accumulate-attribute=total_reports:sum \
  --accumulate-attribute=abuse_score:max \
  --drop-densest-as-needed \
  --force \
  data/geojson/attack-sources.geojson
```

**Flag reference**:

| Flag | Purpose |
|------|---------|
| `-l attack_sources` | Names the vector tile layer |
| `-z14 -Z2` | Zoom range: 2 (continental) to 14 (street-level) |
| `--cluster-distance=50` | Cluster points within 50 pixels at lower zooms |
| `--accumulate-attribute=total_reports:sum` | Sum report counts when clustering |
| `--accumulate-attribute=abuse_score:max` | Keep highest abuse score in each cluster |
| `--drop-densest-as-needed` | Drop overlapping points to meet tile size limits |

See [Conversion & Tippecanoe](04c-CONVERT.md) for additional flags.

### Step 3: Add to Tileserver Configuration

Add the new tileset to `tileserver-config.json`:

```json
{
  "data": {
    "attack-sources": {
      "mbtiles": "data/tiles/attack-sources.mbtiles"
    }
  }
}
```

Restart tileserver-gl to pick up the change:

```bash
docker compose restart tileserver
```

Verify the tileset is served:

```bash
curl -s http://localhost:8080/data/attack-sources.json | python3 -m json.tool
```

The response should include a TileJSON document with `tiles`, `minzoom`, `maxzoom`, and `vector_layers` fields.

### Step 4: Visualize with MapLibre GL JS -- Heatmap and Points

This two-layer approach renders a heatmap at continental and regional zoom levels (z2--z8) and discrete, clickable circles at local zoom levels (z9+).

```javascript
// Add the vector tile source
map.addSource('attacks', {
  type: 'vector',
  url: 'http://localhost:8080/data/attack-sources.json'
});

// Layer 1: Heatmap at low zoom
map.addLayer({
  id: 'attack-heatmap',
  type: 'heatmap',
  source: 'attacks',
  'source-layer': 'attack_sources',
  maxzoom: 9,
  paint: {
    'heatmap-weight': [
      'interpolate', ['linear'], ['get', 'abuse_score'],
      0, 0,
      100, 1
    ],
    'heatmap-intensity': [
      'interpolate', ['linear'], ['zoom'],
      0, 1,
      9, 3
    ],
    'heatmap-color': [
      'interpolate', ['linear'], ['heatmap-density'],
      0, 'rgba(0,0,0,0)',
      0.2, '#2c7fb8',
      0.4, '#41b6c4',
      0.6, '#fee090',
      0.8, '#fc8d59',
      1.0, '#d73027'
    ],
    'heatmap-radius': [
      'interpolate', ['linear'], ['zoom'],
      0, 2,
      9, 20
    ],
    'heatmap-opacity': 0.8
  }
});

// Layer 2: Circle points at high zoom
map.addLayer({
  id: 'attack-points',
  type: 'circle',
  source: 'attacks',
  'source-layer': 'attack_sources',
  minzoom: 9,
  paint: {
    'circle-color': [
      'interpolate', ['linear'], ['get', 'abuse_score'],
      50, '#fee090',
      75, '#fc8d59',
      90, '#d73027'
    ],
    'circle-radius': [
      'interpolate', ['linear'], ['get', 'total_reports'],
      1, 4,
      100, 12,
      1000, 20
    ],
    'circle-stroke-color': '#000000',
    'circle-stroke-width': 1,
    'circle-opacity': 0.85
  }
});

// Popup on click
map.on('click', 'attack-points', (e) => {
  const props = e.features[0].properties;
  new maplibregl.Popup()
    .setLngLat(e.lngLat)
    .setHTML(`
      <strong>${props.ip}</strong><br/>
      City: ${props.city}, ${props.country_iso}<br/>
      Abuse Score: ${props.abuse_score}/100<br/>
      Reports: ${props.total_reports}<br/>
      Last Reported: ${props.last_reported}
    `)
    .addTo(map);
});
```

### Step 5: Attack Arc Visualization with deck.gl

To draw great-circle arcs from attack source locations to destination (target) locations, use deck.gl's `ArcLayer` as a MapLibre GL JS overlay.

**Prerequisites**: `npm install @deck.gl/core @deck.gl/layers @deck.gl/mapbox`

```javascript
import { MapboxOverlay } from '@deck.gl/mapbox';
import { ArcLayer } from '@deck.gl/layers';

// attackConnections: array of {source: [lon, lat], target: [lon, lat], count: N}
const overlay = new MapboxOverlay({
  layers: [
    new ArcLayer({
      id: 'attack-arcs',
      data: attackConnections,
      getSourcePosition: d => d.source,
      getTargetPosition: d => d.target,
      getSourceColor: [255, 0, 0, 200],
      getTargetColor: [255, 200, 0, 200],
      getWidth: d => Math.log2(d.count + 1),
      greatCircle: true,
    }),
  ],
});

map.addControl(overlay);
```

---

## Automation with Cron

Schedule the full pipeline to run every 15 minutes for near-real-time attack visibility.

```bash
# /etc/cron.d/oxot-attack-tiles
# Fetch, convert, and reload every 15 minutes
*/15 * * * * root cd /opt/oxot_tileserver && \
  python3 scripts/fetch-attack-sources.py && \
  docker compose run --rm converter tippecanoe \
    -o data/tiles/attack-sources.mbtiles \
    -l attack_sources -z14 -Z2 \
    --cluster-distance=50 \
    --accumulate-attribute=total_reports:sum \
    --accumulate-attribute=abuse_score:max \
    --drop-densest-as-needed --force \
    data/geojson/attack-sources.geojson && \
  docker compose restart tileserver >> /var/log/oxot-attacks.log 2>&1
```

For a zero-downtime reload approach, see [Updates & Scheduling](04e-MAINTENANCE.md).

---

## Correlating Attacks with Infrastructure Layers

The most operationally significant insight comes from overlaying attack data on existing infrastructure layers. The OXOT Tileserver already serves electric grid, water, telecom, and demographic layers. Spatial correlation answers these questions:

| Question | Attack Layer | Infrastructure Layer | Correlation Method |
|----------|-------------|---------------------|--------------------|
| Which substations are in cities targeted by attacks? | `attack_sources` | `eia_power_plants` ([EIA](02c2-EIA.md)) | `queryRenderedFeatures()` bounding box |
| Are any C2 servers near water treatment plants? | `attack_sources` (filtered by `category=c2`) | `epa_water_systems` ([EPA SDWIS](02d2-EPA-SDWIS.md)) | Turf.js `buffer()` + `pointsWithinPolygon()` |
| What is the population exposure of attack-targeted areas? | `attack_sources` | `census_tracts` ([US Census](02b1-CENSUS-US.md)) | Turf.js `pointsWithinPolygon()` |
| Which telecom towers are co-located with attack origins? | `attack_sources` | `osm_telecoms` ([Telecoms](02e-TELECOMS.md)) | `queryRenderedFeatures()` radius query |

### Client-Side Spatial Query Example

```javascript
// Find all electric substations within the current view that overlap with attack points
const attackBounds = map.getBounds();
const substations = map.queryRenderedFeatures(
  [map.project(attackBounds.getSouthWest()), map.project(attackBounds.getNorthEast())],
  { layers: ['eia-substations'] }
);

const attackPoints = map.queryRenderedFeatures(
  [map.project(attackBounds.getSouthWest()), map.project(attackBounds.getNorthEast())],
  { layers: ['attack-points'] }
);

console.log(`${substations.length} substations and ${attackPoints.length} attack sources in view`);
```

---

## Enrichment with OTX AlienVault Pulses

OTX Pulses provide context beyond raw IP reputation: malware family, attack campaign, targeted industries, and MITRE ATT&CK tactics.

```python
import requests

OTX_API_KEY = os.environ["OTX_API_KEY"]
headers = {"X-OTX-API-KEY": OTX_API_KEY}

# Fetch subscribed Pulses from the last 24 hours
response = requests.get(
    "https://otx.alienvault.com/api/v1/pulses/subscribed",
    headers=headers,
    params={"modified_since": "2026-02-10T00:00:00Z", "limit": 50},
    timeout=30,
)
pulses = response.json()["results"]

# Extract IP indicators with geographic data
for pulse in pulses:
    for indicator in pulse.get("indicators", []):
        if indicator["type"] in ("IPv4", "IPv6"):
            ip = indicator["indicator"]
            # Geolocate and add to GeoJSON with pulse context:
            # pulse["name"], pulse["tags"], pulse["targeted_countries"],
            # pulse["attack_ids"] (MITRE ATT&CK)
```

---

## Limitations and Caveats

- **IP geolocation accuracy**: GeoLite2 is approximately 68% accurate at the city level. Attacks attributed to a city may originate from a different location within the same region. See [IP Address Geolocation](13a1-IP-GEOLOCATION.md) for a detailed accuracy discussion.
- **VPN and proxy evasion**: Attackers frequently use VPNs, Tor exit nodes, and cloud hosting to mask their true origin. The mapped location represents the exit point, not the attacker's physical location.
- **Attribution vs. geolocation**: Geographic location is not attribution. An IP geolocated to a country does not mean the attack was conducted by that country's government or citizens.
- **API rate limits**: AbuseIPDB free tier allows 1,000 checks per day. For higher volume, use the paid tiers or batch queries. GreyNoise community API is limited to 50 queries per day.
- **Data freshness**: GeoLite2 updates weekly. IPs reallocated between updates may map to stale locations.

---

## References

AbuseIPDB. (2026). *AbuseIPDB API v2 documentation*. https://docs.abuseipdb.com/

Abuse.ch. (2026). *Feodo Tracker: Tracking botnet C2 infrastructure*. https://feodotracker.abuse.ch/

CrowdStrike. (2026). *CrowdStrike Falcon platform*. https://www.crowdstrike.com/

GreyNoise Intelligence. (2026). *GreyNoise API documentation*. https://docs.greynoise.io/

LevelBlue. (2026). *Open Threat Exchange (OTX) DirectConnect API*. https://otx.alienvault.com/api

MaxMind. (2026). *GeoLite2 free geolocation data*. https://dev.maxmind.com/geoip/geolite2-free-geolocation-data

MaxMind. (2026). *GeoIP2 City database*. https://www.maxmind.com/en/geoip2-city

MISP Project. (2026). *MISP -- Open source threat intelligence and sharing platform*. https://www.misp-project.org/

Proofpoint. (2026). *Emerging Threats open rulesets*. https://rules.emergingthreats.net/

Recorded Future. (2026). *Recorded Future intelligence platform*. https://www.recordedfuture.com/

Shodan. (2026). *Shodan: The search engine for Internet-connected devices*. https://www.shodan.io/

Uber Technologies. (2026). *deck.gl: Large-scale WebGL-powered data visualization*. https://deck.gl/

---

*[Home](INDEX.md) > [Use Cases](13-USE-CASES.md) > Cyber Attack Mapping | Related: [IP Geolocation](13a1-IP-GEOLOCATION.md), [Threat Intelligence Feeds](13a2-THREAT-INTELLIGENCE-FEEDS.md), [Custom Tiles](07-CUSTOM-TILES.md), [API Reference](05-API.md)*
