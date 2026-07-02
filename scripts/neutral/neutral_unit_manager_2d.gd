extends Node2D
const GameStageRulesScript = preload("res://scripts/rules/game_stage_rules.gd")
const FIRE_DRAGON_IDLE_TEXTURE: Texture2D = preload("res://assets/texture/character/dragon/Fire-Dragon-Idle.png")
const FIRE_DRAGON_ATTACK_TEXTURE: Texture2D = preload("res://assets/texture/character/dragon/Fire-Dragon-Attack.png")
const ICE_DRAGON_IDLE_TEXTURE: Texture2D = preload("res://assets/texture/character/dragon/Ice-Dragon-Idle.png")
const ICE_DRAGON_ATTACK_TEXTURE: Texture2D = preload("res://assets/texture/character/dragon/Ice-Dragon-Attack.png")
## 中立生物管理器 — 亚龙、流浪商队、哥布林复仇队
##
## 独立于 UnitManager2D，作为 GameBoard 同级子节点
## 常规单位 ID 起始 100000，AI 行为在 NEUTRAL_TURN 阶段触发

signal neutral_selected(unit_data: Dictionary)
signal selection_cleared()
signal neutral_combat_started()
signal neutral_combat_ended()
signal neutral_unit_killed(killer_player: int, neutral_unit: Dictionary)

# ========== 网格常量（与 UnitManager2D 一致） ==========
const GRID_COLS := 100
const GRID_ROWS := 56
const TILE_SIZE := 32.0
const GRID_CENTER := Vector2(49.5, 27.5)
const NEXT_ID_START := 100000

# ========== 渲染常量 ==========
const SELECT_COLOR := Color(1.0, 1.0, 1.0, 0.8)
const UNIT_RADIUS := 8.0
const NEUTRAL_COLOR := Color(0.6, 0.6, 0.6)        # 中立灰色
const HIDDEN_TRADER_COLOR := Color(0.55, 0.4, 0.2)  # 褐色（类似资源点）
const REVENGE_COLOR := Color(0.8, 0.15, 0.15)        # 红色复仇

# ========== 巨龙巢穴区域（放置亚龙用） ==========
const MOUNTAIN_CENTER := Vector2(49.5, 27.5)
const RING_INNER := 4.0
const RING_OUTER := 9.0
const ZONE_MOUNTAIN_NEST := 1
const ZONE_MOUNTAIN_BODY := 2
const ZONE_MOUNTAIN_PATH := 3
const ANCIENT_DRAGON_TEMPLATE_ID := "neutral.dragon.ancient"
const PROGENITOR_DRAGON_TEMPLATE_ID := "neutral.dragon.progenitor"
const FIRE_WYVERN_TEMPLATE_ID := "neutral.wyvern.fire"
const FROST_WYVERN_TEMPLATE_ID := "neutral.wyvern.frost"
const ANCIENT_DRAGON_TERRITORY_RADIUS := 5
const ANCIENT_DRAGON_AGGRO_RANGE := 4
const FIRE_DRAGON_ATTACK_FRAMES := 10
const ICE_DRAGON_ATTACK_FRAMES := 9
const FIRE_DRAGON_FRAME_SIZE := Vector2(320.0, 320.0)
const FIRE_DRAGON_DRAW_SIZE := Vector2(70.0, 70.0)
const FIRE_DRAGON_ATTACK_DURATION := 0.55
const MIN_WYVERN_SPACING := 3  # 亚龙之间最小曼哈顿间距

# ========== 数据存储 ==========
var _neutral_units: Array = []       # Array[Dictionary]
var _next_id := NEXT_ID_START
var _selected_id := -1

# AI 状态：unit_id -> { spawn_pos, behavior, aggro_range, aggro_target }
var _ai_data: Dictionary = {}

# 哥布林好感度：player -> score (0~100)
var _goblin_relations: Dictionary = {
	0: 100,
	1: 100,
	2: 100,
}

# ========== 战斗系统 ==========
var _in_combat := false
var _combat_timer: Timer = null
var _combat_data: Dictionary = {}  # { player_unit_id, neutral_unit_id, next_is_player }
var _hit_flash: Dictionary = {}    # unit_id -> true
var _shake_offsets: Dictionary = {} # unit_id -> Vector2
var _attack_visuals: Dictionary = {} # unit_id -> { t: float, flip_x: bool }

# ========== 外部引用 ==========
var _grid_manager: Node = null
var _turn_manager: Node = null
var _fog_manager: Node = null
var _unit_manager: Node = null
var _resource_tracker: Node = null
var _technology_service: Node = null


func _ready() -> void:
	_grid_manager = get_parent().get_node("GridManager2D")
	_fog_manager = get_parent().get_node("FogOfWar2D")
	_unit_manager = get_parent().get_node("UnitManager2D")
	_resource_tracker = get_parent().get_node("ResourceTracker")
	_technology_service = get_parent().get_node_or_null("TechnologyService")


func set_turn_manager(tm: Node) -> void:
	_turn_manager = tm
	if tm:
		tm.neutral_turn_started.connect(_on_neutral_turn_started)
		tm.neutral_turn_ended.connect(_on_neutral_turn_ended)
		tm.player_turn_started.connect(func(_p: int): queue_redraw())


# ========== 单位管理 ==========

func add_neutral_unit(
		template_id: String,
		display_name: String,
		grid_pos: Vector2i,
		hp: int,
		hp_max: int,
		atk: int,
		move_max: int,
		vision: int,
		behavior: String = "",
		aggro_range: int = 0) -> int:
	## 添加一个中立单位到地图上。返回 unit_id（-1 表示失败）。
	if not _is_valid_placement_for_behavior(grid_pos, behavior):
		return -1

	var uid := _next_id
	_next_id += 1

	var unit := {
		"id": uid,
		"template_id": template_id,
		"display_name": display_name,
		"faction": -1,
		"grid_pos": grid_pos,
		"hp": hp,
		"hp_max": hp_max,
		"atk": atk,
		"move_max": move_max,
		"vision": vision,
		"has_moved": false,
		"has_attacked": false,
	}
	_neutral_units.append(unit)

	if not behavior.is_empty():
		_ai_data[uid] = {
			"spawn_pos": grid_pos,
			"behavior": behavior,
			"aggro_range": aggro_range,
			"aggro_target": -1,
		}

	queue_redraw()
	return uid


func remove_neutral_unit(uid: int) -> void:
	for i in range(_neutral_units.size() - 1, -1, -1):
		if _neutral_units[i]["id"] == uid:
			_neutral_units.remove_at(i)
			break
	_ai_data.erase(uid)
	_attack_visuals.erase(uid)
	if _selected_id == uid:
		_selected_id = -1
		selection_cleared.emit()
	queue_redraw()



