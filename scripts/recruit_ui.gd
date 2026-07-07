extends Control
## Center modal recruitment panel for recruit-capable buildings.

signal recruit_requested(building_id: int, unit_template_id: String, count: int)

const QUEUE_CAPACITY := 3

const RECRUIT_ICON_PATHS := {
	"worker": "res://assets/ui/recruit_icons/pickaxe.svg",
	"scout": "res://assets/ui/recruit_icons/binoculars.svg",
	"melee": "res://assets/ui/recruit_icons/sword.svg",
	"tank": "res://assets/ui/recruit_icons/shield.svg",
	"ranged": "res://assets/ui/recruit_icons/bow.svg",
}

const UNIT_PORTRAITS := {
	"unit.elf.worker": {"path": "res://assets/texture/character/elf/Worker/Elf-Worker-Idle.png", "frame_size": Vector2(320.0, 320.0)},
	"unit.elf.scout": {"path": "res://assets/texture/character/elf/Scout/Elf-Scout-Idle.png", "frame_size": Vector2(320.0, 320.0)},
	"unit.elf.guard": {"path": "res://assets/texture/character/elf/Moonshadow Assassin/Elf-Assassin-Idle.png", "frame_size": Vector2(320.0, 320.0)},
	"unit.elf.ranger": {"path": "res://assets/texture/character/elf/Ranger/Elf-Ranger-Idle.png", "frame_size": Vector2(320.0, 320.0)},
	"unit.elf.blade_dancer": {"path": "res://assets/texture/character/elf/Moonshadow Assassin/Elf-Assassin-Idle.png", "frame_size": Vector2(320.0, 320.0)},
	"unit.elf.root_guard": {"path": "res://assets/texture/character/elf/Ranger/Elf-Ranger-Idle.png", "frame_size": Vector2(320.0, 320.0)},
	"unit.dwarf.worker": {"path": "res://assets/texture/character/dwarf/Worker/Dwarf-Worker-Idle.png", "frame_size": Vector2(320.0, 320.0)},
	"unit.dwarf.scout": {"path": "res://assets/texture/character/dwarf/Prospector/Dwarf-Prospector-Idle.png", "frame_size": Vector2(320.0, 320.0)},
	"unit.dwarf.guard": {"path": "res://assets/texture/character/dwarf/Hammer Guard/Dwarf-Hammer-Guard-Idle.png", "frame_size": Vector2(320.0, 320.0)},
	"unit.dwarf.shieldbearer": {"path": "res://assets/texture/character/dwarf/Worker/Dwarf-Worker-Idle.png", "frame_size": Vector2(320.0, 320.0)},
	"unit.dwarf.crossbow": {"path": "res://assets/texture/character/dwarf/Mountain Crossbow/Dwarf-Mountain-Crossbow-Idle.png", "frame_size": Vector2(320.0, 320.0)},
	"unit.dwarf.sapper": {"path": "res://assets/texture/character/dwarf/Worker/Dwarf-Worker-Idle.png", "frame_size": Vector2(320.0, 320.0)},
	"unit.orc.worker": {"path": "res://assets/texture/character/orc/Worker/Orc-Worker-Idle.png", "frame_size": Vector2(320.0, 320.0)},
	"unit.orc.scout": {"path": "res://assets/texture/character/Hunter-Beast/Hunter-tooth Beast.png", "frame_size": Vector2(629.0 / 6.0, 55.0)},
	"unit.orc.guard": {"path": "res://assets/texture/character/orc/Blood Axe Warrior/Orc-Idle.png", "frame_size": Vector2(320.0, 320.0)},
	"unit.orc.mob": {"path": "res://assets/texture/character/orc/Blood Axe Warrior/Orc-Idle.png", "frame_size": Vector2(320.0, 320.0)},
	"unit.orc.bone_shield": {"path": "res://assets/texture/character/orc/Blood Axe Warrior/Orc-Idle.png", "frame_size": Vector2(320.0, 320.0)},
	"unit.orc.hide_tower": {"path": "res://assets/texture/character/orc/Orc-Slinger-Idle.png", "frame_size": Vector2(252.0, 255.0)},
	"unit.orc.slinger": {"path": "res://assets/texture/character/orc/Orc-Slinger-Idle.png", "frame_size": Vector2(252.0, 255.0)},
	"unit.worker": {"path": "res://assets/texture/character/elf/Worker/Elf-Worker-Idle.png", "frame_size": Vector2(320.0, 320.0)},
	"unit.scout": {"path": "res://assets/texture/character/elf/Scout/Elf-Scout-Idle.png", "frame_size": Vector2(320.0, 320.0)},
	"unit.guard": {"path": "res://assets/texture/character/orc/Blood Axe Warrior/Orc-Idle.png", "frame_size": Vector2(320.0, 320.0)},
}

