# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview
**Three Against One** — 3-player hotseat/network turn-based 2.5D strategy board game in Godot 4.6 (~33,500 lines GDScript, 81 scripts).
Three asymmetric factions (Elf/Dwarf/Orc) on a 100×56 shared grid map with fog of war, procedural terrain, resource chains, building chains, tech tree, achievements, stage-based scoring, PvP/PvE combat, and a goblin economy.

## Docs
Key design docs in `docs/`: `game_design_document.md` (comprehensive), `technology_tree.md`, `goblin_hex_card_library.md`, `dragon_stats.md`, `template_toolkit.md`.

## Commands
- **Open project**: Open `project.godot` in Godot 4.6 editor
- **Run game**: Click "Play" (F5) in Godot editor, or `godot4 --path .` from terminal
- **Validate syntax** (no GUI): `C:/tools/godot/Godot_v4.6.2-stable_win64_console.exe --path . --headless --check-only`
- **MCP automation**: `mcp_interaction_server.gd` runs as autoload on TCP 127.0.0.1:9090 for JSON commands (click, screenshot, eval, key_press, multiplayer, etc.)
- **No tests/CI**: Project has no test framework

## Known GDScript Quirks
- `var x := arr[i]` fails when `arr` is untyped Array (returns Variant). Fix: use `var x: Type = arr[i]`.
- Similarly, `for v in [1, 2, 3]` yields Variant — use `var v: int = ...` or wrap in `int()`.
- Ternary `var x := val if cond else val2` also fails type inference. Use explicit `var x: Type = ...`.
- All indentation uses **tabs**, not spaces.
- Godot 4 font/color overrides: use `add_theme_font_size_override("font_size", N)` and `add_theme_color_override("font_color", Color(...))`. Don't use `theme_override_font_sizes["key"] = val` (Godot 3 syntax, causes runtime error).
- Control mouse_filter: `STOP` blocks events from reaching parents; `PASS` passes to parent; `IGNORE` skips the node entirely. Containers like VBoxContainer call `accept_event()` in `_gui_input` by default — set `mouse_filter = Control.MOUSE_FILTER_IGNORE` to make them transparent to clicks.
- **Edit tool + Chinese characters**: The Edit tool cannot match lines containing Chinese fullwidth characters due to Unicode normalization differences. Use Python scripts (via Bash) for modifications in files with Chinese text.
- **Node reference across siblings**: use `get_parent().get_node("TargetNode")` instead of `@onready` when the target is later in tree order (avoids init-order race). All managers use this pattern in `_ready()`.
- **Animation system**: All unit sprites use `_draw()` + `draw_texture_rect_region()` with horizontal sprite strips (no AnimatedSprite2D nodes). Preloaded Texture2D constants + frame count constants drive animation. Idle is wall-clock driven, other states use tween progress (t 0→1).
- **Tech tree panel indentation**: `_draw_node()` method body uses 1-tab indent, not 2-tab. Python replacements need `\t` (single tab).
- **Loading texture via `load()` vs `preload()`**: Button icons (achievement/tech/score/civ) use `load()` in `_init_*_button()` methods. For `const` level textures, use `preload()`.

## Architecture

