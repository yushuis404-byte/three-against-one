# AGENTS.md

This file provides guidance to Codex (Codex.ai/code) when working with code in this repository.

## Project Overview
**Three Against One** — 3-player asynchronous turn-based 2.5D strategy board game in Godot 4.6.
Three asymmetric factions (Elf/Dwarf/Orc) on a shared hex-less grid map with resources, tech trees, fog of war, and PvP/PvE combat.

## Current Status
v0.3 prototype — 100×56 terrain generation with war fog (0.3s fade animation), territorial borders, 173 resource points, Space+LMB pan/zoom camera. Hotseat turn system (Tab cycles Elf→Dwarf→Orc with +6AP/round, cap 12). Unit system (3 types per faction: worker/scout/guard with BFS movement, fog-on-move reveal, **real-time duel combat with visual effects**). Building system (12 generic types with footprint system, turn-based production, **interactive placement mode with ghost preview + validation**, UI panel + resource tracking, **garrison system**, gold economy chain: resource point → gold mine shaft (garrison) → gold_ore). **Worker recruitment** (招募营 building, R key to recruit workers for 1 food + 1 AP). **Gathering system** (workers on resource nodes collect resources next turn). Architecture modularized into independent nodes.

## Known GDScript Quirks
- `var x := arr[i]` fails when `arr` is untyped Array (returns Variant). Fix: use `var x: Type = arr[i]`.
- Similarly, `for v in [1, 2, 3]` yields Variant — use `var v: int = ...` or wrap in `int()`.
- Ternary `var x := val if cond else val2` also fails type inference. Use explicit `var x: Type = ...`.
- All indentation uses **tabs**, not spaces. Edit accordingly.
- Line endings: some files use CRLF, some LF. Godot handles both.
- Godot 4 font/color theme overrides: use `add_theme_font_size_override("font_size", N)` and `add_theme_color_override("font_color", Color(...))`. The `theme_override_font_sizes["key"] = val` syntax used in Godot 3 is gone (causes runtime error).
- Control mouse_filter: `STOP` (default) blocks events from reaching parents; `PASS` passes to parent; `IGNORE` skips the node entirely. Containers (MarginContainer, VBoxContainer, etc.) call `accept_event()` in `_gui_input` by default, consuming click events. To make containers transparent to clicks, set `mouse_filter = Control.MOUSE_FILTER_IGNORE` on all intermediate containers/labels.
- **Edit tool + Chinese characters**: The Edit tool cannot match lines containing Chinese fullwidth characters like `# ========== 回合产出 ==========` due to Unicode normalization differences. Use Python scripts (via Bash) to insert/modify text in files with Chinese content.
- **Node reference across siblings**: use `get_parent().get_node("TargetNode")` instead of `@onready` when the target is later in tree order (avoids init-order race). BuildingManager2D, UnitManager2D, etc. all use this pattern in `_ready()`.

## Commands
- **Open project**: Open `project.godot` in Godot 4.6 editor
- **Run game**: Click "Play" (F5) in Godot editor, or `godot4 --path .` from terminal
- **Validate syntax** (no GUI): `C:/tools/godot/Godot_v4.6.2-stable_win64_console.exe --path . --headless --check-only`
- **No tests/CI**: Project has no test framework yet
- **Game design docs** (reference, not code):
  - `游戏策划_v12.md` — full game design document (v13, reflects actual v0.3 implementation)
  - `地图模块_游戏策划_v12.md` — map module design (v13, updated with 100×56, 6-phase generation)
- **Dev plan**: `开发路径表.md` — modular development roadmap with parallel tracks and phases
- **Dev roadmap tool**: `dev-roadmap/start.bat` — local Python+HTML roadmap tracker

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
│   ├── BuildingManager2D (Node2D)    — building_manager_2d.gd (building placement + production + garrison)
│   ├── UnitManager2D (Node2D)        — unit_manager_2d.gd (unit placement, selection, movement, combat)
│   ├── GatheringManager2D (Node2D)   — gathering_manager_2d.gd (worker resource collection)
│   └── ResourceTracker (Node)        — resource_tracker.gd (per-faction inventory, turn-based collection)
└── UI (CanvasLayer)
    ├── DebugLabel (Label)            — top-left debug info
    ├── TurnLabel (Label)             — top-center turn indicator (faction-colored text)
    ├── BuildingUI (Control)          — building_ui.gd (building panel, right-side card layout)
    ├── ResourcePanel (Panel)         — in-scene resource labels (gold/wood/stone/food etc.)
    └── UnitInfoPanel (Control)       — unit_info_panel.gd (bottom unit details panel, built in code)
