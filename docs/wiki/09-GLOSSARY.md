# Glossary of Terms

> **Last Updated**: 2026-02-11 02:00 UTC

[Home](INDEX.md)

---

This glossary defines domain terminology used throughout the OXOT Tileserver documentation. Terms are organized alphabetically. Cross-references to related terms appear in parentheses.

---

**AbuseIPDB**: Community-driven IP abuse reporting database with confidence scoring. Provides an API for querying reported malicious IP addresses and submitting new reports. See: [Cyber Attack Mapping](13a-CYBER-ATTACK-MAPPING.md).

**ACLED**: Armed Conflict Location & Event Data Project. Real-time collection and mapping of political violence and protest events in 200+ countries. See: [Geopolitical Events](13d-GEOPOLITICAL-EVENTS.md).

**ACS**: American Community Survey. An ongoing statistical survey conducted by the US Census Bureau that provides demographic, social, economic, and housing data for US communities. Used alongside TIGER/Line shapefiles to attach population attributes to geographic boundaries. See: [US Census TIGER/Line + ACS](02b1-CENSUS-US.md). Related: TIGER/Line, ZCTA.

**AIS**: Automatic Identification System. Maritime vessel tracking system transmitting vessel identity, position, course, and speed. See: [Shipping Routes](13e1-SHIPPING-ROUTES.md).

**APA**: American Psychological Association. The citation format (7th edition) used throughout this documentation for referencing data sources, tools, and specifications. See: [References & Citations](10-REFERENCES.md).

**APT**: Advanced Persistent Threat. Sophisticated, long-term cyber attack campaigns typically attributed to nation-state actors. Related: IOC, STIX.

**ASN**: Autonomous System Number. A unique identifier assigned to a network operator for BGP routing. Used in threat intelligence to attribute malicious activity to specific network operators. Related: BGP.

**ASGS**: Australian Statistical Geography Standard. A classification system defined by the Australian Bureau of Statistics that organizes Australia into nested geographic regions (SA1 through SA4, LGA). Used as the basis for Australian census boundary tiles. See: [ABS Census Boundaries](02b3-ABS-AUSTRALIA.md). Related: ABS.

**BGP**: Border Gateway Protocol. The routing protocol used to exchange routing information between autonomous systems on the Internet. BGP data is used in threat intelligence to identify network ownership of malicious IP addresses. Related: ASN.

**Basemap**: The foundational map layer showing roads, buildings, land use, and political boundaries. The OXOT Tileserver uses OpenStreetMap-derived basemap tiles from Protomaps or OpenMapTiles. All custom and infrastructure layers render on top of the basemap. See: [Basemap Sources](02a-BASEMAP.md).

**BoM**: Bureau of Meteorology. The Australian government agency responsible for weather and water data. Provides water resource monitoring data used in the Australian water infrastructure tileset. See: [Australian BoM Water](02d5-BOM-AUSTRALIA.md).

**Choropleth**: A thematic map in which areas are shaded proportional to a statistical variable (e.g., population density by census tract). Supported via MapLibre GL JS fill-layer styling with data-driven paint properties. See: [Socioeconomic Analysis](13c-SOCIOECONOMIC-ANALYSIS.md). Related: heatmap.

**CISA**: Cybersecurity and Infrastructure Security Agency. US federal agency that identifies 16 critical infrastructure sectors. The OXOT Tileserver uses CISA sector codes (ENER, WATR, TRAN, etc.) as a standard classification for infrastructure features.

**CMMS**: Computerized Maintenance Management System. Software used to track equipment, schedule maintenance, and record inspections. Equipment data exported from a CMMS can be converted to GeoJSON for custom tile layers. See: [Equipment & Fixed Asset Layers](07c-EQUIPMENT-LAYERS.md).

**Converter container**: The ephemeral Docker container in the OXOT Tileserver architecture that contains all data processing tools (tippecanoe, osmium-tool, ogr2ogr, GDAL). Used during data preparation and custom tile creation; not running during normal tileserver operation. See: [Converter Container](03c-CONVERTER.md). Related: tileserver-gl.

**CWS**: Community Water System. A public water system that serves at least 15 service connections or 25 year-round residents. CWS data is sourced from EPA SDWIS. See: [EPA SDWIS + WATERS](02d2-EPA-SDWIS.md).

