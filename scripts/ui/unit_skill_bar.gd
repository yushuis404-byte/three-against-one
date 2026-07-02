extends Control

signal skill_requested(action_id: String, unit_id: int)

const BUTTON_SIZE: Vector2 = Vector2(180.0, 36.0)
const READY_COLOR: Color = Color(0.86, 1.0, 0.78, 1.0)
const DISABLED_COLOR: Color = Color(0.42, 0.42, 0.42, 0.78)
const ACTIVE_COLOR: Color = Color(0.78, 0.90, 1.0, 1.0)

var _list: HBoxContainer


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_PASS
	position = Vector2(4, 770)
	size = Vector2(690, 44)
	_build_ui()
	hide()


func _build_ui() -> void:
	_list = HBoxContainer.new()
	_list.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_list.add_theme_constant_override("separation", 8)
	_list.position = Vector2.ZERO
	_list.size = size
	add_child(_list)


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
	for child in _list.get_children():
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
	button.add_theme_font_size_override("font_size", 13)
	button.modulate = DISABLED_COLOR
	if enabled:
		button.modulate = ACTIVE_COLOR if active else READY_COLOR
	button.pressed.connect(_on_skill_pressed.bind(action_id, unit_id))
	_list.add_child(button)


func _format_button_text(label: String, status: String) -> String:
	if status.is_empty():
		return label
	return "%s (%s)" % [label, status]


func _on_skill_pressed(action_id: String, unit_id: int) -> void:
	skill_requested.emit(action_id, unit_id)
