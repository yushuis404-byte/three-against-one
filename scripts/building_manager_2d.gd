extends Node2D
## 建筑管理器 - 放置、绘制、回合产出、交互
##
## 使用 building_grid[y][x] 记录每格所属 building_id（多格建筑多格同 id）
## 绘制在迷雾之下但领土之上，单位之下

const GarrisonServiceScript := preload("res://scripts/services/garrison_service.gd")
const RecruitmentServiceScript := preload("res://scripts/services/recruitment_service.gd")
const BuildingUpgradeServiceScript := preload("res://scripts/services/building_upgrade_service.gd")
const BuildingNetworkServiceScript := preload("res://scripts/services/building_network_service.gd")
const ELF_CAPITAL_TEXTURE: Texture2D = preload("res://assets/texture/Elven Capital.png")
const DWARF_CAPITAL_TEXTURE: Texture2D = preload("res://assets/texture/Dwarf Capital.png")
const ORC_CAPITAL_TEXTURE: Texture2D = preload("res://assets/texture/Orc Capital.png")
const BUILDING_TEXTURE_FIT_CONFIG_PATH := "res://data/building_texture_fit.json"

var grid_cols := 100
var grid_rows := 56
var tile_size := 32.0
var grid_center := Vector2(49.5, 27.5)

var building_grid: Array = []         # [y][x] -> building_id 或 -1
var _buildings: Array = []            # Array[Dictionary]
var _next_id := 1
var _selected_id := -1
var _hovered_id := -1
var _demolition_control_building_id := -1

var _grid_manager: Node = null
var _turn_manager: Node = null
var _network_game_service: Node = null
var _territory_mgr: Node = null
var _fog_mgr: Node = null
var _resource_mgr: Node = null
var _template_registry: Node = null
var _technology_service: Node = null
var _civilization_rules: Node = null
var _garrison_service = GarrisonServiceScript.new()
var _recruitment_service = RecruitmentServiceScript.new()
var _upgrade_service = BuildingUpgradeServiceScript.new()
var _building_network_service = BuildingNetworkServiceScript.new()

var _just_garrisoned: Dictionary = {}  # building_id -> true，本帧刚驻兵
var _tower_cooldowns: Dictionary = {}
var _building_texture_fit_config: Dictionary = {}
var _building_texture_cache: Dictionary = {}

# 放置模式
var _placement_active := false
var _placement_data: BuildingData = null
var _placement_faction := -1
var _placement_hover_pos: Vector2i = Vector2i(-1, -1)
var _placement_valid := false
var _resource_tracker: Node = null

signal building_hovered(text: String)
signal placement_canceled()
signal recruit_panel_requested(building_id: int, building_name: String, options: Array, queue: Array)
signal recruit_panel_closed()
signal recruit_queue_changed(building_id: int, queue: Array)
signal building_placed(player: int, building: Dictionary)
signal building_upgraded(player: int, building: Dictionary, level: int)
signal building_garrisoned(player: int, building: Dictionary, unit: Dictionary)
signal unit_recruited(player: int, unit: Dictionary, unit_template_id: String)

const BUILDING_ALPHA := 0.85
const SELECT_COLOR := Color(1.0, 1.0, 1.0, 0.6)
const EFFECT_RANGE_COLOR := Color(0.35, 0.75, 1.0, 0.18)
const EFFECT_RANGE_BORDER_COLOR := Color(0.6, 0.9, 1.0, 0.35)
const NETWORK_RANGE_COLOR := Color(0.95, 0.72, 0.28, 0.14)
const NETWORK_RANGE_BORDER_COLOR := Color(1.0, 0.85, 0.42, 0.35)
const NETWORK_LINK_COLOR := Color(1.0, 0.82, 0.28, 0.75)
const ELF_CAPITAL_TEXTURE_SCALE := 0.87
const DWARF_CAPITAL_TEXTURE_SCALE := 1.0
const ORC_CAPITAL_TEXTURE_SCALE := 1.0
const REPAIR_AP_COST := 1
const REPAIR_STONE_COST := 1
const BASE_REPAIR_AMOUNT := 2
const DEMOLISH_OVERLAY_COLOR := Color(1.0, 0.05, 0.02, 0.32)
const DEMOLISH_BORDER_COLOR := Color(1.0, 0.18, 0.12, 0.9)
const DEMOLISH_ICON_SIZE := 20.0
const DEMOLISH_CONTROL_SIZE := 14.0
const DEMOLITION_REFUND_RATE := 0.5


func _ready() -> void:
	_init_grid()
	_load_building_texture_fit_config()
	_grid_manager = get_parent().get_node("GridManager2D")
	_territory_mgr = get_parent().get_node("TerritoryManager2D")
	_fog_mgr = get_parent().get_node("FogOfWar2D")
	_resource_mgr = get_parent().get_node("ResourceManager2D")
	_template_registry = get_parent().get_node_or_null("TemplateRegistry")
	_technology_service = get_parent().get_node_or_null("TechnologyService")
	_configure_services()


func _init_grid() -> void:
	building_grid = []
	for y in range(grid_rows):
		var row: Array = []
		for x in range(grid_cols):
			row.append(-1)
		building_grid.append(row)


func set_turn_manager(tm: Node) -> void:
	_turn_manager = tm
	if tm:
		tm.player_turn_started.connect(_on_player_turn_started)
		tm.round_ended.connect(_on_round_ended)
	_configure_services()


func set_network_game_service(service: Node) -> void:
	_network_game_service = service


func _is_network_game() -> bool:
	return _network_game_service != null and _network_game_service.has_method("is_network_game") and bool(_network_game_service.call("is_network_game"))


func _make_building_key(data: BuildingData) -> Dictionary:
	if data == null:
		return {}
	return {
		"name": data.name,
		"category": int(data.category),
	}


func _find_building_template_from_key(key: Dictionary) -> BuildingData:
	var name := str(key.get("name", ""))
	var category := int(key.get("category", -1))
	var templates_by_category: Dictionary = BuildingData.get_templates()
	if category >= 0 and templates_by_category.has(category):
		for data_variant in templates_by_category[category]:
			var data: BuildingData = data_variant
			if data.name == name:
				return data
	for category_key in templates_by_category:
		for data_variant in templates_by_category[category_key]:
			var data: BuildingData = data_variant
			if data.name == name:
				return data
	return null


func _request_network_build(data: BuildingData, faction: int, pos: Vector2i) -> bool:
	if not _is_network_game():
		return false
	if _network_game_service.has_method("request_action"):
		_network_game_service.call("request_action", "build_place", {
			"building": _make_building_key(data),
			"x": pos.x,
			"y": pos.y,
			"faction": faction,
		})
		return true
	return false


func _request_network_recruit(building_id: int, unit_template_id: String, count: int) -> bool:
	if not _is_network_game():
		return false
	if _network_game_service.has_method("request_action"):
		_network_game_service.call("request_action", "recruit", {
			"building_id": building_id,
			"unit_template_id": unit_template_id,
			"count": count,
		})
		return true
	return false


func request_network_build(player: int, building_key: Dictionary, pos: Vector2i) -> bool:
	if _turn_manager == null or not _turn_manager.has_method("can_player_act"):
		return false
	if not bool(_turn_manager.call("can_player_act", player)):
		return false
	var data := _find_building_template_from_key(building_key)
	if data == null:
		return false
	var previous_player := int(_turn_manager.current_player)
	_turn_manager.current_player = player
	var ok := _check_build_payment_available(data, player)
	if ok:
		ok = _can_place(data, player, pos)
	if ok:
		_spend_building_cost(data, player)
		if _turn_manager != null:
			ok = _turn_manager.spend_ap(player, 2)
	if ok:
		ok = place_building(data, player, pos)
	_turn_manager.current_player = previous_player
	if ok:
		queue_redraw()
	return ok


func request_network_recruit(player: int, building_id: int, unit_template_id: String, count: int) -> bool:
	if _turn_manager == null or not _turn_manager.has_method("can_player_act"):
		return false
	if not bool(_turn_manager.call("can_player_act", player)):
		return false
	var building: Dictionary = _get_building_by_id(building_id)
	if building.is_empty() or int(building.get("faction", -1)) != player:
		return false
	var previous_player := int(_turn_manager.current_player)
	_turn_manager.current_player = player
	var ok: bool = _request_recruitment_local(building_id, unit_template_id, count)
	_turn_manager.current_player = previous_player
	return ok


func set_resource_tracker(rt: Node) -> void:
	_resource_tracker = rt
	_configure_services()


func _configure_services() -> void:
	if _recruitment_service == null:
		return
	var unit_mgr = null
	if is_inside_tree():
		unit_mgr = get_parent().get_node_or_null("UnitManager2D")
	_recruitment_service.setup(
		_buildings,
		building_grid,
		grid_cols,
		grid_rows,
		_template_registry,
		_resource_tracker,
		_turn_manager,
		unit_mgr
	)
	if _upgrade_service:
		_upgrade_service.setup(_buildings, _resource_tracker, _turn_manager)
	if _technology_service == null and is_inside_tree():
		_technology_service = get_parent().get_node_or_null("TechnologyService")
	if _technology_service != null:
		if _recruitment_service != null and _recruitment_service.has_method("set_technology_service"):
			_recruitment_service.set_technology_service(_technology_service)
		if _upgrade_service != null and _upgrade_service.has_method("set_technology_service"):
			_upgrade_service.set_technology_service(_technology_service)


