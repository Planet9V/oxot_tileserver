# Map Cards & Popups

> **Last Updated**: 2026-02-11 01:00 UTC

[Home](INDEX.md) > [Custom Tiles](07-CUSTOM-TILES.md)

---

## Overview

Map cards are information panels that appear when a user interacts with features on the map. They display the properties stored in vector tiles -- facility names, equipment details, customer information, condition status -- in a structured, readable format. This page covers popup implementation with MapLibre GL JS, side panel cards as a React component pattern, card templates for different feature types, CSS styling, and API-driven detail loading.

---

## MapLibre GL JS Popups

The most common interaction pattern is a popup that appears when the user clicks a feature. MapLibre GL JS provides the `Popup` class for this purpose.

### Basic Popup Implementation

```javascript
// Change cursor to pointer when hovering over clickable features
map.on('mouseenter', 'facilities', () => {
  map.getCanvas().style.cursor = 'pointer';
});

map.on('mouseleave', 'facilities', () => {
  map.getCanvas().style.cursor = '';
});

// Show popup on click
map.on('click', 'facilities', (e) => {
  const feature = e.features[0];
  const props = feature.properties;

  new maplibregl.Popup({ offset: 15, maxWidth: '320px' })
    .setLngLat(e.lngLat)
    .setHTML(`
      <div class="facility-card">
        <h3>${props.facility_name}</h3>
        <p><strong>Customer:</strong> ${props.customer_name}</p>
        <p><strong>Type:</strong> ${props.facility_type}</p>
        <p><strong>Address:</strong> ${props.address}</p>
        <p><strong>Sector:</strong> ${props.sector}</p>
      </div>
    `)
    .addTo(map);
});
```

### Popup Options

| Option | Type | Default | Description |
|--------|------|---------|-------------|
| `offset` | Number/Array | `0` | Pixel offset from anchor point |
| `maxWidth` | String | `"240px"` | Maximum popup width |
| `closeButton` | Boolean | `true` | Show close button |
| `closeOnClick` | Boolean | `true` | Close when clicking elsewhere |
| `anchor` | String | auto | Preferred anchor: top, bottom, left, right |
| `className` | String | none | CSS class added to the popup container |

---

## Card Templates by Feature Type

Different feature types require different information layouts. The following templates demonstrate structured HTML for each category.

### Infrastructure Card

For power substations, water treatment plants, telecom exchanges:

```javascript
function infrastructureCard(props) {
  return `
    <div class="map-card card-infrastructure">
      <div class="card-header">
        <span class="card-sector sector-${props.sector}">${props.sector}</span>
        <span class="card-status status-${props.status || 'active'}">${props.status || 'Active'}</span>
      </div>
      <h3 class="card-title">${props.facility_name || props.name}</h3>
      <table class="card-table">
        <tr><td>Operator</td><td>${props.owner || props.operator || 'N/A'}</td></tr>
        <tr><td>Type</td><td>${props.facility_type || 'N/A'}</td></tr>
        <tr><td>Voltage</td><td>${props.voltage_kv ? props.voltage_kv + ' kV' : 'N/A'}</td></tr>
        <tr><td>Capacity</td><td>${props.capacity ? props.capacity + ' MW' : 'N/A'}</td></tr>
        <tr><td>Address</td><td>${props.address || 'N/A'}</td></tr>
      </table>
    </div>
  `;
}
```

### Facility Card

For customer-specific facilities:

```javascript
function facilityCard(props) {
  return `
    <div class="map-card card-facility">
      <div class="card-header">
        <span class="card-customer">${props.customer_name}</span>
        <span class="card-criticality criticality-${props.criticality}">${props.criticality}</span>
      </div>
      <h3 class="card-title">${props.facility_name}</h3>
      <table class="card-table">
        <tr><td>Customer ID</td><td>${props.customer_id}</td></tr>
        <tr><td>Type</td><td>${props.facility_type}</td></tr>
        <tr><td>Address</td><td>${props.address}</td></tr>
        <tr><td>Sector</td><td>${props.sector}</td></tr>
        <tr><td>Contact</td><td>${props.contact || 'N/A'}</td></tr>
      </table>
    </div>
  `;
}
```

### Equipment Card

For fixed assets from CMMS/EAM systems:

```javascript
function equipmentCard(props) {
  return `
    <div class="map-card card-equipment">
      <div class="card-header">
        <span class="card-asset-id">${props.asset_id}</span>
        <span class="card-condition condition-${props.condition}">${props.condition}</span>
      </div>
      <h3 class="card-title">${props.asset_type}: ${props.subtype || ''}</h3>
      <table class="card-table">
        <tr><td>Manufacturer</td><td>${props.manufacturer || 'N/A'}</td></tr>
        <tr><td>Model</td><td>${props.model || 'N/A'}</td></tr>
        <tr><td>Installed</td><td>${props.install_date || 'N/A'}</td></tr>
        <tr><td>Last Inspection</td><td>${props.last_inspection || 'N/A'}</td></tr>
        <tr><td>Owner</td><td>${props.owner || 'N/A'}</td></tr>
        <tr><td>Location</td><td>${props.location_description || 'N/A'}</td></tr>
      </table>
    </div>
  `;
}
```

