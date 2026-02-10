# Socioeconomic and Demographic Analysis

> **Last Updated**: 2026-02-11 02:00 UTC

[Home](INDEX.md) > [Use Cases](13-USE-CASES.md) > Socioeconomic and Demographic Analysis

---

## Overview

Infrastructure does not exist in a vacuum. Every substation, water treatment plant, and telecommunications tower serves a population with its own socioeconomic profile. This use case overlays census demographics, vulnerability indices, and development indicators with infrastructure data to answer questions that pure engineering analysis cannot: Which communities are most vulnerable if this asset fails? Where should resilience investments be directed first? Does the workforce exist to operate the systems we are building?

The OXOT Tileserver already hosts demographic boundary layers for the United States ([US Census TIGER/Line + ACS](02b1-CENSUS-US.md)), Europe ([Eurostat NUTS](02b2-EUROSTAT.md)), and Australia ([ABS Census](02b3-ABS-AUSTRALIA.md)). This page extends those layers with additional socioeconomic indices and demonstrates five analytical patterns that combine demographics with infrastructure.

---

## Use Cases

| # | Use Case | Question Answered | Key Data |
|---|----------|-------------------|----------|
| 1 | Infrastructure Vulnerability | Which aging infrastructure serves the most socioeconomically vulnerable populations? | CDC SVI + asset age |
| 2 | Blast Radius / Impact Analysis | How many people live within X km of a critical facility, and what are their demographics? | Census tracts + facility buffers |
| 3 | Cyber Workforce Availability | Does the region have sufficient STEM-educated workers to staff a security operations centre? | ACS educational attainment |
| 4 | Healthcare Proximity | How far must residents travel to reach the nearest hospital or clinic? | Isochrone analysis + healthcare facilities |
| 5 | Environmental Justice | Are pollution-producing facilities disproportionately located near minority or low-income communities? | EPA EJScreen + facility locations |

---

## Data Sources -- Already in the Tileserver

These layers are documented elsewhere in the wiki. They are listed here for cross-reference.

| Layer | Wiki Page | Coverage | Key Fields |
|-------|-----------|----------|------------|
| US Census TIGER/Line + ACS | [02b1-CENSUS-US](02b1-CENSUS-US.md) | United States | Population, median income, age, race, housing |
| Eurostat NUTS + Nuts2json | [02b2-EUROSTAT](02b2-EUROSTAT.md) | European Union + EFTA | GDP per capita, unemployment, educational attainment |
| ABS Census Boundaries | [02b3-ABS-AUSTRALIA](02b3-ABS-AUSTRALIA.md) | Australia | Population, income, Indigenous status, SEIFA index |
| Stats NZ Boundaries | [02b4-STATS-NZ](02b4-STATS-NZ.md) | New Zealand | Meshblock demographics |
| GeoNames Cities | [02b5-GEONAMES](02b5-GEONAMES.md) | Global | City names, population, elevation |

---

## Additional Data Sources

| Source | URL | Coverage | Data | Format | License |
|--------|-----|----------|------|--------|---------|
| World Bank Open Data | https://data.worldbank.org/ | Global (217 economies) | GDP, poverty rate, life expectancy, education, health expenditure | CSV, JSON API | CC BY 4.0 |
| UN SDG Indicators | https://unstats.un.org/sdgs/ | Global | 231 indicators across 17 Sustainable Development Goals | CSV, JSON API | Open |
| CDC Social Vulnerability Index (SVI) | https://www.atsdr.cdc.gov/placeandhealth/svi/ | United States (census tracts) | 16 census variables aggregated into 4 themes and 1 composite score | Shapefile, CSV | Public Domain |
| EPA EJScreen | https://www.epa.gov/ejscreen | United States (block groups) | Environmental justice indices: pollution burden + demographic indicators | Geodatabase, CSV | Public Domain |
| EU Index of Multiple Deprivation | https://ec.europa.eu/eurostat/ | European Union (NUTS 2/3) | Regional deprivation combining income, employment, education, health | CSV | Open |
| SEIFA (Socio-Economic Indexes for Areas) | https://www.abs.gov.au/statistics/people/people-and-communities/socio-economic-indexes-areas-seifa-australia/ | Australia (SA1, SA2) | Index of Relative Socio-economic Disadvantage (IRSD), Advantage and Disadvantage (IRSAD), Economic Resources (IER), Education and Occupation (IEO) | CSV | CC BY 4.0 |
| UNDP Human Development Index | https://hdr.undp.org/data-center | Global (191 countries) | Life expectancy, education, GNI per capita | CSV, API | Open |

