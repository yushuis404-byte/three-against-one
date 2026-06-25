class_name CivilizationRoutePanel
extends Control

const PANEL_COLOR := Color(0.03, 0.035, 0.042, 0.94)
const BORDER_COLOR := Color(0.50, 0.62, 0.86, 0.56)
const HEADER_COLOR := Color(0.13, 0.18, 0.26, 0.90)
const CARD_COLOR := Color(0.07, 0.085, 0.105, 0.92)
const CARD_SELECTED := Color(0.18, 0.24, 0.34, 0.96)
const CARD_DISABLED := Color(0.055, 0.060, 0.070, 0.82)
const TEXT_MAIN := Color(0.94, 0.97, 1.0)
const TEXT_MUTED := Color(0.66, 0.72, 0.80)
const CLOSE_RECT := Rect2(0, 0, 72, 26)

var _rules: CivilizationRuleService = null
var _turn_manager: Node = null
var _selected_player: int = 0
var _selected_lord_id: String = ""
var _message: String = ""

var _player_rects: Dictionary = {}
var _owned_rects: Dictionary = {}
var _candidate_rects: Dictionary = {}
var _add_rect: Rect2 = Rect2()
var _remove_rect: Rect2 = Rect2()

var _axis_names: Dictionary = {
	"information": "\u60c5\u62a5",
	"space": "\u7a7a\u95f4",
	"war": "\u6218\u4e89",
}

var _modifier_names: Dictionary = {
	"unit_vision_bonus": "\u5355\u4f4d\u89c6\u91ce",
	"scout_move_bonus": "\u65a5\u5019\u79fb\u52a8",
	"building_hp_bonus": "\u5efa\u7b51\u8010\u4e45",
	"building_network_production_bonus": "\u5efa\u7b51\u7f51\u7edc\u4ea7\u51fa",
	"repair_efficiency_bonus": "\u4fee\u7406\u6548\u7387",
	"kill_gold_reward": "\u51fb\u6740\u91d1\u5e01",
	"melee_atk_bonus": "\u8fd1\u6218\u653b\u51fb",
}

var _unlock_names: Dictionary = {
	"building.wind_ancient_tree": "\u98ce\u8bed\u53e4\u6811",
	"building.stone_wall": "\u77f3\u5899",
	"building.watch_tower": "\u77ad\u671b\u5854",
	"building.forge": "\u7194\u7089",
	"building.blood_fang_den": "\u8840\u7259\u5de2\u7a74",
	"recipe.mithril.basic": "\u79d8\u94f6\u57fa\u7840\u5de5\u827a",
	"action.fog.reveal": "\u63ed\u793a\u8ff7\u96fe",
	"action.fog.conceal": "\u906e\u853d\u8ff7\u96fe",
	"action.warband.form": "\u7ec4\u5efa\u6218\u5e2e",
}


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_STOP


func setup(rules: Node, turn_manager: Node) -> void:
	_rules = rules as CivilizationRuleService
	_turn_manager = turn_manager
	if _turn_manager != null:
		_selected_player = int(_turn_manager.get("current_player"))
		if _turn_manager.has_signal("player_turn_started"):
			if not _turn_manager.player_turn_started.is_connected(_on_player_turn_started):
				_turn_manager.player_turn_started.connect(_on_player_turn_started)
	if _rules != null:
		if not _rules.route_changed.is_connected(_on_route_changed):
			_rules.route_changed.connect(_on_route_changed)
	queue_redraw()


func _draw() -> void:
	_player_rects.clear()
	_owned_rects.clear()
	_candidate_rects.clear()
	_add_rect = Rect2()
	_remove_rect = Rect2()
	_draw_panel()
	if _rules == null:
		_draw_text(Vector2(24.0, 72.0), "\u6587\u660e\u89c4\u5219\u670d\u52a1\u672a\u8fde\u63a5", 14, TEXT_MAIN)
		return
	_ensure_selected_lord(_selected_player)
	_draw_header(_selected_player)
	_draw_player_tabs()
	_draw_route_summary(_selected_player)
	_draw_owned_lords(_selected_player)
	_draw_candidate_lords(_selected_player)
	_draw_lord_detail(_selected_player)


