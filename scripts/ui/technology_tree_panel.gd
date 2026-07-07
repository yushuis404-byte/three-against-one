class_name TechnologyTreePanel
extends Control

const PANEL_COLOR := Color(0.025, 0.03, 0.036, 0.90)
const GRID_COLOR := Color(1.0, 1.0, 1.0, 0.055)
const LINE_LOCKED := Color(0.22, 0.24, 0.27, 0.72)
const LINE_OPEN := Color(0.34, 0.58, 0.90, 0.84)
const LINE_DONE := Color(0.42, 0.90, 0.58, 0.90)
const NODE_RADIUS := 34.0
const ELF_FRAME_TEXTURE: Texture2D = preload("res://assets/ui/精灵科技框.png")
const DWARF_FRAME_TEXTURE: Texture2D = preload("res://assets/ui/矮人科技框.png")
const ORC_FRAME_TEXTURE: Texture2D = preload("res://assets/ui/兽人科技框.png")
const COMMON_FRAME_TEXTURE: Texture2D = preload("res://assets/ui/通用科技框.png")
const ROOT_FRAME_TEXTURE: Texture2D = preload("res://assets/ui/文明起点.png")
const DRAGON_FRAME_TEXTURE: Texture2D = preload("res://assets/ui/巨龙科技.png")
const CLOSE_RECT := Rect2(0, 0, 72, 26)
const DETAIL_W := 360.0
const HEADER_H := 36.0
const MIN_ZOOM := 0.45
const MAX_ZOOM := 1.75

var _service: TechnologyService = null
var _achievement_service: Node = null
var _turn_manager: Node = null
var _selected_id := ""
var _node_world_positions: Dictionary = {}
var _node_screen_rects: Dictionary = {}
var _pan := Vector2(760.0, 500.0)
var _zoom := 0.58
var _dragging := false
var _last_mouse := Vector2.ZERO
var _research_rect := Rect2()

var _family_colors: Dictionary = {
	"root": Color(0.96, 0.88, 0.44, 1.0),
	"common": Color(0.45, 0.66, 0.95, 1.0),
	"dragon": Color(0.36, 0.86, 0.64, 1.0),
	"lord": Color(0.72, 0.54, 1.0, 1.0),
	"hybrid": Color(1.0, 0.57, 0.35, 1.0),
}