**deck.gl**: WebGL-powered visualization framework by vis.gl for large-scale data visualization, including ArcLayer for geographic connections and HeatmapLayer for density rendering. See: [Cyber Attack Mapping](13a-CYBER-ATTACK-MAPPING.md). Related: heatmap.

**DEXPI**: Data Exchange in the Process Industry. An open standard for exchanging process plant engineering data. Referenced in the OXOT ecosystem for equipment bill-of-materials integration.

**earth-osm**: A Python command-line tool for extracting power infrastructure data from OpenStreetMap. Developed by the PyPSA-meets-Earth project, it outputs clean GeoJSON files for power lines, substations, and generators on a per-country basis. See: [Awesome Electrical Grid Mapping](02c6-AWESOME-GRID-MAPPING.md). Related: PyPSA, OSM.

**EAM**: Enterprise Asset Management. A broader category of software that includes CMMS functionality plus additional capabilities such as lifecycle costing and capital planning. Equipment exports from EAM systems follow the same conversion pipeline as CMMS data. Related: CMMS.

**EIA**: Energy Information Administration. A US federal agency that provides energy statistics. The EIA US Energy Atlas supplies authoritative data on power plants, transmission lines, and substations. See: [EIA US Energy Atlas](02c2-EIA.md).

**ENTSO-E**: European Network of Transmission System Operators for Electricity. Coordinates cross-border electricity transmission in Europe. The ENTSO-E interactive map (extracted via GridKit) provides European transmission network topology. See: [ENTSO-E / GridKit](02c4-ENTSOE.md). Related: GridKit.

**EPA**: Environmental Protection Agency. US federal agency responsible for environmental protection. Provides SDWIS (drinking water systems) and WATERS (watershed boundaries) data. See: [EPA SDWIS + WATERS](02d2-EPA-SDWIS.md).

**EPSG:4326**: The coordinate reference system identifier for WGS84 geographic coordinates (latitude/longitude in decimal degrees). All GeoJSON data must use EPSG:4326. Related: WGS84, GeoJSON.

**FEMA NFHL**: Federal Emergency Management Agency National Flood Hazard Layer. Provides flood zone polygons used to assess flood risk for infrastructure facilities. See: [Natural Hazards](13d1-NATURAL-HAZARDS.md).

**FIRMS**: Fire Information for Resource Management System (NASA). Near-real-time satellite fire detection using MODIS and VIIRS instruments. See: [Natural Hazards](13d1-NATURAL-HAZARDS.md).

**Feature**: A geographic object in GeoJSON consisting of a geometry (point, line, or polygon) and a properties object containing descriptive attributes. A single facility, equipment item, or boundary is represented as one Feature. Related: FeatureCollection, GeoJSON.

**FeatureCollection**: A GeoJSON object containing an array of Features. This is the standard input format for tippecanoe and the expected top-level structure for all OXOT Tileserver custom data files. Related: Feature, GeoJSON.

**GDELT**: Global Database of Events, Language, and Tone. Monitors world news in 100+ languages, updating every 15 minutes with geocoded events. Used for geopolitical event mapping and situational awareness near critical infrastructure. See: [Geopolitical Events](13d-GEOPOLITICAL-EVENTS.md). Related: ACLED.

**GDAL**: Geospatial Data Abstraction Library. An open-source translator library for raster and vector geospatial data formats. The GDAL command-line tools (notably ogr2ogr) are included in the converter container. Related: ogr2ogr.

**Geofabrik**: A provider of OpenStreetMap data extracts in PBF format, organized by geographic region. The OXOT Tileserver download scripts use Geofabrik mirrors for OSM data. See: [OSM Power Infrastructure](02c1-OSM-POWER.md).

**GeoIP**: The process of mapping an IP address to a geographic location. Multiple databases and services provide GeoIP resolution at varying accuracy levels. See: [IP Geolocation](13a1-IP-GEOLOCATION.md). Related: GeoLite2, MMDB.

**GeoJSON**: An open standard format (RFC 7946) for encoding geographic data structures using JSON. GeoJSON is the primary input format for the OXOT Tileserver custom tile pipeline. See: [GeoJSON Authoring](07a-GEOJSON-AUTHORING.md). Related: Feature, FeatureCollection, RFC 7946.

