class_name AchievementLibrary
extends RefCounted


static func get_definitions() -> Array:
	return [
		_def("foundation.lumber.first", "\u7b2c\u4e00\u5ea7\u4f10\u6728\u573a", "foundation", [], _cond("building", {"production_key": "wood"}), _reward(1, {"wood": 6})),
		_def("foundation.quarry.first", "\u7b2c\u4e00\u5ea7\u91c7\u77f3\u573a", "foundation", [], _cond("building", {"production_key": "stone"}), _reward(1, {"stone": 6})),
		_def("foundation.farm.first", "\u7b2c\u4e00\u5ea7\u519c\u573a", "foundation", [], _cond("building", {"production_key": "food"}), _reward(1, {"food": 6})),
		_def("foundation.storage.first", "\u7b2c\u4e00\u5ea7\u4ed3\u5e93", "foundation", [], _cond("building", {"category": BuildingData.BuildingCategory.STORAGE}), _reward(1, {"wood": 5, "stone": 5})),
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