var _effect_names: Dictionary = {
	"scout_vision_bonus": "\u65a5\u5019\u89c6\u91ce",
	"unit_vision_bonus": "\u5355\u4f4d\u89c6\u91ce",
	"resource_discovery_reward": "\u8d44\u6e90\u53d1\u73b0\u5956\u52b1",
	"outpost_vision_bonus": "\u524d\u54e8\u89c6\u91ce",
	"garrison_production_bonus": "\u5165\u9a7b\u4ea7\u51fa",
	"worker_garrison_bonus": "\u5de5\u4eba\u5165\u9a7b",
	"iron_production_bonus": "\u94c1\u77ff\u4ea7\u51fa",
	"building_hp_bonus": "\u5efa\u7b51\u8010\u4e45",
	"building_network_production_bonus": "\u5efa\u7b51\u7f51\u7edc\u4ea7\u51fa",
	"recruit_food_discount": "\u62db\u52df\u98df\u7269\u6298\u6263",
	"recruit_turn_discount": "\u62db\u52df\u56de\u5408\u6298\u6263",
	"first_recruit_ap_discount": "\u9996\u6b21\u62db\u52dfAP\u6298\u6263",
	"storage_flat_bonus": "\u4ed3\u50a8\u4e0a\u9650",
	"building_upgrade_ap_discount": "\u5efa\u7b51\u5347\u7ea7AP\u6298\u6263",
	"gold_ore_production_bonus": "\u91d1\u77ff\u77f3\u4ea7\u51fa",
	"mint_conversion_bonus": "\u94f8\u5e01\u6548\u7387",
	"elf_lord_building_radius": "\u7cbe\u7075\u9886\u4e3b\u5efa\u7b51\u8303\u56f4",
	"ancient_wood_production_bonus": "\u53e4\u6728\u4ea7\u51fa",
	"forest_scout_move_discount": "\u6797\u5730\u65a5\u5019\u884c\u52a8",
	"dwarf_lord_industry_bonus": "\u77ee\u4eba\u5de5\u4e1a",
	"damage_reduction_bonus": "\u51cf\u4f24",
	"orc_lord_military_bonus": "\u517d\u4eba\u519b\u4e8b",
	"kill_food_reward": "\u51fb\u6740\u98df\u7269\u5956\u52b1",
	"melee_attack_bonus": "\u8fd1\u6218\u653b\u51fb",
	"light_unit_attack_bonus": "\u8f7b\u88c5\u653b\u51fb",
	"scout_poison_weaken_turns": "\u65a5\u5019\u8150\u8680\u865a\u5f31",
	"lord_building_radius": "\u9886\u4e3b\u5efa\u7b51\u8303\u56f4",
	"hybrid_tech_discount": "\u878d\u5408\u79d1\u6280\u6298\u6263",
	"dragon_material_handling": "\u9f99\u65cf\u6750\u6599\u5904\u7406",
	"fire_wyvern_equipment": "\u706b\u7130\u4e9a\u9f99\u88c5\u5907",
	"frost_wyvern_equipment": "\u51b0\u971c\u4e9a\u9f99\u88c5\u5907",
	"toxic_wyvern_equipment": "\u6bd2\u6db2\u4e9a\u9f99\u88c5\u5907",
	"miasma_immunity": "瘴气免疫",
	"orc_dragon_war_path": "\u517d\u4eba\u9f99\u6218\u8def\u7ebf",
	"unlock_unit_orc_dragon_slayer": "\u89e3\u9501\u5c60\u9f99\u6218\u58eb",
	"unlock_unit_orc_dragonbone_shield": "\u89e3\u9501\u9f99\u9aa8\u5de8\u76fe\u5175",
	"unlock_unit_orc_dragon_blood_berserker": "\u89e3\u9501\u9f99\u8840\u72c2\u6218\u58eb",
	"unlock_orc_dragon_rider_path": "\u5f00\u542f\u5de8\u9f99\u9a91\u58eb\u8def\u7ebf",
}


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_STOP
	clip_contents = true
	_build_static_layout()


func setup(service: TechnologyService, achievement_service: Node, turn_manager: Node) -> void:
	_service = service
	_achievement_service = achievement_service
	_turn_manager = turn_manager
	if _service != null:
		if not _service.technology_state_changed.is_connected(_on_technology_state_changed):
			_service.technology_state_changed.connect(_on_technology_state_changed)
		if not _service.technology_researched.is_connected(_on_technology_researched):
			_service.technology_researched.connect(_on_technology_researched)
	if _achievement_service != null and _achievement_service.has_signal("tech_points_changed"):
		if not _achievement_service.tech_points_changed.is_connected(_on_tech_points_changed):
			_achievement_service.tech_points_changed.connect(_on_tech_points_changed)
	if _turn_manager != null and _turn_manager.has_signal("player_turn_started"):
		if not _turn_manager.player_turn_started.is_connected(_on_turn_started):
			_turn_manager.player_turn_started.connect(_on_turn_started)
	queue_redraw()


func _draw() -> void:
	_node_screen_rects.clear()
	_draw_panel()
	_draw_grid()
	if _service == null or _turn_manager == null:
		_draw_text(Vector2(18, 26), "\u79d1\u6280\u6811\u672a\u8fde\u63a5", 14, Color(0.92, 0.94, 0.96))
		return
	var player: int = int(_turn_manager.current_player)
	_draw_header(player)
	_draw_branch_guides()
	_draw_connections(player)
	_draw_nodes(player)
	_draw_detail(player)


func _gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton:
		var mb: InputEventMouseButton = event
		if mb.button_index == MOUSE_BUTTON_WHEEL_UP and mb.pressed:
			_zoom_at(mb.position, 1.08)
			accept_event()
			return
		if mb.button_index == MOUSE_BUTTON_WHEEL_DOWN and mb.pressed:
			_zoom_at(mb.position, 0.92)
			accept_event()
			return
		if mb.button_index == MOUSE_BUTTON_LEFT:
			if mb.pressed:
				if _handle_click(mb.position):
					accept_event()
					return
				_dragging = true
				_last_mouse = mb.position
				accept_event()
			else:
				_dragging = false
				accept_event()
			return
		if mb.button_index == MOUSE_BUTTON_RIGHT and mb.pressed:
			_selected_id = ""
			queue_redraw()
			accept_event()
			return
		accept_event()
		return
	if event is InputEventMouseMotion and _dragging:
		var mm: InputEventMouseMotion = event
		_pan += mm.position - _last_mouse
		_last_mouse = mm.position
		queue_redraw()
		accept_event()
		return
	if event is InputEventMouseMotion:
		accept_event()


