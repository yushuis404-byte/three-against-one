class_name RecruitmentService
extends RefCounted
## Recruitment queue rules for recruit-capable buildings.

const QUEUE_CAPACITY := 3
const SPAWN_SEARCH_RADIUS := 8

var buildings: Array = []
var building_grid: Array = []
var grid_cols := 100
var grid_rows := 56
var template_registry: Node = null
var resource_tracker: Node = null
var turn_manager: Node = null
var unit_manager: Node = null
var technology_service: Node = null
var last_spawned_units: Array = []
var _last_spawned_unit_id := -1


func setup(
		p_buildings: Array,
		p_building_grid: Array,
		p_grid_cols: int,
		p_grid_rows: int,
		p_template_registry: Node,
		p_resource_tracker: Node,
		p_turn_manager: Node,
		p_unit_manager: Node) -> void:
	buildings = p_buildings
	building_grid = p_building_grid
	grid_cols = p_grid_cols
	grid_rows = p_grid_rows
	template_registry = p_template_registry
	resource_tracker = p_resource_tracker
	turn_manager = p_turn_manager
	unit_manager = p_unit_manager


func set_technology_service(service: Node) -> void:
	technology_service = service


func request_recruitment(building_id: int, unit_template_id: String, count: int) -> bool:
	var building: Dictionary = get_building_by_id(building_id)
	if not is_recruit_building(building):
		return false
	var faction: int = turn_manager.current_player if turn_manager else -1
	if faction < 0 or building["faction"] != faction:
		return false
	var unit_template: Resource = get_recruit_unit_template(unit_template_id)
	if unit_template == null:
		return false
	if not building_can_recruit(building, unit_template_id):
		return false

	var safe_count: int = clampi(count, 1, QUEUE_CAPACITY)
	var queue: Array = building.get("recruit_queue", [])
	if queue.size() + safe_count > QUEUE_CAPACITY:
		print("[Recruit] Queue is full.")
		return false

	var cost: Dictionary = get_unit_recruit_cost(unit_template, faction)
	for key in cost:
		var need: int = int(cost[key]) * safe_count
		if resource_tracker and resource_tracker.get_resource(faction, key) < need:
			print("[Recruit] Not enough %s." % key)
			return false

	var ap_cost: int = get_unit_recruit_ap_cost(unit_template, faction) * safe_count
	if turn_manager and turn_manager.get_ap(faction) < ap_cost:
		print("[Recruit] Not enough AP.")
		return false

	if resource_tracker:
		for key in cost:
			resource_tracker.spend_resource(faction, key, int(cost[key]) * safe_count)
	if turn_manager:
		turn_manager.spend_ap(faction, ap_cost)

	var turns: int = get_unit_recruit_turns(unit_template, faction)
	for i in range(safe_count):
		queue.append({
			"unit_template_id": unit_template_id,
			"unit_name": str(unit_template.get("display_name")),
			"remaining_turns": turns,
			"total_turns": turns,
		})
	building["recruit_queue"] = queue
	print("[Recruit] Added %d x %s to queue." % [safe_count, unit_template_id])
	return true


func process_recruit_queues(player: int) -> Array:
	var changed: Array = []
	last_spawned_units.clear()
	for building in buildings:
		if building["faction"] != player:
			continue
		var queue: Array = building.get("recruit_queue", [])
		if queue.is_empty():
			continue

		for item in queue:
			var remaining: int = int(item.get("remaining_turns", 0))
			if remaining > 0:
				item["remaining_turns"] = remaining - 1

		var i := 0
		while i < queue.size():
			var item: Dictionary = queue[i]
			if int(item.get("remaining_turns", 0)) <= 0:
				var unit_template_id: String = str(item.get("unit_template_id", ""))
				var spawned: bool = spawn_recruited_unit(building, unit_template_id)
				if spawned:
					last_spawned_units.append({
						"building": building,
						"unit_template_id": unit_template_id,
						"unit_id": _last_spawned_unit_id,
					})
					queue.remove_at(i)
					continue
			i += 1

		building["recruit_queue"] = queue
		changed.append(building)
	return changed


func consume_last_spawned_units() -> Array:
	var result: Array = last_spawned_units.duplicate()
	last_spawned_units.clear()
	return result


func get_recruit_queue(building_id: int) -> Array:
	var building: Dictionary = get_building_by_id(building_id)
	if building.is_empty():
		return []
	return building.get("recruit_queue", []).duplicate(true)