func select_neutral(uid: int) -> void:
	## 选中中立单位，发送数值信息到面板
	for u in _neutral_units:
		if u["id"] == uid:
			_selected_id = uid
			var view: Dictionary = u.duplicate(true)
			var ud: UnitData = UnitData.new(u.get("display_name", "中立单位"), UnitData.UnitCategory.SPECIAL, u.get("move_max", 0), u.get("atk", 0), u.get("hp_max", 1), u.get("vision", 0), 0)
			view["data"] = ud
			neutral_selected.emit(view)
			queue_redraw()
			return


func clear_selection() -> void:
	## 清除中立单位选中状态
	if _selected_id >= 0:
		_selected_id = -1
		selection_cleared.emit()
		queue_redraw()

func get_neutral_unit_at(grid_pos: Vector2i) -> Dictionary:
	for u in _neutral_units:
		if u["grid_pos"] == grid_pos:
			return u
	return {}


func get_neutral_unit_by_id(uid: int) -> Dictionary:
	for u in _neutral_units:
		if u["id"] == uid:
			return u
	return {}


func get_all_neutral_units() -> Array:
	return _neutral_units.duplicate()


func get_neutral_unit_count() -> int:
	return _neutral_units.size()


func get_ai_data_for(unit_id: int) -> Dictionary:
	## 获取指定单位 AI 数据的副本（供 UnitManager2D 查询行为类型）
	return _ai_data.get(unit_id, {}).duplicate()


# ========== 哥布林好感度 ==========

func apply_ranged_damage(neutral_unit_id: int, killer_player: int, damage: int) -> void:
	var neutral_unit: Dictionary = get_neutral_unit_by_id(neutral_unit_id)
	if neutral_unit.is_empty():
		return
	var final_damage: int = maxi(0, damage)
	neutral_unit["hp"] = int(neutral_unit.get("hp", 0)) - final_damage
	_play_hit_effect(neutral_unit_id, neutral_unit.get("grid_pos", Vector2i.ZERO), final_damage)
	if int(neutral_unit.get("hp", 0)) <= 0:
		_on_neutral_defeated(neutral_unit_id, killer_player)
	queue_redraw()


func get_goblin_relation(player: int) -> int:
	return _goblin_relations.get(player, 50)


func modify_goblin_relation(player: int, delta: int) -> void:
	var current: int = _goblin_relations.get(player, 50)
	current = clampi(current + delta, 0, 100)
	_goblin_relations[player] = current
	print("[中立] 阵营 %d 哥布林好感度: %d (变化 %+d)" % [player, current, delta])


func get_price_multiplier(player: int) -> float:
	var score: int = get_goblin_relation(player)
	if score >= 80:
		return 1.0
	elif score >= 50:
		return 1.2 + (80.0 - score) / 30.0 * 0.3  # 1.2~1.5
	elif score >= 20:
		return 1.5 + (50.0 - score) / 30.0 * 0.5  # 1.5~2.0
	else:
		return 2.0


func is_caravan_round(round_number: int) -> bool:
	return GameStageRulesScript.is_goblin_market_stage_start(round_number)


func should_caravan_visit(player: int) -> bool:
	## 按好感度决定商队是否光顾该玩家
	var score: int = get_goblin_relation(player)
	if score >= 80:
		return true
	elif score >= 50:
		return randf() < 0.7
	elif score >= 20:
		return randf() < 0.4
	else:
		return randf() < 0.1


# ========== 绘制 ==========

func _draw() -> void:
	if _neutral_units.is_empty():
		return

	for u in _neutral_units:
		var pos: Vector2i = u["grid_pos"]
		# 迷雾遮挡：未探索区域不显示
		if _fog_manager and _turn_manager:
			var viewer: int = _turn_manager.current_player
			if _fog_manager.get_fog(viewer, pos.x, pos.y) > 0.0:
				continue
		var world_pos: Vector2 = _grid_to_world(pos.x, pos.y)
		var uid: int = u["id"]
		var is_selected := uid == _selected_id
		var behavior: String = _ai_data.get(uid, {}).get("behavior", "")

		# 选中高亮
		if is_selected:
			draw_circle(world_pos, UNIT_RADIUS + 3.0, SELECT_COLOR)

		if _is_dragon_sprite(u):
			_draw_dragon_sprite(u, world_pos)
			continue

		# 颜色按行为类型
		var color: Color = NEUTRAL_COLOR
		match behavior:
			"guard":
				match u.get("template_id", ""):
					"neutral.wyvern.fire":
						color = Color(0.8, 0.3, 0.1)  # 火焰橙红
					"neutral.wyvern.frost":
						color = Color(0.3, 0.6, 0.9)  # 冰霜蓝
					"neutral.wyvern.toxic":
						color = Color(0.5, 0.2, 0.7)  # 毒液紫
					_:
						pass
			"ancient_dragon":
				color = Color(0.45, 0.16, 0.12)
			"progenitor_dragon":
				color = Color(0.68, 0.05, 0.05)
			"hidden_trader":
				color = HIDDEN_TRADER_COLOR
			"revenge":
				color = REVENGE_COLOR

		# 填充圆
		draw_circle(world_pos, UNIT_RADIUS, color)

		# 黑色描边
		draw_arc(world_pos, UNIT_RADIUS, 0, TAU, 16, Color.BLACK, 1.5)

		# 标签文字（圆上方）

# ========== 玩家交互（点击检查） ==========



func _is_dragon_sprite(unit: Dictionary) -> bool:
	return not _get_dragon_sprite_spec(unit).is_empty()


func _get_dragon_sprite_spec(unit: Dictionary) -> Dictionary:
	match str(unit.get("template_id", "")):
		FIRE_WYVERN_TEMPLATE_ID:
			return {
				"idle": FIRE_DRAGON_IDLE_TEXTURE,
				"attack": FIRE_DRAGON_ATTACK_TEXTURE,
				"attack_frames": FIRE_DRAGON_ATTACK_FRAMES,
			}
		FROST_WYVERN_TEMPLATE_ID:
			return {
				"idle": ICE_DRAGON_IDLE_TEXTURE,
				"attack": ICE_DRAGON_ATTACK_TEXTURE,
				"attack_frames": ICE_DRAGON_ATTACK_FRAMES,
			}
	return {}


