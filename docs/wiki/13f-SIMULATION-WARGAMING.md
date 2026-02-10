# Simulation & War Gaming

> **Last Updated**: 2026-02-11 02:00 UTC

[Home](INDEX.md) > [Use Cases](13-USE-CASES.md) > Simulation & War Gaming

---

## Overview

The OXOT Tileserver provides the geographic foundation for tabletop exercises, cyber range simulations, red/blue team exercises, and what-if scenario modeling. When infrastructure layers (power grid, water systems, telecoms, demographics) are already rendered on the map, the next step is to overlay simulated events -- attacks, failures, natural disasters, cascading outages -- and visualize their geographic impact in real time.

This use case category transforms the tileserver from a passive visualization platform into an active simulation surface. Operators define a scenario as a time-ordered sequence of geographic events (called "injects"), load those events as a GeoJSON layer, and step through them on the map. At each step, the map zooms to the event location, highlights affected infrastructure within the blast radius, and displays impact metrics derived from spatial intersection with existing layers.

The scenarios documented on this page align with established exercise frameworks from CISA, NIST, and IEC 62443. The tileserver does not replace dedicated simulation engines (PSSE for power flow, EPANET for water hydraulics, or Caldera for cyber attack emulation); instead, it provides the geographic display layer that makes simulation outputs spatially comprehensible.

---

## Use Cases

| # | Scenario Type | Domain | Simulation Inputs | Complexity |
|---|---------------|--------|-------------------|------------|
| 1 | Cyber Tabletop Exercises | Cybersecurity / OT | Attack injects, SCADA targets, network topology | Medium |
| 2 | Red Team / Blue Team | Offensive/Defensive Security | Attack vectors, defense responses, compromise scope | Medium--High |
| 3 | Dam Breach Simulation | Water / Emergency Management | NID data, DEM elevation, population density | High |
| 4 | Grid Failure Cascading | Electric / Energy | Substation topology, generation/load data | High |
| 5 | Pandemic Spread Modeling | Public Health | Population density, transport networks, SIR model | Medium |
| 6 | Supply Chain Disruption | Logistics / SCRM | Chokepoint closure, supplier removal | Medium |

---

## Scenario Data Model

Every simulation scenario uses a common GeoJSON-based data model. A scenario is a FeatureCollection where each Feature represents an event ("inject") at a specific location and time step.

### Inject Schema

```json
{
  "type": "Feature",
  "geometry": {
    "type": "Point",
    "coordinates": [-77.0369, 38.9072]
  },
  "properties": {
    "inject_number": 1,
    "timestamp": "T+00:00",
    "event": "Initial Compromise",
    "severity": "critical",
    "category": "cyber",
    "description": "APT actor gains initial access to SCADA HMI at water treatment facility via spear-phishing email to operations staff.",
    "affected_sector": "water",
    "ttps": "T1566.001, T1078",
    "impact_radius_km": 0,
    "response_required": "Incident Response Team activation",
    "evidence": "SOC alert: suspicious RDP session from external IP"
  }
}
```

### Full Scenario Example: Water Sector Cyber Tabletop

