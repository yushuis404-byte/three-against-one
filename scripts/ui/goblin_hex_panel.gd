class_name GoblinHexPanel
extends Control

signal hex_selected(player: int, round_number: int, card: Dictionary)

const PANEL_W := 1080
const PANEL_H := 650
const CARD_W := 300
const CARD_H := 420
const CARD_GAP := 32
const CARD_BG_TEXTURE: Texture2D = preload("res://assets/texture/商品卡底图.png")
const BG_TEXTURE: Texture2D = preload("res://assets/texture/背景版图.png")

var _service: Node = null
var _current_player := -1
var _current_round := -1
var _bg: TextureRect = null
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
	_bg = TextureRect.new()
	_bg.texture = BG_TEXTURE
	_bg.size = Vector2(PANEL_W * 1.2, PANEL_H * 1.2)
	_bg.position = Vector2(
		(get_viewport_rect().size.x - _bg.size.x) * 0.5,
		(get_viewport_rect().size.y - _bg.size.y) * 0.5 - 40.0
	)
	_bg.mouse_filter = Control.MOUSE_FILTER_STOP
	_bg.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	add_child(_bg)

	_panel = Panel.new()
	_panel.size = Vector2(PANEL_W, PANEL_H)
	_panel.position = Vector2(
		(get_viewport_rect().size.x - PANEL_W) * 0.5,
		(get_viewport_rect().size.y - PANEL_H) * 0.5
	)
	_panel.mouse_filter = Control.MOUSE_FILTER_STOP
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0, 0, 0, 0)
	style.border_color = Color(0, 0, 0, 0)
	style.border_width_left = 0
	style.border_width_right = 0
	style.border_width_top = 0
	style.border_width_bottom = 0
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
	var card_panel := TextureRect.new()
	card_panel.texture = CARD_BG_TEXTURE
	card_panel.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	card_panel.size = Vector2(CARD_W, CARD_H)
	card_panel.mouse_filter = Control.MOUSE_FILTER_STOP
	card_panel.clip_contents = true

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
	desc.position = Vector2(50, 130)
	desc.size = Vector2(CARD_W - 100, 170)
	desc.horizontal_alignment = HORIZONTAL_ALIGNMENT_FILL
	desc.autowrap_mode = TextServer.AUTOWRAP_ARBITRARY
	desc.clip_text = true
	desc.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	desc.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	desc.add_theme_font_size_override("font_size", 13)
	desc.add_theme_color_override("font_color", Color(0.90, 0.91, 0.94))
	card_panel.add_child(desc)
	# Hover highlight
	var hover_rect := ColorRect.new()
	hover_rect.color = Color(1, 1, 1, 0.1)
	hover_rect.size = Vector2(CARD_W, CARD_H)
	hover_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	hover_rect.visible = false
	card_panel.add_child(hover_rect)
	card_panel.mouse_entered.connect(func(): hover_rect.visible = true)
	card_panel.mouse_exited.connect(func(): hover_rect.visible = false)
	
	# Click card to select
	card_panel.gui_input.connect(func(event: InputEvent):
		if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
			_on_select_pressed(index)
	)
	
	# Refresh button (centered)
	var refresh_btn := Button.new()
	refresh_btn.text = "刷新 0/1" if refresh_used else "刷新 1/1"
	refresh_btn.disabled = refresh_used
	refresh_btn.position = Vector2((CARD_W - 112) / 2, CARD_H - 92)
	refresh_btn.size = Vector2(112, 40)
	refresh_btn.focus_mode = Control.FOCUS_NONE
	refresh_btn.pressed.connect(_on_refresh_pressed.bind(index))
	card_panel.add_child(refresh_btn)
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
