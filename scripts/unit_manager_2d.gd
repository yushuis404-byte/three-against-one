extends Node2D
const BuildingEffectServiceScript := preload("res://scripts/services/building_effect_service.gd")
const ORC_BLOOD_AXE_IDLE_TEXTURE: Texture2D = preload("res://assets/texture/character/orc/Blood Axe Warrior/Orc-Idle.png")
const ORC_BLOOD_AXE_WALK_TEXTURE: Texture2D = preload("res://assets/texture/character/orc/Blood Axe Warrior/Orc-Walk.png")
const ORC_BLOOD_AXE_HURT_TEXTURE: Texture2D = preload("res://assets/texture/character/orc/Blood Axe Warrior/Orc-Hurt.png")
const ORC_BLOOD_AXE_ATTACK_TEXTURE: Texture2D = preload("res://assets/texture/character/orc/Blood Axe Warrior/Orc-Attack01.png")
const ORC_BLOOD_AXE_DEATH_TEXTURE: Texture2D = preload("res://assets/texture/character/orc/Blood Axe Warrior/Orc-Death.png")
const ORC_HUNTING_BEAST_TEXTURE: Texture2D = preload("res://assets/units/orc/Hunting-Toothed Beast/Hunting-Beast.png")
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
var _attack_range_tiles: Array[Vector2i] = []
var _throw_range_tiles: Array[Vector2i] = []

var _turn_manager: Node = null
var _grid_manager: Node = null
var _fog_manager: Node = null
var _template_registry: Node = null
var _building_manager: Node = null
var _wall_manager: Node = null
var _technology_service: Node = null
var _building_effect_service = BuildingEffectServiceScript.new()

# 战斗系统
var _in_combat := false
var _combat_timer: Timer = null
var _combat_data: Dictionary = {}  # { unit_a_id, unit_b_id, next_attacker_id }
var _combat_sequence_id: int = 0
var _building_attack_timer: Timer = null
var _building_attack_data: Dictionary = {}
var _combat_choice_panel: Panel = null
var _combat_choice_label: Label = null
var _combat_retreat_button: Button = null
var _combat_engage_button: Button = null
var _move_visuals: Dictionary = {}  # unit_id -> { from: Vector2, to: Vector2, t: float }
var _hurt_visuals: Dictionary = {}  # unit_id -> { t: float }
var _attack_visuals: Dictionary = {}  # unit_id -> { t: float, flip_x: bool }
var _death_visuals: Dictionary = {}  # unit_id -> { pos: Vector2, t: float, flip_x: bool }
var _unit_facing_flip: Dictionary = {}  # unit_id -> bool
var _pending_attack_after_move: Dictionary = {}  # attacker_id -> defender_id
var _throw_beast_source_id: int = -1
var _fog_reveal_mode: bool = false
var _fog_reveal_tiles: Array[Vector2i] = []
var _fog_conceal_mode: bool = false
var _fog_conceal_tiles: Array[Vector2i] = []
var _last_action_preview_key := ""
var _current_action_preview: Dictionary = {}
var _next_warband_id: int = 1
var _warband_selection_leader_id: int = -1
var _warband_selection_ids: Array[int] = []

# 战斗视觉效果
var _hit_flash: Dictionary = {}  # unit_id -> true（闪白状态）
var _shake_offsets: Dictionary = {}  # unit_id -> Vector2（受击偏移）

const SELECT_COLOR := Color(1.0, 1.0, 1.0, 0.8)
const REACHABLE_COLOR := Color(1.0, 1.0, 1.0, 0.25)
const ATTACK_RANGE_COLOR := Color(1.0, 0.18, 0.12, 0.24)
const THROW_RANGE_COLOR := Color(0.1, 0.82, 1.0, 0.25)
const FOG_REVEAL_COLOR := Color(0.25, 1.0, 0.58, 0.22)
const FOG_REVEAL_BORDER_COLOR := Color(0.68, 1.0, 0.78, 0.82)
const FOG_CONCEAL_COLOR := Color(0.38, 0.72, 1.0, 0.22)
const FOG_CONCEAL_BORDER_COLOR := Color(0.62, 0.92, 1.0, 0.82)
const WARBAND_RING_COLOR := Color(1.0, 0.16, 0.08, 0.55)
const WARBAND_AREA_COLOR := Color(1.0, 0.12, 0.06, 0.10)
const WARBAND_COMMAND_COLOR := Color(0.1, 0.55, 1.0, 0.95)
const WARBAND_SELECTION_COLOR := Color(0.1, 0.55, 1.0, 0.55)
const ATTACK_APPROACH_OK_COLOR := Color(0.2, 1.0, 0.35, 0.38)
const ATTACK_APPROACH_BLOCKED_COLOR := Color(1.0, 0.35, 0.18, 0.42)
const UNIT_RADIUS := 8.0
const SPAWN_SEARCH_RADIUS := 8
const MOVE_VISUAL_DURATION := 1.0
const UNIT_ATTACK_INTERVAL := 1.0
const ORC_BLOOD_AXE_TEMPLATE_ID := "unit.orc.guard"
const ORC_SLINGER_TEMPLATE_ID := "unit.orc.slinger"
const ORC_BEAST_TEMPLATE_ID := "unit.orc.scout"
const ELF_FOG_REVEAL_CASTER_TEMPLATE_ID := "unit.elf.scout"
const ELF_FOG_CONCEAL_CASTER_TEMPLATE_ID := "unit.elf.guard"
const SLINGER_THROW_RANGE := 5
const SLINGER_THROW_AP_COST := 1
const FOG_REVEAL_RADIUS := 2
const FOG_REVEAL_AP_COST := 1
const FOG_CONCEAL_RANGE := 6
const FOG_CONCEAL_RADIUS := 2
const FOG_CONCEAL_AP_COST := 1
const FOG_CONCEAL_DURATION_ROUNDS := 5
const FOG_REVEAL_COOLDOWN_KEY := "fog_reveal_cooldown_turns"
const FOG_CONCEAL_COOLDOWN_KEY := "fog_conceal_cooldown_turns"
const RETREAT_HIDDEN_FROM_FACTION_KEY := "retreat_hidden_from_faction"
const RETREAT_UNSELECTABLE_BY_UNIT_KEY := "retreat_unselectable_by_unit_id"
const WARBAND_RADIUS := 3
const WARBAND_MIN_MEMBERS := 3
const WARBAND_MAX_MEMBERS := 8
const WARBAND_AP_COST := 1
const ELVEN_FIRST_STRIKE_SECOND_HIT_RATIO := 0.5
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
const ORC_HUNTING_BEAST_FRAMES := 10
const ORC_HUNTING_BEAST_FRAME_SIZE := Vector2(183, 176)
const ORC_HUNTING_BEAST_DRAW_SIZE := Vector2(18.4, 17.6)
const ORC_HUNTING_BEAST_FRAME_SECONDS := 0.12


func _ready() -> void:
	_grid_manager = get_parent().get_node("GridManager2D")
	_fog_manager = get_parent().get_node_or_null("FogOfWar2D")
	_template_registry = get_parent().get_node_or_null("TemplateRegistry")
	_building_manager = get_parent().get_node_or_null("BuildingManager2D")
	_wall_manager = get_parent().get_node_or_null("WallBlueprintManager2D")
	_technology_service = get_parent().get_node_or_null("TechnologyService")
	set_process(true)


func _process(_delta: float) -> void:
	_update_action_preview()
	_update_fog_reveal_preview()
	_update_fog_conceal_preview()
	if _fog_reveal_mode or _fog_conceal_mode or not _move_visuals.is_empty() or not _hurt_visuals.is_empty() or not _attack_visuals.is_empty() or not _death_visuals.is_empty() or _has_orc_blood_axe_units():
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
		for i in range(unit_defs.size()):
			var unit_def: Dictionary = unit_defs[i]
			_add_initial_unit(p, str(unit_def["template_id"]), unit_def["fallback"], Vector2i(pos.x + offset + i, pos.y))

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
	fallback.template_id = template_id
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
		"has_thrown_beast": false,
		"fog_reveal_cooldown_turns": 0,
		"fog_conceal_cooldown_turns": 0,
		"retreat_hidden_from_faction": -1,
		"retreat_unselectable_by_unit_id": -1,
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


func apply_building_damage(unit_id: int, attacker_faction: int, damage: int) -> bool:
	var final_damage: int = maxi(0, damage)
	for i in range(_units.size() - 1, -1, -1):
		var unit: Dictionary = _units[i]
		if int(unit.get("id", -1)) != unit_id:
			continue
		unit["hp"] = int(unit.get("hp", 0)) - final_damage
		_play_hit_effect(unit_id, unit.get("grid_pos", Vector2i.ZERO), final_damage)
		if int(unit.get("hp", 0)) <= 0:
			unit_killed.emit(attacker_faction, int(unit.get("faction", -1)), unit.duplicate())
			_move_visuals.erase(unit_id)
			_hurt_visuals.erase(unit_id)
			_attack_visuals.erase(unit_id)
			_death_visuals.erase(unit_id)
			_unit_facing_flip.erase(unit_id)
			_pending_attack_after_move.erase(unit_id)
			_units.remove_at(i)
			queue_redraw()
			return true
		_units[i] = unit
		queue_redraw()
		return false
	return false


func _is_unit_visible_to_current_player(unit: Dictionary) -> bool:
	if _turn_manager == null:
		return true
	var viewer: int = int(_turn_manager.current_player)
	return _is_unit_visible_to_player(viewer, unit)