### Scene Tree
```
StartScreen (Node2D) — start_screen.gd (video bg + buttons + BGM)
  └── MultiplayerConnectionPanel (Control) — code-built overlay for host/join

Main (Node2D) — main.gd (~1800 lines, game state machine)
├── GameCamera (Camera2D) — camera_controller_2d.gd
├── GameBoard (Node2D)
│   ├── GridManager2D (Node2D)          — grid_manager_2d.gd (6-phase terrain gen + draw)
│   ├── ResourceManager2D (Node2D)      — resource_manager_2d.gd (15 resource types, draw)
│   ├── FogOfWar2D (Node2D)             — fog_of_war_2d.gd (per-player float fog overlay)
│   ├── TerritoryManager2D (Node2D)     — territory_manager_2d.gd (borders, town_halls)
│   ├── TurnManager2D (Node)            — turn_manager_2d.gd (turn + AP)
│   ├── BuildingManager2D (Node2D)      — building_manager_2d.gd (buildings, textures, upgrades)
│   ├── WallBlueprintManager2D (Node2D) — wall_blueprint_manager_2d.gd (dwarf wall planning)
│   ├── UnitManager2D (Node2D)          — unit_manager_2d.gd (~5680 lines, units + combat + sprites)
│   ├── GatheringManager2D (Node2D)     — gathering_manager_2d.gd (resource collection)
│   ├── DragonPortalManager2D (Node2D)  — dragon_portal_manager_2d.gd (dragon nest mechanics)
│   ├── ResourceTracker (Node)          — resource_tracker.gd (per-faction inventory)
│   ├── TemplateRegistry (Node)         — templates/template_registry.gd
│   ├── CivilizationRuleService (Node)  — civilization/civilization_rule_service.gd
│   ├── AchievementService (Node)       — services/achievement_service.gd
│   ├── TechnologyService (Node)        — services/technology_service.gd
│   ├── VictoryService (Node)           — services/victory_service.gd
│   ├── StageEventService (Node)        — services/stage_event_service.gd
│   ├── VisibilityService (Node)        — services/visibility_service.gd
│   ├── GameStateSerializer (Node)      — services/game_state_serializer.gd
│   ├── NetworkGameService (Node)       — services/network_game_service.gd
│   └── NeutralUnitManager2D (Node2D)   — neutral/neutral_unit_manager_2d.gd
├── UI (CanvasLayer)
│   ├── ResourcePanel (Panel)           — top bar (faction label + 10 resource icons + progress bars)
│   ├── TurnLabel, StageLabel, APStatusLabel, ScoreLabel, ZoomStatusLabel
│   ├── NetworkStatusLabel, NetworkReadyLabel
│   ├── CreativeModeButton
│   ├── BuildingUI                      — right-side building cards
│   ├── RecruitUI                       — bottom-left recruitment panel
│   ├── UnitInfoPanel                   — bottom unit details
│   ├── GoblinMarketUI / GoblinHexPanel — card market + hex selection overlays
│   ├── UnitSkillBar                    — bottom-right skill buttons
│   ├── ActionPreviewPanel              — move range preview
│   ├── ExpeditionManualPanel           — full-screen manual overlay (z_index 102/112)
│   ├── AchievementTreePanel / TechnologyTreePanel / ScoreRulePanel / CivilizationRoutePanel
│   └── Circular sidebar buttons (achievement/tech/score/civ/manual) + WallBlueprintButton/Label
└── BGMPlayer (AudioStreamPlayer)       — game background music
```

**Draw order**: GridManager2D → ResourceManager2D → FogOfWar2D → TerritoryManager2D → BuildingManager2D → UnitManager2D → GatheringManager2D → NeutralUnitManager2D → DragonPortalManager2D. UI CanvasLayer on top.

**Autoloads**: `McpInteractionServer` (TCP :9090, 4421 lines) | `GameSession` (tracks network/creative mode state across scenes)

### Grid Data Model (all use outer y/inner x, deterministic via `_simple_hash(x, y, seed)`)

| Grid | Owner | Type | Size |
|------|-------|------|------|
| `terrain_grid[y][x]` | GridManager2D | Terrain enum | 100×56 |
| `zone_grid[y][x]` | GridManager2D | ZoneTag enum | 100×56 |
| `resource_grid[y][x]` | ResourceManager2D | ResourceType enum | 100×56 |
| `building_grid[y][x]` | BuildingManager2D | int or -1 | 100×56 |
| `fog_grids[player][y][x]` | FogOfWar2D | float 0.0–0.7 | 3×100×56 |
| `owner_grid[y][x]` | TerritoryManager2D | int -1/0/1/2 | 100×56 |

### Terrain Generation (6 Phases, grid_manager_2d.gd)

1. **Phase 1 — Mountain** (dragon mountain: central volcano with corridors, 4.2% RUINS tiles)
2. **Phase 2 — Resource ring** (resource band between mount radius and outer ring)
3. **Phase 3 — Ocean** (endless sea border with cliffs)
4. **Phase 4 — Territories** (3 faction territories with heightmap + zone tags)
5. **Phase 5 — Impassable** (scattered DRAGON_MOUNT/void blockers)
6. **Phase 6 — Assign terrain** (height + angle → terrain type per zone)

### Key Systems

**Turn system**: Hotseat Elf(0)→Dwarf(1)→Orc(2)→neutral turn→round end. +25AP/round, cap 50. Tab/Enter ends turn. Signal order: `round_started` → `player_turn_started` ×3 → `neutral_turn_started/ended` → `round_ended`. Creative mode bypasses AP/resource costs.

**Stage system**: 5 stages × 15 rounds = 75 total. `game_stage_rules.gd` maps round→stage. StageEventService fires stage-specific events. Goblin hex trigger rounds: 7, 22, 37.

**Victory system** (`services/victory_service.gd`): Conquest (last core building standing → winner) + Final scoring (after round 75 — buildings/units/resources/techs → rank, with resource divisor/points/cap table).

**Combat**: Real-time duel with Timer (1s alternating attacks). VFX: flash/shake/damage text, sprite-based hurt/attack/death animations. Line-of-sight range check before engagement.

**Animation**: All sprites rendered via `_draw()` with `draw_texture_rect_region()` on horizontal strip PNGs. Each unit type has constants for: frame count per state (idle/walk/hurt/attack/death), frame size (px), draw size, and duration. Idle is wall-clock driven (`Time.get_ticks_msec()`), other states use tween progress.