func _handle_click(pos: Vector2) -> bool:
	var close_rect := Rect2(size.x - 86.0, 5.0, CLOSE_RECT.size.x, CLOSE_RECT.size.y)
	if close_rect.has_point(pos):
		visible = false
		return true
	if _research_rect.has_point(pos):
		_try_research_selected()
		return true
	for id in _node_screen_rects.keys():
		var rect: Rect2 = _node_screen_rects[id]
		if rect.has_point(pos):
			_selected_id = str(id)
			queue_redraw()
			return true
	return false


func _try_research_selected() -> void:
	if _selected_id.is_empty() or _service == null or _turn_manager == null:
		return
	var player: int = int(_turn_manager.current_player)
	if _service.research(player, _selected_id):
		queue_redraw()


func _zoom_at(screen_pos: Vector2, factor: float) -> void:
	var old_zoom := _zoom
	var world_before: Vector2 = _screen_to_world(screen_pos)
	_zoom = clampf(_zoom * factor, MIN_ZOOM, MAX_ZOOM)
	if is_equal_approx(old_zoom, _zoom):
		return
	_pan = screen_pos - world_before * _zoom
	queue_redraw()


func _draw_panel() -> void:
	draw_rect(Rect2(Vector2.ZERO, size), PANEL_COLOR, true)
	draw_rect(Rect2(Vector2.ZERO, size), Color(0.36, 0.50, 0.72, 0.45), false, 1.0)
	draw_rect(Rect2(size.x - 86.0, 5.0, CLOSE_RECT.size.x, CLOSE_RECT.size.y), Color(0.18, 0.08, 0.08, 0.85), true)
	draw_rect(Rect2(size.x - 86.0, 5.0, CLOSE_RECT.size.x, CLOSE_RECT.size.y), Color(1.0, 0.55, 0.48, 0.72), false, 1.0)
	_draw_text(Vector2(size.x - 73.0, 23.0), "\u5173\u95ed", 13, Color(1.0, 0.84, 0.80))


func _draw_header(player: int) -> void:
	var tp := 0
	if _achievement_service != null and _achievement_service.has_method("get_tech_points"):
		tp = int(_achievement_service.call("get_tech_points", player))
	var researched: int = _service.get_researched_ids(player).size()
	var total: int = _service.get_definitions().size()
	var title := "\u79d1\u6280\u6811 | %s | \u79d1\u6280\u70b9 %d | %d / %d" % [
		GameCatalog.faction_name(player),
		tp,
		researched,
		total,
	]
	_draw_text(Vector2(14, 24), title, 15, Color(0.94, 0.97, 1.0))
	_draw_text(Vector2(14, 48), "\u5de6\u952e\u62d6\u62fd\u753b\u5e03  \u6eda\u8f6e\u7f29\u653e  \u70b9\u51fb\u5706\u5f62\u8282\u70b9\u67e5\u770b\u5e76\u7814\u7a76", 11, Color(0.66, 0.74, 0.84))


func _draw_grid() -> void:
	var step := 96.0 * _zoom
	if step < 36.0:
		step = 36.0
	var start_x := fposmod(_pan.x, step)
	var start_y := fposmod(_pan.y, step)
	var x := start_x
	while x < size.x - DETAIL_W:
		draw_line(Vector2(x, HEADER_H), Vector2(x, size.y), GRID_COLOR, 1.0)
		x += step
	var y := start_y
	while y < size.y:
		draw_line(Vector2(0, y), Vector2(size.x - DETAIL_W, y), GRID_COLOR, 1.0)
		y += step