func _gui_input(event: InputEvent) -> void:
	if not (event is InputEventMouseButton):
		return
	var mb: InputEventMouseButton = event
	if not mb.pressed or mb.button_index != MOUSE_BUTTON_LEFT:
		return
	if _handle_click(mb.position):
		accept_event()


func _handle_click(pos: Vector2) -> bool:
	var close_rect := Rect2(size.x - 86.0, 5.0, CLOSE_RECT.size.x, CLOSE_RECT.size.y)
	if close_rect.has_point(pos):
		visible = false
		return true
	if _add_rect.has_point(pos):
		_try_add_selected()
		return true
	if _remove_rect.has_point(pos):
		_try_remove_selected()
		return true
	for key in _player_rects.keys():
		var rect: Rect2 = _player_rects[key]
		if rect.has_point(pos):
			_selected_player = int(key)
			_selected_lord_id = ""
			_message = ""
			queue_redraw()
			return true
	for key in _owned_rects.keys():
		var rect: Rect2 = _owned_rects[key]
		if rect.has_point(pos):
			_selected_lord_id = str(key)
			_message = ""
			queue_redraw()
			return true
	for key in _candidate_rects.keys():
		var rect: Rect2 = _candidate_rects[key]
		if rect.has_point(pos):
			_selected_lord_id = str(key)
			_message = ""
			queue_redraw()
			return true
	return false


func _try_add_selected() -> void:
	if _rules == null or _selected_lord_id.is_empty():
		return
	if _rules.add_lord(_selected_player, _selected_lord_id):
		_message = "\u5df2\u52a0\u5165\u9886\u4e3b"
	else:
		var info: Dictionary = _rules.get_lord_add_info(_selected_player, _selected_lord_id)
		_message = _add_reason_text(info)
	queue_redraw()


func _try_remove_selected() -> void:
	if _rules == null or _selected_lord_id.is_empty():
		return
	if _rules.remove_lord(_selected_player, _selected_lord_id):
		_message = "\u5df2\u79fb\u9664\u9886\u4e3b"
	else:
		var info: Dictionary = _rules.get_lord_remove_info(_selected_player, _selected_lord_id)
		_message = _remove_reason_text(info)
	queue_redraw()


func _draw_panel() -> void:
	draw_rect(Rect2(Vector2.ZERO, size), PANEL_COLOR, true)
	draw_rect(Rect2(Vector2.ZERO, size), BORDER_COLOR, false, 1.0)
	draw_rect(Rect2(0.0, 0.0, size.x, 46.0), HEADER_COLOR, true)
	draw_rect(Rect2(size.x - 86.0, 5.0, CLOSE_RECT.size.x, CLOSE_RECT.size.y), Color(0.18, 0.08, 0.08, 0.88), true)
	draw_rect(Rect2(size.x - 86.0, 5.0, CLOSE_RECT.size.x, CLOSE_RECT.size.y), Color(1.0, 0.55, 0.48, 0.72), false, 1.0)
	_draw_text(Vector2(size.x - 73.0, 23.0), "\u5173\u95ed", 13, Color(1.0, 0.84, 0.80))


func _draw_header(player: int) -> void:
	var title := "\u6587\u660e\u8def\u7ebf | %s" % GameCatalog.faction_name(player)
	_draw_text(Vector2(18.0, 29.0), title, 17, TEXT_MAIN)
	_draw_text(Vector2(18.0, 67.0), "\u9009\u62e9\u9886\u4e3b\u67e5\u770b\u89e3\u9501\u9879\uff1b\u53ef\u7528\u5019\u9009\u4f1a\u901a\u8fc7\u89c4\u5219\u670d\u52a1\u6821\u9a8c\u3002", 12, TEXT_MUTED)


