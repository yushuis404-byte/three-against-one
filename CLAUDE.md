# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview
**Three Against One** — 3-player asynchronous turn-based 2.5D strategy board game in Godot 4.6.
Three asymmetric factions (Dwarf/Elf/Orc) on a shared hex-less grid map with resources, tech trees, fog of war, and PvP/PvE combat.

## Current Status
v0.2 prototype — 100×56 terrain generation with 16:9 ocean + camera controls. All game logic (turns, resources, combat, tech) is unimplemented.

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
| `scripts/main.gd` | Game state machine (LOADING → PLAYING → TURN_RESOLVE → GAME_OVER). Entry point. |
| `scripts/grid_manager_2d.gd` | 100×56 terrain generation (6-phase pipeline + expand to 16:9). Draws map via `_draw()` (no tile nodes). |
| `scripts/camera_controller_2d.gd` | Stardew Valley-style camera: Space+LMB drag pan, scroll zoom. Clamps to map bounds. |
| `scripts/terrain_data.gd` | `class_name TerrainData` — 12 terrain types with colors, passability, buildability. Shared data/enum singleton. |

### Terrain Generation Pipeline (7 Phases in grid_manager_2d)
1. **Mountain** — central volcano/dragon nest with 3 corridor paths and scattered ruins
2. **Resource ring** — band around the mountain
3. **Ocean** — edge-based threshold with continental noise, bays, peninsulas, fuzzy coastline
4. **Territories** — Voronoi-like 3-faction split with competition-ratio buffer zones
5. **Scattered impassable** — ~120 random uncrossable tiles
6. **Assign terrain** — final faction/buffer/resource terrain coloring
7. **Expand** — blit 56×56 land to center of 100×56 grid, fill sides with ocean (16:9)

### Grid Coordinates
- Grid: `terrain_grid[y][x]`, outer loops iterate y (rows), inner loops iterate x (cols)
- `grid_to_world(x, y)` → world `Vector2` centered at origin
- `world_to_grid(world_pos)` → grid `Vector2i`
- Terrain types via `TerrainData.Terrain` enum: VOID, WATER, PLAIN_DWARF, MOUNTAIN_DWARF, FOREST_ELF, GLADE_ELF, WASTELAND_ORC, SWAMP_ORC, DRAGON_MOUNT, DRAGON_NEST, CORRIDOR, RUINS

### Key Constants
- Full grid: 100×56 (16:9), 56×56 land mass centered at offset_x=22, 32px tiles
- Viewport: 1920×1080 (stretch: canvas_items)
- Camera: zoom 0.5–2.5, default 1.0 (0.5 shows full 100×56 map)
- Bounds: x=[-1800, 1800], y=[-1096, 1096] (200px margin)

## Development Notes
- All rendering uses `_draw()` + `draw_rect()` — no TileMap nodes, no sprite atlases
- Input mapping in `project.godot` (not code): camera_zoom_in/out (scroll), select (LMB), end_turn (Space)
- MSAA 2× enabled in rendering settings
