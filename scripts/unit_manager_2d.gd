extends Node2D
const BuildingEffectServiceScript := preload("res://scripts/services/building_effect_service.gd")
const ORC_BLOOD_AXE_IDLE_TEXTURE: Texture2D = preload("res://assets/texture/character/orc/Blood Axe Warrior/Orc-Idle.png")
const ORC_BLOOD_AXE_WALK_TEXTURE: Texture2D = preload("res://assets/texture/character/orc/Blood Axe Warrior/Orc-Walk.png")
const ORC_BLOOD_AXE_HURT_TEXTURE: Texture2D = preload("res://assets/texture/character/orc/Blood Axe Warrior/Orc-Hurt.png")
const ORC_BLOOD_AXE_ATTACK_TEXTURE: Texture2D = preload("res://assets/texture/character/orc/Blood Axe Warrior/Orc-Attack01.png")
const ORC_BLOOD_AXE_DEATH_TEXTURE: Texture2D = preload("res://assets/texture/character/orc/Blood Axe Warrior/Orc-Death.png")
## 单位管理器 — 放置、绘制、选择、移动、战斗
##
## 单位绘制在迷雾之下（原型简化），阵营色圆圈 + 中文名 + HP

signal unit_selected(unit_data: Dictionary)
signal selection_cleared()
signal combat_started()
signal combat_ended()
signal hidden_trader_discovered(faction: int)
signal action_preview_changed(preview: Dictionary)
signal unit_killed(killer_player: int, victim_player: int, victim: Dictionary)

var grid_cols := 100
var grid_rows := 56
var tile_size := 32.0
var grid_center := Vector2(49.5, 27.5)

var _units: Array = []       # Array[Dictionary]
var _next_id := 1
var _selected_id := -1
var _reachable_tiles: Array = []  # 当前选中单位的可达格列表

var _turn_manager: Node = null
var _grid_manager: Node = null
var _fog_manager: Node = null
var _template_registry: Node = null
var _building_manager: Node = null
var _technology_service: Node = null
var _building_effect_service = BuildingEffectServiceScript.new()

# 战斗系统
var _in_combat := false
var _combat_timer: Timer = null
var _combat_data: Dictionary = {}  # { unit_a_id, unit_b_id, next_attacker_id }
var _move_visuals: Dictionary = {}  # unit_id -> { from: Vector2, to: Vector2, t: float }
var _hurt_visuals: Dictionary = {}  # unit_id -> { t: float }
var _attack_visuals: Dictionary = {}  # unit_id -> { t: float, flip_x: bool }
var _death_visuals: Dictionary = {}  # unit_id -> { pos: Vector2, t: float, flip_x: bool }
var _unit_facing_flip: Dictionary = {}  # unit_id -> bool
var _pending_attack_after_move: Dictionary = {}  # attacker_id -> defender_id
var _last_action_preview_key := ""
var _current_action_preview: Dictionary = {}

# 战斗视觉效果
var _hit_flash: Dictionary = {}  # unit_id -> true（闪白状态）
var _shake_offsets: Dictionary = {}  # unit_id -> Vector2（受击偏移）

const SELECT_COLOR := Color(1.0, 1.0, 1.0, 0.8)
const REACHABLE_COLOR := Color(1.0, 1.0, 1.0, 0.25)
const ATTACK_APPROACH_OK_COLOR := Color(0.2, 1.0, 0.35, 0.38)
const ATTACK_APPROACH_BLOCKED_COLOR := Color(1.0, 0.35, 0.18, 0.42)
const UNIT_RADIUS := 8.0
const SPAWN_SEARCH_RADIUS := 8
const MOVE_VISUAL_DURATION := 1.0
const ORC_BLOOD_AXE_TEMPLATE_ID := "unit.orc.guard"
const ORC_BLOOD_AXE_IDLE_FRAMES := 6
const ORC_BLOOD_AXE_WALK_FRAMES := 8
const ORC_BLOOD_AXE_HURT_FRAMES := 4
const ORC_BLOOD_AXE_ATTACK_FRAMES := 6
const ORC_BLOOD_AXE_DEATH_FRAMES := 4
const ORC_BLOOD_AXE_FRAME_SIZE := Vector2(100, 100)
const ORC_BLOOD_AXE_DRAW_SIZE := Vector2(96, 96)
const ORC_BLOOD_AXE_IDLE_FRAME_SECONDS := 0.18
const ORC_BLOOD_AXE_HURT_DURATION := 0.28
const ORC_BLOOD_AXE_ATTACK_DURATION := 0.36
const ORC_BLOOD_AXE_DEATH_DURATION := 0.48


func _ready() -> void:
	_grid_manager = get_parent().get_node("GridManager2D")
	_fog_manager = get_parent().get_node_or_null("FogOfWar2D")
	_template_registry = get_parent().get_node_or_null("TemplateRegistry")
	_building_manager = get_parent().get_node_or_null("BuildingManager2D")
	_technology_service = get_parent().get_node_or_null("TechnologyService")
	set_process(true)


func _process(_delta: float) -> void:
	_update_action_preview()
	if not _move_visuals.is_empty() or not _hurt_visuals.is_empty() or not _attack_visuals.is_empty() or not _death_visuals.is_empty() or _has_orc_blood_axe_units():
		queue_redraw()


func set_turn_manager(tm: Node) -> void:
	_turn_manager = tm
	if tm:
		tm.player_turn_started.connect(_on_player_turn_started)
		tm.player_turn_ended.connect(_on_player_turn_ended)


# ========== 单位管理 ==========

func place_initial_units() -> void:
	## 每阵营初始：1工人 + 1斥候 + 1守卫
	var spawns := [
		{ "player": 0, "pos": Vector2i(35, 13), "name_offset": -1 },
		{ "player": 1, "pos": Vector2i(35, 43), "name_offset": -2 },
		{ "player": 2, "pos": Vector2i(62, 35), "name_offset": -3 },
	]
	var fog_mgr = get_parent().get_node("FogOfWar2D")
	for s in spawns:
		var p: int = s["player"]
		var pos: Vector2i = s["pos"]
		var offset: int = s["name_offset"]
		var unit_defs: Array = UnitRoster.get_initial_unit_defs(p)
		_add_initial_unit(p, str(unit_defs[0]["template_id"]), unit_defs[0]["fallback"], Vector2i(pos.x + offset, pos.y))
		_add_initial_unit(p, str(unit_defs[1]["template_id"]), unit_defs[1]["fallback"], Vector2i(pos.x + offset + 1, pos.y))
		_add_initial_unit(p, str(unit_defs[2]["template_id"]), unit_defs[2]["fallback"], Vector2i(pos.x + offset + 2, pos.y))

		# 初始放置时揭示视野
		for u in _units:
			if u["faction"] != p:
				continue
			var upos: Vector2i = u["grid_pos"]
			fog_mgr.reveal_area(p, upos.x, upos.y, _get_unit_vision_value(u))


func _add_initial_unit(faction: int, template_id: String, fallback: UnitData, grid_pos: Vector2i) -> int:
	if _template_registry and _template_registry.has_method("get_unit"):
		var template: Resource = _template_registry.call("get_unit", template_id)
		if template != null:
			return add_unit_from_template(faction, template, grid_pos)
	return _add_unit(faction, fallback, grid_pos)