var _building_id := -1
var _building_name := ""
var _options: Array = []
var _queue: Array = []
var _selected_unit_id := ""
var _counts: Dictionary = {}

var _overlay: ColorRect
var _panel: Panel
var _title: Label
var _recruit_page: HBoxContainer
var _options_box: VBoxContainer
var _detail_name: Label
var _detail_portrait: TextureRect
var _detail_stats: Label
var _detail_cost: Label
var _detail_actions: Label
var _detail_count: Label
var _submit_btn: Button
var _queue_box: VBoxContainer


func _ready() -> void:
	_build_ui()
	hide_panel()


func _notification(what: int) -> void:
	if what == NOTIFICATION_RESIZED and _panel != null:
		_layout_panel()


func _build_ui() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE

	_overlay = ColorRect.new()
	_overlay.set_anchors_preset(Control.PRESET_FULL_RECT)
	_overlay.color = Color(0.0, 0.0, 0.0, 0.42)
	_overlay.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(_overlay)

	_panel = Panel.new()
	_panel.mouse_filter = Control.MOUSE_FILTER_STOP
	_panel.add_theme_stylebox_override("panel", _make_style(Color(0.055, 0.07, 0.075, 0.96), Color(0.56, 0.46, 0.25, 0.92), 2.0, 8.0))
	add_child(_panel)

	var margin := MarginContainer.new()
	margin.set_anchors_preset(Control.PRESET_FULL_RECT)
	margin.add_theme_constant_override("margin_left", 18)
	margin.add_theme_constant_override("margin_right", 18)
	margin.add_theme_constant_override("margin_top", 14)
	margin.add_theme_constant_override("margin_bottom", 16)
	_panel.add_child(margin)

	var root := VBoxContainer.new()
	root.add_theme_constant_override("separation", 12)
	root.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	root.size_flags_vertical = Control.SIZE_EXPAND_FILL
	margin.add_child(root)

	var header := HBoxContainer.new()
	header.add_theme_constant_override("separation", 10)
	root.add_child(header)

	_title = Label.new()
	_title.text = "招募营"
	_title.add_theme_font_size_override("font_size", 22)
	_title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	header.add_child(_title)

	var close_btn := Button.new()
	close_btn.text = "×"
	close_btn.custom_minimum_size = Vector2(38, 34)
	close_btn.focus_mode = Control.FOCUS_NONE
	close_btn.pressed.connect(hide_panel)
	header.add_child(close_btn)

	_recruit_page = HBoxContainer.new()
	_recruit_page.add_theme_constant_override("separation", 14)
	_recruit_page.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_recruit_page.size_flags_vertical = Control.SIZE_EXPAND_FILL
	root.add_child(_recruit_page)

	_build_recruit_page()
	_layout_panel()


