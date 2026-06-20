extends Control

var _panel: PanelContainer
var _title_label: Label
var _target_label: Label
var _approach_label: Label
var _ap_label: Label
var _status_label: Label
var _reason_label: Label


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_build_ui()
	hide()


func _build_ui() -> void:
	_panel = PanelContainer.new()
	_panel.position = Vector2(1400, 52)
	_panel.size = Vector2(360, 150)
	_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_panel)

	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.055, 0.06, 0.065, 0.92)
	style.border_color = Color(0.32, 0.38, 0.42, 0.7)
	style.border_width_left = 1
	style.border_width_top = 1
	style.border_width_right = 1
	style.border_width_bottom = 1
	style.corner_radius_top_left = 6
	style.corner_radius_top_right = 6
	style.corner_radius_bottom_left = 6
	style.corner_radius_bottom_right = 6
	_panel.add_theme_stylebox_override("panel", style)

	var margin := MarginContainer.new()
	margin.mouse_filter = Control.MOUSE_FILTER_IGNORE
	margin.add_theme_constant_override("margin_left", 12)
	margin.add_theme_constant_override("margin_top", 10)
	margin.add_theme_constant_override("margin_right", 12)
	margin.add_theme_constant_override("margin_bottom", 10)
	_panel.add_child(margin)

	var box := VBoxContainer.new()
	box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	box.add_theme_constant_override("separation", 5)
	margin.add_child(box)

	_title_label = _make_label("行动预览", 16, Color(0.92, 0.96, 1.0))
	box.add_child(_title_label)
	_target_label = _make_label("", 14, Color.WHITE)
	box.add_child(_target_label)
	_approach_label = _make_label("", 14, Color(0.78, 0.84, 0.88))
	box.add_child(_approach_label)
	_ap_label = _make_label("", 14, Color(0.78, 0.84, 0.88))
	box.add_child(_ap_label)
	_status_label = _make_label("", 15, Color.WHITE)
	box.add_child(_status_label)
	_reason_label = _make_label("", 13, Color(0.72, 0.76, 0.78))
	_reason_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	box.add_child(_reason_label)


func _make_label(text: String, font_size: int, color: Color) -> Label:
	var label := Label.new()
	label.text = text
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	label.add_theme_font_size_override("font_size", font_size)
	label.add_theme_color_override("font_color", color)
	label.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0.75))
	label.add_theme_constant_override("shadow_offset_x", 1)
	label.add_theme_constant_override("shadow_offset_y", 1)
	return label


func show_preview(preview: Dictionary) -> void:
	if preview.is_empty():
		hide()
		return

	var target_pos: Vector2i = preview.get("target_pos", Vector2i(-1, -1))
	var approach_pos: Vector2i = preview.get("approach_pos", Vector2i(-1, -1))
	var can_attack: bool = bool(preview.get("can_attack", false))
	var ap_cost: int = int(preview.get("ap_cost", 0))

	_target_label.text = "目标：%s  (%d, %d)" % [
		str(preview.get("target_name", "")),
		target_pos.x,
		target_pos.y,
	]
	if approach_pos.x >= 0:
		_approach_label.text = "接敌格：(%d, %d)" % [approach_pos.x, approach_pos.y]
	else:
		_approach_label.text = "接敌格：无"
	_ap_label.text = "AP 消耗：%d" % ap_cost

	if can_attack:
		_status_label.text = "可以攻击"
		_status_label.add_theme_color_override("font_color", Color(0.45, 1.0, 0.55))
	else:
		_status_label.text = "不可攻击"
		_status_label.add_theme_color_override("font_color", Color(1.0, 0.42, 0.32))
	_reason_label.text = str(preview.get("reason", ""))
	show()