func _draw_player_tabs() -> void:
	var x := 18.0
	var y := 84.0
	for player_value in [0, 1, 2]:
		var player: int = int(player_value)
		var rect := Rect2(x, y, 106.0, 30.0)
		_player_rects[player] = rect
		var color: Color = GameCatalog.faction_color(player).darkened(0.45)
		if player == _selected_player:
			color = GameCatalog.faction_color(player).darkened(0.20)
		draw_rect(rect, color, true)
		draw_rect(rect, Color(1.0, 1.0, 1.0, 0.22), false, 1.0)
		_draw_centered_text(rect.get_center() + Vector2(0.0, 5.0), GameCatalog.faction_name(player), 12, TEXT_MAIN)
		x += 116.0


func _draw_route_summary(player: int) -> void:
	var summary: Dictionary = _rules.get_state_summary(player)
	var rect := Rect2(18.0, 128.0, 584.0, 82.0)
	draw_rect(rect, Color(0.055, 0.070, 0.090, 0.88), true)
	draw_rect(rect, Color(1.0, 1.0, 1.0, 0.12), false, 1.0)
	_draw_text(Vector2(rect.position.x + 12.0, rect.position.y + 24.0), "\u5f53\u524d\u8def\u7ebf", 13, TEXT_MAIN)
	var lord_ids: Array = summary.get("lord_ids", [])
	var axis_values: Dictionary = summary.get("axis_values", {})
	_draw_text(Vector2(rect.position.x + 12.0, rect.position.y + 50.0), "\u9886\u4e3b\u6570\uff1a%d" % lord_ids.size(), 12, TEXT_MUTED)
	_draw_text(Vector2(rect.position.x + 130.0, rect.position.y + 50.0), _format_axis_values(axis_values), 12, TEXT_MUTED)
	if not _message.is_empty():
		_draw_text(Vector2(rect.position.x + 12.0, rect.position.y + 74.0), _message, 11, Color(0.92, 0.80, 0.48))


func _draw_owned_lords(player: int) -> void:
	_draw_text(Vector2(18.0, 242.0), "\u5df2\u62e5\u6709\u9886\u4e3b", 14, TEXT_MAIN)
	var y := 258.0
	var lord_ids: Array = _rules.get_lord_ids(player)
	if lord_ids.is_empty():
		_draw_text(Vector2(26.0, y + 24.0), "\u6682\u65e0", 12, TEXT_MUTED)
		return
	for lord_id_value in lord_ids:
		var lord_id: String = str(lord_id_value)
		var summary: Dictionary = _rules.get_lord_summary(lord_id)
		var rect := Rect2(18.0, y, 278.0, 56.0)
		_owned_rects[lord_id] = rect
		_draw_lord_row(rect, summary, _rules.has_lord(player, lord_id), lord_id == _selected_lord_id)
		y += 64.0


func _draw_candidate_lords(player: int) -> void:
	_draw_text(Vector2(320.0, 242.0), "\u5019\u9009\u9886\u4e3b", 14, TEXT_MAIN)
	var y := 258.0
	var summaries: Array = _rules.get_lord_summaries(player)
	if summaries.is_empty():
		_draw_text(Vector2(328.0, y + 24.0), "\u6ca1\u6709\u53ef\u7528\u5019\u9009\u6a21\u677f", 12, TEXT_MUTED)
		return
	for item in summaries:
		var summary: Dictionary = item
		var lord_id: String = str(summary.get("id", ""))
		var add_info: Dictionary = summary.get("add_info", {})
		var available: bool = bool(add_info.get("available", false))
		var rect := Rect2(320.0, y, 282.0, 56.0)
		_candidate_rects[lord_id] = rect
		_draw_lord_row(rect, summary, available, lord_id == _selected_lord_id)
		_draw_text(Vector2(rect.position.x + 12.0, rect.position.y + 45.0), _add_reason_text(add_info), 10, Color(0.72, 0.82, 0.92) if available else Color(0.56, 0.58, 0.62))
		y += 64.0