```

Draw order: GridManager2D → ResourceManager2D → TerritoryManager2D → UnitManager2D → BuildingManager2D → FogOfWar2D. Each sibling has independent `_draw()` and `_unhandled_input()`. Units render above territory borders but below the fog overlay.

**Node reference pattern**: Managers use `get_parent().get_node("OtherManager")` in `_ready()` to reference siblings (avoids scene tree init-order issues with `@onready`).

### Core Scripts (all GDScript, Godot 4.6)

| Script | Lines | Role |
|--------|-------|------|
| `scripts/grid_manager_2d.gd` | 672 | 6-phase terrain generation (mountain → ring → ocean → territories → impassable → assign terrain), terrain `_draw()`, spawn markers, coordinate utils, hash/noise, expansion to 100×56. Delegates resource placement to ResourceManager2D. |
| `scripts/resource_manager_2d.gd` | 340 | ResourceType enum, RESOURCE_DEFS table (14 types, 173 total), resource_grid, deterministic placement, diamond `_draw()`, hover signal, gather_result/remove_resource API. Queries FogOfWar2D to only show diamonds on visible tiles. |
| `scripts/fog_of_war_2d.gd` | 179 | Per-player float fog grids (0.0=explored, 0.7=unexplored), 3×3 smoothing for edge gradients, 0.3s fade animation on first reveal, reveal_area/reveal_area_immediate/is_explored API, `fog_updated(player)` signal. |
| `scripts/territory_manager_2d.gd` | 163 | BFS flood-fill territory from town halls through explored+passable tiles. `owner_grid[y][x]` (-1/0/1/2), border line rendering (2.5px faction colors), `recalc_territory(player)`, `get_cell_owner()`/`is_territory()` API. |
| `scripts/turn_manager_2d.gd` | 79 | Hotseat round-based turn system. 3 players (Elf→Dwarf→Orc→round end), +6AP/round cap 12. Signals: `round_started`, `player_turn_started/ended`, `round_ended`, `ap_changed`. `spend_ap(player, amount)` returns false if insufficient. |
| `scripts/unit_data.gd` | 40 | `class_name UnitData` — template data (name, category, move/atk/hp/vision/food_cost). Static factory methods: `worker()`, `scout()`, `guard()`. |
| `scripts/unit_manager_2d.gd` | 642 | Unit storage (Array[Dictionary]), BFS reachable-tile calculation, AP-cost movement, fog reveal on move. Renders faction-colored circles with Chinese name + HP. LMB select/move/deselect. **Combat system**: Timer-based alternating 1s-interval attack until death, visual effects (flash white, red "-N" damage text floating upward, unit icon shake). |
| `scripts/building_data.gd` | 188 | `class_name BuildingData` — 12 building template types with footprint, cost (gold/wood/stone/iron/food), HP, production, terrain compatibility. Categories: INFRA/T1_RESOURCE/MILITARY/SCOUT/RECRUIT/TOWN_HALL. `is_special_building` flag for special placement/garrison logic (gold mine shaft). Static factory methods for all buildings. |
| `scripts/building_manager_2d.gd` | 763 | Building placement with footprint validation, `building_grid[y][x]`, faction-colored rect rendering + town hall glow/star effects, `round_ended` production, mouse hover/select. **Placement mode**: start/cancel placement, green/red ghost preview, real-time validation (resources + AP + territory + terrain + occupancy + limit), resource deduction + 2AP cost on build. **Garrison system**: garrison/ungarrison units, production bonus, garrison dots rendering. **Recruit system**: R key on selected 招募营 → spawns worker (costs 1 food + 1 AP). |
| `scripts/building_ui.gd` | 388 | Building UI panel (right-side, built in code). Two-column layout: left category sidebar + right 2-column card grid + bottom detail panel. StyleBoxFlat cards with hover effects, cost/production display, built count (x/y). Categories: 基础/资源/军事/侦察/招募/主城. Emits `building_selected(data)` on card click. |
| `scripts/resource_tracker.gd` | 125 | Per-faction resource inventory (`_resources[player][key]`). 8 resource types including "gold" (initial 0) and "gold_ore". Collects building production on `round_ended`, adds garrison bonus separately (supports zero-production buildings like gold mine shaft). API: `add_resource()`, `get_resource()`, `spend_resource()`, `update_display(player)`. |
| `scripts/gathering_manager_2d.gd` | 103 | Tracks workers on resource nodes. On player turn start, checks if worker still on node → collects resources → removes resource from map → floating text. |
| `scripts/unit_info_panel.gd` | 203 | Bottom unit detail panel (built in code). Shows faction-colored name bar, HP bar, ATK/MOVE/VISION/FOOD stats, movement/attack status. |
| `scripts/main.gd` | 230 | Game state machine (LOADING/PLAYING/TURN_RESOLVE/GAME_OVER). Initializes all subsystems, connects signals. Routes `building_ui.building_selected` → `building_manager.start_placement`. |
| `scripts/camera_controller_2d.gd` | 100 | Space+LMB drag pan, scroll zoom, clamp to map bounds. |
| `scripts/terrain_data.gd` | 59 | `class_name TerrainData` — 12 terrain types with colors, passability, buildability. Global enum/data singleton. |

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

- **AP**: Each player gains +6 AP per round (cap 12). Movement costs 1 AP per tile. Building costs 2 AP. `spend_ap(player, amount)` returns false if insufficient.
- **Signal order**: `round_started(round)` → `player_turn_started(player)` → `player_turn_ended(player)` (×3 per round) → `round_ended(round)` → loop.
- `start_game()` must be called AFTER all signal connections are made, or the first signals are missed.
- Connected to UnitManager2D for player turn start/end (resets has_moved/has_attacked flags, clears selection).
- Connected to BuildingManager2D for town hall vision refresh on player turn start and production on round end.
- Connected to ResourceTracker for production collection on round end.

### Unit System (`UnitManager2D` + `UnitData`)

Each faction starts with 3 units: 1 worker (move1/atk0/hp3/vision1), 1 scout (move3/atk1/hp3/vision3), 1 guard (move1/atk3/hp6/vision1). All units stored in `_units: Array[Dictionary]`, rendered via `_draw()` as faction-colored circles.

- **Selection**: LMB on own unit → white selection circle + translucent reachable-tile highlights. LMB on reachable tile → move (AP deducted). LMB elsewhere → deselect.
- **Movement**: BFS from unit position with `move_max` depth. Skips impassable terrain, building-occupied tiles (except garrisonable buildings). Path length = AP cost. After moving, reveals fog at destination based on unit's vision stat. Workers auto-register gathering via GatheringManager2D.
- **Garrison**: Move onto own resource building → garrison unit inside. Click garrisoned building → ungarrison one unit to nearest empty tile.
- **Combat**: LMB adjacent enemy unit → initiate duel. Timer-based alternating attacks (1s interval). Attacker deals ATK damage to defender. Visuals: flash white, red "-N" damage text floating upward, unit shake (randomized offset, ~0.12s ease-out). Continues until one unit dies. Combat locks all input until resolved.
- **Fog interaction**: Units render below fog overlay but are visible through fog (prototype simplification). Movement reveals fog at destination.

### Building System (`BuildingManager2D` + `BuildingData` + `BuildingUI` + `ResourceTracker`)

12 generic building types all factions share. Buildings placed on grid with **footprint** system (`footprint: Vector2i`). Multi-tile buildings write same `building_id` to all occupied cells in `building_grid[y][x]`.

**Special building flag**: `is_special_building` on BuildingData marks buildings that need special placement (gold resource point check) and garrison behavior (worker-only, garrison-based production). Currently used by gold mine shaft.

**Footprint sizes:** Town Hall: 2×2, all others: 1×1.

**Placement mode flow:**
1. Click right-side building card → `building_ui.building_selected(data)` → `main.gd` routes to `building_manager.start_placement(data, faction)`
2. Mouse moves → ghost preview (green=valid, red=invalid) at snapped grid position, real-time validation
3. LMB on valid position → deduct resources (gold/wood/stone/iron/food), deduct 2 AP, call `place_building()`, exit placement mode
4. RMB → cancel placement

**Placement validation** (`_check_placement_valid` + `_can_place`):
1. Resource check: gold vs `cost_gold`, wood/stone/iron/food against costs
2. AP check: current player must have ≥ 2 AP
3. All footprint tiles in faction's territory (TerritoryManager2D)
4. All footprint tiles have compatible terrain (BuildingData.terrain_compatibility)
5. All footprint tiles empty (no existing building)
6. Must not exceed `max_per_faction` limit

**Gold economy chain**: Gold ore (gold_ore) is mined via gold mine shaft, which must be built on a gold resource point (consumes it). Gold mine shaft is INFRA category, costs 20 wood + 15 stone + 5 iron, has `is_special_building = true`. It requires ≥1 garrisoned worker to produce; each garrisoned worker yields +2 gold_ore/turn via garrison bonus. Gold_ore → gold conversion is not yet implemented (planned: mint building). Buildings with `cost_gold > 0` deduct from gold (initial 0 per faction).

**Turn integration:**
- `round_ended` → ResourceTracker collects production from all buildings + garrison bonus → faction inventories
- `player_turn_started` → `building_ui.refresh(player)` rebuilds cards for current faction; town hall vision revealed
- `ap_changed` → refreshes building UI to reflect latest resource counts

**Town hall rendering:** Double-layer outer glow (faction color a=0.3 at 4px, a=0.2 at 8px), thicker 3px border, larger 13px font, "★ 主城 ★" star marker. Town halls reveal fog radius 4 (Manhattan) on placement and each turn.

**Garrison system:** Buildings with production can hold units (capacity = footprint area, min 2). Garrison bonus = 1 extra production per garrisoned unit per key. Rendered as colored dots above building.

**BuildingUI panel:** Right-side (offset_left=1400, width≈500px), fully code-built. Root `mouse_filter = PASS`. Cards have `mouse_filter = STOP` with `gui_input.connect()` for clicks; all interior containers `IGNORE`. Categories: 基础/资源/军事/侦察/招募/主城.

**12 building types:** Town Hall(2×2), Lumber Camp, Quarry, Farm, Warehouse, Mine(iron), Extraction Tower, Ancient Wood Harvest, Barracks Lv1, Scout Post, Gold Mine Shaft, Recruit Camp.

**Worker recruitment**: 招募营 (RECRUIT category, INFRA cost: 20w+15s) allows recruiting workers. Select the building and press **R key** to recruit a worker (costs 1 food + 1 AP). Worker spawns on nearest empty adjacent tile. Limited to 3 per faction.

### Gathering System (`GatheringManager2D`)

Workers moving onto resource nodes auto-register as pending gathers. On next player turn start: checks worker still on node → adds resources via ResourceTracker → removes resource from map → floating "+N 资源" text.

### Resource Types

**8 tracked resources (per-faction inventory):** Gold(0 starting), Wood, Stone, Food, Iron, Magic Dust, Ancient Wood, Gold Ore. Gold must be earned through the gold chain (gold mine shaft → gold_ore, conversion not yet implemented).

**14 map resource points (173 total):** Gold Mine(18), Ancient Forest(16), Quarry(15), Fertile Plain(15), Iron Mine(14), Magic Node(14), Ancient Tree(13), Rune Stone(13), Abandoned Post(12), Star Crystal(12), World Tree Root(12), Dragon Crystal(10), Hot Spring(3), Ancient Relic(2).

Rendered as colored diamond markers only on tiles where `FogOfWar2D.get_fog(player, x, y) == 0.0`.

### ZoneTag Regions

Elf Territory(NW), Dwarf Territory(SW), Orc Territory(SE), Emerald Woodlands(buffer), Scorched Badlands(buffer), Rift Highlands(buffer), Resource Ring, Mountain Nest/Body/Path, Ocean.

### Territory System (`TerritoryManager2D`)

BFS flood-fill from town halls through explored+passable tiles. Player mapping: 0=Elf, 1=Dwarf, 2=Orc. Border rendering: 2.5px lines along shared edges between different owners. Colors: Elf green `#2e9926`, Dwarf gold `#cca619`, Orc red `#cc4026`.