func _is_unit_visible_to_player(viewer: int, unit: Dictionary) -> bool:
	if int(unit.get(RETREAT_HIDDEN_FROM_FACTION_KEY, -1)) == viewer:
		return false
	if _fog_manager == null:
		return true
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
	for t in _attack_range_tiles:
		var pos_attack := _grid_to_world(t.x, t.y)
		var attack_rect := Rect2(pos_attack - Vector2(tile_size, tile_size) * 0.5, Vector2(tile_size, tile_size))
		draw_rect(attack_rect.grow(-4.0), ATTACK_RANGE_COLOR, true)
	for t in _throw_range_tiles:
		var pos_throw := _grid_to_world(t.x, t.y)
		draw_circle(pos_throw, UNIT_RADIUS * 1.7, THROW_RANGE_COLOR)
	for t in _fog_reveal_tiles:
		var pos_reveal := _grid_to_world(t.x, t.y)
		var reveal_rect := Rect2(pos_reveal - Vector2(tile_size, tile_size) * 0.5, Vector2(tile_size, tile_size))
		draw_rect(reveal_rect.grow(-3.0), FOG_REVEAL_COLOR, true)
		draw_rect(reveal_rect.grow(-3.0), FOG_REVEAL_BORDER_COLOR, false, 1.5)
	for t in _fog_conceal_tiles:
		var pos_conceal := _grid_to_world(t.x, t.y)
		var conceal_rect := Rect2(pos_conceal - Vector2(tile_size, tile_size) * 0.5, Vector2(tile_size, tile_size))
		draw_rect(conceal_rect.grow(-3.0), FOG_CONCEAL_COLOR, true)
		draw_rect(conceal_rect.grow(-3.0), FOG_CONCEAL_BORDER_COLOR, false, 1.5)

	_draw_action_preview_highlight()
	_draw_warband_highlights()

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
		var uses_orc_sprite: bool = _uses_orc_sprite(u)

		if is_selected:
			draw_circle(draw_pos, UNIT_RADIUS + 3.0, SELECT_COLOR)

		if _is_orc_blood_axe(u):
			_draw_orc_blood_axe(u, draw_pos)
		elif _is_orc_beast(u):
			_draw_orc_hunting_beast(u, draw_pos)
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
	if event is InputEventKey and event.pressed and not event.echo:
		if event.keycode == KEY_ESCAPE and (_fog_reveal_mode or _fog_conceal_mode):
			_cancel_fog_modes()
			_emit_selected_unit_view()
			return

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
		if not _is_warband_selection_active():
			_clear_selection()
		return

	if _fog_conceal_mode:
		_try_conceal_fog_at(gpos)
		return
	if _fog_reveal_mode:
		_try_reveal_fog_at(gpos)
		return

	if _is_warband_selection_active():
		_handle_warband_selection_click(gpos)
		return

	if _selected_id >= 0 and _throw_beast_source_id >= 0:
		_try_throw_beast_to(gpos)
		return

	if _selected_id >= 0:
		var selected_for_special: Dictionary = _get_unit_by_id(_selected_id)
		if not selected_for_special.is_empty():
			var special_target: Dictionary = get_visible_unit_at(gpos)
			if not special_target.is_empty() and special_target["faction"] == selected_for_special["faction"]:
				if _try_arm_beast_throw(selected_for_special, special_target):
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
			var bmgr_for_attack: Node = get_parent().get_node_or_null("BuildingManager2D")
			if bmgr_for_attack and bmgr_for_attack.has_method("get_building_at"):
				var building_target: Dictionary = bmgr_for_attack.call("get_building_at", gpos)
				if _try_attack_building(src, building_target):
					return
			var target := get_visible_unit_at(gpos)
			if not target.is_empty() and target["faction"] != src["faction"]:
				if _is_retreat_unselectable_for_attacker(src, target):
					print("[Combat] Target cannot be selected by this attacker until its next turn.")
					return
				# 中立单位（faction == -1）→ 调用 NeutralUnitManager2D 战斗
				if _can_ranged_attack(src, target):
					_initiate_ranged_combat(int(src.get("id", -1)), int(target.get("id", -1)))
					return
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
					if not ntarget.is_empty() and _can_ranged_attack(src, ntarget):
						_initiate_ranged_neutral_combat(int(src.get("id", -1)), int(ntarget.get("id", -1)), numgr)
						return
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
			_attack_range_tiles = _calc_attack_range_tiles(u)
			_throw_range_tiles = []
			unit_selected.emit(_make_unit_view(u))
			break
	queue_redraw()


func _clear_selection() -> void:
	_selected_id = -1
	_reachable_tiles = []
	_attack_range_tiles = []
	_throw_range_tiles = []
	_throw_beast_source_id = -1
	_cancel_fog_modes()
	_emit_action_preview({})
	selection_cleared.emit()
	queue_redraw()


func get_selected_unit_view() -> Dictionary:
	if _selected_id < 0:
		return {}
	var unit: Dictionary = _get_unit_by_id(_selected_id)
	if unit.is_empty():
		return {}
	return _make_unit_view(unit)


func request_unit_skill(action_id: String, unit_id: int = -1) -> bool:
	var selected_unit_id: int = unit_id if unit_id >= 0 else _selected_id
	match action_id:
		"fog_reveal":
			var reveal_ok: bool = _request_fog_reveal_skill(selected_unit_id)
			_emit_selected_unit_view()
			return reveal_ok
		"fog_conceal":
			var conceal_ok: bool = _request_fog_conceal_skill(selected_unit_id)
			_emit_selected_unit_view()
			return conceal_ok
		"throw_beast":
			var throw_ok: bool = _request_throw_beast_skill(selected_unit_id)
			_emit_selected_unit_view()
			return throw_ok
		"warband_form":
			return request_form_warband(selected_unit_id)
		"warband_confirm":
			return confirm_warband_selection()
		"warband_cancel":
			cancel_warband_selection()
			return true
		"warband_disband":
			return disband_warband(selected_unit_id)
	return false


func _emit_selected_unit_view() -> void:
	if _selected_id < 0:
		return
	var unit: Dictionary = _get_unit_by_id(_selected_id)
	if unit.is_empty():
		return
	unit_selected.emit(_make_unit_view(unit))


func _request_fog_reveal_skill(unit_id: int) -> bool:
	if unit_id != _selected_id:
		_select_unit(unit_id)
	if _get_selected_fog_reveal_caster().is_empty():
		return false
	_toggle_fog_reveal_mode()
	return true


func _request_fog_conceal_skill(unit_id: int) -> bool:
	if unit_id != _selected_id:
		_select_unit(unit_id)
	if _get_selected_fog_conceal_caster().is_empty():
		return false
	_toggle_fog_conceal_mode()
	return true


func _request_throw_beast_skill(unit_id: int) -> bool:
	if unit_id != _selected_id:
		_select_unit(unit_id)
	var slinger: Dictionary = _get_unit_by_id(unit_id)
	if slinger.is_empty():
		return false
	var beast: Dictionary = _get_adjacent_throw_beast(slinger)
	if beast.is_empty():
		return false
	return _try_arm_beast_throw(slinger, beast)


func _toggle_fog_reveal_mode() -> void:
	if _fog_reveal_mode:
		_cancel_fog_reveal_mode()
		return
	var caster: Dictionary = _get_selected_fog_reveal_caster()
	if caster.is_empty():
		print("[Fog] Select Windrunner Scout on Elf turn before pressing F.")
		return
	if _is_fog_talent_on_cooldown(caster, FOG_REVEAL_COOLDOWN_KEY):
		print("[Fog] Windrunner Scout reveal is cooling down.")
		return
	_cancel_fog_conceal_mode()
	_fog_reveal_mode = true
	_reachable_tiles = []
	_attack_range_tiles = []
	_throw_range_tiles = []
	_throw_beast_source_id = -1
	_emit_action_preview({})
	_update_fog_reveal_preview()
	queue_redraw()


func _cancel_fog_reveal_mode() -> void:
	_fog_reveal_mode = false
	_fog_reveal_tiles.clear()
	queue_redraw()


func _toggle_fog_conceal_mode() -> void:
	if _fog_conceal_mode:
		_cancel_fog_conceal_mode()
		return
	var caster: Dictionary = _get_selected_fog_conceal_caster()
	if caster.is_empty():
		print("[Fog] Select Moonshadow Assassin on Elf turn before pressing G.")
		return
	if _is_fog_talent_on_cooldown(caster, FOG_CONCEAL_COOLDOWN_KEY):
		print("[Fog] Moonshadow Assassin conceal is cooling down.")
		return
	_cancel_fog_reveal_mode()
	_fog_conceal_mode = true
	_reachable_tiles = []
	_attack_range_tiles = []
	_throw_range_tiles = []
	_throw_beast_source_id = -1
	_emit_action_preview({})
	_update_fog_conceal_preview()
	queue_redraw()


func _cancel_fog_conceal_mode() -> void:
	_fog_conceal_mode = false
	_fog_conceal_tiles.clear()
	queue_redraw()


func _cancel_fog_modes() -> void:
	_fog_reveal_mode = false
	_fog_reveal_tiles.clear()
	_fog_conceal_mode = false
	_fog_conceal_tiles.clear()
	queue_redraw()


func _get_selected_elven_caster() -> Dictionary:
	if _turn_manager == null or int(_turn_manager.current_player) != 0:
		return {}
	if _selected_id < 0:
		return {}
	var caster: Dictionary = _get_unit_by_id(_selected_id)
	if caster.is_empty():
		return {}
	if int(caster.get("faction", -1)) != 0:
		return {}
	return caster


func _get_selected_fog_reveal_caster() -> Dictionary:
	var caster: Dictionary = _get_selected_elven_caster()
	if caster.is_empty():
		return {}
	if str(caster.get("template_id", "")) != ELF_FOG_REVEAL_CASTER_TEMPLATE_ID:
		return {}
	return caster


func _get_selected_fog_conceal_caster() -> Dictionary:
	var caster: Dictionary = _get_selected_elven_caster()
	if caster.is_empty():
		return {}
	if str(caster.get("template_id", "")) != ELF_FOG_CONCEAL_CASTER_TEMPLATE_ID:
		return {}
	return caster


func _is_fog_talent_on_cooldown(unit: Dictionary, cooldown_key: String) -> bool:
	return int(unit.get(cooldown_key, 0)) > 0


func _set_fog_talent_cooldown(unit: Dictionary, cooldown_key: String) -> void:
	unit[cooldown_key] = 1


func _tick_fog_talent_cooldowns(unit: Dictionary) -> void:
	var keys: Array[String] = [FOG_REVEAL_COOLDOWN_KEY, FOG_CONCEAL_COOLDOWN_KEY]
	for key in keys:
		var cooldown: int = int(unit.get(key, 0))
		if cooldown > 0:
			unit[key] = cooldown - 1


func _clear_retreat_state(unit: Dictionary) -> void:
	unit[RETREAT_HIDDEN_FROM_FACTION_KEY] = -1
	unit[RETREAT_UNSELECTABLE_BY_UNIT_KEY] = -1


func _update_fog_reveal_preview() -> void:
	if not _fog_reveal_mode:
		if not _fog_reveal_tiles.is_empty():
			_fog_reveal_tiles.clear()
		return
	var caster: Dictionary = _get_selected_fog_reveal_caster()
	if caster.is_empty():
		_cancel_fog_reveal_mode()
		return
	if _is_fog_talent_on_cooldown(caster, FOG_REVEAL_COOLDOWN_KEY):
		_cancel_fog_reveal_mode()
		return
	var target: Vector2i = _world_to_grid(get_global_mouse_position())
	if not _in_bounds(target.x, target.y):
		_fog_reveal_tiles.clear()
		return
	_fog_reveal_tiles = _get_tiles_in_manhattan_radius(target, FOG_REVEAL_RADIUS)


func _update_fog_conceal_preview() -> void:
	if not _fog_conceal_mode:
		if not _fog_conceal_tiles.is_empty():
			_fog_conceal_tiles.clear()
		return
	var caster: Dictionary = _get_selected_fog_conceal_caster()
	if caster.is_empty():
		_cancel_fog_conceal_mode()
		return
	if _is_fog_talent_on_cooldown(caster, FOG_CONCEAL_COOLDOWN_KEY):
		_cancel_fog_conceal_mode()
		return
	var target: Vector2i = _world_to_grid(get_global_mouse_position())
	if not _in_bounds(target.x, target.y):
		_fog_conceal_tiles.clear()
		return
	var caster_pos: Vector2i = caster.get("grid_pos", Vector2i.ZERO)
	if _grid_distance(caster_pos, target) > FOG_CONCEAL_RANGE:
		_fog_conceal_tiles.clear()
		return
	_fog_conceal_tiles = _get_tiles_in_manhattan_radius(target, FOG_CONCEAL_RADIUS)


func _try_reveal_fog_at(target: Vector2i) -> bool:
	var caster: Dictionary = _get_selected_fog_reveal_caster()
	if caster.is_empty():
		_cancel_fog_reveal_mode()
		return false
	if _is_fog_talent_on_cooldown(caster, FOG_REVEAL_COOLDOWN_KEY):
		_cancel_fog_reveal_mode()
		return false
	if _fog_manager == null or not _fog_manager.has_method("reveal_area"):
		return false
	if _turn_manager != null:
		var ok: bool = _turn_manager.spend_ap(int(_turn_manager.current_player), FOG_REVEAL_AP_COST)
		if not ok:
			print("[Fog] Not enough AP to reveal fog.")
			return false
	_fog_manager.call("reveal_area", int(_turn_manager.current_player), target.x, target.y, FOG_REVEAL_RADIUS)
	_set_fog_talent_cooldown(caster, FOG_REVEAL_COOLDOWN_KEY)
	_cancel_fog_reveal_mode()
	_emit_selected_unit_view()
	print("[Fog] Windrunner Scout revealed area %s." % str(target))
	return true