func _add_unit(faction: int, data: UnitData, grid_pos: Vector2i) -> int:
	var spawn_pos: Vector2i = _resolve_spawn_pos(grid_pos)
	if spawn_pos.x < 0:
		print("[Unit] No valid spawn tile near %s for %s." % [str(grid_pos), data.unit_name])
		return -1

	var uid := _next_id
	_next_id += 1
	_units.append({
		"id": uid,
		"data": data,
		"template_id": data.template_id,
		"faction": faction,
		"grid_pos": spawn_pos,
		"hp": data.hp_max,
		"has_moved": false,
		"has_attacked": false,
	})
	if spawn_pos != grid_pos:
		print("[Unit] Adjusted spawn %s -> %s for %s." % [str(grid_pos), str(spawn_pos), data.unit_name])
	return uid


func get_unit_at(grid_pos: Vector2i) -> Dictionary:
	for u in _units:
		if u["grid_pos"] == grid_pos:
			return u
	return {}


func get_visible_unit_at(grid_pos: Vector2i) -> Dictionary:
	for u in _units:
		if u["grid_pos"] == grid_pos and _is_unit_visible_to_current_player(u):
			return u
	return {}


func get_player_units(player: int) -> Array:
	var result: Array = []
	for u in _units:
		if u["faction"] == player:
			result.append(u)
	return result


func get_all_units() -> Array:
	## 返回所有单位的副本（供 NeutralUnitManager2D 查询）
	return _units.duplicate()


func get_unit_by_id(uid: int) -> Dictionary:
	## 公开版 _get_unit_by_id
	return _get_unit_by_id(uid)


func _is_unit_visible_to_current_player(unit: Dictionary) -> bool:
	if _turn_manager == null or _fog_manager == null:
		return true
	var viewer: int = int(_turn_manager.current_player)
	var faction: int = int(unit.get("faction", -1))
	if faction == viewer:
		return true
	var pos: Vector2i = unit.get("grid_pos", Vector2i(-1, -1))
	if pos.x < 0:
		return false
	return float(_fog_manager.get_fog(viewer, pos.x, pos.y)) <= 0.0


# ========== 绘制 ==========

func _draw() -> void:
	if _units.is_empty() and _death_visuals.is_empty():
		return

	# 绘制可达格高亮
	for t in _reachable_tiles:
		var pos2 := _grid_to_world(t.x, t.y)
		draw_circle(pos2, UNIT_RADIUS * 1.5, REACHABLE_COLOR)

	_draw_action_preview_highlight()

	for u in _units:
		if not _is_unit_visible_to_current_player(u):
			continue
		var world_pos: Vector2 = _get_unit_draw_world_pos(u)
		var faction: int = u["faction"]
		var data: UnitData = _get_unit_data(u)
		var hp: int = u["hp"]
		var uid: int = u["id"]
		var is_selected := uid == _selected_id
		var draw_pos: Vector2 = world_pos + _shake_offsets.get(uid, Vector2.ZERO)
		var uses_orc_sprite: bool = _is_orc_blood_axe(u)

		if is_selected:
			draw_circle(draw_pos, UNIT_RADIUS + 3.0, SELECT_COLOR)

		if uses_orc_sprite:
			_draw_orc_blood_axe(u, draw_pos)
		else:
			var color: Color = GameCatalog.faction_color(faction)
			if _hit_flash.has(uid):
				color = Color(1.0, 0.9, 0.85)
			draw_circle(draw_pos, UNIT_RADIUS, color)
			draw_arc(draw_pos, UNIT_RADIUS, 0, TAU, 16, Color.BLACK, 1.5)

		var font: Font = ThemeDB.fallback_font
		var fsize := 11
		var label := data.unit_name
		var text_size := font.get_string_size(label, HORIZONTAL_ALIGNMENT_LEFT, -1, fsize)
		var name_offset_y: float = -30.0 if uses_orc_sprite else -UNIT_RADIUS - 4.0
		var name_pos := Vector2(draw_pos.x - text_size.x / 2.0, draw_pos.y + name_offset_y)
		draw_string(font, name_pos, label, HORIZONTAL_ALIGNMENT_LEFT, -1, fsize, Color.WHITE)

		var hp_label := str(hp)
		var hp_size := font.get_string_size(hp_label, HORIZONTAL_ALIGNMENT_LEFT, -1, fsize)
		var hp_offset_y: float = 32.0 if uses_orc_sprite else UNIT_RADIUS + 14.0
		var hp_pos := Vector2(draw_pos.x - hp_size.x / 2.0, draw_pos.y + hp_offset_y)
		draw_string(font, hp_pos, hp_label, HORIZONTAL_ALIGNMENT_LEFT, -1, fsize, Color.WHITE)

	for unit_id_variant in _death_visuals.keys():
		var unit_id: int = int(unit_id_variant)
		var death: Dictionary = _death_visuals[unit_id]
		var death_pos: Vector2 = death.get("pos", Vector2.ZERO)
		var draw_pos: Vector2 = death_pos + _shake_offsets.get(unit_id, Vector2.ZERO)
		_draw_orc_blood_axe_death(unit_id, draw_pos)


# ========== 交互 ==========

func _unhandled_input(event: InputEvent) -> void:
	if not event is InputEventMouseButton:
		return
	if event.button_index != MOUSE_BUTTON_LEFT or not event.pressed:
		return

	# 战斗中锁定所有操作（含中立战斗）
	if _in_combat:
		return
	if not _move_visuals.is_empty():
		return
	var numgr := get_parent().get_node_or_null("NeutralUnitManager2D")
	if numgr and numgr.has_method("is_in_combat") and numgr.is_in_combat():
		return

	var cursor := get_global_mouse_position()
	var gpos := _world_to_grid(cursor)
	if not _in_bounds(gpos.x, gpos.y):
		_clear_selection()
		return

	# 检查是否点击了可达格（移动）
	if _selected_id >= 0 and gpos in _reachable_tiles:
		# 检查是否可驻兵建筑
		if _turn_manager:
			var bmgr: Node = get_parent().get_node("BuildingManager2D")
			if bmgr and bmgr.has_method("can_garrison"):
				var b: Dictionary = bmgr.get_building_at(gpos)
				if not b.is_empty():
					var sel_unit := _get_unit_by_id(_selected_id)
					if not sel_unit.is_empty() and bmgr.can_garrison(b["id"], _turn_manager.current_player, _get_unit_data(sel_unit).category):
						_garrison_unit_to(b["id"], gpos)
						return
		_move_selected_to(gpos)
		return

	# 检查是否点击了相邻敌方单位（进入决斗）
	if _selected_id >= 0:
		var src := _get_unit_by_id(_selected_id)
		if not src.is_empty():
			var target := get_visible_unit_at(gpos)
			if not target.is_empty() and target["faction"] != src["faction"]:
				# 中立单位（faction == -1）→ 调用 NeutralUnitManager2D 战斗
				if _is_adjacent(src["grid_pos"], target["grid_pos"]):
					if target["faction"] == -1:
						numgr = get_parent().get_node_or_null("NeutralUnitManager2D")
						if numgr and numgr.has_method("engage_combat") and not numgr.is_in_combat():
							numgr.engage_combat(_selected_id, target["id"])
							return
					else:
						_initiate_combat(_selected_id, target["id"])
						return
				elif target["faction"] != -1 and _try_move_to_attack(src, target):
					return

			# 追加：检查中立单位
			if target.is_empty():
				if numgr and numgr.has_method("get_neutral_unit_at"):
					var ntarget: Dictionary = numgr.get_neutral_unit_at(gpos)
					if not ntarget.is_empty() and _is_adjacent(src["grid_pos"], ntarget.get("grid_pos", Vector2i(-1, -1))):
						var behavior: String = ""
						if numgr.has_method("get_ai_data_for"):
							behavior = numgr.get_ai_data_for(ntarget["id"]).get("behavior", "")
						if behavior == "hidden_trader":
							# 花费 1 AP 触发交易
							if _turn_manager and _turn_manager.spend_ap(_turn_manager.current_player, 1):
								numgr.remove_neutral_unit(ntarget["id"])
								hidden_trader_discovered.emit(_turn_manager.current_player)
								return
						else:
							if numgr.has_method("engage_combat") and not numgr.is_in_combat():
								numgr.engage_combat(_selected_id, ntarget["id"])
								return


	# 检查是否点击了己方单位（选择）
	var unit := get_visible_unit_at(gpos)
	if not unit.is_empty():
		var current_player := 0
		if _turn_manager:
			current_player = _turn_manager.current_player
		if unit["faction"] == current_player:
			_select_unit(unit["id"])
			return

	# 检查是否点击了中立单位（选择查看数值）
	if unit.is_empty():
		if numgr and numgr.has_method("get_unit_at_world"):
			var neutral: Dictionary = numgr.get_unit_at_world(cursor)
			if not neutral.is_empty() and numgr.has_method("select_neutral"):
				numgr.select_neutral(neutral["id"])
				return

	# 点击其他 → 取消选择
	_clear_selection()