func set_technology_service(service: Node) -> void:
	_technology_service = service
	_configure_services()


func set_civilization_rules(rules: Node) -> void:
	_civilization_rules = rules
	if _civilization_rules != null and _civilization_rules.has_signal("route_changed"):
		var callback := Callable(self, "_on_civilization_route_changed")
		if not _civilization_rules.route_changed.is_connected(callback):
			_civilization_rules.route_changed.connect(_on_civilization_route_changed)
	queue_redraw()


func _on_civilization_route_changed(_player: int) -> void:
	queue_redraw()


func _on_player_turn_started(player: int) -> void:
	_reveal_town_hall_vision(player)
	_reveal_watch_tower_vision(player)
	_process_recruit_queues(player)
	_process_pending_demolitions(player)
	_process_garrison_repairs(player)
	queue_redraw()


func _process(_delta: float) -> void:
	_just_garrisoned.clear()
	_process_defense_towers(_delta)


func reveal_all_town_hall_vision() -> void:
	## 游戏开始时揭示所有主城的视野
	for p in range(3):
		_reveal_town_hall_vision(p)


func _reveal_town_hall_vision(player: int) -> void:
	## 揭示该玩家所有主城周围的迷雾（视野半径 4）
	if not _fog_mgr or not _fog_mgr.has_method("reveal_area"):
		return
	for b in _buildings:
		if b["faction"] == player:
			var data: BuildingData = b["data"]
			if data.category == BuildingData.BuildingCategory.CORE:
				var origin: Vector2i = b["origin"]
				var fp: Vector2i = data.footprint
				var cx: int = origin.x + fp.x / 2
				var cy: int = origin.y + fp.y / 2
				_fog_mgr.reveal_area(player, cx, cy, 4)


func _reveal_watch_tower_vision(player: int) -> void:
	if not _fog_mgr or not _fog_mgr.has_method("reveal_area"):
		return
	for b in _buildings:
		if int(b.get("faction", -1)) != player:
			continue
		var data: BuildingData = b["data"]
		if BuildingRules.is_watch_tower(data):
			var center: Vector2i = _get_building_center(b)
			_fog_mgr.reveal_area(player, center.x, center.y, 5)


# ========== Building 鏁版嵁 API ==========

func place_building(data: BuildingData, faction: int, origin: Vector2i) -> bool:
	## 在 origin（建筑左上角原点）放置建筑，成功返回 true
	if not _can_place(data, faction, origin):
		return false

	var bid := _next_id
	_next_id += 1

	var tiles := _get_footprint_tiles(origin, data.footprint)
	for t in tiles:
		building_grid[t.y][t.x] = bid

	var hp_max: int = _get_effective_building_hp_max(data, faction)
	_buildings.append({
		"id": bid,
		"data": data,
		"faction": faction,
		"origin": origin,
		"hp": hp_max,
		"hp_max": hp_max,
		"base_hp_max": data.hp_max,
		"level": maxi(1, data.storage_level),
		"pending_demolition": false,
		"garrison": [],
		"recruit_queue": [],
	})

	if BuildingRules.is_outpost(data) and _territory_mgr:
		var source := Vector2i(origin.x + data.footprint.x / 2, origin.y + data.footprint.y / 2)
		if _territory_mgr.has_method("add_town_hall"):
			_territory_mgr.add_town_hall(faction, source)

	# 放置建筑时揭示该阵营对应区域的迷雾
	if _fog_mgr and _fog_mgr.has_method("reveal_area_immediate"):
		var fp: Vector2i = data.footprint
		var center_x: int = origin.x + fp.x / 2
		var center_y: int = origin.y + fp.y / 2
		var reveal_radius: int = 5 if BuildingRules.is_watch_tower(data) else 3
		_fog_mgr.reveal_area_immediate(faction, center_x, center_y, reveal_radius)

	if BuildingRules.is_outpost(data) and _territory_mgr and _territory_mgr.has_method("recalc_territory"):
		_territory_mgr.recalc_territory(faction)

	if data.storage_level > 0 and _resource_tracker and _resource_tracker.has_method("update_display"):
		_resource_tracker.update_display(faction)

	# 金矿矿井消耗金矿资源点
	if data.needs_resource_point:
		if _resource_mgr and _resource_mgr.has_method("remove_resource"):
			_resource_mgr.remove_resource(origin.x, origin.y)

	var placed_building: Dictionary = _get_building_by_id(bid)
	if not placed_building.is_empty():
		building_placed.emit(faction, placed_building.duplicate())
	queue_redraw()
	return true


func get_building_at(grid_pos: Vector2i) -> Dictionary:
	if grid_pos.x < 0 or grid_pos.x >= grid_cols or grid_pos.y < 0 or grid_pos.y >= grid_rows:
		return {}
	var bid: int = building_grid[grid_pos.y][grid_pos.x]
	if bid < 0:
		return {}
	for b in _buildings:
		if b["id"] == bid:
			return b
	return {}


func get_building_by_id(building_id: int) -> Dictionary:
	return _get_building_by_id(building_id)


func is_tile_occupied(gx: int, gy: int) -> bool:
	if gx < 0 or gx >= grid_cols or gy < 0 or gy >= grid_rows:
		return true  # out of bounds = occupied
	return building_grid[gy][gx] >= 0


# ========== Footprint 工具 ==========

func _get_footprint_tiles(origin: Vector2i, fp: Vector2i) -> Array:
	## 返回建筑原点 + footprint 覆盖的所有 Vector2i 格子
	var result: Array = []
	for dy in range(fp.y):
		for dx in range(fp.x):
			result.append(Vector2i(origin.x + dx, origin.y + dy))
	return result


func _can_place(data: BuildingData, faction: int, origin: Vector2i) -> bool:
	## 校验所有 footprint 格是否满足放置条件
	var tiles := _get_footprint_tiles(origin, data.footprint)
	for t in tiles:
		if t.x < 0 or t.x >= grid_cols or t.y < 0 or t.y >= grid_rows:
			return false
		# 领地检查
		if _territory_mgr:
			var owner: int = _territory_mgr.get_cell_owner(t.x, t.y)
			if owner != faction:
				return false
		# 地形兼容
		if _grid_manager and _grid_manager.has_method("get_terrain_at"):
			var terrain: int = _grid_manager.get_terrain_at(t.x, t.y)
			if not (terrain in data.terrain_compatibility):
				return false
		# 格子未被占用
		if building_grid[t.y][t.x] >= 0:
			return false

	# 金矿矿井：需要金矿资源点
	if data.needs_resource_point:
		if not _resource_mgr or not _resource_mgr.has_method("get_resource_type"):
			return false
		if _resource_mgr.get_resource_type(origin.x, origin.y) != 1:
			return false

	# 阵营上限检查
	if data.storage_level > 0:
		var warehouse_count := 0
		for b in _buildings:
			var existing_data: BuildingData = b["data"]
			if b["faction"] == faction and existing_data.storage_level > 0:
				warehouse_count += 1
		if warehouse_count >= data.max_per_faction:
			return false

	if data.max_per_faction < 99:
		var count := 0
		for b in _buildings:
			if b["faction"] == faction and b["data"].name == data.name:
				count += 1
		if count >= data.max_per_faction:
			return false

	return true


func count_buildings(faction: int, name_filter: String = "") -> int:
	var count := 0
	for b in _buildings:
		if b["faction"] != faction:
			continue
		if name_filter.is_empty() or b["data"].name == name_filter:
			count += 1
	return count

func get_all_buildings() -> Array:
	return _buildings.duplicate()


func get_building_network_info(building_id: int) -> Dictionary:
	var building: Dictionary = _get_building_by_id(building_id)
	if _building_network_service == null or building.is_empty():
		return {}
	return _building_network_service.get_network_info(_buildings, building, _civilization_rules)


func get_building_network_production_bonus(building_id: int, resource_key: String) -> int:
	var building: Dictionary = _get_building_by_id(building_id)
	if _building_network_service == null or building.is_empty():
		return 0
	return _building_network_service.get_production_bonus(_buildings, building, resource_key, _civilization_rules)


func get_building_hp_max(building_id: int) -> int:
	var building: Dictionary = _get_building_by_id(building_id)
	return _get_building_hp_max_from_instance(building)


func damage_building(building_id: int, amount: int, attacker_faction: int = -1) -> Dictionary:
	var index: int = _get_building_index_by_id(building_id)
	if index < 0 or amount <= 0:
		return {"ok": false, "destroyed": false, "damage": 0}
	var building: Dictionary = _buildings[index]
	var before_hp: int = int(building.get("hp", 0))
	var damage: int = mini(amount, before_hp)
	building["hp"] = before_hp - damage
	_buildings[index] = building
	_show_building_damage_text(building, damage)
	var destroyed: bool = int(building.get("hp", 0)) <= 0
	if destroyed:
		_destroy_building_at_index(index, attacker_faction)
	else:
		queue_redraw()
	return {"ok": true, "destroyed": destroyed, "damage": damage}


