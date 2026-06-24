class_name AchievementTreePanel
extends Control

const PANEL_COLOR := Color(0.035, 0.04, 0.045, 0.86)
const BORDER_COLOR := Color(0.34, 0.48, 0.68, 0.55)
const LINE_LOCKED := Color(0.26, 0.28, 0.30, 0.75)
const LINE_OPEN := Color(0.38, 0.55, 0.80, 0.85)
const NODE_LOCKED := Color(0.12, 0.13, 0.14, 0.95)
const NODE_OPEN := Color(0.16, 0.23, 0.32, 0.96)
const NODE_DONE := Color(0.18, 0.42, 0.23, 0.96)
const NODE_BORDER := Color(0.72, 0.84, 1.0, 0.72)
const NODE_DONE_BORDER := Color(0.62, 1.0, 0.58, 0.88)
const NODE_SIZE := Vector2(104, 46)
const SIDEBAR_W := 112.0
const HEADER_H := 34.0
const DETAIL_H := 82.0
const NODE_GAP_X := 142.0
const NODE_GAP_Y := 68.0
const CLOSE_RECT := Rect2(0, 0, 72, 26)

var _service: AchievementService = null
var _turn_manager: Node = null
var _selected_branch := "foundation"
var _selected_id := ""
var _node_rects: Dictionary = {}
var _branch_order: Array[String] = ["foundation", "industry", "military", "lord"]
var _branch_names: Dictionary = {
	"foundation": "\u6839\u57fa",
	"industry": "\u5de5\u4e1a",
	"military": "\u519b\u4e8b",
	"lord": "\u9886\u4e3b",
}
var _resource_names: Dictionary = {
	"wood": "\u6728\u6750",
	"stone": "\u77f3\u6599",
	"food": "\u98df\u7269",
	"iron": "\u94c1\u77ff",
	"magic_dust": "\u9b54\u5c18",
	"gold": "\u91d1\u5e01",
	"ancient_wood": "\u53e4\u6728",
	"gold_ore": "\u91d1\u77ff\u77f3",
}


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_STOP
	set_process(false)
	queue_redraw()


func setup(service: AchievementService, turn_manager: Node) -> void:
	_service = service
	_turn_manager = turn_manager
	if _service != null:
		if not _service.achievement_state_changed.is_connected(_on_state_changed):
			_service.achievement_state_changed.connect(_on_state_changed)
		if not _service.achievement_completed.is_connected(_on_achievement_completed):
			_service.achievement_completed.connect(_on_achievement_completed)
	if _turn_manager != null and _turn_manager.has_signal("player_turn_started"):
		if not _turn_manager.player_turn_started.is_connected(_on_turn_started):
			_turn_manager.player_turn_started.connect(_on_turn_started)
	queue_redraw()


func _draw() -> void:
	_node_rects.clear()
	_draw_panel()
	if _service == null or _turn_manager == null:
		_draw_text(Vector2(16, 28), "\u6210\u5c31\u6811\u672a\u8fde\u63a5", 14, Color(0.9, 0.9, 0.9))
		return
	var player: int = int(_turn_manager.current_player)
	_draw_header(player)
	_draw_branch_tabs(player)
	_draw_tree(player)
	_draw_detail(player)


func _gui_input(event: InputEvent) -> void:
	if not (event is InputEventMouseButton):
		return
	var mb: InputEventMouseButton = event
	if not mb.pressed or mb.button_index != MOUSE_BUTTON_LEFT:
		return
	var pos: Vector2 = mb.position
	var close_rect := Rect2(size.x - 86.0, 5.0, CLOSE_RECT.size.x, CLOSE_RECT.size.y)
	if close_rect.has_point(pos):
		visible = false
		accept_event()
		return
	var tab_y := HEADER_H + 8.0
	for i in range(_branch_order.size()):
		var branch: String = _branch_order[i]
		var rect := Rect2(8.0, tab_y + i * 34.0, SIDEBAR_W - 16.0, 28.0)
		if rect.has_point(pos):
			_selected_branch = branch
			_selected_id = ""
			queue_redraw()
			accept_event()
			return
	for id in _node_rects.keys():
		var rect: Rect2 = _node_rects[id]
		if rect.has_point(pos):
			_selected_id = str(id)
			queue_redraw()
			accept_event()
			return


func _on_state_changed(_player: int) -> void:
	queue_redraw()


