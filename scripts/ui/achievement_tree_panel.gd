class_name AchievementTreePanel
extends Control

const PANEL_COLOR := Color(0.035, 0.04, 0.045, 0.88)
const BORDER_COLOR := Color(0.34, 0.48, 0.68, 0.55)
const BLOCK_COLOR := Color(0.06, 0.075, 0.085, 0.82)
const BLOCK_BORDER := Color(0.42, 0.52, 0.66, 0.55)
const BLOCK_TITLE_COLOR := Color(0.82, 0.90, 1.0)
const LINE_LOCKED := Color(0.25, 0.27, 0.30, 0.72)
const LINE_OPEN := Color(0.42, 0.64, 0.92, 0.88)
const LINE_DONE := Color(0.50, 0.92, 0.50, 0.92)
const NODE_LOCKED := Color(0.10, 0.11, 0.12, 0.96)
const NODE_OPEN := Color(0.13, 0.22, 0.34, 0.96)
const NODE_DONE := Color(0.18, 0.42, 0.23, 0.96)
const NODE_BORDER := Color(0.72, 0.84, 1.0, 0.72)
const NODE_DONE_BORDER := Color(0.62, 1.0, 0.58, 0.88)
const NODE_RADIUS := 20.0
const NODE_SIZE := Vector2(40.0, 40.0)
const NODE_STEP := Vector2(112.0, 82.0)
const HEADER_H := 40.0
const DETAIL_H := 114.0
const BOARD_MARGIN := 18.0
const GRID_GAP := 14.0
const CLOSE_RECT := Rect2(0, 0, 72, 26)