func repair_building(building_id: int) -> bool:
	var index: int = _get_building_index_by_id(building_id)
	if index < 0:
		return false
	var building: Dictionary = _buildings[index]
	var faction: int = int(building.get("faction", -1))
	if _turn_manager == null or faction != _turn_manager.current_player:
		return false
	var hp_max: int = _get_building_hp_max_from_instance(building)
	var current_hp: int = int(building.get("hp", hp_max))
	if current_hp >= hp_max:
		return false
	if _resource_tracker == null or _resource_tracker.get_resource(faction, "stone") < REPAIR_STONE_COST:
		return false
	if _turn_manager.get_ap(faction) < REPAIR_AP_COST:
		return false
	_resource_tracker.spend_resource(faction, "stone", REPAIR_STONE_COST)
	_turn_manager.spend_ap(faction, REPAIR_AP_COST)
	var repair_amount: int = BASE_REPAIR_AMOUNT + _get_route_modifier_int(faction, "repair_efficiency_bonus")
	repair_amount += _get_technology_modifier_int(faction, "repair_efficiency_bonus")
	building["hp"] = mini(hp_max, current_hp + maxi(1, repair_amount))
	_buildings[index] = building
	_show_building_heal_text(building, int(building["hp"]) - current_hp)
	if _resource_tracker.has_method("update_display"):
		_resource_tracker.update_display(faction)
	queue_redraw()
	return true


func mark_building_for_demolition(building_id: int) -> bool:
	var index: int = _get_building_index_by_id(building_id)
	if index < 0:
		return false
	var building: Dictionary = _buildings[index]
	var data: BuildingData = building["data"]
	if data.category == BuildingData.BuildingCategory.CORE:
		return false
	if _turn_manager != null and int(building.get("faction", -1)) != _turn_manager.current_player:
		return false
	building["pending_demolition"] = true
	_buildings[index] = building
	queue_redraw()
	return true


func cancel_building_demolition(building_id: int) -> bool:
	var index: int = _get_building_index_by_id(building_id)
	if index < 0:
		return false
	var building: Dictionary = _buildings[index]
	if _turn_manager != null and int(building.get("faction", -1)) != _turn_manager.current_player:
		return false
	if not bool(building.get("pending_demolition", false)):
		return false
	building["pending_demolition"] = false
	_buildings[index] = building
	queue_redraw()
	return true


func _process_garrison_repairs(player: int) -> void:
	for i in range(_buildings.size()):
		var building: Dictionary = _buildings[i]
		if int(building.get("faction", -1)) != player:
			continue
		if bool(building.get("pending_demolition", false)):
			continue
		var repair_amount: int = _garrison_service.get_repair_per_round(building)
		if repair_amount <= 0:
			continue
		var hp_max: int = _get_building_hp_max_from_instance(building)
		var current_hp: int = int(building.get("hp", hp_max))
		if current_hp >= hp_max:
			continue
		building["hp"] = mini(hp_max, current_hp + repair_amount)
		_buildings[i] = building
		_show_building_heal_text(building, int(building["hp"]) - current_hp)


func _process_pending_demolitions(player: int) -> void:
	for i in range(_buildings.size() - 1, -1, -1):
		var building: Dictionary = _buildings[i]
		if int(building.get("faction", -1)) != player:
			continue
		if not bool(building.get("pending_demolition", false)):
			continue
		if not _garrison_service.has_worker_garrison(building):
			continue
		_complete_demolition_at_index(i)


func _complete_demolition_at_index(index: int) -> void:
	if index < 0 or index >= _buildings.size():
		return
	var building: Dictionary = _buildings[index]
	var faction: int = int(building.get("faction", -1))
	var refund: Dictionary = _get_demolition_refund(building)
	_refund_demolition_resources(faction, refund)
	if not refund.is_empty():
		_show_resource_text(building, refund, Color(1.0, 0.35, 0.25))
	_release_demolition_garrison(building)
	_destroy_building_at_index(index)


func _get_demolition_refund(building: Dictionary) -> Dictionary:
	var data: BuildingData = building["data"]
	var raw_costs := {
		"gold": data.cost_gold,
		"wood": data.cost_wood,
		"stone": data.cost_stone,
		"iron": data.cost_iron,
		"food": data.cost_food,
	}
	var refund: Dictionary = {}
	for key in raw_costs:
		var amount: int = int(raw_costs[key])
		if amount <= 0:
			continue
		var refund_amount: int = int(floor(float(amount) * DEMOLITION_REFUND_RATE))
		if refund_amount > 0:
			refund[str(key)] = refund_amount
	return refund


func _refund_demolition_resources(faction: int, refund: Dictionary) -> void:
	if _resource_tracker == null:
		return
	for key in refund:
		_resource_tracker.add_resource(faction, str(key), int(refund[key]))
	if _resource_tracker.has_method("update_display"):
		_resource_tracker.update_display(faction)


func _release_demolition_garrison(building: Dictionary) -> void:
	var garrison: Array = building.get("garrison", [])
	if garrison.is_empty():
		return
	var unit_mgr = get_parent().get_node_or_null("UnitManager2D")
	if unit_mgr == null or not unit_mgr.has_method("add_unit"):
		return
	var faction: int = int(building.get("faction", -1))
	var spawn_pos: Vector2i = _find_ungarrison_pos(building)
	if spawn_pos.x < 0:
		var origin: Vector2i = building["origin"]
		spawn_pos = origin
	for unit in garrison:
		var unit_dict: Dictionary = unit
		if unit_dict.is_empty() or not unit_dict.has("data"):
			continue
		unit_mgr.add_unit(faction, unit_dict["data"], spawn_pos, int(unit_dict.get("hp", -1)))


func _process_defense_towers(delta: float) -> void:
	if _buildings.is_empty():
		return
	for building in _buildings:
		var data: BuildingData = building["data"]
		if data.defense_attack_range <= 0 or data.defense_attack_damage <= 0 or data.defense_attack_cooldown <= 0.0:
			continue
		if bool(building.get("pending_demolition", false)):
			continue
		var building_id: int = int(building.get("id", -1))
		var cooldown: float = maxf(0.0, float(_tower_cooldowns.get(building_id, 0.0)) - delta)
		if cooldown > 0.0:
			_tower_cooldowns[building_id] = cooldown
			continue
		if _try_fire_defense_tower(building):
			_tower_cooldowns[building_id] = data.defense_attack_cooldown
		else:
			_tower_cooldowns[building_id] = 0.1


func _try_fire_defense_tower(building: Dictionary) -> bool:
	var target: Dictionary = _find_defense_tower_target(building)
	if target.is_empty():
		return false
	var data: BuildingData = building["data"]
	var damage: int = data.defense_attack_damage
	var faction: int = int(building.get("faction", -1))
	var target_pos: Vector2i = target.get("grid_pos", Vector2i.ZERO)
	if data.defense_attack_aoe_radius > 0:
		_apply_defense_tower_aoe(faction, target_pos, damage, data.defense_attack_aoe_radius)
	else:
		_apply_defense_tower_damage(faction, target, damage)
	_show_tower_attack_text(building, target_pos, damage)
	return true


func _find_defense_tower_target(building: Dictionary) -> Dictionary:
	var data: BuildingData = building["data"]
	var faction: int = int(building.get("faction", -1))
	var center: Vector2i = _get_building_center(building)
	var range: int = data.defense_attack_range
	var best: Dictionary = {}
	var best_distance := 999999

	var unit_mgr = get_parent().get_node_or_null("UnitManager2D")
	if unit_mgr != null and unit_mgr.has_method("get_all_units"):
		var units: Array = unit_mgr.get_all_units()
		for unit in units:
			var unit_dict: Dictionary = unit
			if int(unit_dict.get("faction", -1)) == faction:
				continue
			var pos: Vector2i = unit_dict.get("grid_pos", Vector2i.ZERO)
			var distance: int = _grid_distance(center, pos)
			if distance <= range and distance < best_distance:
				best_distance = distance
				best = {"kind": "unit", "id": int(unit_dict.get("id", -1)), "grid_pos": pos}

	var neutral_mgr = get_parent().get_node_or_null("NeutralUnitManager2D")
	if neutral_mgr != null and neutral_mgr.has_method("get_all_neutral_units"):
		var neutral_units: Array = neutral_mgr.get_all_neutral_units()
		for neutral_unit in neutral_units:
			var neutral_dict: Dictionary = neutral_unit
			var neutral_pos: Vector2i = neutral_dict.get("grid_pos", Vector2i.ZERO)
			var neutral_distance: int = _grid_distance(center, neutral_pos)
			if neutral_distance <= range and neutral_distance < best_distance:
				best_distance = neutral_distance
				best = {"kind": "neutral", "id": int(neutral_dict.get("id", -1)), "grid_pos": neutral_pos}

	return best


func _apply_defense_tower_aoe(faction: int, center: Vector2i, damage: int, radius: int) -> void:
	var unit_mgr = get_parent().get_node_or_null("UnitManager2D")
	if unit_mgr != null and unit_mgr.has_method("get_all_units"):
		var units: Array = unit_mgr.get_all_units()
		for unit in units:
			var unit_dict: Dictionary = unit
			if int(unit_dict.get("faction", -1)) == faction:
				continue
			var pos: Vector2i = unit_dict.get("grid_pos", Vector2i.ZERO)
			if _grid_distance(center, pos) <= radius:
				_apply_defense_tower_damage(faction, {"kind": "unit", "id": int(unit_dict.get("id", -1)), "grid_pos": pos}, damage)

	var neutral_mgr = get_parent().get_node_or_null("NeutralUnitManager2D")
	if neutral_mgr != null and neutral_mgr.has_method("get_all_neutral_units"):
		var neutral_units: Array = neutral_mgr.get_all_neutral_units()
		for neutral_unit in neutral_units:
			var neutral_dict: Dictionary = neutral_unit
			var neutral_pos: Vector2i = neutral_dict.get("grid_pos", Vector2i.ZERO)
			if _grid_distance(center, neutral_pos) <= radius:
				_apply_defense_tower_damage(faction, {"kind": "neutral", "id": int(neutral_dict.get("id", -1)), "grid_pos": neutral_pos}, damage)