func _draw_dragon_sprite(unit: Dictionary, world_pos: Vector2) -> void:
	var uid: int = int(unit.get("id", -1))
	var spec: Dictionary = _get_dragon_sprite_spec(unit)
	if spec.is_empty():
		return
	var texture: Texture2D = spec.get("idle", FIRE_DRAGON_IDLE_TEXTURE)
	var frame: int = 0
	var flip_x := false
	if _attack_visuals.has(uid):
		texture = spec.get("attack", texture)
		var visual: Dictionary = _attack_visuals.get(uid, {})
		var t: float = float(visual.get("t", 0.0))
		var frame_count: int = int(spec.get("attack_frames", FIRE_DRAGON_ATTACK_FRAMES))
		frame = clampi(int(floor(t * float(frame_count))), 0, frame_count - 1)
		flip_x = bool(visual.get("flip_x", false))
	var offset: Vector2 = _shake_offsets.get(uid, Vector2.ZERO)
	var tint := Color.WHITE
	if _hit_flash.has(uid):
		tint = Color(1.0, 0.55, 0.45, 1.0)
	var src := Rect2(Vector2(FIRE_DRAGON_FRAME_SIZE.x * frame, 0.0), FIRE_DRAGON_FRAME_SIZE)
	var dst := Rect2(-FIRE_DRAGON_DRAW_SIZE * 0.5 + Vector2(0.0, -10.0), FIRE_DRAGON_DRAW_SIZE)
	draw_set_transform(world_pos + offset, 0.0, Vector2(-1.0, 1.0) if flip_x else Vector2.ONE)
	draw_texture_rect_region(texture, dst, src, tint)
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)


func get_unit_at_world(world_pos: Vector2) -> Dictionary:
	var gpos: Vector2i = _world_to_grid(world_pos)
	if not _in_bounds(gpos.x, gpos.y):
		return {}
	# 迷雾中的单位不可点击
	if _fog_manager and _turn_manager:
		var viewer: int = _turn_manager.current_player
		if _fog_manager.get_fog(viewer, gpos.x, gpos.y) > 0.0:
			return {}
	for i in range(_neutral_units.size() - 1, -1, -1):
		var unit: Dictionary = _neutral_units[i]
		if not _is_dragon_sprite(unit):
			continue
		var unit_pos: Vector2i = unit.get("grid_pos", Vector2i.ZERO)
		if _fog_manager and _turn_manager:
			var viewer2: int = _turn_manager.current_player
			if _fog_manager.get_fog(viewer2, unit_pos.x, unit_pos.y) > 0.0:
				continue
		var center: Vector2 = _grid_to_world(unit_pos.x, unit_pos.y) + Vector2(0.0, -10.0)
		var rect := Rect2(center - FIRE_DRAGON_DRAW_SIZE * 0.5, FIRE_DRAGON_DRAW_SIZE)
		if rect.has_point(world_pos):
			return unit
	return get_neutral_unit_at(gpos)


# ========== AI 行为（中立阶段） ==========

func _on_neutral_turn_started() -> void:
	print("[中立] 中立阶段开始，%d 个单位" % _neutral_units.size())
	_process_guard_ai()
	if _in_combat:
		return
	_process_ancient_dragon_ai()
	if _in_combat:
		return
	_process_revenge_ai()


func _on_neutral_turn_ended() -> void:
	queue_redraw()


func _process_guard_ai() -> void:
	## Guard 模式：每回合检测 aggro_range 内玩家单位
	for u in _neutral_units:
		var uid: int = u["id"]
		var ai: Dictionary = _ai_data.get(uid, {})
		if ai.get("behavior", "") != "guard":
			continue

		var pos: Vector2i = u["grid_pos"]
		var aggro: int = ai.get("aggro_range", 0)
		var target_id: int = ai.get("aggro_target", -1)

		# 如果已有目标，继续追击或攻击
		if target_id >= 0:
			var target := _find_player_unit(target_id)
			if target.is_empty():
				ai["aggro_target"] = -1
				continue
			var target_pos: Vector2i = target["grid_pos"]
			if _is_adjacent(pos, target_pos):
				# 相邻 → 触发战斗（中立先手）
				_start_ai_combat(uid, target_id)
				return
			else:
				# 移动一步靠近
				var next := _bfs_step_toward(pos, target_pos, 1)
				if next != pos:
					u["grid_pos"] = next
					print("[中立] Guard %d 移动到 %s" % [uid, str(next)])
				if _is_adjacent(next, target_pos):
					_start_ai_combat(uid, target_id)
					return
			continue

		# 无目标，扫描范围内玩家单位
		var nearest := _find_nearest_player_unit(pos, aggro)
		if nearest >= 0:
			ai["aggro_target"] = nearest
			print("[中立] Guard %d 进入攻击状态，目标 %d" % [uid, nearest])


func _process_ancient_dragon_ai() -> void:
	for u in _neutral_units:
		var uid: int = int(u.get("id", -1))
		var ai: Dictionary = _ai_data.get(uid, {})
		if str(ai.get("behavior", "")) != "ancient_dragon":
			continue

		var pos: Vector2i = u.get("grid_pos", Vector2i.ZERO)
		var home: Vector2i = ai.get("spawn_pos", pos)
		var territory_radius: int = int(ai.get("territory_radius", ANCIENT_DRAGON_TERRITORY_RADIUS))
		var aggro: int = int(ai.get("aggro_range", ANCIENT_DRAGON_AGGRO_RANGE))
		var target_id: int = int(ai.get("aggro_target", -1))

		if target_id >= 0:
			var target: Dictionary = _find_player_unit(target_id)
			if target.is_empty():
				ai["aggro_target"] = -1
				_move_ancient_dragon_idle(u, ai, home, territory_radius)
				continue
			var target_pos: Vector2i = target.get("grid_pos", Vector2i.ZERO)
			if not _is_in_ancient_dragon_territory(target_pos, home, territory_radius):
				ai["aggro_target"] = -1
				_return_ancient_dragon_home(u, uid, home, territory_radius)
				continue
			if _is_adjacent(pos, target_pos):
				_start_ai_combat(uid, target_id)
				return
			var next: Vector2i = _bfs_step_toward_for_ancient_dragon(pos, target_pos, territory_radius * 2 + 2, home, territory_radius, uid)
			if next != pos:
				u["grid_pos"] = next
				pos = next
			if _is_adjacent(pos, target_pos):
				_start_ai_combat(uid, target_id)
				return
			continue

		var nearest: int = _find_nearest_player_unit_in_ancient_dragon_territory(pos, aggro, home, territory_radius)
		if nearest >= 0:
			ai["aggro_target"] = nearest
			continue

		_move_ancient_dragon_idle(u, ai, home, territory_radius)


func _process_revenge_ai() -> void:
	## Revenge 模式：向玩家领地移动，遇到单位/建筑则追击
	for u in _neutral_units:
		var uid: int = u["id"]
		var ai: Dictionary = _ai_data.get(uid, {})
		if ai.get("behavior", "") != "revenge":
			continue

		var pos: Vector2i = u["grid_pos"]
		var aggro: int = ai.get("aggro_range", 0)
		var target_id: int = ai.get("aggro_target", -1)

		if target_id >= 0:
			var target := _find_player_unit(target_id)
			if target.is_empty():
				ai["aggro_target"] = -1
				continue
			var target_pos: Vector2i = target["grid_pos"]
			if _is_adjacent(pos, target_pos):
				_start_ai_combat(uid, target_id)
				return
			var next = _bfs_step_toward(pos, target_pos, 1)
			if next != pos:
				u["grid_pos"] = next
				if _is_adjacent(next, target_pos):
					_start_ai_combat(uid, target_id)
					return
			continue

		# 无目标，扫描范围内
		var nearest := _find_nearest_player_unit(pos, aggro)
		if nearest >= 0:
			ai["aggro_target"] = nearest


