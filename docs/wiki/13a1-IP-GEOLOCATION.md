# IP Address Geolocation

> **Last Updated**: 2026-02-11 02:00 UTC

[Home](INDEX.md) > [Use Cases](13-USE-CASES.md) > [Cyber Attack Mapping](13a-CYBER-ATTACK-MAPPING.md) > IP Geolocation

---

## Overview

IP address geolocation is the foundational capability for every cybersecurity use case in this section. Every attack source IP, every threat indicator, and every scanning host must be mapped from a network address to a latitude/longitude pair before it can appear on the tileserver map. This page documents the available geolocation databases, their accuracy characteristics, usage in Python and Node.js, and the critical limitations that affect operational interpretation.

---

## Geolocation Databases

### MaxMind GeoLite2 (Free)

MaxMind GeoLite2 is the most widely used free IP geolocation database. It ships three database files in MMDB (MaxMind DB) binary format.

| Database | Content | Download |
|----------|---------|----------|
| GeoLite2-City.mmdb | IP to city, region, country, postal code, latitude, longitude, accuracy radius | https://dev.maxmind.com/geoip/geolite2-free-geolocation-data |
| GeoLite2-Country.mmdb | IP to country only (smaller file, faster lookup) | Same URL |
| GeoLite2-ASN.mmdb | IP to Autonomous System Number (ASN) and organization name | Same URL |

**Registration**: Free MaxMind account required. Generate a license key at https://www.maxmind.com/en/accounts/current/license-key.

