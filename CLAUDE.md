# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview
**Three Against One** — 3-player asynchronous turn-based 2.5D strategy board game in Godot 4.6.
Three asymmetric factions (Elf/Dwarf/Orc) on a shared hex-less grid map with resources, tech trees, fog of war, and PvP/PvE combat.

## Current Status
v0.3 prototype — 100×56 terrain generation with war fog (0.3s fade animation), territorial borders, 173 resource points, Space+LMB pan/zoom camera. Hotseat turn system (Tab cycles Elf→Dwarf→Orc with +6AP/round, cap 12). Unit system (3 types per faction: worker/scout/guard with BFS movement, fog-on-move reveal, **real-time duel combat with visual effects**). Building system (12 generic types with footprint system, turn-based production, **interactive placement mode with ghost preview + validation**, UI panel + resource tracking, **garrison system**, gold economy chain: resource point → gold mine shaft (garrison) → gold_ore). **Worker recruitment** (招募营 building, R key to recruit workers for 1 food + 1 AP). **Gathering system** (workers on resource nodes collect resources next turn). **Neutral units**: 7 wyverns (3 types, guard AI, aggro range 2) around dragon nest, 6 wandering traders (territory border placement, discoverable via click + 1 AP, open goblin market). **Goblin Market**: card-based UI with tiered pricing (好感度 system), max 3 items. **Recruit UI**: turn-based queue for military/recruit buildings. Architecture modularized into independent nodes with service/rules layer.

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
- **MCP automation**: `mcp_interaction_server.gd` runs as autoload, listens on TCP 127.0.0.1:9090 for JSON commands (click, screenshot, eval, key_press, etc.). Used by AI to interact with the running game.
- **Game design docs** (reference, not code):
  - `游戏策划_v12.md` — full game design document
  - `地图模块_游戏策划_v12.md` — map module design
- **Dev plan**: `开发路径表.md` — modular development roadmap with parallel tracks and phases
- **Dev roadmap tool**: `dev-roadmap/start.bat` — local Python+HTML roadmap tracker

## Architecture

### Scene Tree (`scenes/main.tscn`) — actual render order
```
Main (Node2D) — main.gd (game state machine)
├── GameCamera (Camera2D) — camera_controller_2d.gd
├── GameBoard (Node2D)
│   ├── GridManager2D (Node2D)        — grid_manager_2d.gd (terrain gen + draw)
│   ├── ResourceManager2D (Node2D)    — resource_manager_2d.gd (resources)
│   ├── FogOfWar2D (Node2D)           — fog_of_war_2d.gd (war fog overlay)
│   ├── TerritoryManager2D (Node2D)   — territory_manager_2d.gd (borders)
│   ├── TurnManager2D (Node)          — turn_manager_2d.gd (turn + AP)
│   ├── BuildingManager2D (Node2D)    — building_manager_2d.gd (buildings)
│   ├── UnitManager2D (Node2D)        — unit_manager_2d.gd (player units)
│   ├── GatheringManager2D (Node2D)   — gathering_manager_2d.gd (resource collection)
│   ├── ResourceTracker (Node)        — resource_tracker.gd (per-faction inventory)
│   ├── TemplateRegistry (Node)       — template_registry.gd (data templates)
│   └── NeutralUnitManager2D (Node2D) — neutral/neutral_unit_manager_2d.gd (wyverns, traders)
└── UI (CanvasLayer)
    ├── DebugLabel (Label)
    ├── TurnLabel (Label)
    ├── BuildingUI (Control)          — building_ui.gd (right-side building cards)
    ├── ResourcePanel (Panel)         — resource labels
    ├── UnitInfoPanel (Control)       — unit_info_panel.gd (bottom unit details)
    ├── RecruitUI (Control)           — recruit_ui.gd (bottom-left recruitment panel)
    └── GoblinMarketUI (Control)      — ui/goblin_market_ui.gd (card market overlay)
```

