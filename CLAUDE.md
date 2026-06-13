# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview
**Three Against One** — 3-player asynchronous turn-based 2.5D strategy board game in Godot 4.6.
Three asymmetric factions (Dwarf/Elf/Orc) on a shared hex-less grid map with resources, tech trees, fog of war, and PvP/PvE combat.

## Current Status
v0.3 prototype — 100×56 terrain generation with war fog (0.3s fade animation), territorial borders, 173 resource points, Space+LMB pan/zoom camera. Hotseat turn system (Tab cycles Elf→Dwarf→Orc with +6AP/round, cap 12), unit system (3 types per faction: worker/scout/guard with BFS movement, fog-on-move reveal), **building system (11 generic building types with footprint system, turn-based production, UI panel + resource tracking)**. Town halls have persistent vision, glow effects, and star markers. Architecture modularized into independent nodes.

## Known GDScript Quirks
- `var x := arr[i]` fails when `arr` is untyped Array (returns Variant). Fix: use `var x: Type = arr[i]`.
- Similarly, `for v in [1, 2, 3]` yields Variant — use `var v: int = ...` or wrap in `int()`.
- Ternary `var x := val if cond else val2` also fails type inference. Use explicit `var x: Type = ...`.
- All indentation uses **tabs**, not spaces. Edit accordingly.
- Line endings: some files use CRLF, some LF. Godot handles both.
- Godot 4 font/color theme overrides: use `add_theme_font_size_override("font_size", N)` and `add_theme_color_override("font_color", Color(...))`. The `theme_override_font_sizes["key"] = val` syntax used in Godot 3 is gone (causes runtime error).
- Control mouse_filter: `STOP` (default) blocks events from reaching parents; `PASS` passes to parent; `IGNORE` skips the node entirely. Containers (MarginContainer, VBoxContainer, etc.) call `accept_event()` in `_gui_input` by default, consuming click events. To make containers transparent to clicks, set `mouse_filter = Control.MOUSE_FILTER_IGNORE` on all intermediate containers/labels.

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
│   ├── GridManager2D (Node2D)        — grid_manager_2d.gd (terrain gen + draw)
│   ├── ResourceManager2D (Node2D)    — resource_manager_2d.gd (resources)
│   ├── FogOfWar2D (Node2D)           — fog_of_war_2d.gd (war fog + fade animation)
│   ├── TerritoryManager2D (Node2D)   — territory_manager_2d.gd (BFS territory + borders)
│   ├── TurnManager2D (Node)          — turn_manager_2d.gd (hotseat turn + AP system)
│   ├── BuildingManager2D (Node2D)    — building_manager_2d.gd (building placement + production)
│   ├── UnitManager2D (Node2D)        — unit_manager_2d.gd (unit placement, selection, movement)
│   └── ResourceTracker (Node)        — resource_tracker.gd (per-faction inventory, turn-based collection)
└── UI (CanvasLayer)
    ├── DebugLabel (Label)            — top-left debug info
    ├── TurnLabel (Label)             — top-center turn indicator (faction-colored text)
    ├── BuildingUI (Control)          — building_ui.gd (building panel, right-side card layout)
    └── ResourcePanel (Panel)         — in-scene resource labels (wood/stone/food/iron etc.)