func _draw_lord_row(rect: Rect2, summary: Dictionary, enabled: bool, selected: bool) -> void:
	var color := CARD_COLOR
	if selected:
		color = CARD_SELECTED
	elif not enabled:
		color = CARD_DISABLED
	draw_rect(rect, color, true)
	draw_rect(rect, Color(1.0, 1.0, 1.0, 0.12), false, 1.0)
	var name: String = str(summary.get("display_name", summary.get("id", "")))
	_draw_text(Vector2(rect.position.x + 12.0, rect.position.y + 21.0), name, 13, TEXT_MAIN if enabled else TEXT_MUTED)
	_draw_text(Vector2(rect.position.x + 12.0, rect.position.y + 38.0), _primary_axis_text(summary), 10, TEXT_MUTED)


func _draw_lord_detail(player: int) -> void:
	var x := 626.0
	var y := 84.0
	var w := size.x - x - 18.0
	var h := size.y - y - 18.0
	var rect := Rect2(x, y, w, h)
	draw_rect(rect, Color(0.04, 0.048, 0.060, 0.93), true)
	draw_rect(rect, Color(1.0, 1.0, 1.0, 0.12), false, 1.0)
	if _selected_lord_id.is_empty():
		_draw_text(Vector2(x + 18.0, y + 32.0), "\u9009\u62e9\u4e00\u4e2a\u9886\u4e3b", 15, TEXT_MAIN)
		return
	var summary: Dictionary = _rules.get_lord_summary(_selected_lord_id)
	if summary.is_empty():
		_draw_text(Vector2(x + 18.0, y + 32.0), "\u9886\u4e3b\u6a21\u677f\u7f3a\u5931", 15, TEXT_MAIN)
		return
	var title: String = str(summary.get("display_name", _selected_lord_id))
	_draw_text(Vector2(x + 18.0, y + 32.0), title, 17, TEXT_MAIN)
	_draw_text(Vector2(x + 18.0, y + 56.0), _primary_axis_text(summary), 12, TEXT_MUTED)
	var desc_y: float = _draw_wrapped_text(Vector2(x + 18.0, y + 86.0), str(summary.get("description", "")), 12, Color(0.76, 0.82, 0.90), w - 36.0, 3)
	_draw_text(Vector2(x + 18.0, desc_y + 24.0), "\u8f74\u5411", 13, TEXT_MAIN)
	var axis_values: Dictionary = summary.get("axis_values", {})
	_draw_text(Vector2(x + 18.0, desc_y + 48.0), _format_axis_values(axis_values), 12, TEXT_MUTED)
	_draw_text(Vector2(x + 18.0, desc_y + 84.0), "\u89e3\u9501", 13, TEXT_MAIN)
	var unlock_lines: Array[String] = _unlock_lines(summary)
	_draw_lines(Vector2(x + 18.0, desc_y + 108.0), unlock_lines, 12, Color(0.78, 0.86, 0.94), 22.0, 5)
	_draw_text(Vector2(x + 18.0, desc_y + 230.0), "\u88ab\u52a8\u4fee\u6b63", 13, TEXT_MAIN)
	var modifier_lines: Array[String] = _modifier_lines(summary)
	_draw_lines(Vector2(x + 18.0, desc_y + 254.0), modifier_lines, 12, Color(0.78, 0.86, 0.94), 22.0, 5)
	_draw_action_buttons(player, x, y, w, h)


func _draw_action_buttons(player: int, x: float, y: float, _w: float, h: float) -> void:
	var add_info: Dictionary = _rules.get_lord_add_info(player, _selected_lord_id)
	var remove_info: Dictionary = _rules.get_lord_remove_info(player, _selected_lord_id)
	var add_enabled: bool = bool(add_info.get("available", false))
	var remove_enabled: bool = bool(remove_info.get("available", false))
	_add_rect = Rect2(x + 18.0, y + h - 54.0, 116.0, 34.0)
	_remove_rect = Rect2(x + 148.0, y + h - 54.0, 116.0, 34.0)
	_draw_button(_add_rect, "\u52a0\u5165", add_enabled)
	_draw_button(_remove_rect, "\u79fb\u9664", remove_enabled)
	_draw_text(Vector2(x + 18.0, y + h - 66.0), _selected_status_text(add_info, remove_info), 11, TEXT_MUTED)