func _on_achievement_completed(_player: int, achievement_id: String, _title: String) -> void:
	_selected_id = achievement_id
	queue_redraw()


func _on_turn_started(_player: int) -> void:
	queue_redraw()


func _draw_panel() -> void:
	var bg := StyleBoxFlat.new()
	bg.bg_color = PANEL_COLOR
	bg.border_color = BORDER_COLOR
	bg.set_border_width_all(1)
	bg.set_corner_radius_all(4)
	draw_style_box(bg, Rect2(Vector2.ZERO, size))
	draw_line(Vector2(SIDEBAR_W, HEADER_H), Vector2(SIDEBAR_W, size.y - DETAIL_H), Color(1, 1, 1, 0.12), 1.0)
	draw_line(Vector2(0, HEADER_H), Vector2(size.x, HEADER_H), Color(1, 1, 1, 0.12), 1.0)
	draw_line(Vector2(SIDEBAR_W, size.y - DETAIL_H), Vector2(size.x, size.y - DETAIL_H), Color(1, 1, 1, 0.12), 1.0)
	draw_rect(Rect2(size.x - 86.0, 5.0, CLOSE_RECT.size.x, CLOSE_RECT.size.y), Color(0.18, 0.08, 0.08, 0.82), true)
	draw_rect(Rect2(size.x - 86.0, 5.0, CLOSE_RECT.size.x, CLOSE_RECT.size.y), Color(1.0, 0.55, 0.48, 0.72), false, 1.0)
	_draw_text(Vector2(size.x - 73.0, 23.0), "\u5173\u95ed", 13, Color(1.0, 0.84, 0.80))


func _draw_header(player: int) -> void:
	var title := "\u6210\u5c31\u6811 | %s | \u79d1\u6280\u70b9 %d" % [
		GameCatalog.faction_name(player),
		_service.get_tech_points(player),
	]
	_draw_text(Vector2(12, 22), title, 15, Color(0.94, 0.97, 1.0))
	var total: int = _service.get_definitions().size()
	var done: int = _service.get_completed_count(player)
	_draw_text(Vector2(size.x - 112.0, 22), "%d / %d" % [done, total], 14, Color(0.72, 0.86, 1.0))


func _draw_branch_tabs(player: int) -> void:
	var summary: Dictionary = _service.get_branch_summary(player)
	var y := HEADER_H + 8.0
	for i in range(_branch_order.size()):
		var branch: String = _branch_order[i]
		var rect := Rect2(8.0, y + i * 34.0, SIDEBAR_W - 16.0, 28.0)
		var active: bool = branch == _selected_branch
		var color := Color(0.12, 0.17, 0.23, 0.96) if active else Color(0.07, 0.08, 0.09, 0.72)
		draw_rect(rect, color, true)
		draw_rect(rect, Color(0.54, 0.70, 0.92, 0.55) if active else Color(1, 1, 1, 0.12), false, 1.0)
		var s: Dictionary = summary.get(branch, {})
		var label := "%s %d/%d" % [
			str(_branch_names.get(branch, branch)),
			int(s.get("completed", 0)),
			int(s.get("total", 0)),
		]
		_draw_text(rect.position + Vector2(8, 19), label, 12, Color(0.9, 0.94, 1.0))


func _draw_tree(player: int) -> void:
	var definitions: Array = _get_branch_definitions(_selected_branch)
	var layout: Dictionary = _make_layout(definitions)
	var origin := Vector2(SIDEBAR_W + 26.0, HEADER_H + 26.0)
	for definition in definitions:
		var id: String = str(definition["id"])
		var pos: Vector2 = layout.get(id, Vector2.ZERO)
		var rect := Rect2(origin + Vector2(pos.x * NODE_GAP_X, pos.y * NODE_GAP_Y), NODE_SIZE)
		_node_rects[id] = rect

	for definition in definitions:
		var id: String = str(definition["id"])
		var rect: Rect2 = _node_rects[id]
		for parent_id in definition.get("parents", []):
			var parent_key: String = str(parent_id)
			if not _node_rects.has(parent_key):
				continue
			var parent_rect: Rect2 = _node_rects[parent_key]
			var done: bool = _service.is_completed(player, parent_key)
			var line_color := LINE_OPEN if done else LINE_LOCKED
			draw_line(parent_rect.position + Vector2(parent_rect.size.x, parent_rect.size.y * 0.5), rect.position + Vector2(0, rect.size.y * 0.5), line_color, 2.0)

	for definition in definitions:
		_draw_node(player, definition, _node_rects[str(definition["id"])])