func _apply_defense_tower_damage(faction: int, target: Dictionary, damage: int) -> void:
	var kind: String = str(target.get("kind", ""))
	var target_id: int = int(target.get("id", -1))
	if target_id < 0:
		return
	if kind == "unit":
		var unit_mgr = get_parent().get_node_or_null("UnitManager2D")
		if unit_mgr != null and unit_mgr.has_method("apply_building_damage"):
			unit_mgr.apply_building_damage(target_id, faction, damage)
	elif kind == "neutral":
		var neutral_mgr = get_parent().get_node_or_null("NeutralUnitManager2D")
		if neutral_mgr != null and neutral_mgr.has_method("apply_ranged_damage"):
			neutral_mgr.apply_ranged_damage(target_id, faction, damage)


func _show_tower_attack_text(building: Dictionary, target_pos: Vector2i, damage: int) -> void:
	var _target: Vector2 = _grid_to_world(target_pos.x, target_pos.y)
	_show_floating_text(building, "-%d" % damage, Color(1.0, 0.25, 0.12))


func _grid_distance(a: Vector2i, b: Vector2i) -> int:
	return abs(a.x - b.x) + abs(a.y - b.y)


func show_building_resource_text(building_id: int, resources: Dictionary) -> void:
	var building: Dictionary = _get_building_by_id(building_id)
	if building.is_empty() or resources.is_empty():
		return
	_show_resource_text(building, resources, Color(0.7, 0.95, 1.0))


func get_upgrade_info(building_id: int) -> Dictionary:
	return _upgrade_service.get_upgrade_info(building_id)


func upgrade_building(building_id: int) -> bool:
	var ok: bool = _upgrade_service.upgrade(building_id)
	if ok:
		var building: Dictionary = _get_building_by_id(building_id)
		if not building.is_empty() and _resource_tracker and _resource_tracker.has_method("update_display"):
			_resource_tracker.update_display(int(building.get("faction", 0)))
		if not building.is_empty():
			building_upgraded.emit(int(building.get("faction", -1)), building.duplicate(), int(building.get("level", 1)))
		queue_redraw()
	return ok


# ========== 驻兵系统 ==========

func max_garrison(building: Dictionary) -> int:
	return _garrison_service.max_garrison(building)


func can_garrison(building_id: int, faction: int, unit_category: int = -1) -> bool:
	return _garrison_service.can_garrison(_buildings, building_id, faction, unit_category)


func garrison_unit(building_id: int, unit_dict: Dictionary) -> void:
	if _garrison_service.garrison_unit(_buildings, building_id, unit_dict):
		_just_garrisoned[building_id] = true
		var building: Dictionary = _get_building_by_id(building_id)
		if not building.is_empty():
			building_garrisoned.emit(int(building.get("faction", -1)), building.duplicate(), unit_dict.duplicate())
		queue_redraw()


func ungarrison_one(building_id: int) -> Dictionary:
	var unit: Dictionary = _garrison_service.ungarrison_one(_buildings, building_id)
	if not unit.is_empty():
		queue_redraw()
	return unit


func get_garrison_bonus(building_id: int) -> Dictionary:
	return _garrison_service.get_garrison_bonus(_buildings, building_id)
func _find_ungarrison_pos(building: Dictionary) -> Vector2i:
	## 在建筑周围找第一个空位用于撤出单位
	var origin: Vector2i = building["origin"]
	var fp: Vector2i = building["data"].footprint
	var dirs := [Vector2i(-1, 0), Vector2i(1, 0), Vector2i(0, -1), Vector2i(0, 1)]
	for dy in range(fp.y):
		for dx in range(fp.x):
			for dir in dirs:
				var n: Vector2i = Vector2i(origin.x + dx, origin.y + dy) + dir
				if n.x < 0 or n.x >= grid_cols or n.y < 0 or n.y >= grid_rows:
					continue
				if building_grid[n.y][n.x] >= 0:
					continue
				return n
	return Vector2i(-1, -1)


# ========== 绘制 ==========

func _draw() -> void:
	if not _buildings.is_empty():
		_draw_effect_ranges()
		_draw_network_ranges()
		_draw_buildings()

	# 放置模式幽灵预览
	if _placement_active and _placement_data and _in_bounds(_placement_hover_pos.x, _placement_hover_pos.y):
		_draw_placement_ghost()


func _draw_buildings() -> void:
	for b in _buildings:
		var data: BuildingData = b["data"]
		var faction: int = b["faction"]
		var origin: Vector2i = b["origin"]
		var fp: Vector2i = data.footprint
		var is_selected: bool = b["id"] == _selected_id

		# 迷雾检查：所有占用格都在迷雾中 -> 不绘制
		if _fog_mgr and _fog_mgr.has_method("get_fog"):
			var all_fogged := true
			var tiles := _get_footprint_tiles(origin, fp)
			for t in tiles:
				var viewer: int = _turn_manager.current_player if _turn_manager else 0
				if _fog_mgr.get_fog(viewer, t.x, t.y) <= 0.0:
					all_fogged = false
					break
			if all_fogged:
				continue

		var world_origin := _grid_to_world(origin.x, origin.y)
		var top_left := Vector2(world_origin.x - tile_size * 0.5, world_origin.y - tile_size * 0.5)
		var w := fp.x * tile_size
		var h := fp.y * tile_size

		# 选中高亮
		if is_selected:
			draw_rect(Rect2(top_left.x - 3, top_left.y - 3, w + 6, h + 6),
				SELECT_COLOR, false, 4.0)

		# 主城特殊效果：外发光
		var texture_key := _get_building_texture_key(data, faction)
		var building_texture := _get_building_texture(texture_key, data, faction)
		var has_building_texture := building_texture != null

		if data.category == BuildingData.BuildingCategory.CORE and not has_building_texture:
			var glow_color: Color = GameCatalog.faction_color(faction)
			glow_color.a = 0.3
			draw_rect(Rect2(top_left.x - 4, top_left.y - 4, w + 8, h + 8), glow_color, true)
			glow_color.a = 0.2
			draw_rect(Rect2(top_left.x - 8, top_left.y - 8, w + 16, h + 16), glow_color, true)

		# 建筑底色方块
		var color: Color = GameCatalog.faction_color(faction)
		color.a = BUILDING_ALPHA
		if not has_building_texture:
			draw_rect(Rect2(top_left.x, top_left.y, w, h), color, true)
		if has_building_texture:
			var default_scale := _get_building_texture_default_scale(data, faction)
			var fit := _get_building_texture_fit(texture_key, default_scale)
			var texture_scale: float = float(fit.get("scale", default_scale))
			var offset_tiles: Vector2 = fit.get("offset", Vector2.ZERO)
			var tex_w: float = w * texture_scale
			var tex_h: float = h * texture_scale
			var tex_rect := Rect2(
				top_left.x + w / 2.0 - tex_w / 2.0 + offset_tiles.x * tile_size,
				top_left.y + h / 2.0 - tex_h / 2.0 + offset_tiles.y * tile_size,
				tex_w,
				tex_h
			)
			draw_texture_rect(building_texture, tex_rect, false)

		if bool(b.get("pending_demolition", false)):
			_draw_demolition_marker(top_left, Vector2(w, h))
		if int(b.get("id", -1)) == _demolition_control_building_id:
			_draw_demolition_control(b, top_left, Vector2(w, h))

		# 建筑名称文字
		var font: Font = ThemeDB.fallback_font
		var fsize: int = 13 if data.category == BuildingData.BuildingCategory.CORE else 11
		var label: String = data.name
		if data.category == BuildingData.BuildingCategory.CORE or has_building_texture:
			label = ""
		if int(b.get("level", 1)) > 1 and data.max_level > 1:
			label = "%s Lv%d" % [data.name, int(b.get("level", 1))]
		var text_size := font.get_string_size(label, HORIZONTAL_ALIGNMENT_LEFT, -1, fsize)
		var label_pos := Vector2(
			top_left.x + w / 2.0 - text_size.x / 2.0,
			top_left.y + h / 2.0 + fsize / 3.0
		)
		# 文字阴影增加可读性
		draw_string(font, Vector2(label_pos.x + 1, label_pos.y + 1), label, HORIZONTAL_ALIGNMENT_LEFT, -1, fsize, Color(0, 0, 0, 0.6))
		draw_string(font, label_pos, label, HORIZONTAL_ALIGNMENT_LEFT, -1, fsize, Color.WHITE)

		# 主城特殊标记：顶部显示主城文本
		if false and data.category == BuildingData.BuildingCategory.CORE:
			var star_text := "* 主城 *"
			var star_size := font.get_string_size(star_text, HORIZONTAL_ALIGNMENT_LEFT, -1, 12)
			var star_pos := Vector2(
				top_left.x + w / 2.0 - star_size.x / 2.0,
				top_left.y - 6
			)
			draw_string(font, Vector2(star_pos.x + 1, star_pos.y + 1), star_text, HORIZONTAL_ALIGNMENT_LEFT, -1, 12, Color(0, 0, 0, 0.7))
			draw_string(font, star_pos, star_text, HORIZONTAL_ALIGNMENT_LEFT, -1, 12, Color(1.0, 0.9, 0.3))

		# HP 标签（右下角小字）
		var hp_label := "HP:%d/%d" % [b["hp"], _get_building_hp_max_from_instance(b)]
		var hp_size := font.get_string_size(hp_label, HORIZONTAL_ALIGNMENT_LEFT, -1, 9)
		var hp_pos := Vector2(
			top_left.x + w - hp_size.x - 2,
			top_left.y + h - 3
		)
		draw_string(font, hp_pos, hp_label, HORIZONTAL_ALIGNMENT_LEFT, -1, 9, Color.WHITE)

		# 驻兵圆点（建筑上方）
		var garrison: Array = b.get("garrison", [])
		if not garrison.is_empty():
			var dot_count: int = garrison.size()
			var max_dots := mini(dot_count, 4)
			var dot_radius := 2.5
			var dot_spacing := 8.0
			var dots_total_width := (max_dots - 1) * dot_spacing
			var dots_start_x := top_left.x + w / 2.0 - dots_total_width / 2.0
			for i in range(max_dots):
				var dot_pos := Vector2(dots_start_x + i * dot_spacing, top_left.y - 10)
				draw_circle(dot_pos, dot_radius, GameCatalog.faction_color(faction))
				draw_arc(dot_pos, dot_radius, 0, TAU, 8, Color.BLACK, 0.8)
			if dot_count > 4:
				var plus_label := "+%d" % [dot_count - 4]
				var plus_size := font.get_string_size(plus_label, HORIZONTAL_ALIGNMENT_LEFT, -1, 8)
				var plus_pos := Vector2(dots_start_x + 4 * dot_spacing + 2, top_left.y - 10 + 3)
				draw_string(font, plus_pos, plus_label, HORIZONTAL_ALIGNMENT_LEFT, -1, 8, Color.WHITE)