func _select_unit(uid: int) -> void:
	_clear_selection()
	_selected_id = uid
	for u in _units:
		if u["id"] == uid:
			_reachable_tiles = _calc_reachable(u)
			unit_selected.emit(_make_unit_view(u))
			break
	queue_redraw()


func _clear_selection() -> void:
	_selected_id = -1
	_reachable_tiles = []
	_emit_action_preview({})
	selection_cleared.emit()
	queue_redraw()


# ========== 移动 ==========


func _update_action_preview() -> void:
	if _selected_id < 0 or _in_combat or not _move_visuals.is_empty():
		_emit_action_preview({})
		return
	var attacker: Dictionary = _get_unit_by_id(_selected_id)
	if attacker.is_empty():
		_emit_action_preview({})
		return
	var cursor := get_global_mouse_position()
	var gpos := _world_to_grid(cursor)
	if not _in_bounds(gpos.x, gpos.y):
		_emit_action_preview({})
		return
	var target: Dictionary = get_visible_unit_at(gpos)
	if target.is_empty() or target["faction"] == attacker["faction"] or target["faction"] == -1:
		_emit_action_preview({})
		return
	_emit_action_preview(_make_attack_preview(attacker, target))


func _emit_action_preview(preview: Dictionary) -> void:
	var key := ""
	if not preview.is_empty():
		key = JSON.stringify(preview)
	if key == _last_action_preview_key:
		return
	_last_action_preview_key = key
	_current_action_preview = preview.duplicate(true)
	action_preview_changed.emit(preview)
	queue_redraw()


func _draw_action_preview_highlight() -> void:
	if _current_action_preview.is_empty():
		return
	var approach_pos: Vector2i = _current_action_preview.get("approach_pos", Vector2i(-1, -1))
	if approach_pos.x < 0:
		return
	var center: Vector2 = _grid_to_world(approach_pos.x, approach_pos.y)
	var rect := Rect2(center - Vector2(tile_size, tile_size) * 0.5, Vector2(tile_size, tile_size))
	var can_attack: bool = bool(_current_action_preview.get("can_attack", false))
	var color: Color = ATTACK_APPROACH_OK_COLOR if can_attack else ATTACK_APPROACH_BLOCKED_COLOR
	draw_rect(rect.grow(-2.0), color, true)
	draw_rect(rect.grow(-2.0), Color(color.r, color.g, color.b, 0.92), false, 2.0)


func _make_attack_preview(attacker: Dictionary, target: Dictionary) -> Dictionary:
	var attacker_data: UnitData = _get_unit_data(attacker)
	var target_data: UnitData = _get_unit_data(target)
	var from: Vector2i = attacker.get("grid_pos", Vector2i.ZERO)
	var target_pos: Vector2i = target.get("grid_pos", Vector2i.ZERO)
	var preview := {
		"visible": true,
		"action": "attack",
		"attacker_name": attacker_data.unit_name,
		"target_name": target_data.unit_name,
		"target_pos": target_pos,
		"approach_pos": Vector2i(-1, -1),
		"ap_cost": 0,
		"can_attack": false,
		"reason": "",
	}

	if _is_adjacent(from, target_pos):
		preview["approach_pos"] = from
		preview["can_attack"] = true
		preview["reason"] = "已相邻，可以攻击"
		return preview

	var approach_tile: Vector2i = _find_attack_approach_tile(attacker, target)
	if approach_tile.x < 0:
		preview["reason"] = "没有可用的接敌格"
		return preview

	var steps: int = _calc_path_length(from, approach_tile)
	var ap_cost: int = _get_movement_ap_cost(attacker, steps)
	preview["approach_pos"] = approach_tile
	preview["ap_cost"] = ap_cost
	if steps <= 0:
		preview["reason"] = "无法到达接敌格"
		return preview

	var current_ap := 0
	if _turn_manager:
		current_ap = int(_turn_manager.get_ap(_turn_manager.current_player))
	if _turn_manager and ap_cost > current_ap:
		preview["reason"] = "AP 不足"
		return preview

	preview["can_attack"] = true
	preview["reason"] = "移动到接敌格后攻击"
	return preview


func _move_selected_to(target: Vector2i) -> void:
	if _selected_id < 0:
		return

	for u in _units:
		if u["id"] == _selected_id:
			var from: Vector2i = u["grid_pos"]
			var steps := _calc_path_length(from, target)
			var ap_cost: int = _get_movement_ap_cost(u, steps)
			if steps <= 0:
				break

			# 扣 AP（1 AP/步，原型简化）
			if _turn_manager:
				var ok: bool = _turn_manager.spend_ap(_turn_manager.current_player, ap_cost)
				if not ok:
					# AP 不足，回退
					break

			u["grid_pos"] = target
			u["has_moved"] = true
			_start_move_visual(u["id"], from, target)

			# 移动后揭示视野
			var data: UnitData = _get_unit_data(u)
			var fog_mgr = get_parent().get_node("FogOfWar2D")
			if fog_mgr:
				var cp: int = _turn_manager.current_player
				fog_mgr.reveal_area(cp, target.x, target.y, _get_unit_vision_value(u))

			# 通知中立单位管理器重绘（新揭示区域的中立单位立即显示）
			var numgr = get_parent().get_node_or_null("NeutralUnitManager2D")
			if numgr:
				numgr.queue_redraw()

			# 工人到达资源格 → 通知采集管理器
			var gather_mgr = get_parent().get_node("GatheringManager2D")
			if gather_mgr and gather_mgr.has_method("start_gather"):
				var res_mgr = get_parent().get_node("ResourceManager2D")
				if res_mgr and res_mgr.has_method("get_gather_result"):
					var gather_info: Array = res_mgr.get_gather_result(target.x, target.y)
					if _can_unit_gather(data, gather_info):
						gather_mgr.start_gather(u["faction"], target, gather_info)

			# 移动后自动取消选择
			_clear_selection()
			queue_redraw()
			break