**Building system**: 25+ types across 8 categories (CORE, ECONOMY, SCOUT, DEFENSE, RECRUITMENT, INDUSTRY, LORD_SPECIAL). Footprint validation, ghost preview, territory/terrain/AP/resource checks. Upgrade service (warehouse Lv1→3), defense towers with automated attack (range/damage/cooldown/AoE). Civilization rules filter per faction+lord. Garrison system: workers inside buildings produce per-turn and repair 1 HP/round.

**Garrison bonus system**: Buildings with `preferred_worker_tag` give +2 production when the matching faction worker is garrisoned, +1 for others. Elf→伐木场, Dwarf→采石场, Orc→农场. Gold mine shaft and mint require garrisoned workers to produce.

**Building textures**: Configured in `data/building_texture_fit.json` — each entry has footprint, offset, scale, and texture path. The `_get_building_texture_key()` function in `building_manager_2d.gd` maps buildings to their config key based on properties (category, tags, production type, storage level). Outpost buildings call `add_town_hall()` on TerritoryManager2D to expand territory.

**Tech tree** (`services/technology_service.gd`): Per-faction techs with TP costs, achievement gating, lord requirements, unlock effects. `technology_library.gd` defines 29 techs across 5 families (root/common/dragon/lord/hybrid). The `technology_tree_panel.gd` renders nodes in a polar-coordinate layout with faction-specific frame textures (elf/dwarf/orc/generic/dragon). Required_any_techs connections are drawn as **dashed lines**.

**Achievement system** (`services/achievement_service.gd`): Milestone tracking → tech points (TP) rewards. `achievement_library.gd` defines 22+ achievements across 4 branches (foundation/industry/military/lord). Each completed achievement grants 1 TP + resources.

**Civilization routes**: Each faction has 1 starter lord (Elf: Wind Seer/information, Dwarf: Stone Warden/space, Orc: Blood Chief/war) with 3-axis progression (information/space/war). Lords unlock buildings, units, recipes, actions. Exclusive lord tags prevent incompatible combinations.

**Garrison economy**: Buildings with `can_garrison = true` accept workers. Per-round production: `PREFERRED_WORKER_PRODUCTION_BONUS = 2` (matching faction), `DEFAULT_WORKER_PRODUCTION_BONUS = 1` (non-matching). Gold chain: gold mine shaft (needs resource point + garrison → gold_ore) → mint (consumes gold_ore → gold).

**Goblin economy**: GoblinMarketUI (card market with reputation pricing) + GoblinHexPanel (stage-based hex selection at rounds 7/22/37) + hidden traders + reputation system (0-100). 36 hex cards across 4 rarities (black/silver/gold/prismatic) and 8 categories (economy/development/building/combat/exploration/defense/comprehensive/faction).

**Neutral units**: 7 wyverns (guard/aggro, 3 fire/2 frost/2 toxic, dragon blood drops), 6 hidden traders, goblin revenge squads. Timer-based combat, proximity triggers. Neutral unit IDs start at 100000.

**Dragon portal**: Dragon nest mechanics with portal confirm panel. Central volcano feature. 3 faction portals with 5-tile interaction range, 6 unit teleport cap, 1 AP/unit exit cost. Miasma damage when miasma_shield tech not researched.

### Resource Economy Chain

```
wood ← lumber camp / iron_oak gathering
stone ← quarry / quarry gathering
food ← farm / berries+game+fruit tree gathering
iron ← mine / iron mine gathering
  ├→ steel ← forge (consumes iron)
  └→ mithril ← forge (tech unlock)
gold_ore ← gold mine shaft (needs garrison + resource point)
  └→ gold ← mint (consumes gold_ore)
magic_dust ← extraction tower / magic_node+rune_stone+star_crystal+ancient_relic gathering
ancient_wood ← ancient_wood harvest camp / ancient_forest+ancient_tree+world_tree_root gathering
dragon_crystal ← dragon_crystal crater gathering
dragon_blood series ← wyvern kills (fire/frost/toxic)
```

### Multiplayer / Network (ENet)

**Architecture**: Host-Client (authoritative server). Host runs all validation + broadcasts RPCs.

**Flow**: Start screen → "联机" → MultiplayerConnectionPanel (code-built overlay). Host or Join → creates ENetMultiplayerPeer → transitions to main.tscn.

**Adoption**: `NetworkGameService.adopt_existing_peer()` detects pre-existing peer from start screen and initializes faction maps, signal connections, and enumerates already-connected peers.

**Service**: `network_game_service.gd` (638 lines) manages peer→faction mapping, action request routing (40+ action types), snapshot broadcasting, turn sync. `game_state_serializer.gd` serializes per-faction state. `game_session.gd` (autoload) persists connection state across scene transitions.