func _draw_branch_guides() -> void:
	var center := _world_to_screen(Vector2.ZERO)
	var radii: Array[float] = [170.0, 320.0, 470.0, 620.0, 770.0]
	for radius in radii:
		draw_arc(center, radius * _zoom, deg_to_rad(-168.0), deg_to_rad(168.0), 96, Color(1.0, 1.0, 1.0, 0.055), 1.0, true)
	var sector_lines: Array[float] = [-165.0, -95.0, -20.0, 52.0, 122.0, 168.0]
	for angle in sector_lines:
		var end := _world_to_screen(_polar_to_world(angle, 830.0))
		draw_line(center, end, Color(1.0, 1.0, 1.0, 0.045), 1.0, true)
	_draw_centered_text(_world_to_screen(_polar_to_world(-132.0, 880.0)), "\u7cbe\u7075", 14, Color(0.56, 0.94, 0.62, 0.55))
	_draw_centered_text(_world_to_screen(_polar_to_world(-56.0, 880.0)), "\u5de8\u9f99", 14, Color(0.42, 0.96, 0.76, 0.55))
	_draw_centered_text(_world_to_screen(_polar_to_world(27.0, 880.0)), "\u517d\u4eba", 14, Color(1.0, 0.45, 0.36, 0.55))
	_draw_centered_text(_world_to_screen(_polar_to_world(140.0, 880.0)), "\u77ee\u4eba", 14, Color(0.94, 0.76, 0.38, 0.55))


func _draw_connections(player: int) -> void:
	for definition in _service.get_definitions():
		var id: String = str(definition["id"])
		if not _node_world_positions.has(id):
			continue
		var to_pos: Vector2 = _world_to_screen(_node_world_positions[id])
		for parent_variant in definition.get("parent_techs", []):
			var parent_id: String = str(parent_variant)
			if not _node_world_positions.has(parent_id):
				continue
			var from_pos: Vector2 = _world_to_screen(_node_world_positions[parent_id])
			var color := LINE_LOCKED
			if _service.is_researched(player, id):
				color = LINE_DONE
			elif _service.is_researched(player, parent_id):
				color = LINE_OPEN
			_draw_elbow_line(from_pos, to_pos, color, 2.2)
		for any_variant in definition.get("required_any_techs", []):
			var any_id: String = str(any_variant)
			if not _node_world_positions.has(any_id):
				continue
			var any_from: Vector2 = _world_to_screen(_node_world_positions[any_id])
			var any_color := LINE_LOCKED
			if _service.is_researched(player, id):
				any_color = LINE_DONE
			elif _service.is_researched(player, any_id):
				any_color = LINE_OPEN
			_draw_elbow_line(any_from, to_pos, Color(any_color.r, any_color.g, any_color.b, 0.55), 1.4, true)


func _draw_nodes(player: int) -> void:
	for definition in _service.get_definitions():
		var id: String = str(definition["id"])
		if not _node_world_positions.has(id):
			continue
		var center: Vector2 = _world_to_screen(_node_world_positions[id])
		var radius := NODE_RADIUS * _zoom
		var rect := Rect2(center - Vector2(radius, radius), Vector2(radius * 2.0, radius * 2.0))
		_node_screen_rects[id] = rect
		if center.x > size.x - DETAIL_W + radius or center.x < -radius or center.y < -radius or center.y > size.y + radius:
			continue
		_draw_node(player, definition, center, radius)


