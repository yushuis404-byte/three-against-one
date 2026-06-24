class_name TechnologyTreePanel
extends Control

const PANEL_COLOR := Color(0.025, 0.03, 0.036, 0.90)
const GRID_COLOR := Color(1.0, 1.0, 1.0, 0.055)
const LINE_LOCKED := Color(0.22, 0.24, 0.27, 0.72)
const LINE_OPEN := Color(0.34, 0.58, 0.90, 0.84)
const LINE_DONE := Color(0.42, 0.90, 0.58, 0.90)
const NODE_RADIUS := 34.0
const CLOSE_RECT := Rect2(0, 0, 72, 26)
const DETAIL_W := 360.0
const HEADER_H := 36.0
const MIN_ZOOM := 0.55
const MAX_ZOOM := 1.75

var _service: TechnologyService = null
var _achievement_service: Node = null
var _turn_manager: Node = null
var _selected_id := ""
var _node_world_positions: Dictionary = {}
var _node_screen_rects: Dictionary = {}
var _pan := Vector2(480.0, 230.0)
var _zoom := 0.92
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
}


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_STOP
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
	if event is InputEventMouseMotion and _dragging:
		var mm: InputEventMouseMotion = event
		_pan += mm.position - _last_mouse
		_last_mouse = mm.position
		queue_redraw()
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
			_draw_curve(from_pos, to_pos, color, 2.2)


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
		_draw_text(Vector2(x + 18.0, HEADER_H + 58.0), "\u5706\u5f62\u4ee3\u8868\u79d1\u6280\uff0c\u66f2\u7ebf\u4ee3\u8868\u524d\u7f6e\u5173\u7cfb\u3002", 12, Color(0.68, 0.74, 0.84))
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
	_draw_text(Vector2(x + 18.0, HEADER_H + 116.0), "\u524d\u7f6e\uff1a" + _join_tech_titles(definition.get("parent_techs", [])), 11, Color(0.68, 0.74, 0.84))
	_draw_text(Vector2(x + 18.0, HEADER_H + 143.0), "\u6210\u5c31\uff1a" + _join_achievement_titles(definition.get("required_achievements", [])), 11, Color(0.68, 0.74, 0.84))
	_draw_text(Vector2(x + 18.0, HEADER_H + 170.0), "\u9886\u4e3b\uff1a" + _join_lord_titles(definition.get("required_lords", [])), 11, Color(0.68, 0.74, 0.84))
	_draw_text(Vector2(x + 18.0, HEADER_H + 208.0), "\u6548\u679c", 13, Color(0.94, 0.97, 1.0))
	_draw_wrapped_lines(Vector2(x + 18.0, HEADER_H + 232.0), _effect_text(definition.get("effects", {})), 12, Color(0.78, 0.86, 0.94), 310.0)
	_research_rect = Rect2(x + 18.0, size.y - 58.0, 126.0, 34.0)
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
		"missing_achievement":
			return "\u72b6\u6001\uff1a\u9700\u8981\u5bf9\u5e94\u6210\u5c31"
		"missing_lord":
			return "\u72b6\u6001\uff1a\u9700\u8981\u62e5\u6709\u5bf9\u5e94\u9886\u4e3b"
		"not_enough_tech_points":
			return "\u72b6\u6001\uff1a\u79d1\u6280\u70b9\u4e0d\u8db3 %d/%d" % [int(info.get("current", 0)), int(info.get("cost", 0))]
		"already_researched":
			return "\u72b6\u6001\uff1a\u5df2\u7814\u7a76"
	return "\u72b6\u6001\uff1a\u672a\u89e3\u9501"


func _build_static_layout() -> void:
	_node_world_positions = {
		"tech.root.civilization": Vector2(0, 0),
		"tech.common.map_drawing": Vector2(210, -210),
		"tech.common.terrain_record": Vector2(430, -310),
		"tech.common.resource_marking": Vector2(430, -120),
		"tech.common.border_survey": Vector2(680, -310),
		"tech.common.basic_forging": Vector2(210, 0),
		"tech.common.tool_forging": Vector2(430, 30),
		"tech.common.iron_mining": Vector2(430, 180),
		"tech.common.metal_parts": Vector2(680, 120),
		"tech.common.grain_ration": Vector2(210, 220),
		"tech.common.recruitment_rules": Vector2(430, 320),
		"tech.common.war_drum_mobilization": Vector2(680, 370),
		"tech.common.storage_system": Vector2(210, 420),
		"tech.common.building_upgrade": Vector2(680, 520),
		"tech.common.gold_mining": Vector2(700, -60),
		"tech.common.coin_machinery": Vector2(940, 40),
		"tech.dragon.toxic_blood": Vector2(940, -110),
		"tech.dragon.corrosive_weapons": Vector2(1190, -80),
		"tech.lord.elf.wind_sight": Vector2(940, -330),
		"tech.lord.elf.forest_sense": Vector2(1190, -410),
		"tech.lord.elf.hidden_march": Vector2(1190, -250),
		"tech.lord.dwarf.deep_forge": Vector2(940, 180),
		"tech.lord.dwarf.vein_echo": Vector2(1190, 110),
		"tech.lord.dwarf.stone_oath": Vector2(1190, 270),
		"tech.lord.orc.blood_drum": Vector2(940, 410),
		"tech.lord.orc.raid_ration": Vector2(1190, 390),
		"tech.lord.orc.berserker_training": Vector2(1190, 540),
		"tech.hybrid.ancient_iron_branch": Vector2(1460, -160),
		"tech.hybrid.forge_war_drum": Vector2(1460, 230),
		"tech.hybrid.forest_raid": Vector2(1460, 460),
		"tech.hybrid.tri_lord_pact": Vector2(1740, 130),
	}


func _draw_curve(from_pos: Vector2, to_pos: Vector2, color: Color, width: float) -> void:
	var points := PackedVector2Array()
	var delta_x: float = absf(to_pos.x - from_pos.x)
	var c1 := from_pos + Vector2(maxf(80.0, delta_x * 0.42), 0.0)
	var c2 := to_pos - Vector2(maxf(80.0, delta_x * 0.42), 0.0)
	for i in range(25):
		var t: float = float(i) / 24.0
		points.append(_cubic_bezier(from_pos, c1, c2, to_pos, t))
	draw_polyline(points, color, width, true)


func _cubic_bezier(a: Vector2, b: Vector2, c: Vector2, d: Vector2, t: float) -> Vector2:
	var u := 1.0 - t
	return a * u * u * u + b * 3.0 * u * u * t + c * 3.0 * u * t * t + d * t * t * t


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