func _try_conceal_fog_at(target: Vector2i) -> bool:
	var caster: Dictionary = _get_selected_fog_conceal_caster()
	if caster.is_empty():
		_cancel_fog_conceal_mode()
		return false
	if _is_fog_talent_on_cooldown(caster, FOG_CONCEAL_COOLDOWN_KEY):
		_cancel_fog_conceal_mode()
		return false
	var caster_pos: Vector2i = caster.get("grid_pos", Vector2i.ZERO)
	if _grid_distance(caster_pos, target) > FOG_CONCEAL_RANGE:
		print("[Fog] Conceal target is out of range.")
		return false
	if _fog_manager == null or not _fog_manager.has_method("add_magic_fog"):
		return false
	if _turn_manager != null:
		var ok: bool = _turn_manager.spend_ap(int(_turn_manager.current_player), FOG_CONCEAL_AP_COST)
		if not ok:
			print("[Fog] Not enough AP to conceal fog.")
			return false
	_fog_manager.call("add_magic_fog", int(_turn_manager.current_player), target.x, target.y, FOG_CONCEAL_RADIUS, FOG_CONCEAL_DURATION_ROUNDS)
	_set_fog_talent_cooldown(caster, FOG_CONCEAL_COOLDOWN_KEY)
	_cancel_fog_conceal_mode()
	_emit_selected_unit_view()
	print("[Fog] Moonshadow Assassin concealed area %s." % str(target))
	return true


# ========== 移动 ==========


func request_form_warband(unit_id: int = -1) -> bool:
	var leader_id: int = unit_id if unit_id >= 0 else _selected_id
	var leader: Dictionary = _get_unit_by_id(leader_id)
	if leader.is_empty():
		return false
	if not _can_unit_join_warband(leader, true):
		return false
	if _turn_manager:
		if int(leader.get("faction", -1)) != int(_turn_manager.current_player):
			return false
	_start_warband_selection(leader_id)
	return true


func confirm_warband_selection() -> bool:
	if not _is_warband_selection_active():
		return false
	if _warband_selection_ids.size() < WARBAND_MIN_MEMBERS:
		print("[Warband] Need at least %d members." % WARBAND_MIN_MEMBERS)
		return false
	if _turn_manager:
		var leader: Dictionary = _get_unit_by_id(_warband_selection_leader_id)
		if leader.is_empty() or int(leader.get("faction", -1)) != int(_turn_manager.current_player):
			cancel_warband_selection()
			return false
		if not _turn_manager.spend_ap(_turn_manager.current_player, WARBAND_AP_COST):
			print("[Warband] Not enough AP.")
			return false
	var warband_id: int = _next_warband_id
	var formed_count: int = _warband_selection_ids.size()
	_next_warband_id += 1
	for member_id in _warband_selection_ids:
		var member: Dictionary = _get_unit_by_id(member_id)
		if member.is_empty():
			continue
		member["warband_id"] = warband_id
		member["warband_leader_id"] = _warband_selection_leader_id
		member["warband_turn"] = _turn_manager.round_number if _turn_manager else 0
	var leader_view: Dictionary = _get_unit_by_id(_warband_selection_leader_id)
	_warband_selection_leader_id = -1
	_warband_selection_ids.clear()
	if not leader_view.is_empty():
		unit_selected.emit(_make_unit_view(leader_view))
	queue_redraw()
	print("[Warband] Formed orc warband %d with %d members." % [warband_id, formed_count])
	return true


func cancel_warband_selection() -> void:
	if not _is_warband_selection_active():
		return
	var leader: Dictionary = _get_unit_by_id(_warband_selection_leader_id)
	_warband_selection_leader_id = -1
	_warband_selection_ids.clear()
	if not leader.is_empty():
		unit_selected.emit(_make_unit_view(leader))
	queue_redraw()


func disband_warband(unit_id: int = -1) -> bool:
	var selected_unit_id: int = unit_id if unit_id >= 0 else _selected_id
	var unit: Dictionary = _get_unit_by_id(selected_unit_id)
	if unit.is_empty():
		return false
	var warband_id: int = int(unit.get("warband_id", -1))
	if warband_id < 0:
		return false
	if _turn_manager and int(unit.get("faction", -1)) != int(_turn_manager.current_player):
		return false
	for member in _units:
		if int(member.get("warband_id", -1)) != warband_id:
			continue
		member.erase("warband_id")
		member.erase("warband_leader_id")
		member.erase("warband_turn")
	_reachable_tiles = _calc_reachable(unit)
	unit_selected.emit(_make_unit_view(unit))
	queue_redraw()
	return true


func _start_warband_selection(leader_id: int) -> void:
	_warband_selection_leader_id = leader_id
	_warband_selection_ids.clear()
	_warband_selection_ids.append(leader_id)
	_selected_id = leader_id
	var leader: Dictionary = _get_unit_by_id(leader_id)
	if not leader.is_empty():
		_reachable_tiles = []
		_attack_range_tiles = []
		_throw_range_tiles = []
		unit_selected.emit(_make_unit_view(leader))
	queue_redraw()


func _is_warband_selection_active() -> bool:
	return _warband_selection_leader_id >= 0


func _handle_warband_selection_click(gpos: Vector2i) -> void:
	var target: Dictionary = get_visible_unit_at(gpos)
	if target.is_empty():
		return
	if not _can_unit_join_warband(target, false):
		return
	var target_id: int = int(target.get("id", -1))
	if target_id == _warband_selection_leader_id:
		return
	if target_id in _warband_selection_ids:
		_warband_selection_ids.erase(target_id)
	elif _warband_selection_ids.size() < WARBAND_MAX_MEMBERS:
		_warband_selection_ids.append(target_id)
	var leader: Dictionary = _get_unit_by_id(_warband_selection_leader_id)
	if not leader.is_empty():
		unit_selected.emit(_make_unit_view(leader))
	queue_redraw()


func _update_action_preview() -> void:
	if _fog_reveal_mode or _fog_conceal_mode:
		_emit_action_preview({})
		return
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
	if target.is_empty():
		var neutral_mgr := get_parent().get_node_or_null("NeutralUnitManager2D")
		if neutral_mgr and neutral_mgr.has_method("get_neutral_unit_at"):
			var neutral_target: Dictionary = neutral_mgr.get_neutral_unit_at(gpos)
			if not neutral_target.is_empty():
				_emit_action_preview(_make_neutral_attack_preview(attacker, neutral_target))
				return
	if target.is_empty() or target["faction"] == attacker["faction"] or target["faction"] == -1:
		_emit_action_preview({})
		return
	if _is_retreat_unselectable_for_attacker(attacker, target):
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
	if bool(_current_action_preview.get("is_ranged", false)):
		_draw_ranged_attack_preview_line()
	var approach_pos: Vector2i = _current_action_preview.get("approach_pos", Vector2i(-1, -1))
	if approach_pos.x < 0:
		return
	var center: Vector2 = _grid_to_world(approach_pos.x, approach_pos.y)
	var rect := Rect2(center - Vector2(tile_size, tile_size) * 0.5, Vector2(tile_size, tile_size))
	var can_attack: bool = bool(_current_action_preview.get("can_attack", false))
	var color: Color = ATTACK_APPROACH_OK_COLOR if can_attack else ATTACK_APPROACH_BLOCKED_COLOR
	draw_rect(rect.grow(-2.0), color, true)
	draw_rect(rect.grow(-2.0), Color(color.r, color.g, color.b, 0.92), false, 2.0)


func _draw_ranged_attack_preview_line() -> void:
	var attacker_pos: Vector2i = _current_action_preview.get("attacker_pos", Vector2i(-1, -1))
	var target_pos: Vector2i = _current_action_preview.get("target_pos", Vector2i(-1, -1))
	if attacker_pos.x < 0 or target_pos.x < 0:
		return
	var from: Vector2 = _grid_to_world(attacker_pos.x, attacker_pos.y)
	var to: Vector2 = _grid_to_world(target_pos.x, target_pos.y)
	var can_attack: bool = bool(_current_action_preview.get("can_attack", false))
	var color: Color = Color(1.0, 0.34, 0.22, 0.92) if can_attack else Color(0.75, 0.75, 0.75, 0.65)
	_draw_dashed_line(from, to, color, 3.0, 12.0, 8.0)
	draw_circle(to, UNIT_RADIUS * 2.0, Color(color.r, color.g, color.b, 0.18))
	draw_circle(to, UNIT_RADIUS * 2.0, color, false, 2.0)


func _draw_dashed_line(from: Vector2, to: Vector2, color: Color, width: float, dash_length: float, gap_length: float) -> void:
	var delta: Vector2 = to - from
	var length: float = delta.length()
	if length <= 0.01:
		return
	var direction: Vector2 = delta / length
	var cursor: float = 0.0
	while cursor < length:
		var segment_end: float = minf(cursor + dash_length, length)
		draw_line(from + direction * cursor, from + direction * segment_end, color, width, true)
		cursor += dash_length + gap_length


func _draw_warband_highlights() -> void:
	if _is_warband_selection_active():
		_draw_warband_selection_highlights()
	var selected: Dictionary = _get_unit_by_id(_selected_id)
	if not selected.is_empty() and _is_active_warband_member(selected):
		var leader: Dictionary = _get_warband_leader(int(selected.get("warband_id", -1)))
		var center_pos: Vector2i = leader.get("grid_pos", selected.get("grid_pos", Vector2i.ZERO))
		for tile in _get_tiles_in_manhattan_radius(center_pos, WARBAND_RADIUS):
			var p: Vector2 = _grid_to_world(tile.x, tile.y)
			var rect := Rect2(p - Vector2(tile_size, tile_size) * 0.5, Vector2(tile_size, tile_size))
			draw_rect(rect.grow(-3.0), WARBAND_AREA_COLOR, true)
	for unit in _units:
		if not _is_unit_visible_to_current_player(unit):
			continue
		if not _is_active_warband_member(unit):
			continue
		var p2: Vector2 = _get_unit_draw_world_pos(unit)
		draw_circle(p2, UNIT_RADIUS + 7.0, Color(WARBAND_RING_COLOR.r, WARBAND_RING_COLOR.g, WARBAND_RING_COLOR.b, 0.16))
		draw_circle(p2, UNIT_RADIUS + 7.0, WARBAND_RING_COLOR, false, 2.0)
		if int(unit.get("id", -1)) == int(unit.get("warband_leader_id", -2)):
			draw_circle(p2 + Vector2(0, -30), 5.0, WARBAND_COMMAND_COLOR)
			draw_circle(p2 + Vector2(0, -30), 8.0, Color(WARBAND_COMMAND_COLOR.r, WARBAND_COMMAND_COLOR.g, WARBAND_COMMAND_COLOR.b, 0.25))


