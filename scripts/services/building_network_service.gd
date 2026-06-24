class_name BuildingNetworkService
extends RefCounted
## Computes short-range building network bonuses for civilization routes.

const MOD_NETWORK_PRODUCTION_BONUS := "building_network_production_bonus"
const DEFAULT_LINK_RANGE := 4


func get_network_info(buildings: Array, building: Dictionary, civilization_rules: Node = null) -> Dictionary:
	if building.is_empty() or not building.has("data"):
		return _make_info(false, 0, 0, DEFAULT_LINK_RANGE, [])
	var faction: int = int(building.get("faction", -1))
	var route_bonus: int = _get_route_modifier(civilization_rules, faction, MOD_NETWORK_PRODUCTION_BONUS)
	var linked_ids: Array = _get_linked_building_ids(buildings, building, DEFAULT_LINK_RANGE)
	var is_connected: bool = linked_ids.size() > 0
	var production_bonus: int = 0
	if route_bonus > 0 and is_connected and _can_receive_production_bonus(building):
		production_bonus = route_bonus
	return _make_info(is_connected, linked_ids.size(), production_bonus, DEFAULT_LINK_RANGE, linked_ids)


func get_production_bonus(buildings: Array, building: Dictionary, resource_key: String, civilization_rules: Node = null) -> int:
	if resource_key.is_empty():
		return 0
	var info: Dictionary = get_network_info(buildings, building, civilization_rules)
	return int(info.get("production_bonus", 0))


func can_use_network_bonus(player: int, civilization_rules: Node = null) -> bool:
	return _get_route_modifier(civilization_rules, player, MOD_NETWORK_PRODUCTION_BONUS) > 0


func get_link_range() -> int:
	return DEFAULT_LINK_RANGE


func is_cell_in_network_range(building: Dictionary, cell: Vector2i) -> bool:
	if building.is_empty() or not building.has("data"):
		return false
	var center: Vector2i = _get_building_center(building)
	return _manhattan_distance(center, cell) <= DEFAULT_LINK_RANGE


func _get_linked_building_ids(buildings: Array, building: Dictionary, link_range: int) -> Array:
	var linked_ids: Array = []
	var target_id: int = int(building.get("id", -1))
	var faction: int = int(building.get("faction", -1))
	if faction < 0:
		return linked_ids
	for other in buildings:
		var other_building: Dictionary = other
		var other_id: int = int(other_building.get("id", -1))
		if other_id == target_id:
			continue
		if int(other_building.get("faction", -2)) != faction:
			continue
		if not _is_network_node(other_building):
			continue
		if _distance_between_buildings(building, other_building) <= link_range:
			linked_ids.append(other_id)
	return linked_ids


func _can_receive_production_bonus(building: Dictionary) -> bool:
	if building.is_empty() or not building.has("data"):
		return false
	var data: BuildingData = building["data"]
	return not data.production.is_empty()


func _is_network_node(building: Dictionary) -> bool:
	if building.is_empty() or not building.has("data"):
		return false
	return true


func _get_route_modifier(civilization_rules: Node, player: int, key: String) -> int:
	if civilization_rules == null or player < 0:
		return 0
	if civilization_rules.has_method("get_modifier_int"):
		return int(civilization_rules.call("get_modifier_int", player, key, 0))
	if civilization_rules.has_method("get_modifier"):
		return int(civilization_rules.call("get_modifier", player, key, 0))
	return 0


func _make_info(active: bool, linked_count: int, production_bonus: int, link_range: int, linked_ids: Array) -> Dictionary:
	return {
		"active": active,
		"linked_count": linked_count,
		"production_bonus": production_bonus,
		"link_range": link_range,
		"linked_building_ids": linked_ids.duplicate(),
	}


func _distance_between_buildings(a: Dictionary, b: Dictionary) -> int:
	return _manhattan_distance(_get_building_center(a), _get_building_center(b))


func _get_building_center(building: Dictionary) -> Vector2i:
	var data: BuildingData = building["data"]
	var origin: Vector2i = building.get("origin", Vector2i.ZERO)
	return Vector2i(origin.x + data.footprint.x / 2, origin.y + data.footprint.y / 2)


func _manhattan_distance(a: Vector2i, b: Vector2i) -> int:
	return absi(a.x - b.x) + absi(a.y - b.y)