func _draw_button(rect: Rect2, label: String, enabled: bool) -> void:
	var color: Color = Color(0.12, 0.13, 0.15, 0.94)
	if enabled:
		color = Color(0.18, 0.34, 0.56, 0.96)
	draw_rect(rect, color, true)
	draw_rect(rect, Color(0.58, 0.76, 1.0, 0.55), false, 1.0)
	_draw_centered_text(rect.get_center() + Vector2(0.0, 5.0), label, 13, TEXT_MAIN if enabled else TEXT_MUTED)


func _ensure_selected_lord(player: int) -> void:
	if not _selected_lord_id.is_empty():
		var current: Dictionary = _rules.get_lord_summary(_selected_lord_id)
		if not current.is_empty() and int(current.get("civilization", -1)) == player:
			return
	var lord_ids: Array = _rules.get_lord_ids(player)
	if not lord_ids.is_empty():
		_selected_lord_id = str(lord_ids[0])
		return
	var summaries: Array = _rules.get_lord_summaries(player)
	if not summaries.is_empty():
		var first: Dictionary = summaries[0]
		_selected_lord_id = str(first.get("id", ""))
		return
	_selected_lord_id = ""


func _format_axis_values(axis_values: Dictionary) -> String:
	var parts := PackedStringArray()
	for key_value in ["information", "space", "war"]:
		var key: String = str(key_value)
		var value: int = int(axis_values.get(key, 0))
		parts.append("%s %d" % [str(_axis_names.get(key, key)), value])
	return "  ".join(parts)


func _primary_axis_text(summary: Dictionary) -> String:
	var primary_axis: int = int(summary.get("primary_axis", 0))
	var axis_name := "\u60c5\u62a5"
	match primary_axis:
		LordTemplate.Axis.SPACE:
			axis_name = "\u7a7a\u95f4"
		LordTemplate.Axis.WAR:
			axis_name = "\u6218\u4e89"
	return "\u4e3b\u8f74\uff1a%s" % axis_name


func _unlock_lines(summary: Dictionary) -> Array[String]:
	var lines: Array[String] = []
	var units: Array = summary.get("unlock_units", [])
	var buildings: Array = summary.get("unlock_buildings", [])
	var recipes: Array = summary.get("unlock_recipes", [])
	var actions: Array = summary.get("unlock_actions", [])
	_append_unlock_line(lines, "\u5355\u4f4d", units)
	_append_unlock_line(lines, "\u5efa\u7b51", buildings)
	_append_unlock_line(lines, "\u914d\u65b9", recipes)
	_append_unlock_line(lines, "\u884c\u52a8", actions)
	if lines.is_empty():
		lines.append("\u65e0\u76f4\u63a5\u89e3\u9501")
	return lines


func _append_unlock_line(lines: Array[String], title: String, ids: Array) -> void:
	if ids.is_empty():
		return
	var names := PackedStringArray()
	for id_value in ids:
		names.append(_display_id(str(id_value)))
	lines.append("%s\uff1a%s" % [title, ", ".join(names)])


func _modifier_lines(summary: Dictionary) -> Array[String]:
	var modifiers: Dictionary = summary.get("passive_modifiers", {})
	var lines: Array[String] = []
	if modifiers.is_empty():
		lines.append("\u65e0\u88ab\u52a8\u4fee\u6b63")
		return lines
	var keys: Array = modifiers.keys()
	keys.sort()
	for key_value in keys:
		var key: String = str(key_value)
		var value: Variant = modifiers[key]
		var name: String = str(_modifier_names.get(key, _humanize_key(key)))
		if value is int or value is float:
			var prefix: String = ""
			if float(value) >= 0.0:
				prefix = "+"
			lines.append("%s %s%s" % [name, prefix, str(value)])
		else:
			lines.append("%s %s" % [name, str(value)])
	return lines