func _draw_demolition_marker(top_left: Vector2, size: Vector2) -> void:
	var body_rect := Rect2(top_left, size)
	draw_rect(body_rect, DEMOLISH_OVERLAY_COLOR, true)
	draw_rect(body_rect, DEMOLISH_BORDER_COLOR, false, 2.0)

	var icon_size: float = maxf(10.0, minf(size.x, size.y) / 3.0)
	var center := top_left + size * 0.5
	_draw_hammer_icon(center, icon_size)


func _draw_hammer_icon(center: Vector2, icon_size: float) -> void:
	var icon_color := Color(1.0, 0.12, 0.08, 1.0)
	var shadow_color := Color(0.0, 0.0, 0.0, 0.55)
	var scale_factor: float = icon_size / 24.0

	draw_set_transform(center + Vector2(1.0, 1.0), deg_to_rad(42.0), Vector2.ONE)
	draw_rect(Rect2(Vector2(-2.0, -6.0) * scale_factor, Vector2(4.0, 15.0) * scale_factor), shadow_color, true)
	draw_rect(Rect2(Vector2(-8.0, -10.0) * scale_factor, Vector2(16.0, 5.0) * scale_factor), shadow_color, true)
	draw_set_transform(center, deg_to_rad(42.0), Vector2.ONE)
	draw_rect(Rect2(Vector2(-2.0, -6.0) * scale_factor, Vector2(4.0, 15.0) * scale_factor), icon_color, true)
	draw_rect(Rect2(Vector2(-8.0, -10.0) * scale_factor, Vector2(16.0, 5.0) * scale_factor), icon_color, true)
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)


func _draw_demolition_control(building: Dictionary, top_left: Vector2, size: Vector2) -> void:
	var rect: Rect2 = _get_demolition_control_rect(building, top_left, size)
	var is_pending: bool = bool(building.get("pending_demolition", false))
	var bg_color := Color(0.95, 0.06, 0.04, 0.96)
	if is_pending:
		bg_color = Color(0.95, 0.22, 0.08, 0.96)
	draw_rect(rect, bg_color, true)
	draw_rect(rect, Color(0.1, 0.0, 0.0, 0.9), false, 1.0)

	var font: Font = ThemeDB.fallback_font
	var symbol := "-" if is_pending else "X"
	var font_size := 13 if is_pending else 12
	var text_size := font.get_string_size(symbol, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size)
	var text_pos := Vector2(
		rect.position.x + rect.size.x / 2.0 - text_size.x / 2.0,
		rect.position.y + rect.size.y / 2.0 + font_size * 0.35
	)
	draw_string(font, text_pos, symbol, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size, Color.WHITE)


func _get_demolition_control_rect(_building: Dictionary, top_left: Vector2, size: Vector2) -> Rect2:
	var rect_pos := Vector2(
		top_left.x + size.x - DEMOLISH_CONTROL_SIZE * 0.55,
		top_left.y - DEMOLISH_CONTROL_SIZE * 0.45
	)
	return Rect2(rect_pos, Vector2(DEMOLISH_CONTROL_SIZE, DEMOLISH_CONTROL_SIZE))


func _get_demolition_control_rect_for_building(building: Dictionary) -> Rect2:
	if building.is_empty():
		return Rect2()
	var data: BuildingData = building["data"]
	var origin: Vector2i = building["origin"]
	var fp: Vector2i = data.footprint
	var world_origin := _grid_to_world(origin.x, origin.y)
	var top_left := Vector2(world_origin.x - tile_size * 0.5, world_origin.y - tile_size * 0.5)
	var size := Vector2(fp.x * tile_size, fp.y * tile_size)
	return _get_demolition_control_rect(building, top_left, size)


func _can_show_demolition_control(building: Dictionary) -> bool:
	if building.is_empty():
		return false
	var data: BuildingData = building["data"]
	if data.category == BuildingData.BuildingCategory.CORE:
		return false
	if _turn_manager != null and int(building.get("faction", -1)) != _turn_manager.current_player:
		return false
	return true


func _toggle_demolition_control(building: Dictionary) -> void:
	if not _can_show_demolition_control(building):
		_demolition_control_building_id = -1
		return
	var building_id: int = int(building.get("id", -1))
	if _demolition_control_building_id == building_id:
		_demolition_control_building_id = -1
	else:
		_demolition_control_building_id = building_id
	queue_redraw()


func _activate_demolition_control(building_id: int) -> bool:
	var building: Dictionary = _get_building_by_id(building_id)
	if not _can_show_demolition_control(building):
		return false
	var changed := false
	if bool(building.get("pending_demolition", false)):
		changed = cancel_building_demolition(building_id)
	else:
		changed = mark_building_for_demolition(building_id)
	if changed:
		_demolition_control_building_id = -1
		queue_redraw()
	return changed


func _draw_effect_ranges() -> void:
	var range_buildings: Array[Dictionary] = []
	if _hovered_id >= 0:
		var hovered: Dictionary = _get_building_by_id(_hovered_id)
		if _should_draw_effect_range(hovered):
			range_buildings.append(hovered)
	if _selected_id >= 0 and _selected_id != _hovered_id:
		var selected: Dictionary = _get_building_by_id(_selected_id)
		if _should_draw_effect_range(selected):
			range_buildings.append(selected)

	for building in range_buildings:
		_draw_effect_range_for_building(building)


func _should_draw_effect_range(building: Dictionary) -> bool:
	if building.is_empty() or not building.has("data"):
		return false
	var data: BuildingData = building["data"]
	return data.effect_radius > 0


func _draw_effect_range_for_building(building: Dictionary) -> void:
	var data: BuildingData = building["data"]
	var center: Vector2i = _get_building_center(building)
	var radius: int = data.effect_radius
	for y in range(center.y - radius, center.y + radius + 1):
		for x in range(center.x - radius, center.x + radius + 1):
			if not _in_bounds(x, y):
				continue
			var dist: int = absi(center.x - x) + absi(center.y - y)
			if dist > radius:
				continue
			var world_pos: Vector2 = _grid_to_world(x, y)
			var top_left := Vector2(world_pos.x - tile_size * 0.5, world_pos.y - tile_size * 0.5)
			var rect := Rect2(top_left, Vector2(tile_size, tile_size))
			draw_rect(rect, EFFECT_RANGE_COLOR, true)
			draw_rect(rect, EFFECT_RANGE_BORDER_COLOR, false, 1.0)


func _draw_network_ranges() -> void:
	var range_buildings: Array[Dictionary] = []
	if _hovered_id >= 0:
		var hovered: Dictionary = _get_building_by_id(_hovered_id)
		if _should_draw_network_range(hovered):
			range_buildings.append(hovered)
	if _selected_id >= 0 and _selected_id != _hovered_id:
		var selected: Dictionary = _get_building_by_id(_selected_id)
		if _should_draw_network_range(selected):
			range_buildings.append(selected)

	for building in range_buildings:
		_draw_network_range_for_building(building)


func _should_draw_network_range(building: Dictionary) -> bool:
	if building.is_empty() or _building_network_service == null:
		return false
	var faction: int = int(building.get("faction", -1))
	return _building_network_service.can_use_network_bonus(faction, _civilization_rules)