# ========== 战斗系统 ==========

func is_in_combat() -> bool:
	return _in_combat


func is_combat_involving_player(player: int) -> bool:
	if not _in_combat:
		return false
	var player_unit_id: int = int(_combat_data.get("player_unit_id", -1))
	if player_unit_id < 0:
		return false
	var player_unit: Dictionary = _find_player_unit(player_unit_id)
	return not player_unit.is_empty() and int(player_unit.get("faction", -1)) == player


func engage_combat(player_unit_id: int, neutral_unit_id: int) -> void:
	## 玩家攻击中立生物的入口，由 UnitManager2D 在检测到点击时调用
	## Timer 交替攻击，玩家先行
	if _in_combat:
		return

	var nu := get_neutral_unit_by_id(neutral_unit_id)
	var pu := _find_player_unit(player_unit_id)
	if nu.is_empty() or pu.is_empty():
		return

	_in_combat = true
	_combat_data = {
		"player_unit_id": player_unit_id,
		"neutral_unit_id": neutral_unit_id,
		"next_is_player": true,
	}
	# 通知 unit_manager 锁定战斗状态
	if _unit_manager and _unit_manager.has_method("notify_combat_started"):
		_unit_manager.notify_combat_started()

	neutral_combat_started.emit()
	print("[战斗] 玩家 %d 攻击中立 %s" % [pu["faction"], nu.get("display_name", "")])

	_combat_timer = Timer.new()
	_combat_timer.wait_time = 1.0
	_combat_timer.timeout.connect(_combat_tick)
	add_child(_combat_timer)
	_combat_timer.start()

	# 先手立即出拳
	_combat_tick()


func _combat_tick() -> void:
	## 当前攻击方给对方造成伤害，检查死亡，否则切换回合
	if not _in_combat:
		return

	var player_unit := _find_player_unit(_combat_data.get("player_unit_id", -1))
	var neutral_unit := get_neutral_unit_by_id(_combat_data.get("neutral_unit_id", -1))

	# 任一单位已被移除（异常保护）
	if player_unit.is_empty() or neutral_unit.is_empty():
		_end_combat(-1)
		return

	var is_player_attacking: bool = _combat_data.get("next_is_player", true)

	if is_player_attacking:
		# 玩家攻击中立
		var dmg: int = 0
		if _unit_manager and _unit_manager.has_method("get_unit_atk_value"):
			dmg = _unit_manager.get_unit_atk_value(player_unit["id"])

		neutral_unit["hp"] -= dmg
		_play_hit_effect(neutral_unit["id"], neutral_unit["grid_pos"], dmg)
		print("[战斗] 玩家 -> 中立: %d 伤害，中立 HP: %d" % [dmg, neutral_unit["hp"]])

		if neutral_unit["hp"] <= 0:
			# 中立死亡
			var killer_player: int = player_unit["faction"]
			_on_neutral_defeated(neutral_unit["id"], killer_player)
			_end_combat(player_unit["id"])
			return

		# 切换为中立攻击
		_combat_data["next_is_player"] = false

	else:
		# 中立攻击玩家
		var dmg: int = neutral_unit.get("atk", 1)
		_start_neutral_attack_visual(neutral_unit, player_unit)
		player_unit["hp"] -= dmg

		# 完整受击效果（闪白 + shake + 飘字）
		if _unit_manager and _unit_manager.has_method("play_hit_effect_at"):
			_unit_manager.play_hit_effect_at(player_unit["grid_pos"], dmg, player_unit["id"])

		# 同时在自家队列 redraw
		queue_redraw()
		print("[战斗] 中立 -> 玩家: %d 伤害，玩家 HP: %d" % [dmg, player_unit["hp"]])

		if player_unit["hp"] <= 0:
			# 玩家单位死亡
			if _unit_manager and _unit_manager.has_method("remove_unit_by_id"):
				_unit_manager.remove_unit_by_id(player_unit["id"])
			_end_combat(neutral_unit["id"])
			return

		# 切换为玩家攻击
		_combat_data["next_is_player"] = true


func _end_combat(winner_id: int) -> void:
	## 结束战斗
	if _combat_timer:
		_combat_timer.stop()
		_combat_timer.queue_free()
		_combat_timer = null

	_in_combat = false
	_combat_data = {}
	neutral_combat_ended.emit()

	# 通知 unit_manager：胜者是玩家单位则自动选中，否则清除选中
	if _unit_manager and _unit_manager.has_method("notify_combat_ended"):
		var is_player_winner: bool = not _find_player_unit(winner_id).is_empty()
		if is_player_winner:
			_unit_manager.notify_combat_ended(winner_id)
		else:
			_unit_manager.notify_combat_ended()

	queue_redraw()
	print("[战斗] 结束，胜者 ID: %d" % winner_id)


func _on_neutral_defeated(neutral_unit_id: int, killer_player: int) -> void:
	## 中立单位被击杀后的处理：掉落、移除
	var template_id: String = ""
	var defeated_unit: Dictionary = {}
	for u in _neutral_units:
		if u["id"] == neutral_unit_id:
			defeated_unit = u.duplicate()
			template_id = u.get("template_id", "")
			break

	# 检查是否是亚龙（掉落龙血）
	var blood_key: String = GameCatalog.DRAGON_BLOOD_DROPS.get(template_id, "")
	if not blood_key.is_empty() and _resource_tracker:
		_resource_tracker.add_resource(killer_player, blood_key, 1)
		print("[中立] 阵营 %d 击杀 %s，获得 %s ×1" % [killer_player, template_id, blood_key])

		# 检查是否是龙类（掉落龙晶）
		if template_id.begins_with("neutral.") and ("dragon." in template_id or "wyvern." in template_id):
			if _resource_tracker:
				_resource_tracker.add_resource(killer_player, "dragon_crystal", 1)
				print("[中立] 阵营 %d 击杀 %s，获得 龙晶 x1" % [killer_player, template_id])
	if not defeated_unit.is_empty():
		neutral_unit_killed.emit(killer_player, defeated_unit)
		_apply_kill_food_reward(killer_player)
	remove_neutral_unit(neutral_unit_id)


func _apply_kill_food_reward(killer_player: int) -> void:
	var reward: int = _get_technology_modifier(killer_player, "kill_food_reward")
	reward += _get_technology_modifier(killer_player, "orc_kill_reward_bonus")
	if reward <= 0:
		return
	if _resource_tracker != null and _resource_tracker.has_method("add_resource"):
		_resource_tracker.add_resource(killer_player, "food", reward)