```json
{
  "type": "FeatureCollection",
  "metadata": {
    "scenario_id": "WTR-TTX-2026-001",
    "title": "Water Treatment SCADA Compromise",
    "classification": "EXERCISE - EXERCISE - EXERCISE",
    "duration": "4 hours",
    "sectors": ["water", "electric"],
    "framework": "CISA CTEP",
    "inject_count": 8
  },
  "features": [
    {
      "type": "Feature",
      "geometry": {"type": "Point", "coordinates": [-77.0369, 38.9072]},
      "properties": {
        "inject_number": 1,
        "timestamp": "T+00:00",
        "event": "Initial Compromise",
        "severity": "critical",
        "category": "cyber",
        "description": "APT actor gains access to SCADA HMI at water treatment facility via compromised vendor VPN credentials.",
        "ttps": "T1078 (Valid Accounts), T1133 (External Remote Services)"
      }
    },
    {
      "type": "Feature",
      "geometry": {"type": "Point", "coordinates": [-77.0369, 38.9072]},
      "properties": {
        "inject_number": 2,
        "timestamp": "T+01:00",
        "event": "Lateral Movement",
        "severity": "high",
        "category": "cyber",
        "description": "Attacker moves from IT network to OT network through misconfigured firewall rule. Enumerates PLCs on process control VLAN.",
        "ttps": "T0886 (Remote Services), T0846 (Remote System Discovery)"
      }
    },
    {
      "type": "Feature",
      "geometry": {"type": "Point", "coordinates": [-77.0369, 38.9072]},
      "properties": {
        "inject_number": 3,
        "timestamp": "T+02:00",
        "event": "Process Manipulation",
        "severity": "critical",
        "category": "cyber-physical",
        "description": "Attacker modifies chlorine dosing setpoint from 2.0 mg/L to 8.0 mg/L. Operator display shows normal readings (HMI spoofing).",
        "ttps": "T0836 (Modify Parameter), T0856 (Spoof Reporting Message)",
        "impact_radius_km": 15
      }
    },
    {
      "type": "Feature",
      "geometry": {"type": "Point", "coordinates": [-77.10, 38.88]},
      "properties": {
        "inject_number": 4,
        "timestamp": "T+02:30",
        "event": "Public Health Impact",
        "severity": "critical",
        "category": "physical",
        "description": "Emergency department at regional hospital reports 12 patients with chemical burns to mouth and throat. Source traced to municipal water supply.",
        "impact_radius_km": 15
      }
    },
    {
      "type": "Feature",
      "geometry": {"type": "Point", "coordinates": [-77.05, 38.92]},
      "properties": {
        "inject_number": 5,
        "timestamp": "T+03:00",
        "event": "Boil Water Notice",
        "severity": "high",
        "category": "response",
        "description": "County issues boil water advisory for 180,000 residents. National Guard activated to distribute bottled water.",
        "impact_radius_km": 25
      }
    }
  ]
}
```

---

## Time-Stepped Animation

The core visualization mechanic for tabletop exercises is stepping through injects in sequence. Each step reveals the next event on the map and zooms to its location.

### MapLibre GL JS Implementation

```javascript
// Load scenario layer
map.addSource('scenario', {
  type: 'geojson',
  data: scenarioGeoJSON
});

// Event markers (filtered by current inject)
map.addLayer({
  id: 'scenario-events',
  type: 'circle',
  source: 'scenario',
  filter: ['<=', ['get', 'inject_number'], 0],  // Initially show nothing
  paint: {
    'circle-color': [
      'match', ['get', 'severity'],
      'critical', '#DC143C',
      'high',     '#FF8C00',
      'medium',   '#FFD700',
      'low',      '#32CD32',
      /* fallback */ '#888888'
    ],
    'circle-radius': 12,
    'circle-stroke-width': 3,
    'circle-stroke-color': '#ffffff'
  }
});

// Event labels
map.addLayer({
  id: 'scenario-labels',
  type: 'symbol',
  source: 'scenario',
  filter: ['<=', ['get', 'inject_number'], 0],
  layout: {
    'text-field': ['concat', '#', ['to-string', ['get', 'inject_number']],
                   ': ', ['get', 'event']],
    'text-font': ['Open Sans Bold'],
    'text-size': 12,
    'text-offset': [0, 2],
    'text-anchor': 'top'
  },
  paint: {
    'text-color': '#333333',
    'text-halo-color': '#ffffff',
    'text-halo-width': 2
  }
});

// Step control
let currentInject = 0;
const maxInject = scenarioGeoJSON.features.length;

function advanceScenario() {
  if (currentInject >= maxInject) return;
  currentInject++;

  // Update filter to show all injects up to current
  map.setFilter('scenario-events', ['<=', ['get', 'inject_number'], currentInject]);
  map.setFilter('scenario-labels', ['<=', ['get', 'inject_number'], currentInject]);

  // Find the latest inject feature
  const latest = scenarioGeoJSON.features.find(
    f => f.properties.inject_number === currentInject
  );

  // Fly to event location
  map.flyTo({
    center: latest.geometry.coordinates,
    zoom: latest.properties.impact_radius_km > 10 ? 10 : 13,
    speed: 0.8,
    essential: true
  });

  // Update sidebar with inject details
  updateInjectPanel(latest.properties);
}

function resetScenario() {
  currentInject = 0;
  map.setFilter('scenario-events', ['<=', ['get', 'inject_number'], 0]);
  map.setFilter('scenario-labels', ['<=', ['get', 'inject_number'], 0]);
}

// Bind to UI buttons
document.getElementById('btn-advance').addEventListener('click', advanceScenario);
document.getElementById('btn-reset').addEventListener('click', resetScenario);
```

---

## Impact Zone Visualization

When an inject specifies an `impact_radius_km`, render a circular impact zone around the event point.