**Actual draw order** (CanvasItem children render in tree order): GridManager2D → ResourceManager2D → FogOfWar2D (fog overlay on top of terrain/resources) → TerritoryManager2D → BuildingManager2D (buildings on top of territory) → UnitManager2D (player units) → GatheringManager2D → NeutralUnitManager2D (neutral units on top of fog). Each sibling has independent `_draw()` and `_unhandled_input()`. UI CanvasLayer renders on top of all game board children.

**Node reference pattern**: Managers use `get_parent().get_node("OtherManager")` in `_ready()` to reference siblings (avoids scene tree init-order issues with `@onready`).

### Core Scripts (all GDScript, Godot 4.6)

| Script | Lines | Role |
|--------|-------|------|
| `scripts/main.gd` | 230 | Game state machine (LOADING/PLAYING/TURN_RESOLVE/GAME_OVER). Initializes subsystems, connects signals, routes building_selected → start_placement. |
| `scripts/camera_controller_2d.gd` | 100 | Space+LMB drag pan, scroll zoom, clamp to map bounds. |
| `scripts/grid_manager_2d.gd` | 672 | 6-phase terrain generation (mountain → ring → ocean → territories → impassable → assign terrain), terrain `_draw()`, spawn markers, coordinate utils, hash/noise, expansion to 100×56. Delegates resource placement to ResourceManager2D. |
| `scripts/resource_manager_2d.gd` | 340 | ResourceType enum, RESOURCE_DEFS table (14 types, 173 total), resource_grid, deterministic placement, diamond `_draw()`, hover signal, gather_result/remove_resource API. Queries FogOfWar2D to only show diamonds on visible tiles. |
| `scripts/fog_of_war_2d.gd` | 179 | Per-player float fog grids (0.0=explored, 0.7=unexplored), 3×3 smoothing for edge gradients, 0.3s fade animation, reveal_area/reveal_area_immediate/is_explored API, `fog_updated(player)` signal. |
| `scripts/territory_manager_2d.gd` | 163 | BFS flood-fill territory from town halls through explored+passable tiles. `owner_grid[y][x]` (-1/0/1/2), border line rendering. |
| `scripts/turn_manager_2d.gd` | 79 | Hotseat round-based: Elf→Dwarf→Orc→round end. +6AP/round cap 12. Signals: round_started, player_turn_started/ended, round_ended, ap_changed. Also fires neutral_turn_started/ended. |
| `scripts/unit_manager_2d.gd` | ~854 | Player unit storage, BFS movement with AP cost, fog reveal on move, LMB select/move/deselect, combat system (Timer-based 1s interval, visual effects), garrison integration, hidden trader detection with 1 AP cost. |
| `scripts/unit_data.gd` | 40 | `class_name UnitData` — template data (name, category, move/atk/hp/vision/food_cost). Static factory methods. |
| `scripts/building_data.gd` | 188 | `class_name BuildingData` — 12 building template types with footprint, cost, HP, production, terrain compatibility. Categories: INFRA/T1_RESOURCE/MILITARY/SCOUT/RECRUIT/TOWN_HALL. |
| `scripts/building_manager_2d.gd` | 763 | Building placement with footprint validation, `building_grid[y][x]`, faction-colored rect rendering, round_ended production, placement mode (ghost preview, validation), garrison system, recruit system (R key). |
| `scripts/building_ui.gd` | 388 | Building UI panel (right-side, code-built). Two-column layout: category sidebar + card grid + detail panel. Categories: 基础/资源/军事/侦察/招募/主城. |
| `scripts/resource_tracker.gd` | 125 | Per-faction resource inventory (8 types). Collects building production on round_ended, adds garrison bonus. API: add_resource/get_resource/spend_resource/update_display. |
| `scripts/gathering_manager_2d.gd` | 103 | Worker resource collection. On player turn start, checks worker on node → collects → removes resource → floating text. |
| `scripts/neutral/neutral_unit_manager_2d.gd` | ~991 | Neutral unit placement, rendering with fog check, per-unit _ai_data behavior system (guard/revenge/hidden_trader), combat system (Timer-based, player-first or neutral-first), wyvern placement around dragon nest, trader placement at territory borders, goblin relations system. |
| `scripts/ui/goblin_market_ui.gd` | 337 | Card-based goblin market panel. 4 goods drawn from pool, tiered pricing by goblin relations, max 3 selections with price escalation. |
| `scripts/recruit_ui.gd` | 220 | Bottom-left recruitment panel. Shows recruit options, count selector, turn-based queue status. |
| `scripts/unit_info_panel.gd` | 203 | Bottom unit detail panel (code-built). Faction-colored name bar, HP bar, ATK/MOVE/VISION/FOOD stats. |
| `scripts/core/game_catalog.gd` | 51 | `class_name GameCatalog`. Shared constants: FACTION_NAMES/COLORS, RESOURCE_NAMES/KEYS, DRAGON_BLOOD_DROPS. Static helper methods for UI strings. |
| `scripts/terrain_data.gd` | 59 | `class_name TerrainData` — 12 terrain types enum, passability/buildability. Global singleton pattern. |
| `scripts/rules/unit_roster.gd` | 31 | `class_name UnitRoster`. Per-faction initial unit definitions with template_id + fallback UnitData. |
| `scripts/rules/building_rules.gd` | 55 | `class_name BuildingRules`. Centralized building identifiers (outpost/mint/gold mine shaft) and faction recruit template ID mapping. |
| `scripts/services/garrison_service.gd` | 66 | `class_name GarrisonService`. Garrison state mutation: max_garrison, can_garrison, garrison_unit, ungarrison_one, get_garrison_bonus (gold_mine_shaft: 2 gold_ore/unit). |
| `scripts/services/recruitment_service.gd` | 262 | `class_name RecruitmentService`. Turn-based recruitment queue (queue capacity 3), cost/AP deduction, spawn on completion, find_empty_adjacent_pos. |