### Demographics Card

For census and population features:

```javascript
function demographicsCard(props) {
  const pop = props.population ? props.population.toLocaleString() : 'N/A';
  return `
    <div class="map-card card-demographics">
      <h3 class="card-title">${props.name || props.NAME}</h3>
      <table class="card-table">
        <tr><td>Population</td><td>${pop}</td></tr>
        <tr><td>Area</td><td>${props.area_km2 ? props.area_km2 + ' km2' : 'N/A'}</td></tr>
        <tr><td>Median Income</td><td>${props.median_income ? '$' + props.median_income.toLocaleString() : 'N/A'}</td></tr>
        <tr><td>Region Code</td><td>${props.geoid || props.NUTS_ID || 'N/A'}</td></tr>
      </table>
    </div>
  `;
}
```

### Auto-Selecting the Card Template

Route to the correct template based on the layer that was clicked:

```javascript
const cardTemplates = {
  'facilities': facilityCard,
  'equipment-layer': equipmentCard,
  'infrastructure': infrastructureCard,
  'demographics': demographicsCard
};

const clickableLayers = Object.keys(cardTemplates);

clickableLayers.forEach(layerId => {
  map.on('click', layerId, (e) => {
    const props = e.features[0].properties;
    const template = cardTemplates[layerId];

    new maplibregl.Popup({ offset: 15, maxWidth: '360px' })
      .setLngLat(e.lngLat)
      .setHTML(template(props))
      .addTo(map);
  });
});
```

---

## Side Panel Cards (React Pattern)

For richer interactions, display feature details in a side panel rather than a popup. This pattern works well in React applications where the map is one component among several.

### React Component

```jsx
function FeaturePanel({ feature, onClose }) {
  if (!feature) return null;

  const { properties, geometry } = feature;

  return (
    <div className="feature-panel">
      <div className="panel-header">
        <h2>{properties.facility_name || properties.asset_id || properties.name}</h2>
        <button className="panel-close" onClick={onClose}>Close</button>
      </div>

      <div className="panel-body">
        <section className="panel-section">
          <h3>Details</h3>
          <dl className="panel-details">
            {Object.entries(properties).map(([key, value]) => (
              <div key={key} className="detail-row">
                <dt>{formatLabel(key)}</dt>
                <dd>{formatValue(key, value)}</dd>
              </div>
            ))}
          </dl>
        </section>

        <section className="panel-section">
          <h3>Location</h3>
          <p>
            {geometry.coordinates[1].toFixed(6)},
            {geometry.coordinates[0].toFixed(6)}
          </p>
        </section>
      </div>
    </div>
  );
}

function formatLabel(key) {
  return key.replace(/_/g, ' ').replace(/\b\w/g, c => c.toUpperCase());
}

function formatValue(key, value) {
  if (value === null || value === undefined) return 'N/A';
  if (key.includes('date')) return new Date(value).toLocaleDateString();
  if (typeof value === 'number') return value.toLocaleString();
  return String(value);
}
```

### Connecting the Map Click to the Panel

```jsx
function MapWithPanel() {
  const [selectedFeature, setSelectedFeature] = useState(null);

  useEffect(() => {
    map.on('click', 'facilities', (e) => {
      if (e.features.length > 0) {
        setSelectedFeature(e.features[0]);
      }
    });
  }, []);

  return (
    <div className="map-container">
      <div id="map" />
      <FeaturePanel
        feature={selectedFeature}
        onClose={() => setSelectedFeature(null)}
      />
    </div>
  );
}
```

---

## Styling Cards with CSS

### Base Card Styles

```css
.map-card {
  font-family: -apple-system, BlinkMacSystemFont, 'Segoe UI', Roboto, sans-serif;
  font-size: 13px;
  line-height: 1.4;
  color: #1a1a1a;
}

.map-card h3 {
  margin: 8px 0;
  font-size: 15px;
  font-weight: 600;
}

.card-header {
  display: flex;
  justify-content: space-between;
  align-items: center;
  margin-bottom: 4px;
}

.card-table {
  width: 100%;
  border-collapse: collapse;
}

.card-table td {
  padding: 3px 0;
  border-bottom: 1px solid #e5e5e5;
}

.card-table td:first-child {
  font-weight: 500;
  color: #666666;
  width: 40%;
}
```

### Condition Indicators

