class_name DragonPortalConfirmPanel
extends Control

signal confirmed(payload: Dictionary)
signal canceled()

var _panel: Panel = null
var _title_label: Label = null
var _body_label: Label = null
var _confirm_button: Button = null
var _cancel_button: Button = null
var _payload: Dictionary = {}


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_STOP
	set_anchors_preset(Control.PRESET_FULL_RECT)
	_build_ui()
	hide()


func show_request(title: String, body: String, payload: Dictionary, allow_confirm: bool = true) -> void:
	_payload = payload.duplicate(true)
	_title_label.text = title
	_body_label.text = body
	_confirm_button.visible = allow_confirm
	_confirm_button.disabled = not allow_confirm
	_cancel_button.text = "取消"
	if not allow_confirm:
		_cancel_button.text = "确定"
	show()
	move_to_front()


func _build_ui() -> void:
	var shade := ColorRect.new()
	shade.name = "Shade"
	shade.color = Color(0.0, 0.0, 0.0, 0.46)
	shade.mouse_filter = Control.MOUSE_FILTER_STOP
	shade.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(shade)

	_panel = Panel.new()
	_panel.name = "Panel"
	_panel.position = Vector2(710.0, 350.0)
	_panel.size = Vector2(500.0, 250.0)
	_panel.mouse_filter = Control.MOUSE_FILTER_STOP
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.055, 0.065, 0.085, 0.98)
	style.border_color = Color(0.42, 0.76, 1.0, 0.62)
	style.border_width_left = 1
	style.border_width_top = 1
	style.border_width_right = 1
	style.border_width_bottom = 1
	style.corner_radius_top_left = 8
	style.corner_radius_top_right = 8
	style.corner_radius_bottom_left = 8
	style.corner_radius_bottom_right = 8
	_panel.add_theme_stylebox_override("panel", style)
	add_child(_panel)

	_title_label = Label.new()
	_title_label.position = Vector2(22.0, 20.0)
	_title_label.size = Vector2(456.0, 32.0)
	_title_label.add_theme_font_size_override("font_size", 18)
	_title_label.add_theme_color_override("font_color", Color(0.92, 0.97, 1.0))
	_panel.add_child(_title_label)

	_body_label = Label.new()
	_body_label.position = Vector2(22.0, 64.0)
	_body_label.size = Vector2(456.0, 108.0)
	_body_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_body_label.add_theme_font_size_override("font_size", 14)
	_body_label.add_theme_color_override("font_color", Color(0.76, 0.84, 0.92))
	_panel.add_child(_body_label)

	_confirm_button = Button.new()
	_confirm_button.position = Vector2(240.0, 194.0)
	_confirm_button.size = Vector2(104.0, 36.0)
	_confirm_button.text = "确定"
	_confirm_button.focus_mode = Control.FOCUS_NONE
	_confirm_button.pressed.connect(_on_confirm_pressed)
	_panel.add_child(_confirm_button)

	_cancel_button = Button.new()
	_cancel_button.position = Vector2(362.0, 194.0)
	_cancel_button.size = Vector2(104.0, 36.0)
	_cancel_button.text = "取消"
	_cancel_button.focus_mode = Control.FOCUS_NONE
	_cancel_button.pressed.connect(_on_cancel_pressed)
	_panel.add_child(_cancel_button)


func _on_confirm_pressed() -> void:
	var payload := _payload.duplicate(true)
	hide()
	confirmed.emit(payload)


func _on_cancel_pressed() -> void:
	hide()
	canceled.emit()