**Update frequency**: Weekly, released on Tuesdays. Use the `geoipupdate` tool (https://github.com/maxmind/geoipupdate) to automate downloads.

**Python usage**:

```python
import geoip2.database

# pip install geoip2
reader = geoip2.database.Reader("data/raw/GeoLite2-City.mmdb")

response = reader.city("203.0.113.42")
print(f"Country: {response.country.iso_code}")       # "AU"
print(f"City:    {response.city.name}")               # "Sydney"
print(f"Lat:     {response.location.latitude}")       # -33.8688
print(f"Lon:     {response.location.longitude}")      # 151.2093
print(f"Radius:  {response.location.accuracy_radius} km")  # 50

reader.close()
```

**Node.js usage**:

```javascript
// npm install @maxmind/geoip2-node
const { Reader } = require('@maxmind/geoip2-node');

async function lookup(ip) {
  const reader = await Reader.open('data/raw/GeoLite2-City.mmdb');
  const response = reader.city(ip);
  console.log(`Country: ${response.country.isoCode}`);
  console.log(`City:    ${response.city.names.en}`);
  console.log(`Lat:     ${response.location.latitude}`);
  console.log(`Lon:     ${response.location.longitude}`);
}

lookup('203.0.113.42');
```

### MaxMind GeoIP2 (Commercial)

The commercial GeoIP2 databases offer higher accuracy, confidence scores, and additional fields (user type, connection type, domain, ISP detail). Pricing starts at $100/month.

- **URL**: https://www.maxmind.com/en/geoip2-city
- **API option**: Web service API for real-time lookups without a local database file. See https://dev.maxmind.com/geoip/docs/web-services.

### IP2Location LITE (Free)

IP2Location provides free LITE databases with country, region, city, ISP, and ASN data. Updates are released biweekly.

| Database | Content | Download |
|----------|---------|----------|
| DB11.LITE | Country, region, city, latitude, longitude, zip, timezone, ISP, domain | https://lite.ip2location.com/ |
| DB-ASN.LITE | IP to ASN and ASN name | https://lite.ip2location.com/ |

**Python usage**:

```python
import IP2Location

# pip install IP2Location
db = IP2Location.IP2Location("data/raw/IP2LOCATION-LITE-DB11.BIN")
record = db.get_all("8.8.8.8")

print(f"Country: {record.country_short}")   # "US"
print(f"City:    {record.city}")             # "Mountain View"
print(f"Lat:     {record.latitude}")         # 37.405992
print(f"Lon:     {record.longitude}")        # -122.078515
```

### IP2Proxy LITE (Free)

Identifies VPNs, public proxies, web proxies, Tor exit nodes, and data center hosting. Essential for flagging IPs whose geolocation may not reflect the actual attacker location.

- **URL**: https://lite.ip2location.com/ip2proxy-lite
- **Proxy types detected**: PUB (public), VPN, DCH (data center/hosting), SES (search engine spider), RES (residential proxy), CPN (consumer privacy network), EPN (enterprise private network)

```python
import IP2Proxy

# pip install IP2Proxy
db = IP2Proxy.IP2Proxy("data/raw/IP2PROXY-LITE-PX11.BIN")
record = db.get_all("1.2.3.4")

print(f"Is proxy: {record['is_proxy']}")       # 1 = yes
print(f"Type:     {record['proxy_type']}")      # "VPN"
print(f"Provider: {record['provider']}")        # "NordVPN"
```

---

## BGP and ASN Mapping

IP addresses are allocated in blocks to Autonomous Systems (ASNs). Mapping an IP to its ASN reveals the hosting provider, ISP, or organization responsible for the address space. This is complementary to city-level geolocation and often more operationally useful -- knowing an attack comes from AS 14618 (Amazon AWS us-east-1) is more actionable than knowing it geolocates to Ashburn, Virginia.

### Data Sources

| Source | URL | Coverage | Format | Access |
|--------|-----|----------|--------|--------|
| RIPE NCC RIS | https://ris.ripe.net/ | Global BGP routing data, emphasis on European peering | MRT dumps, JSON API | Free |
| RIPE NCC Stat | https://stat.ripe.net/docs/02.data-api/ | IP allocation, routing, geolocation per RIR database | JSON REST API | Free |
| ARIN RDAP / Whois | https://www.arin.net/resources/registry/whois/ | North American IP allocations | RDAP JSON, Whois text | Free |
| APNIC Whois | https://www.apnic.net/manage-ip/using-whois/ | Asia-Pacific IP allocations | RDAP JSON, Whois text | Free |
| RouteViews | http://www.routeviews.org/ | University of Oregon global BGP table dumps | MRT dumps | Free |
| CAIDA AS Rank | https://asrank.caida.org/ | ASN ranking by customer cone size | JSON API, CSV | Free |
| PeeringDB | https://www.peeringdb.com/ | Internet exchange and peering data | JSON REST API | Free |

### Using RIPE Stat API

```python
import requests

def get_asn_info(ip):
    """Look up the ASN and holder for an IP address via RIPE Stat."""
    response = requests.get(
        "https://stat.ripe.net/data/prefix-overview/data.json",
        params={"resource": ip},
        timeout=10,
    )
    data = response.json()["data"]
    asns = data.get("asns", [])
    if asns:
        return {
            "asn": asns[0]["asn"],
            "holder": asns[0]["holder"],
            "prefix": data.get("resource", ""),
        }
    return None

info = get_asn_info("8.8.8.8")
# {"asn": 15169, "holder": "GOOGLE", "prefix": "8.8.8.0/24"}
```

---

## VPN, Proxy, and Tor Detection

Attackers frequently route traffic through anonymizing services. Detecting these intermediaries is critical for accurate threat mapping: an IP geolocated to Amsterdam may actually originate from an attacker in a different country using a Dutch VPN exit point.

### Tor Exit Node List

The Tor Project publishes a bulk list of current exit node IPs, updated approximately hourly.

- **URL**: https://check.torproject.org/torbulkexitlist
- **Format**: Plain text, one IPv4 address per line
- **Recommended refresh**: Hourly via cron

```bash
curl -s https://check.torproject.org/torbulkexitlist > data/raw/tor-exits.txt
```

### Cloud Provider IP Ranges

Major cloud providers publish their IP ranges in machine-readable format. Attacks originating from these ranges are almost certainly using cloud-hosted infrastructure rather than the attacker's own network.

| Provider | URL | Format |
|----------|-----|--------|
| AWS | https://ip-ranges.amazonaws.com/ip-ranges.json | JSON with `prefixes` array, each containing `ip_prefix`, `region`, `service` |
| Microsoft Azure | https://www.microsoft.com/en-us/download/details.aspx?id=56519 | JSON (download link changes weekly; parse the page for the current URL) |
| Google Cloud | https://www.gstatic.com/ipranges/cloud.json | JSON with `prefixes` array, each containing `ipv4Prefix`, `scope` |
| Oracle Cloud | https://docs.oracle.com/en-us/iaas/tools/public_ip_ranges.json | JSON |
| DigitalOcean | Published via BGP; see ASN 14061 | MRT / Whois |

### Flagging Proxy IPs in GeoJSON

Add a `proxy_type` property to each GeoJSON feature so that the MapLibre layer can style proxy-sourced attacks differently:

```python
# After geolocating an IP, check against known proxy lists
def classify_ip(ip, tor_set, cloud_ranges, ip2proxy_db):
    if ip in tor_set:
        return "tor"
    for cidr in cloud_ranges:
        if ip_in_cidr(ip, cidr):
            return "cloud"
    proxy_record = ip2proxy_db.get_all(ip)
    if proxy_record["is_proxy"]:
        return proxy_record["proxy_type"].lower()
    return "direct"
```

---

## Accuracy by Geographic Level

The following table summarizes empirical accuracy rates across the three most common free and commercial databases. Accuracy is measured as the percentage of test IPs where the database returns the correct value at each geographic level.

| Level | GeoLite2 (Free) | GeoIP2 (Commercial) | IP2Location LITE (Free) |
|-------|------------------|---------------------|-------------------------|
| Country | ~99% | ~99.8% | ~99.5% |
| Region/State | ~75% | ~85% | ~80% |
| City | ~68% | ~83% | ~75% |
| Postal Code | ~55% | ~70% | ~60% |
| Accuracy Radius (median) | 50--100 km | 10--50 km | 25--75 km |

**Source**: MaxMind. (2026). *GeoIP2 City accuracy*. https://www.maxmind.com/en/geoip2-city-accuracy-comparison. IP2Location. (2026). *IP2Location accuracy*. https://www.ip2location.com/data-accuracy.

### Factors Affecting Accuracy

- **Mobile IPs**: Carriers often register IP blocks to a central office, not the device location. A mobile IP in rural Queensland may geolocate to Sydney.
- **CGN (Carrier-Grade NAT)**: Multiple users share a single public IP. The geolocation applies to the NAT gateway, not individual users.
- **Satellite and VSAT**: Satellite internet IPs often geolocate to the ground station, which may be hundreds of kilometers from the user.
- **IPv6 transition**: IPv6 coverage in geolocation databases is improving but still lags behind IPv4. Expect lower accuracy for IPv6 addresses.
- **Recently reallocated blocks**: IP blocks transferred between organizations may retain stale geolocation data until the next database update.

---

## Converting to Tiles

### Aggregate by City

For a global heatmap view, aggregate individual IP geolocations to the city level and use the city centroid as the tile geometry.

```python
from collections import defaultdict

city_stats = defaultdict(lambda: {
    "count": 0, "max_abuse": 0, "ips": set(),
    "lat": 0.0, "lon": 0.0, "country": "", "city": ""
})

for feature in geojson["features"]:
    p = feature["properties"]
    key = f"{p['city']}|{p['country_iso']}"
    city_stats[key]["count"] += 1
    city_stats[key]["max_abuse"] = max(city_stats[key]["max_abuse"], p["abuse_score"])
    city_stats[key]["ips"].add(p["ip"])
    city_stats[key]["lat"] = p["latitude"]
    city_stats[key]["lon"] = p["longitude"]
    city_stats[key]["country"] = p["country_iso"]
    city_stats[key]["city"] = p["city"]

# Build aggregated GeoJSON
aggregated_features = []
for key, stats in city_stats.items():
    aggregated_features.append({
        "type": "Feature",
        "geometry": {
            "type": "Point",
            "coordinates": [stats["lon"], stats["lat"]],
        },
        "properties": {
            "city": stats["city"],
            "country": stats["country"],
            "attack_count": stats["count"],
            "unique_ips": len(stats["ips"]),
            "max_abuse_score": stats["max_abuse"],
        },
    })
```

### Tippecanoe for Aggregated Data

```bash
tippecanoe -o data/tiles/attack-cities.mbtiles \
  -l attack_cities \
  -z12 -Z0 \
  --no-feature-limit \
  --no-tile-size-limit \
  data/geojson/attack-cities.geojson
```

---

## Automating GeoLite2 Updates

Use MaxMind's `geoipupdate` tool to keep the MMDB files current.

### Installation

```bash
# macOS
brew install geoipupdate

# Debian/Ubuntu
sudo apt-get install geoipupdate

# Docker
docker pull ghcr.io/maxmind/geoipupdate
```

### Configuration

Create `/etc/GeoIP.conf` (or `data/raw/GeoIP.conf` for a project-local configuration):

```ini
AccountID 123456
LicenseKey YOUR_LICENSE_KEY
EditionIDs GeoLite2-City GeoLite2-Country GeoLite2-ASN
DatabaseDirectory /opt/oxot_tileserver/data/raw
```

### Cron Schedule

```bash
# Update GeoLite2 databases every Wednesday at 03:00 UTC
# (databases are released on Tuesdays; one-day buffer for propagation)
0 3 * * 3 /usr/bin/geoipupdate -f /etc/GeoIP.conf >> /var/log/geoipupdate.log 2>&1
```

---

## References

APNIC. (2026). *APNIC Whois database*. https://www.apnic.net/manage-ip/using-whois/

ARIN. (2026). *ARIN Whois/RDAP*. https://www.arin.net/resources/registry/whois/

CAIDA. (2026). *AS Rank: A ranking of Autonomous Systems*. https://asrank.caida.org/

IP2Location. (2026). *IP2Location LITE databases*. https://lite.ip2location.com/

IP2Location. (2026). *IP2Proxy LITE databases*. https://lite.ip2location.com/ip2proxy-lite

MaxMind. (2026). *GeoLite2 free geolocation data*. https://dev.maxmind.com/geoip/geolite2-free-geolocation-data

MaxMind. (2026). *GeoIP2 City accuracy*. https://www.maxmind.com/en/geoip2-city-accuracy-comparison

MaxMind. (2026). *geoipupdate: Automatic GeoIP database updater*. https://github.com/maxmind/geoipupdate

PeeringDB. (2026). *PeeringDB: The interconnection database*. https://www.peeringdb.com/

RIPE NCC. (2026). *RIPEstat data API*. https://stat.ripe.net/docs/02.data-api/

RIPE NCC. (2026). *Routing Information Service (RIS)*. https://ris.ripe.net/

RouteViews. (2026). *University of Oregon Route Views project*. http://www.routeviews.org/

Tor Project. (2026). *Tor bulk exit list*. https://check.torproject.org/torbulkexitlist

---

*[Home](INDEX.md) > [Use Cases](13-USE-CASES.md) > [Cyber Attack Mapping](13a-CYBER-ATTACK-MAPPING.md) > IP Geolocation | Related: [Threat Intelligence Feeds](13a2-THREAT-INTELLIGENCE-FEEDS.md), [Data Sources](02-DATA-SOURCES.md)*