func _display_id(id: String) -> String:
	if _unlock_names.has(id):
		return str(_unlock_names[id])
	return _humanize_key(id)


func _humanize_key(key: String) -> String:
	var text := key
	for prefix_value in ["building.", "recipe.", "action.", "unit.", "lord."]:
		var prefix: String = str(prefix_value)
		text = text.replace(prefix, "")
	text = text.replace(".", " ")
	text = text.replace("_", " ")
	return text


func _add_reason_text(info: Dictionary) -> String:
	var reason: String = str(info.get("reason", ""))
	match reason:
		"ok":
			return "\u53ef\u52a0\u5165"
		"already_owned":
			return "\u5df2\u62e5\u6709"
		"missing_required_tag":
			return "\u7f3a\u5c11\u524d\u7f6e\u6807\u7b7e\uff1a%s" % str(info.get("tag", ""))
		"exclusive_conflict":
			return "\u4e0e\u5df2\u6709\u9886\u4e3b\u4e92\u65a5"
		"wrong_civilization":
			return "\u9635\u8425\u4e0d\u5339\u914d"
		"lord_missing":
			return "\u6a21\u677f\u7f3a\u5931"
	return "\u4e0d\u53ef\u52a0\u5165"


func _remove_reason_text(info: Dictionary) -> String:
	var reason: String = str(info.get("reason", ""))
	match reason:
		"ok":
			return "\u53ef\u79fb\u9664"
		"primary_lord":
			return "\u4e3b\u9886\u4e3b\u4e0d\u80fd\u79fb\u9664"
		"not_owned":
			return "\u672a\u62e5\u6709"
	return "\u4e0d\u53ef\u79fb\u9664"


func _selected_status_text(add_info: Dictionary, remove_info: Dictionary) -> String:
	if bool(add_info.get("available", false)):
		return _add_reason_text(add_info)
	if bool(remove_info.get("available", false)):
		return _remove_reason_text(remove_info)
	if str(add_info.get("reason", "")) == "already_owned":
		return _remove_reason_text(remove_info)
	return _add_reason_text(add_info)


func _on_route_changed(player: int) -> void:
	if player == _selected_player:
		queue_redraw()


func _on_player_turn_started(player: int) -> void:
	_selected_player = player
	_selected_lord_id = ""
	_message = ""
	queue_redraw()


func _draw_lines(pos: Vector2, lines: Array[String], font_size: int, color: Color, gap: float, max_lines: int) -> void:
	var y := pos.y
	var count := mini(lines.size(), max_lines)
	for i in range(count):
		_draw_text(Vector2(pos.x, y), lines[i], font_size, color)
		y += gap
	if lines.size() > max_lines:
		_draw_text(Vector2(pos.x, y), "\u2026", font_size, color)


func _draw_wrapped_text(pos: Vector2, text: String, font_size: int, color: Color, max_width: float, max_lines: int) -> float:
	if text.is_empty():
		return pos.y
	var font: Font = ThemeDB.fallback_font
	var words: PackedStringArray = text.split(" ")
	var lines: Array[String] = []
	var current := ""
	for word_value in words:
		var word: String = str(word_value)
		var candidate: String = word
		if not current.is_empty():
			candidate = current + " " + word
		var width: float = font.get_string_size(candidate, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size).x
		if width > max_width and not current.is_empty():
			lines.append(current)
			current = word
		else:
			current = candidate
	if not current.is_empty():
		lines.append(current)
	var y := pos.y
	var count := mini(lines.size(), max_lines)
	for i in range(count):
		_draw_text(Vector2(pos.x, y), lines[i], font_size, color)
		y += 20.0
	return y


func _draw_text(pos: Vector2, text: String, font_size: int, color: Color) -> void:
	var font: Font = ThemeDB.fallback_font
	draw_string(font, pos, text, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size, color)


func _draw_centered_text(pos: Vector2, text: String, font_size: int, color: Color) -> void:
	var font: Font = ThemeDB.fallback_font
	var width: float = font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size).x
	draw_string(font, pos - Vector2(width * 0.5, 0.0), text, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size, color)