### Template System (`scripts/templates/`)

Data-driven template system with code-side defaults, migrating toward `.tres` file loading:

| Script | Role |
|--------|------|
| `templates/template_registry.gd` | Central registry (Node). Loads templates from `res://data/templates/` + code defaults. API: get_unit/get_building/get_resource_node/has_tag queries. |
| `templates/game_template.gd` | Base `GameTemplate` resource class. |
| `templates/unit_template.gd` | Unit template (role, move/atk/hp/vision, recruit_cost, ai_behavior, aggro_range). |
| `templates/building_template.gd` | Building template (role, build_cost, production, recruit_options, needs_resource_point, garrison config). |
| `templates/resource_node_template.gd` | Resource node template. |
| `templates/resource_amount.gd` | Key+amount pair resource (used in costs/production). |
| `templates/production_recipe.gd` | Production recipe (outputs, requires_garrison, per_garrison_unit). |
| `templates/default_template_library.gd` | Code-default templates: 12+ unit templates (faction-specific + neutral), 4 building templates. |

Template IDs follow `category.subtype.variant` convention (e.g. `unit.elf.worker`, `neutral.wyvern.fire`, `building.recruit_camp`).

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
| `resource_grid[y][x]` | ResourceManager2D | `ResourceType` enum | 100×56 |
| `building_grid[y][x]` | BuildingManager2D | int (building_id or -1) | 100×56 |
| `fog_grids[player][y][x]` | FogOfWar2D | float (0.0–0.7) | 3 × 100×56 |
| `owner_grid[y][x]` | TerritoryManager2D | int (-1/0/1/2) | 100×56 |

All grids use outer loop y (rows), inner x (cols). All generation is **deterministic** via `_simple_hash(x, y, seed)`.

### Turn System (`TurnManager2D`)

Hotseat round-based: Elf(0) → Dwarf(1) → Orc(2) → round end → next round. Tab key ends current player's turn.

