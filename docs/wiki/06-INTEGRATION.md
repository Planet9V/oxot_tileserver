# Application Integration

> **Last Updated**: 2026-02-11 01:00 UTC

[Home](INDEX.md)

---

## Overview

The OXOT Tileserver serves vector tiles and style definitions over a standard REST API, making it compatible with any map client that supports the MapLibre GL Style Specification or the Mapbox Vector Tile format. This section provides integration guides for the three most common JavaScript map libraries, the OXOT Cyber Digital Twin platform, and custom applications.

---

## Supported Map Libraries

| Library | Vector Tile Support | Style Spec Support | Recommended For |
|---------|--------------------|--------------------|-----------------|
| **MapLibre GL JS** | Native | Native | Primary client. Best performance, full feature support. |
| **Leaflet** | Via plugin (`leaflet.vectorgrid`) | Partial (via adapter) | Lightweight applications where Leaflet is already in use. |
| **OpenLayers** | Native (`ol/source/VectorTile`) | Via `ol-mapbox-style` | Enterprise GIS applications using the OpenLayers ecosystem. |

### Recommendation

MapLibre GL JS is the recommended client for the OXOT Tileserver. It provides native vector tile rendering with GPU acceleration, full MapLibre GL Style Specification support (including expressions, interpolation, and data-driven styling), and built-in support for TileJSON auto-discovery. The other libraries are supported for environments where they are already established.

---

## Quick Comparison

| Feature | MapLibre GL JS | Leaflet + Plugin | OpenLayers |
|---------|---------------|-------------------|------------|
| Rendering | WebGL (GPU) | Canvas (CPU) | WebGL or Canvas |
| Tile format | PBF native | PBF via plugin | PBF native |
| Style URL | Direct consumption | Manual layer setup | Via ol-mapbox-style |
| Rotation / tilt | Yes | No | Yes |
| 3D extrusions | Yes | No | Limited |
| Bundle size | ~200 KB gzipped | ~40 KB + plugin | ~150 KB gzipped |
| Mobile | Good | Good | Good |
| Offline | With service worker | With service worker | With service worker |

---

## OXOT Cyber Digital Twin

The OXOT Cyber Digital Twin application (running on port 5000) already includes a tileserver-gl service in its Docker Compose stack. The standalone OXOT Tileserver documented in this wiki can serve as a replacement or augmented data source for the DT's map view.

See [OXOT Cyber DT Integration](06d-OXOT-CYBERDT.md) for configuration details.

---

## Common Integration Pattern

Regardless of the map library, the integration pattern follows the same steps:

1. **Point at the style URL**: Use `http://localhost:8080/styles/infrastructure/style.json` as the map's style source.
2. **Or add individual sources**: Use TileJSON URLs (`http://localhost:8080/data/osm-infrastructure.json`) and define layers in client code.
3. **Add interaction**: Attach click/hover handlers to query features and display popups.
4. **Filter and toggle**: Use client-side expressions to show/hide layers or filter by property.

---

## Children Pages

| Page | Description |
|------|-------------|
| [MapLibre GL JS](06a-MAPLIBRE.md) | Primary client integration with full working examples |
| [Leaflet Integration](06b-LEAFLET.md) | Leaflet with the vectorgrid plugin |
| [OpenLayers Integration](06c-OPENLAYERS.md) | OpenLayers vector tile source and styling |
| [OXOT Cyber DT Integration](06d-OXOT-CYBERDT.md) | Connecting to the OXOT digital twin platform |
| [Custom Application Guide](06e-CUSTOM-APPS.md) | Server-side, mobile, and iframe embedding |

---

## Next Steps

- **Starting a new project?** Begin with [MapLibre GL JS](06a-MAPLIBRE.md).
- **Already using Leaflet?** See [Leaflet Integration](06b-LEAFLET.md).
- **Connecting to the OXOT Digital Twin?** See [OXOT Cyber DT Integration](06d-OXOT-CYBERDT.md).
- **Need API details first?** Review [REST API Endpoints](05a-REST-ENDPOINTS.md).

---

*[Home](INDEX.md) | [MapLibre](06a-MAPLIBRE.md) | [Leaflet](06b-LEAFLET.md) | [OpenLayers](06c-OPENLAYERS.md) | [OXOT DT](06d-OXOT-CYBERDT.md) | [Custom](06e-CUSTOM-APPS.md)*