func _draw_node(player: int, definition: Dictionary, rect: Rect2) -> void:
	var id: String = str(definition["id"])
	var completed: bool = _service.is_completed(player, id)
	var unlocked: bool = _service.is_unlocked(player, id)
	var color := NODE_LOCKED
	var border := Color(1, 1, 1, 0.18)
	if completed:
		color = NODE_DONE
		border = NODE_DONE_BORDER
	elif unlocked:
		color = NODE_OPEN
		border = NODE_BORDER
	if id == _selected_id:
		border = Color(1.0, 0.90, 0.42, 1.0)
	draw_rect(rect, color, true)
	draw_rect(rect, border, false, 2.0 if id == _selected_id else 1.0)
	var title: String = str(definition.get("title", id))
	if title.length() > 16:
		title = title.substr(0, 15) + "."
	_draw_text(rect.position + Vector2(8, 18), title, 12, Color(0.92, 0.96, 1.0) if unlocked else Color(0.55, 0.58, 0.62))
	var mark := "\u5df2\u5b8c\u6210" if completed else ("\u53ef\u8fbe\u6210" if unlocked else "\u672a\u5f00\u653e")
	_draw_text(rect.position + Vector2(8, 36), mark, 10, Color(0.70, 1.0, 0.66) if completed else Color(0.62, 0.76, 0.96))


func _draw_detail(player: int) -> void:
	var y: float = size.y - DETAIL_H + 22.0
	if _selected_id.is_empty():
		_draw_text(Vector2(SIDEBAR_W + 18.0, y), "\u70b9\u51fb\u8282\u70b9\u67e5\u770b\u6761\u4ef6\u548c\u5956\u52b1", 13, Color(0.78, 0.82, 0.88))
		_draw_text(Vector2(SIDEBAR_W + 18.0, y + 24.0), "\u7eff\u8272=\u5df2\u5b8c\u6210  \u84dd\u8272=\u53ef\u8fbe\u6210  \u7070\u8272=\u672a\u5f00\u653e", 12, Color(0.62, 0.70, 0.82))
		return
	var definition: Dictionary = _service.get_definition(_selected_id)
	if definition.is_empty():
		return
	_draw_text(Vector2(SIDEBAR_W + 18.0, y), str(definition.get("title", _selected_id)), 14, Color(0.96, 0.98, 1.0))
	var status := "\u5df2\u5b8c\u6210" if _service.is_completed(player, _selected_id) else ("\u53ef\u8fbe\u6210" if _service.is_unlocked(player, _selected_id) else "\u672a\u5f00\u653e")
	_draw_text(Vector2(SIDEBAR_W + 18.0, y + 22.0), "%s | %s | %s" % [
		status,
		_describe_condition(definition.get("condition", {})),
		_describe_reward(definition.get("reward", {})),
	], 12, Color(0.82, 0.88, 0.96))
	var parents: Array = definition.get("parents", [])
	if not parents.is_empty():
		var parent_text := PackedStringArray()
		for parent in parents:
			parent_text.append(_get_title_for_id(str(parent)))
		_draw_text(Vector2(SIDEBAR_W + 18.0, y + 43.0), "\u524d\u7f6e\uff1a" + ", ".join(parent_text), 11, Color(0.64, 0.70, 0.78))


func _get_branch_definitions(branch: String) -> Array:
	var result: Array = []
	if _service == null:
		return result
	for definition in _service.get_definitions():
		var d: Dictionary = definition
		if str(d.get("branch", "")) == branch:
			result.append(d)
	return result


func _make_layout(definitions: Array) -> Dictionary:
	var same_branch_ids := {}
	for definition in definitions:
		same_branch_ids[str(definition["id"])] = true
	var depths: Dictionary = {}
	for definition in definitions:
		_assign_depth(str(definition["id"]), definitions, same_branch_ids, depths)
	var per_depth_count: Dictionary = {}
	var result: Dictionary = {}
	for definition in definitions:
		var id: String = str(definition["id"])
		var depth: int = int(depths.get(id, 0))
		var lane: int = int(per_depth_count.get(depth, 0))
		per_depth_count[depth] = lane + 1
		result[id] = Vector2(depth, lane)
	return result