- **AP**: Each player gains +6 AP per round (cap 12). Movement 1 AP/tile. Building 2 AP. `spend_ap(player, amount)` returns false if insufficient.
- **Signal order**: `round_started(round)` → `player_turn_started(player)` × 3 → `neutral_turn_started` (AI neutral units act) → `neutral_turn_ended` → `round_ended(round)` → loop.
- `start_game()` must be called AFTER all signal connections are made, or the first signals are missed.

### Unit System (`UnitManager2D` + `UnitData` + `UnitRoster`)

Faction-specific starting units (defined in `UnitRoster`):
- **Elf**: 精灵工人 (move2/atk0/hp3/vision1), 风行斥候 (move4/atk1/hp3/vision4), 月影刺客 (move2/atk3/hp5/vision2)
- **Dwarf**: 矮人工人 (move1/atk0/hp4/vision1), 勘探者 (move2/atk1/hp4/vision2), 铁锤卫 (move1/atk3/hp8/vision1)
- **Orc**: 兽人工人 (move1/atk0/hp4/vision1), 猎齿兽 (move2/atk2/hp5/vision1), 血斧兵 (move1/atk4/hp6/vision2)

Selection, movement, combat, garrison, and fog interaction as documented below. `_is_tile_empty()` (line 784) checks ALL occupiers: player units, buildings, neutral units.

### Neutral Unit System (`NeutralUnitManager2D`)

Stores neutral units as Array[Dictionary] with fields: id, template_id, display_name, faction=-1, grid_pos, hp, hp_max, atk, move_max, vision, has_moved, has_attacked. AI behaviors stored in `_ai_data[unit_id]` dict.

**Behaviors:**
- **guard**: Wyverns. Scans aggro_range for player units; if found, pursues and attacks. Alternating Timer combat (same system as player PvP). Wyverns placed via polar coordinates around MOUNTAIN_CENTER (49.5,27.5), RING_INNER=4.0, RING_OUTER=9.0, MIN_WYVERN_SPACING=3. 3 fire + 2 frost + 2 toxic wyverns.
- **hidden_trader**: Wander traders. Placed at territory border tiles (buffer zones adjacent to faction zones, distance ≥ 12 from center). Discoverable by clicking adjacent with 1 AP.
- **revenge**: Goblin revenge squads. Spawned near offender's town hall when goblin relations drop.

**Goblin relations**: Per-player score 0-100, initial 100. Affects price_multiplier (1.0 at 80+, 1.2-2.0 otherwise) and caravan visit chance. Modified by on_player_plundered (-40 success, -25 failure, 50% revenge squad chance).

**Dragon blood drops**: Killing wyverns give faction-specific resource (fire_dragon_blood, frost_dragon_blood, toxic_dragon_blood). Defined in `DRAGON_BLOOD_DROPS` map in GameCatalog.

**Fog integration**: `_draw()` skips units on tiles where `get_fog(current_player, x, y) > 0.0`. `get_unit_at_world()` also checks fog (fogged units unclickable). `player_turn_started` signal triggers `queue_redraw()` for fog refresh.

### Building System

12 generic building types (defined in `building_data.gd`). All factions share the same pool. Footprint sizes: Town Hall 2×2, others 1×1.

**Special building flag** (`is_special_building`): Marks buildings needing special placement (gold resource point check) and worker-only garrison. Currently used by gold mine shaft.

**Gold economy chain**: Gold resource point → gold mine shaft (must build on gold point, consumes it) → garrison workers produce +2 gold_ore/unit/turn → gold_ore→gold conversion not yet implemented.

**Recruitment**: Uses `RecruitmentService` and `RecruitUI`. Turn-based queue (max 3). Buildings with RECRUIT/MILITARY category can recruit units. R key on recruit camp → quick recruit (1 food + 1 AP) for workers.

**Garrison**: Uses `GarrisonService`. Buildings with non-empty production can garrison units (capacity = footprint area, min 2). Gold mine shaft requires worker garrison for production. Garrison bonus = 1 extra/unit for normal buildings, 2 gold_ore/unit for gold mine shaft.

### MCP Interaction Server (`mcp_interaction_server.gd`)