func _try_move_to_attack(attacker: Dictionary, target: Dictionary) -> bool:
	if attacker.is_empty() or target.is_empty():
		return false
	var attacker_id: int = int(attacker.get("id", -1))
	if attacker_id != _selected_id:
		return false
	var from: Vector2i = attacker.get("grid_pos", Vector2i.ZERO)
	var target_pos: Vector2i = target.get("grid_pos", Vector2i.ZERO)
	var approach_tile: Vector2i = _find_attack_approach_tile(attacker, target)
	if approach_tile.x < 0:
		return false
	var steps: int = _calc_path_length(from, approach_tile)
	if steps <= 0:
		return false
	var ap_cost: int = _get_movement_ap_cost(attacker, steps)
	if _turn_manager:
		var ok: bool = _turn_manager.spend_ap(_turn_manager.current_player, ap_cost)
		if not ok:
			return false

	for u in _units:
		if u["id"] == attacker_id:
			u["grid_pos"] = approach_tile
			u["has_moved"] = true
			_pending_attack_after_move[attacker_id] = int(target.get("id", -1))
			_start_move_visual(attacker_id, from, approach_tile)
			var data: UnitData = _get_unit_data(u)
			var fog_mgr = get_parent().get_node("FogOfWar2D")
			if fog_mgr and _turn_manager:
				fog_mgr.reveal_area(_turn_manager.current_player, approach_tile.x, approach_tile.y, _get_unit_vision_value(u))
			_reachable_tiles = []
			queue_redraw()
			return true
	return false


func _find_attack_approach_tile(attacker: Dictionary, target: Dictionary) -> Vector2i:
	var from: Vector2i = attacker.get("grid_pos", Vector2i.ZERO)
	var target_pos: Vector2i = target.get("grid_pos", Vector2i.ZERO)
	var candidates: Array[Vector2i] = _get_attack_approach_candidates(from, target_pos)
	var reachable: Array = _calc_reachable(attacker)
	for candidate in candidates:
		if candidate in reachable:
			return candidate
	return Vector2i(-1, -1)


func _get_attack_approach_candidates(from: Vector2i, target_pos: Vector2i) -> Array[Vector2i]:
	var dirs: Array[Vector2i] = [Vector2i(0, -1), Vector2i(0, 1), Vector2i(-1, 0), Vector2i(1, 0)]
	var preferred := Vector2i.ZERO
	var dx: int = from.x - target_pos.x
	var dy: int = from.y - target_pos.y
	if absi(dy) >= absi(dx) and dy != 0:
		var y_dir := 1
		if dy < 0:
			y_dir = -1
		preferred = Vector2i(0, y_dir)
	elif dx != 0:
		var x_dir := 1
		if dx < 0:
			x_dir = -1
		preferred = Vector2i(x_dir, 0)

	var result: Array[Vector2i] = []
	if preferred != Vector2i.ZERO:
		result.append(target_pos + preferred)
	for dir in dirs:
		if dir == preferred:
			continue
		result.append(target_pos + dir)
	return result


func _start_move_visual(unit_id: int, from: Vector2i, to: Vector2i) -> void:
	if not is_inside_tree():
		return
	_move_visuals[unit_id] = {
		"from": _grid_to_world(from.x, from.y),
		"to": _grid_to_world(to.x, to.y),
		"t": 0.0,
		"flip_x": to.x < from.x,
	}
	var tween := create_tween()
	tween.set_trans(Tween.TRANS_SINE)
	tween.set_ease(Tween.EASE_IN_OUT)
	tween.tween_method(_set_move_visual_t.bind(unit_id), 0.0, 1.0, MOVE_VISUAL_DURATION)
	tween.tween_callback(_finish_move_visual.bind(unit_id))


func _set_move_visual_t(t: float, unit_id: int) -> void:
	if not _move_visuals.has(unit_id):
		return
	var visual: Dictionary = _move_visuals[unit_id]
	visual["t"] = clampf(t, 0.0, 1.0)
	_move_visuals[unit_id] = visual
	queue_redraw()


func _finish_move_visual(unit_id: int) -> void:
	_move_visuals.erase(unit_id)
	if _pending_attack_after_move.has(unit_id):
		var defender_id: int = int(_pending_attack_after_move.get(unit_id, -1))
		_pending_attack_after_move.erase(unit_id)
		var attacker: Dictionary = _get_unit_by_id(unit_id)
		var defender: Dictionary = _get_unit_by_id(defender_id)
		if not attacker.is_empty() and not defender.is_empty():
			if _is_adjacent(attacker["grid_pos"], defender["grid_pos"]):
				_initiate_combat(unit_id, defender_id)
				return
	queue_redraw()


func _get_unit_draw_world_pos(unit: Dictionary) -> Vector2:
	var uid: int = unit.get("id", -1)
	if _move_visuals.has(uid):
		var visual: Dictionary = _move_visuals[uid]
		var from: Vector2 = visual.get("from", Vector2.ZERO)
		var to: Vector2 = visual.get("to", Vector2.ZERO)
		var t: float = float(visual.get("t", 1.0))
		return from.lerp(to, t)
	var pos: Vector2i = unit["grid_pos"]
	return _grid_to_world(pos.x, pos.y)


func _has_orc_blood_axe_units() -> bool:
	for unit in _units:
		if _is_orc_blood_axe(unit):
			return true
	return false


func _is_orc_blood_axe(unit: Dictionary) -> bool:
	return str(unit.get("template_id", "")) == ORC_BLOOD_AXE_TEMPLATE_ID


func _draw_orc_blood_axe(unit: Dictionary, draw_pos: Vector2) -> void:
	var uid: int = unit.get("id", -1)
	var is_moving: bool = _move_visuals.has(uid)
	var is_hurt: bool = _hurt_visuals.has(uid)
	var is_attacking: bool = _attack_visuals.has(uid)
	var texture: Texture2D = ORC_BLOOD_AXE_IDLE_TEXTURE
	var frame_count: int = ORC_BLOOD_AXE_IDLE_FRAMES
	if is_hurt:
		texture = ORC_BLOOD_AXE_HURT_TEXTURE
		frame_count = ORC_BLOOD_AXE_HURT_FRAMES
	elif is_attacking:
		texture = ORC_BLOOD_AXE_ATTACK_TEXTURE
		frame_count = ORC_BLOOD_AXE_ATTACK_FRAMES
	elif is_moving:
		texture = ORC_BLOOD_AXE_WALK_TEXTURE
		frame_count = ORC_BLOOD_AXE_WALK_FRAMES
	var frame: int = 0
	if is_hurt:
		var hurt: Dictionary = _hurt_visuals.get(uid, {})
		var hurt_t: float = float(hurt.get("t", 0.0))
		frame = clampi(int(floor(hurt_t * float(frame_count))), 0, frame_count - 1)
	elif is_attacking:
		var attack: Dictionary = _attack_visuals.get(uid, {})
		var attack_t: float = float(attack.get("t", 0.0))
		frame = clampi(int(floor(attack_t * float(frame_count))), 0, frame_count - 1)
	elif is_moving:
		var visual: Dictionary = _move_visuals.get(uid, {})
		var t: float = float(visual.get("t", 0.0))
		frame = clampi(int(floor(t * float(frame_count))), 0, frame_count - 1)
	else:
		var seconds: float = float(Time.get_ticks_msec()) / 1000.0
		frame = int(floor(seconds / ORC_BLOOD_AXE_IDLE_FRAME_SECONDS)) % frame_count
	var src := Rect2(Vector2(ORC_BLOOD_AXE_FRAME_SIZE.x * frame, 0.0), ORC_BLOOD_AXE_FRAME_SIZE)
	var dst := Rect2(-ORC_BLOOD_AXE_DRAW_SIZE * 0.5, ORC_BLOOD_AXE_DRAW_SIZE)
	var modulate := Color.WHITE
	var flip_x: bool = bool(_unit_facing_flip.get(uid, false))
	if is_attacking:
		var attack_visual: Dictionary = _attack_visuals.get(uid, {})
		flip_x = bool(attack_visual.get("flip_x", flip_x))
	elif is_moving:
		var move_visual: Dictionary = _move_visuals.get(uid, {})
		flip_x = bool(move_visual.get("flip_x", flip_x))
	draw_set_transform(draw_pos, 0.0, Vector2(-1.0, 1.0) if flip_x else Vector2.ONE)
	draw_texture_rect_region(texture, dst, src, modulate)
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)