```css
.card-condition {
  display: inline-block;
  padding: 2px 8px;
  border-radius: 10px;
  font-size: 11px;
  font-weight: 600;
  text-transform: uppercase;
}

.condition-critical { background: #fee2e2; color: #dc2626; }
.condition-poor { background: #ffedd5; color: #ea580c; }
.condition-fair { background: #fef9c3; color: #ca8a04; }
.condition-good { background: #dcfce7; color: #16a34a; }
```

### Criticality Badges

```css
.card-criticality {
  display: inline-block;
  padding: 2px 8px;
  border-radius: 10px;
  font-size: 11px;
  font-weight: 600;
  text-transform: uppercase;
}

.criticality-critical { background: #dc2626; color: #ffffff; }
.criticality-high { background: #ea580c; color: #ffffff; }
.criticality-medium { background: #ca8a04; color: #ffffff; }
.criticality-low { background: #16a34a; color: #ffffff; }
```

### Sector Tags

```css
.card-sector {
  display: inline-block;
  padding: 2px 6px;
  border-radius: 4px;
  font-size: 10px;
  font-weight: 700;
  letter-spacing: 0.5px;
  background: #e5e7eb;
  color: #374151;
}

.sector-ENER { background: #fef3c7; color: #92400e; }
.sector-WATR { background: #dbeafe; color: #1e40af; }
.sector-TRAN { background: #e0e7ff; color: #3730a3; }
.sector-CHEM { background: #fce7f3; color: #9d174d; }
```

---

## Loading Additional Data on Card Open

Vector tiles contain a subset of properties optimized for rendering performance. When the user clicks a feature, you may need to fetch additional details from an API that are too large or too detailed for tile storage.

### Fetch-on-Click Pattern

```javascript
map.on('click', 'equipment-layer', async (e) => {
  const props = e.features[0].properties;
  const assetId = props.asset_id;

  // Show initial card with tile properties
  const popup = new maplibregl.Popup({ maxWidth: '360px' })
    .setLngLat(e.lngLat)
    .setHTML(`
      <div class="map-card">
        <h3>${props.asset_type}: ${props.asset_id}</h3>
        <p class="loading-indicator">Loading details...</p>
      </div>
    `)
    .addTo(map);

  // Fetch full details from API
  try {
    const response = await fetch(`/api/equipment/${assetId}`);
    const detail = await response.json();

    popup.setHTML(`
      <div class="map-card card-equipment-detail">
        <h3>${detail.asset_type}: ${detail.asset_id}</h3>
        <table class="card-table">
          <tr><td>Manufacturer</td><td>${detail.manufacturer}</td></tr>
          <tr><td>Model</td><td>${detail.model}</td></tr>
          <tr><td>Serial Number</td><td>${detail.serial_number}</td></tr>
          <tr><td>Installed</td><td>${detail.install_date}</td></tr>
          <tr><td>Last Inspection</td><td>${detail.last_inspection}</td></tr>
          <tr><td>Next Inspection</td><td>${detail.next_inspection}</td></tr>
          <tr><td>Condition</td><td>${detail.condition}</td></tr>
          <tr><td>Maintenance Notes</td><td>${detail.notes || 'None'}</td></tr>
        </table>
      </div>
    `);
  } catch (err) {
    popup.setHTML(`
      <div class="map-card">
        <h3>${props.asset_type}: ${props.asset_id}</h3>
        <p class="error-message">Failed to load details.</p>
      </div>
    `);
  }
});
```

### What to Store in Tiles vs. API

| In Tiles (properties) | In API (fetch on click) |
|------------------------|------------------------|
| Name, type, category | Full description, notes |
| Condition (single word) | Inspection history |
| Sector, criticality | Maintenance schedule |
| Customer ID, name | Contact details, SLAs |
| Coordinates | Related assets, dependencies |
| Status (active/offline) | Incident history |

Keep tile properties small and focused on styling and filtering. Load detailed, text-heavy attributes from an API on demand.

---

## Related Pages

- [Custom Tiles](07-CUSTOM-TILES.md) -- parent page with workflow overview
- [Custom Layer Styling](07d-STYLING.md) -- paint and layout property reference
- [Per-Customer Facility Layers](07b-CUSTOMER-LAYERS.md) -- customer-specific card examples
- [Equipment & Fixed Asset Layers](07c-EQUIPMENT-LAYERS.md) -- equipment card attributes
- [MapLibre GL JS](06a-MAPLIBRE.md) -- primary client integration
- [OXOT Cyber DT Integration](06d-OXOT-CYBERDT.md) -- digital twin card patterns

---

*[Home](INDEX.md) | [Custom Tiles](07-CUSTOM-TILES.md) | [Styling](07d-STYLING.md) | [Customer Layers](07b-CUSTOMER-LAYERS.md)*