func _build_recruit_page() -> void:
	var left_panel := PanelContainer.new()
	left_panel.custom_minimum_size = Vector2(520, 0)
	left_panel.size_flags_vertical = Control.SIZE_EXPAND_FILL
	left_panel.add_theme_stylebox_override("panel", _make_style(Color(0.09, 0.105, 0.11, 0.92), Color(0.23, 0.25, 0.25, 1.0), 1.0, 6.0))
	_recruit_page.add_child(left_panel)

	var left_margin := MarginContainer.new()
	left_margin.add_theme_constant_override("margin_left", 10)
	left_margin.add_theme_constant_override("margin_right", 10)
	left_margin.add_theme_constant_override("margin_top", 10)
	left_margin.add_theme_constant_override("margin_bottom", 10)
	left_panel.add_child(left_margin)

	var left_root := VBoxContainer.new()
	left_root.add_theme_constant_override("separation", 8)
	left_margin.add_child(left_root)

	var left_title := Label.new()
	left_title.text = "可招募兵种"
	left_title.add_theme_font_size_override("font_size", 16)
	left_root.add_child(left_title)

	var scroll := ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	left_root.add_child(scroll)

	_options_box = VBoxContainer.new()
	_options_box.add_theme_constant_override("separation", 8)
	_options_box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(_options_box)

	var detail_panel := PanelContainer.new()
	detail_panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	detail_panel.size_flags_vertical = Control.SIZE_EXPAND_FILL
	detail_panel.add_theme_stylebox_override("panel", _make_style(Color(0.085, 0.09, 0.095, 0.94), Color(0.23, 0.25, 0.25, 1.0), 1.0, 6.0))
	_recruit_page.add_child(detail_panel)

	var detail_margin := MarginContainer.new()
	detail_margin.add_theme_constant_override("margin_left", 18)
	detail_margin.add_theme_constant_override("margin_right", 18)
	detail_margin.add_theme_constant_override("margin_top", 16)
	detail_margin.add_theme_constant_override("margin_bottom", 16)
	detail_panel.add_child(detail_margin)

	var detail_root := VBoxContainer.new()
	detail_root.add_theme_constant_override("separation", 12)
	detail_root.size_flags_vertical = Control.SIZE_EXPAND_FILL
	detail_margin.add_child(detail_root)

	_detail_name = Label.new()
	_detail_name.add_theme_font_size_override("font_size", 24)
	detail_root.add_child(_detail_name)

	_detail_portrait = TextureRect.new()
	_detail_portrait.custom_minimum_size = Vector2(210, 170)
	_detail_portrait.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_detail_portrait.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	detail_root.add_child(_detail_portrait)

	_detail_stats = Label.new()
	_detail_stats.add_theme_font_size_override("font_size", 15)
	_detail_stats.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	detail_root.add_child(_detail_stats)

	_detail_cost = Label.new()
	_detail_cost.add_theme_font_size_override("font_size", 15)
	_detail_cost.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	detail_root.add_child(_detail_cost)

	_detail_actions = Label.new()
	_detail_actions.add_theme_font_size_override("font_size", 15)
	_detail_actions.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_detail_actions.custom_minimum_size = Vector2(0, 48)
	detail_root.add_child(_detail_actions)

	var footer := HBoxContainer.new()
	footer.add_theme_constant_override("separation", 10)
	detail_root.add_child(footer)

	_detail_count = Label.new()
	_detail_count.custom_minimum_size = Vector2(120, 38)
	_detail_count.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	footer.add_child(_detail_count)

	_submit_btn = Button.new()
	_submit_btn.text = "加入队列"
	_submit_btn.custom_minimum_size = Vector2(150, 38)
	_submit_btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_submit_btn.pressed.connect(_request_recruitment)
	footer.add_child(_submit_btn)

	_build_queue_panel(detail_root)


