class_name DefaultTemplateLibrary
extends RefCounted
## Code-side defaults used while the project migrates toward .tres content files.

const UnitTemplateScript := preload("res://scripts/templates/unit_template.gd")
const BuildingTemplateScript := preload("res://scripts/templates/building_template.gd")
const LordTemplateScript := preload("res://scripts/templates/lord_template.gd")
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
	worker.recruit_ap = 1
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
	scout.food_cost = 2
	scout.recruit_cost = [_amount("food", 2)]
	scout.recruit_ap_cost = 2
	scout.recruit_ap = 2
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
	guard.food_cost = 3
	guard.recruit_cost = [_amount("food", 3)]
	guard.recruit_ap_cost = 3
	guard.recruit_ap = 3
	guard.recruit_turns = 3

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
	_config_recruit(elf_scout, [_amount("food", 2)], 2, 2, 2, true)

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
	_config_recruit(elf_guard, [_amount("food", 3)], 3, 3, 3, true)

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
	_config_recruit(dwarf_scout, [_amount("food", 2)], 2, 2, 2, true)

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
	_config_recruit(dwarf_guard, [_amount("food", 3)], 3, 3, 3, true)

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
	_config_recruit(orc_scout, [_amount("food", 2)], 2, 2, 2, true)

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
	_config_recruit(orc_guard, [_amount("food", 3)], 3, 3, 3, true)

	var orc_bone_shield = _unit_basic(
		"unit.orc.bone_shield",
		"\u788e\u9aa8\u76fe\u5974",
		UnitTemplateScript.UnitRole.GUARD,
		1,
		1,
		9,
		1,
		["orc", "guard", "military", "melee", "tank", "shield", "damage_soak"]
	)
	orc_bone_shield.damage_reduction = 1
	_config_recruit(orc_bone_shield, [_amount("food", 3), _amount("wood", 2)], 2, 2, 3, true)

	var orc_hide_tower = _unit_basic(
		"unit.orc.hide_tower",
		"\u517d\u76ae\u5de8\u76fe\u5175",
		UnitTemplateScript.UnitRole.GUARD,
		1,
		2,
		14,
		1,
		["orc", "guard", "military", "melee", "tank", "shield", "heavy", "damage_soak"]
	)
	orc_hide_tower.damage_reduction = 2
	_config_recruit(orc_hide_tower, [_amount("food", 5), _amount("wood", 4), _amount("stone", 2)], 3, 3, 5, true)

	var orc_slinger = _unit_basic(
		"unit.orc.slinger",
		"\u517d\u4eba\u6295\u77f3\u5175",
		UnitTemplateScript.UnitRole.SPECIAL,
		1,
		2,
		4,
		3,
		["orc", "slinger", "ranged", "military", "throw_beast"]
	)
	orc_slinger.attack_range = 4
	_config_recruit(orc_slinger, [_amount("food", 3), _amount("stone", 4)], 2, 2, 3, true)

	# ========== 中立生物模板 ==========
	var wyvern_fire = _unit_basic(
		"neutral.wyvern.fire",
		"火焰亚龙",
		UnitTemplateScript.UnitRole.GUARD,
		1, 3, 6, 2,
		["neutral", "wyvern", "fire"]
	)
	wyvern_fire.ai_behavior = "guard"
	wyvern_fire.aggro_range = 2
	wyvern_fire.can_attack_units = true
	wyvern_fire.can_gather = false
	wyvern_fire.can_garrison = false

	var wyvern_frost = _unit_basic(
		"neutral.wyvern.frost",
		"冰霜亚龙",
		UnitTemplateScript.UnitRole.GUARD,
		1, 2, 8, 2,
		["neutral", "wyvern", "frost"]
	)
	wyvern_frost.ai_behavior = "guard"
	wyvern_frost.aggro_range = 2
	wyvern_frost.can_attack_units = true
	wyvern_frost.can_gather = false
	wyvern_frost.can_garrison = false

	var wyvern_toxic = _unit_basic(
		"neutral.wyvern.toxic",
		"毒液亚龙",
		UnitTemplateScript.UnitRole.GUARD,
		1, 3, 5, 2,
		["neutral", "wyvern", "toxic"]
	)
	wyvern_toxic.ai_behavior = "guard"
	wyvern_toxic.aggro_range = 2
	wyvern_toxic.can_attack_units = true
	wyvern_toxic.can_gather = false
	wyvern_toxic.can_garrison = false

	var trader = _unit_basic(
		"neutral.trader.wander",
		"流浪商队",
		UnitTemplateScript.UnitRole.SPECIAL,
		0, 0, 1, 0,
		["neutral", "trader", "hidden"]
	)
	trader.ai_behavior = "hidden_trader"
	trader.aggro_range = 0
	trader.can_attack_units = false
	trader.can_gather = false
	trader.can_garrison = false

	var goblin_revenge = _unit_basic(
		"neutral.goblin.revenge",
		"哥布林复仇队",
		UnitTemplateScript.UnitRole.GUARD,
		2, 2, 4, 2,
		["neutral", "goblin", "revenge"]
	)
	goblin_revenge.ai_behavior = "revenge"
	goblin_revenge.aggro_range = 3
	goblin_revenge.can_attack_units = true
	goblin_revenge.can_gather = false
	goblin_revenge.can_garrison = false

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
		orc_bone_shield.id: orc_bone_shield,
		orc_hide_tower.id: orc_hide_tower,
		orc_slinger.id: orc_slinger,
		wyvern_fire.id: wyvern_fire,
		wyvern_frost.id: wyvern_frost,
		wyvern_toxic.id: wyvern_toxic,
		trader.id: trader,
		goblin_revenge.id: goblin_revenge,
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
	lumber_camp.build_cost = [_amount("wood", 8)]
	lumber_camp.production = [
		_recipe_outputs("recipe.wood.flat", [_amount("wood", 3)])
	]
	lumber_camp.can_garrison = true
	lumber_camp.garrison_capacity = 2
	lumber_camp.allowed_garrison_unit_tags = ["worker"]
	lumber_camp.preferred_worker_tag = "elf"
	lumber_camp.max_per_faction = 7
	lumber_camp.tags = ["infra", "production", "wood"]

	var stone_wall = BuildingTemplateScript.new()
	stone_wall.id = "building.stone_wall"
	stone_wall.display_name = "\u77f3\u5899"
	stone_wall.description = "\u77ee\u4eba\u9632\u7ebf\u5efa\u7b51\uff1a\u5360\u683c\u963b\u6321\u79fb\u52a8\uff0c\u53ef\u88ab\u653b\u51fb\u548c\u4fee\u590d\u3002"
	stone_wall.role = BuildingTemplateScript.BuildingRole.SPECIAL
	stone_wall.hp_max = 12
	stone_wall.build_cost = [_amount("stone", 8)]
	stone_wall.max_per_faction = 99
	stone_wall.tags = ["defense", "wall", "stone_wall", "blocks_movement", "dwarf"]

	var watch_tower = BuildingTemplateScript.new()
	watch_tower.id = "building.watch_tower"
	watch_tower.display_name = "\u77ad\u671b\u5854"
	watch_tower.description = "\u77ee\u4eba\u9632\u7ebf\u5efa\u7b51\uff1a\u5360\u683c\u963b\u6321\u79fb\u52a8\uff0c\u63d0\u4f9b\u66f4\u5927\u9632\u7ebf\u89c6\u91ce\u3002"
	watch_tower.role = BuildingTemplateScript.BuildingRole.SCOUT
	watch_tower.hp_max = 10
	watch_tower.build_cost = [_amount("wood", 15), _amount("stone", 20), _amount("iron", 5)]
	watch_tower.max_per_faction = 6
	watch_tower.tags = ["defense", "watch_tower", "vision", "blocks_movement", "dwarf"]

	var forge = BuildingTemplateScript.new()
	forge.id = "building.forge"
	forge.display_name = "\u7194\u7089"
	forge.description = "\u77ee\u4eba\u5de5\u4e1a\u5efa\u7b51\uff1a\u5c06\u94c1\u77ff\u8f6c\u5316\u4e3a\u7cbe\u94a2\uff0c\u89e3\u9501\u79d8\u94f6\u5de5\u827a\u540e\u53ef\u8f6c\u5316\u79d8\u94f6\u3002"
	forge.role = BuildingTemplateScript.BuildingRole.SPECIAL
	forge.hp_max = 8
	forge.build_cost = [_amount("wood", 20), _amount("stone", 25), _amount("iron", 5)]
	forge.production = [
		_recipe_outputs("recipe.steel.basic", [_amount("steel", 1)])
	]
	forge.max_per_faction = 2
	forge.tags = ["industry", "forge", "conversion", "dwarf"]

	var wind_ancient_tree = BuildingTemplateScript.new()
	wind_ancient_tree.id = "building.wind_ancient_tree"
	wind_ancient_tree.display_name = "\u98ce\u8bed\u53e4\u6811"
	wind_ancient_tree.description = "\u7cbe\u7075\u98ce\u8bed\u8005\u7279\u8272\u5efa\u7b51\uff1a\u6bcf\u56de\u5408 +1 \u53e4\u6728\uff0c\u9644\u8fd1\u5df1\u65b9\u5355\u4f4d\u89c6\u91ce +1\u3002"
	wind_ancient_tree.role = BuildingTemplateScript.BuildingRole.SPECIAL
	wind_ancient_tree.hp_max = 8
	wind_ancient_tree.build_cost = [_amount("wood", 30), _amount("stone", 20)]
	wind_ancient_tree.production = [
		_recipe_outputs("recipe.ancient_wood.wind_tree", [_amount("ancient_wood", 1)])
	]
	var wind_tree_terrain: Array[int] = [
		TerrainData.Terrain.FOREST_ELF,
		TerrainData.Terrain.GLADE_ELF,
	]
	wind_ancient_tree.terrain_compatibility = wind_tree_terrain
	wind_ancient_tree.max_per_faction = 1
	wind_ancient_tree.tags = ["lord_building", "elf", "vision", "ancient_wood"]

	var gold_mine = BuildingTemplateScript.new()
	gold_mine.id = "building.gold_mine_shaft"
	gold_mine.display_name = "Gold Mine Shaft"
	gold_mine.role = BuildingTemplateScript.BuildingRole.GOLD_CHAIN
	gold_mine.hp_max = 6
	gold_mine.build_cost = [
		_amount("wood", 20),
		_amount("stone", 15),
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
		stone_wall.id: stone_wall,
		watch_tower.id: watch_tower,
		forge.id: forge,
		wind_ancient_tree.id: wind_ancient_tree,
		gold_mine.id: gold_mine,
	}