func _draw_network_range_for_building(building: Dictionary) -> void:
	var center: Vector2i = _get_building_center(building)
	var radius: int = _building_network_service.get_link_range()
	for y in range(center.y - radius, center.y + radius + 1):
		for x in range(center.x - radius, center.x + radius + 1):
			if not _in_bounds(x, y):
				continue
			var dist: int = absi(center.x - x) + absi(center.y - y)
			if dist > radius:
				continue
			var world_pos: Vector2 = _grid_to_world(x, y)
			var top_left := Vector2(world_pos.x - tile_size * 0.5, world_pos.y - tile_size * 0.5)
			var rect := Rect2(top_left, Vector2(tile_size, tile_size))
			draw_rect(rect, NETWORK_RANGE_COLOR, true)
			draw_rect(rect, NETWORK_RANGE_BORDER_COLOR, false, 1.0)

	var info: Dictionary = get_building_network_info(int(building.get("id", -1)))
	var linked_ids: Array = info.get("linked_building_ids", [])
	var source_pos: Vector2 = _grid_to_world(center.x, center.y)
	for linked_id in linked_ids:
		var linked_building: Dictionary = _get_building_by_id(int(linked_id))
		if linked_building.is_empty():
			continue
		var linked_center: Vector2i = _get_building_center(linked_building)
		var linked_pos: Vector2 = _grid_to_world(linked_center.x, linked_center.y)
		draw_line(source_pos, linked_pos, NETWORK_LINK_COLOR, 2.0)


func _get_building_center(building: Dictionary) -> Vector2i:
	var data: BuildingData = building["data"]
	var origin: Vector2i = building.get("origin", Vector2i.ZERO)
	return Vector2i(origin.x + data.footprint.x / 2, origin.y + data.footprint.y / 2)


func _get_effective_building_hp_max(data: BuildingData, faction: int) -> int:
	var bonus: int = _get_route_modifier_int(faction, "building_hp_bonus")
	bonus += _get_technology_modifier_int(faction, "building_hp_bonus")
	return maxi(1, data.hp_max + bonus)


func _get_building_hp_max_from_instance(building: Dictionary) -> int:
	if building.is_empty() or not building.has("data"):
		return 0
	var data: BuildingData = building["data"]
	return int(building.get("hp_max", data.hp_max))


func _get_route_modifier_int(player: int, key: String) -> int:
	if _civilization_rules == null or player < 0:
		return 0
	if _civilization_rules.has_method("get_modifier_int"):
		return int(_civilization_rules.call("get_modifier_int", player, key, 0))
	if _civilization_rules.has_method("get_modifier"):
		return int(_civilization_rules.call("get_modifier", player, key, 0))
	return 0


func _get_technology_modifier_int(player: int, key: String) -> int:
	if _technology_service == null and is_inside_tree():
		_technology_service = get_parent().get_node_or_null("TechnologyService")
	if _technology_service != null and _technology_service.has_method("get_modifier"):
		return int(_technology_service.call("get_modifier", player, key, 0))
	return 0


func _load_building_texture_fit_config() -> void:
	_building_texture_fit_config = {}
	if not FileAccess.file_exists(BUILDING_TEXTURE_FIT_CONFIG_PATH):
		return
	var file := FileAccess.open(BUILDING_TEXTURE_FIT_CONFIG_PATH, FileAccess.READ)
	if file == null:
		return
	var text := file.get_as_text()
	file.close()
	var parsed: Variant = JSON.parse_string(text)
	if parsed is Dictionary:
		_building_texture_fit_config = parsed


func _get_building_texture_fit(key: String, default_scale: float) -> Dictionary:
	var result := {
		"scale": default_scale,
		"offset": Vector2.ZERO,
	}
	var resolved_key := _resolve_building_texture_key(key)
	if not _building_texture_fit_config.has(resolved_key):
		return result
	var fit_variant: Variant = _building_texture_fit_config[resolved_key]
	if not fit_variant is Dictionary:
		return result
	var fit: Dictionary = fit_variant
	if fit.has("scale"):
		result["scale"] = float(fit.get("scale", default_scale))
	if fit.has("offset"):
		var offset_variant: Variant = fit["offset"]
		if offset_variant is Array:
			var offset_array: Array = offset_variant
			if offset_array.size() >= 2:
				result["offset"] = Vector2(float(offset_array[0]), float(offset_array[1]))
	return result


func _get_building_texture_key(data: BuildingData, faction: int) -> String:
	if data.category == BuildingData.BuildingCategory.CORE:
		return _get_capital_fit_key(faction)
	if data.unique_effect_id != "":
		return data.unique_effect_id.replace(".", "_")
	if data.tags.has("barracks"):
		return "barracks"
	if data.tags.has("forge"):
		return "forge"
	if data.storage_level > 0:
		return "warehouse"
	if data.needs_resource_point:
		return "gold_mine_shaft"
	if data.production.has("wood"):
		return "lumber_camp"
	if data.production.has("stone"):
		return "quarry"
	if data.production.has("food"):
		return "farm"
	if data.production.has("iron"):
		return "iron_mine"
	if data.production.has("gold_ore"):
		return "gold_mine_shaft"
	match data.category:
		BuildingData.BuildingCategory.RECRUITMENT:
			return "recruit_camp"
		BuildingData.BuildingCategory.SCOUT:
			if data.defense_attack_range > 0:
				return "watch_tower"
			return "scout_post"
		BuildingData.BuildingCategory.DEFENSE:
			return "defense_tower"
	return ""


func _resolve_building_texture_key(key: String) -> String:
	if key.is_empty() or _building_texture_fit_config.has(key):
		return key
	var aliases := {
		"gold_mine_shaft": "gold_mine",
		"barracks": "barracks_lv1",
	}
	var alias: String = str(aliases.get(key, ""))
	if not alias.is_empty() and _building_texture_fit_config.has(alias):
		return alias
	return key


func _get_building_texture(data_key: String, data: BuildingData, faction: int) -> Texture2D:
	var path := _get_building_texture_path(data_key)
	if not path.is_empty():
		return _load_building_texture(path)
	if data.category == BuildingData.BuildingCategory.CORE:
		return _get_capital_texture(data, faction)
	return null


func _get_building_texture_path(key: String) -> String:
	var resolved_key := _resolve_building_texture_key(key)
	if resolved_key.is_empty() or not _building_texture_fit_config.has(resolved_key):
		return ""
	var fit_variant: Variant = _building_texture_fit_config[resolved_key]
	if not fit_variant is Dictionary:
		return ""
	var fit: Dictionary = fit_variant
	var texture_path := str(fit.get("texture", ""))
	return texture_path.strip_edges()


func _load_building_texture(path: String) -> Texture2D:
	if path.is_empty():
		return null
	if _building_texture_cache.has(path):
		return _building_texture_cache[path]
	var loaded := load(path)
	var texture: Texture2D = loaded if loaded is Texture2D else null
	_building_texture_cache[path] = texture
	return texture


func _get_building_texture_default_scale(data: BuildingData, faction: int) -> float:
	if data.category == BuildingData.BuildingCategory.CORE:
		return _get_capital_default_scale(faction)
	return 1.0


func _get_capital_texture(data: BuildingData, faction: int) -> Texture2D:
	if data.category != BuildingData.BuildingCategory.CORE:
		return null
	match faction:
		0:
			return ELF_CAPITAL_TEXTURE
		1:
			return DWARF_CAPITAL_TEXTURE
		2:
			return ORC_CAPITAL_TEXTURE
	return null


func _get_capital_fit_key(faction: int) -> String:
	match faction:
		0:
			return "elf_capital"
		1:
			return "dwarf_capital"
		2:
			return "orc_capital"
	return "capital"


func _get_capital_default_scale(faction: int) -> float:
	match faction:
		0:
			return ELF_CAPITAL_TEXTURE_SCALE
		1:
			return DWARF_CAPITAL_TEXTURE_SCALE
		2:
			return ORC_CAPITAL_TEXTURE_SCALE
	return 1.0


func _draw_placement_ghost() -> void:
	if not _placement_data:
		return
	var fp: Vector2i = _placement_data.footprint
	var world_origin := _grid_to_world(_placement_hover_pos.x, _placement_hover_pos.y)
	var top_left := Vector2(world_origin.x - tile_size * 0.5, world_origin.y - tile_size * 0.5)
	var w := fp.x * tile_size
	var h := fp.y * tile_size
	var color: Color
	if _placement_valid:
		color = Color(0.3, 1.0, 0.3, 0.4)
	else:
		color = Color(1.0, 0.3, 0.3, 0.4)
	draw_rect(Rect2(top_left.x, top_left.y, w, h), color, true)
	draw_rect(Rect2(top_left.x, top_left.y, w, h), Color.WHITE, false, 1.5)


# ========== 回合产出 ==========

func _on_round_ended(round_number: int) -> void:
	for b in _buildings:
		var data: BuildingData = b["data"]
		var prod: Dictionary = data.production

		# 金币铸造厂特殊显示
		if BuildingRules.is_mint(data):
			var garr: Array = b.get("garrison", [])
			var gcount := garr.size()
			if gcount > 0:
				var faction_name := GameCatalog.faction_name(int(b["faction"]))
				print("[Building] %s mint: garrison %d => gold +%d" % [faction_name, gcount, gcount * 2])
				_show_production_text(b, {"gold": gcount * 2}, 0, Color(1.0, 0.84, 0.0))
			continue

		if prod.is_empty():
			continue
		var faction_name := ""
		match b["faction"]:
			0: faction_name = "精灵"
			1: faction_name = "矮人"
			2: faction_name = "兽人"
		var parts: PackedStringArray = []
		for key in prod:
			parts.append("%s +%d" % [key, prod[key]])
		print("[建筑] %s %s: %s" % [faction_name, data.name, ", ".join(parts)])

		# 驻兵加成日志
		var garrison: Array = b.get("garrison", [])
		var gcount: int = garrison.size()
		if gcount > 0:
			var garrison_bonus: Dictionary = get_garrison_bonus(b["id"])
			var bonus_parts: PackedStringArray = []
			for key in garrison_bonus:
				bonus_parts.append("%s +%d" % [key, garrison_bonus[key]])
			if not bonus_parts.is_empty():
				print("[Building] garrison bonus %s: %s" % [data.name, ", ".join(bonus_parts)])

		# 建筑上方飘浮产量文字
		_show_production_text(b, prod, gcount)


