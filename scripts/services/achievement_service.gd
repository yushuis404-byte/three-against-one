class_name AchievementService
extends Node

const AchievementLibraryScript := preload("res://scripts/achievements/achievement_library.gd")

signal achievement_completed(player: int, achievement_id: String, title: String)
signal achievement_state_changed(player: int)
signal tech_points_changed(player: int, amount: int)

var _definitions: Array = []
var _by_id: Dictionary = {}
var _completed: Array = [{}, {}, {}]
var _tech_points: Array[int] = [0, 0, 0]
var _event_counts: Array = [{}, {}, {}]
var _resource_tracker: Node = null
var _building_manager: Node = null
var _unit_manager: Node = null
var _neutral_manager: Node = null


func _ready() -> void:
	_definitions = AchievementLibraryScript.get_definitions()
	for definition in _definitions:
		_by_id[str(definition["id"])] = definition


func setup(resource_tracker: Node, building_manager: Node, unit_manager: Node, neutral_manager: Node) -> void:
	_resource_tracker = resource_tracker
	_building_manager = building_manager
	_unit_manager = unit_manager
	_neutral_manager = neutral_manager
	_connect_signal(_building_manager, "building_placed", _on_building_placed)
	_connect_signal(_building_manager, "building_upgraded", _on_building_upgraded)
	_connect_signal(_building_manager, "building_garrisoned", _on_building_garrisoned)
	_connect_signal(_building_manager, "unit_recruited", _on_unit_recruited)
	_connect_signal(_unit_manager, "unit_killed", _on_unit_killed)
	_connect_signal(_neutral_manager, "neutral_unit_killed", _on_neutral_unit_killed)
	_connect_signal(_resource_tracker, "resources_updated", _on_resources_updated)


func get_definitions() -> Array:
	return _definitions.duplicate(true)


func get_definition(achievement_id: String) -> Dictionary:
	return _by_id.get(achievement_id, {}).duplicate(true)


func is_completed(player: int, achievement_id: String) -> bool:
	if player < 0 or player >= _completed.size():
		return false
	return bool(_completed[player].get(achievement_id, false))


func is_unlocked(player: int, achievement_id: String) -> bool:
	var definition: Dictionary = _by_id.get(achievement_id, {})
	if definition.is_empty():
		return false
	for parent_id in definition.get("parents", []):
		if not is_completed(player, str(parent_id)):
			return false
	return true


func get_completed_count(player: int) -> int:
	if player < 0 or player >= _completed.size():
		return 0
	return _completed[player].size()


func get_tech_points(player: int) -> int:
	if player < 0 or player >= _tech_points.size():
		return 0
	return _tech_points[player]


func spend_tech_points(player: int, amount: int) -> bool:
	if player < 0 or player >= _tech_points.size():
		return false
	if _tech_points[player] < amount:
		return false
	_tech_points[player] -= amount
	tech_points_changed.emit(player, _tech_points[player])
	achievement_state_changed.emit(player)
	return true


func get_branch_summary(player: int) -> Dictionary:
	var result: Dictionary = {}
	for definition in _definitions:
		var branch: String = str(definition.get("branch", "other"))
		if not result.has(branch):
			result[branch] = {"total": 0, "completed": 0, "unlocked": 0}
		result[branch]["total"] = int(result[branch]["total"]) + 1
		if is_completed(player, str(definition["id"])):
			result[branch]["completed"] = int(result[branch]["completed"]) + 1
		elif is_unlocked(player, str(definition["id"])):
			result[branch]["unlocked"] = int(result[branch]["unlocked"]) + 1
	return result


func get_recent_completed(player: int, limit: int = 4) -> Array:
	var result: Array = []
	for definition in _definitions:
		var id: String = str(definition["id"])
		if is_completed(player, id):
			result.append(str(definition["title"]))
	if result.size() > limit:
		result = result.slice(result.size() - limit, result.size())
	return result


func get_progress(player: int, achievement_id: String) -> Dictionary:
	if player < 0 or player >= _completed.size():
		return {"current": 0, "target": 1}
	var definition: Dictionary = _by_id.get(achievement_id, {})
	if definition.is_empty():
		return {"current": 0, "target": 1}
	var condition: Dictionary = definition.get("condition", {})
	var target: int = int(definition.get("target", _condition_target(condition)))
	target = maxi(1, target)
	if is_completed(player, achievement_id):
		return {"current": target, "target": target}
	var current: int = _condition_current(player, condition)
	return {
		"current": clampi(current, 0, target),
		"target": target,
	}


func _connect_signal(node: Node, signal_name: String, callable: Callable) -> void:
	if node == null or not node.has_signal(signal_name):
		return
	if not node.is_connected(signal_name, callable):
		node.connect(signal_name, callable)