**Pattern**: Client sends `request_action(type, payload)` → host validates + applies + broadcasts snapshot → clients apply via `_rpc_apply_*`. `_execute_as_player()` pattern in unit/building managers for host-side context switching.

### Key Data Files

| File | Role |
|------|------|
| `scripts/terrain_data.gd` | Terrain enum (12 types), color, passability, buildability |
| `scripts/building_data.gd` | BuildingData class + factory (25+ buildings across 8 categories) |
| `scripts/unit_data.gd` | UnitData class + factory (base worker/scout/guard) |
| `scripts/core/game_catalog.gd` | Shared names: resources (15), factions (3), dragon blood drops |
| `scripts/rules/terrain_data.gd` | (alias for scripts/terrain_data.gd) |
| `scripts/rules/game_stage_rules.gd` | Stage timing: 5 stages × 15 rounds, hex trigger rounds |
| `scripts/rules/goblin_hex_card_library.gd` | 36 hex card definitions with 4 rarities |
| `scripts/rules/achievement_library.gd` | (alias: scripts/achievements/achievement_library.gd) |
| `scripts/rules/technology_library.gd` | (alias: scripts/technologies/technology_library.gd) |
| `scripts/templates/default_template_library.gd` | Unit/building/lord template factory |
| `data/building_texture_fit.json` | Building texture config (footprint/offset/scale/texture path) |

### Core Scripts by Size

| Lines | Script | Role |
|-------|--------|------|
| 5680 | `scripts/unit_manager_2d.gd` | Units, combat, sprite animation, warbands, action preview |
| 4421 | `mcp_interaction_server.gd` | MCP TCP automation server (autoload) |
| 1928 | `scripts/building_manager_2d.gd` | Building placement, upgrades, networks, effects, recruitment |
| 1807 | `scripts/main.gd` | Game state machine, initializes ALL subsystems |
| 1802 | `scripts/neutral/neutral_unit_manager_2d.gd` | Wyvern AI, goblin market, reputation |
| 1702 | `scripts/grid_manager_2d.gd` | 6-phase terrain generation, editor painting |
| 695 | `scripts/resource_manager_2d.gd` | 15 resource types, deterministic placement |
| 689 | `scripts/templates/default_template_library.gd` | Unit/building template factory |
| 638 | `scripts/services/network_game_service.gd` | ENet multiplayer: host/join, RPC routing, snapshots |
| 608 | `scripts/ui/technology_tree_panel.gd` | Tech tree UI (_draw-based, polar layout, faction frames) |
| 579 | `scripts/building_data.gd` | Building factory: 25+ types across 8 categories |
| 560 | `scripts/unit_info_panel.gd` | Unit details panel with warband UI |
| 551 | `scripts/ui/achievement_tree_panel.gd` | Achievement tree UI (_draw-based) |
| 546 | `scripts/wall_blueprint_manager_2d.gd` | Dwarf wall planning system |
| 504 | `scripts/ui/civilization_route_panel.gd` | Civilization route selection UI |
| 412 | `scripts/building_ui.gd` | Right-side building cards, category sidebar |
| 401 | `scripts/services/achievement_service.gd` | Achievement tracking + TP rewards |
| 391 | `scripts/services/recruitment_service.gd` | Queue-based recruitment |
| 384 | `scripts/fog_of_war_2d.gd` | Per-player float fog, 3×3 smoothing, 0.3s fade |
| 338 | `scripts/ui/goblin_market_ui.gd` | Card market overlay |
| 319 | `scripts/services/technology_service.gd` | Tech tree state + research |
| 294 | `scripts/services/goblin_hex_service.gd` | Goblin hex card logic |
| 278 | `scripts/ui/expedition_manual_panel.gd` | Full-screen game manual with pagination + directory |

### Constants
- **Grid**: 100×56, 56×56 land at LAND_OFFSET_X=22, 32px tiles
- **Viewport**: 1920×1080, MSAA 2x, canvas_items stretch
- **Camera zoom**: 0.55–2.5, bounds: x=[-1800, 1800], y=[-1096, 1096]
- **AP**: +25/round, cap 50. Building 2 AP, Combat 4 AP, recruit 1–3 AP
- **Stages**: 5 stages × 15 rounds = 75 total rounds
- **Goblin hex triggers**: rounds 7, 22, 37
- **Neutral unit IDs**: start at 100000
- **Network**: default port 24531, max 3 players
- **Dragon nest radius**: 1.5, mount radius: 7.3, resource ring outer: 9.5
- **Dragon portal**: 6 units max, range 5, exit AP 1
- **Main city**: 2×2 footprint, HP 40, ATK 5
- **Warehouse storage bonus**: Lv1 +20, Lv2 +55, Lv3 +115 (covers 9 resource types)
- **Garrison bonus**: preferred_worker_tag → +2, other → +1; repair 1 HP/round/worker