func _show_production_text(building: Dictionary, prod: Dictionary, gcount: int, custom_color: Color = Color(0.5, 1.0, 0.5)) -> void:
	## 在建筑上方创建飘浮产量文字，如“木材 +1”“石料 +2”
	if prod.is_empty():
		return
	var lines: PackedStringArray = []
	var bonus: Dictionary = get_garrison_bonus(building["id"])
	for key in prod:
		var network_bonus: int = get_building_network_production_bonus(int(building["id"]), str(key))
		var total: int = int(prod[key]) + int(bonus.get(key, 0)) + network_bonus
		var rname: String = GameCatalog.resource_name(key)
		lines.append("%s +%d" % [rname, total])
	_show_floating_text(building, "\n".join(lines), custom_color)


func _show_resource_text(building: Dictionary, resources: Dictionary, custom_color: Color) -> void:
	var lines: PackedStringArray = []
	for key in resources:
		var rname: String = GameCatalog.resource_name(str(key))
		lines.append("%s +%d" % [rname, int(resources[key])])
	_show_floating_text(building, "\n".join(lines), custom_color)


func _show_building_damage_text(building: Dictionary, amount: int) -> void:
	if amount <= 0:
		return
	_show_floating_text(building, "-%d HP" % amount, Color(1.0, 0.25, 0.18))


func _show_building_heal_text(building: Dictionary, amount: int) -> void:
	if amount <= 0:
		return
	_show_floating_text(building, "+%d HP" % amount, Color(0.45, 1.0, 0.45))


func _show_floating_text(building: Dictionary, text: String, custom_color: Color) -> void:
	if building.is_empty() or text.is_empty():
		return
	var world_pos: Vector2 = _get_building_world_center(building)
	var label := Label.new()
	label.text = text
	label.add_theme_color_override("font_color", custom_color)
	label.add_theme_font_size_override("font_size", 13)
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.position = Vector2(world_pos.x - 30, world_pos.y - 30)
	add_child(label)

	var tween := create_tween()
	tween.set_trans(Tween.TRANS_SINE)
	tween.tween_property(label, "position", label.position + Vector2(0, -30), 1.0)
	tween.parallel().tween_property(label, "modulate:a", 0.0, 1.0)
	tween.tween_callback(label.queue_free)


func _get_building_world_center(building: Dictionary) -> Vector2:
	var center: Vector2i = _get_building_center(building)
	return _grid_to_world(center.x, center.y)


# ========== 交互 ==========

func _unhandled_input(event: InputEvent) -> void:
	if _placement_active:
		_handle_placement_input(event)
		return

	if event is InputEventKey and event.pressed and not event.echo:
		if event.keycode == KEY_U and _selected_id >= 0:
			var building: Dictionary = _get_building_by_id(_selected_id)
			if not building.is_empty() and _turn_manager and int(building.get("faction", -1)) == _turn_manager.current_player:
				upgrade_building(_selected_id)
			return
		if event.keycode == KEY_H and _selected_id >= 0:
			repair_building(_selected_id)
			return

	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		var mouse_event: InputEventMouseButton = event
		var cursor := get_global_mouse_position()
		if _demolition_control_building_id >= 0:
			var control_building: Dictionary = _get_building_by_id(_demolition_control_building_id)
			if not control_building.is_empty():
				var control_rect: Rect2 = _get_demolition_control_rect_for_building(control_building)
				if control_rect.has_point(cursor):
					_activate_demolition_control(_demolition_control_building_id)
					return

		var gpos := _world_to_grid(cursor)
		if gpos.x < 0 or gpos.x >= grid_cols or gpos.y < 0 or gpos.y >= grid_rows:
			_demolition_control_building_id = -1
			_clear_selection()
			queue_redraw()
			return

		var building := get_building_at(gpos)
		if not building.is_empty():
			if mouse_event.double_click:
				_toggle_demolition_control(building)
				_select_building(int(building["id"]))
				return

			var garr: Array = building.get("garrison", [])
			var building_data: BuildingData = building["data"]
			if not garr.is_empty() and building_data.upgrade_rules.is_empty() and _turn_manager and not _just_garrisoned.has(building["id"]):
				var cp: int = _turn_manager.current_player
				if building["faction"] == cp:
					var unit_dict := ungarrison_one(building["id"])
					if not unit_dict.is_empty():
						var spawn_pos := _find_ungarrison_pos(building)
						if spawn_pos.x >= 0:
							var unit_mgr = get_parent().get_node("UnitManager2D")
							if unit_mgr and unit_mgr.has_method("add_unit"):
								unit_mgr.add_unit(cp, unit_dict["data"], spawn_pos, unit_dict.get("hp", -1))
						return

			if _selected_id == building["id"]:
				_clear_selection()
			else:
				_select_building(building["id"])
		else:
			_demolition_control_building_id = -1
			_clear_selection()
			queue_redraw()

	if event is InputEventMouseMotion:
		var cursor := get_global_mouse_position()
		var gpos := _world_to_grid(cursor)
		if gpos.x < 0 or gpos.x >= grid_cols or gpos.y < 0 or gpos.y >= grid_rows:
			_set_hovered_building(-1)
			return
		var building := get_building_at(gpos)
		if not building.is_empty():
			_set_hovered_building(int(building["id"]))
			var data: BuildingData = building["data"]
			var fname := GameCatalog.faction_name(int(building["faction"]))
			var building_name: String = data.name
			if int(building.get("level", 1)) > 1 and data.max_level > 1:
				building_name = "%s Lv%d" % [data.name, int(building.get("level", 1))]
			var hover_text := "%s - %s (HP:%d/%d)" % [fname, building_name, building["hp"], _get_building_hp_max_from_instance(building)]
			if bool(building.get("pending_demolition", false)):
				hover_text += " - 待拆除"
			if BuildingRules.is_defense_building(data):
				hover_text += " - 防御建筑"
			if BuildingRules.is_forge(data):
				hover_text += " - 配方:2铁+1石=>1精钢; 2铁+1魔尘=>1秘银"
			if data.effect_radius > 0:
				hover_text += " - Range:%d" % data.effect_radius
			if data.defense_attack_range > 0:
				hover_text += " - Tower:%d格/%d伤/%.1fs" % [data.defense_attack_range, data.defense_attack_damage, data.defense_attack_cooldown]
			hover_text += " - %s" % data.get_garrison_rule_text()
			var network_info: Dictionary = get_building_network_info(int(building["id"]))
			if _should_draw_network_range(building):
				var linked_count: int = int(network_info.get("linked_count", 0))
				var network_bonus: int = int(network_info.get("production_bonus", 0))
				if linked_count > 0:
					hover_text += " - 建筑网络:%d" % linked_count
					if network_bonus > 0:
						hover_text += " 产出+%d" % network_bonus
				else:
					hover_text += " - 建筑网络:未连接"
			var garr: Array = building.get("garrison", [])
			if not garr.is_empty():
				hover_text += " - Garrison:%d/%d" % [garr.size(), max_garrison(building)]
			if _turn_manager != null:
				if int(building.get("faction", -1)) == _turn_manager.current_player and int(building.get("hp", 0)) < _get_building_hp_max_from_instance(building):
					hover_text += " - H修复:%d石料+%dAP" % [REPAIR_STONE_COST, REPAIR_AP_COST]
				elif int(building.get("faction", -1)) != _turn_manager.current_player:
					hover_text += " - 可攻击"
			building_hovered.emit(hover_text)
		else:
			_set_hovered_building(-1)

func _handle_placement_input(event: InputEvent) -> void:
	## 放置模式下处理鼠标移动（预览）+ 左键（建造）+ 右键（取消）
	if event is InputEventMouseMotion:
		var cursor := get_global_mouse_position()
		var gpos := _world_to_grid(cursor)
		_placement_hover_pos = gpos
		_placement_valid = _check_placement_valid(gpos)
		queue_redraw()
		return

	if event is InputEventMouseButton and event.pressed:
		if event.button_index == MOUSE_BUTTON_LEFT:
			if _placement_valid:
				_do_placement(_placement_hover_pos)
			else:
				queue_redraw()
		elif event.button_index == MOUSE_BUTTON_RIGHT:
			cancel_placement()


func _select_building(bid: int) -> void:
	_selected_id = bid
	var building: Dictionary = _get_building_by_id(bid)
	if _is_recruit_building(building):
		_emit_recruit_panel(building)
	else:
		recruit_panel_closed.emit()
	queue_redraw()


func _clear_selection() -> void:
	_selected_id = -1
	_demolition_control_building_id = -1
	recruit_panel_closed.emit()
	queue_redraw()


# ========== 放置模式 ==========


func _set_hovered_building(building_id: int) -> void:
	if _hovered_id == building_id:
		return
	_hovered_id = building_id
	queue_redraw()

func start_placement(data: BuildingData, faction: int) -> void:
	## 点击建筑卡片后进入放置模式
	_placement_active = true
	_placement_data = data
	_placement_faction = faction
	_placement_hover_pos = Vector2i(-1, -1)
	_placement_valid = false
	queue_redraw()