func _on_building_placed(player: int, building: Dictionary) -> void:
	_evaluate_event(player, "building", {"building": building})
	_evaluate_all_counts(player)


func _on_building_upgraded(player: int, building: Dictionary, _level: int) -> void:
	_evaluate_event(player, "building_upgrade", {"building": building})
	_evaluate_all_counts(player)


func _on_building_garrisoned(player: int, building: Dictionary, unit: Dictionary) -> void:
	_evaluate_event(player, "building_garrison", {"building": building, "unit": unit})


func _on_unit_recruited(player: int, unit: Dictionary, unit_template_id: String) -> void:
	_register_unit_recruit_progress(player, unit)
	_evaluate_event(player, "unit_recruited", {"unit": unit, "unit_template_id": unit_template_id})
	_evaluate_all_counts(player)


func _on_unit_killed(killer_player: int, _victim_player: int, _victim: Dictionary) -> void:
	_increment_event_count(killer_player, "kill.player")
	_increment_event_count(killer_player, "kill.any")
	_evaluate_event(killer_player, "kill", {"target": "player"})


func _on_neutral_unit_killed(killer_player: int, _neutral: Dictionary) -> void:
	_increment_event_count(killer_player, "kill.neutral")
	_increment_event_count(killer_player, "kill.any")
	_evaluate_event(killer_player, "kill", {"target": "neutral"})


func _on_resources_updated(player: int) -> void:
	_evaluate_event(player, "resource_stock", {})
	_evaluate_event(player, "resource_any_stock", {})


func _evaluate_all_counts(player: int) -> void:
	_evaluate_event(player, "building_count", {})
	_evaluate_event(player, "unit_count", {})


func _evaluate_event(player: int, kind: String, context: Dictionary) -> void:
	if player < 0 or player >= _completed.size():
		return
	for definition in _definitions:
		var id: String = str(definition["id"])
		if is_completed(player, id) or not is_unlocked(player, id):
			continue
		var condition: Dictionary = definition.get("condition", {})
		if str(condition.get("kind", "")) != kind:
			continue
		if _condition_met(player, condition, context):
			_complete(player, definition)


func _condition_met(player: int, condition: Dictionary, context: Dictionary) -> bool:
	var kind: String = str(condition.get("kind", ""))
	match kind:
		"building":
			return _building_matches(context.get("building", {}), condition)
		"building_count":
			return _count_buildings(player, condition) >= int(condition.get("count", 1))
		"building_garrison":
			return _building_matches(context.get("building", {}), condition) and _unit_matches(context.get("unit", {}), condition)
		"unit_recruited":
			return _unit_matches(context.get("unit", {}), condition) and _get_unit_recruit_count(player, condition) >= _condition_target(condition)
		"unit_count":
			return _count_units(player, condition) >= int(condition.get("count", 1))
		"kill":
			var target: String = str(condition.get("target", ""))
			var context_target: String = str(context.get("target", ""))
			if target != "any" and context_target != target:
				return false
			return _get_kill_count(player, target) >= _condition_target(condition)
		"resource_stock":
			if _resource_tracker == null:
				return false
			var key: String = str(condition.get("key", ""))
			return _resource_tracker.get_resource(player, key) >= int(condition.get("amount", 1))
		"resource_any_stock":
			if _resource_tracker == null:
				return false
			for key in condition.get("keys", []):
				if _resource_tracker.get_resource(player, str(key)) >= int(condition.get("amount", 1)):
					return true
			return false
	return false


func _condition_current(player: int, condition: Dictionary) -> int:
	var kind: String = str(condition.get("kind", ""))
	match kind:
		"building":
			return _count_buildings(player, condition)
		"building_count":
			return _count_buildings(player, condition)
		"building_garrison":
			return _count_garrisoned_buildings(player, condition)
		"unit_recruited":
			return _get_unit_recruit_count(player, condition)
		"unit_count":
			return _count_units(player, condition)
		"kill":
			return _get_kill_count(player, str(condition.get("target", "")))
		"resource_stock":
			if _resource_tracker == null:
				return 0
			return int(_resource_tracker.get_resource(player, str(condition.get("key", ""))))
		"resource_any_stock":
			return _resource_any_current(player, condition)
	return 0


func _condition_target(condition: Dictionary) -> int:
	if condition.has("amount"):
		return int(condition["amount"])
	if condition.has("count"):
		return int(condition["count"])
	return 1