func _draw_warband_selection_highlights() -> void:
	var leader: Dictionary = _get_unit_by_id(_warband_selection_leader_id)
	if leader.is_empty():
		return
	var leader_pos: Vector2 = _get_unit_draw_world_pos(leader)
	draw_circle(leader_pos + Vector2(0, -30), 5.0, WARBAND_COMMAND_COLOR)
	draw_circle(leader_pos + Vector2(0, -30), 8.0, Color(WARBAND_COMMAND_COLOR.r, WARBAND_COMMAND_COLOR.g, WARBAND_COMMAND_COLOR.b, 0.25))
	for unit in _units:
		if not _is_unit_visible_to_current_player(unit):
			continue
		if not _can_unit_join_warband(unit, false):
			continue
		var pos: Vector2 = _get_unit_draw_world_pos(unit)
		if int(unit.get("id", -1)) in _warband_selection_ids:
			draw_circle(pos, UNIT_RADIUS + 9.0, Color(WARBAND_SELECTION_COLOR.r, WARBAND_SELECTION_COLOR.g, WARBAND_SELECTION_COLOR.b, 0.18))
			draw_circle(pos, UNIT_RADIUS + 9.0, WARBAND_SELECTION_COLOR, false, 2.5)
		else:
			draw_circle(pos, UNIT_RADIUS + 6.0, Color(WARBAND_SELECTION_COLOR.r, WARBAND_SELECTION_COLOR.g, WARBAND_SELECTION_COLOR.b, 0.14), false, 1.5)


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
		"attacker_pos": from,
		"target_pos": target_pos,
		"approach_pos": Vector2i(-1, -1),
		"ap_cost": 0,
		"can_attack": false,
		"is_ranged": false,
		"reason": "",
	}

	if attacker_data.attack_range > 1 and _grid_distance(from, target_pos) <= attacker_data.attack_range:
		preview["approach_pos"] = from
		preview["can_attack"] = true
		preview["is_ranged"] = true
		preview["reason"] = "\u5c04\u7a0b\u5185\uff0c\u53ef\u4ee5\u8fdc\u7a0b\u653b\u51fb"
		if _can_trigger_elven_first_strike(attacker, target):
			preview["reason"] += "\uff1b\u4fe1\u606f\u4f18\u52bf\u89e6\u53d1\u5148\u624b\u8fde\u51fb"
		return preview

	if _is_adjacent(from, target_pos):
		preview["approach_pos"] = from
		preview["can_attack"] = true
		preview["reason"] = "已相邻，可以攻击"
		if _can_trigger_elven_first_strike(attacker, target):
			preview["reason"] += "\uff1b\u4fe1\u606f\u4f18\u52bf\u89e6\u53d1\u5148\u624b\u8fde\u51fb"
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


func _make_neutral_attack_preview(attacker: Dictionary, target: Dictionary) -> Dictionary:
	var attacker_data: UnitData = _get_unit_data(attacker)
	var from: Vector2i = attacker.get("grid_pos", Vector2i.ZERO)
	var target_pos: Vector2i = target.get("grid_pos", Vector2i.ZERO)
	var preview := {
		"visible": true,
		"action": "attack",
		"attacker_name": attacker_data.unit_name,
		"target_name": str(target.get("display_name", "中立单位")),
		"attacker_pos": from,
		"target_pos": target_pos,
		"approach_pos": Vector2i(-1, -1),
		"ap_cost": 0,
		"can_attack": false,
		"is_ranged": false,
		"reason": "",
	}
	var dist: int = _grid_distance(from, target_pos)
	if attacker_data.attack_range > 1 and dist > 1 and dist <= attacker_data.attack_range:
		preview["approach_pos"] = from
		preview["can_attack"] = true
		preview["is_ranged"] = true
		preview["reason"] = "\u5c04\u7a0b\u5185\uff0c\u53ef\u4ee5\u8fdc\u7a0b\u653b\u51fb"
		return preview
	if dist == 1:
		preview["approach_pos"] = from
		preview["can_attack"] = true
		preview["reason"] = "\u5df2\u8d34\u8eab\uff0c\u8fdb\u5165\u8fd1\u6218\u51b3\u6597"
		return preview
	preview["reason"] = "\u76ee\u6807\u4e0d\u5728\u5c04\u7a0b\u5185"
	return preview


func _can_ranged_attack(attacker: Dictionary, target: Dictionary) -> bool:
	if attacker.is_empty() or target.is_empty():
		return false
	var data: UnitData = _get_unit_data(attacker)
	if data.attack_range <= 1:
		return false
	var from: Vector2i = attacker.get("grid_pos", Vector2i.ZERO)
	var target_pos: Vector2i = target.get("grid_pos", Vector2i.ZERO)
	var dist: int = _grid_distance(from, target_pos)
	return dist > 1 and dist <= data.attack_range


func _can_unit_attack_unit(attacker: Dictionary, target: Dictionary) -> bool:
	if attacker.is_empty() or target.is_empty():
		return false
	var data: UnitData = _get_unit_data(attacker)
	if data.atk <= 0:
		return false
	var from: Vector2i = attacker.get("grid_pos", Vector2i.ZERO)
	var target_pos: Vector2i = target.get("grid_pos", Vector2i.ZERO)
	var distance: int = _grid_distance(from, target_pos)
	return distance > 0 and distance <= data.attack_range


func _can_unit_see_unit(viewer: Dictionary, target: Dictionary) -> bool:
	if viewer.is_empty() or target.is_empty():
		return false
	var viewer_faction: int = int(viewer.get("faction", -1))
	if int(target.get(RETREAT_HIDDEN_FROM_FACTION_KEY, -1)) == viewer_faction:
		return false
	if viewer_faction == int(target.get("faction", -2)):
		return true
	var viewer_pos: Vector2i = viewer.get("grid_pos", Vector2i.ZERO)
	var target_pos: Vector2i = target.get("grid_pos", Vector2i.ZERO)
	return _grid_distance(viewer_pos, target_pos) <= _get_unit_vision_value(viewer)


func _is_retreat_unselectable_for_attacker(attacker: Dictionary, target: Dictionary) -> bool:
	if attacker.is_empty() or target.is_empty():
		return false
	return int(target.get(RETREAT_UNSELECTABLE_BY_UNIT_KEY, -1)) == int(attacker.get("id", -2))


func _choose_tactical_first_attacker(initiator: Dictionary, target: Dictionary) -> int:
	var initiator_sees_target: bool = _can_unit_see_unit(initiator, target)
	var target_sees_initiator: bool = _can_unit_see_unit(target, initiator)
	if initiator_sees_target and not target_sees_initiator:
		return int(initiator.get("id", -1))
	if target_sees_initiator and not initiator_sees_target:
		return int(target.get("id", -1))
	var initiator_range: int = _get_unit_data(initiator).attack_range
	var target_range: int = _get_unit_data(target).attack_range
	if target_range > initiator_range:
		return int(target.get("id", -1))
	return int(initiator.get("id", -1))


func _apply_unit_attack_damage(attacker: Dictionary, defender: Dictionary) -> bool:
	if attacker.is_empty() or defender.is_empty():
		return false
	var raw_dmg: int = _get_unit_attack_value(attacker)
	var reduction: int = _get_unit_damage_reduction(defender)
	var dmg: int = maxi(1, raw_dmg - reduction) if raw_dmg > 0 else 0
	_play_attack_effect(attacker, defender)
	defender["hp"] = int(defender.get("hp", 0)) - dmg
	if dmg > 0:
		_try_apply_scout_poison_weaken(attacker, defender)
	_play_hit_effect(int(defender.get("id", -1)), defender.get("grid_pos", Vector2i.ZERO), dmg)
	if int(defender.get("hp", 0)) <= 0:
		return true
	if _apply_elven_first_strike_followup(attacker, defender):
		return int(defender.get("hp", 0)) <= 0
	return false


func _try_attack_building(attacker: Dictionary, building: Dictionary) -> bool:
	if attacker.is_empty() or building.is_empty():
		return false
	if _in_combat:
		return false
	if int(building.get("faction", -1)) == int(attacker.get("faction", -2)):
		return false
	if not _can_unit_attack_building(attacker, building):
		return false
	_start_building_attack(attacker, building)
	return true


func _can_unit_attack_building(attacker: Dictionary, building: Dictionary) -> bool:
	if attacker.is_empty() or building.is_empty():
		return false
	if int(building.get("faction", -1)) == int(attacker.get("faction", -2)):
		return false
	var data: UnitData = _get_unit_data(attacker)
	if data.atk <= 0:
		return false
	var from: Vector2i = attacker.get("grid_pos", Vector2i.ZERO)
	var distance: int = _distance_to_building(from, building)
	if distance < 0 or distance > data.attack_range:
		return false
	return _get_building_attack_damage(attacker) > 0


func _get_building_attack_damage(attacker: Dictionary) -> int:
	if attacker.is_empty():
		return 0
	var data: UnitData = _get_unit_data(attacker)
	var damage: int = _get_unit_attack_value(attacker)
	if data.category == UnitData.UnitCategory.SIEGE or "building_breaker" in data.tags:
		damage += 2
	return maxi(0, damage)


func _start_building_attack(attacker: Dictionary, building: Dictionary) -> void:
	var bmgr: Node = get_parent().get_node_or_null("BuildingManager2D")
	if bmgr == null or not bmgr.has_method("damage_building") or not bmgr.has_method("get_building_by_id"):
		return
	_in_combat = true
	_combat_sequence_id += 1
	_combat_data = {}
	_building_attack_data = {
		"attacker_id": int(attacker.get("id", -1)),
		"building_id": int(building.get("id", -1)),
		"attacker_faction": int(attacker.get("faction", -1)),
		"sequence_id": _combat_sequence_id,
	}
	_reachable_tiles = []
	_attack_range_tiles = []
	_throw_range_tiles = []
	_throw_beast_source_id = -1
	_emit_action_preview({})
	combat_started.emit()
	_ensure_building_attack_timer()
	_perform_building_attack_tick()
	queue_redraw()


func _ensure_building_attack_timer() -> void:
	if _building_attack_timer != null:
		return
	_building_attack_timer = Timer.new()
	_building_attack_timer.one_shot = true
	_building_attack_timer.wait_time = UNIT_ATTACK_INTERVAL
	_building_attack_timer.timeout.connect(_on_building_attack_timer_timeout)
	add_child(_building_attack_timer)


func _on_building_attack_timer_timeout() -> void:
	_perform_building_attack_tick()


func _perform_building_attack_tick() -> void:
	if not _in_combat or _building_attack_data.is_empty():
		return
	var sequence_id: int = int(_building_attack_data.get("sequence_id", -1))
	if sequence_id != _combat_sequence_id:
		_finish_building_attack_state()
		return
	var bmgr: Node = get_parent().get_node_or_null("BuildingManager2D")
	if bmgr == null or not bmgr.has_method("damage_building") or not bmgr.has_method("get_building_by_id"):
		_finish_building_attack_state()
		return
	var attacker: Dictionary = _get_unit_by_id(int(_building_attack_data.get("attacker_id", -1)))
	var building: Dictionary = bmgr.call("get_building_by_id", int(_building_attack_data.get("building_id", -1)))
	if attacker.is_empty() or building.is_empty() or not _can_unit_attack_building(attacker, building):
		_finish_building_attack_state()
		return
	var damage: int = _get_building_attack_damage(attacker)
	var result: Dictionary = bmgr.call("damage_building", int(building.get("id", -1)), damage, int(attacker.get("faction", -1)))
	var refreshed: Dictionary = _get_unit_by_id(int(attacker.get("id", -1)))
	if not refreshed.is_empty():
		unit_selected.emit(_make_unit_view(refreshed))
	if bool(result.get("destroyed", false)):
		_finish_building_attack_state()
		queue_redraw()
		return
	_schedule_next_building_attack_tick()
	queue_redraw()