func _get_technology_modifier(player: int, key: String) -> int:
	if _technology_service == null and is_inside_tree():
		_technology_service = get_parent().get_node_or_null("TechnologyService")
	if _technology_service != null and _technology_service.has_method("get_modifier"):
		return int(_technology_service.call("get_modifier", player, key, 0))
	return 0


func _start_ai_combat(neutral_unit_id: int, player_unit_id: int) -> void:
	## AI 在中立阶段主动攻击玩家单位（中立先手）
	if _in_combat:
		return

	var nu := get_neutral_unit_by_id(neutral_unit_id)
	var pu := _find_player_unit(player_unit_id)
	if nu.is_empty() or pu.is_empty():
		return

	_in_combat = true
	_combat_data = {
		"player_unit_id": player_unit_id,
		"neutral_unit_id": neutral_unit_id,
		"next_is_player": false,  # 中立先手
	}
	neutral_combat_started.emit()
	print("[战斗] 中立 %s 攻击玩家 %d" % [nu.get("display_name", ""), pu["faction"]])

	_combat_timer = Timer.new()
	_combat_timer.wait_time = 1.0
	_combat_timer.timeout.connect(_combat_tick)
	add_child(_combat_timer)
	_combat_timer.start()

	# 中立先手出拳
	_combat_tick()


# ========== 战斗视觉效果 ==========

func _start_neutral_attack_visual(neutral_unit: Dictionary, target_unit: Dictionary) -> void:
	if not _is_dragon_sprite(neutral_unit):
		return
	var uid: int = int(neutral_unit.get("id", -1))
	var from_pos: Vector2i = neutral_unit.get("grid_pos", Vector2i.ZERO)
	var target_pos: Vector2i = target_unit.get("grid_pos", Vector2i.ZERO)
	var flip_x := target_pos.x < from_pos.x
	_attack_visuals[uid] = {"t": 0.0, "flip_x": flip_x}
	queue_redraw()
	var tween := create_tween()
	tween.tween_method(_set_attack_visual_t.bind(uid), 0.0, 1.0, FIRE_DRAGON_ATTACK_DURATION)
	tween.tween_callback(_finish_attack_visual.bind(uid))


func _set_attack_visual_t(t: float, unit_id: int) -> void:
	if not _attack_visuals.has(unit_id):
		return
	var visual: Dictionary = _attack_visuals[unit_id]
	visual["t"] = t
	_attack_visuals[unit_id] = visual
	queue_redraw()


func _finish_attack_visual(unit_id: int) -> void:
	_attack_visuals.erase(unit_id)
	queue_redraw()


func _play_hit_effect(unit_id: int, grid_pos: Vector2i, damage: int) -> void:
	## 触发中立单位的受击视觉效果
	if not is_inside_tree():
		return
	_hit_flash[unit_id] = true
	_hit_shake(unit_id)
	_show_damage_text(grid_pos, damage)
	queue_redraw()

	await get_tree().create_timer(0.15).timeout
	if not is_inside_tree():
		return
	_hit_flash.erase(unit_id)
	queue_redraw()


func _hit_shake(unit_id: int) -> void:
	_shake_offsets[unit_id] = Vector2.ZERO
	var tween := create_tween()
	tween.set_ease(Tween.EASE_OUT)
	tween.tween_method(_tween_shake.bind(unit_id), 1.0, 0.0, 0.12)


func _tween_shake(amount: float, unit_id: int) -> void:
	if amount <= 0.0:
		_shake_offsets.erase(unit_id)
	else:
		_shake_offsets[unit_id] = Vector2(
			randf_range(-3.0, 3.0),
			randf_range(-2.0, 2.0)
		) * amount
	queue_redraw()


func _show_damage_text(grid_pos: Vector2i, damage: int) -> void:
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


# ========== 打劫 / 复仇系统 ==========

func on_player_plundered(player: int, success: bool) -> void:
	## 玩家打劫商队后的处理（由 main.gd 在战斗结束后调用）
	## success: true=打劫成功, false=打劫失败（被反杀）
	if success:
		modify_goblin_relation(player, -40)  # 大幅下降
	else:
		modify_goblin_relation(player, -25)  # 下降

	# 概率触发复仇
	var revenge_chance: float = 0.5  # # TODO: 概率待平衡
	if randf() < revenge_chance:
		_spawn_revenge_squad(player)


func _spawn_revenge_squad(player: int) -> void:
	## 在玩家领地边缘生成哥布林复仇队
	if not _grid_manager:
		return

	# 尝试在主城周围寻空地
	var spawns: Array[Vector2i] = [
		Vector2i(35, 13), Vector2i(35, 43), Vector2i(62, 35)
	]
	if player < 0 or player >= spawns.size():
		return

	var center := spawns[player]
	var dirs := [Vector2i(0, -1), Vector2i(0, 1), Vector2i(-1, 0), Vector2i(1, 0),
				 Vector2i(-1, -1), Vector2i(1, -1), Vector2i(-1, 1), Vector2i(1, 1)]

	# 从主城向外 BFS 找可达边缘格
	var visited := {}
	var queue: Array = [center]
	visited[center] = true
	var candidates: Array = []

	while queue.size() > 0 and candidates.size() < 3:
		var pos: Vector2i = queue.pop_front()
		for dir in dirs:
			var npos := Vector2i(pos.x + dir.x, pos.y + dir.y)
			if visited.has(npos):
				continue
			if not _in_bounds(npos.x, npos.y):
				continue
			visited[npos] = true
			var dist: int = abs(npos.x - center.x) + abs(npos.y - center.y)
			if dist >= 4 and _is_passable(npos.x, npos.y):
				candidates.append(npos)
			elif dist < 8:
				queue.append(npos)

	if candidates.is_empty():
		print("[中立] 无法生成复仇队: 未找到合适位置")
		return

	# 生成 1~2 个复仇单位
	var count := 1 if candidates.size() < 2 else randi() % 2 + 1
	for i in range(mini(count, candidates.size())):
		var pos: Vector2i = candidates[i]
		var uid := add_neutral_unit("neutral.goblin.revenge", "哥布林复仇队", pos, 4, 4, 2, 2, 2, "revenge", 3)
		if uid >= 0:
			print("[中立] 复仇队生成于 %s (阵营 %d)" % [str(pos), player])


# ========== 初始放置 ==========

func place_initial_neutral_units() -> void:
	## 第一阶段：放置亚龙和流浪商队（确定性放置）
	_place_dragon_lair_units()
	_place_wyverns()
	_place_wander_traders()