func _draw_node(player: int, definition: Dictionary, center: Vector2, radius: float) -> void:
	var id: String = str(definition["id"])
	if id == "tech.root.civilization":
		draw_texture_rect(ROOT_FRAME_TEXTURE, Rect2(center - Vector2(radius, radius), Vector2(radius * 2.0, radius * 2.0)), false)
		return
	var family: String = str(definition.get("family", "common"))
	var family_color: Color = _family_colors.get(family, Color(0.7, 0.7, 0.8))
	var researched: bool = _service.is_researched(player, id)
	var available: bool = _service.is_available(player, id)
	var fill := Color(0.10, 0.11, 0.13, 0.98)
	var ring := Color(1.0, 1.0, 1.0, 0.22)
	if researched:
		fill = family_color.darkened(0.25)
		ring = Color(0.62, 1.0, 0.58, 0.95)
	elif available:
		fill = family_color.darkened(0.48)
		ring = family_color.lightened(0.20)
	if id == _selected_id:
		ring = Color(1.0, 0.90, 0.42, 1.0)
	draw_circle(center, radius, fill)
	var frame_size := radius * 2.0
	var frame_rect := Rect2(center - Vector2(radius, radius), Vector2(frame_size, frame_size))
	if id.begins_with("tech.lord.elf"):
		draw_texture_rect(ELF_FRAME_TEXTURE, frame_rect, false)
	elif id.begins_with("tech.lord.dwarf"):
		draw_texture_rect(DWARF_FRAME_TEXTURE, frame_rect, false)
	elif id.begins_with("tech.lord.orc"):
		draw_texture_rect(ORC_FRAME_TEXTURE, frame_rect, false)
	elif id.begins_with("tech.common"):
		draw_texture_rect(COMMON_FRAME_TEXTURE, frame_rect, false)
	elif id.begins_with("tech.dragon"):
		draw_texture_rect(DRAGON_FRAME_TEXTURE, frame_rect, false)
	else:
		draw_arc(center, radius, 0.0, TAU, 64, ring, 3.0 if id == _selected_id else 2.0)
	draw_circle(center, maxi(4.0, radius * 0.16), family_color)
	var title: String = str(definition.get("title", id))
	if title.length() > 6:
		title = title.substr(0, 6)
	_draw_centered_text(center + Vector2(0, radius + 17.0), title, 12, Color(0.92, 0.96, 1.0) if available or researched else Color(0.55, 0.58, 0.62))
	var cost := str(_service.get_effective_cost(player, id))
	if int(definition.get("cost", 0)) > 0:
		_draw_centered_text(center + Vector2(0, 5.0), cost, 13, Color(0.95, 0.96, 1.0))


func _draw_detail(player: int) -> void:
	var x := size.x - DETAIL_W
	draw_rect(Rect2(x, HEADER_H, DETAIL_W, size.y - HEADER_H), Color(0.04, 0.05, 0.06, 0.92), true)
	draw_line(Vector2(x, HEADER_H), Vector2(x, size.y), Color(1, 1, 1, 0.12), 1.0)
	if _selected_id.is_empty():
		_draw_text(Vector2(x + 18.0, HEADER_H + 32.0), "\u9009\u62e9\u4e00\u4e2a\u79d1\u6280\u8282\u70b9", 15, Color(0.94, 0.97, 1.0))
		_draw_text(Vector2(x + 18.0, HEADER_H + 58.0), "\u5706\u5f62\u4ee3\u8868\u79d1\u6280\uff0c\u6298\u7ebf\u4ee3\u8868\u524d\u7f6e\u5173\u7cfb\u3002", 12, Color(0.68, 0.74, 0.84))
		return
	var definition: Dictionary = _service.get_definition(_selected_id)
	if definition.is_empty():
		return
	var title: String = str(definition.get("title", _selected_id))
	var info: Dictionary = _service.get_research_info(player, _selected_id)
	var researched: bool = _service.is_researched(player, _selected_id)
	var available: bool = bool(info.get("available", false))
	_draw_text(Vector2(x + 18.0, HEADER_H + 32.0), title, 17, Color(0.98, 0.98, 1.0))
	_draw_text(Vector2(x + 18.0, HEADER_H + 58.0), _status_text(researched, available, info), 12, Color(0.74, 0.86, 1.0))
	_draw_text(Vector2(x + 18.0, HEADER_H + 88.0), "\u6d88\u8017\uff1a%d \u79d1\u6280\u70b9" % _service.get_effective_cost(player, _selected_id), 12, Color(0.86, 0.90, 0.96))
	_draw_text(Vector2(x + 18.0, HEADER_H + 116.0), "材料：" + _resource_cost_text(definition), 11, Color(0.74, 0.84, 0.78))
	_draw_text(Vector2(x + 18.0, HEADER_H + 143.0), "\u524d\u7f6e\uff1a" + _join_tech_titles(definition.get("parent_techs", [])), 11, Color(0.68, 0.74, 0.84))
	_draw_text(Vector2(x + 18.0, HEADER_H + 170.0), "\u4efb\u610f\u524d\u7f6e\uff1a" + _join_tech_titles(definition.get("required_any_techs", [])), 11, Color(0.68, 0.74, 0.84))
	_draw_text(Vector2(x + 18.0, HEADER_H + 197.0), "\u6210\u5c31\uff1a" + _join_achievement_titles(definition.get("required_achievements", [])), 11, Color(0.68, 0.74, 0.84))
	_draw_text(Vector2(x + 18.0, HEADER_H + 224.0), "\u9886\u4e3b\uff1a" + _join_lord_titles(definition.get("required_lords", [])), 11, Color(0.68, 0.74, 0.84))
	_draw_text(Vector2(x + 18.0, HEADER_H + 256.0), "\u6548\u679c", 13, Color(0.94, 0.97, 1.0))
	_draw_wrapped_lines(Vector2(x + 18.0, HEADER_H + 280.0), _effect_text(definition.get("effects", {})), 12, Color(0.78, 0.86, 0.94), 310.0)
	_research_rect = Rect2(x + 18.0, HEADER_H + 372.0, 150.0, 36.0)
	var button_color := Color(0.20, 0.36, 0.58, 0.96) if available else Color(0.12, 0.13, 0.15, 0.96)
	if researched:
		button_color = Color(0.16, 0.32, 0.18, 0.96)
	draw_rect(_research_rect, button_color, true)
	draw_rect(_research_rect, Color(0.58, 0.76, 1.0, 0.55), false, 1.0)
	var label := "\u7814\u7a76" if available else ("\u5df2\u7814\u7a76" if researched else "\u672a\u89e3\u9501")
	_draw_centered_text(_research_rect.get_center() + Vector2(0, 5), label, 13, Color(0.94, 0.97, 1.0))