func _assign_depth(id: String, definitions: Array, same_branch_ids: Dictionary, depths: Dictionary) -> int:
	if depths.has(id):
		return int(depths[id])
	var definition := {}
	for item in definitions:
		var d: Dictionary = item
		if str(d["id"]) == id:
			definition = d
			break
	var depth := 0
	for parent_id_variant in definition.get("parents", []):
		var parent_id: String = str(parent_id_variant)
		if not same_branch_ids.has(parent_id):
			continue
		depth = maxi(depth, _assign_depth(parent_id, definitions, same_branch_ids, depths) + 1)
	depths[id] = depth
	return depth


func _describe_condition(condition: Dictionary) -> String:
	var kind: String = str(condition.get("kind", ""))
	match kind:
		"building":
			if condition.has("production_key"):
				return "\u5efa\u9020\u4ea7\u51fa " + _resource_name(str(condition["production_key"])) + " \u7684\u5efa\u7b51"
			if condition.has("tag"):
				return "\u5efa\u9020 " + _tag_name(str(condition["tag"])) + " \u5efa\u7b51"
			if condition.has("special"):
				return "\u5efa\u9020 " + _special_name(str(condition["special"]))
			if condition.has("category"):
				return "\u5efa\u9020\u6307\u5b9a\u7c7b\u578b\u5efa\u7b51"
			if condition.has("civilization"):
				return "\u5efa\u9020 " + _civilization_name(str(condition["civilization"])) + " \u9886\u4e3b\u5efa\u7b51"
			return "\u5efa\u9020\u6307\u5b9a\u5efa\u7b51"
		"building_count":
			return "\u62e5\u6709 %d \u5ea7\u6307\u5b9a\u5efa\u7b51" % int(condition.get("count", 1))
		"building_garrison":
			return "\u5de5\u4eba\u5165\u9a7b\u6307\u5b9a\u5efa\u7b51"
		"unit_recruited":
			return "\u62db\u52df\u4e00\u540d\u6218\u6597\u5355\u4f4d"
		"unit_count":
			return "\u62e5\u6709 %d \u540d\u6307\u5b9a\u5355\u4f4d" % int(condition.get("count", 1))
		"kill":
			return "\u51fb\u8d25" + _target_name(str(condition.get("target", "target")))
		"resource_stock", "resource_any_stock":
			return "\u62e5\u6709\u6307\u5b9a\u8d44\u6e90"
	return kind


func _describe_reward(reward: Dictionary) -> String:
	var parts: Array[String] = []
	var tp: int = int(reward.get("tech_points", 0))
	if tp > 0:
		parts.append("\u79d1\u6280\u70b9 +%d" % tp)
	var resources: Dictionary = reward.get("resources", {})
	for key in resources:
		parts.append("%s +%d" % [_resource_name(str(key)), int(resources[key])])
	return "\u5956\u52b1\uff1a" + ", ".join(parts) if not parts.is_empty() else "\u5956\u52b1\uff1a\u65e0"


func _get_title_for_id(achievement_id: String) -> String:
	if _service == null:
		return achievement_id
	var definition: Dictionary = _service.get_definition(achievement_id)
	return str(definition.get("title", achievement_id))


func _resource_name(key: String) -> String:
	return str(_resource_names.get(key, GameCatalog.resource_name(key)))


func _tag_name(tag: String) -> String:
	match tag:
		"barracks":
			return "\u5175\u8425"
	return tag


func _special_name(key: String) -> String:
	match key:
		"gold_shaft":
			return "\u91d1\u77ff\u4e95"
		"mint":
			return "\u91d1\u5e01\u94f8\u9020\u5382"
	return key


func _civilization_name(key: String) -> String:
	match key:
		"elf":
			return "\u7cbe\u7075"
		"dwarf":
			return "\u77ee\u4eba"
		"orc":
			return "\u517d\u4eba"
	return key


func _target_name(key: String) -> String:
	match key:
		"neutral":
			return "\u4e2d\u7acb\u5355\u4f4d"
		"player":
			return "\u654c\u65b9\u5355\u4f4d"
	return key


func _draw_text(pos: Vector2, text: String, font_size: int, color: Color) -> void:
	var font: Font = ThemeDB.fallback_font
	draw_string(font, pos, text, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size, color)
