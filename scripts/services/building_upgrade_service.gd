class_name BuildingUpgradeService
extends RefCounted

var buildings: Array = []
var resource_tracker: Node = null
var turn_manager: Node = null
var technology_service: Node = null


func setup(p_buildings: Array, p_resource_tracker: Node, p_turn_manager: Node) -> void:
	buildings = p_buildings
	resource_tracker = p_resource_tracker
	turn_manager = p_turn_manager


func set_technology_service(service: Node) -> void:
	technology_service = service


func get_upgrade_info(building_id: int) -> Dictionary:
	var building: Dictionary = get_building_by_id(building_id)
	if building.is_empty():
		return {"can_upgrade": false, "reason": "building_not_found"}
	var data: BuildingData = building["data"]
	var current_level: int = int(building.get("level", 1))
	var next_level: int = current_level + 1
	if data.upgrade_rules.is_empty() or next_level > data.max_level:
		return {"can_upgrade": false, "reason": "max_level", "level": current_level}
	if not data.upgrade_rules.has(next_level):
		return {"can_upgrade": false, "reason": "missing_rule", "level": current_level}

	var rule: Dictionary = data.upgrade_rules[next_level]
	var faction: int = int(building.get("faction", -1))
	if bool(rule.get("requires_garrison_worker", false)) and not has_garrison_worker(building):
		return {
			"can_upgrade": false,
			"reason": "requires_worker",
			"level": current_level,
			"next_level": next_level,
			"cost": rule.get("cost", {}),
		}

	var cost: Dictionary = rule.get("cost", {})
	var ap_cost: int = _get_upgrade_ap_cost(faction)
	if turn_manager and turn_manager.has_method("get_ap") and turn_manager.get_ap(faction) < ap_cost:
		return {
			"can_upgrade": false,
			"reason": "not_enough_ap",
			"level": current_level,
			"next_level": next_level,
			"cost": cost,
			"ap_cost": ap_cost,
		}
	for key in cost:
		var need: int = int(cost[key])
		if resource_tracker and resource_tracker.get_resource(faction, str(key)) < need:
			return {
				"can_upgrade": false,
				"reason": "not_enough_resource",
				"missing": str(key),
				"level": current_level,
				"next_level": next_level,
				"cost": cost,
				"ap_cost": ap_cost,
			}

	return {
		"can_upgrade": true,
		"reason": "",
		"level": current_level,
		"next_level": next_level,
		"cost": cost,
		"ap_cost": ap_cost,
	}


func upgrade(building_id: int) -> bool:
	var info: Dictionary = get_upgrade_info(building_id)
	if not bool(info.get("can_upgrade", false)):
		print("[Upgrade] Failed: %s" % str(info.get("reason", "")))
		return false
	var building: Dictionary = get_building_by_id(building_id)
	if building.is_empty():
		return false
	var faction: int = int(building.get("faction", -1))
	var cost: Dictionary = info.get("cost", {})
	if resource_tracker:
		for key in cost:
			resource_tracker.spend_resource(faction, str(key), int(cost[key]))
	var ap_cost: int = int(info.get("ap_cost", 0))
	if turn_manager and ap_cost > 0:
		turn_manager.spend_ap(faction, ap_cost)
	building["level"] = int(info.get("next_level", int(building.get("level", 1)) + 1))
	print("[Upgrade] Building %d upgraded to Lv%d." % [building_id, int(building["level"])])
	return true


func has_garrison_worker(building: Dictionary) -> bool:
	var garrison: Array = building.get("garrison", [])
	for unit in garrison:
		var unit_dict: Dictionary = unit
		if unit_dict.has("data"):
			var data: UnitData = unit_dict["data"]
			if data.category == UnitData.UnitCategory.WORKER:
				return true
	return false


func get_building_by_id(building_id: int) -> Dictionary:
	for building in buildings:
		if int(building.get("id", -1)) == building_id:
			return building
	return {}


func _get_upgrade_ap_cost(faction: int) -> int:
	var base_cost := 1
	var discount := 0
	if technology_service != null and technology_service.has_method("get_modifier"):
		discount = int(technology_service.call("get_modifier", faction, "building_upgrade_ap_discount", 0))
	return maxi(0, base_cost - discount)