func _schedule_next_building_attack_tick() -> void:
	_ensure_building_attack_timer()
	if _building_attack_timer == null:
		return
	_building_attack_timer.wait_time = UNIT_ATTACK_INTERVAL
	_building_attack_timer.start()


func _finish_building_attack_state() -> void:
	if _building_attack_timer != null:
		_building_attack_timer.stop()
	_building_attack_data = {}
	_finish_combat_state()


func _distance_to_building(from: Vector2i, building: Dictionary) -> int:
	var best: int = 999
	for tile in _get_building_tiles(building):
		var pos: Vector2i = tile
		best = mini(best, _grid_distance(from, pos))
	return -1 if best == 999 else best


func _get_building_tiles(building: Dictionary) -> Array[Vector2i]:
	var result: Array[Vector2i] = []
	if building.is_empty() or not building.has("data"):
		return result
	var data: BuildingData = building["data"]
	var origin: Vector2i = building.get("origin", Vector2i.ZERO)
	for dy in range(data.footprint.y):
		for dx in range(data.footprint.x):
			result.append(Vector2i(origin.x + dx, origin.y + dy))
	return result


func _remove_unit_after_attack(target_id: int, attacker: Dictionary) -> void:
	for i in range(_units.size() - 1, -1, -1):
		if int(_units[i].get("id", -1)) != target_id:
			continue
		var loser: Dictionary = _units[i]
		unit_killed.emit(int(attacker.get("faction", -1)), int(loser.get("faction", -1)), loser.duplicate())
		_apply_kill_food_reward(attacker)
		_move_visuals.erase(target_id)
		_hurt_visuals.erase(target_id)
		_attack_visuals.erase(target_id)
		_death_visuals.erase(target_id)
		_unit_facing_flip.erase(target_id)
		_pending_attack_after_move.erase(target_id)
		_units.remove_at(i)
		return


func _try_arm_beast_throw(slinger: Dictionary, beast: Dictionary) -> bool:
	if not _is_orc_slinger(slinger):
		return false
	if not _is_orc_beast(beast):
		return false
	if int(slinger.get("faction", -1)) != int(beast.get("faction", -2)):
		return false
	if bool(slinger.get("has_thrown_beast", false)):
		return false
	if not _is_adjacent(slinger.get("grid_pos", Vector2i.ZERO), beast.get("grid_pos", Vector2i.ZERO)):
		return false
	_throw_beast_source_id = int(beast.get("id", -1))
	_reachable_tiles = []
	_attack_range_tiles = []
	_throw_range_tiles = _calc_throw_range_tiles(slinger)
	_emit_action_preview({
		"visible": true,
		"action": "throw_beast",
		"target_name": _get_unit_data(beast).unit_name,
		"target_pos": beast.get("grid_pos", Vector2i.ZERO),
		"approach_pos": beast.get("grid_pos", Vector2i.ZERO),
		"ap_cost": SLINGER_THROW_AP_COST,
		"can_attack": true,
		"reason": "\u5df2\u9009\u4e2d\u6295\u63b7\u76ee\u6807\uff0c\u70b9\u51fb 5 \u683c\u5185\u843d\u70b9",
	})
	queue_redraw()
	return true


func _get_adjacent_throw_beast(slinger: Dictionary) -> Dictionary:
	if slinger.is_empty():
		return {}
	var slinger_pos: Vector2i = slinger.get("grid_pos", Vector2i.ZERO)
	var faction: int = int(slinger.get("faction", -1))
	for unit in _units:
		var candidate: Dictionary = unit
		if int(candidate.get("faction", -2)) != faction:
			continue
		if not _is_orc_beast(candidate):
			continue
		if _is_adjacent(slinger_pos, candidate.get("grid_pos", Vector2i.ZERO)):
			return candidate
	return {}


func _try_throw_beast_to(target: Vector2i) -> bool:
	var slinger: Dictionary = _get_unit_by_id(_selected_id)
	var beast: Dictionary = _get_unit_by_id(_throw_beast_source_id)
	if slinger.is_empty() or beast.is_empty():
		_throw_beast_source_id = -1
		return false
	if _grid_distance(slinger.get("grid_pos", Vector2i.ZERO), target) > SLINGER_THROW_RANGE:
		print("[Unit] Throw target out of range.")
		return false
	var landing: Vector2i = _resolve_throw_landing(target)
	if landing.x < 0:
		print("[Unit] No valid landing tile for beast throw.")
		return false
	if _turn_manager:
		var ok: bool = _turn_manager.spend_ap(_turn_manager.current_player, SLINGER_THROW_AP_COST)
		if not ok:
			print("[Unit] Not enough AP for beast throw.")
			return false
	var from: Vector2i = beast.get("grid_pos", Vector2i.ZERO)
	beast["grid_pos"] = landing
	beast["has_moved"] = true
	slinger["has_thrown_beast"] = true
	_start_move_visual(int(beast.get("id", -1)), from, landing)
	if _fog_manager and _turn_manager:
		_fog_manager.reveal_area(_turn_manager.current_player, landing.x, landing.y, _get_unit_vision_value(beast))
	_throw_beast_source_id = -1
	_throw_range_tiles = []
	_clear_selection()
	queue_redraw()
	return true


func _resolve_throw_landing(preferred: Vector2i) -> Vector2i:
	if _is_valid_spawn_tile(preferred.x, preferred.y):
		return preferred
	for radius in range(1, 4):
		for dx in range(-radius, radius + 1):
			var dy_abs: int = radius - absi(dx)
			var candidates: Array[Vector2i] = [Vector2i(preferred.x + dx, preferred.y + dy_abs)]
			if dy_abs != 0:
				candidates.append(Vector2i(preferred.x + dx, preferred.y - dy_abs))
			for candidate in candidates:
				if _is_valid_spawn_tile(candidate.x, candidate.y):
					return candidate
	return Vector2i(-1, -1)


func _grid_distance(a: Vector2i, b: Vector2i) -> int:
	return abs(a.x - b.x) + abs(a.y - b.y)


func _move_selected_to(target: Vector2i) -> void:
	if _selected_id < 0:
		return

	for u in _units:
		if u["id"] == _selected_id:
			if _is_active_warband_member(u):
				_move_warband_to(u, target)
				return
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
	if _move_visuals.has(unit_id):
		var visual: Dictionary = _move_visuals[unit_id]
		_unit_facing_flip[unit_id] = bool(visual.get("flip_x", false))
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
		if _is_orc_blood_axe(unit) or _is_orc_beast(unit):
			return true
	return false


func _uses_orc_sprite(unit: Dictionary) -> bool:
	return _is_orc_blood_axe(unit) or _is_orc_beast(unit)


func _is_orc_blood_axe(unit: Dictionary) -> bool:
	return str(unit.get("template_id", "")) == ORC_BLOOD_AXE_TEMPLATE_ID


func _is_orc_slinger(unit: Dictionary) -> bool:
	return str(unit.get("template_id", "")) == ORC_SLINGER_TEMPLATE_ID


func _is_orc_beast(unit: Dictionary) -> bool:
	return str(unit.get("template_id", "")) == ORC_BEAST_TEMPLATE_ID


func _draw_orc_hunting_beast(unit: Dictionary, draw_pos: Vector2) -> void:
	var uid: int = unit.get("id", -1)
	var is_moving: bool = _move_visuals.has(uid)
	var frame: int = 0
	if is_moving:
		var visual: Dictionary = _move_visuals.get(uid, {})
		var t: float = float(visual.get("t", 0.0))
		frame = clampi(int(floor(t * float(ORC_HUNTING_BEAST_FRAMES))), 0, ORC_HUNTING_BEAST_FRAMES - 1)
	var src := Rect2(Vector2(ORC_HUNTING_BEAST_FRAME_SIZE.x * frame, 0.0), ORC_HUNTING_BEAST_FRAME_SIZE)
	var dst := Rect2(-ORC_HUNTING_BEAST_DRAW_SIZE * 0.5, ORC_HUNTING_BEAST_DRAW_SIZE)
	var flip_x: bool = bool(_unit_facing_flip.get(uid, false))
	if is_moving:
		var move_visual: Dictionary = _move_visuals.get(uid, {})
		flip_x = bool(move_visual.get("flip_x", flip_x))
	draw_set_transform(draw_pos, 0.0, Vector2(-1.0, 1.0) if flip_x else Vector2.ONE)
	draw_texture_rect_region(ORC_HUNTING_BEAST_TEXTURE, dst, src, Color.WHITE)
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)


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

func _get_warband_candidates(leader: Dictionary) -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	if not _can_unit_join_warband(leader, true):
		return result
	var leader_pos: Vector2i = leader.get("grid_pos", Vector2i.ZERO)
	for unit in _units:
		if not _can_unit_join_warband(unit, false):
			continue
		if int(unit.get("warband_id", -1)) >= 0:
			continue
		var pos: Vector2i = unit.get("grid_pos", Vector2i.ZERO)
		if _grid_distance(leader_pos, pos) <= WARBAND_RADIUS:
			result.append(unit)
	result.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		var apos: Vector2i = a.get("grid_pos", Vector2i.ZERO)
		var bpos: Vector2i = b.get("grid_pos", Vector2i.ZERO)
		return _grid_distance(leader_pos, apos) < _grid_distance(leader_pos, bpos)
	)
	if result.size() > WARBAND_MAX_MEMBERS:
		result.resize(WARBAND_MAX_MEMBERS)
	return result


func _is_orc_warband_unit(unit: Dictionary) -> bool:
	return _can_unit_join_warband(unit, false)


func _can_unit_join_warband(unit: Dictionary, allow_existing_member: bool) -> bool:
	if int(unit.get("faction", -1)) != 2:
		return false
	if _turn_manager and int(unit.get("faction", -1)) != int(_turn_manager.current_player):
		return false
	if not allow_existing_member and int(unit.get("warband_id", -1)) >= 0:
		return false
	return true


func _is_active_warband_member(unit: Dictionary) -> bool:
	var warband_id: int = int(unit.get("warband_id", -1))
	if warband_id < 0:
		return false
	return _get_warband_member_count(warband_id) >= WARBAND_MIN_MEMBERS


func _get_warband_member_count(warband_id: int) -> int:
	var count := 0
	for unit in _units:
		if int(unit.get("warband_id", -1)) == warband_id:
			count += 1
	return count


func _get_warband_members(warband_id: int) -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	for unit in _units:
		if int(unit.get("warband_id", -1)) == warband_id:
			result.append(unit)
	return result


func _get_warband_member_ids(warband_id: int) -> Array[int]:
	var result: Array[int] = []
	for unit in _units:
		if int(unit.get("warband_id", -1)) == warband_id:
			result.append(int(unit.get("id", -1)))
	return result


func _get_warband_leader(warband_id: int) -> Dictionary:
	var members: Array[Dictionary] = _get_warband_members(warband_id)
	if members.is_empty():
		return {}
	var leader_id: int = int(members[0].get("warband_leader_id", -1))
	for member in members:
		if int(member.get("id", -1)) == leader_id:
			return member
	return members[0]


func _get_warband_move_limit(warband_id: int) -> int:
	var limit: int = 999
	for member in _get_warband_members(warband_id):
		var data: UnitData = _get_unit_data(member)
		limit = mini(limit, data.move_max)
	return 0 if limit == 999 else limit


func _get_warband_size_ap(member_count: int) -> int:
	if member_count <= 4:
		return 1
	if member_count <= 6:
		return 2
	return 3


func _get_warband_move_ap(distance: int, member_count: int) -> int:
	if distance <= 0:
		return 0
	return distance + _get_warband_size_ap(member_count)


