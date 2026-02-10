# Threat Intelligence Feeds

> **Last Updated**: 2026-02-11 02:00 UTC

[Home](INDEX.md) > [Use Cases](13-USE-CASES.md) > [Cyber Attack Mapping](13a-CYBER-ATTACK-MAPPING.md) > Threat Intelligence Feeds

---

## Overview

Threat intelligence (TI) feeds provide structured data about malicious IPs, domains, URLs, and file hashes observed in active attacks. When these indicators include IP addresses -- either as the source of an attack or the location of command-and-control infrastructure -- they can be geolocated and rendered on the OXOT Tileserver map.

This page catalogs the major open and commercial TI feeds that contain geographic data, documents how to ingest them, and describes the pipeline for converting feed data into tileserver-compatible vector tiles. It is a companion to [Cyber Attack Mapping](13a-CYBER-ATTACK-MAPPING.md), which covers the end-to-end visualization workflow, and [IP Address Geolocation](13a1-IP-GEOLOCATION.md), which covers the geolocation step in detail.

---

## Open and Free Feeds

### OTX AlienVault (LevelBlue)

OTX (Open Threat Exchange) is one of the largest open threat intelligence sharing communities. Contributors publish "Pulses" -- curated collections of indicators of compromise (IOCs) with context, tags, and targeted industry references.

- **URL**: https://otx.alienvault.com/
- **API documentation**: https://otx.alienvault.com/api
- **Format**: JSON REST API
- **Update frequency**: Real-time (new Pulses published continuously)
- **Rate limit**: 10,000 requests per hour with a free API key
- **Geographic data**: IP indicators (IPv4, IPv6) can be geolocated; some Pulses include `targeted_countries`

**Fetching subscribed Pulses**:

```python
import os
import requests

OTX_API_KEY = os.environ["OTX_API_KEY"]
BASE_URL = "https://otx.alienvault.com/api/v1"
headers = {"X-OTX-API-KEY": OTX_API_KEY}

# Fetch Pulses modified in the last 24 hours
response = requests.get(
    f"{BASE_URL}/pulses/subscribed",
    headers=headers,
    params={"modified_since": "2026-02-10T00:00:00Z", "limit": 50},
    timeout=30,
)
response.raise_for_status()
pulses = response.json()["results"]

# Extract IP indicators
ip_indicators = []
for pulse in pulses:
    for indicator in pulse.get("indicators", []):
        if indicator["type"] in ("IPv4", "IPv6"):
            ip_indicators.append({
                "ip": indicator["indicator"],
                "pulse_name": pulse["name"],
                "pulse_id": pulse["id"],
                "tags": pulse.get("tags", []),
                "targeted_countries": pulse.get("targeted_countries", []),
                "attack_ids": [a["id"] for a in pulse.get("attack_ids", [])],
                "created": indicator.get("created", ""),
            })

print(f"Extracted {len(ip_indicators)} IP indicators from {len(pulses)} Pulses")
```

**Indicator detail lookup** (per-IP context):

```python
def get_ip_reputation(ip):
    """Fetch OTX reputation data for a single IP."""
    response = requests.get(
        f"{BASE_URL}/indicators/IPv4/{ip}/general",
        headers=headers,
        timeout=10,
    )
    data = response.json()
    return {
        "ip": ip,
        "pulse_count": data.get("pulse_info", {}).get("count", 0),
        "country": data.get("country_name", ""),
        "city": data.get("city", ""),
        "latitude": data.get("latitude", None),
        "longitude": data.get("longitude", None),
        "asn": data.get("asn", ""),
    }
```

### MISP (Malware Information Sharing Platform)

MISP is a self-hosted threat intelligence platform used by CERTs, ISACs, and security teams worldwide. It supports STIX 2.1 and TAXII 2.1 for automated feed sharing.

- **URL**: https://www.misp-project.org/
- **Source code**: https://github.com/MISP/MISP
- **API documentation**: https://www.misp-project.org/openapi/
- **Format**: MISP JSON, STIX 2.1
- **Update frequency**: Real-time (event publication by community members)
- **Geographic data**: Attributes of type `ip-src`, `ip-dst` with optional geographic context

