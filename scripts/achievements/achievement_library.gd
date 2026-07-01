class_name AchievementLibrary
extends RefCounted


static func get_definitions() -> Array:
	return [
		_def("foundation.lumber.first", "\u7b2c\u4e00\u5ea7\u4f10\u6728\u573a", "foundation", [], _cond("building", {"production_key": "wood"}), _reward(1, {"wood": 6})),
		_def("foundation.quarry.first", "\u7b2c\u4e00\u5ea7\u91c7\u77f3\u573a", "foundation", [], _cond("building", {"production_key": "stone"}), _reward(1, {"stone": 6})),
		_def("foundation.farm.first", "\u7b2c\u4e00\u5ea7\u519c\u573a", "foundation", [], _cond("building", {"production_key": "food"}), _reward(1, {"food": 6})),
		_def("foundation.storage.first", "\u7b2c\u4e00\u5ea7\u4ed3\u5e93", "foundation", [], _cond("building", {"category": BuildingData.BuildingCategory.ECONOMY}), _reward(1, {"wood": 5, "stone": 5})),
		_def("foundation.worker.force", "\u52b3\u529b\u6210\u578b", "foundation", [], _cond("unit_count", {"category": UnitData.UnitCategory.WORKER, "count": 3}), _reward(1, {"food": 5})),
		_def("foundation.worker.garrison", "\u5de5\u4eba\u5165\u9a7b", "foundation", ["foundation.worker.force"], _cond("building_garrison", {"worker": true}), _reward(1, {})),

		_def("industry.iron.first", "\u7b2c\u4e00\u5ea7\u94c1\u77ff\u4e95", "industry", ["foundation.quarry.first"], _cond("building", {"production_key": "iron"}), _reward(1, {"iron": 3})),
		_def("industry.gold.shaft", "\u5efa\u7acb\u91d1\u77ff\u4e95", "industry", ["foundation.lumber.first", "foundation.quarry.first"], _cond("building", {"special": "gold_shaft"}), _reward(1, {"stone": 5})),
		_def("industry.gold_ore.first", "\u7b2c\u4e00\u6279\u91d1\u77ff\u77f3", "industry", ["industry.gold.shaft"], _cond("resource_stock", {"key": "gold_ore", "amount": 1}), _reward(1, {})),
		_def("industry.mint.first", "\u7b2c\u4e00\u5ea7\u94f8\u5e01\u5382", "industry", ["industry.iron.first", "industry.gold_ore.first"], _cond("building", {"special": "mint"}), _reward(1, {"iron": 3})),
		_def("industry.gold.first", "\u7b2c\u4e00\u679a\u91d1\u5e01", "industry", ["industry.mint.first"], _cond("resource_stock", {"key": "gold", "amount": 1}), _reward(1, {})),
		_def("industry.rare.first", "\u7a00\u6709\u6750\u6599", "industry", ["industry.iron.first"], _cond("resource_any_stock", {"keys": ["magic_dust", "ancient_wood"], "amount": 1}), _reward(1, {})),

		_def("military.barracks.first", "\u7b2c\u4e00\u5ea7\u5175\u8425", "military", ["foundation.farm.first"], _cond("building", {"tag": "barracks"}), _reward(1, {"food": 5})),
		_def("military.barracks.two", "\u53cc\u5175\u8425", "military", ["military.barracks.first"], _cond("building_count", {"tag": "barracks", "count": 2}), _reward(1, {"wood": 8})),
		_def("military.barracks.worker", "\u5175\u8425\u5165\u9a7b", "military", ["military.barracks.first", "foundation.worker.garrison"], _cond("building_garrison", {"tag": "barracks", "worker": true}), _reward(1, {})),
		_def("military.recruit.first", "\u7b2c\u4e00\u540d\u6218\u6597\u5355\u4f4d", "military", ["military.barracks.first"], _cond("unit_recruited", {"combat": true}), _reward(1, {"food": 5})),
		_def("military.force.three", "\u6218\u6597\u5c0f\u961f", "military", ["military.recruit.first"], _cond("unit_count", {"combat": true, "count": 3}), _reward(1, {})),
		_def("military.force.six", "\u6218\u56e2\u96cf\u5f62", "military", ["military.force.three"], _cond("unit_count", {"combat": true, "count": 6}), _reward(1, {"food": 10})),
		_def("military.kill.neutral", "\u7b2c\u4e00\u6b21\u72e9\u730e", "military", ["military.recruit.first"], _cond("kill", {"target": "neutral", "count": 1}), _reward(1, {"food": 8})),
		_def("military.dragon_blood.fire", "\u706b\u7130\u9f99\u8840", "military", ["military.kill.neutral"], _cond("resource_stock", {"key": "fire_dragon_blood", "amount": 1}), _reward(1, {})),
		_def("military.dragon_blood.frost", "\u51b0\u971c\u9f99\u8840", "military", ["military.kill.neutral"], _cond("resource_stock", {"key": "frost_dragon_blood", "amount": 1}), _reward(1, {})),
		_def("military.dragon_blood.toxic", "\u6bd2\u6db2\u9f99\u8840", "military", ["military.kill.neutral"], _cond("resource_stock", {"key": "toxic_dragon_blood", "amount": 1}), _reward(1, {})),
		_def("military.kill.player", "\u7b2c\u4e00\u6b21\u4ea4\u950b", "military", ["military.kill.neutral"], _cond("kill", {"target": "player", "count": 1}), _reward(1, {"gold": 2})),

		_def("lord.building.first", "\u7b2c\u4e00\u5ea7\u9886\u4e3b\u5efa\u7b51", "lord", ["foundation.worker.garrison"], _cond("building", {"category": BuildingData.BuildingCategory.LORD_SPECIAL}), _reward(1, {"magic_dust": 2})),
		_def("lord.elf.first", "\u7cbe\u7075\u9886\u4e3b\u636e\u70b9", "lord", ["lord.building.first"], _cond("building", {"civilization": "elf"}), _reward(1, {"ancient_wood": 2})),
		_def("lord.dwarf.first", "\u77ee\u4eba\u9886\u4e3b\u636e\u70b9", "lord", ["lord.building.first"], _cond("building", {"civilization": "dwarf"}), _reward(1, {"stone": 8})),
		_def("lord.orc.first", "\u517d\u4eba\u9886\u4e3b\u636e\u70b9", "lord", ["lord.building.first"], _cond("building", {"civilization": "orc"}), _reward(1, {"food": 8})),
	]


