class_name GoblinHexPanel
extends Control

signal hex_selected(player: int, round_number: int, card: Dictionary)

const PANEL_W := 1080
const PANEL_H := 650
const CARD_W := 300
const CARD_H := 420
const CARD_GAP := 32

var _service: Node = null
var _current_player := -1
var _current_round := -1
var _bg: ColorRect = null
var _panel: Panel = null
var _title: Label = null
var _subtitle: Label = null
var _card_nodes: Array = []


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_STOP
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	z_index = 140
	_build_frame()
	hide()


func setup(service: Node) -> void:
	_service = service


func show_hex(player: int, round_number: int) -> void:
	if _service == null:
		return
	_current_player = player
	_current_round = round_number
	var rarity: String = str(_service.call("get_round_rarity", round_number))
	var rarity_name: String = _rarity_name(rarity)
	_title.text = "哥布林海克斯馈赠"
	_subtitle.text = "第 %d 回合 · 全局品质：%s · 免费三选一" % [round_number, rarity_name]
	_rebuild_cards()
	show()


func _build_frame() -> void:
	_bg = ColorRect.new()
	_bg.color = Color(0, 0, 0, 0.68)
	_bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_bg.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(_bg)

	_panel = Panel.new()
	_panel.size = Vector2(PANEL_W, PANEL_H)
	_panel.position = Vector2(
		(get_viewport_rect().size.x - PANEL_W) * 0.5,
		(get_viewport_rect().size.y - PANEL_H) * 0.5
	)
	_panel.mouse_filter = Control.MOUSE_FILTER_STOP
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.075, 0.075, 0.095, 0.98)
	style.border_color = Color(0.95, 0.72, 0.32, 0.75)
	style.border_width_left = 2
	style.border_width_right = 2
	style.border_width_top = 2
	style.border_width_bottom = 2
	style.corner_radius_top_left = 8
	style.corner_radius_top_right = 8
	style.corner_radius_bottom_left = 8
	style.corner_radius_bottom_right = 8
	_panel.add_theme_stylebox_override("panel", style)
	add_child(_panel)

	_title = Label.new()
	_title.position = Vector2(32, 22)
	_title.size = Vector2(PANEL_W - 64, 40)
	_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_title.clip_text = true
	_title.add_theme_font_size_override("font_size", 28)
	_title.add_theme_color_override("font_color", Color(1.0, 0.86, 0.42))
	_panel.add_child(_title)

	_subtitle = Label.new()
	_subtitle.position = Vector2(32, 62)
	_subtitle.size = Vector2(PANEL_W - 64, 28)
	_subtitle.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_subtitle.clip_text = true
	_subtitle.add_theme_font_size_override("font_size", 16)
	_subtitle.add_theme_color_override("font_color", Color(0.88, 0.90, 0.94))
	_panel.add_child(_subtitle)


func _rebuild_cards() -> void:
	for node_variant in _card_nodes:
		var node: Node = node_variant
		if is_instance_valid(node):
			node.queue_free()
	_card_nodes.clear()
	if _service == null:
		return
	var choices: Array = _service.call("get_choices", _current_player, _current_round)
	var refresh_used: Array = _service.call("get_refresh_used", _current_player, _current_round)
	var total_w := choices.size() * CARD_W + maxi(0, choices.size() - 1) * CARD_GAP
	var start_x := (PANEL_W - total_w) * 0.5
	for i in range(choices.size()):
		var card: Dictionary = choices[i]
		var used := false
		if i < refresh_used.size():
			used = bool(refresh_used[i])
		var card_node: Control = _build_card(card, i, used)
		card_node.position = Vector2(start_x + i * (CARD_W + CARD_GAP), 120)
		_panel.add_child(card_node)
		_card_nodes.append(card_node)


func _build_card(card: Dictionary, index: int, refresh_used: bool) -> Control:
	var rarity_color: Color = card.get("rarity_color", Color.WHITE)
	var card_panel := Panel.new()
	card_panel.size = Vector2(CARD_W, CARD_H)
	card_panel.mouse_filter = Control.MOUSE_FILTER_STOP
	card_panel.clip_contents = true
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.13, 0.13, 0.16, 0.98)
	style.border_color = rarity_color
	style.border_width_left = 3
	style.border_width_right = 3
	style.border_width_top = 3
	style.border_width_bottom = 3
	style.corner_radius_top_left = 8
	style.corner_radius_top_right = 8
	style.corner_radius_bottom_left = 8
	style.corner_radius_bottom_right = 8
	card_panel.add_theme_stylebox_override("panel", style)

	var rarity := Label.new()
	rarity.text = "%s · %s" % [str(card.get("rarity_name", "")), str(card.get("category_name", ""))]
	rarity.position = Vector2(36, 22)
	rarity.size = Vector2(CARD_W - 72, 24)
	rarity.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	rarity.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	rarity.clip_text = true
	rarity.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	rarity.add_theme_font_size_override("font_size", 14)
	rarity.add_theme_color_override("font_color", rarity_color)
	card_panel.add_child(rarity)

	var name := Label.new()
	name.text = str(card.get("name", ""))
	name.position = Vector2(38, 56)
	name.size = Vector2(CARD_W - 76, 58)
	name.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	name.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	name.autowrap_mode = TextServer.AUTOWRAP_ARBITRARY
	name.clip_text = true
	name.max_lines_visible = 2
	name.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	name.add_theme_font_size_override("font_size", 21)
	name.add_theme_color_override("font_color", Color.WHITE)
	card_panel.add_child(name)

	var desc := Label.new()
	desc.text = str(card.get("description", ""))
	desc.position = Vector2(42, 136)
	desc.size = Vector2(CARD_W - 84, 156)
	desc.autowrap_mode = TextServer.AUTOWRAP_ARBITRARY
	desc.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	desc.clip_text = true
	desc.max_lines_visible = 6
	desc.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	desc.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	desc.add_theme_font_size_override("font_size", 13)
	desc.add_theme_color_override("font_color", Color(0.90, 0.91, 0.94))
	card_panel.add_child(desc)

	var refresh_btn := Button.new()
	refresh_btn.text = "刷新 0/1" if refresh_used else "刷新 1/1"
	refresh_btn.disabled = refresh_used
	refresh_btn.position = Vector2(26, CARD_H - 92)
	refresh_btn.size = Vector2(112, 40)
	refresh_btn.focus_mode = Control.FOCUS_NONE
	refresh_btn.pressed.connect(_on_refresh_pressed.bind(index))
	card_panel.add_child(refresh_btn)

	var select_btn := Button.new()
	select_btn.text = "选择"
	select_btn.position = Vector2(CARD_W - 138, CARD_H - 92)
	select_btn.size = Vector2(112, 40)
	select_btn.focus_mode = Control.FOCUS_NONE
	select_btn.pressed.connect(_on_select_pressed.bind(index))
	card_panel.add_child(select_btn)
	return card_panel


func _on_refresh_pressed(index: int) -> void:
	if _service == null:
		return
	var ok: bool = bool(_service.call("refresh_choice", _current_player, _current_round, index))
	if ok:
		_rebuild_cards()


func _on_select_pressed(index: int) -> void:
	if _service == null:
		return
	var card: Dictionary = _service.call("select_choice", _current_player, _current_round, index)
	if card.is_empty():
		return
	hide()
	hex_selected.emit(_current_player, _current_round, card)
	_current_player = -1
	_current_round = -1


func _rarity_name(rarity: String) -> String:
	return str(GoblinHexCardLibrary.RARITY_NAMES.get(rarity, rarity))
