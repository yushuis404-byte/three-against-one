# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview
**Three Against One** — 3-player asynchronous turn-based 2.5D strategy board game in Godot 4.6.
Three asymmetric factions (Dwarf/Elf/Orc) on a shared hex-less grid map with resources, tech trees, fog of war, and PvP/PvE combat.

## Current Status
v0.2 prototype — 100×56 terrain generation with 16:9 ocean, elliptical landmass, 173 resource points with diamond markers, Space+LMB pan/zoom camera. Game logic (turns, combat, tech) is unimplemented.

## Commands
- **Open project**: Open `project.godot` in Godot 4.6 editor
- **Run game**: Click "Play" (F5) in Godot editor, or `godot4 --path .` from terminal
- **No tests/CI**: Project has no test framework yet
- **Game design docs** (reference, not code):
  - `游戏策划_v12.md` — full game design document
  - `地图模块_游戏策划_v12.md` — map module design
- **Dev plan**: `开发路径表.md` — modular development roadmap with parallel tracks and phases

## Architecture

### Scene Tree (`scenes/main.tscn`)
```
Main (Node2D) — main.gd (game state controller)
├── GameCamera (Camera2D) — camera_controller_2d.gd
├── GameBoard (Node2D)
│   └── GridManager2D (Node2D) — grid_manager_2d.gd
└── UI (CanvasLayer)
    └── DebugLabel (Label)
```

### Core Scripts (all GDScript, no third-party dependencies)

| Script | Role |
|--------|------|
| `scripts/main.gd` | Game state machine (LOADING→PLAYING→TURN_RESOLVE→GAME_OVER). Connects grid_manager resource hover signal to DebugLabel. |
| `scripts/grid_manager_2d.gd` | 100×56 terrain + resource generation (8-phase pipeline). Draws everything via `_draw()` — no tile nodes. Drives the entire map. |
| `scripts/camera_controller_2d.gd` | Stardew Valley-style camera: Space+LMB drag pan, scroll zoom. Clamps to map bounds. |
| `scripts/terrain_data.gd` | `class_name TerrainData` — 12 terrain types with colors, passability, buildability. Global enum/data singleton. |

### Terrain Generation Pipeline (8 Phases in grid_manager_2d)

All phases operate on a 56×56 land grid. Step 7 expands to 100×56 (16:9).

1. **Mountain** — central volcano/dragon nest, 3 corridor paths, scattered ruins
2. **Resource ring** — band around the mountain
3. **Ocean** — edge-based threshold + continental noise + **elliptical corner rounding** (`CORNER_ROUNDING=4.0`), bays, peninsulas, fuzzy coastline
4. **Territories** — Voronoi-like 3-faction split with competition-ratio blending → 9 `ZoneTag` regions (3 faction + 3 buffer + mountain + ring + ocean)
5. **Scattered impassable** — ~120 random uncrossable tiles
6. **Assign terrain** — faction/buffer/resource terrain coloring per ZoneTag
7. **Place resources** — 14 resource types (173 total), deterministic placement per zone constraints
8. **Expand** — blit 56×56 land to center of 100×56 grid, fill sides with ocean (WATER)

### Grid & Resource Data Model

**Grid**: `terrain_grid[y][x]` — `TerrainData.Terrain` enum values. Outer loop y (rows), inner x (cols).
**Zone**: `zone_grid[y][x]` — parallel `ZoneTag` enum (9 region types).
**Resources**: `resource_grid[y][x]` — parallel `ResourceType` enum (14 types, 0=NONE).
**World coords**: `grid_to_world(x, y)` → centered `Vector2`; `world_to_grid(world_pos)` → `Vector2i`.

All generation is **deterministic** — uses `_simple_hash(x, y, seed)` for noise and Fisher-Yates shuffle (no Godot RNG). Same inputs always produce the same map.

### ZoneTag Regions

| Tag | Description |
|-----|-------------|
| ELF_TERRITORY | NW faction zone (seed 13,13) |
| DWARF_TERRITORY | SW faction zone (seed 13,43) |
| ORC_TERRITORY | SE faction zone (seed 43,43) |
| EMERALD_WOODLANDS | Buffer between Elf and Dwarf |
| SCORCHED_BADLANDS | Buffer between Dwarf and Orc |
| RIFT_HIGHLANDS | Buffer between Elf and Orc |
| RESOURCE_RING | Band around central mountain |
| MOUNTAIN_NEST / MOUNTAIN_BODY / MOUNTAIN_PATH | Central mountain complex |
| OCEAN | Outside the landmass |

### 14 Resource Types (173 total)

Gold Mine(18), Ancient Forest(16), Quarry(15), Fertile Plain(15), Iron Mine(14), Magic Node(14), Ancient Tree(13), Rune Stone(13), Abandoned Post(12), Star Crystal(12), World Tree Root(12), Dragon Crystal(10), Hot Spring(3), Ancient Relic(2).

Placed per faction zone + buffer zone distributions. Rendered as colored diamond markers on the map.

### Key Constants
- Grid: 100×56 (16:9), 56×56 land centered at LAND_OFFSET_X=22, 32px tiles
- Viewport: 1920×1080 (stretch: canvas_items)
- Camera: zoom 0.55–2.5, default 1.0 (~0.55 shows full 100×56 map)
- Bounds: x=[-1800, 1800], y=[-1096, 1096] (200px margin)

## Development Notes
- All rendering uses `_draw()` + `draw_rect()` — no TileMap nodes, no sprite atlases
- Player spawns: Elf at (12,13)..(14,13), Dwarf at (12,43)..(14,43), Orc at (39,35)..(41,35) — all in land coords, offset by LAND_OFFSET_X at render time
- Signal-based hover: `grid_manager.resource_hovered(text)` → `main.gd` → `DebugLabel`
- Input mappings: camera_zoom_in/out (scroll), select (LMB), end_turn (Spacebar)
- MSAA 2× enabled in rendering settings
- No design doc files should be edited by code — they are reference only
