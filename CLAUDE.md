# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview
**Three Against One** — 3-player hotseat turn-based 2.5D strategy board game in Godot 4.6 (~14,759 lines GDScript).
Three asymmetric factions (Elf/Dwarf/Orc) on a 100×56 shared grid map with fog of war, procedural terrain, resource chains, building chains, tech tree, achievements, stage-based scoring, PvP/PvE combat, and a goblin economy.

## Current Status
v0.5 prototype — full terrain gen + per-player fog of war + territorial BFS borders. Hotseat turn system (Tab cycles Elf→Dwarf→Orc→round end). AP system (12/round, carry cap 12). 9 faction-specific units (worker/scout/guard per faction) with BFS movement + real-time duel combat. 16+ building types with footprint validation, placement mode, garrison/production chains, and recruitment queues. Full gold economy chain (resource point → mine shaft → ore → mint → gold). Worker gathering system. Neutral AI units (7 wyverns with aggro AI, 6 hidden traders, goblin revenge squads) + goblin market card UI with reputation system. **Achievement tree** (tech points unlock). **Technology tree** (faction-specific techs with resource costs/effects). **Victory system** (conquest + stage-based scoring). **Civilization route system** (faction-specific development paths). **Stage events** (5-stage timer, goblin market triggers). **Creative mode** (no-cost toggle). **Building upgrade/effect/network services**. **Lord template**. **Action preview**. Recruit UI, unit info panel, AP status label. Editor terrain painter plugin.

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
- **Design docs** (reference only, don't edit): `游戏策划_v12.md`, `建筑与资源循环系统策划.md`, `单位策划.md`, `中立单位.md`, `开发路径表.md`
- **Dev roadmap tool**: `dev-roadmap/start.bat` — local Python+HTML roadmap tracker
- **Avoid auto-running Godot headless check** after fixing code — the user's memory says not to.

## Architecture

### Scene Tree (`scenes/main.tscn`) — actual render order
```
Main (Node2D) — main.gd (game state machine, 706 lines)
├── GameCamera (Camera2D) — camera_controller_2d.gd
├── GameBoard (Node2D)
│   ├── GridManager2D (Node2D)            — grid_manager_2d.gd (terrain gen + draw)
│   ├── ResourceManager2D (Node2D)        — resource_manager_2d.gd (resource points)
│   ├── FogOfWar2D (Node2D)               — fog_of_war_2d.gd (war fog overlay)
│   ├── TerritoryManager2D (Node2D)       — territory_manager_2d.gd (borders)
│   ├── TurnManager2D (Node)              — turn_manager_2d.gd (turn + AP)
│   ├── BuildingManager2D (Node2D)        — building_manager_2d.gd (buildings)
│   ├── UnitManager2D (Node2D)            — unit_manager_2d.gd (player units)
│   ├── GatheringManager2D (Node2D)       — gathering_manager_2d.gd (resource collection)
│   ├── ResourceTracker (Node)            — resource_tracker.gd (per-faction inventory)
│   ├── TemplateRegistry (Node)           — template_registry.gd (data templates)
│   ├── CivilizationRuleService (Node)    — civilization/civilization_rule_service.gd
│   ├── AchievementService (Node)         — services/achievement_service.gd
│   ├── TechnologyService (Node)          — services/technology_service.gd
│   ├── VictoryService (Node)             — services/victory_service.gd
│   ├── StageEventService (Node)          — services/stage_event_service.gd
│   └── NeutralUnitManager2D (Node2D)     — neutral/neutral_unit_manager_2d.gd
└── UI (CanvasLayer)
    ├── DebugLabel (Label)
    ├── TurnLabel (Label)
    ├── StageLabel (Label)                — stage/round display
    ├── APStatusLabel (Label)             — per-faction AP display
    ├── CreativeModeButton (Button)       — toggle no-cost mode
    ├── BuildingUI (Control)              — building_ui.gd (right-side building cards)
    ├── ResourcePanel (Panel)             — resource labels (10 resources)
    ├── UnitInfoPanel (Control)           — unit_info_panel.gd (bottom unit details)
    ├── RecruitUI (Control)               — recruit_ui.gd (bottom-left recruitment panel)
    ├── GoblinMarketUI (Control)          — ui/goblin_market_ui.gd (card market overlay)
    ├── ActionPreviewPanel (Control)      — ui/action_preview_panel.gd
    ├── AchievementTreePanel (Control)    — ui/achievement_tree_panel.gd
    ├── TechnologyTreePanel (Control)     — ui/technology_tree_panel.gd
    ├── ScoreRulePanel (Control)          — ui/score_rule_panel.gd
    ├── CivilizationRoutePanel (Control)  — ui/civilization_route_panel.gd
    ├── CivilizationDebugPanel (Control)  — ui/civilization_debug_panel.gd
    ├── GameOverLabel (Label)
    └── AchievementTreeButton/TechnologyTreeButton/ScoreRuleButton/CivilizationRouteButton
```

**Draw order**: GridManager2D → ResourceManager2D → FogOfWar2D → TerritoryManager2D → BuildingManager2D → UnitManager2D → GatheringManager2D → NeutralUnitManager2D. UI CanvasLayer on top.

**Node reference pattern**: Managers use `get_parent().get_node("OtherManager")` in `_ready()` to reference siblings.

### Core Scripts (all GDScript, Godot 4.6)

**Managers (~10,400 lines total):**
| Script | Lines | Role |
|--------|-------|------|
| `main.gd` | 706 | Game state machine. Initializes ALL subsystems (achievement, tech, victory, stage events, civ routes, creative mode, goblin market, action preview), routes signals. |
| `unit_manager_2d.gd` | 2000 | Player unit storage, BFS movement (1AP/tile), fog-on-move reveal, real-time duel combat (Timer 1s alternating attacks, VFX: flash/shake/damage text), garrison integration, hidden trader trigger, **warband formation**, **action preview system**. |
| `grid_manager_2d.gd` | 1383 | 6-phase deterministic terrain generation (mountain→ring→ocean→territories→impassable→assign), editor brush painting, cliff autotiling. |
| `building_manager_2d.gd` | 1205 | Building placement (footprint validation, ghost preview, territory/terrain/AP/resource checks), production on round_ended, garrison system, **building upgrade** (level upgrades), **building network** (adjacency bonuses), **building effects**, **civilization rule integration**, fog reveal on build. |
| `neutral/neutral_unit_manager_2d.gd` | 1025 | Neutral AI (guard/revenge/hidden_trader behaviors), wyvern combat (Timer-based), goblin reputation (0-100), goblin market integration, dragon blood drops. |
| `camera_controller_2d.gd` | 101 | Space+LMB drag pan, scroll zoom, smooth lerp, map bounds clamp. |
| `fog_of_war_2d.gd` | 189 | Per-player float fog grids, 3×3 smoothing, 0.3s fade animation. |
| `territory_manager_2d.gd` | 176 | BFS territory from town halls, border rendering, outpost territory. |
| `turn_manager_2d.gd` | 134 | Hotseat turn cycle (+12AP/round carry cap 12), AP spend/check, creative mode flag. |
| `resource_manager_2d.gd` | 367 | 18 resource types, deterministic placement (173 total), diamond draw, gather/remove. |
| `gathering_manager_2d.gd` | 103 | Worker resource collection on turn start. |
| `resource_tracker.gd` | 307 | Per-faction inventory (10 resources now: +mithril, +steel), production from buildings, creative mode bypass, civilization rule modifiers. |
| `building_ui.gd` | 410 | Right-side building cards, category sidebar, detail panel, civilization rule filtering. |
| `recruit_ui.gd` | 219 | Recruitment panel, count selector, queue display. |
| `unit_info_panel.gd` | 279 | Unit details (name/category/status/HP bar/stats), **warband UI**, faction-colored. |

**Data classes:**
| Script | Lines | Role |
|--------|-------|------|
| `building_data.gd` | 521 | 16+ factory methods. New building categories: LORD (领主大厅), GOLD_CHAIN. New buildings: lord_hall (3 levels: 初建/扩建/堡垒), 投石机场 (catapult_stand), mithril_mine/steel_works/ancient_temple/research_tower/market. Categories expanded from 7 to 9. |
| `unit_data.gd` | 51 | UnitData class, from_template bridge. |
| `terrain_data.gd` | 60 | 12 terrain types enum, passability/buildability. |
| `core/game_catalog.gd` | 52 | Shared constants: factions, resources (10 tracked), dragon blood drops, helper methods. |

**Service layer (~1,200 lines):**
| Script | Lines | Role |
|--------|-------|------|
| `services/recruitment_service.gd` | 314 | Queue-based recruitment (cap 3), cost/AP deduction, spawn on completion. |
| `services/garrison_service.gd` | 66 | Garrison rules, capacity, bonus calculation. |
| `services/technology_service.gd` | 241 | Tech tree state, faction-specific techs, resource cost/effects, research unlock. |
| `services/victory_service.gd` | 294 | Conquest victory (town hall HP check), stage-based scoring, score ranking, final scoring. |
| `services/achievement_service.gd` | 274 | Achievement tracking (total milestones), tech points (TP) rewards, achievement_completed signal. |
| `services/stage_event_service.gd` | — | Stage progression timer (5 stages), goblin market trigger on specific stages. |
| `services/building_effect_service.gd` | — | Building passive effects/bonuses. |
| `services/building_network_service.gd` | — | Adjacency-based building bonuses. |
| `services/building_upgrade_service.gd` | 121 | Building level upgrades, cost scaling. |

**Rules & state:**
| Script | Lines | Role |
|--------|-------|------|
| `rules/building_rules.gd` | 55 | Building classification, faction recruit template mapping. |
| `rules/unit_roster.gd` | 31 | Per-faction starting unit definitions (9 units across 3 factions). |
| `rules/game_stage_rules.gd` | — | Stage constants: TOTAL_STAGES=5, ROUNDS_PER_STAGE=6, stage round mapping. |
| `civilization/civilization_route_state.gd` | 197 | Faction-specific development route state tracking. |
| `civilization/civilization_rule_service.gd` | 250 | Civilization route rules, bonuses, unlock conditions, debug view. |

**Template system (~1,200 lines):**
| Script | Lines | Role |
|--------|-------|------|
| `templates/default_template_library.gd` | 566 | Code-default templates: unit templates (faction-specific + neutral), building templates (recruit_camp/barracks/lumber_camp/gold_mine/lord_hall), lord templates. |
| `templates/template_registry.gd` | 126 | Central registry, loads code defaults + .tres/.res from `res://data/templates/`. |
| `templates/game_template.gd` | 38 | Base GameTemplate resource class. |
| `templates/unit_template.gd` | 73 | Unit template (role, stats, recruit_cost, ai_behavior). |
| `templates/building_template.gd` | 43 | Building template (role, build_cost, production, recruit_options). |
| `templates/lord_template.gd` | — | Lord template (level, abilities, upgrade costs). |
| `templates/resource_node_template.gd` | 18 | Resource node template. |
| `templates/resource_amount.gd` | 23 | Key+amount pair. |
| `templates/production_recipe.gd` | 50 | Production recipe (outputs, garrison config). |

Template IDs: `category.subtype.variant` (e.g. `unit.elf.worker`, `neutral.wyvern.fire`, `building.recruit_camp`).

**UI Panels:**
| Script | Lines | Role |
|--------|-------|------|
| `ui/technology_tree_panel.gd` | 511 | Tech tree display, research buttons, faction-specific tree layout. |
| `ui/civilization_route_panel.gd` | 501 | Civilization route selection/display, route progress. |
| `ui/achievement_tree_panel.gd` | 379 | Achievement tree display, TP rewards. |
| `ui/goblin_market_ui.gd` | 336 | Card-based goblin market (4 goods, tiered pricing, max 3 selections). |
| `ui/score_rule_panel.gd` | 145 | Stage scoring rules display. |
| `ui/civilization_debug_panel.gd` | 147 | Debug view for civilization routes. |
| `ui/action_preview_panel.gd` | — | Shows action preview on unit selection/move target. |

### Terrain Generation Pipeline (6 Phases)

All phases operate on a 56×56 land grid, then expanded to 100×56. 6-phase pipeline in `grid_manager_2d.gd`:
1. **Mountain** — central volcano/dragon nest, 3 corridor paths, scattered ruins
2. **Resource ring** — band around mountain (ZoneTag only)
3. **Ocean** — edge threshold + continental noise + elliptical corner rounding
4. **Territories** — Voronoi-like 3-faction split → 9 ZoneTag regions
5. **Scattered impassable** — ~120 random uncrossable tiles
6. **Assign terrain** — per ZoneTag terrain coloring

### Grid Data Model

| Grid | Owner | Type | Size |
|------|-------|------|------|
| `terrain_grid[y][x]` | GridManager2D | `TerrainData.Terrain` enum | 100×56 |
| `zone_grid[y][x]` | GridManager2D | `ZoneTag` enum | 100×56 |
| `resource_grid[y][x]` | ResourceManager2D | `ResourceType` enum | 100×56 |
| `building_grid[y][x]` | BuildingManager2D | int or -1 | 100×56 |
| `fog_grids[player][y][x]` | FogOfWar2D | float 0.0–0.7 | 3×100×56 |
| `owner_grid[y][x]` | TerritoryManager2D | int -1/0/1/2 | 100×56 |

All use outer y/inner x. Deterministic via `_simple_hash(x, y, seed)`.

### Turn System

Hotseat: Elf(0) → Dwarf(1) → Orc(2) → round end. Tab/Enter ends current player turn.
- **AP**: +12 per round, carry cap 12 (turn_manager.gd: `AP_PER_ROUND=12`, `AP_MAX=12`). Movement 1 AP/tile. Building 2 AP.
- **Signal order**: `round_started(round)` → `player_turn_started(player)` × 3 → `neutral_turn_started` → `neutral_turn_ended` → `round_ended(round)` → loop.
- `start_game()` must be called AFTER all signal connections are made.
- **Creative mode**: Toggle button in UI, sets flag so `spend_ap`/`spend_resource` are no-ops.

### Stage System (5 stages, 6 rounds each = 30 rounds total)

Stage module in `rules/game_stage_rules.gd`: `TOTAL_STAGES=5`, `ROUNDS_PER_STAGE=6`. `get_stage_for_round(round)` maps round → stage. StageEventService fires `goblin_market_started` on stage-specific rounds, triggering goblin market availability on player turn start.

### Victory System

Two modes in `services/victory_service.gd`:
- **Conquest victory**: Any town hall HP reaches 0 → that player's conqueror is declared winner.
- **Stage scoring**: After round 30 (or final stage), `final_scoring_started` signal runs score calculation: buildings, units, resources, technology level → rank → winner.

### Building System (16+ types)

`building_data.gd` now has expanded categories:
- INFRA (7): lumber_camp, quarry, farm, warehouse, gold_mine_shaft, mint, market
- T1_RESOURCE (3): mine, extraction_tower, ancient_wood_harvest
- LORD (3): lord_hall_lv1/2/3 (领主大厅初建/扩建/堡垒)
- GOLD_CHAIN (1): (gold_mine_shaft moved from INFRA)
- MILITARY (2): barracks_lv1, catapult_stand (投石机场)
- SCOUT (2): scout_post, outpost
- RECRUIT (1): recruit_camp
- SPECIAL (3): mithril_mine, steel_works, ancient_temple, research_tower

**Building upgrade**: `services/building_upgrade_service.gd` handles level upgrades with cost scaling. `building_manager_2d.gd` tracks `building_level` and applies upgrade effects.

**Building effects**: `services/building_effect_service.gd` — passive bonuses (e.g., research_tower gives tech discount).

**Building network**: `services/building_network_service.gd` — adjacency bonuses between compatible buildings.

**Civilization rules**: `civilization/civilization_rule_service.gd` filters available buildings per faction + route, applies faction-specific bonuses.

### Unit System (9 faction units + warbands)

UnitManager2D now at 2000 lines. Key additions:
- **Warband formation** (`request_form_warband`): merge multiple units into a warband group.
- **Action preview** (`action_preview_changed` signal → ActionPreviewPanel): shows move range highlight before confirming.
- **Extended combat**: neutral engagement properly connected, hidden trader discovery triggers goblin market.

Faction units (same as before):
- Elf: 精灵工人(m2/a0/hp3/v1), 风行斥候(m4/a1/hp3/v4), 月影刺客(m2/a3/hp5/v2)
- Dwarf: 矮人工人(m1/a0/hp4/v1), 勘探者(m2/a1/hp4/v2), 铁锤卫(m1/a3/hp8/v1)
- Orc: 兽人工人(m1/a0/hp4/v1), 猎齿兽(m2/a2/hp5/v1), 血斧兵(m1/a4/hp6/v2)

### Achievement System

`services/achievement_service.gd`: Tracks achievement milestones (total resource collected, units recruited, buildings built, enemies killed). Each achievement grants **tech points (TP)**. `achievement_completed(player, id, title)` signal. Achievements defined in `achievements/achievement_library.gd`. `ui/achievement_tree_panel.gd` renders the tree UI.

### Technology System

`services/technology_service.gd`: Per-faction tech tree. Techs defined in `technologies/technology_library.gd`. Each tech has: resource costs (gold, strategic resources), required achievements/TP, unlock effects (building access, unit buffs, production bonuses). `has_tech(player, tech_id)` / `research_tech(player, tech_id)` API. `ui/technology_tree_panel.gd` (511 lines) renders faction-specific tree with research buttons.

### Civilization Route System

`civilization/civilization_rule_service.gd` (250 lines): Each faction has 2-3 development routes (e.g., Elf: 游击路线/魔法路线). Route tracking in `civilization_route_state.gd`. Routes gate building access, unit bonuses, and production modifiers. `civilization_route_panel.gd` (501 lines) for route selection UI. `civilization_debug_panel.gd` for debugging.

### Key Resources (10 tracked)

Resources in `resource_tracker.gd` + `game_catalog.gd`:
`gold, wood, stone, food, iron, magic_dust, ancient_wood, gold_ore, mithril, steel`

### Constants
- Grid: 100×56, 56×56 land at LAND_OFFSET_X=22, 32px tiles
- Viewport: 1920×1080, MSAA 2x
- Camera zoom: 0.55–2.5
- AP: +12/round, cap 12
- Building AP cost: 2, Combat AP cost: 4
- Neutral unit IDs start at 100000
- Bounds: x=[-1800, 1800], y=[-1096, 1096] (200px margin)

## Development Notes
- **Godot executable**: `C:\tools\godot\Godot_v4.6.2-stable_win64_console.exe`
- **Validation**: `Godot_v4.6.2-stable_win64_console.exe --path . --headless --check-only` (note: this actually runs the full terrain generation, not just parsing)
- All rendering uses `_draw()` + primitive drawing — no TileMap nodes, no sprite atlases
- Total code: ~14,759 lines GDScript across 50+ files in 9 subdirectories
- **Service pattern**: `scripts/services/` — `RefCounted` or Node for domain logic
- **Rules pattern**: `scripts/rules/` — static utility classes (RefCounted, no state)
- Autoloads: `McpInteractionServer` (`res://mcp_interaction_server.gd`) — TCP on port 9090
- Input in `main.gd` uses direct keycode checks (Enter/Tab) rather than InputMap
- Fog is float-based with 3×3 smoothing, 0.3s fade, triggers territory recalculation
- `data/editor_terrain_map.json` — editor terrain save/restore file