func _draw_orc_blood_axe_death(unit_id: int, draw_pos: Vector2) -> void:
	var death: Dictionary = _death_visuals.get(unit_id, {})
	var t: float = float(death.get("t", 0.0))
	var frame: int = clampi(int(floor(t * float(ORC_BLOOD_AXE_DEATH_FRAMES))), 0, ORC_BLOOD_AXE_DEATH_FRAMES - 1)
	var src := Rect2(Vector2(ORC_BLOOD_AXE_FRAME_SIZE.x * frame, 0.0), ORC_BLOOD_AXE_FRAME_SIZE)
	var dst := Rect2(-ORC_BLOOD_AXE_DRAW_SIZE * 0.5, ORC_BLOOD_AXE_DRAW_SIZE)
	var flip_x: bool = bool(death.get("flip_x", false))
	draw_set_transform(draw_pos, 0.0, Vector2(-1.0, 1.0) if flip_x else Vector2.ONE)
	draw_texture_rect_region(ORC_BLOOD_AXE_DEATH_TEXTURE, dst, src, Color.WHITE)
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)


func _trigger_hidden_trader_if_adjacent(target: Vector2i, faction: int) -> void:
	"""检查目标格相邻是否有隐藏商队，有则触发交易"""
	var numgr := get_parent().get_node_or_null("NeutralUnitManager2D")
	if not numgr or not numgr.has_method("get_neutral_unit_at"):
		return

	var dirs := [Vector2i(0, -1), Vector2i(0, 1), Vector2i(-1, 0), Vector2i(1, 0)]
	for dir in dirs:
		var adj := Vector2i(target.x + dir.x, target.y + dir.y)
		var nu: Dictionary = numgr.get_neutral_unit_at(adj)
		if not nu.is_empty():
			var ai: Dictionary = numgr.get_ai_data_for(nu.get("id", -1))
			if ai.get("behavior", "") == "hidden_trader":
				print("[中立] 发现隐藏商队，触发交易 (阵营 %d)" % faction)
				numgr.remove_neutral_unit(nu["id"])
				hidden_trader_discovered.emit(faction)
				return

func _calc_reachable(unit: Dictionary) -> Array:
	## BFS 从单位位置出发，max_depth = move_max
	var from: Vector2i = unit["grid_pos"]
	var data: UnitData = _get_unit_data(unit)
	var max_steps: int = data.move_max
	var result: Array = []

	var visited := {}
	var depth := {}
	var queue: Array = [from]
	visited[from] = true
	depth[from] = 0

	var dirs := [Vector2i(0, -1), Vector2i(0, 1), Vector2i(-1, 0), Vector2i(1, 0)]

	while queue.size() > 0:
		var pos: Vector2i = queue.pop_front()
		var d: int = depth[pos]

		if d >= max_steps:
			continue

		for dir in dirs:
			var nx: int = pos.x + dir.x
			var ny: int = pos.y + dir.y
			var nkey := Vector2i(nx, ny)

			if not _in_bounds(nx, ny):
				continue
			if visited.has(nkey):
				continue
			if not _is_tile_passable(nx, ny):
				continue
			if not _is_tile_empty(nx, ny):
				# 检查是否可驻兵建筑（资源建筑、同阵营、有容量）
				var bmgr: Node = get_parent().get_node("BuildingManager2D")
				if bmgr and bmgr.has_method("get_building_at") and bmgr.has_method("max_garrison"):
					var b: Dictionary = bmgr.get_building_at(Vector2i(nx, ny))
					if not b.is_empty() and b["faction"] == unit["faction"]:
						if not b["data"].production.is_empty():
							if b.get("garrison", []).size() < bmgr.max_garrison(b):
								visited[nkey] = true
								result.append(nkey)
				continue

			visited[nkey] = true
			depth[nkey] = d + 1
			result.append(nkey)
			queue.append(nkey)

	return result


func _calc_path_length(from: Vector2i, to: Vector2i) -> int:
	## 简化的 BFS 寻路，返回最短步数，不可达返回 -1
	if from == to:
		return 0

	var visited := {}
	var queue: Array = [from]
	var dist := { from: 0 }
	visited[from] = true

	var dirs := [Vector2i(0, -1), Vector2i(0, 1), Vector2i(-1, 0), Vector2i(1, 0)]

	while queue.size() > 0:
		var pos: Vector2i = queue.pop_front()
		var d: int = dist[pos]

		for dir in dirs:
			var nx: int = pos.x + dir.x
			var ny: int = pos.y + dir.y
			var nkey := Vector2i(nx, ny)

			if not _in_bounds(nx, ny):
				continue
			if visited.has(nkey):
				continue
			if not _is_tile_passable(nx, ny):
				continue

			if nkey == to:
				return d + 1

			visited[nkey] = true
			dist[nkey] = d + 1
			queue.append(nkey)

	return -1


# ========== 回合集成 ==========

func _on_player_turn_started(player: int) -> void:
	# 重置该玩家单位的移动/攻击状态
	for u in _units:
		if u["faction"] == player:
			u["has_moved"] = false
			u["has_attacked"] = false
			_tick_unit_statuses(u)

	_clear_selection()


func _on_player_turn_ended(player: int) -> void:
	_clear_selection()


# ========== 驻兵 ==========

func _garrison_unit_to(building_id: int, target: Vector2i) -> void:
	## 将选中单位入驻到建筑内
	if _selected_id < 0:
		return

	for u in _units:
		if u["id"] == _selected_id:
			var from: Vector2i = u["grid_pos"]
			var steps := _calc_path_length(from, target)
			if steps <= 0:
				return

			# 扣 AP
			if _turn_manager:
				var ok: bool = _turn_manager.spend_ap(_turn_manager.current_player, steps)
				if not ok:
					return

			# 入驻建筑
			var bmgr: Node = get_parent().get_node("BuildingManager2D")
			if bmgr and bmgr.has_method("garrison_unit"):
				bmgr.garrison_unit(building_id, u)

			# 从单位列表移除
			_units.erase(u)
			_clear_selection()
			queue_redraw()
			return


# ========== 战斗系统 ==========