**Fetching events via the MISP REST API**:

```python
from pymisp import PyMISP

# pip install pymisp
misp = PyMISP("https://your-misp-instance.local", os.environ["MISP_API_KEY"], ssl=True)

# Search for events with IP attributes from the last day
events = misp.search(
    controller="events",
    type_attribute=["ip-src", "ip-dst"],
    timestamp="1d",
    pythonify=True,
)

ip_list = []
for event in events:
    for attribute in event.attributes:
        if attribute.type in ("ip-src", "ip-dst"):
            ip_list.append({
                "ip": attribute.value,
                "direction": "source" if attribute.type == "ip-src" else "destination",
                "event_id": event.id,
                "event_info": event.info,
                "threat_level": event.threat_level_id,
                "tags": [tag.name for tag in attribute.tags] if attribute.tags else [],
            })
```

### Abuse.ch Feeds

Abuse.ch operates several free, community-driven threat feeds focused on specific malware families and abuse infrastructure.

| Feed | URL | Focus | Format | Update |
|------|-----|-------|--------|--------|
| URLhaus | https://urlhaus.abuse.ch/ | Malware distribution URLs with hosting IPs | CSV, JSON API | Real-time |
| Feodo Tracker | https://feodotracker.abuse.ch/ | Botnet C2 server IPs (Dridex, Emotet, TrickBot, QakBot) | CSV, JSON | Real-time |
| SSL Blocklist | https://sslbl.abuse.ch/ | Malicious SSL certificates with associated IPs | CSV | Real-time |
| ThreatFox | https://threatfox.abuse.ch/ | IOCs (IPs, domains, URLs, hashes) from multiple malware families | JSON API | Real-time |

**Fetching Feodo Tracker C2 IPs**:

```python
import csv
import io
import requests

response = requests.get(
    "https://feodotracker.abuse.ch/downloads/ipblocklist_recommended.txt",
    timeout=15,
)
lines = response.text.strip().split("\n")

c2_ips = []
for line in lines:
    line = line.strip()
    if line and not line.startswith("#"):
        c2_ips.append(line)

print(f"Fetched {len(c2_ips)} C2 IPs from Feodo Tracker")
```

**Fetching ThreatFox IOCs**:

```python
response = requests.post(
    "https://threatfox-api.abuse.ch/api/v1/",
    json={"query": "get_iocs", "days": 1},
    timeout=30,
)
iocs = response.json().get("data", [])

ip_iocs = [
    ioc for ioc in iocs
    if ioc.get("ioc_type") in ("ip:port",)
]
print(f"Fetched {len(ip_iocs)} IP-based IOCs from ThreatFox")
```

### Emerging Threats (Proofpoint)

Proofpoint publishes free open rulesets containing IP reputation lists and Suricata/Snort IDS rules.

- **URL**: https://rules.emergingthreats.net/
- **IP blocklists**: https://rules.emergingthreats.net/fwrules/emerging-Block-IPs.txt
- **Format**: Plain text, one CIDR block per line
- **Update frequency**: Daily

```python
response = requests.get(
    "https://rules.emergingthreats.net/fwrules/emerging-Block-IPs.txt",
    timeout=15,
)
blocked_cidrs = [
    line.strip() for line in response.text.split("\n")
    if line.strip() and not line.startswith("#")
]
print(f"Fetched {len(blocked_cidrs)} blocked CIDRs from Emerging Threats")
```

### GreyNoise Community

GreyNoise classifies IPs that are mass-scanning the internet. The Community API provides basic classification (benign, malicious, unknown) and geographic data.

- **URL**: https://viz.greynoise.io/
- **API documentation**: https://docs.greynoise.io/reference/get_v3-community-ip
- **Rate limit**: Community API -- 50 queries per day; Enterprise -- unlimited

