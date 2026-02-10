> **Last Updated**: 2026-02-11 01:00 UTC

[Home](INDEX.md) > [Data Sources](02-DATA-SOURCES.md) > [Electric Grid](02c-ELECTRIC.md) > EIA US Energy Atlas

# EIA US Energy Atlas

The U.S. Energy Information Administration (EIA) publishes the most comprehensive
authoritative dataset on energy infrastructure in the United States. The US Energy
Atlas provides geospatial layers for power plants, transmission lines, pipelines,
refineries, and renewable energy installations.

---

## Quick Reference

| Attribute | Value |
|-----------|-------|
| **Provider** | U.S. Energy Information Administration (EIA) |
| **URL** | https://atlas.eia.gov/ |
| **Coverage** | United States, Puerto Rico, US territories |
| **Format** | Shapefile, GeoJSON, CSV (via API) |
| **Key Features** | 10,000+ power plants >= 1 MW |
| **Size (raw)** | ~200 MB (all energy layers) |
| **Size (tiles)** | ~100 MB (MBTiles) |
| **Update Cadence** | Annual (EIA-860: generators); Monthly (EIA-923: generation) |
| **License** | Public Domain (US Government work) |
| **OXOT Option** | C and above |

---

## Available Layers

| Layer | Geometry | Feature Count | Key Attributes |
|-------|----------|--------------|----------------|
| Power plants | Point | ~10,000 | Fuel type, capacity MW, operator, NERC region |
| Transmission lines | LineString | ~70,000 segments | Voltage kV, owner, status |
| Natural gas pipelines | LineString | ~50,000 segments | Diameter, operator, status |
| Petroleum refineries | Point | ~130 | Capacity bbl/day, operator |
| Coal mines | Point | ~800 | Production, type |
| Wind turbines | Point | ~75,000 | Capacity kW, hub height, rotor diameter |

---

## EIA Forms

The underlying data comes from two mandatory reporting forms:

### EIA-860: Annual Electric Generator Report

- **Scope**: All generators >= 1 MW
- **Fields**: Plant name, operator, fuel type, nameplate capacity (MW), prime mover,
  operating status, NERC region, balancing authority, latitude/longitude
- **Release**: Annual (preliminary in spring; final in fall)

### EIA-923: Power Plant Operations Report

- **Scope**: Monthly generation and fuel consumption
- **Fields**: Net generation (MWh), fuel consumption (MMBtu), capacity factor
- **Release**: Monthly (2-month lag)

---

## Key Attributes

| Field | Type | Description |
|-------|------|-------------|
| `Plant_Name` | String | Facility name |
| `Utility_Name` | String | Owning utility |
| `PrimSource` | String | Primary fuel type |
| `Total_MW` | Number | Total nameplate capacity |
| `Latitude` / `Longitude` | Number | WGS 84 coordinates |
| `NERC_Region` | String | NERC reliability region code |
| `Balancing_Authority` | String | BA code |
| `Operating_Year` | Number | Year of first commercial operation |
| `Sector_Name` | String | Electric utility, IPP, industrial, commercial |

### Fuel Type Codes

| Code | Fuel Type |
|------|-----------|
| NG | Natural Gas |
| SUN | Solar (PV + Thermal) |
| WND | Wind |
| WAT | Conventional Hydroelectric |
| NUC | Nuclear |
| COL | Coal |
| PET | Petroleum |
| BIO | Biomass / Wood |
| GEO | Geothermal |
| OTH | Other |

---

## Download Methods

### Bulk Shapefile Download

```bash
# Power plants
wget https://atlas.eia.gov/datasets/eia::power-plants/about \
  -O eia_power_plants.zip
unzip eia_power_plants.zip

# Transmission lines
wget https://atlas.eia.gov/datasets/eia::transmission-lines/about \
  -O eia_transmission.zip
unzip eia_transmission.zip
```

### ArcGIS REST API

```bash
# Query power plants >= 100 MW, return GeoJSON
curl "https://services7.arcgis.com/FGr1D95XCGALKXqM/arcgis/rest/services/PowerPlants/FeatureServer/0/query?where=Total_MW>=100&outFields=*&f=geojson" \
  -o eia_plants_100mw.geojson
```

---

## Conversion Pipeline

### Step 1: Download and Filter

```bash
ogr2ogr -f GeoJSON eia_plants.geojson \
  Power_Plants.shp \
  -where "Total_MW >= 1"
```

### Step 2: Generate Tiles

```bash
# Power plants (points)
tippecanoe \
  -o eia_plants.mbtiles \
  -z14 -Z2 \
  -r1 \
  --cluster-distance=10 \
  -l eia_plants \
  eia_plants.geojson

# Transmission lines
tippecanoe \
  -o eia_transmission.mbtiles \
  -z14 -Z4 \
  --drop-densest-as-needed \
  -l eia_transmission \
  eia_transmission.geojson
```

### Step 3: Merge Tilesets

```bash
tile-join \
  -o eia_energy.mbtiles \
  eia_plants.mbtiles \
  eia_transmission.mbtiles
```

---

## Quality Notes

- **Coordinate accuracy**: Plant locations are self-reported by operators. Most are
  accurate to < 100 m, but some rural plants may have coordinates offset to
  facility centroids rather than actual plant locations.
- **Completeness**: EIA-860 is mandatory for plants >= 1 MW. Smaller distributed
  generation (rooftop solar, small CHP) is not included.
- **Temporal lag**: The most recent complete annual data is typically 12-18 months
  behind the current date.

---

## References

U.S. Energy Information Administration. (2025). *U.S. energy atlas*. U.S. Department of Energy. https://atlas.eia.gov/

U.S. Energy Information Administration. (2025). *Form EIA-860: Annual electric generator report*. https://www.eia.gov/electricity/data/eia860/

U.S. Energy Information Administration. (2025). *Form EIA-923: Power plant operations report*. https://www.eia.gov/electricity/data/eia923/

---

## Related Pages

- **Parent**: [Electric Grid](02c-ELECTRIC.md)
- **Siblings**: [OSM Power](02c1-OSM-POWER.md) | [HIFLD](02c3-HIFLD.md) | [ENTSO-E](02c4-ENTSOE.md) | [Geoscience AU](02c5-GEOSCIENCE-AU.md)
- **Pipeline**: [Conversion & Tippecanoe](04c-CONVERT.md)
- **See Also**: [OXOT Cyber DT Integration](06d-OXOT-CYBERDT.md)