func _initiate_combat(attacker_id: int, defender_id: int) -> void:
	## 发起决斗：创建 1 秒间隔 Timer，轮流攻击直至死亡
	_in_combat = true
	_combat_data = {
		"unit_a_id": attacker_id,
		"unit_b_id": defender_id,
		"next_attacker_id": attacker_id,
	}
	combat_started.emit()

	# 创建并启动 Timer
	_combat_timer = Timer.new()
	_combat_timer.wait_time = 1.0
	_combat_timer.timeout.connect(_combat_tick)
	add_child(_combat_timer)
	_combat_timer.start()

	# 先手立即出拳（不等待 1 秒）
	_combat_tick()


func _combat_tick() -> void:
	## 当前攻击方给对方造成 ATK 点伤害，检查死亡，否则切换回合
	var cur_attacker_id: int = _combat_data["next_attacker_id"]
	var unit_a: Dictionary = _get_unit_by_id(_combat_data["unit_a_id"])
	var unit_b: Dictionary = _get_unit_by_id(_combat_data["unit_b_id"])

	# 任一单位已被移除（异常保护）
	if unit_a.is_empty() or unit_b.is_empty():
		_end_combat(-1)
		return

	# 确定攻守方
	var attacker: Dictionary
	var defender: Dictionary
	if cur_attacker_id == unit_a["id"]:
		attacker = unit_a
		defender = unit_b
	else:
		attacker = unit_b
		defender = unit_a

	# 造成伤害
	var raw_dmg: int = _get_unit_attack_value(attacker)
	var reduction: int = _get_unit_damage_reduction(defender)
	var dmg: int = maxi(1, raw_dmg - reduction) if raw_dmg > 0 else 0
	_play_attack_effect(attacker, defender)
	defender["hp"] -= dmg
	if dmg > 0:
		_try_apply_scout_poison_weaken(attacker, defender)

	# 受击视觉效果
	_play_hit_effect(defender["id"], defender["grid_pos"], dmg)

	# 刷新 UI（重发选中单位数据）
	var selected := _get_unit_by_id(_selected_id)
	if not selected.is_empty():
		unit_selected.emit(_make_unit_view(selected))

	queue_redraw()

	# 检查是否死亡
	if defender["hp"] <= 0:
		_end_combat(attacker["id"], attacker["grid_pos"], defender["grid_pos"])
		return

	# 交替攻击方
	_combat_data["next_attacker_id"] = defender["id"]


func _end_combat(winner_id: int, attacker_pos: Vector2i = Vector2i(-1, -1), loser_pos: Vector2i = Vector2i(-1, -1)) -> void:
	## 结束决斗：停止 Timer，移除死亡单位，清除状态
	if _combat_timer:
		_combat_timer.stop()
		_combat_timer.queue_free()
		_combat_timer = null

	# 找出失败方并从单位列表移除
	var loser_id: int = -1
	if _combat_data.get("unit_a_id", -1) == winner_id:
		loser_id = _combat_data.get("unit_b_id", -1)
	elif _combat_data.get("unit_b_id", -1) == winner_id:
		loser_id = _combat_data.get("unit_a_id", -1)

	if loser_id >= 0:
		for i in range(_units.size() - 1, -1, -1):
			if _units[i]["id"] == loser_id:
				var loser: Dictionary = _units[i]
				var winner: Dictionary = _get_unit_by_id(winner_id)
				if not winner.is_empty():
					unit_killed.emit(int(winner.get("faction", -1)), int(loser.get("faction", -1)), loser.duplicate())
					_apply_kill_food_reward(winner)
				if _is_orc_blood_axe(loser):
					_start_death_visual(loser_id, loser["grid_pos"], attacker_pos, loser_pos)
				_move_visuals.erase(loser_id)
				_hurt_visuals.erase(loser_id)
				_attack_visuals.erase(loser_id)
				_pending_attack_after_move.erase(loser_id)
				_units.remove_at(i)
				break

	if _death_visuals.has(loser_id):
		_combat_data = {}
		_clear_selection()
		return

	_finish_combat_state()


# ========== 战斗视觉效果 ==========


func _play_attack_effect(attacker: Dictionary, defender: Dictionary) -> void:
	if attacker.is_empty() or defender.is_empty():
		return
	if not _is_orc_blood_axe(attacker):
		return
	var attacker_pos: Vector2i = attacker.get("grid_pos", Vector2i.ZERO)
	var defender_pos: Vector2i = defender.get("grid_pos", Vector2i.ZERO)
	var flip_x: bool = defender_pos.x < attacker_pos.x
	var attacker_id: int = int(attacker.get("id", -1))
	_unit_facing_flip[attacker_id] = flip_x
	_start_attack_visual(attacker_id, flip_x)


func _start_attack_visual(unit_id: int, flip_x: bool) -> void:
	if not is_inside_tree():
		return
	_attack_visuals[unit_id] = {"t": 0.0, "flip_x": flip_x}
	var tween := create_tween()
	tween.set_trans(Tween.TRANS_SINE)
	tween.set_ease(Tween.EASE_OUT)
	tween.tween_method(_set_attack_visual_t.bind(unit_id), 0.0, 1.0, ORC_BLOOD_AXE_ATTACK_DURATION)
	tween.tween_callback(_finish_attack_visual.bind(unit_id))


func _set_attack_visual_t(t: float, unit_id: int) -> void:
	if not _attack_visuals.has(unit_id):
		return
	var visual: Dictionary = _attack_visuals[unit_id]
	visual["t"] = clampf(t, 0.0, 1.0)
	_attack_visuals[unit_id] = visual
	queue_redraw()


func _finish_attack_visual(unit_id: int) -> void:
	_attack_visuals.erase(unit_id)
	queue_redraw()


func _start_death_visual(unit_id: int, grid_pos: Vector2i, attacker_pos: Vector2i, loser_pos: Vector2i) -> void:
	if not is_inside_tree():
		return
	var flip_x: bool = bool(_unit_facing_flip.get(unit_id, false))
	if attacker_pos.x >= 0 and loser_pos.x >= 0:
		flip_x = attacker_pos.x < loser_pos.x
	_unit_facing_flip[unit_id] = flip_x
	_death_visuals[unit_id] = {
		"pos": _grid_to_world(grid_pos.x, grid_pos.y),
		"t": 0.0,
		"flip_x": flip_x,
	}
	var tween := create_tween()
	tween.set_trans(Tween.TRANS_SINE)
	tween.set_ease(Tween.EASE_OUT)
	tween.tween_method(_set_death_visual_t.bind(unit_id), 0.0, 1.0, ORC_BLOOD_AXE_DEATH_DURATION)
	tween.tween_callback(_finish_death_visual.bind(unit_id))


func _set_death_visual_t(t: float, unit_id: int) -> void:
	if not _death_visuals.has(unit_id):
		return
	var visual: Dictionary = _death_visuals[unit_id]
	visual["t"] = clampf(t, 0.0, 1.0)
	_death_visuals[unit_id] = visual
	queue_redraw()


func _finish_death_visual(unit_id: int) -> void:
	_death_visuals.erase(unit_id)
	_shake_offsets.erase(unit_id)
	_unit_facing_flip.erase(unit_id)
	if _in_combat and _combat_data.is_empty():
		_finish_combat_state()
	queue_redraw()


func _finish_combat_state() -> void:
	_in_combat = false
	_combat_data = {}
	combat_ended.emit()
	_clear_selection()