func _place_dragon_lair_units() -> void:
	var center := Vector2i(int(round(MOUNTAIN_CENTER.x)), int(round(MOUNTAIN_CENTER.y)))
	var blocked_positions: Array[Vector2i] = []
	var progenitor_pos: Vector2i = _find_nearest_dragon_lair_tile(center, blocked_positions, 2)
	if progenitor_pos.x >= 0:
		var progenitor_id := add_neutral_unit(
			PROGENITOR_DRAGON_TEMPLATE_ID,
			"史祖龙",
			progenitor_pos,
			70,
			70,
			8,
			0,
			6,
			"progenitor_dragon",
			0
		)
		if progenitor_id >= 0:
			var progenitor_ai: Dictionary = _ai_data.get(progenitor_id, {})
			progenitor_ai["territory_radius"] = 0
			progenitor_ai["rest_heal"] = 0
			_ai_data[progenitor_id] = progenitor_ai

	var desired_positions: Array[Vector2i] = [
		center + Vector2i(-4, -3),
		center + Vector2i(-4, 3),
		center + Vector2i(5, 1),
	]
	var used_positions: Array[Vector2i] = []
	if progenitor_pos.x >= 0:
		used_positions.append(progenitor_pos)
	for desired_variant in desired_positions:
		var desired: Vector2i = desired_variant
		var pos: Vector2i = _find_nearest_dragon_lair_tile(desired, used_positions, 4)
		if pos.x < 0:
			continue
		var uid := add_neutral_unit(
			ANCIENT_DRAGON_TEMPLATE_ID,
			"古龙",
			pos,
			28,
			28,
			5,
			1,
			4,
			"ancient_dragon",
			ANCIENT_DRAGON_AGGRO_RANGE
		)
		if uid >= 0:
			var ancient_ai: Dictionary = _ai_data.get(uid, {})
			ancient_ai["territory_radius"] = ANCIENT_DRAGON_TERRITORY_RADIUS
			_ai_data[uid] = ancient_ai
			used_positions.append(pos)


func _place_wyverns() -> void:
	## 亚龙：围绕中央巨龙巢穴放置（极坐标环状候选）
	var placements: Array = [
		# [template_id, name, seed_offset, count, hp, atk, move, vision]
		["neutral.wyvern.fire", "火焰亚龙", 0, 3, 6, 3, 1, 2],
		["neutral.wyvern.frost", "冰霜亚龙", 100, 2, 8, 2, 1, 2],
		["neutral.wyvern.toxic", "毒液亚龙", 200, 2, 5, 3, 1, 2],
	]

	for p in placements:
		var template_id: String = p[0]
		var name: String = p[1]
		var seed_off: int = p[2]
		var count: int = p[3]
		var hp: int = p[4]
		var atk: int = p[5]
		var move: int = p[6]
		var vision: int = p[7]
		var placed := 0

		for attempt in range(200):
			if placed >= count:
				break
			# 极坐标生成环状候选点
			var h1: float = _simple_hash(attempt, seed_off, 0)
			var h2: float = _simple_hash(attempt, seed_off + 1, 1)
			var angle: float = h1 * TAU
			var dist: float = h2 * (RING_OUTER - RING_INNER) + RING_INNER
			var cx: int = int(round(MOUNTAIN_CENTER.x + cos(angle) * dist))
			var cy: int = int(round(MOUNTAIN_CENTER.y + sin(angle) * dist))
			var pos := Vector2i(clamp(cx, 0, GRID_COLS - 1), clamp(cy, 0, GRID_ROWS - 1))

			if not _grid_manager:
				continue
			# 检查曼哈顿距离确保在环内
			var md: int = abs(pos.x - int(MOUNTAIN_CENTER.x)) + abs(pos.y - int(MOUNTAIN_CENTER.y))
			if md < int(RING_INNER) or md > int(RING_OUTER):
				continue
			# 不在中央 void 区域（巨龙巢穴 / 山体）
			if _grid_manager and _grid_manager.has_method("get_zone_at"):
				var zt: int = _grid_manager.get_zone_at(pos.x, pos.y)
				if zt == 1 or zt == 2:  # MOUNTAIN_NEST=1, MOUNTAIN_BODY=2
					continue
			# 不与已有亚龙靠太近
			var too_close := false
			for u in _neutral_units:
				var d: int = abs(pos.x - u["grid_pos"].x) + abs(pos.y - u["grid_pos"].y)
				if d < MIN_WYVERN_SPACING:
					too_close = true
					break
			if too_close:
				continue
			if not _is_valid_placement(pos):
				continue
			if _is_near_spawn(pos, 5):
				continue

			var uid := add_neutral_unit(template_id, name, pos, hp, hp, atk, move, vision, "guard", 2)
			if uid >= 0:
				placed += 1

		# 宽松模式：扩大范围绕过山地不可通行区域
		if placed < count:
			print("[中立] %s 仅放置 %d/%d，尝试宽松模式" % [name, placed, count])
			for attempt in range(500):
				if placed >= count:
					break
				var h1: float = _simple_hash(attempt * 3, seed_off + 50, 2)
				var h2: float = _simple_hash(attempt * 3 + 1, seed_off + 51, 3)
				var angle: float = h1 * TAU
				var dist: float = h2 * 12.0 + 2.0
				var cx: int = int(round(MOUNTAIN_CENTER.x + cos(angle) * dist))
				var cy: int = int(round(MOUNTAIN_CENTER.y + sin(angle) * dist))
				var pos := Vector2i(clamp(cx, 0, GRID_COLS - 1), clamp(cy, 0, GRID_ROWS - 1))
				if not _is_passable(pos.x, pos.y):
					continue
				# 不在中央 void 区域
				if _grid_manager and _grid_manager.has_method("get_zone_at"):
					var zt: int = _grid_manager.get_zone_at(pos.x, pos.y)
					if zt == 1 or zt == 2:  # MOUNTAIN_NEST=1, MOUNTAIN_BODY=2
						continue
				# 不与已有亚龙靠太近
				var too_close := false
				for u in _neutral_units:
					var d: int = abs(pos.x - u["grid_pos"].x) + abs(pos.y - u["grid_pos"].y)
					if d < MIN_WYVERN_SPACING:
						too_close = true
						break
				if too_close:
					continue
				if _is_near_spawn(pos, 3):
					continue
				var uid := add_neutral_unit(template_id, name, pos, hp, hp, atk, move, vision, "guard", 2)
				if uid >= 0:
					placed += 1

		print("[中立] %s 放置完毕: %d 只" % [name, placed])