```

Draw order: GridManager2D → ResourceManager2D → TerritoryManager2D → UnitManager2D → FogOfWar2D. Each sibling has independent `_draw()` and `_unhandled_input()`. Units render above territory borders but below the fog overlay.

### Core Scripts (all GDScript, Godot 4.6)

| Script | Lines | Role |
|--------|-------|------|
| `scripts/grid_manager_2d.gd` | 672 | 6-phase terrain generation (mountain → ring → ocean → territories → impassable → assign terrain), terrain `_draw()`, spawn markers, coordinate utils, hash/noise, expansion to 100×56. Delegates resource placement to ResourceManager2D. |
| `scripts/resource_manager_2d.gd` | 260 | ResourceType enum, RESOURCE_DEFS table (14 types, 173 total), resource_grid, deterministic placement, diamond `_draw()`, hover signal. Queries FogOfWar2D to only show diamonds on visible tiles. |
| `scripts/fog_of_war_2d.gd` | 167 | Per-player float fog grids (0.0=explored, 0.7=unexplored), 3×3 smoothing for edge gradients, 0.3s fade animation on first reveal, reveal_area/reveal_area_immediate/is_explored API, `fog_updated(player)` signal. |
| `scripts/territory_manager_2d.gd` | 164 | BFS flood-fill territory from town halls through explored+passable tiles. `owner_grid[y][x]` (-1/0/1/2), border line rendering (2.5px faction colors), `recalc_territory(player)`, `get_cell_owner()`/`is_territory()` API. |
| `scripts/turn_manager_2d.gd` | 80 | Hotseat round-based turn system. 3 players (Elf→Dwarf→Orc→round end), +6AP/round cap 12. Signals: `round_started`, `player_turn_started/ended`, `round_ended`, `ap_changed`. `spend_ap(player, amount)` returns false if insufficient. |
| `scripts/unit_data.gd` | 41 | `class_name UnitData` — template data (name, category, move/atk/hp/vision/food_cost). Static factory methods: `worker()`, `scout()`, `guard()`. |
| `scripts/unit_manager_2d.gd` | 358 | Unit storage (Array[Dictionary] with id/data/grid_pos/hp/flags), BFS reachable-tile calculation, AP-cost movement, fog reveal on move. Renders faction-colored circles with Chinese name + HP. LMB select/move/deselect interaction. |
| `scripts/building_data.gd` | 154 | `class_name BuildingData` — 11 building template types with footprint, cost, HP, production, terrain compatibility. Static factory methods for all generic buildings. |
| `scripts/building_manager_2d.gd` | 351 | Building placement with footprint validation, `building_grid[y][x]`, faction-colored rect rendering + town hall glow/star effects, `round_ended` production, mouse hover/select interaction, town hall vision reveal. See Building System section. |
| `scripts/building_ui.gd` | 384 | Building UI panel (right-side, built in code). Two-column layout: left category sidebar + right card grid + bottom detail panel. StyleBoxFlat cards with hover effects, cost/production display. Emits `building_selected(data)` on click. |
| `scripts/resource_tracker.gd` | 105 | Per-faction resource inventory (`_resources[player][key]`). Collects building production on `round_ended`, updates UI labels. API: `add_resource()`, `get_resource()`, `update_display(player)`. |
| `scripts/main.gd` | 209 | Game state machine (LOADING/PLAYING/TURN_RESOLVE/GAME_OVER). Initializes all subsystems in order. Connects turn signals to faction-colored TurnLabel UI. Faction name/color constants. `_place_initial_buildings()` for initial building setup. |
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
| `building_grid[y][x]` | BuildingManager2D | int (building_id or -1) | 100×56 |
| `fog_grids[player][y][x]` | FogOfWar2D | float (0.0–0.7) | 3 × 100×56 |
| `owner_grid[y][x]` | TerritoryManager2D | int (-1/0/1/2) | 100×56 |

All grids use outer loop y (rows), inner x (cols). All generation is **deterministic** via `_simple_hash(x, y, seed)`.

### Turn System (`TurnManager2D`)

Hotseat round-based: Elf(0) → Dwarf(1) → Orc(2) → round end → next round. Tab key ends current player's turn.

- **AP**: Each player gains +6 AP per round (cap 12). Movement costs 1 AP per tile (prototype simplified). `spend_ap(player, amount)` returns false if insufficient.
- **Signal order**: `round_started(round)` → `player_turn_started(player)` → `player_turn_ended(player)` (×3 per round) → `round_ended(round)` → loop.
- `start_game()` must be called AFTER all signal connections are made, or the first signals are missed.
- Connected to UnitManager2D for player turn start/end (resets has_moved/has_attacked flags, clears selection).

### Unit System (`UnitManager2D` + `UnitData`)

Each faction starts with 3 units: 1 worker (move1/atk0/hp3/vision1), 1 scout (move3/atk1/hp3/vision3), 1 guard (move1/atk3/hp6/vision1). All units stored in `_units: Array[Dictionary]`, rendered via `_draw()` as faction-colored circles.

- **Selection**: LMB on own unit → white selection circle + translucent reachable-tile highlights. LMB on reachable tile → move (AP deducted). LMB elsewhere → deselect.
- **Movement**: BFS from unit position with `move_max` depth. Skips impassable terrain and occupied tiles. Path length = AP cost. After moving, calls `fog_mgr.reveal_area(player, x, y, unit.vision)`.
- **Fog interaction**: Units are rendered below fog overlay (visible through fog in prototype). Movement reveals fog at the destination position based on unit's vision stat.

### Building System (`BuildingManager2D` + `BuildingData` + `BuildingUI` + `ResourceTracker`)

11 generic building types all factions share (no faction-specific buildings yet). Buildings are placed on the grid with a **footprint** system (`footprint: Vector2i`), stored in `building_grid[y][x]` where multi-tile buildings write the same `building_id` to all occupied cells.

**Footprint sizes (current):**
- Town Hall: **2×2** (阵营核心)
- Barracks Lv1, all resource buildings: **1×1** (Barracks upgrade path: 1×1→2×1→2×2)

**Key data per building:** name, category, cost (gold/wood/stone/iron/food), hp_max, production dict (e.g. `{ "wood": 3 }`), terrain_compatibility (Array of `TerrainData.Terrain`), max_per_faction, footprint.

**Initial placement** (in `main.gd._place_initial_buildings()`):
- Each faction: 1 Town Hall (2×2, near spawn) + 1 Lumber Camp + 1 Quarry + 1 Farm (placed at nearby empty tiles)
- Buildings placed BEFORE units to avoid overlap

**Town hall rendering** (`BuildingManager2D._draw()`):
- Double-layer outer glow: faction color at a=0.3 (4px out) and a=0.2 (8px out)
- Thicker border (3px vs 1.5px for other buildings)
- Larger font (13px vs 11px), with "★ 主城 ★" star marker above the building

**Town hall vision:**
- `reveal_all_town_hall_vision()` — called after initial placement, reveals fog radius 4 around all town halls for all players
- `_reveal_town_hall_vision(player)` — called each turn for the current player's town halls (radius 4, Manhattan distance)
- `place_building()` auto-reveals fog radius 3 around any newly placed building

**BuildingUI Panel** (`building_ui.gd`):
- Right-side panel built entirely in code (no .tscn), positioned at offset_left=1400, width≈500px
- Two-column layout: left 80px category sidebar + right 2-column card grid + bottom 60px detail panel
- Root Control uses `mouse_filter = PASS` to avoid blocking map interaction
- Cards use `mouse_filter = STOP` with `gui_input.connect()` for click detection; all interior containers use `IGNORE`
- Categories: 基础/资源/军事/侦察/金币/主城 (maps to `BuildingData.BuildingCategory`)
- Each card shows: building name + build count (x/y), cost (yellow), production (green)
- Cards have StyleBoxFlat backgrounds (dark bg, gray border, 4px rounded corners) with hover brightening
- Bottom detail panel updates on card click and emits `building_selected(data)` signal
- `_format_cost()` skips zero-cost resources; `_format_production()` shows "+N资源/回合"

**Resource Tracker** (`resource_tracker.gd`):
- Per-faction inventory: `_resources[player]["wood"/"stone"/"food"/etc]`
- Connected to `round_ended` signal: iterates all buildings, adds production to the owning faction's inventory
- UI labels updated via `update_display(player)` — shows 7 resource types (木材/石料/食物/铁矿/魔尘/古木/金矿)
- `resources_updated(player)` signal for UI refresh

**Turn integration:**
- `round_ended` signal → `ResourceTracker` collects production from all buildings → adds to faction inventories
- `player_turn_started` signal → `building_ui.refresh(player)` rebuilds cards for the current faction
- `ap_changed` signal → also refreshes building UI to reflect latest resource counts

**Unit interaction:**
- `UnitManager2D._is_tile_empty()` checks `BuildingManager2D.is_tile_occupied()` — units cannot walk through buildings
- Buildings render below units but above territory borders

**Placement validation** (`_can_place()`):
1. All footprint tiles must be in faction's territory (TerritoryManager2D.get_cell_owner)
2. All footprint tiles must have compatible terrain (BuildingData.terrain_compatibility)
3. All footprint tiles must be empty (no existing building)
4. Must not exceed max_per_faction limit

**11 building types:**
Town Hall(2×2), Lumber Camp, Quarry, Farm, Warehouse, Mine(iron), Extraction Tower, Ancient Wood Harvest, Barracks Lv1, Scout Post, Gold Mine Shaft

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

### Territory System (`TerritoryManager2D`)

BFS flood-fill from town halls through explored+passable tiles. Player mapping: 0=Elf, 1=Dwarf, 2=Orc.

- **`recalc_territory(player)`** — clears old ownership, BFS orthogonally from all town halls. Only enters tiles where `fog_mgr.is_explored(player, nx, ny)` AND `TerrainData.is_passable(terrain)`. Emits `territory_updated(player)`.
- **Border rendering** — `_draw()` iterates owned tiles, checks 4 neighbors. If neighbor owner differs, draws 2.5px line along the shared edge. Colors: Elf green `#2e9926`, Dwarf gold `#cca619`, Orc red `#cc4026`.
- **Town halls** — each faction starts with 1. Can build more (500g + T3 resource) for strategic redundancy. Each anchors a connected territory zone.
- **Enemy on your territory** — auto-revealed (fog removed), combat if garrisoned. Enemy buildings on your tiles flip ownership to them — must be retaken.