**GeoLite2**: MaxMind's free IP geolocation database with approximately 68% city-level accuracy. Available in MMDB binary format for fast lookups. See: [IP Geolocation](13a1-IP-GEOLOCATION.md). Related: GeoIP, MMDB.

**GeoPackage**: An open, standards-based container format for geospatial data defined by the Open Geospatial Consortium. Uses SQLite as its storage engine. Can be converted to GeoJSON using ogr2ogr. Related: ogr2ogr, Shapefile.

**GISCO**: Geographic Information System of the Commission. The geographic information system maintained by Eurostat that provides European geographic data including NUTS region boundaries. Related: Eurostat, NUTS.

**GreyNoise**: Threat intelligence platform analyzing internet scanning and exploitation traffic with geographic attribution. Distinguishes between benign scanners and malicious actors. See: [Cyber Attack Mapping](13a-CYBER-ATTACK-MAPPING.md). Related: AbuseIPDB, OTX.

**Global Transmission Database**: A research-grade dataset published on Zenodo containing worldwide transmission network topology with node-edge graphs, capacity, and impedance data (MIT license). See: [Awesome Electrical Grid Mapping](02c6-AWESOME-GRID-MAPPING.md). Related: GridKit, PyPSA.

**GridKit**: An open research extraction of the European power grid topology derived from the ENTSO-E interactive map. Published as a dataset on Zenodo by Bart Wiegmans (2016). See: [ENTSO-E / GridKit](02c4-ENTSOE.md). Related: ENTSO-E.

**Heatmap**: A map visualization where data density is represented by color intensity. Supported natively in MapLibre GL JS via the `heatmap` layer type and in deck.gl via `HeatmapLayer`. See: [Cyber Attack Mapping](13a-CYBER-ATTACK-MAPPING.md). Related: choropleth.

**HIFLD**: Homeland Infrastructure Foundation-Level Data. A US Department of Homeland Security program providing open geospatial data on infrastructure facilities including power plants, hospitals, schools, and emergency services. See: [HIFLD Open Data](02c3-HIFLD.md).

**HNSW**: Hierarchical Navigable Small World. A graph-based algorithm for approximate nearest neighbor search in high-dimensional spaces. Used in the OXOT platform's vector database for similarity search on embeddings. Not directly related to tileserver operation but referenced in the broader OXOT ecosystem.

**IOC**: Indicator of Compromise. An artifact (IP address, domain, file hash, URL, etc.) that indicates a potential security breach. IOCs are the primary data type consumed from threat intelligence feeds and plotted on the map. See: [Threat Intelligence Feeds](13a2-THREAT-INTELLIGENCE-FEEDS.md). Related: STIX, TAXII, APT.

**MISP**: Malware Information Sharing Platform. Open-source threat intelligence sharing platform supporting STIX/TAXII formats. Enables collaborative threat data exchange between organizations. See: [Threat Intelligence Feeds](13a2-THREAT-INTELLIGENCE-FEEDS.md). Related: STIX, TAXII, OTX.

**MMDB**: MaxMind Database format. Binary format optimized for fast IP geolocation lookups. Used by GeoLite2 and GeoIP2 databases. See: [IP Geolocation](13a1-IP-GEOLOCATION.md). Related: GeoIP, GeoLite2.

**MBTiles**: A specification for storing tiled map data in SQLite databases. Each MBTiles file contains vector tiles organized by zoom level (z), column (x), and row (y). This is the primary output format of tippecanoe and the input format for tileserver-gl. See: [Conversion & Tippecanoe](04c-CONVERT.md). Related: PMTiles, tippecanoe, tileset.

**MVT**: Mapbox Vector Tile. The binary format (Protocol Buffers) used to encode vector tile data. Each tile contains layers, and each layer contains features with geometries and properties. Served by the tileserver as `.pbf` files. See: [Vector Tile Format](05c-VECTOR-TILES.md). Related: PBF, vector tile.

**NID**: National Inventory of Dams. A database maintained by the US Army Corps of Engineers cataloging over 90,000 dams in the United States. See: [National Inventory of Dams](02d4-NID-DAMS.md).

