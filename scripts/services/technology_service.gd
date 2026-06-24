class_name TechnologyService
extends Node

const TechnologyLibraryScript := preload("res://scripts/technologies/technology_library.gd")

signal technology_researched(player: int, technology_id: String, title: String)
signal technology_state_changed(player: int)

var _definitions: Array = []
var _by_id: Dictionary = {}
var _researched: Array = [{}, {}, {}]
var _active_effects: Array = [{}, {}, {}]
var _achievement_service: Node = null
var _civilization_rules: Node = null


func _ready() -> void:
	_definitions = TechnologyLibraryScript.get_definitions()
	for definition in _definitions:
		_by_id[str(definition["id"])] = definition
	for player in range(3):
		_research_free_root(player)


func setup(achievement_service: Node, civilization_rules: Node) -> void:
	_achievement_service = achievement_service
	_civilization_rules = civilization_rules
	for player in range(3):
		_rebuild_effects(player)


func get_definitions() -> Array:
	return _definitions.duplicate(true)


func get_definition(technology_id: String) -> Dictionary:
	return _by_id.get(technology_id, {}).duplicate(true)


func is_researched(player: int, technology_id: String) -> bool:
	if not _is_valid_player(player):
		return false
	return bool(_researched[player].get(technology_id, false))


func is_available(player: int, technology_id: String) -> bool:
	var info: Dictionary = get_research_info(player, technology_id)
	return bool(info.get("available", false))


func get_research_info(player: int, technology_id: String) -> Dictionary:
	if not _is_valid_player(player):
		return {"available": false, "reason": "invalid_player"}
	var definition: Dictionary = _by_id.get(technology_id, {})
	if definition.is_empty():
		return {"available": false, "reason": "missing_technology"}
	if is_researched(player, technology_id):
		return {"available": false, "reason": "already_researched"}

	for parent_id in definition.get("parent_techs", []):
		if not is_researched(player, str(parent_id)):
			return {
				"available": false,
				"reason": "missing_parent",
				"missing": str(parent_id),
			}

	var any_techs: Array = definition.get("required_any_techs", [])
	if not any_techs.is_empty():
		var has_any_required := false
		for any_id in any_techs:
			if is_researched(player, str(any_id)):
				has_any_required = true
				break
		if not has_any_required:
			return {
				"available": false,
				"reason": "missing_any_tech",
				"missing": any_techs.duplicate(),
			}

	for achievement_id in definition.get("required_achievements", []):
		if _achievement_service == null or not _achievement_service.has_method("is_completed"):
			return {"available": false, "reason": "achievement_service_missing"}
		if not bool(_achievement_service.call("is_completed", player, str(achievement_id))):
			return {
				"available": false,
				"reason": "missing_achievement",
				"missing": str(achievement_id),
			}

	for lord_id in definition.get("required_lords", []):
		if _civilization_rules == null or not _civilization_rules.has_method("has_lord"):
			return {"available": false, "reason": "civilization_service_missing"}
		if not bool(_civilization_rules.call("has_lord", player, str(lord_id))):
			return {
				"available": false,
				"reason": "missing_lord",
				"missing": str(lord_id),
			}

	var cost: int = get_effective_cost(player, technology_id)
	if cost > 0:
		if _achievement_service == null or not _achievement_service.has_method("get_tech_points"):
			return {"available": false, "reason": "achievement_service_missing"}
		var current_points: int = int(_achievement_service.call("get_tech_points", player))
		if current_points < cost:
			return {
				"available": false,
				"reason": "not_enough_tech_points",
				"cost": cost,
				"current": current_points,
			}

	return {
		"available": true,
		"reason": "",
		"cost": cost,
	}


func research(player: int, technology_id: String) -> bool:
	var info: Dictionary = get_research_info(player, technology_id)
	if not bool(info.get("available", false)):
		print("[Technology] Research failed: %s -> %s" % [technology_id, str(info.get("reason", ""))])
		return false
	var cost: int = int(info.get("cost", 0))
	if cost > 0:
		if _achievement_service == null or not _achievement_service.has_method("spend_tech_points"):
			return false
		if not bool(_achievement_service.call("spend_tech_points", player, cost)):
			return false
	_researched[player][technology_id] = true
	_rebuild_effects(player)
	var definition: Dictionary = _by_id.get(technology_id, {})
	technology_researched.emit(player, technology_id, str(definition.get("title", technology_id)))
	technology_state_changed.emit(player)
	print("[Technology] P%d researched %s." % [player, technology_id])
	return true


func force_research(player: int, technology_id: String) -> bool:
	if not _is_valid_player(player) or not _by_id.has(technology_id):
		return false
	_researched[player][technology_id] = true
	_rebuild_effects(player)
	technology_state_changed.emit(player)
	return true


func get_researched_ids(player: int) -> Array:
	if not _is_valid_player(player):
		return []
	return _researched[player].keys()


func get_available_ids(player: int) -> Array:
	var result: Array = []
	for definition in _definitions:
		var id: String = str(definition["id"])
		if is_available(player, id):
			result.append(id)
	return result


func get_effective_cost(player: int, technology_id: String) -> int:
	var definition: Dictionary = _by_id.get(technology_id, {})
	if definition.is_empty():
		return 0
	var cost: int = int(definition.get("cost", 0))
	var family: String = str(definition.get("family", ""))
	if family == "hybrid":
		cost -= get_modifier(player, "hybrid_tech_discount", 0)
	return maxi(0, cost)


func get_modifier(player: int, key: String, default_value: int = 0) -> int:
	if not _is_valid_player(player):
		return default_value
	return int(_active_effects[player].get(key, default_value))


func get_all_modifiers(player: int) -> Dictionary:
	if not _is_valid_player(player):
		return {}
	return _active_effects[player].duplicate(true)


func has_any(player: int, technology_ids: Array) -> bool:
	for technology_id in technology_ids:
		if is_researched(player, str(technology_id)):
			return true
	return false


func has_all(player: int, technology_ids: Array) -> bool:
	for technology_id in technology_ids:
		if not is_researched(player, str(technology_id)):
			return false
	return true


func get_state_summary(player: int) -> Dictionary:
	return {
		"player": player,
		"researched": get_researched_ids(player),
		"available": get_available_ids(player),
		"modifiers": get_all_modifiers(player),
	}


func _research_free_root(player: int) -> void:
	if not _is_valid_player(player):
		return
	for definition in _definitions:
		if int(definition.get("cost", 0)) == 0 and definition.get("parent_techs", []).is_empty():
			_researched[player][str(definition["id"])] = true
	_rebuild_effects(player)


func _rebuild_effects(player: int) -> void:
	if not _is_valid_player(player):
		return
	var effects: Dictionary = {}
	for definition in _definitions:
		var id: String = str(definition["id"])
		if not is_researched(player, id):
			continue
		var node_effects: Dictionary = definition.get("effects", {})
		for key in node_effects:
			var effect_key: String = str(key)
			var value = node_effects[key]
			if value is int or value is float:
				effects[effect_key] = int(effects.get(effect_key, 0)) + int(value)
			else:
				effects[effect_key] = value
	_active_effects[player] = effects


func _is_valid_player(player: int) -> bool:
	return player >= 0 and player < _researched.size()
