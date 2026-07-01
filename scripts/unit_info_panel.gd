extends Control

signal form_warband_requested(unit_id: int)
signal confirm_warband_requested()
signal cancel_warband_requested()
signal disband_warband_requested(unit_id: int)
## 底部单位信息面板 v2 — 方案A：头像 + 属性网格 + 命令区

# ── 区域容器 ──
var _panel: Panel
var _portrait_rect: TextureRect
var _portrait_fallback: Label
var _faction_bar: ColorRect

# ── 分隔线 ──

# ── 中部属性区 ──
var _name_label: Label
var _cat_label: Label
var _hp_heart_1: Label
var _hp_heart_2: Label
var _hp_heart_3: Label
var _hp_text: Label

var _atk_icon: TextureRect
var _atk_label: Label
var _mov_icon: TextureRect
var _mov_label: Label
var _vis_icon: TextureRect
var _vis_label: Label
var _food_icon: TextureRect
var _food_label: Label
# ── 右侧命令区 ──
var _warband_button: Button
var _warband_confirm_button: Button
var _warband_cancel_button: Button
var _warband_disband_button: Button
var _warband_cost_label: Label

var _current_unit_id: int = -1

const CATEGORY_NAMES := {
	UnitData.UnitCategory.WORKER: "工人",
	UnitData.UnitCategory.SCOUT: "斥候",
	UnitData.UnitCategory.GUARD: "守卫",
	UnitData.UnitCategory.ELITE: "精英",
	UnitData.UnitCategory.SIEGE: "攻城",
	UnitData.UnitCategory.SPECIAL: "特殊",
}

const CATEGORY_LETTERS := {
	UnitData.UnitCategory.WORKER: "工",
	UnitData.UnitCategory.SCOUT: "侦",
	UnitData.UnitCategory.GUARD: "卫",
	UnitData.UnitCategory.ELITE: "精",
	UnitData.UnitCategory.SIEGE: "攻",
	UnitData.UnitCategory.SPECIAL: "特",
}

# ── 尺寸常量 ──
const PANEL_LEFT := 4.0
const PANEL_TOP := 880.0
const PANEL_RIGHT := 694.0
const PANEL_BOTTOM := 1148.0
const PANEL_W := 690.0
const PANEL_H := 268.0

const MARGIN_L := 34.0
const MARGIN_R := 52.0
const MARGIN_T := 13.0
const MARGIN_B := 18.0
const PORTRAIT_W := 130.0
const COMMAND_W := 80.0
const DIVIDER_W := 2.0

# ── 颜色 ──
const CLR_BG := Color(0.08, 0.08, 0.08, 0.92)
const CLR_BORDER := Color(0.722, 0.565, 0.180, 0.5)
const CLR_DIVIDER := Color(0.651, 0.498, 0.149, 0.5)
const CLR_TEXT_WHITE := Color(0.227, 0.149, 0.094)
const CLR_TEXT_DIM := Color(0.420, 0.298, 0.231)
const CLR_GREEN := Color(0.165, 0.290, 0.118)
const CLR_GREEN_DIM := Color(0.129, 0.227, 0.086)
const CLR_HEART := Color(0.761, 0.227, 0.180)
const CLR_HEART_EMPTY := Color(0.361, 0.290, 0.243)
const CLR_PORTRAIT_BG := Color(0.176, 0.133, 0.086)
const CLR_BTN_BG := Color(0.290, 0.227, 0.157)
const CLR_BTN_HOVER := Color(0.420, 0.314, 0.212)


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_PASS
	_build_ui()
	hide()


func _build_ui() -> void:
	# ═══ 主面板 ═══
	_panel = Panel.new()
	_panel.offset_left = PANEL_LEFT
	_panel.offset_top = PANEL_TOP
	_panel.offset_right = PANEL_RIGHT
	_panel.offset_bottom = PANEL_BOTTOM
	_panel.scale = Vector2(0.75, 0.75)

	var style := StyleBoxFlat.new()
	style.bg_color = Color(0, 0, 0, 0)
	_panel.add_theme_stylebox_override("panel", style)
	add_child(_panel)

	# 羊皮纸底图
	var bg_tex := TextureRect.new()
	bg_tex.name = "ParchmentBG"
	bg_tex.offset_left = 0.0
	bg_tex.offset_top = 0.0
	bg_tex.offset_right = PANEL_W
	bg_tex.offset_bottom = PANEL_H
	bg_tex.texture = load("res://assets/info_panel_bg.png")
	bg_tex.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	bg_tex.stretch_mode = TextureRect.STRETCH_SCALE
	bg_tex.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_panel.add_child(bg_tex)

	# ═══ 分区构建 ═══
	_build_portrait_section()
	_build_stats_section()
	_build_command_section()