func make_lord_templates() -> Dictionary:
	var elf_lord: Resource = _lord_basic(
		"lord.elf.wind_seer",
		"\u98ce\u8bed\u8005",
		LordTemplateScript.Civilization.ELF,
		LordTemplateScript.Axis.INFORMATION,
		{"information": 3, "space": 0, "war": 0},
		["lord", "elf", "information", "starter"]
	)
	elf_lord.description = "\u7cbe\u7075\u8def\u7ebf\u521d\u59cb\u9886\u4e3b\uff1a\u5f3a\u5316\u89c6\u91ce\u3001\u4fa6\u5bdf\u548c\u8ff7\u96fe\u4e92\u52a8\u3002"
	elf_lord.unlock_building_ids = ["building.wind_ancient_tree"]
	elf_lord.unlock_action_ids = ["action.fog.reveal"]
	elf_lord.passive_modifiers = {
		"scout_move_bonus": 1,
	}

	var dwarf_lord: Resource = _lord_basic(
		"lord.dwarf.stone_warden",
		"\u77f3\u5b88\u536b",
		LordTemplateScript.Civilization.DWARF,
		LordTemplateScript.Axis.SPACE,
		{"information": 0, "space": 3, "war": 0},
		["lord", "dwarf", "space", "starter"]
	)
	dwarf_lord.description = "\u77ee\u4eba\u8def\u7ebf\u521d\u59cb\u9886\u4e3b\uff1a\u5f3a\u5316\u5efa\u7b51\u3001\u9632\u7ebf\u548c\u7a7a\u95f4\u63a7\u5236\u3002"
	dwarf_lord.unlock_building_ids = ["building.stone_wall", "building.watch_tower", "building.forge"]
	dwarf_lord.unlock_recipe_ids = ["recipe.mithril.basic"]
	dwarf_lord.passive_modifiers = {
		"building_hp_bonus": 2,
		"building_network_production_bonus": 1,
		"repair_efficiency_bonus": 1,
	}

	var orc_lord: Resource = _lord_basic(
		"lord.orc.blood_chief",
		"\u8840\u65a7\u914b\u957f",
		LordTemplateScript.Civilization.ORC,
		LordTemplateScript.Axis.WAR,
		{"information": 0, "space": 0, "war": 3},
		["lord", "orc", "war", "starter"]
	)
	orc_lord.description = "\u517d\u4eba\u8def\u7ebf\u521d\u59cb\u9886\u4e3b\uff1a\u5f3a\u5316\u6218\u6597\u8282\u594f\u3001\u63a0\u593a\u548c\u6218\u4e89\u7ecf\u6d4e\u3002"
	orc_lord.unlock_building_ids = ["building.blood_fang_den"]
	orc_lord.unlock_action_ids = ["action.warband.form"]
	orc_lord.passive_modifiers = {
		"kill_gold_reward": 1,
		"melee_atk_bonus": 1,
	}

	return {
		elf_lord.id: elf_lord,
		dwarf_lord.id: dwarf_lord,
		orc_lord.id: orc_lord,
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


func _lord_basic(
		p_id: String,
		p_name: String,
		p_civilization: int,
		p_primary_axis: int,
		p_axis_values: Dictionary,
		p_tags: Array) -> Resource:
	var template = LordTemplateScript.new()
	template.id = p_id
	template.display_name = p_name
	template.civilization = p_civilization
	template.primary_axis = p_primary_axis
	template.axis_values = p_axis_values.duplicate(true)
	template.tags = p_tags.duplicate()
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
	template.recruit_ap = ap_cost
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