### Key Constants
- Grid: 100×56 (16:9), 56×56 land centered at LAND_OFFSET_X=22, 32px tiles
- Viewport: 1920×1080 (stretch: canvas_items)
- Camera: zoom 0.55–2.5, default 1.0 (~0.55 shows full 100×56 map)
- Bounds: x=[-1800, 1800], y=[-1096, 1096] (200px margin)
- Starting gold: 0 (gold mine shaft + garrisoned worker produces +2 gold_ore/turn per worker; gold_ore→gold conversion pending)
- Building AP cost: 2 per building

## Development Notes
- **Godot executable**: `C:\tools\godot\Godot_v4.6.2-stable_win64_console.exe` (or `..._win64.exe` for GUI)
- **Validation**: `Godot_v4.6.2-stable_win64_console.exe --path . --headless --check-only` to check for GDScript parse errors without launching window
- All rendering uses `_draw()` + `draw_rect()` / `draw_circle()` / `draw_string()` — no TileMap nodes, no sprite atlases
- Player spawns (land coords, offset by LAND_OFFSET_X=22 at render): Elf at (12,13)..(14,13), Dwarf at (12,43)..(14,43), Orc at (39,35)..(41,35)
- Signal chain: `ResourceManager2D.resource_hovered(text)` / `BuildingManager2D.building_hovered(text)` → `main.gd` → `DebugLabel`
- Fog is float-based (0.0=explored, 0.7=unexplored) with 3×3 neighborhood smoothing for edge gradients. First reveal triggers a 0.3s fade animation (lerp 0.7→0.0), then emits `fog_updated(player)` which triggers territory recalculation.
- Input mappings: camera_zoom_in/out (scroll), select (LMB), end_turn (Tab/Enter)
- MSAA 2× enabled in rendering settings
- No design doc files should be edited by code — they are reference only
- Input handling in `main.gd` uses direct keycode checks (`event.keycode == KEY_ENTER or event.keycode == KEY_TAB`) rather than InputMap actions, because InputMap can be corrupted by script-based editing and Tab can be intercepted by the Godot editor's own shortcuts when running embedded
- `dev-roadmap/` — local web-based development roadmap tool. Start with `start.bat` (Python backend + HTML frontend). Tracks module completion status and development notes in `state.json`.