func _build_portrait_section() -> void:
	var cx := MARGIN_L + PORTRAIT_W / 2.0 + 80.0
	var frame_size := 110.0
	var grid_bottom := MARGIN_T + 138.0 + 44.0 + 18.0
	var py := grid_bottom - frame_size

	_portrait_rect = TextureRect.new()
	_portrait_rect.position = Vector2(cx - frame_size / 2.0, py)
	_portrait_rect.size = Vector2(frame_size, frame_size)
	_portrait_rect.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_portrait_rect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	_panel.add_child(_portrait_rect)

	var tex := load("res://assets/portrait_elf_worker.png")
	if tex:
		_portrait_rect.texture = tex
	else:
		_portrait_fallback = Label.new()
		_portrait_fallback.position = Vector2(cx - 10, py + frame_size / 2.0 - 16)
		_portrait_fallback.add_theme_font_size_override("font_size", 32)
		_portrait_fallback.add_theme_color_override("font_color", CLR_GREEN)
		_portrait_fallback.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		_panel.add_child(_portrait_fallback)


func _build_stats_section() -> void:
	var sx := MARGIN_L + PORTRAIT_W + 112.0

	# ═══ 单位名 + 标签 + 状态 ═══
	_name_label = Label.new()
	_name_label.position = Vector2(MARGIN_L + 92.0, MARGIN_T + 34)
	_name_label.add_theme_font_size_override("font_size", 22)
	_name_label.add_theme_color_override("font_color", CLR_TEXT_DIM)
	_panel.add_child(_name_label)

	_cat_label = Label.new()
	_cat_label.position = Vector2(sx + 2, MARGIN_T + 40)
	_cat_label.add_theme_font_size_override("font_size", 12)
	_cat_label.add_theme_color_override("font_color", CLR_TEXT_DIM)
	_panel.add_child(_cat_label)


	# ═══ HP 爱心 ═══
	var hp_y := MARGIN_T + 78.0
	var hp_label := Label.new()
	hp_label.position = Vector2(sx, hp_y + 6)
	hp_label.text = "生命"
	hp_label.add_theme_font_size_override("font_size", 13)
	hp_label.add_theme_color_override("font_color", CLR_TEXT_DIM)
	_panel.add_child(hp_label)

	var heart_x := sx + 50.0
	_hp_heart_1 = _make_heart(heart_x, hp_y)
	_hp_heart_2 = _make_heart(heart_x + 28, hp_y)
	_hp_heart_3 = _make_heart(heart_x + 56, hp_y)

	_hp_text = Label.new()
	_hp_text.position = Vector2(heart_x + 90, hp_y + 6)
	_hp_text.text = "3/3"
	_hp_text.add_theme_font_size_override("font_size", 16)
	_hp_text.add_theme_color_override("font_color", CLR_TEXT_WHITE)
	_panel.add_child(_hp_text)

	# ═══ 属性 2×2 网格 ═══
	var grid_y := MARGIN_T + 138.0
	var col_w := 170.0
	var row_h := 44.0
	var icon_ofs := 36.0
	var val_ofs := 66.0

	_make_stat_name(sx, grid_y, "攻击")
	_atk_icon = _make_icon_texture(sx + icon_ofs, grid_y, "icon_atk")
	_atk_label = _make_stat_val(sx + val_ofs, grid_y, "0/1")

	_make_stat_name(sx + col_w, grid_y, "视野")
	_vis_icon = _make_icon_texture(sx + col_w + icon_ofs, grid_y, "icon_vis")
	_vis_label = _make_stat_val(sx + col_w + val_ofs, grid_y, "1")

	_make_stat_name(sx, grid_y + row_h, "移动")
	_mov_icon = _make_icon_texture(sx + icon_ofs, grid_y + row_h, "icon_mov")
	_mov_label = _make_stat_val(sx + val_ofs, grid_y + row_h, "2")

	_make_stat_name(sx + col_w, grid_y + row_h, "食物")
	_food_icon = _make_icon_texture(sx + col_w + icon_ofs, grid_y + row_h, "icon_food")
	_food_label = _make_stat_val(sx + col_w + val_ofs, grid_y + row_h, "1")

