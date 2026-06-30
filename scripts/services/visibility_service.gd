class_name VisibilityService
extends Node

var _fog_manager: Node = null


func setup(fog_manager: Node) -> void:
	_fog_manager = fog_manager


func is_tile_visible(player: int, pos: Vector2i) -> bool:
	if _fog_manager == null or not _fog_manager.has_method("get_fog"):
		return true
	return float(_fog_manager.call("get_fog", player, pos.x, pos.y)) <= 0.0


func filter_units_for_player(player: int, units: Array) -> Array:
	var result: Array = []
	for unit_variant in units:
		var unit: Dictionary = unit_variant
		var faction: int = int(unit.get("faction", -1))
		var pos: Vector2i = unit.get("grid_pos", Vector2i(-1, -1))
		if faction == player or is_tile_visible(player, pos):
			result.append(_make_unit_view(unit, faction == player))
	return result


func filter_buildings_for_player(player: int, buildings: Array) -> Array:
	var result: Array = []
	for building_variant in buildings:
		var building: Dictionary = building_variant
		var faction: int = int(building.get("faction", -1))
		var origin: Vector2i = building.get("origin", Vector2i(-1, -1))
		var tiles: Array = building.get("tiles", [])
		var visible := faction == player or is_tile_visible(player, origin)
		if not visible:
			for tile_variant in tiles:
				var tile: Vector2i = tile_variant
				if is_tile_visible(player, tile):
					visible = true
					break
		if visible:
			result.append(_make_building_view(building, faction == player))
	return result


func filter_resources_for_player(player: int, resources: Array) -> Array:
	var result: Array = []
	for resource_variant in resources:
		var resource: Dictionary = resource_variant
		var pos: Vector2i = resource.get("grid_pos", Vector2i(-1, -1))
		if is_tile_visible(player, pos):
			result.append(resource.duplicate(true))
	return result


func _make_unit_view(unit: Dictionary, owned: bool) -> Dictionary:
	var data: UnitData = unit.get("data", null)
	var view := {
		"id": int(unit.get("id", -1)),
		"faction": int(unit.get("faction", -1)),
		"grid_pos": unit.get("grid_pos", Vector2i(-1, -1)),
		"template_id": str(unit.get("template_id", "")),
		"owned": owned,
	}
	if data != null:
		view["name"] = data.unit_name
		view["hp_max"] = data.hp_max if owned else 0
	view["hp"] = int(unit.get("hp", 0)) if owned else -1
	return view


func _make_building_view(building: Dictionary, owned: bool) -> Dictionary:
	var data: BuildingData = building.get("data", null)
	var view := {
		"id": int(building.get("id", -1)),
		"faction": int(building.get("faction", -1)),
		"origin": building.get("origin", Vector2i(-1, -1)),
		"tiles": building.get("tiles", []).duplicate(true),
		"owned": owned,
	}
	if data != null:
		view["name"] = data.name
		view["category"] = int(data.category)
		view["footprint"] = data.footprint
	view["hp"] = int(building.get("hp", 0)) if owned else -1
	view["level"] = int(building.get("level", 1)) if owned else 0
	return view