func _status_text(researched: bool, available: bool, info: Dictionary) -> String:
	if researched:
		return "\u72b6\u6001\uff1a\u5df2\u7814\u7a76"
	if available:
		return "\u72b6\u6001\uff1a\u53ef\u7814\u7a76"
	var reason: String = str(info.get("reason", ""))
	match reason:
		"missing_parent":
			return "\u72b6\u6001\uff1a\u9700\u8981\u524d\u7f6e\u79d1\u6280"
		"missing_any_tech":
			return "\u72b6\u6001\uff1a\u9700\u8981\u4efb\u610f\u4e00\u4e2a\u6307\u5b9a\u79d1\u6280"
		"missing_achievement":
			return "\u72b6\u6001\uff1a\u9700\u8981\u5bf9\u5e94\u6210\u5c31"
		"missing_lord":
			return "\u72b6\u6001\uff1a\u9700\u8981\u62e5\u6709\u5bf9\u5e94\u9886\u4e3b"
		"not_enough_tech_points":
			return "\u72b6\u6001\uff1a\u79d1\u6280\u70b9\u4e0d\u8db3 %d/%d" % [int(info.get("current", 0)), int(info.get("cost", 0))]
		"not_enough_resource_cost_any":
			return "状态：需要任意一种亚龙龙血"
		"not_enough_resource_cost":
			return "状态：材料不足"
		"resource_tracker_missing":
			return "状态：资源系统未连接"
		"already_researched":
			return "\u72b6\u6001\uff1a\u5df2\u7814\u7a76"
	return "\u72b6\u6001\uff1a\u672a\u89e3\u9501"


