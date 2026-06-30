class_name GameStateSerializer
extends Node

var _turn_manager: Node = null
var _unit_manager: Node = null
var _building_manager: Node = null
var _resource_manager: Node = null
var _resource_tracker: Node = null
var _visibility_service: VisibilityService = null


func setup(
	turn_manager: Node,
	unit_manager: Node,
	building_manager: Node,
	resource_manager: Node,
	resource_tracker: Node,
	visibility_service: VisibilityService
) -> void:
	_turn_manager = turn_manager
	_unit_manager = unit_manager
	_building_manager = building_manager
	_resource_manager = resource_manager
	_resource_tracker = resource_tracker
	_visibility_service = visibility_service


func make_player_snapshot(player: int) -> Dictionary:
	var ready: Array = []
	if _turn_manager != null and _turn_manager.has_method("get_ready_players"):
		ready = _turn_manager.call("get_ready_players")
	var snapshot := {
		"player": player,
		"round": _get_round_number(),
		"turn_phase": _get_turn_phase(),
		"current_player": _get_current_player(),
		"player_ready": ready,
		"ap": _get_player_ap(player),
		"resources": _get_player_resources(player),
		"units": _get_visible_units(player),
		"buildings": _get_visible_buildings(player),
		"resources_on_map": _get_visible_map_resources(player),
	}
	return snapshot


func make_public_snapshot() -> Dictionary:
	return {
		"round": _get_round_number(),
		"turn_phase": _get_turn_phase(),
		"current_player": _get_current_player(),
		"player_ready": _turn_manager.call("get_ready_players") if _turn_manager != null and _turn_manager.has_method("get_ready_players") else [],
	}


func _get_round_number() -> int:
	if _turn_manager == null:
		return 0
	return int(_turn_manager.get("round_number"))


func _get_turn_phase() -> int:
	if _turn_manager == null:
		return 0
	return int(_turn_manager.get("turn_phase"))


func _get_current_player() -> int:
	if _turn_manager == null:
		return 0
	return int(_turn_manager.get("current_player"))


func _get_player_ap(player: int) -> int:
	if _turn_manager == null or not _turn_manager.has_method("get_ap"):
		return 0
	return int(_turn_manager.call("get_ap", player))


func _get_player_resources(player: int) -> Dictionary:
	if _resource_tracker == null or not _resource_tracker.has_method("get_all"):
		return {}
	return _resource_tracker.call("get_all", player)


func _get_visible_units(player: int) -> Array:
	if _unit_manager == null or not _unit_manager.has_method("get_all_units"):
		return []
	var units: Array = _unit_manager.call("get_all_units")
	if _visibility_service == null:
		return units
	return _visibility_service.filter_units_for_player(player, units)


func _get_visible_buildings(player: int) -> Array:
	if _building_manager == null or not _building_manager.has_method("get_all_buildings"):
		return []
	var buildings: Array = _building_manager.call("get_all_buildings")
	if _visibility_service == null:
		return buildings
	return _visibility_service.filter_buildings_for_player(player, buildings)


func _get_visible_map_resources(player: int) -> Array:
	if _resource_manager == null or not _resource_manager.has_method("get_all_resource_views"):
		return []
	var resources: Array = _resource_manager.call("get_all_resource_views")
	if _visibility_service == null:
		return resources
	return _visibility_service.filter_resources_for_player(player, resources)
