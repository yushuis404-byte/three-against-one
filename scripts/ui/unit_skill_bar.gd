extends Control

signal skill_requested(action_id: String, unit_id: int)

const PANEL_SIZE: Vector2 = Vector2(236.0, 280.0)
const PANEL_POS: Vector2 = Vector2(1680.0, 795.0)
const BUTTON_SIZE: Vector2 = Vector2(212.0, 52.0)
const READY_COLOR: Color = Color(0.86, 1.0, 0.78, 1.0)
const DISABLED_COLOR: Color = Color(0.42, 0.42, 0.42, 0.78)
const ACTIVE_COLOR: Color = Color(0.78, 0.90, 1.0, 1.0)

var _panel: PanelContainer
var _list: VBoxContainer


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_PASS
	_build_ui()
	hide()


func _build_ui() -> void:
	_panel = PanelContainer.new()
	_panel.position = PANEL_POS
	_panel.size = PANEL_SIZE
	_panel.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(_panel)

	var style: StyleBoxFlat = StyleBoxFlat.new()
	style.bg_color = Color(0.045, 0.05, 0.055, 0.92)
	style.border_color = Color(0.42, 0.50, 0.58, 0.72)
	style.set_border_width_all(1)
	style.set_corner_radius_all(6)
	_panel.add_theme_stylebox_override("panel", style)

	var margin: MarginContainer = MarginContainer.new()
	margin.mouse_filter = Control.MOUSE_FILTER_IGNORE
	margin.add_theme_constant_override("margin_left", 10)
	margin.add_theme_constant_override("margin_top", 10)
	margin.add_theme_constant_override("margin_right", 10)
	margin.add_theme_constant_override("margin_bottom", 10)
	_panel.add_child(margin)

	_list = VBoxContainer.new()
	_list.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_list.add_theme_constant_override("separation", 7)
	margin.add_child(_list)

	var title: Label = Label.new()
	title.text = "技能"
	title.mouse_filter = Control.MOUSE_FILTER_IGNORE
	title.add_theme_font_size_override("font_size", 16)
	title.add_theme_color_override("font_color", Color(0.92, 0.96, 1.0))
	_list.add_child(title)


func show_skills(skills: Array) -> void:
	_clear_buttons()
	if skills.is_empty():
		hide()
		return
	for skill_variant in skills:
		var skill: Dictionary = skill_variant
		_add_skill_button(skill)
	show()


func clear_skills() -> void:
	_clear_buttons()
	hide()


func _clear_buttons() -> void:
	if _list == null:
		return
	var children: Array = _list.get_children()
	for i in range(children.size()):
		var child: Node = children[i]
		if child is Button:
			_list.remove_child(child)
			child.queue_free()


func _add_skill_button(skill: Dictionary) -> void:
	var action_id: String = str(skill.get("id", ""))
	if action_id.is_empty():
		return
	var unit_id: int = int(skill.get("unit_id", -1))
	var enabled: bool = bool(skill.get("enabled", false))
	var active: bool = bool(skill.get("active", false))
	var label: String = str(skill.get("label", action_id))
	var status: String = str(skill.get("status", ""))
	var reason: String = str(skill.get("reason", ""))
	var button: Button = Button.new()
	button.custom_minimum_size = BUTTON_SIZE
	button.focus_mode = Control.FOCUS_NONE
	button.disabled = not enabled
	button.text = _format_button_text(label, status)
	button.tooltip_text = reason
	button.modulate = DISABLED_COLOR
	if enabled:
		button.modulate = ACTIVE_COLOR if active else READY_COLOR
	button.pressed.connect(_on_skill_pressed.bind(action_id, unit_id))
	_list.add_child(button)


func _format_button_text(label: String, status: String) -> String:
	if status.is_empty():
		return label
	return "%s\n%s" % [label, status]


func _on_skill_pressed(action_id: String, unit_id: int) -> void:
	skill_requested.emit(action_id, unit_id)
