extends Control
## Recruit panel for buildings with recruit options.

signal recruit_requested(building_id: int, unit_template_id: String, count: int)

var _building_id := -1
var _options: Array = []
var _queue: Array = []
var _selected_unit_id := ""
var _count := 1

var _panel: Panel
var _title: Label
var _options_box: VBoxContainer
var _count_label: Label
var _summary_label: Label
var _queue_label: Label


func _ready() -> void:
	_build_ui()
	hide_panel()


func _build_ui() -> void:
	mouse_filter = Control.MOUSE_FILTER_PASS
	set_anchors_preset(Control.PRESET_FULL_RECT)

	_panel = Panel.new()
	_panel.offset_left = 16
	_panel.offset_top = 720
	_panel.offset_right = 430
	_panel.offset_bottom = 1050
	_panel.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(_panel)

	var margin := MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 10)
	margin.add_theme_constant_override("margin_right", 10)
	margin.add_theme_constant_override("margin_top", 10)
	margin.add_theme_constant_override("margin_bottom", 10)
	_panel.add_child(margin)

	var root := VBoxContainer.new()
	root.add_theme_constant_override("separation", 7)
	margin.add_child(root)

	_title = Label.new()
	_title.text = "招募"
	_title.add_theme_font_size_override("font_size", 17)
	root.add_child(_title)

	_options_box = VBoxContainer.new()
	_options_box.add_theme_constant_override("separation", 4)
	root.add_child(_options_box)

	var count_row := HBoxContainer.new()
	count_row.add_theme_constant_override("separation", 8)
	root.add_child(count_row)

	var minus_btn := Button.new()
	minus_btn.text = "-"
	minus_btn.custom_minimum_size = Vector2(38, 30)
	minus_btn.pressed.connect(_change_count.bind(-1))
	count_row.add_child(minus_btn)

	_count_label = Label.new()
	_count_label.custom_minimum_size = Vector2(90, 30)
	_count_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_count_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	count_row.add_child(_count_label)

	var plus_btn := Button.new()
	plus_btn.text = "+"
	plus_btn.custom_minimum_size = Vector2(38, 30)
	plus_btn.pressed.connect(_change_count.bind(1))
	count_row.add_child(plus_btn)

	var recruit_btn := Button.new()
	recruit_btn.text = "加入队列"
	recruit_btn.custom_minimum_size = Vector2(110, 30)
	recruit_btn.pressed.connect(_request_recruitment)
	count_row.add_child(recruit_btn)

	_summary_label = Label.new()
	_summary_label.add_theme_font_size_override("font_size", 12)
	root.add_child(_summary_label)

	var sep := HSeparator.new()
	root.add_child(sep)

	_queue_label = Label.new()
	_queue_label.add_theme_font_size_override("font_size", 12)
	_queue_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	root.add_child(_queue_label)


func show_panel(building_id: int, building_name: String, options: Array, queue: Array) -> void:
	_building_id = building_id
	_options = options.duplicate(true)
	_queue = queue.duplicate(true)
	_count = 1
	if _selected_unit_id.is_empty() or not _has_option(_selected_unit_id):
		_selected_unit_id = str(_options[0]["id"]) if not _options.is_empty() else ""
	_title.text = "%s 招募" % building_name
	visible = true
	_panel.visible = true
	_rebuild_options()
	_refresh()


func hide_panel() -> void:
	visible = false
	if _panel:
		_panel.visible = false


func update_queue(building_id: int, queue: Array) -> void:
	if building_id != _building_id:
		return
	_queue = queue.duplicate(true)
	_refresh()


func _rebuild_options() -> void:
	for child in _options_box.get_children():
		child.queue_free()

	for option in _options:
		var unit_id: String = str(option["id"])
		var btn := Button.new()
		btn.text = _format_option(option)
		btn.toggle_mode = true
		btn.button_pressed = unit_id == _selected_unit_id
		btn.pressed.connect(_select_option.bind(unit_id))
		_options_box.add_child(btn)


func _format_option(option: Dictionary) -> String:
	var name: String = str(option.get("name", "单位"))
	var cost_text: String = _format_cost(option.get("cost", {}))
	var ap_cost: int = int(option.get("ap_cost", 0))
	var turns: int = int(option.get("turns", 1))
	return "%s  |  %s  AP %d  %d回合" % [name, cost_text, ap_cost, turns]


func _select_option(unit_id: String) -> void:
	_selected_unit_id = unit_id
	_rebuild_options()
	_refresh()


func _change_count(delta: int) -> void:
	_count = clampi(_count + delta, 1, 3)
	_refresh()


func _request_recruitment() -> void:
	if _building_id < 0 or _selected_unit_id.is_empty():
		return
	recruit_requested.emit(_building_id, _selected_unit_id, _count)


func _refresh() -> void:
	_count_label.text = "数量 %d" % _count
	var option: Dictionary = _get_selected_option()
	if option.is_empty():
		_summary_label.text = "没有可招募单位"
	else:
		var total_cost := _scale_cost(option.get("cost", {}), _count)
		var total_ap: int = int(option.get("ap_cost", 0)) * _count
		_summary_label.text = "总成本: %s | AP %d | 队列容量 3" % [_format_cost(total_cost), total_ap]
	_queue_label.text = _format_queue()


func _format_queue() -> String:
	if _queue.is_empty():
		return "当前队列: 空"
	var lines: PackedStringArray = ["当前队列:"]
	for item in _queue:
		var name: String = str(item.get("unit_name", item.get("unit_template_id", "单位")))
		var remaining: int = int(item.get("remaining_turns", 0))
		var total: int = int(item.get("total_turns", 1))
		if remaining <= 0:
			lines.append("- %s 完成，等待空位" % name)
		else:
			lines.append("- %s 剩余 %d/%d 回合" % [name, remaining, total])
	return "\n".join(lines)


func _format_cost(cost: Dictionary) -> String:
	if cost.is_empty():
		return "免费"
	var parts: PackedStringArray = []
	for key in cost:
		var name: String = GameCatalog.resource_name(key)
		parts.append("%s %d" % [name, int(cost[key])])
	return " ".join(parts)


func _scale_cost(cost: Dictionary, multiplier: int) -> Dictionary:
	var result: Dictionary = {}
	for key in cost:
		result[key] = int(cost[key]) * multiplier
	return result


func _get_selected_option() -> Dictionary:
	for option in _options:
		if str(option.get("id", "")) == _selected_unit_id:
			return option
	return {}


func _has_option(unit_id: String) -> bool:
	for option in _options:
		if str(option.get("id", "")) == unit_id:
			return true
	return false
