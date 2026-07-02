extends Control

const CONFIG_PATH := "res://data/building_texture_fit.json"
const DEFAULT_TILE_SIZE := 32.0
const SIDE_PANEL_WIDTH := 360.0

const PRESET_TEXTURES := [
	{"key": "elf_capital", "name": "Elf Capital", "path": "res://assets/texture/Elven Capital.png", "footprint": Vector2i(2, 2), "scale": 0.87},
	{"key": "dwarf_capital", "name": "Dwarf Capital", "path": "res://assets/texture/Dwarf Capital.png", "footprint": Vector2i(2, 2), "scale": 1.0},
	{"key": "orc_capital", "name": "Orc Capital", "path": "res://assets/texture/Orc Capital.png", "footprint": Vector2i(2, 2), "scale": 1.0},
	{"key": "gold_mine", "name": "Gold Mine", "path": "res://assets/texture/Gold mine.png", "footprint": Vector2i(1, 1), "scale": 1.0},
	{"key": "stone", "name": "Stone", "path": "res://assets/texture/stone.png", "footprint": Vector2i(1, 1), "scale": 1.0},
	{"key": "lumber_camp", "name": "Lumber Camp", "path": "", "footprint": Vector2i(1, 1), "scale": 1.0},
	{"key": "quarry", "name": "Quarry", "path": "", "footprint": Vector2i(1, 1), "scale": 1.0},
	{"key": "farm", "name": "Farm", "path": "", "footprint": Vector2i(1, 1), "scale": 1.0},
	{"key": "warehouse", "name": "Warehouse", "path": "", "footprint": Vector2i(1, 1), "scale": 1.0},
	{"key": "iron_mine", "name": "Iron Mine", "path": "", "footprint": Vector2i(1, 1), "scale": 1.0},
	{"key": "forge", "name": "Forge", "path": "", "footprint": Vector2i(1, 1), "scale": 1.0},
	{"key": "recruit_camp", "name": "Recruit Camp", "path": "", "footprint": Vector2i(1, 1), "scale": 1.0},
	{"key": "scout_post", "name": "Scout Post", "path": "", "footprint": Vector2i(1, 1), "scale": 1.0},
	{"key": "watch_tower", "name": "Watch Tower", "path": "", "footprint": Vector2i(1, 1), "scale": 1.0},
]

var _preset_index := 0
var _texture: Texture2D = null
var _texture_path := ""
var _footprint := Vector2i(2, 2)
var _texture_scale := 1.0
var _offset_tiles := Vector2.ZERO
var _view_zoom := 4.0

var _path_edit: LineEdit = null
var _value_label: Label = null


func _ready() -> void:
	_build_ui()
	_load_preset(0)


func _draw() -> void:
	var preview_rect := Rect2(Vector2.ZERO, Vector2(size.x - SIDE_PANEL_WIDTH, size.y))
	draw_rect(preview_rect, Color(0.13, 0.14, 0.15), true)
	_draw_preview(preview_rect)


func _build_ui() -> void:
	var panel := PanelContainer.new()
	panel.anchor_left = 1.0
	panel.anchor_right = 1.0
	panel.anchor_bottom = 1.0
	panel.offset_left = -SIDE_PANEL_WIDTH
	add_child(panel)

	var margin := MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 14)
	margin.add_theme_constant_override("margin_top", 14)
	margin.add_theme_constant_override("margin_right", 14)
	margin.add_theme_constant_override("margin_bottom", 14)
	panel.add_child(margin)

	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 10)
	margin.add_child(box)

	var title := Label.new()
	title.text = "Building Texture Fit"
	title.add_theme_font_size_override("font_size", 22)
	box.add_child(title)

	var preset := OptionButton.new()
	for preset_data in PRESET_TEXTURES:
		var item: Dictionary = preset_data
		preset.add_item(str(item.get("name", "")))
	preset.item_selected.connect(_load_preset)
	box.add_child(preset)

	_path_edit = LineEdit.new()
	_path_edit.placeholder_text = "res://assets/texture/..."
	_path_edit.text_submitted.connect(func(_text: String) -> void: _load_texture_from_path())
	box.add_child(_path_edit)

	var load_button := Button.new()
	load_button.text = "Load Path"
	load_button.pressed.connect(_load_texture_from_path)
	box.add_child(load_button)

	box.add_child(_make_slider_row("Footprint W", 1.0, 6.0, 1.0, float(_footprint.x), func(value: float) -> void:
		_footprint.x = int(value)
		_refresh_value_label()
		queue_redraw()
	))
	box.add_child(_make_slider_row("Footprint H", 1.0, 6.0, 1.0, float(_footprint.y), func(value: float) -> void:
		_footprint.y = int(value)
		_refresh_value_label()
		queue_redraw()
	))
	box.add_child(_make_slider_row("Texture Scale", 0.1, 3.0, 0.01, _texture_scale, func(value: float) -> void:
		_texture_scale = value
		_refresh_value_label()
		queue_redraw()
	))
	box.add_child(_make_slider_row("Offset X", -3.0, 3.0, 0.01, _offset_tiles.x, func(value: float) -> void:
		_offset_tiles.x = value
		_refresh_value_label()
		queue_redraw()
	))
	box.add_child(_make_slider_row("Offset Y", -3.0, 3.0, 0.01, _offset_tiles.y, func(value: float) -> void:
		_offset_tiles.y = value
		_refresh_value_label()
		queue_redraw()
	))
	box.add_child(_make_slider_row("View Zoom", 1.0, 8.0, 0.1, _view_zoom, func(value: float) -> void:
		_view_zoom = value
		queue_redraw()
	))

	var save_button := Button.new()
	save_button.text = "Save Apply JSON"
	save_button.pressed.connect(_save_config)
	box.add_child(save_button)

	_value_label = Label.new()
	_value_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	box.add_child(_value_label)