func _build_static_layout() -> void:
	_node_world_positions = {
		"tech.root.civilization": Vector2(0, 0),
		"tech.common.map_drawing": _polar_to_world(-132.0, 170.0),
		"tech.common.terrain_record": _polar_to_world(-146.0, 320.0),
		"tech.common.resource_marking": _polar_to_world(-62.0, 170.0),
		"tech.common.border_survey": _polar_to_world(-132.0, 470.0),
		"tech.common.basic_forging": _polar_to_world(140.0, 170.0),
		"tech.common.tool_forging": _polar_to_world(154.0, 320.0),
		"tech.common.iron_mining": _polar_to_world(126.0, 320.0),
		"tech.common.metal_parts": _polar_to_world(140.0, 470.0),
		"tech.common.grain_ration": _polar_to_world(52.0, 170.0),
		"tech.common.recruitment_rules": _polar_to_world(52.0, 320.0),
		"tech.common.war_drum_mobilization": _polar_to_world(52.0, 470.0),
		"tech.common.storage_system": _polar_to_world(168.0, 270.0),
		"tech.common.building_upgrade": _polar_to_world(168.0, 470.0),
		"tech.common.gold_mining": _polar_to_world(-40.0, 320.0),
		"tech.common.coin_machinery": _polar_to_world(-24.0, 470.0),
		"tech.dragon.nest_survey": _polar_to_world(-62.0, 320.0),
		"tech.dragon.wyvern_fire_research": _polar_to_world(-82.0, 470.0),
		"tech.dragon.wyvern_frost_research": _polar_to_world(-62.0, 470.0),
		"tech.dragon.wyvern_toxic_research": _polar_to_world(-42.0, 470.0),
		"tech.dragon.miasma_shield": _polar_to_world(-62.0, 545.0),
		"tech.dragon.fire_blade": _polar_to_world(-82.0, 620.0),
		"tech.dragon.frost_scale": _polar_to_world(-62.0, 620.0),
		"tech.dragon.corrosive_weapons": _polar_to_world(-42.0, 620.0),
		"tech.lord.elf.wind_sight": _polar_to_world(-132.0, 620.0),
		"tech.lord.elf.forest_sense": _polar_to_world(-150.0, 770.0),
		"tech.lord.elf.hidden_march": _polar_to_world(-114.0, 770.0),
		"tech.lord.dwarf.deep_forge": _polar_to_world(140.0, 620.0),
		"tech.lord.dwarf.vein_echo": _polar_to_world(122.0, 770.0),
		"tech.lord.dwarf.stone_oath": _polar_to_world(158.0, 770.0),
		"tech.lord.orc.blood_drum": _polar_to_world(52.0, 620.0),
		"tech.lord.orc.raid_ration": _polar_to_world(34.0, 770.0),
		"tech.lord.orc.berserker_training": _polar_to_world(70.0, 770.0),
		"tech.lord.orc.dragon_war_lore": _polar_to_world(-4.0, 620.0),
		"tech.lord.orc.dragon_slayer": _polar_to_world(-16.0, 770.0),
		"tech.lord.orc.dragonbone_shield": _polar_to_world(0.0, 770.0),
		"tech.lord.orc.dragon_blood_berserker": _polar_to_world(16.0, 860.0),
		"tech.lord.orc.dragon_rider_path": _polar_to_world(-4.0, 860.0),
		"tech.hybrid.ancient_iron_branch": _polar_to_world(-178.0, 620.0),
		"tech.hybrid.forge_war_drum": _polar_to_world(96.0, 620.0),
		"tech.hybrid.forest_raid": _polar_to_world(88.0, 770.0),
		"tech.hybrid.tri_lord_pact": _polar_to_world(112.0, 860.0),
	}


func _draw_elbow_line(from_pos: Vector2, to_pos: Vector2, color: Color, width: float, dashed: bool = false) -> void:
	var from_world := _screen_to_world(from_pos)
	var to_world := _screen_to_world(to_pos)
	var from_radius := from_world.length()
	var to_radius := to_world.length()
	if from_radius < 8.0 or to_radius < 8.0:
		if dashed:
			draw_dashed_line(from_pos, to_pos, color, width, 6.0, 4.0, true)
		else:
			draw_line(from_pos, to_pos, color, width, true)
		return
	var from_angle := rad_to_deg(atan2(from_world.y, from_world.x))
	var to_angle := rad_to_deg(atan2(to_world.y, to_world.x))
	var points := PackedVector2Array()
	var radial_joint_world := _polar_to_world(from_angle, to_radius)
	if absf(to_radius - from_radius) > 24.0:
		points.append(from_pos)
		points.append(_world_to_screen(radial_joint_world))
		_append_arc_points(points, to_radius, from_angle, to_angle)
		points.append(to_pos)
	else:
		_append_arc_points(points, from_radius, from_angle, to_angle)
	if dashed:
		_draw_dashed_polyline(points, color, width)
	else:
		draw_polyline(points, color, width, true)


func _append_arc_points(points: PackedVector2Array, radius: float, from_angle: float, to_angle: float) -> void:
	var diff := _shortest_angle_delta(from_angle, to_angle)
	var steps := maxi(5, int(absf(diff) / 8.0))
	for i in range(steps + 1):
		var t := float(i) / float(steps)
		var angle := from_angle + diff * t
		points.append(_world_to_screen(_polar_to_world(angle, radius)))


func _draw_dashed_polyline(points: PackedVector2Array, color: Color, width: float) -> void:
	for i in range(points.size() - 1):
		draw_dashed_line(points[i], points[i + 1], color, width, 6.0, 4.0, true)