### 14 Resource Types (173 total)

Gold Mine(18), Ancient Forest(16), Quarry(15), Fertile Plain(15), Iron Mine(14), Magic Node(14), Ancient Tree(13), Rune Stone(13), Abandoned Post(12), Star Crystal(12), World Tree Root(12), Dragon Crystal(10), Hot Spring(3), Ancient Relic(2).

Rendered as colored diamond markers only on tiles where `FogOfWar2D.get_fog(player, x, y) == 0.0`.

### Key Constants
- Grid: 100×56 (16:9), 56×56 land centered at LAND_OFFSET_X=22, 32px tiles
- Viewport: 1920×1080 (stretch: canvas_items)
- Camera: zoom 0.55–2.5, default 1.0 (~0.55 shows full 100×56 map)
- Bounds: x=[-1800, 1800], y=[-1096, 1096] (200px margin)

## Development Notes
- **Godot executable**: `C:\tools\godot\Godot_v4.6.2-stable_win64_console.exe` (or `..._win64.exe` for GUI). Downloaded locally for automated validation.
- **Validation**: `Godot_v4.6.2-stable_win64_console.exe --path . --headless --check-only` to check for GDScript parse errors without launching window.
- All rendering uses `_draw()` + `draw_rect()` — no TileMap nodes, no sprite atlases
- Player spawns (land coords, offset by LAND_OFFSET_X=22 at render): Elf at (12,13)..(14,13), Dwarf at (12,43)..(14,43), Orc at (39,35)..(41,35)
- Signal chain: `ResourceManager2D.resource_hovered(text)` → `main.gd` → `DebugLabel`
- Node reference across siblings: use `get_parent().get_node("TargetNode")` instead of `@onready` when the target is later in tree order (avoids init-order race)
- Fog is float-based (0.0=explored, 0.7=unexplored) with 3×3 neighborhood smoothing for edge gradients. First reveal triggers a 0.3s fade animation (lerp 0.7→0.0), then emits `fog_updated(player)` signal which triggers territory recalculation.
- Input mappings: camera_zoom_in/out (scroll), select (LMB), end_turn (Tab)
- MSAA 2× enabled in rendering settings
- No design doc files should be edited by code — they are reference only
- Input handling in `main.gd` uses direct keycode checks (`event.keycode == KEY_ENTER or event.keycode == KEY_TAB`) rather than InputMap actions, because InputMap can be corrupted by script-based editing and Tab can be intercepted by the Godot editor's own shortcuts when running embedded
- `dev-roadmap/` — local web-based development roadmap tool. Start with `start.bat` (Python backend + HTML frontend). Tracks module completion status and development notes in `state.json`.
