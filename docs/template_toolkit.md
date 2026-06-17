# Template Toolkit

This project now has a low-intrusion template layer under `scripts/templates/`.
The current prototype can keep running while managers migrate one feature at a time.

## Core Files

- `game_template.gd`: shared id, display name, description, icon key, tags, and sort order.
- `resource_amount.gd`: reusable `{ resource_key, amount }` pair for costs and rewards.
- `production_recipe.gd`: generic input/output conversion rule.
- `unit_template.gd`: reusable unit definition.
- `building_template.gd`: reusable building definition.
- `resource_node_template.gd`: reusable map resource definition.
- `lord_template.gd`: reusable lord/civilization route definition.
- `default_template_library.gd`: code-side defaults used before `.tres` data files are authored.
- `template_registry.gd`: loader/query node for all templates.

`TemplateRegistry` is already mounted in `scenes/main.tscn` under `GameBoard`.

## Unit Template Pattern

Create one base template, then derive variants by overriding only the differences.

```gdscript
var guard = registry.get_unit("unit.guard")
var heavy_guard = guard.create_variant("unit.guard.heavy", {
	"display_name": "Heavy Guard",
	"move_max": 1,
	"atk": 4,
	"hp_max": 10,
	"tags": ["guard", "military", "melee", "heavy"],
})
```

The compatibility bridge is already in place:

```gdscript
unit_manager.add_unit_from_template(player, registry.get_unit("unit.worker"), grid_pos)
```

Existing `UnitData` still works. `UnitTemplate.to_unit_data()` and `UnitData.from_template()` let old systems consume new templates.

## Lord Template Pattern

`LordTemplate` is the reusable data block for the civilization route system. A lord does not execute gameplay by itself. It describes civilization axis values, unlocks, and passive modifier keys that later systems can query.

```gdscript
var lord: LordTemplate = registry.get_lord("lord.elf.wind_seer")
var vision_bonus: int = int(lord.get_modifier("unit_vision_bonus", 0))
var unlocks_tree: bool = lord.unlocks_building("building.wind_ancient_tree")
```

Each player now has one visible route-state node under `GameBoard`:

- `ElfCivilizationState`
- `DwarfCivilizationState`
- `OrcCivilizationState`

They all use `CivilizationRouteState` and aggregate owned lord templates into route values, unlock lists, and passive modifiers.

```gdscript
var elf_route = get_node("GameBoard/ElfCivilizationState")
var info_value: int = elf_route.get_axis_value("information")
var vision_bonus: int = elf_route.get_modifier_int("unit_vision_bonus")
var buildings: Array = elf_route.get_unlocked_buildings()
```

`CivilizationRuleService` is the common query surface for other gameplay systems:

```gdscript
var rules = get_node("GameBoard/CivilizationRuleService")
var vision_bonus: int = rules.get_modifier_int(player, "unit_vision_bonus")
var can_build_tree: bool = rules.unlocks_building(player, "building.wind_ancient_tree")
```

`UI/CivilizationDebugPanel` is a temporary read-only panel that shows each player's route summary during development.

The first default lords are:

- `lord.elf.wind_seer`: information route, vision and scouting modifiers.
- `lord.dwarf.stone_warden`: space route, building and repair modifiers.
- `lord.orc.blood_chief`: war route, kill reward and melee attack modifiers.

## Migration Order

1. Move unit spawning to `TemplateRegistry`.
2. Move recruit camp options to `BuildingTemplate.recruit_options`.
3. Move building UI card data to `BuildingTemplate`.
4. Move production and garrison bonuses to `ProductionRecipe`.
5. Move map resource definitions to `ResourceNodeTemplate`.
6. Use `LordTemplate` to unlock civilization-specific content without branching manager code.

The rule of thumb: new content should be template data first, system code only when the rule itself is new.