func _get_warband_ap_text(member_count: int) -> String:
	if member_count < WARBAND_MIN_MEMBERS:
		return ""
	var command_ap: int = _get_warband_size_ap(member_count)
	return "\u519b\u56e2%d\u4eba\uff1a\u6bcf\u683c1 AP\uff0c\u6307\u6325\u9644\u52a0%d AP\u30021\u683c%d AP / 2\u683c%d AP / 3\u683c%d AP" % [
		member_count,
		command_ap,
		_get_warband_move_ap(1, member_count),
		_get_warband_move_ap(2, member_count),
		_get_warband_move_ap(3, member_count),
	]


func _has_adjacent_warband_ally(unit: Dictionary) -> bool:
	if not _is_active_warband_member(unit):
		return false
	var warband_id: int = int(unit.get("warband_id", -1))
	var pos: Vector2i = unit.get("grid_pos", Vector2i.ZERO)
	for other in _units:
		if int(other.get("id", -1)) == int(unit.get("id", -2)):
			continue
		if int(other.get("warband_id", -1)) != warband_id:
			continue
		if _is_adjacent(pos, other.get("grid_pos", Vector2i.ZERO)):
			return true
	return false


func _clear_player_warbands(player: int) -> void:
	return
	for unit in _units:
		if int(unit.get("faction", -1)) == player:
			unit.erase("warband_id")
			unit.erase("warband_turn")


func _get_tiles_in_manhattan_radius(center: Vector2i, radius: int) -> Array[Vector2i]:
	var result: Array[Vector2i] = []
	for y in range(center.y - radius, center.y + radius + 1):
		for x in range(center.x - radius, center.x + radius + 1):
			if not _in_bounds(x, y):
				continue
			var pos := Vector2i(x, y)
			if _grid_distance(center, pos) <= radius:
				result.append(pos)
	return result


func _calc_reachable(unit: Dictionary) -> Array:
	if _is_active_warband_member(unit):
		return _calc_warband_reachable(unit)
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


func _calc_warband_reachable(unit: Dictionary) -> Array:
	var warband_id: int = int(unit.get("warband_id", -1))
	var leader: Dictionary = _get_warband_leader(warband_id)
	if leader.is_empty():
		return []
	var from: Vector2i = leader.get("grid_pos", Vector2i.ZERO)
	var max_steps: int = _get_warband_move_limit(warband_id)
	var result: Array = []
	var visited := {}
	var depth := {}
	var queue: Array = [from]
	var member_ids: Array[int] = _get_warband_member_ids(warband_id)
	var dirs := [Vector2i(0, -1), Vector2i(0, 1), Vector2i(-1, 0), Vector2i(1, 0)]
	visited[from] = true
	depth[from] = 0
	while queue.size() > 0:
		var pos: Vector2i = queue.pop_front()
		var d: int = depth[pos]
		if d >= max_steps:
			continue
		for dir in dirs:
			var nkey := Vector2i(pos.x + dir.x, pos.y + dir.y)
			if visited.has(nkey):
				continue
			if not _is_warband_formation_valid(warband_id, from, nkey, member_ids):
				continue
			visited[nkey] = true
			depth[nkey] = d + 1
			result.append(nkey)
			queue.append(nkey)
	return result


func _calc_warband_path_length(warband_id: int, from: Vector2i, to: Vector2i) -> int:
	if from == to:
		return 0
	var max_steps: int = _get_warband_move_limit(warband_id)
	var visited := {}
	var dist := { from: 0 }
	var queue: Array = [from]
	var member_ids: Array[int] = _get_warband_member_ids(warband_id)
	var dirs := [Vector2i(0, -1), Vector2i(0, 1), Vector2i(-1, 0), Vector2i(1, 0)]
	visited[from] = true
	while queue.size() > 0:
		var pos: Vector2i = queue.pop_front()
		var d: int = dist[pos]
		if d >= max_steps:
			continue
		for dir in dirs:
			var nkey := Vector2i(pos.x + dir.x, pos.y + dir.y)
			if visited.has(nkey):
				continue
			if not _is_warband_formation_valid(warband_id, from, nkey, member_ids):
				continue
			if nkey == to:
				return d + 1
			visited[nkey] = true
			dist[nkey] = d + 1
			queue.append(nkey)
	return -1


func _is_warband_formation_valid(warband_id: int, leader_from: Vector2i, leader_to: Vector2i, member_ids: Array[int]) -> bool:
	var delta: Vector2i = leader_to - leader_from
	var occupied_targets := {}
	for member in _get_warband_members(warband_id):
		var old_pos: Vector2i = member.get("grid_pos", Vector2i.ZERO)
		var target: Vector2i = old_pos + delta
		if not _in_bounds(target.x, target.y):
			return false
		if not _is_tile_passable(target.x, target.y):
			return false
		if occupied_targets.has(target):
			return false
		if not _is_tile_empty_ignoring_units(target.x, target.y, member_ids):
			return false
		occupied_targets[target] = true
	return true


func _calc_attack_range_tiles(unit: Dictionary) -> Array[Vector2i]:
	var result: Array[Vector2i] = []
	var data: UnitData = _get_unit_data(unit)
	if data.attack_range <= 1:
		return result
	var from: Vector2i = unit.get("grid_pos", Vector2i.ZERO)
	for y in range(from.y - data.attack_range, from.y + data.attack_range + 1):
		for x in range(from.x - data.attack_range, from.x + data.attack_range + 1):
			var pos := Vector2i(x, y)
			if not _in_bounds(x, y):
				continue
			if pos == from:
				continue
			if _grid_distance(from, pos) <= data.attack_range:
				result.append(pos)
	return result


func _calc_throw_range_tiles(slinger: Dictionary) -> Array[Vector2i]:
	var result: Array[Vector2i] = []
	var from: Vector2i = slinger.get("grid_pos", Vector2i.ZERO)
	for y in range(from.y - SLINGER_THROW_RANGE, from.y + SLINGER_THROW_RANGE + 1):
		for x in range(from.x - SLINGER_THROW_RANGE, from.x + SLINGER_THROW_RANGE + 1):
			var pos := Vector2i(x, y)
			if not _in_bounds(x, y):
				continue
			if pos == from:
				continue
			if _grid_distance(from, pos) <= SLINGER_THROW_RANGE:
				result.append(pos)
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
	_clear_player_warbands(player)
	for u in _units:
		if u["faction"] == player:
			u["has_moved"] = false
			u["has_attacked"] = false
			u["has_first_struck"] = false
			u["has_thrown_beast"] = false
			_clear_retreat_state(u)
			_tick_fog_talent_cooldowns(u)
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


func _move_warband_to(selected_unit: Dictionary, target: Vector2i) -> void:
	var warband_id: int = int(selected_unit.get("warband_id", -1))
	if warband_id < 0:
		return
	var leader: Dictionary = _get_warband_leader(warband_id)
	if leader.is_empty():
		return
	var from: Vector2i = leader.get("grid_pos", Vector2i.ZERO)
	var steps: int = _calc_warband_path_length(warband_id, from, target)
	if steps <= 0:
		return
	var members: Array[Dictionary] = _get_warband_members(warband_id)
	var ap_cost: int = _get_warband_move_ap(steps, members.size())
	if _turn_manager:
		var ok: bool = _turn_manager.spend_ap(_turn_manager.current_player, ap_cost)
		if not ok:
			return
	var delta: Vector2i = target - from
	for member in members:
		var member_from: Vector2i = member.get("grid_pos", Vector2i.ZERO)
		var member_to: Vector2i = member_from + delta
		member["grid_pos"] = member_to
		member["has_moved"] = true
		_start_move_visual(int(member.get("id", -1)), member_from, member_to)
		if _fog_manager and _turn_manager:
			_fog_manager.reveal_area(_turn_manager.current_player, member_to.x, member_to.y, _get_unit_vision_value(member))
	var numgr = get_parent().get_node_or_null("NeutralUnitManager2D")
	if numgr:
		numgr.queue_redraw()
	_reachable_tiles = _calc_warband_reachable(leader)
	unit_selected.emit(_make_unit_view(leader))
	queue_redraw()


# ========== 战斗系统 ==========

func _begin_tactical_encounter(initiator_id: int, target_id: int) -> bool:
	if _in_combat:
		return false
	var initiator: Dictionary = _get_unit_by_id(initiator_id)
	var target: Dictionary = _get_unit_by_id(target_id)
	if initiator.is_empty() or target.is_empty():
		return false
	if int(initiator.get("faction", -1)) == int(target.get("faction", -2)):
		return false
	if int(initiator.get("faction", -1)) < 0 or int(target.get("faction", -1)) < 0:
		return false
	var first_id: int = _choose_tactical_first_attacker(initiator, target)
	var first_attacker: Dictionary = _get_unit_by_id(first_id)
	var decision_unit: Dictionary = target if first_id == initiator_id else initiator
	if not _can_unit_attack_unit(first_attacker, decision_unit):
		if _can_unit_attack_unit(initiator, target):
			first_attacker = initiator
			decision_unit = target
			first_id = initiator_id
		elif _can_unit_attack_unit(target, initiator):
			first_attacker = target
			decision_unit = initiator
			first_id = target_id
		else:
			return false

	_in_combat = true
	_combat_sequence_id += 1
	_reachable_tiles = []
	_attack_range_tiles = []
	_throw_range_tiles = []
	_throw_beast_source_id = -1
	_emit_action_preview({})
	_combat_data = {
		"mode": "tactical_decision",
		"phase": "decision",
		"initiator_id": initiator_id,
		"target_id": target_id,
		"first_attacker_id": first_id,
		"decision_unit_id": int(decision_unit.get("id", -1)),
		"committed_to_engage": false,
		"sequence_id": _combat_sequence_id,
	}
	combat_started.emit()
	var dead: bool = _apply_unit_attack_damage(first_attacker, decision_unit)
	if dead:
		_remove_unit_after_attack(int(decision_unit.get("id", -1)), first_attacker)
		_finish_combat_state()
		queue_redraw()
		return true
	_show_combat_choice_panel(decision_unit, first_attacker)
	queue_redraw()
	return true


func _start_locked_duel(first_attacker_id: int, second_unit_id: int) -> void:
	if _combat_timer:
		_combat_timer.stop()
		_combat_timer.queue_free()
		_combat_timer = null
	_hide_combat_choice_panel()
	_combat_data = {
		"unit_a_id": first_attacker_id,
		"unit_b_id": second_unit_id,
		"next_attacker_id": first_attacker_id,
		"initial_attacker_id": first_attacker_id,
		"locked_until_death": true,
	}
	_combat_timer = Timer.new()
	_combat_timer.wait_time = 1.0
	_combat_timer.timeout.connect(_combat_tick)
	add_child(_combat_timer)
	_combat_timer.start()
	_combat_tick()


func _show_combat_choice_panel(decision_unit: Dictionary, first_attacker: Dictionary) -> void:
	_ensure_combat_choice_panel()
	if _combat_choice_panel == null:
		return
	var unit_name: String = _get_unit_data(decision_unit).unit_name
	var attacker_name: String = _get_unit_data(first_attacker).unit_name
	_combat_choice_label.text = "%s 受到 %s 先手攻击，选择撤离或战斗。" % [unit_name, attacker_name]
	_combat_choice_panel.visible = true