func _build_queue_panel(root: VBoxContainer) -> void:
	var queue_panel := PanelContainer.new()
	queue_panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	queue_panel.size_flags_vertical = Control.SIZE_EXPAND_FILL
	queue_panel.add_theme_stylebox_override("panel", _make_style(Color(0.07, 0.08, 0.085, 0.94), Color(0.22, 0.22, 0.20, 1.0), 1.0, 6.0))
	root.add_child(queue_panel)

	var queue_margin := MarginContainer.new()
	queue_margin.add_theme_constant_override("margin_left", 10)
	queue_margin.add_theme_constant_override("margin_right", 10)
	queue_margin.add_theme_constant_override("margin_top", 8)
	queue_margin.add_theme_constant_override("margin_bottom", 8)
	queue_panel.add_child(queue_margin)

	var queue_root := VBoxContainer.new()
	queue_root.add_theme_constant_override("separation", 8)
	queue_margin.add_child(queue_root)

	var queue_title := Label.new()
	queue_title.text = "当前招募队列"
	queue_title.add_theme_font_size_override("font_size", 15)
	queue_root.add_child(queue_title)

	var scroll := ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	queue_root.add_child(scroll)

	_queue_box = VBoxContainer.new()
	_queue_box.add_theme_constant_override("separation", 6)
	_queue_box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(_queue_box)


func show_panel(building_id: int, building_name: String, options: Array, queue: Array) -> void:
	_building_id = building_id
	_building_name = building_name
	_options = options.duplicate(true)
	_queue = queue.duplicate(true)
	_ensure_counts()
	if _selected_unit_id.is_empty() or not _has_option(_selected_unit_id):
		_selected_unit_id = str(_options[0].get("id", "")) if not _options.is_empty() else ""
	_title.text = "%s · 招募" % _building_name
	visible = true
	mouse_filter = Control.MOUSE_FILTER_STOP
	_overlay.visible = true
	_panel.visible = true
	_layout_panel()
	_refresh()


func hide_panel() -> void:
	visible = false
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	if _overlay != null:
		_overlay.visible = false
	if _panel != null:
		_panel.visible = false


func update_queue(building_id: int, queue: Array) -> void:
	if building_id != _building_id:
		return
	_queue = queue.duplicate(true)
	_ensure_counts()
	_refresh()


func _layout_panel() -> void:
	if _panel == null:
		return
	var viewport_size: Vector2 = get_viewport_rect().size
	if viewport_size.x <= 0.0 or viewport_size.y <= 0.0:
		viewport_size = Vector2(1920.0, 1080.0)
	var panel_w: float = minf(viewport_size.x * 0.6667, viewport_size.y * 0.90 * 4.0 / 3.0)
	var panel_h: float = panel_w * 0.75
	_panel.size = Vector2(panel_w, panel_h)
	_panel.position = (viewport_size - _panel.size) * 0.5


func _refresh() -> void:
	_recruit_page.visible = true
	_rebuild_options()
	_rebuild_queue()
	_update_detail()


func _ensure_counts() -> void:
	var max_count: int = maxi(1, _get_available_queue_slots())
	for option in _options:
		var unit_id: String = str(option.get("id", ""))
		if unit_id.is_empty():
			continue
		if not _counts.has(unit_id):
			_counts[unit_id] = 1
		_counts[unit_id] = clampi(int(_counts[unit_id]), 1, max_count)


func _rebuild_options() -> void:
	for child in _options_box.get_children():
		child.queue_free()

	for option_variant in _options:
		var option: Dictionary = option_variant
		var row := _make_option_row(option)
		_options_box.add_child(row)