func _place_wander_traders() -> void:
	## 流浪商队：放置在阵营版图交界处，远离巨龙巢穴
	var count := 6
	var placed := 0
	var buffer_zones := [10, 11, 12]  # EMERALD_WOODLANDS, RIFT_HIGHLANDS, SCORCHED_BADLANDS
	var territory_zones := [7, 8, 9]  # ELF, DWARF, ORC
	var candidates: Array = []
	var dirs := [Vector2i(0, -1), Vector2i(0, 1), Vector2i(-1, 0), Vector2i(1, 0)]

	# 扫描全图，收集位于版图交界处且远离中心的候选格
	for y in range(GRID_ROWS):
		for x in range(GRID_COLS):
			var zt: int = _grid_manager.get_zone_at(x, y) if _grid_manager else -1
			if zt not in buffer_zones:
				continue
			# 检查是否至少有一个邻格是阵营领土
			var adj_to_territory := false
			for dir in dirs:
				var nx: int = x + dir.x
				var ny: int = y + dir.y
				if _in_bounds(nx, ny):
					var nzt: int = _grid_manager.get_zone_at(nx, ny) if _grid_manager else -1
					if nzt in territory_zones:
						adj_to_territory = true
						break
			if not adj_to_territory:
				continue
			# 远离巨龙巢穴
			var dist_from_center: int = abs(x - int(MOUNTAIN_CENTER.x)) + abs(y - int(MOUNTAIN_CENTER.y))
			if dist_from_center < 12:
				continue
			var pos := Vector2i(x, y)
			if not _is_valid_placement(pos):
				continue
			if _is_near_spawn(pos, 6):
				continue
			candidates.append(pos)

	# 确定性洗牌
	for i in range(candidates.size()):
		var j: int = int(_simple_hash(i, 42, 0) * candidates.size()) % candidates.size()
		var tmp: Vector2i = candidates[i]
		candidates[i] = candidates[j]
		candidates[j] = tmp

	# 放置
	for pos in candidates:
		if placed >= count:
			break
		var uid := add_neutral_unit("neutral.trader.wander", "流浪商队", pos, 1, 1, 0, 0, 0, "hidden_trader", 0)
		if uid >= 0:
			placed += 1

	print("[中立] 流浪商队放置: %d 个 (候选 %d)" % [placed, candidates.size()])


func _find_nearest_dragon_lair_tile(origin: Vector2i, blocked: Array[Vector2i], max_radius: int) -> Vector2i:
	for radius in range(max_radius + 1):
		for y in range(origin.y - radius, origin.y + radius + 1):
			for x in range(origin.x - radius, origin.x + radius + 1):
				var pos := Vector2i(x, y)
				if abs(pos.x - origin.x) + abs(pos.y - origin.y) > radius:
					continue
				if pos in blocked:
					continue
				if _is_valid_placement_for_behavior(pos, "ancient_dragon"):
					return pos
	return Vector2i(-1, -1)


func _is_valid_placement_for_behavior(pos: Vector2i, behavior: String) -> bool:
	if behavior == "ancient_dragon" or behavior == "progenitor_dragon":
		if not _in_bounds(pos.x, pos.y):
			return false
		if not _is_dragon_lair_zone(pos):
			return false
		if not _is_empty(pos.x, pos.y):
			return false
		return true
	return _is_valid_placement(pos)


func _is_dragon_lair_zone(pos: Vector2i) -> bool:
	if _grid_manager == null:
		return false
	if _grid_manager.has_method("is_dragon_lair_walkable"):
		return bool(_grid_manager.call("is_dragon_lair_walkable", pos.x, pos.y))
	if not _grid_manager.has_method("get_zone_at"):
		return false
	var zt: int = int(_grid_manager.get_zone_at(pos.x, pos.y))
	return zt == ZONE_MOUNTAIN_NEST or zt == ZONE_MOUNTAIN_BODY or zt == ZONE_MOUNTAIN_PATH


func _move_ancient_dragon_idle(unit: Dictionary, ai: Dictionary, home: Vector2i, territory_radius: int) -> void:
	var uid: int = int(unit.get("id", -1))
	var pos: Vector2i = unit.get("grid_pos", Vector2i.ZERO)
	if not _is_in_ancient_dragon_territory(pos, home, territory_radius):
		_return_ancient_dragon_home(unit, uid, home, territory_radius)
		return
	var hp: int = int(unit.get("hp", 0))
	var hp_max: int = int(unit.get("hp_max", hp))
	_patrol_ancient_dragon(unit, uid, home, territory_radius)


func _return_ancient_dragon_home(unit: Dictionary, uid: int, home: Vector2i, territory_radius: int) -> void:
	var pos: Vector2i = unit.get("grid_pos", Vector2i.ZERO)
	var next: Vector2i = _bfs_step_toward_for_ancient_dragon(pos, home, territory_radius * 2 + 2, home, territory_radius, uid)
	if next != pos:
		unit["grid_pos"] = next


func _patrol_ancient_dragon(unit: Dictionary, uid: int, home: Vector2i, territory_radius: int) -> void:
	var pos: Vector2i = unit.get("grid_pos", Vector2i.ZERO)
	var dirs: Array[Vector2i] = [Vector2i(0, -1), Vector2i(1, 0), Vector2i(0, 1), Vector2i(-1, 0)]
	var round_number: int = 0
	if _turn_manager != null:
		round_number = int(_turn_manager.round_number)
	var start_index: int = int(floor(_simple_hash(uid, round_number, 91) * float(dirs.size())))
	for i in range(dirs.size()):
		var dir: Vector2i = dirs[(start_index + i) % dirs.size()]
		var next: Vector2i = pos + dir
		if _is_ancient_dragon_move_allowed(next, home, territory_radius, uid):
			unit["grid_pos"] = next
			return


func _is_in_ancient_dragon_territory(pos: Vector2i, home: Vector2i, territory_radius: int) -> bool:
	return abs(pos.x - home.x) + abs(pos.y - home.y) <= territory_radius


func _find_nearest_player_unit_in_ancient_dragon_territory(from: Vector2i, radius: int, home: Vector2i, territory_radius: int) -> int:
	if not _unit_manager or not _unit_manager.has_method("get_all_units"):
		return -1
	var units: Array = _unit_manager.get_all_units()
	var nearest_dist := radius + 1
	var nearest_id := -1
	for unit_variant in units:
		var unit: Dictionary = unit_variant
		var upos: Vector2i = unit.get("grid_pos", Vector2i.ZERO)
		if not _is_in_ancient_dragon_territory(upos, home, territory_radius):
			continue
		var dist: int = abs(from.x - upos.x) + abs(from.y - upos.y)
		if dist <= radius and dist < nearest_dist:
			nearest_dist = dist
			nearest_id = int(unit.get("id", -1))
	return nearest_id


func _bfs_step_toward_for_ancient_dragon(from: Vector2i, to: Vector2i, max_steps: int, home: Vector2i, territory_radius: int, uid: int) -> Vector2i:
	if from == to:
		return from
	var dirs: Array[Vector2i] = [Vector2i(0, -1), Vector2i(0, 1), Vector2i(-1, 0), Vector2i(1, 0)]
	var visited := {}
	var queue: Array = [from]
	var parent := { from: from }
	var depth := { from: 0 }
	visited[from] = true
	while queue.size() > 0:
		var pos: Vector2i = queue.pop_front()
		var d: int = int(depth[pos])
		if pos == to:
			var step: Vector2i = pos
			while parent.get(step, step) != from:
				step = parent.get(step, step)
			return step
		if d >= max_steps:
			continue
		for dir_variant in dirs:
			var dir: Vector2i = dir_variant
			var next: Vector2i = pos + dir
			if visited.has(next):
				continue
			if next != to and not _is_ancient_dragon_move_allowed(next, home, territory_radius, uid):
				continue
			if next == to and not _is_in_ancient_dragon_territory(next, home, territory_radius):
				continue
			visited[next] = true
			parent[next] = pos
			depth[next] = d + 1
			queue.append(next)
	return from