### Turf.js Buffer Approach

```javascript
import * as turf from '@turf/turf';

function showImpactZone(feature) {
  const radiusKm = feature.properties.impact_radius_km;
  if (!radiusKm || radiusKm <= 0) return;

  const center = turf.point(feature.geometry.coordinates);
  const buffer = turf.buffer(center, radiusKm, { units: 'kilometers' });

  // Add or update impact zone source
  if (map.getSource('impact-zone')) {
    map.getSource('impact-zone').setData(buffer);
  } else {
    map.addSource('impact-zone', { type: 'geojson', data: buffer });

    map.addLayer({
      id: 'impact-zone-fill',
      type: 'fill',
      source: 'impact-zone',
      paint: {
        'fill-color': '#DC143C',
        'fill-opacity': 0.15
      }
    });

    map.addLayer({
      id: 'impact-zone-outline',
      type: 'line',
      source: 'impact-zone',
      paint: {
        'line-color': '#DC143C',
        'line-width': 2,
        'line-dasharray': [4, 2]
      }
    });
  }
}
```

### Querying Affected Infrastructure

Determine which infrastructure assets fall within the impact zone:

```javascript
function findAffectedInfrastructure(impactPolygon) {
  // Query all rendered features within the impact zone bounding box
  const bbox = turf.bbox(impactPolygon);
  const sw = map.project([bbox[0], bbox[1]]);
  const ne = map.project([bbox[2], bbox[3]]);

  const allFeatures = map.queryRenderedFeatures([sw, ne], {
    layers: [
      'electric-substations',
      'water-treatment-plants',
      'telecom-towers',
      'population-centroids'
    ]
  });

  // Filter to features actually within the polygon (not just bounding box)
  const affected = allFeatures.filter(f => {
    const pt = turf.point(f.geometry.coordinates);
    return turf.booleanPointInPolygon(pt, impactPolygon);
  });

  return affected;
}
```

---

## Cascading Failure Visualization

### Power Grid Cascade Simulation

Power grid cascading failures occur when the loss of one substation overloads adjacent transmission lines, causing them to trip, which overloads the next set of lines, and so on.

```javascript
// Graph representation of power grid
const gridGraph = {
  nodes: substations,  // From EIA or HIFLD layers
  edges: transmissionLines
};

function simulateCascade(failedNodeId) {
  const failed = new Set([failedNodeId]);
  const steps = [{ step: 0, failed: [failedNodeId] }];
  let changed = true;
  let step = 0;

  while (changed) {
    changed = false;
    step++;
    const newFailures = [];

    for (const edge of gridGraph.edges) {
      // If one end is failed and the other is not,
      // check if remaining capacity is exceeded
      const fromFailed = failed.has(edge.from);
      const toFailed = failed.has(edge.to);

      if (fromFailed !== toFailed) {
        const survivingNode = fromFailed ? edge.to : edge.from;
        const loadOnSurvivor = calculateRedistributedLoad(survivingNode, failed);

        if (loadOnSurvivor > edge.capacity * 1.2) {
          // Overloaded: this node fails too
          failed.add(survivingNode);
          newFailures.push(survivingNode);
          changed = true;
        }
      }
    }

    if (newFailures.length > 0) {
      steps.push({ step, failed: newFailures });
    }
  }

  return steps;
}

// Animate cascade on map
async function animateCascade(cascadeSteps) {
  for (const step of cascadeSteps) {
    for (const nodeId of step.failed) {
      // Change node color to red
      map.setFeatureState(
        { source: 'electric-grid', sourceLayer: 'substations', id: nodeId },
        { failed: true, cascade_step: step.step }
      );
    }
    // Pause between steps for visual effect
    await new Promise(resolve => setTimeout(resolve, 1500));
  }
}
```

### Dam Breach Flood Modeling

Combine National Inventory of Dams (NID) data with digital elevation models (DEM) and population density to estimate downstream flood impact.

```python
import rasterio
import numpy as np
from shapely.geometry import Point

def estimate_flood_zone(dam_location, dam_height_m, dem_path, downstream_km=30):
    """
    Simplified flood zone estimation.
    For production use, apply HEC-RAS or MIKE FLOOD hydraulic models.
    """
    with rasterio.open(dem_path) as dem:
        # Read elevation data in downstream corridor
        # ... (clip DEM to downstream extent, compute flow accumulation)
        pass

    # Approximate: flood zone = area below dam_elevation - dam_height + safety_margin
    dam_elevation = get_elevation_at_point(dem_path, dam_location)
    flood_elevation = dam_elevation + (dam_height_m * 0.3)  # Rough surge estimate

    # Generate polygon of areas below flood_elevation within downstream_km
    # This is a simplified stand-in; real implementation uses hydraulic routing
    return flood_polygon
```