func _make_slider_row(label_text: String, min_value: float, max_value: float, step: float, initial_value: float, callback: Callable) -> Control:
	var row := VBoxContainer.new()
	var label := Label.new()
	label.text = label_text
	row.add_child(label)
	var slider := HSlider.new()
	slider.min_value = min_value
	slider.max_value = max_value
	slider.step = step
	slider.value = initial_value
	slider.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	slider.value_changed.connect(callback)
	row.add_child(slider)
	return row


func _load_preset(index: int) -> void:
	_preset_index = index
	var preset: Dictionary = PRESET_TEXTURES[index]
	_texture_path = str(preset.get("path", ""))
	_footprint = preset.get("footprint", Vector2i(2, 2))
	_texture_scale = float(preset.get("scale", 1.0))
	_offset_tiles = Vector2.ZERO
	if _path_edit != null:
		_path_edit.text = _texture_path
	_load_texture_from_path()


func _load_texture_from_path() -> void:
	if _path_edit != null:
		_texture_path = _path_edit.text.strip_edges()
	var loaded := load(_texture_path)
	_texture = loaded if loaded is Texture2D else null
	_refresh_value_label()
	queue_redraw()


func _refresh_value_label() -> void:
	if _value_label == null:
		return
	var preset: Dictionary = PRESET_TEXTURES[_preset_index]
	_value_label.text = "key: %s\ntexture: %s\nfootprint: %dx%d\nscale: %.2f\noffset: %.2f, %.2f" % [
		str(preset.get("key", "")),
		_texture_path,
		_footprint.x,
		_footprint.y,
		_texture_scale,
		_offset_tiles.x,
		_offset_tiles.y
	]


func _save_config() -> void:
	var config := _load_config()
	var preset: Dictionary = PRESET_TEXTURES[_preset_index]
	var key := str(preset.get("key", "custom"))
	config[key] = {
		"texture": _texture_path,
		"footprint": [_footprint.x, _footprint.y],
		"scale": _texture_scale,
		"offset": [_offset_tiles.x, _offset_tiles.y],
	}
	var file := FileAccess.open(CONFIG_PATH, FileAccess.WRITE)
	if file == null:
		return
	file.store_string(JSON.stringify(config, "\t"))
	file.close()


func _load_config() -> Dictionary:
	if not FileAccess.file_exists(CONFIG_PATH):
		return {}
	var file := FileAccess.open(CONFIG_PATH, FileAccess.READ)
	if file == null:
		return {}
	var text := file.get_as_text()
	file.close()
	var parsed: Variant = JSON.parse_string(text)
	return parsed if parsed is Dictionary else {}


func _draw_preview(preview_rect: Rect2) -> void:
	var font: Font = ThemeDB.fallback_font
	var tile_px := DEFAULT_TILE_SIZE * _view_zoom
	var footprint_size := Vector2(float(_footprint.x), float(_footprint.y)) * tile_px
	var footprint_rect := Rect2(preview_rect.get_center() - footprint_size * 0.5, footprint_size)
	draw_rect(footprint_rect.grow(tile_px * 2.0), Color(0.09, 0.10, 0.11), true)
	for x in range(-2, _footprint.x + 3):
		var px := footprint_rect.position.x + float(x) * tile_px
		draw_line(Vector2(px, footprint_rect.position.y - tile_px * 2.0), Vector2(px, footprint_rect.end.y + tile_px * 2.0), Color(0.78, 0.86, 1.0, 0.3), 1.0)
	for y in range(-2, _footprint.y + 3):
		var py := footprint_rect.position.y + float(y) * tile_px
		draw_line(Vector2(footprint_rect.position.x - tile_px * 2.0, py), Vector2(footprint_rect.end.x + tile_px * 2.0, py), Color(0.78, 0.86, 1.0, 0.3), 1.0)
	draw_rect(footprint_rect, Color(0.25, 0.58, 1.0, 0.18), true)
	draw_rect(footprint_rect, Color(0.48, 0.78, 1.0, 0.95), false, 2.0)
	if _texture != null:
		var tex_size := footprint_size * _texture_scale
		var tex_rect := Rect2(footprint_rect.get_center() - tex_size * 0.5 + _offset_tiles * tile_px, tex_size)
		draw_texture_rect(_texture, tex_rect, false)
		draw_rect(tex_rect, Color(1.0, 1.0, 1.0, 0.65), false, 1.0)
	draw_string(font, preview_rect.position + Vector2(24.0, 32.0), "Preview only. Main workflow is GridManager2D inspector.", HORIZONTAL_ALIGNMENT_LEFT, -1, 16, Color(0.88, 0.9, 0.92))