func get_recruit_options(building: Dictionary) -> Array:
	if not is_recruit_building(building):
		return []
	var result: Array = []
	var template_ids: Array = get_recruit_template_ids_for_building(building)
	for template_id in template_ids:
		var unit_template: Resource = get_recruit_unit_template(template_id)
		if unit_template == null:
			continue
		result.append({
			"id": template_id,
			"name": str(unit_template.get("display_name")),
			"cost": get_unit_recruit_cost(unit_template, int(building.get("faction", -1))),
			"ap_cost": get_unit_recruit_ap_cost(unit_template, int(building.get("faction", -1))),
			"turns": get_unit_recruit_turns(unit_template, int(building.get("faction", -1))),
			"move": int(unit_template.get("move_max")),
			"atk": int(unit_template.get("atk")),
			"hp": int(unit_template.get("hp_max")),
			"vision": int(unit_template.get("vision")),
			"attack_range": int(unit_template.get("attack_range")),
			"attack_interval": float(unit_template.get("attack_interval")),
			"damage_reduction": int(unit_template.get("damage_reduction")),
			"food_cost": int(unit_template.get("food_cost")),
			"role": int(unit_template.get("role")),
			"tags": unit_template.get("tags").duplicate(),
			"can_gather": bool(unit_template.get("can_gather")),
			"can_garrison": bool(unit_template.get("can_garrison")),
			"can_attack_units": bool(unit_template.get("can_attack_units")),
			"can_attack_buildings": bool(unit_template.get("can_attack_buildings")),
		})
	return result


func get_recruit_template_ids_for_building(building: Dictionary) -> Array:
	var faction_ids: Array = get_faction_recruit_template_ids(building)
	if not faction_ids.is_empty():
		return faction_ids

	var building_template: Resource = get_building_template_for_data(building["data"])
	if building_template != null:
		var recruit_options: Array = building_template.get("recruit_options")
		if not recruit_options.is_empty():
			var template_ids: Array = []
			for unit_template in recruit_options:
				if unit_template == null:
					continue
				var template_id := str(unit_template.get("id"))
				if not template_id.is_empty():
					template_ids.append(template_id)
			if not template_ids.is_empty():
				return template_ids

	var data: BuildingData = building["data"]
	if "recruit_camp" in data.tags:
		return ["unit.worker", "unit.guard", "unit.scout"]
	return []


func get_faction_recruit_template_ids(building: Dictionary) -> Array:
	if building.is_empty() or not building.has("data"):
		return []
	var data: BuildingData = building["data"]
	var faction: int = int(building.get("faction", -1))
	return BuildingRules.get_faction_recruit_template_ids(data, faction)


func get_building_template_for_data(data: BuildingData) -> Resource:
	if data == null or not template_registry or not template_registry.has_method("get_building"):
		return null
	var template_id := BuildingRules.get_building_template_id(data)
	if template_id.is_empty():
		return null
	return template_registry.call("get_building", template_id)


func building_can_recruit(building: Dictionary, unit_template_id: String) -> bool:
	return unit_template_id in get_recruit_template_ids_for_building(building)


func get_recruit_unit_template(unit_template_id: String) -> Resource:
	if template_registry and template_registry.has_method("get_unit"):
		return template_registry.call("get_unit", unit_template_id)
	return null


func get_unit_recruit_cost(unit_template: Resource, faction: int = -1) -> Dictionary:
	var result: Dictionary = {}
	if unit_template == null:
		return result
	var items: Array = unit_template.get("recruit_cost")
	for item in items:
		if item == null:
			continue
		var key: String = str(item.get("key"))
		var amount: int = int(item.get("amount"))
		if key.is_empty() or amount == 0:
			continue
		result[key] = int(result.get(key, 0)) + amount
	var food_discount: int = _get_technology_modifier(faction, "recruit_food_discount")
	if food_discount > 0 and result.has("food"):
		result["food"] = maxi(0, int(result["food"]) - food_discount)
	return result


func get_unit_recruit_ap_cost(unit_template: Resource, faction: int = -1) -> int:
	if unit_template == null:
		return 0
	var ap_cost: int = int(unit_template.get("recruit_ap_cost"))
	if ap_cost <= 0:
		ap_cost = int(unit_template.get("recruit_ap"))
	ap_cost -= _get_technology_modifier(faction, "first_recruit_ap_discount")
	return maxi(0, ap_cost)


func get_unit_recruit_turns(unit_template: Resource, faction: int = -1) -> int:
	if unit_template == null:
		return 1
	var turns: int = maxi(1, int(unit_template.get("recruit_turns")))
	turns -= _get_technology_modifier(faction, "recruit_turn_discount")
	return maxi(1, turns)


func is_recruit_building(building: Dictionary) -> bool:
	if building.is_empty():
		return false
	var data: BuildingData = building["data"]
	return "recruit" in data.tags