func _ensure_combat_choice_panel() -> void:
	if _combat_choice_panel != null:
		return
	var parent_node: Node = null
	if get_tree().current_scene != null:
		parent_node = get_tree().current_scene.get_node_or_null("UI")
	if parent_node == null:
		parent_node = self
	_combat_choice_panel = Panel.new()
	_combat_choice_panel.name = "CombatChoicePanel"
	_combat_choice_panel.position = Vector2(760.0, 420.0)
	_combat_choice_panel.size = Vector2(420.0, 150.0)
	_combat_choice_panel.visible = false
	_combat_choice_panel.mouse_filter = Control.MOUSE_FILTER_STOP
	_combat_choice_panel.z_index = 120
	parent_node.add_child(_combat_choice_panel)

	var margin := MarginContainer.new()
	margin.set_anchors_preset(Control.PRESET_FULL_RECT)
	margin.add_theme_constant_override("margin_left", 14)
	margin.add_theme_constant_override("margin_right", 14)
	margin.add_theme_constant_override("margin_top", 14)
	margin.add_theme_constant_override("margin_bottom", 14)
	_combat_choice_panel.add_child(margin)

	var vbox := VBoxContainer.new()
	vbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	vbox.size_flags_vertical = Control.SIZE_EXPAND_FILL
	margin.add_child(vbox)

	_combat_choice_label = Label.new()
	_combat_choice_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_combat_choice_label.add_theme_font_size_override("font_size", 16)
	vbox.add_child(_combat_choice_label)

	var buttons := HBoxContainer.new()
	buttons.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	vbox.add_child(buttons)

	_combat_retreat_button = Button.new()
	_combat_retreat_button.text = "撤离"
	_combat_retreat_button.focus_mode = Control.FOCUS_NONE
	_combat_retreat_button.pressed.connect(_on_combat_retreat_pressed)
	buttons.add_child(_combat_retreat_button)

	_combat_engage_button = Button.new()
	_combat_engage_button.text = "战斗"
	_combat_engage_button.focus_mode = Control.FOCUS_NONE
	_combat_engage_button.pressed.connect(_on_combat_engage_pressed)
	buttons.add_child(_combat_engage_button)


func _hide_combat_choice_panel() -> void:
	if _combat_choice_panel != null:
		_combat_choice_panel.visible = false


func _on_combat_retreat_pressed() -> void:
	_resolve_tactical_retreat()


func _on_combat_engage_pressed() -> void:
	_resolve_tactical_engage()


func _resolve_tactical_retreat() -> void:
	if str(_combat_data.get("mode", "")) != "tactical_decision":
		return
	if bool(_combat_data.get("committed_to_engage", false)):
		return
	var retreat_unit: Dictionary = _get_unit_by_id(int(_combat_data.get("decision_unit_id", -1)))
	var attacker: Dictionary = _get_unit_by_id(int(_combat_data.get("first_attacker_id", -1)))
	if retreat_unit.is_empty() or attacker.is_empty():
		_finish_combat_state()
		return
	if int(retreat_unit.get("faction", -1)) == 0:
		retreat_unit[RETREAT_HIDDEN_FROM_FACTION_KEY] = int(attacker.get("faction", -1))
	else:
		retreat_unit[RETREAT_UNSELECTABLE_BY_UNIT_KEY] = int(attacker.get("id", -1))
	print("[Combat] Unit retreated from tactical encounter.")
	_finish_combat_state()
	queue_redraw()


func _resolve_tactical_engage() -> void:
	if str(_combat_data.get("mode", "")) != "tactical_decision":
		return
	_combat_data["committed_to_engage"] = true
	_combat_data["phase"] = "committed_approach"
	_hide_combat_choice_panel()
	_continue_committed_engage()


func _continue_committed_engage(expected_sequence_id: int = -1) -> void:
	if not _in_combat:
		return
	if str(_combat_data.get("mode", "")) != "tactical_decision":
		return
	if expected_sequence_id >= 0 and int(_combat_data.get("sequence_id", -2)) != expected_sequence_id:
		return
	if not bool(_combat_data.get("committed_to_engage", false)):
		return
	var mover: Dictionary = _get_unit_by_id(int(_combat_data.get("decision_unit_id", -1)))
	var opponent: Dictionary = _get_unit_by_id(int(_combat_data.get("first_attacker_id", -1)))
	if mover.is_empty() or opponent.is_empty():
		_finish_combat_state()
		return
	if _can_unit_attack_unit(mover, opponent):
		_start_locked_duel(int(mover.get("id", -1)), int(opponent.get("id", -1)))
		return
	var approach_tile: Vector2i = _find_forced_approach_tile(mover, opponent)
	if approach_tile.x < 0:
		print("[Combat] Forced approach blocked; ending encounter.")
		_finish_combat_state()
		return
	_move_unit_without_ap(mover, approach_tile)
	var dead: bool = _apply_unit_attack_damage(opponent, mover)
	if dead:
		_remove_unit_after_attack(int(mover.get("id", -1)), opponent)
		_finish_combat_state()
		queue_redraw()
		return
	_schedule_committed_engage_continue()


func _schedule_committed_engage_continue() -> void:
	if not is_inside_tree():
		return
	var sequence_id: int = int(_combat_data.get("sequence_id", -1))
	var timer: SceneTreeTimer = get_tree().create_timer(MOVE_VISUAL_DURATION + 0.1)
	timer.timeout.connect(_continue_committed_engage.bind(sequence_id))


func _find_forced_approach_tile(mover: Dictionary, opponent: Dictionary) -> Vector2i:
	var reachable: Array = _calc_reachable(mover)
	if reachable.is_empty():
		return Vector2i(-1, -1)
	var opponent_pos: Vector2i = opponent.get("grid_pos", Vector2i.ZERO)
	var current_pos: Vector2i = mover.get("grid_pos", Vector2i.ZERO)
	var current_dist: int = _grid_distance(current_pos, opponent_pos)
	var attack_range: int = _get_unit_data(mover).attack_range
	var best_attack_tile := Vector2i(-1, -1)
	var best_attack_dist: int = 999
	var best_approach_tile := Vector2i(-1, -1)
	var best_approach_dist: int = current_dist
	for tile_variant in reachable:
		var tile: Vector2i = tile_variant
		var dist: int = _grid_distance(tile, opponent_pos)
		if dist <= attack_range and dist < best_attack_dist:
			best_attack_tile = tile
			best_attack_dist = dist
		elif dist < best_approach_dist:
			best_approach_tile = tile
			best_approach_dist = dist
	if best_attack_tile.x >= 0:
		return best_attack_tile
	return best_approach_tile


func _move_unit_without_ap(unit: Dictionary, target: Vector2i) -> void:
	var from: Vector2i = unit.get("grid_pos", Vector2i.ZERO)
	unit["grid_pos"] = target
	unit["has_moved"] = true
	_start_move_visual(int(unit.get("id", -1)), from, target)
	if _fog_manager:
		var faction: int = int(unit.get("faction", -1))
		_fog_manager.reveal_area(faction, target.x, target.y, _get_unit_vision_value(unit))
	queue_redraw()