static func _def(id: String, title: String, branch: String, parents: Array, condition: Dictionary, reward: Dictionary) -> Dictionary:
	return {
		"id": id,
		"title": title,
		"branch": branch,
		"panel": _panel_for_id(id, branch),
		"position": _position_for_id(id),
		"icon_key": _icon_for_id(id, condition),
		"description": _description_for_id(id, title),
		"target": _target_for_condition(condition),
		"unlocks_hint": _unlocks_for_id(id),
		"parents": parents,
		"condition": condition,
		"reward": reward,
	}


static func _cond(kind: String, args: Dictionary) -> Dictionary:
	var result: Dictionary = args.duplicate(true)
	result["kind"] = kind
	return result


static func _reward(tech_points: int, resources: Dictionary) -> Dictionary:
	return {
		"tech_points": tech_points,
		"resources": resources,
	}


static func _panel_for_id(id: String, branch: String) -> String:
	match id:
		"military.dragon_blood.fire", "military.dragon_blood.frost", "military.dragon_blood.toxic":
			return "dragon"
		"lord.elf.first":
			return "elf_shadow"
		"lord.dwarf.first":
			return "dwarf_fortress"
		"lord.orc.first":
			return "orc_war"
		"lord.building.first":
			return "lord"
	return branch


static func _position_for_id(id: String) -> Vector2i:
	var positions: Dictionary = {
		"foundation.worker.force": Vector2i(0, 0),
		"foundation.lumber.first": Vector2i(1, 0),
		"foundation.quarry.first": Vector2i(2, 0),
		"foundation.farm.first": Vector2i(3, 0),
		"foundation.storage.first": Vector2i(2, 1),
		"foundation.worker.garrison": Vector2i(1, 1),

		"industry.iron.first": Vector2i(0, 0),
		"industry.gold.shaft": Vector2i(1, 0),
		"industry.gold_ore.first": Vector2i(2, 0),
		"industry.mint.first": Vector2i(3, 0),
		"industry.gold.first": Vector2i(4, 0),
		"industry.rare.first": Vector2i(2, 1),

		"military.barracks.first": Vector2i(0, 0),
		"military.barracks.two": Vector2i(1, 0),
		"military.barracks.worker": Vector2i(1, 1),
		"military.recruit.first": Vector2i(2, 0),
		"military.force.three": Vector2i(3, 0),
		"military.force.six": Vector2i(4, 0),
		"military.kill.neutral": Vector2i(3, 1),
		"military.kill.player": Vector2i(4, 1),

		"military.dragon_blood.fire": Vector2i(1, 0),
		"military.dragon_blood.frost": Vector2i(2, 0),
		"military.dragon_blood.toxic": Vector2i(3, 0),

		"lord.building.first": Vector2i(0, 0),
		"lord.elf.first": Vector2i(0, 0),
		"lord.dwarf.first": Vector2i(0, 0),
		"lord.orc.first": Vector2i(0, 0),
	}
	if positions.has(id):
		var result: Vector2i = positions[id]
		return result
	return Vector2i.ZERO


