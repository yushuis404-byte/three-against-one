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
		"Worker",
		UnitTemplateScript.UnitRole.WORKER,
		1,
		0,
		3,
		1,
		["worker", "civilian", "gatherer"]
	)
	worker.recruit_cost = [_amount("food", 1)]
	worker.can_attack_units = false

	var scout = _unit_basic(
		"unit.scout",
		"Scout",
		UnitTemplateScript.UnitRole.SCOUT,
		3,
		1,
		3,
		3,
		["scout", "military", "light"]
	)
	scout.food_cost = 1

	var guard = _unit_basic(
		"unit.guard",
		"Guard",
		UnitTemplateScript.UnitRole.GUARD,
		1,
		3,
		6,
		1,
		["guard", "military", "melee"]
	)
	guard.food_cost = 2

	var veteran_guard: Resource = guard.create_variant("unit.guard.veteran", {
		"display_name": "Veteran Guard",
		"atk": 4,
		"hp_max": 8,
		"tags": ["guard", "military", "melee", "veteran"],
	})

	return {
		worker.id: worker,
		scout.id: scout,
		guard.id: guard,
		veteran_guard.id: veteran_guard,
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