func _is_ancient_dragon_move_allowed(pos: Vector2i, home: Vector2i, territory_radius: int, uid: int) -> bool:
	if not _in_bounds(pos.x, pos.y):
		return false
	if not _is_in_ancient_dragon_territory(pos, home, territory_radius):
		return false
	if not _is_dragon_lair_zone(pos):
		return false
	if _is_occupied_by_other_neutral(pos, uid):
		return false
	if _unit_manager and _unit_manager.has_method("get_unit_at"):
		var player_unit: Dictionary = _unit_manager.get_unit_at(pos)
		if not player_unit.is_empty():
			return false
	var bmgr = get_parent().get_node("BuildingManager2D")
	if bmgr and bmgr.has_method("is_tile_occupied"):
		if bmgr.is_tile_occupied(pos.x, pos.y):
			return false
	return true


func _is_occupied_by_other_neutral(pos: Vector2i, uid: int) -> bool:
	for unit_variant in _neutral_units:
		var unit: Dictionary = unit_variant
		if int(unit.get("id", -1)) == uid:
			continue
		if unit.get("grid_pos", Vector2i.ZERO) == pos:
			return true
	return false


func _is_valid_placement(pos: Vector2i) -> bool:
	if not _in_bounds(pos.x, pos.y):
		return false
	if not _is_passable(pos.x, pos.y):
		return false
	if not _is_empty(pos.x, pos.y):
		return false
	return true


func _is_passable(gx: int, gy: int) -> bool:
	if _grid_manager and _grid_manager.has_method("get_terrain_at"):
		if _grid_manager.has_method("is_dragon_lair_walkable") and bool(_grid_manager.call("is_dragon_lair_walkable", gx, gy)):
			return true
		var t: int = _grid_manager.get_terrain_at(gx, gy)
		return TerrainData.is_passable(t)
	return true


func _is_empty(gx: int, gy: int) -> bool:
	var pos := Vector2i(gx, gy)
	# 自己占用
	for u in _neutral_units:
		if u["grid_pos"] == pos:
			return false
	# 玩家单位占用
	if _unit_manager and _unit_manager.has_method("get_unit_at"):
		var pu: Dictionary = _unit_manager.get_unit_at(pos)
		if not pu.is_empty():
			return false
	# 建筑占用
	var bmgr = get_parent().get_node("BuildingManager2D")
	if bmgr and bmgr.has_method("is_tile_occupied"):
		if bmgr.is_tile_occupied(gx, gy):
			return false
	return true


func _is_near_spawn(pos: Vector2i, radius: int) -> bool:
	## 检查 pos 是否在任意阵营出生点附近
	var spawns: Array[Vector2i] = [
		Vector2i(35, 13),   # 精灵主城（渲染坐标）
		Vector2i(35, 43),   # 矮人主城
		Vector2i(62, 35),   # 兽人主城
	]
	for s in spawns:
		if abs(pos.x - s.x) <= radius and abs(pos.y - s.y) <= radius:
			return true
	return false


func _find_player_unit(unit_id: int) -> Dictionary:
	if not _unit_manager or not _unit_manager.has_method("get_unit_by_id"):
		return {}
	return _unit_manager.get_unit_by_id(unit_id)


func _find_nearest_player_unit(from: Vector2i, radius: int) -> int:
	## 在 radius 曼哈顿距离内找最近的玩家单位
	if not _unit_manager or not _unit_manager.has_method("get_all_units"):
		return -1
	var units: Array = _unit_manager.get_all_units()
	var nearest_dist := radius + 1
	var nearest_id := -1

	for u in units:
		var upos: Vector2i = u["grid_pos"]
		var dist: int = abs(from.x - upos.x) + abs(from.y - upos.y)
		if dist <= radius and dist < nearest_dist:
			nearest_dist = dist
			nearest_id = u["id"]

	return nearest_id


func _bfs_step_toward(from: Vector2i, to: Vector2i, max_steps: int) -> Vector2i:
	## BFS 向目标移动一步（限制搜索深度），返回新位置或原位置
	if from == to:
		return from

	var dirs := [Vector2i(0, -1), Vector2i(0, 1), Vector2i(-1, 0), Vector2i(1, 0)]
	var visited := {}
	var queue: Array = [from]
	var parent := { from: from }
	var depth := { from: 0 }
	visited[from] = true

	while queue.size() > 0:
		var pos: Vector2i = queue.pop_front()
		var d: int = depth[pos]

		if d >= max_steps:
			continue

		if pos == to:
			var step := pos
			while parent.get(step, step) != from:
				step = parent.get(step, step)
			return step

		for dir in dirs:
			var nx: int = pos.x + dir.x
			var ny: int = pos.y + dir.y
			var nkey := Vector2i(nx, ny)

			if not _in_bounds(nx, ny):
				continue
			if visited.has(nkey):
				continue
			if not _is_passable(nx, ny):
				continue

			visited[nkey] = true
			parent[nkey] = pos
			depth[nkey] = d + 1
			queue.append(nkey)

	return from


func _is_adjacent(a: Vector2i, b: Vector2i) -> bool:
	return abs(a.x - b.x) + abs(a.y - b.y) == 1


func _in_bounds(x: int, y: int) -> bool:
	return x >= 0 and x < GRID_COLS and y >= 0 and y < GRID_ROWS


func _grid_to_world(grid_x: int, grid_y: int) -> Vector2:
	var offset := Vector2(-GRID_CENTER.x * TILE_SIZE, -GRID_CENTER.y * TILE_SIZE)
	return Vector2(grid_x * TILE_SIZE + offset.x, grid_y * TILE_SIZE + offset.y)


func _world_to_grid(world_pos: Vector2) -> Vector2i:
	var offset := Vector2(-GRID_CENTER.x * TILE_SIZE, -GRID_CENTER.y * TILE_SIZE)
	var gx := int(roundf((world_pos.x - offset.x) / TILE_SIZE))
	var gy := int(roundf((world_pos.y - offset.y) / TILE_SIZE))
	return Vector2i(gx, gy)


func _simple_hash(x: int, y: int, seed: int) -> float:
	## 确定性伪随机，返回 0.0~1.0
	var h: int = (x * 374761393 + y * 668265263 + seed * 1274126177)
	h = (h ^ (h >> 13)) * 1274126177
	h = h ^ (h >> 16)
	return float(h & 0x7fffffff) / 2147483648.0