func _make_option_row(option: Dictionary) -> PanelContainer:
	var unit_id: String = str(option.get("id", ""))
	var selected: bool = unit_id == _selected_unit_id
	var row := PanelContainer.new()
	row.mouse_filter = Control.MOUSE_FILTER_STOP
	row.custom_minimum_size = Vector2(0, 58)
	var bg_color := Color(0.16, 0.20, 0.22, 0.95) if selected else Color(0.105, 0.12, 0.13, 0.92)
	var border_color := Color(0.72, 0.58, 0.28, 1.0) if selected else Color(0.22, 0.24, 0.25, 1.0)
	row.add_theme_stylebox_override("panel", _make_style(bg_color, border_color, 1.4 if selected else 1.0, 6.0))
	row.gui_input.connect(_on_option_row_gui_input.bind(unit_id))

	var margin := MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 10)
	margin.add_theme_constant_override("margin_right", 8)
	margin.add_theme_constant_override("margin_top", 6)
	margin.add_theme_constant_override("margin_bottom", 6)
	row.add_child(margin)

	var hbox := HBoxContainer.new()
	hbox.add_theme_constant_override("separation", 8)
	margin.add_child(hbox)

	var marker := TextureRect.new()
	marker.texture = _get_unit_marker_icon(option)
	marker.custom_minimum_size = Vector2(34, 34)
	marker.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	marker.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	hbox.add_child(marker)

	var info_box := VBoxContainer.new()
	info_box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	info_box.add_theme_constant_override("separation", 2)
	hbox.add_child(info_box)

	var name_label := Label.new()
	name_label.text = str(option.get("name", "单位"))
	name_label.add_theme_font_size_override("font_size", 15)
	info_box.add_child(name_label)

	var meta_label := Label.new()
	meta_label.text = "%s | AP %d | %d回合" % [_format_cost(option.get("cost", {})), int(option.get("ap_cost", 0)), int(option.get("turns", 1))]
	meta_label.add_theme_font_size_override("font_size", 12)
	meta_label.add_theme_color_override("font_color", Color(0.78, 0.78, 0.72, 1.0))
	info_box.add_child(meta_label)

	var minus_btn := Button.new()
	minus_btn.text = "-"
	minus_btn.custom_minimum_size = Vector2(34, 34)
	minus_btn.focus_mode = Control.FOCUS_NONE
	minus_btn.pressed.connect(_change_option_count.bind(unit_id, -1))
	hbox.add_child(minus_btn)

	var count_label := Label.new()
	count_label.text = str(_get_option_count(unit_id))
	count_label.custom_minimum_size = Vector2(30, 34)
	count_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	count_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	hbox.add_child(count_label)

	var plus_btn := Button.new()
	plus_btn.text = "+"
	plus_btn.custom_minimum_size = Vector2(34, 34)
	plus_btn.focus_mode = Control.FOCUS_NONE
	plus_btn.pressed.connect(_change_option_count.bind(unit_id, 1))
	hbox.add_child(plus_btn)
	return row


func _on_option_row_gui_input(event: InputEvent, unit_id: String) -> void:
	if event is InputEventMouseButton:
		var mouse_event: InputEventMouseButton = event
		if mouse_event.button_index == MOUSE_BUTTON_LEFT and mouse_event.pressed:
			_selected_unit_id = unit_id
			_refresh()


func _change_option_count(unit_id: String, delta: int) -> void:
	_selected_unit_id = unit_id
	var max_count: int = maxi(1, _get_available_queue_slots())
	_counts[unit_id] = clampi(_get_option_count(unit_id) + delta, 1, max_count)
	_refresh()


func _request_recruitment() -> void:
	if _building_id < 0 or _selected_unit_id.is_empty():
		return
	var count: int = _get_option_count(_selected_unit_id)
	recruit_requested.emit(_building_id, _selected_unit_id, count)