func _initiate_combat(attacker_id: int, defender_id: int) -> void:
	if _begin_tactical_encounter(attacker_id, defender_id):
		return
	if _in_combat:
		return
	## 发起决斗：创建 1 秒间隔 Timer，轮流攻击直至死亡
	_in_combat = true
	_combat_data = {
		"unit_a_id": attacker_id,
		"unit_b_id": defender_id,
		"next_attacker_id": attacker_id,
		"initial_attacker_id": attacker_id,
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


func _initiate_ranged_combat(attacker_id: int, defender_id: int) -> void:
	if attacker_id < 0 or defender_id < 0:
		return
	if _begin_tactical_encounter(attacker_id, defender_id):
		return
	if _in_combat:
		return
	_in_combat = true
	_combat_data = {
		"mode": "ranged_unit",
		"attacker_id": attacker_id,
		"defender_id": defender_id,
	}
	combat_started.emit()
	_combat_timer = Timer.new()
	_combat_timer.wait_time = 1.0
	_combat_timer.timeout.connect(_ranged_combat_tick)
	add_child(_combat_timer)
	_combat_timer.start()
	_ranged_combat_tick()


func _initiate_ranged_neutral_combat(attacker_id: int, neutral_id: int, neutral_mgr: Node) -> void:
	if attacker_id < 0 or neutral_id < 0 or neutral_mgr == null:
		return
	_in_combat = true
	_combat_data = {
		"mode": "ranged_neutral",
		"attacker_id": attacker_id,
		"neutral_id": neutral_id,
		"neutral_mgr": neutral_mgr,
	}
	combat_started.emit()
	_combat_timer = Timer.new()
	_combat_timer.wait_time = 1.0
	_combat_timer.timeout.connect(_ranged_neutral_combat_tick)
	add_child(_combat_timer)
	_combat_timer.start()
	_ranged_neutral_combat_tick()


func _ranged_combat_tick() -> void:
	var attacker: Dictionary = _get_unit_by_id(int(_combat_data.get("attacker_id", -1)))
	var defender: Dictionary = _get_unit_by_id(int(_combat_data.get("defender_id", -1)))
	if attacker.is_empty() or defender.is_empty():
		_finish_ranged_combat()
		return
	var raw_dmg: int = _get_unit_attack_value(attacker)
	var reduction: int = _get_unit_damage_reduction(defender)
	var dmg: int = maxi(1, raw_dmg - reduction) if raw_dmg > 0 else 0
	_play_attack_effect(attacker, defender)
	defender["hp"] = int(defender.get("hp", 0)) - dmg
	if dmg > 0:
		_try_apply_scout_poison_weaken(attacker, defender)
	_play_hit_effect(int(defender.get("id", -1)), defender.get("grid_pos", Vector2i.ZERO), dmg)
	if int(defender.get("hp", 0)) <= 0:
		_remove_unit_after_attack(int(defender.get("id", -1)), attacker)
		_finish_ranged_combat()
		return
	if _apply_elven_first_strike_followup(attacker, defender):
		if int(defender.get("hp", 0)) <= 0:
			_remove_unit_after_attack(int(defender.get("id", -1)), attacker)
			_finish_ranged_combat()
			return
	queue_redraw()


func _ranged_neutral_combat_tick() -> void:
	var attacker: Dictionary = _get_unit_by_id(int(_combat_data.get("attacker_id", -1)))
	var neutral_mgr: Node = _combat_data.get("neutral_mgr", null)
	if attacker.is_empty() or neutral_mgr == null or not neutral_mgr.has_method("get_neutral_unit_by_id"):
		_finish_ranged_combat()
		return
	var neutral_id: int = int(_combat_data.get("neutral_id", -1))
	var target: Dictionary = neutral_mgr.call("get_neutral_unit_by_id", neutral_id)
	if target.is_empty():
		_finish_ranged_combat()
		return
	var dmg: int = _get_unit_attack_value(attacker)
	if neutral_mgr.has_method("apply_ranged_damage"):
		neutral_mgr.call("apply_ranged_damage", neutral_id, int(attacker.get("faction", -1)), dmg)
	target = neutral_mgr.call("get_neutral_unit_by_id", neutral_id)
	if target.is_empty():
		_finish_ranged_combat()
		return
	queue_redraw()


func _finish_ranged_combat() -> void:
	if _combat_timer:
		_combat_timer.stop()
		_combat_timer.queue_free()
		_combat_timer = null
	_finish_combat_state()


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
	if int(attacker.get("id", -1)) == int(_combat_data.get("initial_attacker_id", -1)):
		_apply_elven_first_strike_followup(attacker, defender)

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
	if _in_combat and _combat_data.is_empty() and _building_attack_data.is_empty():
		_finish_combat_state()
	queue_redraw()


func _finish_combat_state() -> void:
	_hide_combat_choice_panel()
	if _building_attack_timer != null:
		_building_attack_timer.stop()
	_in_combat = false
	_combat_sequence_id += 1
	_combat_data = {}
	_building_attack_data = {}
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


func get_unit_vision_for_fog(unit: Dictionary) -> int:
	return _get_unit_vision_value(unit)



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
	if _is_active_warband_member(unit):
		bonus += 1
	var penalty: int = 0
	var statuses: Dictionary = unit.get("statuses", {})
	if int(statuses.get("poison_weakened_turns", 0)) > 0:
		penalty += 1
	return maxi(0, data.atk + bonus - penalty)


func _get_unit_damage_reduction(unit: Dictionary) -> int:
	var data: UnitData = _get_unit_data(unit)
	var bonus: int = data.damage_reduction
	bonus += _get_building_effect_modifier(unit, BuildingEffectService.MOD_DAMAGE_REDUCTION)
	bonus += _get_technology_modifier_for_unit(unit, "damage_reduction_bonus")
	if _has_adjacent_warband_ally(unit):
		bonus += 1
	return maxi(0, bonus)


func _can_trigger_elven_first_strike(attacker: Dictionary, defender: Dictionary) -> bool:
	if attacker.is_empty() or defender.is_empty():
		return false
	var attacker_data: UnitData = _get_unit_data(attacker)
	if int(attacker.get("faction", -1)) != 0 and not ("elf" in attacker_data.tags):
		return false
	if attacker_data.atk <= 0:
		return false
	if bool(attacker.get("has_first_struck", false)):
		return false
	if int(attacker.get("faction", -1)) == int(defender.get("faction", -2)):
		return false
	var attacker_pos: Vector2i = attacker.get("grid_pos", Vector2i.ZERO)
	var defender_pos: Vector2i = defender.get("grid_pos", Vector2i.ZERO)
	var distance: int = _grid_distance(attacker_pos, defender_pos)
	return distance <= _get_unit_vision_value(attacker) and distance > _get_unit_vision_value(defender)


func _apply_elven_first_strike_followup(attacker: Dictionary, defender: Dictionary) -> bool:
	if not _can_trigger_elven_first_strike(attacker, defender):
		return false
	var raw_dmg: int = _get_unit_attack_value(attacker)
	var reduction: int = _get_unit_damage_reduction(defender)
	var normal_damage: int = maxi(1, raw_dmg - reduction) if raw_dmg > 0 else 0
	if normal_damage <= 0:
		return false
	var followup_damage: int = maxi(1, int(ceil(float(normal_damage) * ELVEN_FIRST_STRIKE_SECOND_HIT_RATIO)))
	defender["hp"] = int(defender.get("hp", 0)) - followup_damage
	attacker["has_first_struck"] = true
	_play_hit_effect(int(defender.get("id", -1)), defender.get("grid_pos", Vector2i.ZERO), followup_damage)
	return true


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
		"has_thrown_beast": false,
		"fog_reveal_cooldown_turns": 0,
		"fog_conceal_cooldown_turns": 0,
		"retreat_hidden_from_faction": -1,
		"retreat_unselectable_by_unit_id": -1,
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
	if _wall_manager == null and is_inside_tree():
		_wall_manager = get_parent().get_node_or_null("WallBlueprintManager2D")
	if _wall_manager != null and _wall_manager.has_method("blocks_movement_at"):
		if bool(_wall_manager.call("blocks_movement_at", Vector2i(gx, gy))):
			return false
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


func _get_unit_skill_actions(unit: Dictionary) -> Array:
	var actions: Array = []
	if unit.is_empty():
		return actions
	if _is_fog_reveal_unit(unit):
		actions.append(_make_fog_skill_action(unit, "fog_reveal", "揭示迷雾", FOG_REVEAL_AP_COST, FOG_REVEAL_COOLDOWN_KEY, _fog_reveal_mode))
	if _is_fog_conceal_unit(unit):
		actions.append(_make_fog_skill_action(unit, "fog_conceal", "遮蔽迷雾", FOG_CONCEAL_AP_COST, FOG_CONCEAL_COOLDOWN_KEY, _fog_conceal_mode))
	if _is_orc_slinger(unit):
		actions.append(_make_throw_skill_action(unit))
	if _is_orc_warband_unit(unit) or int(unit.get("warband_id", -1)) >= 0 or _is_warband_selection_active():
		_append_warband_skill_actions(actions, unit)
	return actions


func _make_fog_skill_action(unit: Dictionary, action_id: String, label: String, ap_cost: int, cooldown_key: String, active: bool) -> Dictionary:
	var cooldown: int = int(unit.get(cooldown_key, 0))
	var enabled: bool = true
	var status: String = "可用"
	var reason: String = ""
	if active:
		if action_id == "fog_reveal":
			status = "选择任意地图点"
		else:
			status = "选择目标中"
	elif int(unit.get("faction", -1)) != _current_player_id():
		enabled = false
		status = "非当前回合"
		reason = "只能在该单位所属玩家的回合使用。"
	elif cooldown > 0:
		enabled = false
		status = "冷却 %d 回合" % cooldown
		reason = status
	elif not _has_ap(ap_cost):
		enabled = false
		status = "AP 不足"
		reason = "需要 %d AP。" % ap_cost
	return {
		"id": action_id,
		"unit_id": int(unit.get("id", -1)),
		"label": label,
		"enabled": enabled,
		"active": active,
		"cooldown": cooldown,
		"status": status,
		"reason": reason,
	}


func _make_throw_skill_action(unit: Dictionary) -> Dictionary:
	var used: bool = bool(unit.get("has_thrown_beast", false))
	var has_beast: bool = not _get_adjacent_throw_beast(unit).is_empty()
	var enabled: bool = true
	var status: String = "可用"
	var reason: String = "点击后选择相邻猎齿兽，并在地图上选择落点。"
	var cooldown: int = 0
	if int(unit.get("faction", -1)) != _current_player_id():
		enabled = false
		status = "非当前回合"
		reason = "只能在该单位所属玩家的回合使用。"
	elif used:
		enabled = false
		status = "冷却 1 回合"
		reason = "本回合已经投掷过，下个本方回合恢复。"
		cooldown = 1
	elif not has_beast:
		enabled = false
		status = "需要相邻猎齿兽"
		reason = "投掷者旁边必须有己方猎齿兽。"
	elif not _has_ap(SLINGER_THROW_AP_COST):
		enabled = false
		status = "AP 不足"
		reason = "需要 %d AP。" % SLINGER_THROW_AP_COST
	return {
		"id": "throw_beast",
		"unit_id": int(unit.get("id", -1)),
		"label": "投掷猎齿兽",
		"enabled": enabled,
		"active": _throw_beast_source_id >= 0,
		"cooldown": cooldown,
		"status": status,
		"reason": reason,
	}


func _append_warband_skill_actions(actions: Array, unit: Dictionary) -> void:
	var unit_id: int = int(unit.get("id", -1))
	var selecting: bool = _is_warband_selection_active() and unit_id == _warband_selection_leader_id
	var warband_id: int = int(unit.get("warband_id", -1))
	if selecting:
		var selected_count: int = _warband_selection_ids.size()
		var can_confirm: bool = selected_count >= WARBAND_MIN_MEMBERS and _has_ap(WARBAND_AP_COST)
		var status: String = "%d/%d" % [selected_count, WARBAND_MIN_MEMBERS]
		if not _has_ap(WARBAND_AP_COST):
			status = "AP 不足"
		actions.append({
			"id": "warband_confirm",
			"unit_id": unit_id,
			"label": "确认战团",
			"enabled": can_confirm,
			"active": true,
			"cooldown": 0,
			"status": status,
			"reason": "至少选择 %d 名兽人单位，需要 %d AP。" % [WARBAND_MIN_MEMBERS, WARBAND_AP_COST],
		})
		actions.append({
			"id": "warband_cancel",
			"unit_id": unit_id,
			"label": "取消战团",
			"enabled": true,
			"active": true,
			"cooldown": 0,
			"status": "选择中",
			"reason": "取消当前战团选择。",
		})
		return
	if warband_id >= 0:
		actions.append({
			"id": "warband_disband",
			"unit_id": unit_id,
			"label": "解散战团",
			"enabled": int(unit.get("faction", -1)) == _current_player_id(),
			"active": false,
			"cooldown": 0,
			"status": "已编组",
			"reason": "解除该单位所在战团。",
		})
		return
	var can_form: bool = _can_unit_join_warband(unit, true) and _get_warband_candidates(unit).size() >= WARBAND_MIN_MEMBERS and _has_ap(WARBAND_AP_COST)
	var form_status: String = "可用"
	var form_reason: String = "选择附近兽人单位组成战团，需要 %d AP。" % WARBAND_AP_COST
	if int(unit.get("faction", -1)) != _current_player_id():
		can_form = false
		form_status = "非当前回合"
	elif not _has_ap(WARBAND_AP_COST):
		can_form = false
		form_status = "AP 不足"
	elif _get_warband_candidates(unit).size() < WARBAND_MIN_MEMBERS:
		can_form = false
		form_status = "人数不足"
		form_reason = "附近可编组兽人不足 %d 名。" % WARBAND_MIN_MEMBERS
	actions.append({
		"id": "warband_form",
		"unit_id": unit_id,
		"label": "组建战团",
		"enabled": can_form,
		"active": false,
		"cooldown": 0,
		"status": form_status,
		"reason": form_reason,
	})


func _is_fog_reveal_unit(unit: Dictionary) -> bool:
	return str(unit.get("template_id", "")) == ELF_FOG_REVEAL_CASTER_TEMPLATE_ID


func _is_fog_conceal_unit(unit: Dictionary) -> bool:
	return str(unit.get("template_id", "")) == ELF_FOG_CONCEAL_CASTER_TEMPLATE_ID


func _has_ap(amount: int) -> bool:
	if _turn_manager == null or not _turn_manager.has_method("get_ap"):
		return true
	return int(_turn_manager.call("get_ap", _current_player_id())) >= amount


func _current_player_id() -> int:
	if _turn_manager == null:
		return -1
	return int(_turn_manager.current_player)


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
	var warband_id: int = int(unit.get("warband_id", -1))
	var candidate_count: int = _get_warband_candidates(unit).size()
	var selecting: bool = _is_warband_selection_active() and int(unit.get("id", -1)) == _warband_selection_leader_id
	var member_count: int = _warband_selection_ids.size() if selecting else (_get_warband_member_count(warband_id) if warband_id >= 0 else candidate_count)
	view["can_form_warband"] = _can_unit_join_warband(unit, true) and warband_id < 0
	view["warband_id"] = warband_id
	view["warband_member_count"] = member_count
	view["warband_ap_text"] = _get_warband_ap_text(member_count)
	view["warband_selecting"] = selecting
	view["warband_selected_count"] = _warband_selection_ids.size() if selecting else 0
	view["skills"] = _get_unit_skill_actions(unit)
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


func _is_tile_empty_ignoring_units(gx: int, gy: int, ignored_unit_ids: Array[int]) -> bool:
	var pos := Vector2i(gx, gy)
	for u in _units:
		if int(u.get("id", -1)) in ignored_unit_ids:
			continue
		if u["grid_pos"] == pos:
			return false
	var bmgr = get_parent().get_node("BuildingManager2D")
	if bmgr and bmgr.is_tile_occupied(gx, gy):
		return false
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