**NUTS**: Nomenclature of Territorial Units for Statistics. A geocode standard for referencing subdivisions of EU member states. Organized in three levels: NUTS 1 (major regions), NUTS 2 (regions), NUTS 3 (small regions). Used by Eurostat for statistical data. See: [Eurostat NUTS + Nuts2json](02b2-EUROSTAT.md). Related: Eurostat, GISCO.

**ODbL**: Open Database License. A copyleft license used by OpenStreetMap data. Requires attribution and share-alike for derivative databases. All OSM-derived tiles must comply with ODbL terms.

**ogr2ogr**: A GDAL command-line utility for converting between geospatial data formats (Shapefile, GeoPackage, GeoJSON, CSV, KML, and 80+ others). Included in the converter container. See: [GeoJSON Authoring](07a-GEOJSON-AUTHORING.md). Related: GDAL.

**OTX**: Open Threat Exchange (AlienVault/LevelBlue). Community threat intelligence platform with 100,000+ participants sharing indicators of compromise. Provides a free API for querying and submitting threat data. See: [Threat Intelligence Feeds](13a2-THREAT-INTELLIGENCE-FEEDS.md). Related: MISP, IOC.

**OSM**: OpenStreetMap. A collaborative project that creates a free, editable map of the world. OSM data provides global coverage for power infrastructure, water infrastructure, and telecoms through community-maintained tags. See: [OSM Power Infrastructure](02c1-OSM-POWER.md). Related: PBF, Geofabrik.

**osmium**: A fast, flexible command-line tool for working with OpenStreetMap data in PBF format. Used in the converter container to filter OSM data by tags (e.g., `power=*`, `amenity=water*`). See: [OSM Extraction](04b-EXTRACT.md). Related: OSM, PBF.

**OXOT**: The parent platform for operational technology security. The OXOT Tileserver provides geographic visualization services to the broader OXOT Cyber Digital Twin ecosystem. See: [OXOT Cyber DT Integration](06d-OXOT-CYBERDT.md).

**PyPSA**: Python for Power System Analysis. An open-source toolbox for simulating and optimising modern electrical power systems. PyPSA-Eur provides the European transmission model; PyPSA-Earth extends coverage globally. See: [Awesome Electrical Grid Mapping](02c6-AWESOME-GRID-MAPPING.md). Related: earth-osm, ENTSO-E.

**PBF**: Protocolbuffer Binary Format. A compact binary format used for OpenStreetMap data files (`.osm.pbf`) and for individual vector tile payloads (`.pbf`). PBF tiles are served by tileserver-gl at the `/{z}/{x}/{y}.pbf` endpoint. Related: MVT, OSM.

**PMTiles**: A single-file archive format for pyramids of map tiles. An alternative to MBTiles that supports HTTP range requests for serverless tile serving. The converter container includes the pmtiles CLI for conversion. Related: MBTiles.

**RFC 7946**: The IETF specification defining the GeoJSON format, published in 2016. Supersedes the earlier GeoJSON specification (2008). Mandates WGS84 coordinates and right-hand polygon winding order. Related: GeoJSON, WGS84.

**SCRM**: Supply Chain Risk Management. The practice of identifying, assessing, and mitigating risks within the supply chain. Geographic visualization of supply chain dependencies is a key use case for the OXOT Tileserver. See: [Supply Chain Mapping](13e-SUPPLY-CHAIN-MAPPING.md).

**SDWIS**: Safe Drinking Water Information System. An EPA database tracking public water systems in the United States. Contains location, population served, and violation history for community water systems. See: [EPA SDWIS + WATERS](02d2-EPA-SDWIS.md). Related: CWS, EPA.

**Shapefile**: An ESRI vector data storage format widely used in GIS. Consists of multiple files (.shp, .shx, .dbf, .prj). Can be converted to GeoJSON using ogr2ogr for tile generation. Related: ogr2ogr, GeoPackage.

**STIX**: Structured Threat Information Expression. A standardized language and format for sharing cyber threat intelligence, including indicators, threat actors, campaigns, and attack patterns. Related: TAXII, IOC, MISP.

**Slippy map**: The z/x/y tile coordinate convention used by web map tile services. Zoom level `z` determines the number of tiles; `x` and `y` identify the specific tile within the grid. The tileserver serves tiles at `/{z}/{x}/{y}.pbf`. Related: tileset, vector tile.