static func _icon_for_id(id: String, condition: Dictionary) -> String:
	if id.begins_with("lord.elf"):
		return "elf"
	if id.begins_with("lord.dwarf"):
		return "dwarf"
	if id.begins_with("lord.orc"):
		return "orc"
	if id.find("dragon_blood") >= 0:
		return "dragon"
	var kind: String = str(condition.get("kind", ""))
	match kind:
		"building", "building_count", "building_garrison":
			if condition.has("production_key"):
				return str(condition["production_key"])
			if condition.has("special"):
				return str(condition["special"])
			if condition.has("tag"):
				return str(condition["tag"])
			return "building"
		"unit_recruited", "unit_count":
			if bool(condition.get("worker", false)):
				return "worker"
			return "unit"
		"kill":
			return "kill"
		"resource_stock", "resource_any_stock":
			if condition.has("key"):
				return str(condition["key"])
			return "resource"
	return "achievement"


static func _description_for_id(id: String, title: String) -> String:
	var descriptions: Dictionary = {
		"foundation.worker.force": "拥有 3 名工人，说明基础劳动力已经成型。",
		"foundation.worker.garrison": "让工人进入建筑驻守，开启驻守产出和建筑协作。",
		"industry.gold.shaft": "在金矿资源点上建立金矿井，进入金币经济链。",
		"industry.gold_ore.first": "产出第一批金矿石，为铸币做准备。",
		"military.recruit.first": "招募第一名真正的战斗单位。",
		"military.force.six": "形成 6 人规模的战团雏形。",
		"military.kill.neutral": "完成第一次狩猎，打开战争经济的入口。",
		"military.kill.player": "击败其他玩家单位，进入真实冲突阶段。",
		"lord.building.first": "建造任意领主特色建筑，开始选择文明路线。",
		"lord.elf.first": "建立精灵领主据点，进入情报、视野和迷雾路线。",
		"lord.dwarf.first": "建立矮人领主据点，进入筑防、驻守和阵地路线。",
		"lord.orc.first": "建立兽人领主据点，进入击杀收益和战团路线。",
	}
	if descriptions.has(id):
		return str(descriptions[id])
	return title


static func _target_for_condition(condition: Dictionary) -> int:
	if condition.has("amount"):
		return int(condition["amount"])
	if condition.has("count"):
		return int(condition["count"])
	return 1


static func _unlocks_for_id(id: String) -> Array:
	var hints: Dictionary = {
		"foundation.worker.force": ["tech.common.map_drawing"],
		"foundation.storage.first": ["tech.common.storage_system", "tech.common.border_survey"],
		"foundation.worker.garrison": ["tech.common.tool_forging", "tech.common.building_upgrade"],
		"industry.iron.first": ["tech.common.iron_mining"],
		"industry.gold.shaft": ["tech.common.gold_mining"],
		"industry.mint.first": ["tech.common.coin_machinery"],
		"military.barracks.first": ["tech.common.recruitment_rules"],
		"military.recruit.first": ["tech.common.war_drum_mobilization"],
		"military.kill.neutral": ["tech.dragon.nest_survey", "tech.lord.orc.raid_ration"],
		"lord.elf.first": ["tech.lord.elf.wind_sight"],
		"lord.dwarf.first": ["tech.lord.dwarf.deep_forge"],
		"lord.orc.first": ["tech.lord.orc.blood_drum"],
	}
	if hints.has(id):
		var result: Array = hints[id]
		return result.duplicate()
	return []