---

## Implementation: Vulnerability Choropleth (CDC SVI)

The CDC Social Vulnerability Index ranks every US census tract on a 0-to-1 scale across four themes: socioeconomic status, household composition and disability, minority status and language, and housing type and transportation. A tract scoring 0.9 is in the 90th percentile of vulnerability.

### Download and Prepare

```bash
# Download SVI shapefile from CDC
wget "https://svi.cdc.gov/Documents/Data/2022/csv/SVI_2022_US.csv" \
  -O data/raw/svi-2022.csv

# Join SVI scores to existing TIGER tract geometries using FIPS code
python scripts/join_svi_to_tracts.py \
  --tracts data/geojson/census-tracts.geojson \
  --svi data/raw/svi-2022.csv \
  --output data/geojson/tracts-with-svi.geojson
```

### Join Script (Python)

```python
import geopandas as gpd
import pandas as pd

tracts = gpd.read_file("data/geojson/census-tracts.geojson")
svi = pd.read_csv("data/raw/svi-2022.csv", dtype={"FIPS": str})

# Select key SVI fields
svi_subset = svi[["FIPS", "RPL_THEMES",
                   "RPL_THEME1", "RPL_THEME2",
                   "RPL_THEME3", "RPL_THEME4"]]
svi_subset = svi_subset.rename(columns={
    "RPL_THEMES": "svi_score",
    "RPL_THEME1": "svi_socioeconomic",
    "RPL_THEME2": "svi_household_disability",
    "RPL_THEME3": "svi_minority_language",
    "RPL_THEME4": "svi_housing_transport"
})

merged = tracts.merge(svi_subset, left_on="GEOID", right_on="FIPS", how="left")
merged.to_file("data/geojson/tracts-with-svi.geojson", driver="GeoJSON")
```

### Tile Generation

```bash
tippecanoe -o data/tiles/svi-tracts.mbtiles \
  -l svi_tracts \
  -z14 -Z6 \
  --coalesce-densest-as-needed \
  data/geojson/tracts-with-svi.geojson
```

### MapLibre Choropleth Layer

```javascript
map.addSource('svi', {
  type: 'vector',
  url: 'http://localhost:8080/data/svi-tracts.json'
});

map.addLayer({
  id: 'vulnerability-choropleth',
  type: 'fill',
  source: 'svi',
  'source-layer': 'svi_tracts',
  paint: {
    'fill-color': [
      'interpolate', ['linear'], ['get', 'svi_score'],
      0.0, '#1a9850',
      0.25, '#91cf60',
      0.5, '#fee08b',
      0.75, '#fc8d59',
      1.0, '#d73027'
    ],
    'fill-opacity': 0.6
  }
});

// Popup on click
map.on('click', 'vulnerability-choropleth', (e) => {
  const props = e.features[0].properties;
  new maplibregl.Popup()
    .setLngLat(e.lngLat)
    .setHTML(`
      <strong>Tract ${props.GEOID}</strong><br>
      Overall SVI: ${(props.svi_score * 100).toFixed(0)}th percentile<br>
      Socioeconomic: ${(props.svi_socioeconomic * 100).toFixed(0)}%<br>
      Minority/Language: ${(props.svi_minority_language * 100).toFixed(0)}%
    `)
    .addTo(map);
});
```

---

## Implementation: Population Impact Radius

When a critical facility experiences an incident -- chemical release, explosion, or prolonged outage -- operators need to know the population within the potential impact zone. This pattern uses Turf.js to create a buffer around a facility and then counts the census-tract centroids inside it.

### Client-Side Buffer Analysis

```javascript
import * as turf from '@turf/turf';

function calculateImpactPopulation(facilityCoords, radiusKm) {
  const center = turf.point(facilityCoords);
  const buffer = turf.buffer(center, radiusKm, { units: 'kilometers' });

  // Query all rendered census-tract features
  const tractFeatures = map.querySourceFeatures('demographics-us', {
    sourceLayer: 'census_tracts'
  });

  // Calculate centroid of each tract and test containment
  let totalPopulation = 0;
  let affectedTracts = 0;
  const demographics = { medianIncome: [], medianAge: [] };

  tractFeatures.forEach(tract => {
    const centroid = turf.centroid(tract);
    if (turf.booleanPointInPolygon(centroid, buffer)) {
      totalPopulation += tract.properties.total_population || 0;
      affectedTracts++;
      demographics.medianIncome.push(tract.properties.median_income);
      demographics.medianAge.push(tract.properties.median_age);
    }
  });

  return {
    totalPopulation,
    affectedTracts,
    avgMedianIncome: average(demographics.medianIncome),
    avgMedianAge: average(demographics.medianAge),
    bufferGeoJSON: buffer
  };
}

function average(arr) {
  const valid = arr.filter(v => v != null && v > 0);
  return valid.length > 0 ? valid.reduce((a, b) => a + b, 0) / valid.length : null;
}
```