func _build_command_section() -> void:
	var cx := PANEL_W - MARGIN_R - COMMAND_W
	var btn_w := 76.0
	var btn_h := 28.0
	var btn_x := cx + (COMMAND_W - btn_w) / 2.0
	var gap := 8.0
	var start_y := MARGIN_T + 6.0

	# 军团按钮
	var wb_y := start_y + (btn_h + gap) * 3 + 4

	_warband_button = Button.new()
	_warband_button.position = Vector2(btn_x - 4, wb_y)
	_warband_button.size = Vector2(btn_w + 8, btn_h)
	_warband_button.text = "组建军团"
	_warband_button.focus_mode = Control.FOCUS_NONE
	_warband_button.pressed.connect(_on_warband_button_pressed)
	_style_button(_warband_button, false)
	_panel.add_child(_warband_button)

	_warband_confirm_button = Button.new()
	_warband_confirm_button.position = Vector2(btn_x - 4, wb_y)
	_warband_confirm_button.size = Vector2(44, 26)
	_warband_confirm_button.text = "确认"
	_warband_confirm_button.focus_mode = Control.FOCUS_NONE
	_warband_confirm_button.pressed.connect(_on_warband_confirm_pressed)
	_style_button(_warband_confirm_button, false)
	_panel.add_child(_warband_confirm_button)

	_warband_cancel_button = Button.new()
	_warband_cancel_button.position = Vector2(btn_x + 48, wb_y)
	_warband_cancel_button.size = Vector2(44, 26)
	_warband_cancel_button.text = "取消"
	_warband_cancel_button.focus_mode = Control.FOCUS_NONE
	_warband_cancel_button.pressed.connect(_on_warband_cancel_pressed)
	_style_button(_warband_cancel_button, false)
	_panel.add_child(_warband_cancel_button)

	_warband_disband_button = Button.new()
	_warband_disband_button.position = Vector2(btn_x - 4, wb_y)
	_warband_disband_button.size = Vector2(btn_w + 8, btn_h)
	_warband_disband_button.text = "解散军团"
	_warband_disband_button.focus_mode = Control.FOCUS_NONE
	_warband_disband_button.pressed.connect(_on_warband_disband_pressed)
	_style_button(_warband_disband_button, false)
	_panel.add_child(_warband_disband_button)

	_warband_cost_label = Label.new()
	_warband_cost_label.position = Vector2(cx - 120, wb_y + btn_h - 4)
	_warband_cost_label.size = Vector2(110, 32)
	_warband_cost_label.add_theme_font_size_override("font_size", 12)
	_warband_cost_label.add_theme_color_override("font_color", Color(1.0, 0.82, 0.58))
	_warband_cost_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_panel.add_child(_warband_cost_label)

# ── 辅助构建方法 ──

func _make_heart(x: float, y: float) -> Label:
	var lbl := Label.new()
	lbl.position = Vector2(x, y)
	lbl.text = "♥"
	lbl.add_theme_font_size_override("font_size", 22)
	lbl.add_theme_color_override("font_color", CLR_HEART)
	_panel.add_child(lbl)
	return lbl



func _make_stat_name(x: float, y: float, text: String) -> void:
	var lbl := Label.new()
	lbl.position = Vector2(x, y)
	lbl.text = text
	lbl.add_theme_font_size_override("font_size", 13)
	lbl.add_theme_color_override("font_color", CLR_TEXT_DIM)
	_panel.add_child(lbl)

func _make_icon_texture(x: float, y: float, icon_name: String) -> TextureRect:
	var rect := TextureRect.new()
	rect.position = Vector2(x, y)
	rect.size = Vector2(20, 20)
	rect.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	rect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	var tex := load("res://assets/%s.png" % icon_name)
	if tex:
		rect.texture = tex
	_panel.add_child(rect)
	return rect


func _make_stat_val(x: float, y: float, default_val: String) -> Label:
	var lbl := Label.new()
	lbl.position = Vector2(x, y)
	lbl.text = default_val
	lbl.add_theme_font_size_override("font_size", 16)
	lbl.add_theme_color_override("font_color", CLR_TEXT_WHITE)
	_panel.add_child(lbl)
	return lbl




func _style_button(btn: Button, primary: bool) -> void:
	var s := StyleBoxFlat.new()
	if primary:
		s.bg_color = CLR_BTN_BG
		s.border_color = CLR_GREEN_DIM
	else:
		s.bg_color = Color(0.03, 0.06, 0.03)
		s.border_color = Color(0.15, 0.30, 0.15, 0.7)
	s.border_width_top = 2
	s.border_width_bottom = 2
	s.border_width_left = 2
	s.border_width_right = 2
	btn.add_theme_stylebox_override("normal", s)

	var s_hover := StyleBoxFlat.new()
	s_hover.bg_color = CLR_BTN_HOVER
	s_hover.border_color = CLR_GREEN
	s_hover.border_width_top = 2
	s_hover.border_width_bottom = 2
	s_hover.border_width_left = 2
	s_hover.border_width_right = 2
	btn.add_theme_stylebox_override("hover", s_hover)

	btn.add_theme_font_size_override("font_size", 13 if primary else 11)
	btn.add_theme_color_override("font_color", CLR_GREEN if primary else CLR_TEXT_DIM)
	btn.add_theme_color_override("font_hover_color", Color(0.54, 0.93, 0.54))
	btn.add_theme_color_override("font_focus_color", CLR_GREEN)
	if not primary:
		btn.add_theme_color_override("font_color", Color(0.5, 0.5, 0.5))