Runs as autoload, listens on TCP 127.0.0.1:9090. Accepts JSON-format commands over TCP, one command per line (newline-delimited). Used by external automation (Claude Code) to interact with the running game.

**Key commands**: screenshot, click, key_press, key_hold, mouse_move, mouse_drag, scroll, eval (arbitrary GDScript), wait, get_ui_elements, get_scene_tree, get_property, set_property, call_method, get_node_info, instantiate_scene, connect_signal, get_camera, set_camera, navigate_path, tilemap, audio_play, etc.

Busy flag with 30s timeout prevents overlapping commands.

### Editor Plugins (`addons/`)

- **terrain_map_painter**: Editor plugin that routes canvas input events to `GridManager2D.editor_handle_canvas_paint_event()`. Enables hand-painting terrain tiles in the Godot editor. Saves/restores zone data via `data/editor_terrain_map.json`.
- **godot_mcp**: Full MCP server addon for Godot editor (runs alongside the game MCP server). Provides command handling, WebSocket server, and management UI for editor automation.

### ZoneTag Regions

Elf Territory(NW, zone 7), Dwarf Territory(SW, zone 8), Orc Territory(SE, zone 9), Emerald Woodlands(buffer, zone 10), Scorched Badlands(buffer, zone 11), Rift Highlands(buffer, zone 12), Resource Ring, Mountain Nest/Body/Path, Ocean.

### Key Constants
- Grid: 100×56 (16:9), 56×56 land centered at LAND_OFFSET_X=22, 32px tiles
- Viewport: 1920×1080 (stretch: canvas_items)
- Camera: zoom 0.55–2.5, default 1.0 (~0.55 shows full 100×56 map)
- Bounds: x=[-1800, 1800], y=[-1096, 1096] (200px margin)
- Building AP cost: 2 per building
- Neutral unit IDs start at 100000

## Development Notes
- **Godot executable**: `C:\tools\godot\Godot_v4.6.2-stable_win64_console.exe` (or `..._win64.exe` for GUI)
- **Validation**: `Godot_v4.6.2-stable_win64_console.exe --path . --headless --check-only` for GDScript parse errors without launching window
- All rendering uses `_draw()` + `draw_rect()` / `draw_circle()` / `draw_string()` — no TileMap nodes, no sprite atlases
- Player spawns (land coords, offset by LAND_OFFSET_X=22 at render): Elf at (12,13)..(14,13), Dwarf at (12,43)..(14,43), Orc at (39,35)..(41,35)
- Signal chain: `ResourceManager2D.resource_hovered(text)` / `BuildingManager2D.building_hovered(text)` → `main.gd` → `DebugLabel`
- Fog is float-based (0.0=explored, 0.7=unexplored) with 3×3 neighborhood smoothing for edge gradients. First reveal triggers 0.3s fade animation (lerp 0.7→0.0), then emits `fog_updated(player)` which triggers territory recalculation.
- After `reveal_area` in unit movement, always call `numgr.queue_redraw()` on NeutralUnitManager2D so newly-revealed neutral units appear immediately (not next turn).
- Input mappings: camera_zoom_in/out (scroll), select (LMB), end_turn (Tab/Enter)
- MSAA 2× enabled in rendering settings
- No design doc files should be edited by code — they are reference only
- Input handling in `main.gd` uses direct keycode checks (`event.keycode == KEY_ENTER or event.keycode == KEY_TAB`) rather than InputMap actions, because InputMap can be corrupted by script-based editing and Tab can be intercepted by the Godot editor's own shortcuts when running embedded
- `dev-roadmap/` — local web-based development roadmap tool. Start with `start.bat` (Python backend + HTML frontend). Tracks module completion status and development notes in `state.json`.
- Autoloads: `McpInteractionServer` (`res://mcp_interaction_server.gd`) — TCP server on port 9090
- `data/editor_terrain_map.json` — editor terrain save file (zone data lost on scene reload, saved here for restoration)
- Service pattern: `scripts/services/` — stateless `RefCounted` classes for domain logic; `scripts/rules/` — static rule identifiers