func _update_detail() -> void:
	var option: Dictionary = _get_selected_option()
	if option.is_empty():
		_detail_name.text = "没有可招募单位"
		_detail_portrait.texture = null
		_detail_stats.text = ""
		_detail_cost.text = ""
		_detail_actions.text = ""
		_detail_count.text = ""
		_submit_btn.disabled = true
		return

	var unit_id: String = str(option.get("id", ""))
	var count: int = _get_option_count(unit_id)
	var total_cost: Dictionary = _scale_cost(option.get("cost", {}), count)
	var total_ap: int = int(option.get("ap_cost", 0)) * count
	_detail_name.text = str(option.get("name", "单位"))
	_detail_portrait.texture = _make_portrait_texture(unit_id)
	_detail_stats.text = "生命 %d   攻击 %d   移动 %d   视野 %d   射程 %d   攻速 %.1fs   减伤 %d" % [
		int(option.get("hp", 1)),
		int(option.get("atk", 0)),
		int(option.get("move", 0)),
		int(option.get("vision", 0)),
		int(option.get("attack_range", 1)),
		float(option.get("attack_interval", 1.0)),
		int(option.get("damage_reduction", 0)),
	]
	_detail_cost.text = "单个：%s，AP %d，%d回合。当前数量 %d，总成本：%s，AP %d。" % [
		_format_cost(option.get("cost", {})),
		int(option.get("ap_cost", 0)),
		int(option.get("turns", 1)),
		count,
		_format_cost(total_cost),
		total_ap,
	]
	_detail_actions.text = "用途：%s" % _format_unit_actions(option)
	_detail_count.text = "数量 %d/%d" % [count, maxi(1, _get_available_queue_slots())]
	_submit_btn.disabled = _get_available_queue_slots() <= 0


func _rebuild_queue() -> void:
	for child in _queue_box.get_children():
		child.queue_free()
	if _queue.is_empty():
		var empty := Label.new()
		empty.text = "当前没有招募队列。"
		empty.add_theme_font_size_override("font_size", 16)
		_queue_box.add_child(empty)
		return
	for item_variant in _queue:
		var item: Dictionary = item_variant
		_queue_box.add_child(_make_queue_row(item))


func _make_queue_row(item: Dictionary) -> PanelContainer:
	var row := PanelContainer.new()
	row.custom_minimum_size = Vector2(0, 50)
	row.add_theme_stylebox_override("panel", _make_style(Color(0.105, 0.12, 0.13, 0.94), Color(0.24, 0.25, 0.24, 1.0), 1.0, 6.0))

	var margin := MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 12)
	margin.add_theme_constant_override("margin_right", 12)
	margin.add_theme_constant_override("margin_top", 8)
	margin.add_theme_constant_override("margin_bottom", 8)
	row.add_child(margin)

	var hbox := HBoxContainer.new()
	hbox.add_theme_constant_override("separation", 12)
	margin.add_child(hbox)

	var name := Label.new()
	name.text = str(item.get("unit_name", item.get("unit_template_id", "单位")))
	name.add_theme_font_size_override("font_size", 14)
	name.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	hbox.add_child(name)

	var remaining: int = int(item.get("remaining_turns", 0))
	var total: int = maxi(1, int(item.get("total_turns", 1)))
	var progress := ProgressBar.new()
	progress.custom_minimum_size = Vector2(150, 22)
	progress.max_value = total
	progress.value = total - max(remaining, 0)
	hbox.add_child(progress)

	var state := Label.new()
	state.custom_minimum_size = Vector2(110, 22)
	state.add_theme_font_size_override("font_size", 12)
	state.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	state.text = "等待空位" if remaining <= 0 else "剩余 %d/%d 回合" % [remaining, total]
	hbox.add_child(state)
	return row


func _get_selected_option() -> Dictionary:
	for option_variant in _options:
		var option: Dictionary = option_variant
		if str(option.get("id", "")) == _selected_unit_id:
			return option
	return {}


func _has_option(unit_id: String) -> bool:
	for option_variant in _options:
		var option: Dictionary = option_variant
		if str(option.get("id", "")) == unit_id:
			return true
	return false


func _get_option_count(unit_id: String) -> int:
	return int(_counts.get(unit_id, 1))


func _get_available_queue_slots() -> int:
	return maxi(0, QUEUE_CAPACITY - _queue.size())


func _get_unit_marker_icon(option: Dictionary) -> Texture2D:
	var icon_key: String = _get_unit_marker_key(option)
	var icon_path: String = str(RECRUIT_ICON_PATHS.get(icon_key, RECRUIT_ICON_PATHS["melee"]))
	return load(icon_path)