---

## CISA Exercise Frameworks

The tileserver scenario format aligns with established exercise methodologies.

### CISA Tabletop Exercise Packages (CTEPs)

CISA publishes free tabletop exercise packages covering multiple critical infrastructure sectors.

**URL**: https://www.cisa.gov/resources-tools/resources/cisa-tabletop-exercise-packages

**Available CTEPs (2026)**:
- Cyber Attack on a Water System
- Ransomware Attack on an Electric Utility
- Supply Chain Compromise
- Insider Threat at a Chemical Facility
- Multi-Sector Cascading Failure

Each CTEP includes facilitator guides, inject schedules, and discussion questions. The OXOT Tileserver adds a geographic dimension by placing each inject at its real-world location.

### NIST Cybersecurity Framework Alignment

Map scenario injects to NIST CSF 2.0 functions:

| CSF Function | Scenario Phase | Map Visualization |
|--------------|----------------|-------------------|
| Govern (GV) | Pre-exercise | Regulatory boundaries, compliance zones |
| Identify (ID) | Asset discovery | Infrastructure layer highlighting |
| Protect (PR) | Defense posture | Security control locations |
| Detect (DE) | Alert generation | SOC detection overlay, sensor locations |
| Respond (RS) | Incident response | Response team deployment, staging areas |
| Recover (RC) | Recovery operations | Restoration sequence, priority zones |

### IEC 62443 Scenario Mapping

For OT/ICS-focused exercises, map scenario events to IEC 62443 zones and conduits:

```json
{
  "inject_number": 2,
  "event": "Zone Boundary Violation",
  "iec62443_zone": "Zone 3 (Site Operations)",
  "iec62443_conduit": "Conduit 3-4 (DMZ bypass)",
  "security_level_target": "SL 3",
  "security_level_achieved": "SL 1",
  "description": "Attacker traverses from Zone 2 (Enterprise) to Zone 3 (Operations) through an unmonitored conduit."
}
```

---

## Supply Chain Disruption Scenarios

Leverage the supply chain data model from [Supply Chain Visualization](13e-SUPPLY-CHAIN-MAPPING.md) to simulate chokepoint closures and supplier failures.

### Chokepoint Closure Scenario

```javascript
function simulateChokepointClosure(chokepointName, supplyChain) {
  // Find all edges that cross this chokepoint
  const affectedEdges = supplyChain.edges.filter(
    e => e.chokepoints_crossed.includes(chokepointName)
  );

  // Highlight affected routes in red
  for (const edge of affectedEdges) {
    map.setFeatureState(
      { source: 'supply-chain', sourceLayer: 'supply_edges', id: edge.id },
      { disrupted: true }
    );
  }

  // Identify downstream nodes that become unreachable
  const unreachableNodes = findUnreachableNodes(supplyChain, affectedEdges);

  // Display impact summary
  return {
    chokepoint: chokepointName,
    affected_routes: affectedEdges.length,
    unreachable_nodes: unreachableNodes.length,
    estimated_lead_time_increase_days: calculateRerouteDelay(affectedEdges)
  };
}
```

---

## References

CISA. (2026). *CISA tabletop exercise packages (CTEPs)*. https://www.cisa.gov/resources-tools/resources/cisa-tabletop-exercise-packages

International Electrotechnical Commission. (2024). *IEC 62443: Industrial communication networks -- Network and system security*. https://webstore.iec.ch/en/publication/33615

MITRE. (2026). *ATT&CK for ICS*. https://attack.mitre.org/techniques/ics/

NIST. (2024). *NIST Cybersecurity Framework (CSF) 2.0*. https://www.nist.gov/cyberframework

U.S. Army Corps of Engineers. (2026). *National inventory of dams*. https://nid.sec.usace.army.mil/

U.S. EIA. (2026). *U.S. Energy Atlas: Electric grid data*. https://atlas.eia.gov/

---

*[Home](INDEX.md) | [Use Cases](13-USE-CASES.md) | [Supply Chain](13e-SUPPLY-CHAIN-MAPPING.md) | [Additional Use Cases](13g-ADDITIONAL-USE-CASES.md)*
