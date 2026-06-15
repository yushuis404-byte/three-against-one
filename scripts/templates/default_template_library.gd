class_name DefaultTemplateLibrary
extends RefCounted
## Code-side defaults used while the project migrates toward .tres content files.

const UnitTemplateScript := preload("res://scripts/templates/unit_template.gd")
const BuildingTemplateScript := preload("res://scripts/templates/building_template.gd")
const ResourceAmountScript := preload("res://scripts/templates/resource_amount.gd")
const ProductionRecipeScript := preload("res://scripts/templates/production_recipe.gd")


func make_unit_templates() -> Dictionary:
	var worker = _unit_basic(
		"unit.worker",
		"工人",
		UnitTemplateScript.UnitRole.WORKER,
		1,
		0,
		3,
		1,
		["worker", "civilian", "gatherer"]
	)
	worker.recruit_cost = [_amount("food", 1)]
	worker.recruit_ap_cost = 1
	worker.recruit_turns = 1
	worker.can_attack_units = false

	var scout = _unit_basic(
		"unit.scout",
		"斥候",
		UnitTemplateScript.UnitRole.SCOUT,
		3,
		1,
		3,
		3,
		["scout", "military", "light"]
	)
	scout.food_cost = 1
	scout.recruit_cost = [_amount("food", 1), _amount("wood", 5)]
	scout.recruit_ap_cost = 1
	scout.recruit_turns = 2

	var guard = _unit_basic(
		"unit.guard",
		"守卫",
		UnitTemplateScript.UnitRole.GUARD,
		1,
		3,
		6,
		1,
		["guard", "military", "melee"]
	)
	guard.food_cost = 2
	guard.recruit_cost = [_amount("food", 2), _amount("wood", 5), _amount("stone", 5)]
	guard.recruit_ap_cost = 1
	guard.recruit_turns = 2

	var veteran_guard: Resource = guard.create_variant("unit.guard.veteran", {
		"display_name": "精锐守卫",
		"atk": 4,
		"hp_max": 8,
		"recruit_turns": 3,
		"tags": ["guard", "military", "melee", "veteran"],
	})

	var elf_worker = _unit_basic(
		"unit.elf.worker",
		"精灵工人",
		UnitTemplateScript.UnitRole.WORKER,
		2,
		0,
		3,
		1,
		["elf", "worker", "civilian", "gatherer", "forest_move_bonus"]
	)
	_config_recruit(elf_worker, [_amount("food", 1)], 1, 1, 1, false)

	var elf_scout = _unit_basic(
		"unit.elf.scout",
		"风行斥候",
		UnitTemplateScript.UnitRole.SCOUT,
		4,
		1,
		3,
		4,
		["elf", "scout", "military", "light", "forest_move_bonus", "high_vision"]
	)
	_config_recruit(elf_scout, [_amount("gold", 50), _amount("wood", 20)], 1, 2, 1, true)

	var elf_guard = _unit_basic(
		"unit.elf.guard",
		"月影刺客",
		UnitTemplateScript.UnitRole.GUARD,
		2,
		3,
		5,
		2,
		["elf", "guard", "military", "melee", "mobile_attacker"]
	)
	_config_recruit(elf_guard, [_amount("gold", 80), _amount("wood", 20), _amount("ancient_wood", 10)], 1, 2, 2, true)

	var dwarf_worker = _unit_basic(
		"unit.dwarf.worker",
		"矮人工人",
		UnitTemplateScript.UnitRole.WORKER,
		1,
		0,
		4,
		1,
		["dwarf", "worker", "civilian", "gatherer", "sturdy"]
	)
	_config_recruit(dwarf_worker, [_amount("food", 1)], 1, 1, 1, false)

	var dwarf_scout = _unit_basic(
		"unit.dwarf.scout",
		"勘探者",
		UnitTemplateScript.UnitRole.SCOUT,
		2,
		1,
		4,
		2,
		["dwarf", "scout", "military", "light", "resource_detect_bonus", "mountain_move_bonus"]
	)
	_config_recruit(dwarf_scout, [_amount("gold", 50), _amount("stone", 20)], 1, 2, 1, true)

	var dwarf_guard = _unit_basic(
		"unit.dwarf.guard",
		"铁锤卫",
		UnitTemplateScript.UnitRole.GUARD,
		1,
		3,
		8,
		1,
		["dwarf", "guard", "military", "melee", "high_hp", "defender"]
	)
	_config_recruit(dwarf_guard, [_amount("gold", 80), _amount("stone", 20), _amount("iron", 10)], 1, 2, 2, true)

	var orc_worker = _unit_basic(
		"unit.orc.worker",
		"兽人工人",
		UnitTemplateScript.UnitRole.WORKER,
		1,
		0,
		4,
		1,
		["orc", "worker", "civilian", "gatherer", "sturdy"]
	)
	_config_recruit(orc_worker, [_amount("food", 1)], 1, 1, 1, false)

	var orc_scout = _unit_basic(
		"unit.orc.scout",
		"猎齿兽",
		UnitTemplateScript.UnitRole.SCOUT,
		2,
		2,
		5,
		2,
		["orc", "scout", "military", "beast", "bonus_vs_worker"]
	)
	_config_recruit(orc_scout, [_amount("gold", 50), _amount("food", 30)], 1, 2, 0, true)

	var orc_guard = _unit_basic(
		"unit.orc.guard",
		"血斧兵",
		UnitTemplateScript.UnitRole.GUARD,
		1,
		4,
		6,
		1,
		["orc", "guard", "military", "melee", "high_attack"]
	)
	_config_recruit(orc_guard, [_amount("gold", 80), _amount("food", 30), _amount("iron", 10)], 1, 2, 2, true)

	return {
		worker.id: worker,
		scout.id: scout,
		guard.id: guard,
		veteran_guard.id: veteran_guard,
		elf_worker.id: elf_worker,
		elf_scout.id: elf_scout,
		elf_guard.id: elf_guard,
		dwarf_worker.id: dwarf_worker,
		dwarf_scout.id: dwarf_scout,
		dwarf_guard.id: dwarf_guard,
		orc_worker.id: orc_worker,
		orc_scout.id: orc_scout,
		orc_guard.id: orc_guard,
	}