func cancel_placement() -> void:
	## 取消放置模式
	_placement_active = false
	_placement_data = null
	_placement_faction = -1
	_placement_hover_pos = Vector2i(-1, -1)
	_placement_valid = false
	placement_canceled.emit()
	queue_redraw()


func _check_placement_valid(pos: Vector2i) -> bool:
	## 实时校验是否可在此处建造
	if not _placement_data or not _in_bounds(pos.x, pos.y):
		return false

	var data: BuildingData = _placement_data
	var faction: int = _placement_faction

	# 资源检查
	if _resource_tracker:
		if _resource_tracker.get_resource(faction, "gold") < data.cost_gold:
			return false
		if _resource_tracker.get_resource(faction, "wood") < data.cost_wood:
			return false
		if _resource_tracker.get_resource(faction, "stone") < data.cost_stone:
			return false
		if _resource_tracker.get_resource(faction, "iron") < data.cost_iron:
			return false
		if _resource_tracker.get_resource(faction, "food") < data.cost_food:
			return false

	# AP 检查
	if _turn_manager:
		var ap: int = _turn_manager.get_ap(_turn_manager.current_player)
		if ap < 2:
			return false

	# 领土/地形/占用/上限检查
	return _can_place(data, faction, pos)


func _check_build_payment_available(data: BuildingData, faction: int) -> bool:
	if data == null:
		return false
	if _resource_tracker:
		if _resource_tracker.get_resource(faction, "gold") < data.cost_gold:
			return false
		if _resource_tracker.get_resource(faction, "wood") < data.cost_wood:
			return false
		if _resource_tracker.get_resource(faction, "stone") < data.cost_stone:
			return false
		if _resource_tracker.get_resource(faction, "iron") < data.cost_iron:
			return false
		if _resource_tracker.get_resource(faction, "food") < data.cost_food:
			return false
	if _turn_manager and _turn_manager.get_ap(faction) < 2:
		return false
	return true


func _spend_building_cost(data: BuildingData, faction: int) -> void:
	if data == null or _resource_tracker == null:
		return
	_resource_tracker.spend_resource(faction, "gold", data.cost_gold)
	_resource_tracker.spend_resource(faction, "wood", data.cost_wood)
	_resource_tracker.spend_resource(faction, "stone", data.cost_stone)
	_resource_tracker.spend_resource(faction, "iron", data.cost_iron)
	_resource_tracker.spend_resource(faction, "food", data.cost_food)


func _do_placement(pos: Vector2i) -> void:
	## 执行建造：扣资源 -> 扣 AP -> 放置建筑
	if not _placement_data:
		return

	var data: BuildingData = _placement_data
	var faction: int = _placement_faction

	# 扣资源
	if _request_network_build(data, faction, pos):
		cancel_placement()
		return
	if _resource_tracker:
		_resource_tracker.spend_resource(faction, "gold", data.cost_gold)
		_resource_tracker.spend_resource(faction, "wood", data.cost_wood)
		_resource_tracker.spend_resource(faction, "stone", data.cost_stone)
		_resource_tracker.spend_resource(faction, "iron", data.cost_iron)
		_resource_tracker.spend_resource(faction, "food", data.cost_food)

	# 扣 AP
	if _turn_manager:
		_turn_manager.spend_ap(faction, 2)

	# 放置建筑
	var placed: bool = place_building(data, faction, pos)
	if placed:
		print("[建造] 阵营 %d 在 %s 建造 %s" % [faction, str(pos), data.name])

	cancel_placement()


# ========== 坐标工具 ==========

func _grid_to_world(grid_x: int, grid_y: int) -> Vector2:
	var offset := Vector2(-grid_center.x * tile_size, -grid_center.y * tile_size)
	return Vector2(grid_x * tile_size + offset.x, grid_y * tile_size + offset.y)


func _world_to_grid(world_pos: Vector2) -> Vector2i:
	var offset := Vector2(-grid_center.x * tile_size, -grid_center.y * tile_size)
	var gx := int(roundf((world_pos.x - offset.x) / tile_size))
	var gy := int(roundf((world_pos.y - offset.y) / tile_size))
	return Vector2i(gx, gy)


func _in_bounds(gx: int, gy: int) -> bool:
	return gx >= 0 and gx < grid_cols and gy >= 0 and gy < grid_rows


func request_recruitment(building_id: int, unit_template_id: String, count: int) -> bool:
	if _request_network_recruit(building_id, unit_template_id, count):
		return true
	return _request_recruitment_local(building_id, unit_template_id, count)


func _request_recruitment_local(building_id: int, unit_template_id: String, count: int) -> bool:
	var ok: bool = _recruitment_service.request_recruitment(building_id, unit_template_id, count)
	if ok:
		var building: Dictionary = _get_building_by_id(building_id)
		recruit_queue_changed.emit(building_id, building.get("recruit_queue", []).duplicate(true))
		_emit_recruit_panel(building)
	return ok


func get_recruit_queue(building_id: int) -> Array:
	return _recruitment_service.get_recruit_queue(building_id)


func _process_recruit_queues(player: int) -> void:
	var changed_buildings: Array = _recruitment_service.process_recruit_queues(player)
	var spawned_units: Array = _recruitment_service.consume_last_spawned_units()
	for building in changed_buildings:
		var queue: Array = building.get("recruit_queue", [])
		recruit_queue_changed.emit(building["id"], queue.duplicate(true))
		if building["id"] == _selected_id:
			_emit_recruit_panel(building)
	var unit_mgr = get_parent().get_node_or_null("UnitManager2D")
	for entry in spawned_units:
		var unit_id: int = int(entry.get("unit_id", -1))
		if unit_id < 0 or unit_mgr == null or not unit_mgr.has_method("get_unit_by_id"):
			continue
		var unit: Dictionary = unit_mgr.get_unit_by_id(unit_id)
		if unit.is_empty():
			continue
		unit_recruited.emit(player, unit.duplicate(), str(entry.get("unit_template_id", "")))


func _spawn_recruited_unit(building: Dictionary, unit_template_id: String) -> bool:
	return _recruitment_service.spawn_recruited_unit(building, unit_template_id)


func _find_empty_adjacent_pos(building: Dictionary) -> Vector2i:
	return _recruitment_service.find_empty_adjacent_pos(building)


func _emit_recruit_panel(building: Dictionary) -> void:
	var options: Array = _get_recruit_options(building)
	if options.is_empty():
		recruit_panel_closed.emit()
		return
	recruit_panel_requested.emit(
		building["id"],
		building["data"].name,
		options,
		building.get("recruit_queue", []).duplicate(true)
	)


func _get_recruit_options(building: Dictionary) -> Array:
	return _recruitment_service.get_recruit_options(building)


func _get_recruit_template_ids_for_building(building: Dictionary) -> Array:
	return _recruitment_service.get_recruit_template_ids_for_building(building)


func _get_faction_recruit_template_ids(building: Dictionary) -> Array:
	return _recruitment_service.get_faction_recruit_template_ids(building)


func _get_building_template_for_data(data: BuildingData) -> Resource:
	return _recruitment_service.get_building_template_for_data(data)


func _building_can_recruit(building: Dictionary, unit_template_id: String) -> bool:
	return _recruitment_service.building_can_recruit(building, unit_template_id)


func _get_recruit_unit_template(unit_template_id: String) -> Resource:
	return _recruitment_service.get_recruit_unit_template(unit_template_id)


func _get_unit_recruit_cost(unit_template: Resource) -> Dictionary:
	return _recruitment_service.get_unit_recruit_cost(unit_template)


func _is_recruit_building(building: Dictionary) -> bool:
	return _recruitment_service.is_recruit_building(building)


func _get_building_by_id(building_id: int) -> Dictionary:
	for building in _buildings:
		if building["id"] == building_id:
			return building
	return {}


func _get_building_index_by_id(building_id: int) -> int:
	for i in range(_buildings.size()):
		var building: Dictionary = _buildings[i]
		if int(building.get("id", -1)) == building_id:
			return i
	return -1


func _destroy_building_at_index(index: int, attacker_faction: int = -1) -> void:
	if index < 0 or index >= _buildings.size():
		return
	var building: Dictionary = _buildings[index]
	var data: BuildingData = building["data"]
	var origin: Vector2i = building["origin"]
	var tiles: Array = _get_footprint_tiles(origin, data.footprint)
	for tile in tiles:
		var pos: Vector2i = tile
		if _in_bounds(pos.x, pos.y) and int(building_grid[pos.y][pos.x]) == int(building["id"]):
			building_grid[pos.y][pos.x] = -1
	if int(building.get("id", -1)) == _selected_id:
		_selected_id = -1
	if int(building.get("id", -1)) == _hovered_id:
		_hovered_id = -1
	if int(building.get("id", -1)) == _demolition_control_building_id:
		_demolition_control_building_id = -1
	var faction: int = int(building.get("faction", -1))
	if BuildingRules.is_outpost(data) and _territory_mgr and _territory_mgr.has_method("remove_town_hall"):
		var source := Vector2i(origin.x + data.footprint.x / 2, origin.y + data.footprint.y / 2)
		_territory_mgr.remove_town_hall(faction, source)
	_buildings.remove_at(index)
	if BuildingRules.is_outpost(data) and _territory_mgr and _territory_mgr.has_method("recalc_territory"):
		_territory_mgr.recalc_territory(faction)
	if _resource_tracker != null and _resource_tracker.has_method("update_display"):
		var display_faction: int = attacker_faction if attacker_faction >= 0 else faction
		_resource_tracker.update_display(display_faction)
	queue_redraw()