**Source-layer**: A named layer within a vector tile. A single tileset can contain multiple source-layers (e.g., `power_lines`, `substations`, `power_plants`). Client-side layer definitions reference a specific source-layer for rendering. Related: vector tile, tileset.

**TAXII**: Trusted Automated Exchange of Indicator Information. A transport protocol for sharing STIX-formatted cyber threat intelligence data over HTTPS. Provides discovery, collection, and channel services. Related: STIX, IOC, MISP.

**TIGER/Line**: Topologically Integrated Geographic Encoding and Referencing. A geographic boundary dataset produced by the US Census Bureau containing state, county, tract, block group, and other administrative boundaries. See: [US Census TIGER/Line + ACS](02b1-CENSUS-US.md). Related: ACS, ZCTA.

**TileJSON**: A specification (maintained by Mapbox) for describing map tilesets via JSON metadata. Contains tileset name, bounds, zoom range, tile URL template, and layer descriptions. Served by tileserver-gl at `/data/<tileset>.json`. See: [TileJSON Metadata](05b-TILEJSON.md).

**Tileserver-gl**: An open-source map tile server (maintained by MapTiler) that serves vector and raster tiles from MBTiles files. The runtime container in the OXOT Tileserver architecture. See: [Architecture & Components](01a-ARCHITECTURE.md). Related: converter container.

**Tileset**: A set of map tiles organized by zoom level and tile coordinates. In the OXOT Tileserver, each `.mbtiles` file is one tileset. A tileset may contain one or more source-layers. Related: MBTiles, source-layer.

**tippecanoe**: A command-line tool (maintained by Felt) for creating vector tilesets from GeoJSON input. Handles zoom-level tile generation, feature simplification, and attribute management. The primary conversion tool in the OXOT Tileserver pipeline. See: [Conversion & Tippecanoe](04c-CONVERT.md). Related: MBTiles, GeoJSON.

**turf.js**: Advanced geospatial analysis library for JavaScript. Provides spatial operations including buffers, spatial joins, distance calculations, and area computations. Used for blast-radius modeling and proximity analysis in simulation use cases. See: [Simulation](13f-SIMULATION-WARGAMING.md). Related: GeoJSON.

**TSV**: Tab-Separated Values. A plain text format for tabular data where columns are delimited by tab characters. Some data sources (GeoNames, HIFLD) distribute data in TSV format.

**Vector tile**: A map tile containing vector data (points, lines, polygons) encoded as Protocol Buffers. Unlike raster tiles (PNG/JPEG images), vector tiles are rendered client-side, enabling dynamic styling, interactivity, and resolution independence. See: [Vector Tile Format](05c-VECTOR-TILES.md). Related: MVT, PBF, raster tile.

**WFD**: Water Framework Directive. An EU directive establishing a framework for the protection of inland surface waters, transitional waters, coastal waters, and groundwater. Referenced in European water data context. Related: WISE, EEA.

**WGS84**: World Geodetic System 1984. The geographic coordinate reference system used by GPS and mandated by the GeoJSON specification (RFC 7946). Coordinates are expressed as decimal degrees of longitude and latitude. Identified as EPSG:4326. Related: EPSG:4326, GeoJSON.

**WISE**: Water Information System for Europe. A platform maintained by the European Environment Agency (EEA) providing data on European water quality, quantity, and ecological status. See: [EEA WISE](02d3-EEA-WISE.md). Related: WFD, EEA.

**ZCTA**: ZIP Code Tabulation Area. A Census Bureau geographic unit approximating US ZIP code delivery areas. Useful for demographic analysis at the postal code level. See: [US Census TIGER/Line + ACS](02b1-CENSUS-US.md). Related: TIGER/Line, ACS.

---

## Related Pages

- [Home](INDEX.md) -- documentation entry point
- [References & Citations](10-REFERENCES.md) -- full bibliography in APA format
- [Data Sources](02-DATA-SOURCES.md) -- catalog of all 22 data sources
- [Use Cases & Implementation](13-USE-CASES.md) -- operational use case catalog
- [Custom Tiles](07-CUSTOM-TILES.md) -- creating bespoke tile layers
- [GeoJSON Authoring](07a-GEOJSON-AUTHORING.md) -- GeoJSON specification details

---

*[Home](INDEX.md) | [References](10-REFERENCES.md) | [Data Sources](02-DATA-SOURCES.md)*