func _shortest_angle_delta(from_angle: float, to_angle: float) -> float:
	var delta := fposmod(to_angle - from_angle + 180.0, 360.0) - 180.0
	return delta


func _polar_to_world(angle_degrees: float, radius: float) -> Vector2:
	var angle := deg_to_rad(angle_degrees)
	return Vector2(cos(angle), sin(angle)) * radius


func _world_to_screen(world: Vector2) -> Vector2:
	return world * _zoom + _pan


func _screen_to_world(screen: Vector2) -> Vector2:
	return (screen - _pan) / _zoom


func _join_tech_titles(ids: Array) -> String:
	if ids.is_empty():
		return "\u65e0"
	var parts := PackedStringArray()
	for id_variant in ids:
		var d: Dictionary = _service.get_definition(str(id_variant)) if _service != null else {}
		parts.append(str(d.get("title", str(id_variant))))
	return ", ".join(parts)


func _join_achievement_titles(ids: Array) -> String:
	if ids.is_empty():
		return "\u65e0"
	var parts := PackedStringArray()
	for id_variant in ids:
		var title := str(id_variant)
		if _achievement_service != null and _achievement_service.has_method("get_definition"):
			var d: Dictionary = _achievement_service.call("get_definition", str(id_variant))
			title = str(d.get("title", title))
		parts.append(title)
	return ", ".join(parts)


func _join_lord_titles(ids: Array) -> String:
	if ids.is_empty():
		return "\u65e0"
	var parts := PackedStringArray()
	for id_variant in ids:
		parts.append(_lord_title(str(id_variant)))
	return ", ".join(parts)


func _lord_title(id: String) -> String:
	match id:
		"lord.elf.wind_seer":
			return "\u98ce\u8bed\u8005"
		"lord.dwarf.stone_warden":
			return "\u77f3\u5b88\u536b"
		"lord.orc.blood_chief":
			return "\u8840\u65a7\u914b\u957f"
	return id


func _resource_cost_text(definition: Dictionary) -> String:
	var any_costs: Array = definition.get("resource_cost_any", [])
	if not any_costs.is_empty():
		var parts := PackedStringArray()
		for cost_variant in any_costs:
			var cost: Dictionary = cost_variant
			parts.append(_single_resource_cost_text(cost))
		return "任意一种：" + " / ".join(parts)
	var cost_dict: Dictionary = definition.get("resource_cost", {})
	if cost_dict.is_empty():
		return "无"
	return _single_resource_cost_text(cost_dict)


func _single_resource_cost_text(cost: Dictionary) -> String:
	var parts := PackedStringArray()
	for key in cost:
		var resource_key: String = str(key)
		parts.append("%s ×%d" % [GameCatalog.resource_name(resource_key), int(cost[key])])
	return ", ".join(parts)


func _effect_text(effects: Dictionary) -> Array[String]:
	var lines: Array[String] = []
	if effects.is_empty():
		lines.append("\u65e0\u76f4\u63a5\u6548\u679c")
		return lines
	for key in effects:
		var name: String = str(_effect_names.get(str(key), str(key)))
		var value := int(effects[key])
		var prefix := "+" if value >= 0 else ""
		lines.append("%s %s%d" % [name, prefix, value])
	return lines


func _draw_wrapped_lines(pos: Vector2, lines: Array[String], font_size: int, color: Color, _width: float) -> void:
	var y := pos.y
	for line in lines:
		_draw_text(Vector2(pos.x, y), line, font_size, color)
		y += 22.0


func _on_technology_state_changed(_player: int) -> void:
	queue_redraw()


func _on_technology_researched(_player: int, technology_id: String, _title: String) -> void:
	_selected_id = technology_id
	queue_redraw()


func _on_tech_points_changed(_player: int, _amount: int) -> void:
	queue_redraw()


func _on_turn_started(_player: int) -> void:
	queue_redraw()


func _draw_text(pos: Vector2, text: String, font_size: int, color: Color) -> void:
	var font: Font = ThemeDB.fallback_font
	draw_string(font, pos, text, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size, color)


func _draw_centered_text(pos: Vector2, text: String, font_size: int, color: Color) -> void:
	var font: Font = ThemeDB.fallback_font
	var width: float = font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size).x
	draw_string(font, pos - Vector2(width * 0.5, 0.0), text, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size, color)