func _building_matches(building: Dictionary, condition: Dictionary) -> bool:
	if building.is_empty() or not building.has("data"):
		return false
	var data: BuildingData = building["data"]
	if condition.has("category") and data.category != int(condition["category"]):
		return false
	if condition.has("tag") and not (str(condition["tag"]) in data.tags):
		return false
	if condition.has("production_key") and not data.production.has(str(condition["production_key"])):
		return false
	if condition.has("civilization") and data.civilization_tag != str(condition["civilization"]):
		return false
	if condition.has("special"):
		var special: String = str(condition["special"])
		if special == "mint" and not BuildingRules.is_mint(data):
			return false
		if special == "gold_shaft" and not data.needs_resource_point:
			return false
	return true


func _unit_matches(unit: Dictionary, condition: Dictionary) -> bool:
	if unit.is_empty() or not unit.has("data"):
		return false
	var data: UnitData = unit["data"]
	if bool(condition.get("worker", false)) and data.category != UnitData.UnitCategory.WORKER:
		return false
	if bool(condition.get("combat", false)) and data.atk <= 0:
		return false
	if condition.has("category") and data.category != int(condition["category"]):
		return false
	return true


func _count_buildings(player: int, condition: Dictionary) -> int:
	if _building_manager == null or not _building_manager.has_method("get_all_buildings"):
		return 0
	var count := 0
	for building in _building_manager.get_all_buildings():
		var b: Dictionary = building
		if int(b.get("faction", -1)) != player:
			continue
		if _building_matches(b, condition):
			count += 1
	return count


func _count_units(player: int, condition: Dictionary) -> int:
	if _unit_manager == null or not _unit_manager.has_method("get_all_units"):
		return 0
	var count := 0
	for unit in _unit_manager.get_all_units():
		var u: Dictionary = unit
		if int(u.get("faction", -1)) != player:
			continue
		if _unit_matches(u, condition):
			count += 1
	return count


func _count_garrisoned_buildings(player: int, condition: Dictionary) -> int:
	if _building_manager == null or not _building_manager.has_method("get_all_buildings"):
		return 0
	var count := 0
	for building in _building_manager.get_all_buildings():
		var b: Dictionary = building
		if int(b.get("faction", -1)) != player:
			continue
		if not _building_matches(b, condition):
			continue
		var garrison: Array = b.get("garrison", [])
		for unit in garrison:
			var unit_dict: Dictionary = unit
			if _unit_matches(unit_dict, condition):
				count += 1
				break
	return count


func _resource_any_current(player: int, condition: Dictionary) -> int:
	if _resource_tracker == null:
		return 0
	var best := 0
	for key in condition.get("keys", []):
		best = maxi(best, int(_resource_tracker.get_resource(player, str(key))))
	return best


func _register_unit_recruit_progress(player: int, unit: Dictionary) -> void:
	_increment_event_count(player, "unit_recruited.any")
	if _unit_matches(unit, {"combat": true}):
		_increment_event_count(player, "unit_recruited.combat")
	if _unit_matches(unit, {"worker": true}):
		_increment_event_count(player, "unit_recruited.worker")


func _get_unit_recruit_count(player: int, condition: Dictionary) -> int:
	if bool(condition.get("combat", false)):
		return _get_event_count(player, "unit_recruited.combat")
	if bool(condition.get("worker", false)):
		return _get_event_count(player, "unit_recruited.worker")
	return _get_event_count(player, "unit_recruited.any")


func _get_kill_count(player: int, target: String) -> int:
	if target.is_empty():
		target = "any"
	if target == "any":
		return _get_event_count(player, "kill.any")
	return _get_event_count(player, "kill.%s" % target)


func _increment_event_count(player: int, key: String) -> void:
	if player < 0 or player >= _event_counts.size():
		return
	var counts: Dictionary = _event_counts[player]
	counts[key] = int(counts.get(key, 0)) + 1
	_event_counts[player] = counts


func _get_event_count(player: int, key: String) -> int:
	if player < 0 or player >= _event_counts.size():
		return 0
	var counts: Dictionary = _event_counts[player]
	return int(counts.get(key, 0))


func _complete(player: int, definition: Dictionary) -> void:
	var id: String = str(definition["id"])
	_completed[player][id] = true
	var reward: Dictionary = definition.get("reward", {})
	var tech_points: int = int(reward.get("tech_points", 0))
	if tech_points > 0:
		_tech_points[player] += tech_points
		tech_points_changed.emit(player, _tech_points[player])
	if _resource_tracker != null:
		var resources: Dictionary = reward.get("resources", {})
		for key in resources:
			_resource_tracker.add_resource(player, str(key), int(resources[key]))
	achievement_completed.emit(player, id, str(definition["title"]))
	achievement_state_changed.emit(player)
	print("[Achievement] P%d completed %s." % [player, id])
