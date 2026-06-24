class_name BuildingEffectService
extends RefCounted
## Queries reusable area effects emitted by placed buildings.

const MOD_VISION_BONUS := "vision_bonus"
const MOD_ATTACK_BONUS := "attack_bonus"
const MOD_DAMAGE_REDUCTION := "damage_reduction"


func get_modifier_for_unit(building_manager: Node, unit: Dictionary, modifier_key: String) -> int:
	if building_manager == null or not building_manager.has_method("get_all_buildings"):
		return 0
	if unit.is_empty():
		return 0
	var result := 0
	var buildings: Array = building_manager.call("get_all_buildings")
	for building in buildings:
		var building_dict: Dictionary = building
		result += _get_building_modifier_for_unit(building_dict, unit, modifier_key)
	return result


func is_cell_in_building_effect(building: Dictionary, cell: Vector2i) -> bool:
	if building.is_empty() or not building.has("data"):
		return false
	var data: BuildingData = building["data"]
	if data.effect_radius <= 0:
		return false
	var center: Vector2i = _get_building_center(building)
	return _manhattan_distance(center, cell) <= data.effect_radius


func _get_building_modifier_for_unit(building: Dictionary, unit: Dictionary, modifier_key: String) -> int:
	if building.is_empty() or unit.is_empty():
		return 0
	if int(building.get("faction", -1)) != int(unit.get("faction", -2)):
		return 0
	var unit_pos: Vector2i = unit.get("grid_pos", Vector2i(-999, -999))
	if not is_cell_in_building_effect(building, unit_pos):
		return 0
	var data: BuildingData = building["data"]
	match data.unique_effect_id:
		"elf.wind_speaking_tree":
			if modifier_key == MOD_VISION_BONUS:
				return 1
		"orc.war_drum_camp":
			if modifier_key == MOD_ATTACK_BONUS and _is_melee_unit(unit):
				return 1
		"dwarf.iron_oath_fortress":
			if modifier_key == MOD_DAMAGE_REDUCTION:
				return 1
	return 0


func _is_melee_unit(unit: Dictionary) -> bool:
	if not unit.has("data"):
		return false
	var data: UnitData = unit["data"]
	return data.category == UnitData.UnitCategory.GUARD or "melee" in data.tags


func _get_building_center(building: Dictionary) -> Vector2i:
	var data: BuildingData = building["data"]
	var origin: Vector2i = building.get("origin", Vector2i.ZERO)
	return Vector2i(origin.x + data.footprint.x / 2, origin.y + data.footprint.y / 2)


func _manhattan_distance(a: Vector2i, b: Vector2i) -> int:
	return absi(a.x - b.x) + absi(a.y - b.y)