```python
GREYNOISE_API_KEY = os.environ.get("GREYNOISE_API_KEY", "")

def greynoise_lookup(ip):
    """Classify an IP using GreyNoise Community API."""
    response = requests.get(
        f"https://api.greynoise.io/v3/community/{ip}",
        headers={"key": GREYNOISE_API_KEY} if GREYNOISE_API_KEY else {},
        timeout=10,
    )
    if response.status_code == 200:
        data = response.json()
        return {
            "ip": ip,
            "noise": data.get("noise", False),
            "riot": data.get("riot", False),
            "classification": data.get("classification", "unknown"),
            "name": data.get("name", ""),
            "last_seen": data.get("last_seen", ""),
        }
    return None
```

### PhishTank

PhishTank (https://phishtank.org/) provides community-verified phishing URLs in JSON format. Extract the hosting IP from each URL hostname, then geolocate. Requires a free API key for bulk download from https://data.phishtank.com/data/online-valid.json.

For **Tor Exit Nodes**, see [IP Address Geolocation](13a1-IP-GEOLOCATION.md).

---

## Commercial Feeds

| Provider | URL | Key Features | Geographic Data | Pricing |
|----------|-----|-------------|-----------------|---------|
| GreyNoise Enterprise | https://www.greynoise.io/ | Full scan/attack telemetry; IP timeline; CVE exploitation tracking | IP geolocation, destination inference | Enterprise |
| CrowdStrike Falcon Intelligence | https://www.crowdstrike.com/ | APT adversary profiles; nation-state attribution; campaign tracking | Adversary origin country, target geography | Enterprise |
| Recorded Future | https://www.recordedfuture.com/ | NLP-driven threat intelligence from open/dark web; risk scores | IP/domain geolocation; entity geo-mapping | Enterprise |
| Mandiant (Google) | https://www.mandiant.com/ | Incident response-derived intelligence; APT group profiles | Attribution geography, targeted sectors | Enterprise |
| Palo Alto Unit 42 | https://unit42.paloaltonetworks.com/ | Threat research, campaign reports, AutoFocus tool | IP/domain geolocation | Enterprise |
| Cisco Talos | https://talosintelligence.com/ | IP and domain reputation; spam and malware tracking | IP geolocation via Talos Intelligence portal | Free (limited) / Cisco customer |

## STIX/TAXII Integration

STIX (Structured Threat Information Expression) and TAXII (Trusted Automated eXchange of Intelligence Information) are OASIS standards for representing and transmitting threat intelligence.

### STIX 2.1 Overview

STIX 2.1 defines domain objects for threat actors, campaigns, indicators, malware, and observed data. The `indicator` object uses the STIX patterning language to express IOCs.

- **Specification**: https://docs.oasis-open.org/cti/stix/v2.1/stix-v2.1.html
- **Python library**: `stix2` -- https://github.com/oasis-open/cti-python-stix2

```python
from stix2 import Filter, MemoryStore

store = MemoryStore()
store.load_from_file("data/raw/stix-bundle.json")

indicators = store.query([
    Filter("type", "=", "indicator"),
    Filter("pattern_type", "=", "stix"),
])

# Extract IPs from STIX patterns like [ipv4-addr:value = '203.0.113.5']
import re
ip_patterns = []
for ind in indicators:
    match = re.search(r"ipv4-addr:value\s*=\s*'([^']+)'", ind.pattern)
    if match:
        ip_patterns.append({"ip": match.group(1), "indicator_id": ind.id, "name": ind.name})
```

### TAXII 2.1 Client

TAXII servers publish collections of STIX objects that clients can poll on a schedule.

- **Python library**: `taxii2-client` -- https://github.com/oasis-open/cti-taxii-client

```python
from taxii2client.v21 import Server, Collection

server = Server("https://taxii.example.com/taxii2/", user="api", password=os.environ["TAXII_KEY"])
for api_root in server.api_roots:
    for col in api_root.collections:
        print(f"Collection: {col.title} (ID: {col.id})")

# Fetch recent objects from a specific collection
collection = Collection("https://taxii.example.com/taxii2/feeds/collections/abc123/",
                        user="api", password=os.environ["TAXII_KEY"])
stix_objects = collection.get_objects(added_after="2026-02-10T00:00:00Z").get("objects", [])
```

---

## Building a Geographic Threat Feed Pipeline

The following end-to-end pipeline fetches indicators from multiple feeds, geolocates them, merges the results, and produces vector tiles.

```
+-----------+     +-----------+     +-----------+
| OTX       |     | Feodo     |     | ET Block  |
| Pulses    |     | Tracker   |     | IPs       |
+-----+-----+     +-----+-----+     +-----+-----+
      |                 |                 |
      v                 v                 v
+--------------------------------------------------+
|           fetch_all_feeds.py                      |
|   - Deduplicate IPs across feeds                  |
|   - Geolocate via MaxMind GeoLite2                |
|   - Classify proxy/VPN/Tor via IP2Proxy           |
|   - Tag with feed source and threat category      |
+----------------------------+---------------------+
                             |
                             v
                  data/geojson/threat-intel.geojson
                             |
                             v
              tippecanoe -o data/tiles/threat-intel.mbtiles
                             |
                             v
                    tileserver-config.json
                             |
                             v
                   docker compose restart tileserver
```

### Deduplication Strategy

When merging indicators from multiple feeds, the same IP may appear in several sources. Deduplicate by IP address, but retain the union of metadata:

```python
from collections import defaultdict

merged = defaultdict(lambda: {
    "feeds": set(),
    "tags": set(),
    "max_confidence": 0,
    "first_seen": None,
    "last_seen": None,
    "geo": None,
})

for indicator in all_indicators:
    ip = indicator["ip"]
    merged[ip]["feeds"].add(indicator["source_feed"])
    merged[ip]["tags"].update(indicator.get("tags", []))
    merged[ip]["max_confidence"] = max(
        merged[ip]["max_confidence"],
        indicator.get("confidence", 0),
    )
    # Keep geographic data from the first successful lookup
    if merged[ip]["geo"] is None and indicator.get("latitude"):
        merged[ip]["geo"] = {
            "lat": indicator["latitude"],
            "lon": indicator["longitude"],
            "city": indicator.get("city", ""),
            "country": indicator.get("country", ""),
        }
```

### Tippecanoe Conversion

```bash
tippecanoe -o data/tiles/threat-intel.mbtiles \
  -l threat_intel \
  -z14 -Z2 \
  --cluster-distance=40 \
  --accumulate-attribute=feed_count:sum \
  --accumulate-attribute=max_confidence:max \
  --drop-densest-as-needed \
  --force \
  data/geojson/threat-intel.geojson
```

---

## Temporal Visualization

Threat intelligence is inherently temporal. An indicator that was active yesterday may be irrelevant today. Store a `timestamp` or `last_seen` property in each GeoJSON feature, and use MapLibre GL JS filter expressions to animate the map.

### Time-Based Filtering

```javascript
// Show only indicators from the last 24 hours
const cutoff = Date.now() - (24 * 60 * 60 * 1000);

map.setFilter('threat-intel-points', [
  '>=', ['get', 'last_seen_epoch'], cutoff
]);
```

### Animated Time Slider

```javascript
const slider = document.getElementById('time-slider');
slider.addEventListener('input', (e) => {
  const hoursAgo = parseInt(e.target.value);
  const cutoff = Date.now() - (hoursAgo * 60 * 60 * 1000);
  map.setFilter('threat-intel-points', [
    '>=', ['get', 'last_seen_epoch'], cutoff
  ]);
  document.getElementById('time-label').textContent =
    `Showing: last ${hoursAgo} hours`;
});
```

### Decay Styling

Older indicators can be rendered with reduced opacity to visually communicate recency. Use MapLibre's `interpolate` expression on the `circle-opacity` paint property, dividing the age of each feature (in milliseconds since `last_seen_epoch`) by 86,400,000 (one day) and interpolating from full opacity at age 0 to 0.2 opacity at age 7 days. Color-code by `source_feed` using a `match` expression and scale `circle-radius` by `feed_count`. See [Custom Layer Styling](07d-STYLING.md) for the full paint property reference.

---

## Feed Refresh Schedule

| Feed | Recommended Interval | Rationale |
|------|---------------------|-----------|
| OTX AlienVault Pulses | Every 15 minutes | High volume, real-time publication |
| AbuseIPDB Blocklist | Every 6 hours | Daily API limit of 1,000 checks on free tier |
| Feodo Tracker | Every 30 minutes | C2 servers change frequently |
| ThreatFox IOCs | Every 15 minutes | Real-time community submissions |
| Emerging Threats Block IPs | Daily at 04:00 UTC | Updated once per day |
| GreyNoise (Community) | Every 12 hours | 50 queries/day limit |
| Tor Exit Nodes | Hourly | List changes as relays join/leave |
| PhishTank | Every 2 hours | Moderate update frequency |

---

## Operational Considerations

### API Key Management

Store all API keys in the `.env` file and reference them via environment variables in fetch scripts. Never commit keys to version control.

```bash
# .env
ABUSEIPDB_API_KEY=your_key_here
OTX_API_KEY=your_key_here
GREYNOISE_API_KEY=your_key_here
MISP_API_KEY=your_key_here
TAXII_KEY=your_key_here
```

See [Environment Configuration](03d-ENVIRONMENT.md) for the full `.env` reference.

### Error Handling and Retry

All fetch scripts should implement retry with exponential backoff (base 2, three attempts) for transient API failures. Wrap each `requests.get()` call in a retry loop that catches `requests.exceptions.RequestException` and waits `2^attempt` seconds before retrying.

### Data Retention

- **Raw API responses** in `data/raw/`: Retain for 30 days for audit trail
- **GeoJSON files** in `data/geojson/`: Retain current plus one previous version
- **MBTiles files** in `data/tiles/`: Retain current only (overwrite with `--force`)

---

## References

Abuse.ch. (2026). *Feodo Tracker: Tracking botnet C2 infrastructure*. https://feodotracker.abuse.ch/

Abuse.ch. (2026). *ThreatFox: Indicators of compromise database*. https://threatfox.abuse.ch/

Abuse.ch. (2026). *URLhaus: Malware URL exchange*. https://urlhaus.abuse.ch/

Cisco Talos Intelligence. (2026). *Talos Intelligence*. https://talosintelligence.com/

GreyNoise Intelligence. (2026). *GreyNoise API documentation*. https://docs.greynoise.io/

LevelBlue. (2026). *Open Threat Exchange (OTX) DirectConnect API v1*. https://otx.alienvault.com/api

MISP Project. (2026). *MISP: Open source threat intelligence and sharing platform*. https://www.misp-project.org/

OASIS. (2021). *STIX version 2.1 specification*. https://docs.oasis-open.org/cti/stix/v2.1/stix-v2.1.html

OASIS. (2021). *TAXII version 2.1 specification*. https://docs.oasis-open.org/cti/taxii/v2.1/taxii-v2.1.html

OASIS. (2026). *cti-python-stix2: Python APIs for STIX 2*. https://github.com/oasis-open/cti-python-stix2

OASIS. (2026). *cti-taxii-client: TAXII 2 client library*. https://github.com/oasis-open/cti-taxii-client

PhishTank. (2026). *PhishTank: Out of the Net, into the tank*. https://phishtank.org/

Proofpoint. (2026). *Emerging Threats open rulesets*. https://rules.emergingthreats.net/

---

*[Home](INDEX.md) > [Use Cases](13-USE-CASES.md) > [Cyber Attack Mapping](13a-CYBER-ATTACK-MAPPING.md) > Threat Intelligence Feeds | Related: [IP Geolocation](13a1-IP-GEOLOCATION.md), [Custom Tiles](07-CUSTOM-TILES.md), [Environment Configuration](03d-ENVIRONMENT.md)*