func spawn_recruited_unit(building: Dictionary, unit_template_id: String) -> bool:
	_last_spawned_unit_id = -1
	var unit_template: Resource = get_recruit_unit_template(unit_template_id)
	if unit_template == null:
		return false
	var spawn_pos: Vector2i = find_nearest_spawn_pos(building)
	if spawn_pos.x < 0:
		print("[Recruit] No valid spawn tile near recruit building; completed unit waits.")
		return false
	if unit_manager and unit_manager.has_method("add_unit_from_template"):
		var unit_id: int = unit_manager.add_unit_from_template(building["faction"], unit_template, spawn_pos)
		if unit_id < 0:
			print("[Recruit] Unit manager rejected spawn at %s; completed unit waits." % str(spawn_pos))
			return false
		_last_spawned_unit_id = unit_id
		print("[Recruit] Spawned %s at %s." % [unit_template_id, str(spawn_pos)])
		return true
	return false


func find_nearest_spawn_pos(building: Dictionary) -> Vector2i:
	if building.is_empty() or not building.has("origin") or not building.has("data"):
		return Vector2i(-1, -1)
	var origin: Vector2i = building["origin"]
	var fp: Vector2i = building["data"].footprint
	for radius in range(1, SPAWN_SEARCH_RADIUS + 1):
		var candidates: Array[Vector2i] = _get_spawn_ring_candidates(origin, fp, radius)
		for candidate in candidates:
			if _is_valid_spawn_tile(candidate):
				return candidate
	return Vector2i(-1, -1)


func _get_spawn_ring_candidates(origin: Vector2i, footprint: Vector2i, radius: int) -> Array[Vector2i]:
	var result: Array[Vector2i] = []
	var left: int = origin.x - radius
	var right: int = origin.x + footprint.x - 1 + radius
	var top: int = origin.y - radius
	var bottom: int = origin.y + footprint.y - 1 + radius
	for x in range(left, right + 1):
		result.append(Vector2i(x, top))
		if bottom != top:
			result.append(Vector2i(x, bottom))
	for y in range(top + 1, bottom):
		result.append(Vector2i(left, y))
		if right != left:
			result.append(Vector2i(right, y))
	return result


func find_empty_adjacent_pos(building: Dictionary) -> Vector2i:
	return find_nearest_spawn_pos(building)


func _is_valid_spawn_tile(pos: Vector2i) -> bool:
	if not in_bounds(pos.x, pos.y):
		return false
	if building_grid[pos.y][pos.x] >= 0:
		return false
	if not _is_passable_tile(pos):
		return false
	if _has_resource_at(pos):
		return false
	if unit_manager and unit_manager.has_method("get_unit_at"):
		var unit: Dictionary = unit_manager.get_unit_at(pos)
		if not unit.is_empty():
			return false
	if _has_neutral_unit_at(pos):
		return false
	return true


func _is_passable_tile(pos: Vector2i) -> bool:
	if unit_manager == null or not unit_manager.is_inside_tree():
		return true
	var grid_manager: Node = unit_manager.get_parent().get_node_or_null("GridManager2D")
	if grid_manager == null or not grid_manager.has_method("get_terrain_at"):
		return true
	var terrain: int = int(grid_manager.call("get_terrain_at", pos.x, pos.y))
	return TerrainData.is_passable(terrain)


func _has_resource_at(pos: Vector2i) -> bool:
	if unit_manager == null or not unit_manager.is_inside_tree():
		return false
	var resource_manager: Node = unit_manager.get_parent().get_node_or_null("ResourceManager2D")
	if resource_manager == null or not resource_manager.has_method("get_resource_type"):
		return false
	return int(resource_manager.call("get_resource_type", pos.x, pos.y)) != 0


func _has_neutral_unit_at(pos: Vector2i) -> bool:
	if unit_manager == null or not unit_manager.is_inside_tree():
		return false
	var neutral_manager: Node = unit_manager.get_parent().get_node_or_null("NeutralUnitManager2D")
	if neutral_manager == null or not neutral_manager.has_method("get_neutral_unit_at"):
		return false
	var neutral: Dictionary = neutral_manager.call("get_neutral_unit_at", pos)
	return not neutral.is_empty()


func get_building_by_id(building_id: int) -> Dictionary:
	for building in buildings:
		if building["id"] == building_id:
			return building
	return {}


func in_bounds(gx: int, gy: int) -> bool:
	return gx >= 0 and gx < grid_cols and gy >= 0 and gy < grid_rows


func _get_technology_modifier(faction: int, key: String) -> int:
	if faction < 0:
		return 0
	if technology_service == null and unit_manager != null and unit_manager.is_inside_tree():
		technology_service = unit_manager.get_parent().get_node_or_null("TechnologyService")
	if technology_service != null and technology_service.has_method("get_modifier"):
		return int(technology_service.call("get_modifier", faction, key, 0))
	return 0
