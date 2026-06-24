class_name TechnologyLibrary
extends RefCounted


static func get_definitions() -> Array:
	return [
		_def("tech.root.civilization", "\u6587\u660e\u8d77\u70b9", "root", 0, [], [], [], _effects({})),

		_def("tech.common.map_drawing", "\u5730\u56fe\u7ed8\u5236", "common", 1, ["tech.root.civilization"], ["foundation.worker.force"], [], _effects({"scout_vision_bonus": 1})),
		_def("tech.common.terrain_record", "\u5730\u5f62\u8bb0\u5f55", "common", 1, ["tech.common.map_drawing"], [], [], _effects({"unit_vision_bonus": 1})),
		_def("tech.common.resource_marking", "\u8d44\u6e90\u6807\u8bb0", "common", 1, ["tech.common.map_drawing"], [], [], _effects({"resource_discovery_reward": 1})),
		_def("tech.common.border_survey", "\u8fb9\u5883\u6d4b\u7ed8", "common", 2, ["tech.common.terrain_record"], ["foundation.storage.first"], [], _effects({"outpost_vision_bonus": 1})),

		_def("tech.common.basic_forging", "\u57fa\u7840\u953b\u9020", "common", 1, ["tech.root.civilization"], ["foundation.quarry.first"], [], _effects({"garrison_production_bonus": 1})),
		_def("tech.common.tool_forging", "\u5de5\u5177\u953b\u9020", "common", 1, ["tech.common.basic_forging"], ["foundation.worker.garrison"], [], _effects({"worker_garrison_bonus": 1})),
		_def("tech.common.iron_mining", "\u94c1\u77ff\u5f00\u91c7", "common", 2, ["tech.common.basic_forging"], ["industry.iron.first"], [], _effects({"iron_production_bonus": 1})),
		_def("tech.common.metal_parts", "\u91d1\u5c5e\u6784\u4ef6", "common", 2, ["tech.common.basic_forging", "tech.common.iron_mining"], [], [], _effects({"building_hp_bonus": 2})),

		_def("tech.common.grain_ration", "\u519b\u7cae\u5236\u5ea6", "common", 1, ["tech.root.civilization"], ["foundation.farm.first"], [], _effects({"recruit_food_discount": 1})),
		_def("tech.common.recruitment_rules", "\u62db\u52df\u89c4\u7a0b", "common", 1, ["tech.common.grain_ration"], ["military.barracks.first"], [], _effects({"recruit_turn_discount": 1})),
		_def("tech.common.war_drum_mobilization", "\u6218\u9f13\u52a8\u5458", "common", 2, ["tech.common.recruitment_rules"], ["military.recruit.first"], [], _effects({"first_recruit_ap_discount": 1})),

		_def("tech.common.storage_system", "\u4ed3\u50a8\u5236\u5ea6", "common", 1, ["tech.root.civilization"], ["foundation.storage.first"], [], _effects({"storage_flat_bonus": 20})),
		_def("tech.common.building_upgrade", "\u5efa\u7b51\u5347\u7ea7", "common", 2, ["tech.common.storage_system", "tech.common.tool_forging"], ["foundation.worker.garrison"], [], _effects({"building_upgrade_ap_discount": 1})),

		_def("tech.common.gold_mining", "\u91d1\u77ff\u5f00\u91c7", "common", 2, ["tech.common.resource_marking", "tech.common.iron_mining"], ["industry.gold.shaft"], [], _effects({"gold_ore_production_bonus": 1})),
		_def("tech.common.coin_machinery", "\u94f8\u5e01\u673a\u68b0", "common", 2, ["tech.common.gold_mining", "tech.common.metal_parts"], ["industry.mint.first"], [], _effects({"mint_conversion_bonus": 1})),

		_def("tech.dragon.toxic_blood", "\u6bd2\u6db2\u9f99\u8840\u8fa8\u8bc6", "dragon", 1, ["tech.common.resource_marking"], ["military.dragon_blood.toxic"], [], _effects({})),
		_def("tech.dragon.corrosive_weapons", "\u8150\u8680\u6b66\u5668", "dragon", 2, ["tech.dragon.toxic_blood", "tech.common.recruitment_rules"], [], [], _effects({"scout_poison_weaken_turns": 3})),

		_def("tech.lord.elf.wind_sight", "\u98ce\u8bed\u89c6\u754c", "lord", 2, ["tech.common.border_survey"], ["lord.elf.first"], ["lord.elf.wind_seer"], _effects({"elf_lord_building_radius": 1})),
		_def("tech.lord.elf.forest_sense", "\u68ee\u6797\u901a\u611f", "lord", 2, ["tech.lord.elf.wind_sight", "tech.common.resource_marking"], ["industry.rare.first"], ["lord.elf.wind_seer"], _effects({"ancient_wood_production_bonus": 1})),
		_def("tech.lord.elf.hidden_march", "\u9690\u79d8\u884c\u519b", "lord", 3, ["tech.lord.elf.wind_sight", "tech.common.terrain_record"], [], ["lord.elf.wind_seer"], _effects({"forest_scout_move_discount": 1})),

		_def("tech.lord.dwarf.deep_forge", "\u6df1\u7089\u5de5\u827a", "lord", 2, ["tech.common.metal_parts"], ["lord.dwarf.first"], ["lord.dwarf.stone_warden"], _effects({"dwarf_lord_industry_bonus": 1})),
		_def("tech.lord.dwarf.vein_echo", "\u77ff\u8109\u56de\u54cd", "lord", 2, ["tech.lord.dwarf.deep_forge", "tech.common.iron_mining"], [], ["lord.dwarf.stone_warden"], _effects({"iron_production_bonus": 1})),
		_def("tech.lord.dwarf.stone_oath", "\u77f3\u8a93\u52a0\u56fa", "lord", 3, ["tech.lord.dwarf.deep_forge", "tech.common.building_upgrade"], [], ["lord.dwarf.stone_warden"], _effects({"building_hp_bonus": 3, "damage_reduction_bonus": 1})),

		_def("tech.lord.orc.blood_drum", "\u8840\u9f13\u53f7\u4ee4", "lord", 2, ["tech.common.war_drum_mobilization"], ["lord.orc.first"], ["lord.orc.blood_chief"], _effects({"orc_lord_military_bonus": 1})),
		_def("tech.lord.orc.raid_ration", "\u63a0\u98df\u519b\u7cae", "lord", 2, ["tech.lord.orc.blood_drum", "tech.common.grain_ration"], ["military.kill.neutral"], ["lord.orc.blood_chief"], _effects({"kill_food_reward": 1})),
		_def("tech.lord.orc.berserker_training", "\u72c2\u6218\u8bad\u7ec3", "lord", 3, ["tech.lord.orc.blood_drum", "tech.common.recruitment_rules"], [], ["lord.orc.blood_chief"], _effects({"melee_attack_bonus": 1})),

		_def("tech.hybrid.ancient_iron_branch", "\u8fdc\u53e4\u94c1\u679d", "hybrid", 3, ["tech.lord.elf.forest_sense", "tech.lord.dwarf.vein_echo"], [], ["lord.elf.wind_seer", "lord.dwarf.stone_warden"], _effects({"ancient_wood_production_bonus": 1, "iron_production_bonus": 1})),
		_def("tech.hybrid.forge_war_drum", "\u7194\u7089\u6218\u9f13", "hybrid", 3, ["tech.lord.dwarf.vein_echo", "tech.lord.orc.blood_drum"], [], ["lord.dwarf.stone_warden", "lord.orc.blood_chief"], _effects({"iron_production_bonus": 1, "recruit_turn_discount": 1})),
		_def("tech.hybrid.forest_raid", "\u6797\u95f4\u7a81\u88ad", "hybrid", 3, ["tech.lord.elf.hidden_march", "tech.lord.orc.berserker_training"], [], ["lord.elf.wind_seer", "lord.orc.blood_chief"], _effects({"light_unit_attack_bonus": 1, "scout_vision_bonus": 1})),
		_def("tech.hybrid.tri_lord_pact", "\u4e09\u65cf\u8bae\u7ea6", "hybrid", 4, ["tech.hybrid.ancient_iron_branch", "tech.hybrid.forge_war_drum", "tech.hybrid.forest_raid"], [], ["lord.elf.wind_seer", "lord.dwarf.stone_warden", "lord.orc.blood_chief"], _effects({"lord_building_radius": 1, "hybrid_tech_discount": 1})),
	]


static func _def(
		id: String,
		title: String,
		family: String,
		cost: int,
		parent_techs: Array,
		required_achievements: Array,
		required_lords: Array,
		effects: Dictionary) -> Dictionary:
	return {
		"id": id,
		"title": title,
		"family": family,
		"cost": cost,
		"parent_techs": parent_techs,
		"required_achievements": required_achievements,
		"required_lords": required_lords,
		"effects": effects,
	}


static func _effects(values: Dictionary) -> Dictionary:
	return values.duplicate(true)