func make_building_templates(unit_templates: Dictionary) -> Dictionary:
	var recruit_camp = BuildingTemplateScript.new()
	recruit_camp.id = "building.recruit_camp"
	recruit_camp.display_name = "Recruit Camp"
	recruit_camp.role = BuildingTemplateScript.BuildingRole.RECRUIT
	recruit_camp.hp_max = 4
	recruit_camp.build_cost = [_amount("wood", 20), _amount("stone", 15)]
	recruit_camp.max_per_faction = 3
	recruit_camp.recruit_options = [unit_templates["unit.worker"]]
	recruit_camp.tags = ["recruit", "infra"]

	var barracks = BuildingTemplateScript.new()
	barracks.id = "building.barracks_lv1"
	barracks.display_name = "兵营"
	barracks.role = BuildingTemplateScript.BuildingRole.MILITARY
	barracks.hp_max = 8
	barracks.build_cost = [_amount("gold", 100), _amount("wood", 50), _amount("stone", 30)]
	barracks.max_per_faction = 99
	barracks.recruit_options = [unit_templates["unit.guard"], unit_templates["unit.scout"]]
	barracks.tags = ["military", "recruit"]

	var lumber_camp = BuildingTemplateScript.new()
	lumber_camp.id = "building.lumber_camp"
	lumber_camp.display_name = "Lumber Camp"
	lumber_camp.role = BuildingTemplateScript.BuildingRole.INFRA
	lumber_camp.hp_max = 4
	lumber_camp.build_cost = [_amount("wood", 3)]
	lumber_camp.production = [
		_recipe_outputs("recipe.wood.flat", [_amount("wood", 3)])
	]
	lumber_camp.max_per_faction = 7
	lumber_camp.tags = ["infra", "production", "wood"]

	var gold_mine = BuildingTemplateScript.new()
	gold_mine.id = "building.gold_mine_shaft"
	gold_mine.display_name = "Gold Mine Shaft"
	gold_mine.role = BuildingTemplateScript.BuildingRole.GOLD_CHAIN
	gold_mine.hp_max = 6
	gold_mine.build_cost = [
		_amount("wood", 20),
		_amount("stone", 15),
		_amount("iron", 5),
	]
	gold_mine.needs_resource_point = true
	gold_mine.required_resource_tags = ["gold"]
	gold_mine.can_garrison = true
	gold_mine.garrison_capacity = 2
	gold_mine.allowed_garrison_unit_tags = ["worker"]
	var mine_recipe = _recipe_outputs(
		"recipe.gold_ore.per_worker",
		[_amount("gold_ore", 2)]
	)
	mine_recipe.requires_garrison = true
	mine_recipe.per_garrison_unit = true
	mine_recipe.required_unit_tags = ["worker"]
	gold_mine.production = [mine_recipe]
	gold_mine.max_per_faction = 2
	gold_mine.tags = ["infra", "gold", "garrison"]

	return {
		recruit_camp.id: recruit_camp,
		barracks.id: barracks,
		lumber_camp.id: lumber_camp,
		gold_mine.id: gold_mine,
	}


func _unit_basic(
		p_id: String,
		p_name: String,
		p_role: int,
		p_move: int,
		p_atk: int,
		p_hp: int,
		p_vision: int,
		p_tags: Array) -> Resource:
	var template = UnitTemplateScript.new()
	template.id = p_id
	template.display_name = p_name
	template.role = p_role
	template.move_max = p_move
	template.atk = p_atk
	template.hp_max = p_hp
	template.vision = p_vision
	template.tags = p_tags.duplicate()
	template.can_gather = p_role == UnitTemplateScript.UnitRole.WORKER
	return template


func _config_recruit(
		template: Resource,
		cost: Array,
		ap_cost: int,
		turns: int,
		food_cost: int,
		can_attack: bool) -> void:
	template.recruit_cost = cost
	template.recruit_ap_cost = ap_cost
	template.recruit_turns = turns
	template.food_cost = food_cost
	template.can_attack_units = can_attack


func _amount(key: String, amount: int) -> Resource:
	var item = ResourceAmountScript.new()
	item.key = key
	item.amount = amount
	return item


func _recipe_outputs(id: String, outputs: Array) -> Resource:
	var recipe = ProductionRecipeScript.new()
	recipe.id = id
	recipe.outputs = outputs
	return recipe