var _service: AchievementService = null
var _turn_manager: Node = null
var _selected_id := ""
var _node_rects: Dictionary = {}
var _node_defs: Dictionary = {}
var _panel_rects: Dictionary = {}
var _panel_order: Array[String] = [
	"foundation",
	"military",
	"elf_shadow",
	"industry",
	"dragon",
	"dwarf_fortress",
	"lord",
	"orc_war",
	"hybrid_end",
]
var _panel_names: Dictionary = {
	"foundation": "基础建设",
	"military": "军事训练",
	"elf_shadow": "精灵情报",
	"industry": "资源工业",
	"dragon": "龙血路线",
	"dwarf_fortress": "矮人筑防",
	"lord": "领主据点",
	"orc_war": "兽人战争",
	"hybrid_end": "终局融合",
}
var _resource_names: Dictionary = {
	"wood": "木材",
	"stone": "石料",
	"food": "食物",
	"iron": "铁矿",
	"magic_dust": "魔尘",
	"gold": "金币",
	"ancient_wood": "古木",
	"gold_ore": "金矿石",
}
var _tech_names: Dictionary = {
	"tech.common.map_drawing": "地图绘制",
	"tech.common.storage_system": "仓储制度",
	"tech.common.border_survey": "边境测绘",
	"tech.common.tool_forging": "工具锻造",
	"tech.common.building_upgrade": "建筑升级",
	"tech.common.iron_mining": "铁矿开采",
	"tech.common.gold_mining": "金矿开采",
	"tech.common.coin_machinery": "铸币机械",
	"tech.common.recruitment_rules": "招募规程",
	"tech.common.war_drum_mobilization": "战鼓动员",
	"tech.dragon.nest_survey": "龙巢勘测",
	"tech.lord.elf.wind_sight": "风语视界",
	"tech.lord.dwarf.deep_forge": "深炉工艺",
	"tech.lord.orc.blood_drum": "血鼓号令",
	"tech.lord.orc.raid_ration": "掠食军粮",
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
	_node_defs.clear()
	_draw_panel()
	if _service == null or _turn_manager == null:
		_draw_text(Vector2(16.0, 28.0), "成就树未连接", 14, Color(0.9, 0.9, 0.9))
		return
	var player: int = int(_turn_manager.current_player)
	_draw_header(player)
	_panel_rects = _make_panel_rects()
	_draw_block_frames(player)
	_build_node_rects()
	_draw_links(player)
	_draw_nodes(player)
	_draw_detail(player)


func _gui_input(event: InputEvent) -> void:
	if event is InputEventMouseMotion:
		accept_event()
		return
	if not (event is InputEventMouseButton):
		return
	var mb: InputEventMouseButton = event
	if not mb.pressed or mb.button_index != MOUSE_BUTTON_LEFT:
		accept_event()
		return
	var pos: Vector2 = mb.position
	var close_rect := Rect2(size.x - 86.0, 7.0, CLOSE_RECT.size.x, CLOSE_RECT.size.y)
	if close_rect.has_point(pos):
		visible = false
		accept_event()
		return
	for id in _node_rects.keys():
		var rect: Rect2 = _node_rects[id]
		if rect.has_point(pos):
			_selected_id = str(id)
			queue_redraw()
			accept_event()
			return
	accept_event()


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
	draw_line(Vector2(0.0, HEADER_H), Vector2(size.x, HEADER_H), Color(1.0, 1.0, 1.0, 0.12), 1.0)
	draw_line(Vector2(0.0, size.y - DETAIL_H), Vector2(size.x, size.y - DETAIL_H), Color(1.0, 1.0, 1.0, 0.12), 1.0)
	draw_rect(Rect2(size.x - 86.0, 7.0, CLOSE_RECT.size.x, CLOSE_RECT.size.y), Color(0.18, 0.08, 0.08, 0.82), true)
	draw_rect(Rect2(size.x - 86.0, 7.0, CLOSE_RECT.size.x, CLOSE_RECT.size.y), Color(1.0, 0.55, 0.48, 0.72), false, 1.0)
	_draw_text(Vector2(size.x - 73.0, 25.0), "关闭", 13, Color(1.0, 0.84, 0.80))


func _draw_header(player: int) -> void:
	var title := "成就树 | %s | 科技点 %d" % [
		GameCatalog.faction_name(player),
		_service.get_tech_points(player),
	]
	_draw_text(Vector2(14.0, 25.0), title, 16, Color(0.94, 0.97, 1.0))
	var total: int = _service.get_definitions().size()
	var done: int = _service.get_completed_count(player)
	_draw_text(Vector2(size.x - 190.0, 25.0), "%d / %d" % [done, total], 14, Color(0.72, 0.86, 1.0))
	_draw_text(Vector2(330.0, 25.0), "绿色=已完成  蓝色=可完成  灰色=前置未完成  虚线=跨板块前置", 12, Color(0.68, 0.75, 0.86))


func _make_panel_rects() -> Dictionary:
	var result: Dictionary = {}
	var board_x: float = BOARD_MARGIN
	var board_y: float = HEADER_H + BOARD_MARGIN
	var board_w: float = size.x - BOARD_MARGIN * 2.0
	var board_h: float = size.y - DETAIL_H - board_y - BOARD_MARGIN
	var col_w: float = (board_w - GRID_GAP * 2.0) / 3.0
	var row_h: float = (board_h - GRID_GAP * 2.0) / 3.0
	for i in range(_panel_order.size()):
		var panel_id: String = _panel_order[i]
		var col: int = i % 3
		var row: int = floori(float(i) / 3.0)
		var pos := Vector2(board_x + float(col) * (col_w + GRID_GAP), board_y + float(row) * (row_h + GRID_GAP))
		result[panel_id] = Rect2(pos, Vector2(col_w, row_h))
	return result


func _draw_block_frames(player: int) -> void:
	for panel_id in _panel_order:
		if not _panel_rects.has(panel_id):
			continue
		var rect: Rect2 = _panel_rects[panel_id]
		draw_rect(rect, BLOCK_COLOR, true)
		draw_rect(rect, BLOCK_BORDER, false, 1.0)
		draw_rect(Rect2(rect.position, Vector2(rect.size.x, 28.0)), Color(0.10, 0.13, 0.16, 0.82), true)
		var counts: Dictionary = _panel_counts(player, panel_id)
		var title := "%s  %d/%d" % [
			str(_panel_names.get(panel_id, panel_id)),
			int(counts.get("completed", 0)),
			int(counts.get("total", 0)),
		]
		_draw_text(rect.position + Vector2(12.0, 20.0), title, 13, BLOCK_TITLE_COLOR)
		if int(counts.get("total", 0)) == 0:
			_draw_text(rect.position + Vector2(18.0, 58.0), "待规划", 12, Color(0.48, 0.54, 0.62))


func _build_node_rects() -> void:
	for definition_variant in _service.get_definitions():
		var definition: Dictionary = definition_variant
		var panel_id: String = _definition_panel(definition)
		if not _panel_rects.has(panel_id):
			continue
		var panel_rect: Rect2 = _panel_rects[panel_id]
		var grid_pos: Vector2i = Vector2i.ZERO
		if definition.has("position"):
			grid_pos = definition["position"]
		var node_pos: Vector2 = panel_rect.position + Vector2(24.0 + float(grid_pos.x) * NODE_STEP.x, 50.0 + float(grid_pos.y) * NODE_STEP.y)
		var id: String = str(definition["id"])
		_node_rects[id] = Rect2(node_pos, NODE_SIZE)
		_node_defs[id] = definition


func _draw_links(player: int) -> void:
	for definition_variant in _service.get_definitions():
		var definition: Dictionary = definition_variant
		var id: String = str(definition["id"])
		if not _node_rects.has(id):
			continue
		var rect: Rect2 = _node_rects[id]
		for parent_id_variant in definition.get("parents", []):
			var parent_id: String = str(parent_id_variant)
			if not _node_rects.has(parent_id):
				continue
			var parent_rect: Rect2 = _node_rects[parent_id]
			var parent_done: bool = _service.is_completed(player, parent_id)
			var child_open: bool = _service.is_unlocked(player, id)
			var line_color: Color = LINE_LOCKED
			if parent_done and child_open:
				line_color = LINE_OPEN
			if parent_done and _service.is_completed(player, id):
				line_color = LINE_DONE
			var from: Vector2 = parent_rect.position + parent_rect.size * 0.5
			var to: Vector2 = rect.position + rect.size * 0.5
			var parent_def: Dictionary = _node_defs.get(parent_id, {})
			var same_panel: bool = _definition_panel(parent_def) == _definition_panel(definition)
			if same_panel:
				draw_line(from, to, line_color, 2.0)
			else:
				var cross_color := Color(line_color.r, line_color.g, line_color.b, line_color.a * 0.55)
				_draw_dashed_line(from, to, cross_color, 1.0, 8.0, 7.0)


func _draw_nodes(player: int) -> void:
	for definition_variant in _service.get_definitions():
		var definition: Dictionary = definition_variant
		var id: String = str(definition["id"])
		if _node_rects.has(id):
			_draw_node(player, definition, _node_rects[id])


func _draw_node(player: int, definition: Dictionary, rect: Rect2) -> void:
	var id: String = str(definition["id"])
	var completed: bool = _service.is_completed(player, id)
	var unlocked: bool = _service.is_unlocked(player, id)
	var fill: Color = NODE_LOCKED
	var border: Color = Color(1.0, 1.0, 1.0, 0.18)
	var text_color: Color = Color(0.55, 0.58, 0.62)
	if completed:
		fill = NODE_DONE
		border = NODE_DONE_BORDER
		text_color = Color(0.92, 1.0, 0.90)
	elif unlocked:
		fill = NODE_OPEN
		border = NODE_BORDER
		text_color = Color(0.92, 0.96, 1.0)
	if id == _selected_id:
		border = Color(1.0, 0.90, 0.42, 1.0)
	var center: Vector2 = rect.get_center()
	var radius := NODE_RADIUS
	draw_circle(center, radius, fill)
	var border_width: float = 1.5
	if id == _selected_id:
		border_width = 2.0
	draw_arc(center, radius, 0.0, TAU, 48, border, border_width)

	var icon_label: String = _icon_label(str(definition.get("icon_key", "")))
	_draw_centered_text(center + Vector2(0.0, 6.0), icon_label, 17, text_color)

	var progress: Dictionary = _service.get_progress(player, id)
	var progress_text: String = "%d/%d" % [int(progress.get("current", 0)), int(progress.get("target", 1))]
	var progress_color: Color = Color(0.48, 0.52, 0.58)
	if unlocked:
		progress_color = Color(0.78, 0.86, 0.96)
	_draw_centered_text(center + Vector2(0.0, radius + 15.0), progress_text, 10, progress_color)
	_draw_centered_text(center + Vector2(0.0, radius + 31.0), _short_title(str(definition.get("title", id))), 10, text_color)


func _draw_detail(player: int) -> void:
	var y: float = size.y - DETAIL_H + 22.0
	if _selected_id.is_empty():
		_draw_text(Vector2(18.0, y), "点击任意节点查看条件、进度、奖励和关联科技。", 13, Color(0.78, 0.82, 0.88))
		_draw_text(Vector2(18.0, y + 26.0), "每个板块是一个玩法方向；板块内实线表示直接路线，跨板块虚线表示外部前置。", 12, Color(0.62, 0.70, 0.82))
		return
	var definition: Dictionary = _service.get_definition(_selected_id)
	if definition.is_empty():
		return
	var progress: Dictionary = _service.get_progress(player, _selected_id)
	var status := "未开放"
	if _service.is_completed(player, _selected_id):
		status = "已完成"
	elif _service.is_unlocked(player, _selected_id):
		status = "可完成"
	_draw_text(Vector2(18.0, y), "%s | %s | %d/%d" % [
		str(definition.get("title", _selected_id)),
		status,
		int(progress.get("current", 0)),
		int(progress.get("target", 1)),
	], 14, Color(0.96, 0.98, 1.0))
	_draw_text(Vector2(18.0, y + 24.0), str(definition.get("description", "")), 12, Color(0.76, 0.83, 0.92))
	_draw_text(Vector2(18.0, y + 46.0), "%s | %s" % [
		_describe_condition(definition.get("condition", {})),
		_describe_reward(definition.get("reward", {})),
	], 12, Color(0.82, 0.88, 0.96))
	_draw_text(Vector2(18.0, y + 68.0), _describe_unlocks(definition), 11, Color(0.64, 0.70, 0.78))
	var parents: Array = definition.get("parents", [])
	if not parents.is_empty():
		var parent_text := PackedStringArray()
		for parent in parents:
			parent_text.append(_get_title_for_id(str(parent)))
		_draw_text(Vector2(640.0, y + 68.0), "前置：" + ", ".join(parent_text), 11, Color(0.64, 0.70, 0.78))


func _panel_counts(player: int, panel_id: String) -> Dictionary:
	var total := 0
	var completed := 0
	var unlocked := 0
	for definition_variant in _service.get_definitions():
		var definition: Dictionary = definition_variant
		if _definition_panel(definition) != panel_id:
			continue
		total += 1
		var id: String = str(definition["id"])
		if _service.is_completed(player, id):
			completed += 1
		elif _service.is_unlocked(player, id):
			unlocked += 1
	return {
		"total": total,
		"completed": completed,
		"unlocked": unlocked,
	}


func _definition_panel(definition: Dictionary) -> String:
	if definition.is_empty():
		return ""
	if definition.has("panel"):
		return str(definition["panel"])
	return str(definition.get("branch", "foundation"))


func _icon_label(key: String) -> String:
	match key:
		"wood":
			return "木"
		"stone":
			return "石"
		"food":
			return "粮"
		"iron":
			return "铁"
		"gold", "gold_ore":
			return "金"
		"magic_dust":
			return "魔"
		"ancient_wood":
			return "古"
		"worker":
			return "工"
		"unit":
			return "兵"
		"kill":
			return "战"
		"dragon":
			return "龙"
		"elf":
			return "精"
		"dwarf":
			return "矮"
		"orc":
			return "兽"
		"recruit_camp":
			return "招"
		"gold_shaft":
			return "井"
		"mint":
			return "铸"
		"building":
			return "建"
		"resource":
			return "资"
	return "成"


func _short_title(title: String) -> String:
	if title.length() <= 6:
		return title
	return title.substr(0, 6)


func _describe_condition(condition: Dictionary) -> String:
	var kind: String = str(condition.get("kind", ""))
	match kind:
		"building":
			if condition.has("production_key"):
				return "条件：建造产出 " + _resource_name(str(condition["production_key"])) + " 的建筑"
			if condition.has("tag"):
				return "条件：建造 " + _tag_name(str(condition["tag"])) + " 建筑"
			if condition.has("special"):
				return "条件：建造 " + _special_name(str(condition["special"]))
			if condition.has("category"):
				return "条件：建造指定类型建筑"
			if condition.has("civilization"):
				return "条件：建造 " + _civilization_name(str(condition["civilization"])) + " 领主建筑"
			return "条件：建造指定建筑"
		"building_count":
			return "条件：拥有 %d 座指定建筑" % int(condition.get("count", 1))
		"building_garrison":
			return "条件：工人入驻指定建筑"
		"unit_recruited":
			return "条件：招募一名战斗单位"
		"unit_count":
			return "条件：拥有 %d 名指定单位" % int(condition.get("count", 1))
		"kill":
			return "条件：击败" + _target_name(str(condition.get("target", "target")))
		"resource_stock", "resource_any_stock":
			return "条件：拥有指定资源"
	return "条件：" + kind


func _describe_reward(reward: Dictionary) -> String:
	var parts: Array[String] = []
	var tp: int = int(reward.get("tech_points", 0))
	if tp > 0:
		parts.append("科技点 +%d" % tp)
	var resources: Dictionary = reward.get("resources", {})
	for key in resources:
		parts.append("%s +%d" % [_resource_name(str(key)), int(resources[key])])
	if parts.is_empty():
		return "奖励：无"
	return "奖励：" + ", ".join(parts)


func _describe_unlocks(definition: Dictionary) -> String:
	var hints: Array = definition.get("unlocks_hint", [])
	if hints.is_empty():
		return "关联科技：无"
	var names := PackedStringArray()
	for hint in hints:
		var key: String = str(hint)
		names.append(str(_tech_names.get(key, key)))
	return "关联科技：" + ", ".join(names)


func _get_title_for_id(achievement_id: String) -> String:
	if _service == null:
		return achievement_id
	var definition: Dictionary = _service.get_definition(achievement_id)
	return str(definition.get("title", achievement_id))


func _resource_name(key: String) -> String:
	return str(_resource_names.get(key, GameCatalog.resource_name(key)))


func _tag_name(tag: String) -> String:
	match tag:
		"recruit_camp":
			return "招募营"
	return tag


func _special_name(key: String) -> String:
	match key:
		"gold_shaft":
			return "金矿井"
		"mint":
			return "金币铸造厂"
	return key


func _civilization_name(key: String) -> String:
	match key:
		"elf":
			return "精灵"
		"dwarf":
			return "矮人"
		"orc":
			return "兽人"
	return key


func _target_name(key: String) -> String:
	match key:
		"neutral":
			return "中立单位"
		"player":
			return "敌方单位"
		"any":
			return "任意单位"
	return key


func _draw_dashed_line(from: Vector2, to: Vector2, color: Color, width: float, dash_len: float, gap_len: float) -> void:
	var delta: Vector2 = to - from
	var length: float = delta.length()
	if length <= 0.01:
		return
	var dir: Vector2 = delta / length
	var distance: float = 0.0
	while distance < length:
		var start: Vector2 = from + dir * distance
		var end_distance: float = minf(distance + dash_len, length)
		var end: Vector2 = from + dir * end_distance
		draw_line(start, end, color, width)
		distance += dash_len + gap_len


func _draw_text(pos: Vector2, text: String, font_size: int, color: Color) -> void:
	var font: Font = ThemeDB.fallback_font
	draw_string(font, pos, text, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size, color)


func _draw_centered_text(pos: Vector2, text: String, font_size: int, color: Color) -> void:
	var font: Font = ThemeDB.fallback_font
	var width: float = font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size).x
	draw_string(font, pos - Vector2(width * 0.5, 0.0), text, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size, color)