### Rendering the Impact Zone

```javascript
// Add the buffer polygon as a visual overlay
map.addSource('impact-zone', {
  type: 'geojson',
  data: bufferGeoJSON
});

map.addLayer({
  id: 'impact-zone-fill',
  type: 'fill',
  source: 'impact-zone',
  paint: {
    'fill-color': '#ff0000',
    'fill-opacity': 0.15
  }
});

map.addLayer({
  id: 'impact-zone-border',
  type: 'line',
  source: 'impact-zone',
  paint: {
    'line-color': '#ff0000',
    'line-width': 2,
    'line-dasharray': [4, 2]
  }
});
```

---

## Implementation: Environmental Justice Screening

The EPA EJScreen tool provides block-group-level indices that combine pollution burden (air quality, proximity to hazardous waste, water discharge) with demographic indicators (minority percentage, low-income percentage, linguistic isolation). Overlaying these indices with OXOT infrastructure layers reveals whether industrial facilities are disproportionately sited near disadvantaged communities.

### Workflow

1. Download EJScreen data from https://www.epa.gov/ejscreen.
2. Join to existing block-group geometries from the Census layer.
3. Convert to tiles with tippecanoe.
4. Render as a bivariate choropleth (pollution burden on one axis, demographic vulnerability on the other).

---

## Implementation: Cyber Workforce Availability

Using ACS Table B15003 (educational attainment), operators can map the percentage of the adult population with bachelor's or graduate degrees in STEM fields. This informs decisions about where to locate security operations centres and training facilities.

### Key ACS Variables

| ACS Variable | Description |
|-------------|-------------|
| B15003_022E | Bachelor's degree holders |
| B15003_023E | Master's degree holders |
| B15003_024E | Professional school degree holders |
| B15003_025E | Doctorate degree holders |
| B15003_001E | Total population 25 years and over |

```python
# Calculate STEM-proxy percentage
df['stem_proxy_pct'] = (
    (df['B15003_022E'] + df['B15003_023E'] +
     df['B15003_024E'] + df['B15003_025E']) / df['B15003_001E']
) * 100
```

---

## Refresh Cadence

| Data | Refresh | Source Cycle |
|------|---------|-------------|
| ACS 5-year estimates | Annual (December) | US Census Bureau releases each December |
| CDC SVI | Annual | Updated with each new ACS release |
| EPA EJScreen | Annual | Updated each spring |
| World Bank indicators | Annual | Calendar year aggregates |
| Eurostat NUTS | Annual | Regional accounts published each spring |

---

## References

Agency for Toxic Substances and Disease Registry. (2024). *CDC/ATSDR Social Vulnerability Index*. U.S. Department of Health and Human Services. https://www.atsdr.cdc.gov/placeandhealth/svi/

Australian Bureau of Statistics. (2023). *Socio-Economic Indexes for Areas (SEIFA), Australia*. https://www.abs.gov.au/statistics/people/people-and-communities/socio-economic-indexes-areas-seifa-australia/

U.S. Census Bureau. (2025). *American Community Survey 5-year estimates*. https://data.census.gov/

U.S. Environmental Protection Agency. (2025). *EJScreen: Environmental Justice Screening and Mapping Tool*. https://www.epa.gov/ejscreen

United Nations. (2026). *SDG indicators: Global indicator framework for the Sustainable Development Goals*. https://unstats.un.org/sdgs/

United Nations Development Programme. (2025). *Human Development Report data center*. https://hdr.undp.org/data-center

World Bank Group. (2026). *World Bank Open Data*. https://data.worldbank.org/

---

*[Home](INDEX.md) | [Use Cases](13-USE-CASES.md) | [Demographics](02b-DEMOGRAPHICS.md) | [US Census](02b1-CENSUS-US.md) | [Facility Location](13b-FACILITY-BUILDING-LOCATION.md)*