func _get_unit_marker_key(option: Dictionary) -> String:
	var tags: Array = option.get("tags", [])
	if bool(option.get("can_gather", false)) or "worker" in tags:
		return "worker"
	if "ranged" in tags or "crossbow" in tags or "slinger" in tags:
		return "ranged"
	if "tank" in tags or "shield" in tags or "damage_soak" in tags:
		return "tank"
	if "scout" in tags or "beast" in tags or int(option.get("role", -1)) == 1:
		return "scout"
	return "melee"


func _get_unit_marker(option: Dictionary) -> String:
	var tags: Array = option.get("tags", [])
	if bool(option.get("can_gather", false)) or "worker" in tags:
		return "镐"
	if "ranged" in tags or "crossbow" in tags or "slinger" in tags:
		return "弓"
	if "tank" in tags or "shield" in tags or "damage_soak" in tags:
		return "盾"
	if "scout" in tags or "beast" in tags or int(option.get("role", -1)) == 1:
		return "靴"
	return "剑"


func _format_unit_actions(option: Dictionary) -> String:
	var tags: Array = option.get("tags", [])
	var parts: PackedStringArray = []
	if bool(option.get("can_gather", false)) or "worker" in tags:
		parts.append("采集资源、入驻建筑、执行建设和升级相关工作")
	if "scout" in tags:
		parts.append("快速探索、扩大视野、寻找资源与敌方动向")
	if "ranged" in tags or "crossbow" in tags or "slinger" in tags:
		parts.append("远程攻击，在安全距离压制目标")
	if "throw_beast" in tags:
		parts.append("可投掷相邻猎齿兽")
	if "tank" in tags or "shield" in tags or "damage_soak" in tags:
		parts.append("承受伤害，保护后排和军团阵线")
	if "swarm" in tags or "cheap" in tags:
		parts.append("低成本成批投入，适合人海推进")
	if "melee" in tags and parts.is_empty():
		parts.append("近战接敌，持续攻击敌方单位或建筑")
	elif "melee" in tags:
		parts.append("可参与近战压制")
	if bool(option.get("can_attack_buildings", false)):
		parts.append("可攻击建筑")
	if parts.is_empty() and bool(option.get("can_attack_units", false)):
		parts.append("参与战斗")
	if parts.is_empty():
		parts.append("基础辅助单位")
	return "；".join(parts)


func _format_cost(cost_variant) -> String:
	var cost: Dictionary = {}
	if cost_variant is Dictionary:
		cost = cost_variant
	if cost.is_empty():
		return "免费"
	var parts: PackedStringArray = []
	for key in cost:
		var name: String = GameCatalog.resource_name(str(key))
		parts.append("%s %d" % [name, int(cost[key])])
	return " ".join(parts)


func _scale_cost(cost_variant, multiplier: int) -> Dictionary:
	var result: Dictionary = {}
	if not (cost_variant is Dictionary):
		return result
	var cost: Dictionary = cost_variant
	for key in cost:
		result[key] = int(cost[key]) * multiplier
	return result


func _make_portrait_texture(unit_id: String) -> Texture2D:
	if not UNIT_PORTRAITS.has(unit_id):
		return null
	var spec: Dictionary = UNIT_PORTRAITS[unit_id]
	var texture: Texture2D = load(str(spec.get("path", "")))
	if texture == null:
		return null
	var frame_size: Vector2 = spec.get("frame_size", Vector2(texture.get_width(), texture.get_height()))
	if frame_size.x <= 0.0 or frame_size.y <= 0.0:
		return texture
	if texture.get_width() <= frame_size.x and texture.get_height() <= frame_size.y:
		return texture
	var atlas := AtlasTexture.new()
	atlas.atlas = texture
	atlas.region = Rect2(Vector2.ZERO, frame_size)
	return atlas


func _make_style(bg: Color, border: Color, border_width: float, radius: float) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = bg
	style.border_color = border
	style.set_border_width_all(int(round(border_width)))
	style.set_corner_radius_all(int(round(radius)))
	return style
