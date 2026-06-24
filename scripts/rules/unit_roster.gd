class_name UnitRoster
extends RefCounted
## Initial faction unit roster definitions.


static func get_initial_unit_defs(faction: int) -> Array:
	match faction:
		0:
			return [
				{"template_id": "unit.elf.worker", "fallback": UnitData.new("精灵工人", UnitData.UnitCategory.WORKER, 2, 0, 3, 1, 1)},
				{"template_id": "unit.elf.scout", "fallback": UnitData.new("风行斥候", UnitData.UnitCategory.SCOUT, 4, 1, 3, 4, 1)},
				{"template_id": "unit.elf.guard", "fallback": UnitData.new("月影刺客", UnitData.UnitCategory.GUARD, 2, 3, 5, 2, 2)},
			]
		1:
			return [
				{"template_id": "unit.dwarf.worker", "fallback": UnitData.new("矮人工人", UnitData.UnitCategory.WORKER, 1, 0, 4, 1, 1)},
				{"template_id": "unit.dwarf.scout", "fallback": UnitData.new("勘探者", UnitData.UnitCategory.SCOUT, 2, 1, 4, 2, 1)},
				{"template_id": "unit.dwarf.guard", "fallback": UnitData.new("铁锤卫", UnitData.UnitCategory.GUARD, 1, 3, 8, 1, 2)},
			]
		2:
			return [
				{"template_id": "unit.orc.worker", "fallback": UnitData.new("兽人工人", UnitData.UnitCategory.WORKER, 1, 0, 4, 1, 1)},
				{"template_id": "unit.orc.scout", "fallback": UnitData.new("猎齿兽", UnitData.UnitCategory.SCOUT, 2, 2, 5, 2, 1)},
				{"template_id": "unit.orc.guard", "fallback": UnitData.new("血斧兵", UnitData.UnitCategory.GUARD, 1, 4, 6, 1, 2)},
				{"template_id": "unit.orc.slinger", "fallback": UnitData.new("\u517d\u4eba\u6295\u77f3\u5175", UnitData.UnitCategory.SPECIAL, 1, 2, 4, 3, 3, 4)},
			]
	return [
		{"template_id": "unit.worker", "fallback": UnitData.worker()},
		{"template_id": "unit.scout", "fallback": UnitData.scout()},
		{"template_id": "unit.guard", "fallback": UnitData.guard()},
	]
