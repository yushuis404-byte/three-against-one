class_name GarrisonService
extends RefCounted
## Garrison rules and state mutation for building dictionaries.


func max_garrison(building: Dictionary) -> int:
	var fp: Vector2i = building["data"].footprint
	return max(2, fp.x * fp.y)


func can_garrison(buildings: Array, building_id: int, faction: int, unit_category: int = -1) -> bool:
	for building in buildings:
		if building["id"] != building_id:
			continue
		if building["faction"] != faction:
			return false
		var data: BuildingData = building["data"]
		if data.production.is_empty() and not data.is_special_building:
			return false
		if building["garrison"].size() >= max_garrison(building):
			return false
		if not data.production.is_empty() or data.is_special_building:
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
		var count: int = building["garrison"].size()
		if BuildingRules.is_gold_mine_shaft(data):
			return { "gold_ore": count * 2 }
		var prod: Dictionary = data.production
		if prod.is_empty():
			return {}
		var bonus: Dictionary = {}
		for key in prod:
			bonus[key] = count
		return bonus
	return {}
