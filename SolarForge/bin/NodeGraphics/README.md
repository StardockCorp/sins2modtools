# Node Graphics for SolarForge Scenario Editor

This directory contains graphics assets used to replace colored dots in the scenario editor's galaxy chart view.

## Directory Structure

- **Stars/** - Graphics for stellar objects (red stars, blue stars, etc.)
- **Planets/** - Graphics for planetary objects (terran planets, gas giants, etc.)
- **Structures/** - Graphics for artificial structures (starbases, stations, etc.)
- **Special/** - Graphics for special objects (nebulae, asteroid fields, etc.)

## Supported File Formats

- PNG (recommended for new graphics)
- DDS (for optimized game assets)
- BMP, JPG, JPEG (basic support)

## Naming Convention

Graphics should be named to match the `EditorVisualTag` or `Name` of the corresponding `GalaxyChartNodeFilling`:

- Use lowercase
- Replace spaces with underscores
- Examples:
  - "Red Star" → `red_star.png`
  - "Terran Planet" → `terran_planet.png`
  - "Mining Station" → `mining_station.png`

## Fallback Behavior

If no custom graphic is found for a node type, the system will fall back to the original colored dot rendering.

## Size Recommendations

- Graphics will be automatically scaled to match the zoom level
- Recommended base size: 64x64 pixels
- Higher resolutions (128x128 or 256x256) will provide better quality at high zoom levels

## Adding New Graphics

1. Create your graphic file in the appropriate subdirectory
2. Name it according to the convention above
3. The system will automatically detect and use the new graphic
4. No code changes required for basic graphics additions