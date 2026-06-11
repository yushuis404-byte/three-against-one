# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview
**Three Against One** — 3-player asynchronous turn-based 2.5D strategy board game in Godot 4.6.
Three asymmetric factions (Dwarf/Elf/Orc) on a shared hex-less grid map with resources, tech trees, fog of war, and PvP/PvE combat.

## Current Status
v0.2 prototype — 100×56 terrain generation with war fog, 173 resource points, Space+LMB pan/zoom camera. Architecture modularized into independent nodes. Game logic (turns, combat, tech) is unimplemented.

## Known GDScript Quirks
- `var x := arr[i]` fails when `arr` is untyped Array (returns Variant). Fix: use `var x: Type = arr[i]`.
- Similarly, `for v in [1, 2, 3]` yields Variant — use `var v: int = ...` or wrap in `int()`.
- All indentation uses **tabs**, not spaces. Edit accordingly.
- Line endings: some files use CRLF, some LF. Godot handles both.

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
│   ├── GridManager2D (Node2D)      — grid_manager_2d.gd (terrain gen + draw)
│   ├── ResourceManager2D (Node2D)  — resource_manager_2d.gd (resources)
│   └── FogOfWar2D (Node2D)         — fog_of_war_2d.gd (war fog)
└── UI (CanvasLayer)
    └── DebugLabel (Label)
```

Draw order: GridManager2D (terrain) → ResourceManager2D (diamonds, only on visible tiles) → FogOfWar2D (black overlay on top). Each sibling has independent `_draw()` and `_unhandled_input()`.

### Core Scripts (all GDScript, Godot 4.6)

| Script | Lines | Role |
|--------|-------|------|
| `scripts/grid_manager_2d.gd` | 672 | 6-phase terrain generation (mountain → ring → ocean → territories → impassable → assign terrain), terrain `_draw()`, spawn markers, coordinate utils, hash/noise, expansion to 100×56. Delegates resource placement to ResourceManager2D. |
| `scripts/resource_manager_2d.gd` | 260 | ResourceType enum, RESOURCE_DEFS table (14 types, 173 total), resource_grid, deterministic placement, diamond `_draw()`, hover signal. Queries FogOfWar2D to only show diamonds on visible tiles. |
| `scripts/fog_of_war_2d.gd` | 102 | Per-player float fog grids (0.0=visible, 0.5=fogged), 3×3 smoothing for edge gradients, reveal_area/explore_area/get_fog API. |
| `scripts/main.gd` | 47 | Game state machine, connects resource_hovered signal to DebugLabel, sets initial fog reveals. |
| `scripts/camera_controller_2d.gd` | 101 | Space+LMB drag pan, scroll zoom, clamp to map bounds. |
| `scripts/terrain_data.gd` | 60 | `class_name TerrainData` — 12 terrain types with colors, passability, buildability. Global enum/data singleton. |

### Terrain Generation Pipeline (6 Phases + expansion in grid_manager_2d)

All phases operate on a 56×56 land grid, then expanded to 100×56 (16:9).

1. **Mountain** — central volcano/dragon nest, 3 corridor paths, scattered ruins
2. **Resource ring** — band around the mountain (ZoneTag only, terrain assigned in Phase 6)
3. **Ocean** — edge-based threshold + continental noise + **elliptical corner rounding** (`CORNER_ROUNDING=4.0`), bays, peninsulas, fuzzy coastline
4. **Territories** — Voronoi-like 3-faction split with competition-ratio blending → 9 `ZoneTag` regions
5. **Scattered impassable** — ~120 random uncrossable tiles
6. **Assign terrain** — faction/buffer/resource terrain coloring per ZoneTag

After Phase 6, ResourceManager2D places resources, then the 56×56 grid is expanded to 100×56.

### Grid Data Model

| Grid | In | Type | Size |
|------|----|------|------|
| `terrain_grid[y][x]` | GridManager2D | `TerrainData.Terrain` enum | 100×56 |
| `zone_grid[y][x]` | GridManager2D | `ZoneTag` enum (local) | 100×56 |
| `resource_grid[y][x]` | ResourceManager2D | `ResourceType` enum (local) | 100×56 |
| `fog_grids[player][y][x]` | FogOfWar2D | float (0.0–0.5) | 3 × 100×56 |

All grids use outer loop y (rows), inner x (cols). All generation is **deterministic** via `_simple_hash(x, y, seed)`.

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

Rendered as colored diamond markers only on tiles where `FogOfWar2D.get_fog(player, x, y) == 0.0`.

### Key Constants
- Grid: 100×56 (16:9), 56×56 land centered at LAND_OFFSET_X=22, 32px tiles
- Viewport: 1920×1080 (stretch: canvas_items)
- Camera: zoom 0.55–2.5, default 1.0 (~0.55 shows full 100×56 map)
- Bounds: x=[-1800, 1800], y=[-1096, 1096] (200px margin)

## Development Notes
- All rendering uses `_draw()` + `draw_rect()` — no TileMap nodes, no sprite atlases
- Player spawns (land coords, offset by LAND_OFFSET_X=22 at render): Elf at (12,13)..(14,13), Dwarf at (12,43)..(14,43), Orc at (39,35)..(41,35)
- Signal chain: `ResourceManager2D.resource_hovered(text)` → `main.gd` → `DebugLabel`
- Node reference across siblings: use `get_parent().get_node("TargetNode")` instead of `@onready` when the target is later in tree order (avoids init-order race)
- Fog is float-based (0.0=visible, 0.5=fogged) with 3×3 neighborhood smoothing for edge gradients
- Input mappings: camera_zoom_in/out (scroll), select (LMB), end_turn (Spacebar)
- MSAA 2× enabled in rendering settings
- No design doc files should be edited by code — they are reference only