func _play_hit_effect(unit_id: int, grid_pos: Vector2i, damage: int) -> void:
	if not is_inside_tree():
		return
	var unit: Dictionary = _get_unit_by_id(unit_id)
	if not unit.is_empty() and _is_orc_blood_axe(unit):
		_start_hurt_visual(unit_id)
	else:
		_hit_flash[unit_id] = true
	_hit_shake(unit_id)
	_show_damage_text(grid_pos, damage)
	queue_redraw()

	if _hit_flash.has(unit_id):
		await get_tree().create_timer(0.15).timeout
		if not is_inside_tree():
			return
		_hit_flash.erase(unit_id)
		queue_redraw()


func _start_hurt_visual(unit_id: int) -> void:
	_hurt_visuals[unit_id] = {"t": 0.0}
	var tween := create_tween()
	tween.set_trans(Tween.TRANS_SINE)
	tween.set_ease(Tween.EASE_OUT)
	tween.tween_method(_set_hurt_visual_t.bind(unit_id), 0.0, 1.0, ORC_BLOOD_AXE_HURT_DURATION)
	tween.tween_callback(_finish_hurt_visual.bind(unit_id))


func _set_hurt_visual_t(t: float, unit_id: int) -> void:
	if not _hurt_visuals.has(unit_id):
		return
	var visual: Dictionary = _hurt_visuals[unit_id]
	visual["t"] = clampf(t, 0.0, 1.0)
	_hurt_visuals[unit_id] = visual
	queue_redraw()


func _finish_hurt_visual(unit_id: int) -> void:
	_hurt_visuals.erase(unit_id)
	queue_redraw()

func _hit_shake(unit_id: int) -> void:
	## 受击震动：随机偏移 → 快速衰减归零（~0.12s）
	_shake_offsets[unit_id] = Vector2.ZERO
	var tween := create_tween()
	tween.set_ease(Tween.EASE_OUT)
	tween.tween_method(_tween_shake.bind(unit_id), 1.0, 0.0, 0.12)


func _tween_shake(amount: float, unit_id: int) -> void:
	## Tween 回调：每帧生成随机偏移，幅度随 amount 衰减
	if amount <= 0.0:
		_shake_offsets.erase(unit_id)
	else:
		_shake_offsets[unit_id] = Vector2(
			randf_range(-3.0, 3.0),
			randf_range(-2.0, 2.0)
		) * amount
	queue_redraw()


func _show_damage_text(grid_pos: Vector2i, damage: int) -> void:
	## 在单位位置创建红色 "-N" 浮动数字，向上飘散消失
	var label := Label.new()
	label.text = "-%d" % damage
	label.add_theme_color_override("font_color", Color(1.0, 0.2, 0.1))
	label.add_theme_font_size_override("font_size", 16)
	label.add_theme_color_override("font_shadow_color", Color.BLACK)
	add_child(label)

	var world_pos: Vector2 = _grid_to_world(grid_pos.x, grid_pos.y)
	label.position = Vector2(world_pos.x - 10, world_pos.y - 24)
	label.z_index = 10

	var tween := create_tween()
	tween.set_trans(Tween.TRANS_SINE)
	tween.tween_property(label, "position", label.position + Vector2(randf_range(-20.0, 20.0), -40.0), 0.8)
	tween.parallel().tween_property(label, "modulate:a", 0.0, 0.8)
	tween.tween_callback(label.queue_free)


func is_in_combat() -> bool:
	return _in_combat


func notify_combat_started() -> void:
	## 公开接口：通知 unit_manager 进入战斗状态（供 NeutralUnitManager2D 调用）
	_in_combat = true


func notify_combat_ended(re_select_id: int = -1) -> void:
	## 公开接口：通知 unit_manager 战斗结束（供 NeutralUnitManager2D 调用）
	## re_select_id >= 0 时自动选中该单位
	_in_combat = false
	_combat_data = {}
	if re_select_id >= 0:
		_select_unit(re_select_id)
	else:
		_clear_selection()


func play_hit_effect_at(grid_pos: Vector2i, damage: int, unit_id: int = -1) -> void:
	## 公开接口：在指定格播放受击视觉效果（供 NeutralUnitManager2D 调用）
	## 传入 unit_id 时触发完整效果（闪白 + shake + 飘字）
	if unit_id >= 0:
		_play_hit_effect(unit_id, grid_pos, damage)
	else:
		_show_damage_text(grid_pos, damage)


func remove_unit_by_id(uid: int) -> void:
	## 公开接口：按 ID 移除单位（供 NeutralUnitManager2D 战斗后调用）
	for i in range(_units.size() - 1, -1, -1):
		if _units[i]["id"] == uid:
			_move_visuals.erase(uid)
			_hurt_visuals.erase(uid)
			_attack_visuals.erase(uid)
			_death_visuals.erase(uid)
			_unit_facing_flip.erase(uid)
			_pending_attack_after_move.erase(uid)
			_units.remove_at(i)
			break
	queue_redraw()


func get_unit_atk_value(uid: int) -> int:
	## 公开接口：获取单位的攻击力（供 NeutralUnitManager2D 战斗使用）
	var unit := _get_unit_by_id(uid)
	if unit.is_empty():
		return 0
	return _get_unit_attack_value(unit)



func _get_unit_vision_value(unit: Dictionary) -> int:
	var data: UnitData = _get_unit_data(unit)
	var bonus: int = _get_building_effect_modifier(unit, BuildingEffectService.MOD_VISION_BONUS)
	bonus += _get_technology_modifier_for_unit(unit, "unit_vision_bonus")
	if data.category == UnitData.UnitCategory.SCOUT:
		bonus += _get_technology_modifier_for_unit(unit, "scout_vision_bonus")
	return maxi(0, data.vision + bonus)


func _get_unit_attack_value(unit: Dictionary) -> int:
	var data: UnitData = _get_unit_data(unit)
	var bonus: int = _get_building_effect_modifier(unit, BuildingEffectService.MOD_ATTACK_BONUS)
	if data.category == UnitData.UnitCategory.GUARD or "melee" in data.tags:
		bonus += _get_technology_modifier_for_unit(unit, "melee_attack_bonus")
	if "light" in data.tags or data.category == UnitData.UnitCategory.SCOUT:
		bonus += _get_technology_modifier_for_unit(unit, "light_unit_attack_bonus")
	if int(unit.get("faction", -1)) == 2:
		bonus += _get_technology_modifier_for_unit(unit, "orc_lord_military_bonus")
	var penalty: int = 0
	var statuses: Dictionary = unit.get("statuses", {})
	if int(statuses.get("poison_weakened_turns", 0)) > 0:
		penalty += 1
	return maxi(0, data.atk + bonus - penalty)


func _get_unit_damage_reduction(unit: Dictionary) -> int:
	var bonus: int = _get_building_effect_modifier(unit, BuildingEffectService.MOD_DAMAGE_REDUCTION)
	bonus += _get_technology_modifier_for_unit(unit, "damage_reduction_bonus")
	return maxi(0, bonus)


func _get_movement_ap_cost(unit: Dictionary, steps: int) -> int:
	if steps <= 0:
		return 0
	var data: UnitData = _get_unit_data(unit)
	var discount := 0
	if data.category == UnitData.UnitCategory.SCOUT or "scout" in data.tags:
		discount += _get_technology_modifier_for_unit(unit, "forest_scout_move_discount")
	return maxi(0, steps - discount)


