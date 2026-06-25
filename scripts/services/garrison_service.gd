class_name GarrisonService
extends RefCounted
## Garrison rules and state mutation for building dictionaries.

const DEFAULT_WORKER_PRODUCTION_BONUS := 1
const PREFERRED_WORKER_PRODUCTION_BONUS := 2


func max_garrison(building: Dictionary) -> int:
	if not building.has("data"):
		return 0
	var data: BuildingData = building["data"]
	if data.garrison_capacity > 0:
		return data.garrison_capacity
	var fp: Vector2i = data.footprint
	return max(0, fp.x * fp.y)


func can_garrison(buildings: Array, building_id: int, faction: int, unit_category: int = -1) -> bool:
	for building in buildings:
		if building["id"] != building_id:
			continue
		if building["faction"] != faction:
			return false
		var data: BuildingData = building["data"]
		if data.garrison_capacity <= 0:
			return false
		if building["garrison"].size() >= max_garrison(building):
			return false
		if unit_category >= 0 and unit_category != UnitData.UnitCategory.WORKER:
			return false
		return true
	return false


func garrison_unit(buildings: Array, building_id: int, unit_dict: Dictionary) -> bool:
	for building in buildings:
		if building["id"] == building_id:
			building["garrison"].append(unit_dict.duplicate())
			return true
	return false


func ungarrison_one(buildings: Array, building_id: int) -> Dictionary:
	for building in buildings:
		if building["id"] != building_id:
			continue
		if building["garrison"].is_empty():
			return {}
		var unit: Dictionary = building["garrison"].pop_back()
		return unit
	return {}


func get_garrison_bonus(buildings: Array, building_id: int) -> Dictionary:
	for building in buildings:
		if building["id"] != building_id:
			continue
		if building["garrison"].is_empty():
			return {}
		var data: BuildingData = building["data"]
		if BuildingRules.is_gold_mine_shaft(data):
			var count: int = building["garrison"].size()
			return { "gold_ore": count * 2 }
		var prod: Dictionary = data.production
		if prod.is_empty():
			return {}
		var bonus: Dictionary = {}
		var garrison: Array = building["garrison"]
		for unit in garrison:
			var unit_dict: Dictionary = unit
			var bonus_amount: int = _get_worker_production_bonus(unit_dict, data.preferred_worker_tag)
			if bonus_amount <= 0:
				continue
			for key in prod:
				var current: int = int(bonus.get(key, 0))
				bonus[key] = current + bonus_amount
		return bonus
	return {}


func has_worker_garrison(building: Dictionary) -> bool:
	var garrison: Array = building.get("garrison", [])
	for unit in garrison:
		var unit_dict: Dictionary = unit
		if not unit_dict.has("data"):
			continue
		var unit_data: UnitData = unit_dict["data"]
		if unit_data.category == UnitData.UnitCategory.WORKER:
			return true
	return false


func get_repair_per_round(building: Dictionary) -> int:
	if not building.has("data"):
		return 0
	var data: BuildingData = building["data"]
	if data.garrison_capacity <= 0:
		return 0
	if data.garrison_repair_requires_worker and not has_worker_garrison(building):
		return 0
	return maxi(0, data.garrison_repair_per_round)


func _get_worker_production_bonus(unit: Dictionary, preferred_worker_tag: String) -> int:
	if not unit.has("data"):
		return 0
	var unit_data: UnitData = unit["data"]
	if unit_data.category != UnitData.UnitCategory.WORKER:
		return 0
	if not preferred_worker_tag.is_empty() and preferred_worker_tag in unit_data.tags:
		return PREFERRED_WORKER_PRODUCTION_BONUS
	return DEFAULT_WORKER_PRODUCTION_BONUS