# ── 公共接口 ──

func show_unit(unit: Dictionary) -> void:
	if unit.is_empty():
		hide()
		return

	var data: UnitData = unit["data"]
	var faction: int = unit["faction"]
	_current_unit_id = int(unit.get("id", -1))
	var color: Color = GameCatalog.faction_color(faction)

	# 阵营色条
	if _faction_bar:
		_faction_bar.color = color

	# 名称（阵营色）
	_name_label.text = data.unit_name
	_name_label.add_theme_color_override("font_color", CLR_TEXT_DIM)

	# 分类标签
	_cat_label.text = CATEGORY_NAMES.get(data.category, "未知")

	# HP 爱心
	var hp: int = unit.get("hp", data.hp_max)
	var hp_max: int = data.hp_max
	_set_hearts(hp, hp_max)
	_hp_text.text = "%d/%d" % [hp, hp_max]
	if hp == 0:
		_hp_text.add_theme_color_override("font_color", Color(1.0, 0.2, 0.2))
	elif hp < hp_max:
		_hp_text.add_theme_color_override("font_color", Color(1.0, 0.7, 0.2))
	else:
		_hp_text.add_theme_color_override("font_color", CLR_TEXT_WHITE)

	# 属性
	if data.atk > 0:
		_atk_label.text = "%d/%d" % [data.atk, data.attack_range]
	else:
		_atk_label.text = "0"
	_mov_label.text = "%d" % data.move_max
	var effective_vision: int = int(unit.get("effective_vision", data.vision))
	var vision_bonus: int = int(unit.get("vision_bonus", effective_vision - data.vision))
	if vision_bonus != 0:
		var bonus_prefix: String = "+" if vision_bonus > 0 else ""
		_vis_label.text = "%d (%s%d)" % [effective_vision, bonus_prefix, vision_bonus]
	else:
		_vis_label.text = str(effective_vision)
	_food_label.text = str(data.food_cost)

	# 命令按钮状态
	_update_warband_button(unit)

	show()
	queue_redraw()


func hide_panel() -> void:
	_current_unit_id = -1
	hide()


func _set_hearts(current: int, maximum: int) -> void:
	var hearts := [_hp_heart_1, _hp_heart_2, _hp_heart_3]
	var count := mini(maximum, hearts.size())
	for i in hearts.size():
		if hearts[i] == null:
			continue
		if i < count:
			hearts[i].visible = true
			if i < current:
				hearts[i].add_theme_color_override("font_color", CLR_HEART)
			else:
				hearts[i].add_theme_color_override("font_color", CLR_HEART_EMPTY)
		else:
			hearts[i].visible = false


# ── 命令按钮回调 ──







# ── 军团按钮（保持原有逻辑） ──

func _update_warband_button(unit: Dictionary) -> void:
	if _warband_button == null:
		return
	_warband_button.visible = false
	_warband_confirm_button.visible = false
	_warband_cancel_button.visible = false
	_warband_disband_button.visible = false
	_warband_cost_label.visible = false
	return
	var can_form: bool = bool(unit.get("can_form_warband", false))
	var is_member: bool = int(unit.get("warband_id", -1)) >= 0
	var is_selecting: bool = bool(unit.get("warband_selecting", false))
	var selected_count: int = int(unit.get("warband_selected_count", 0))
	_warband_button.visible = int(unit.get("faction", -1)) == 2
	_warband_button.disabled = is_selecting or not can_form or is_member
	_warband_confirm_button.visible = is_selecting
	_warband_confirm_button.disabled = selected_count < 3
	_warband_cancel_button.visible = is_selecting
	_warband_disband_button.visible = is_member and not is_selecting
	_warband_cost_label.visible = int(unit.get("faction", -1)) == 2 and (can_form or is_member or is_selecting)
	_warband_cost_label.text = str(unit.get("warband_ap_text", ""))
	if is_member:
		_warband_button.text = "军团指挥中"
	elif is_selecting:
		_warband_button.text = "选择军团中"
	elif can_form:
		_warband_button.text = "军团指挥"
	else:
		_warband_button.text = "军团条件不足"


func _on_warband_button_pressed() -> void:
	if _current_unit_id < 0:
		return
	form_warband_requested.emit(_current_unit_id)


func _on_warband_confirm_pressed() -> void:
	confirm_warband_requested.emit()


func _on_warband_cancel_pressed() -> void:
	cancel_warband_requested.emit()


func _on_warband_disband_pressed() -> void:
	if _current_unit_id < 0:
		return
	disband_warband_requested.emit(_current_unit_id)