func _apply_kill_food_reward(winner: Dictionary) -> void:
	var reward: int = _get_technology_modifier_for_unit(winner, "kill_food_reward")
	if reward <= 0:
		return
	var faction: int = int(winner.get("faction", -1))
	var tracker: Node = get_parent().get_node_or_null("ResourceTracker") if is_inside_tree() else null
	if tracker != null and tracker.has_method("add_resource"):
		tracker.add_resource(faction, "food", reward)


func _try_apply_scout_poison_weaken(attacker: Dictionary, defender: Dictionary) -> void:
	var data: UnitData = _get_unit_data(attacker)
	if data.category != UnitData.UnitCategory.SCOUT and not ("scout" in data.tags):
		return
	var turns: int = _get_technology_modifier_for_unit(attacker, "scout_poison_weaken_turns")
	if turns <= 0:
		return
	var statuses: Dictionary = defender.get("statuses", {})
	statuses["poison_weakened_turns"] = maxi(int(statuses.get("poison_weakened_turns", 0)), turns)
	defender["statuses"] = statuses


func _tick_unit_statuses(unit: Dictionary) -> void:
	var statuses: Dictionary = unit.get("statuses", {})
	if statuses.is_empty():
		return
	if statuses.has("poison_weakened_turns"):
		var turns: int = int(statuses.get("poison_weakened_turns", 0)) - 1
		if turns > 0:
			statuses["poison_weakened_turns"] = turns
		else:
			statuses.erase("poison_weakened_turns")
	unit["statuses"] = statuses


func _get_building_effect_modifier(unit: Dictionary, modifier_key: String) -> int:
	if _building_effect_service == null:
		return 0
	return _building_effect_service.get_modifier_for_unit(_building_manager, unit, modifier_key)


func _get_technology_modifier_for_unit(unit: Dictionary, modifier_key: String) -> int:
	var faction: int = int(unit.get("faction", -1))
	if faction < 0:
		return 0
	if _technology_service == null and is_inside_tree():
		_technology_service = get_parent().get_node_or_null("TechnologyService")
	if _technology_service != null and _technology_service.has_method("get_modifier"):
		return int(_technology_service.call("get_modifier", faction, modifier_key, 0))
	return 0

func add_unit(faction: int, data: UnitData, grid_pos: Vector2i, hp: int = -1) -> int:
	## 公共接口：添加一个单位到地图上（用于驻兵撤出等）
	var spawn_pos: Vector2i = _resolve_spawn_pos(grid_pos)
	if spawn_pos.x < 0:
		print("[Unit] No valid spawn tile near %s for %s." % [str(grid_pos), data.unit_name])
		return -1

	var uid := _next_id
	_next_id += 1
	_units.append({
		"id": uid,
		"data": data,
		"template_id": data.template_id,
		"faction": faction,
		"grid_pos": spawn_pos,
		"hp": hp if hp >= 0 else data.hp_max,
		"has_moved": false,
		"has_attacked": false,
		"statuses": {},
	})
	if spawn_pos != grid_pos:
		print("[Unit] Adjusted spawn %s -> %s for %s." % [str(grid_pos), str(spawn_pos), data.unit_name])
	queue_redraw()
	return uid


func add_unit_from_template(faction: int, template: Resource, grid_pos: Vector2i, hp: int = -1) -> int:
	## Compatibility entry for the template toolkit.
	if template == null:
		return -1
	return add_unit(faction, UnitData.from_template(template), grid_pos, hp)


func get_selected_id() -> int:
	return _selected_id


# ========== 工具 ==========

func _is_tile_passable(gx: int, gy: int) -> bool:
	if _grid_manager and _grid_manager.has_method("get_terrain_at"):
		var t: int = _grid_manager.get_terrain_at(gx, gy)
		return TerrainData.is_passable(t)
	return true


func _get_unit_template(unit: Dictionary) -> Resource:
	if not _template_registry or not _template_registry.has_method("get_unit"):
		return null
	var template_id: String = str(unit.get("template_id", ""))
	if template_id.is_empty() and unit.has("data"):
		var data: UnitData = unit["data"]
		template_id = data.template_id
	if template_id.is_empty():
		return null
	return _template_registry.call("get_unit", template_id)


func _get_unit_data(unit: Dictionary) -> UnitData:
	var template: Resource = _get_unit_template(unit)
	if template != null:
		return UnitData.from_template(template)
	if unit.has("data"):
		return unit["data"]
	return UnitData.new("", UnitData.UnitCategory.SPECIAL, 0, 0, 1, 0, 0)


func _can_unit_gather(data: UnitData, gather_info: Array) -> bool:
	if gather_info.is_empty():
		return false
	if data.category == UnitData.UnitCategory.WORKER:
		return true
	for result in gather_info:
		var entry: Dictionary = result
		if str(entry.get("key", "")) == "food":
			return true
	return false


func _make_unit_view(unit: Dictionary) -> Dictionary:
	var view: Dictionary = unit.duplicate(true)
	view["data"] = _get_unit_data(unit)
	return view


func _is_tile_empty(gx: int, gy: int) -> bool:
	var pos := Vector2i(gx, gy)
	# 单位占用检查
	for u in _units:
		if u["grid_pos"] == pos:
			return false
	# 建筑占用检查
	var bmgr = get_parent().get_node("BuildingManager2D")
	if bmgr and bmgr.is_tile_occupied(gx, gy):
		return false
	# 中立单位占用检查
	var numgr = get_parent().get_node_or_null("NeutralUnitManager2D")
	if numgr and numgr.has_method("get_neutral_unit_at"):
		if not numgr.get_neutral_unit_at(pos).is_empty():
			return false
	return true


func _resolve_spawn_pos(preferred: Vector2i) -> Vector2i:
	if _is_valid_spawn_tile(preferred.x, preferred.y):
		return preferred

	for radius in range(1, SPAWN_SEARCH_RADIUS + 1):
		for dx in range(-radius, radius + 1):
			var dy_abs: int = radius - absi(dx)
			var candidates: Array[Vector2i] = [Vector2i(preferred.x + dx, preferred.y + dy_abs)]
			if dy_abs != 0:
				candidates.append(Vector2i(preferred.x + dx, preferred.y - dy_abs))
			for candidate in candidates:
				if _is_valid_spawn_tile(candidate.x, candidate.y):
					return candidate

	return Vector2i(-1, -1)


func _is_valid_spawn_tile(gx: int, gy: int) -> bool:
	if not _in_bounds(gx, gy):
		return false
	if not _is_tile_passable(gx, gy):
		return false
	if not _is_tile_empty(gx, gy):
		return false
	return true


func _in_bounds(x: int, y: int) -> bool:
	return x >= 0 and x < grid_cols and y >= 0 and y < grid_rows


func _get_unit_by_id(uid: int) -> Dictionary:
	for u in _units:
		if u["id"] == uid:
			return u
	return {}


func _is_adjacent(a: Vector2i, b: Vector2i) -> bool:
	return abs(a.x - b.x) + abs(a.y - b.y) == 1


func _grid_to_world(grid_x: int, grid_y: int) -> Vector2:
	var offset := Vector2(-grid_center.x * tile_size, -grid_center.y * tile_size)
	return Vector2(grid_x * tile_size + offset.x, grid_y * tile_size + offset.y)


func _world_to_grid(world_pos: Vector2) -> Vector2i:
	var offset := Vector2(-grid_center.x * tile_size, -grid_center.y * tile_size)
	var gx := int(roundf((world_pos.x - offset.x) / tile_size))
	var gy := int(roundf((world_pos.y - offset.y) / tile_size))
	return Vector2i(gx, gy)
