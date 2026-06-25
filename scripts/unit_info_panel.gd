extends Control

signal form_warband_requested(unit_id: int)
signal confirm_warband_requested()
signal cancel_warband_requested()
signal disband_warband_requested(unit_id: int)
## 底部单位信息面板 — 选中单位时显示属性

var _panel: Panel
var _name_label: Label
var _cat_label: Label
var _status_label: Label
var _hp_bar_bg: ColorRect
var _hp_bar_fg: ColorRect
var _hp_label: Label
var _atk_label: Label
var _mov_label: Label
var _vis_label: Label
var _food_label: Label
var _hint_label: Label
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


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_PASS
	_build_ui()
	hide()


func _build_ui() -> void:
	# 主面板
	_panel = Panel.new()
	_panel.offset_left = 250.0
	_panel.offset_top = 830.0
	_panel.offset_right = 1650.0
	_panel.offset_bottom = 1040.0

	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.06, 0.06, 0.06, 0.92)
	style.border_color = Color(0.25, 0.25, 0.25, 0.5)
	style.border_width_top = 1
	style.border_width_bottom = 1
	style.border_width_left = 1
	style.border_width_right = 1
	style.corner_radius_top_left = 6
	style.corner_radius_top_right = 6
	_panel.add_theme_stylebox_override("panel", style)
	add_child(_panel)

	# 顶部阵营色条（4px）
	var bar := ColorRect.new()
	bar.position = Vector2(0, 0)
	bar.size = Vector2(1400, 4)
	bar.color = Color(0.5, 0.5, 0.5)
	bar.name = "FactionBar"
	_panel.add_child(bar)

	var margin := 20
	var row_h := 36
	var start_y := 20

	# 第一行：单位名 + 分类 + 状态
	_name_label = Label.new()
	_name_label.position = Vector2(margin, start_y)
	_name_label.add_theme_font_size_override("font_size", 24)
	_name_label.add_theme_color_override("font_color", Color.WHITE)
	_panel.add_child(_name_label)

	_cat_label = Label.new()
	_cat_label.position = Vector2(margin + 220, start_y + 6)
	_cat_label.add_theme_font_size_override("font_size", 14)
	_cat_label.add_theme_color_override("font_color", Color(0.7, 0.7, 0.7))
	_panel.add_child(_cat_label)

	_status_label = Label.new()
	_status_label.position = Vector2(1150, start_y + 6)
	_status_label.add_theme_font_size_override("font_size", 15)
	_panel.add_child(_status_label)

	var row2_y := start_y + row_h + 8


	# HP 条
	var hp_label_title := Label.new()
	hp_label_title.position = Vector2(margin, row2_y)
	hp_label_title.text = "生命"
	hp_label_title.add_theme_font_size_override("font_size", 14)
	hp_label_title.add_theme_color_override("font_color", Color(0.8, 0.8, 0.8))
	_panel.add_child(hp_label_title)

	_hp_bar_bg = ColorRect.new()
	_hp_bar_bg.position = Vector2(margin + 40, row2_y + 2)
	_hp_bar_bg.size = Vector2(160, 18)
	_hp_bar_bg.color = Color(0.15, 0.15, 0.15)
	_panel.add_child(_hp_bar_bg)

	_hp_bar_fg = ColorRect.new()
	_hp_bar_fg.position = Vector2(margin + 40, row2_y + 2)
	_hp_bar_fg.size = Vector2(160, 18)
	_hp_bar_fg.color = Color(0.2, 0.8, 0.2)
	_panel.add_child(_hp_bar_fg)

	_hp_label = Label.new()
	_hp_label.position = Vector2(margin + 40 + 80, row2_y + 1)
	_hp_label.add_theme_font_size_override("font_size", 13)
	_hp_label.add_theme_color_override("font_color", Color.WHITE)
	_hp_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_panel.add_child(_hp_label)

	# 属性数值（水平排列）
	var stat_x := margin + 240
	var stat_gap := 140

	_atk_label = _make_stat_label(stat_x, row2_y, "攻击")
	_mov_label = _make_stat_label(stat_x + stat_gap, row2_y, "移动")
	_vis_label = _make_stat_label(stat_x + stat_gap * 2, row2_y, "视野")
	_food_label = _make_stat_label(stat_x + stat_gap * 3, row2_y, "食物")

	_hint_label = Label.new()
	_hint_label.position = Vector2(margin, row2_y + 66)
	_hint_label.size = Vector2(1320, 40)
	_hint_label.add_theme_font_size_override("font_size", 15)
	_hint_label.add_theme_color_override("font_color", Color(0.78, 0.9, 1.0))
	_hint_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_panel.add_child(_hint_label)

	_warband_button = Button.new()
	_warband_button.position = Vector2(1150, row2_y + 46)
	_warband_button.size = Vector2(170, 34)
	_warband_button.text = "\u7ec4\u5efa\u519b\u56e2"
	_warband_button.focus_mode = Control.FOCUS_NONE
	_warband_button.pressed.connect(_on_warband_button_pressed)
	_panel.add_child(_warband_button)

	_warband_confirm_button = Button.new()
	_warband_confirm_button.position = Vector2(1150, row2_y + 84)
	_warband_confirm_button.size = Vector2(82, 30)
	_warband_confirm_button.text = "\u786e\u8ba4"
	_warband_confirm_button.focus_mode = Control.FOCUS_NONE
	_warband_confirm_button.pressed.connect(_on_warband_confirm_pressed)
	_panel.add_child(_warband_confirm_button)

	_warband_cancel_button = Button.new()
	_warband_cancel_button.position = Vector2(1238, row2_y + 84)
	_warband_cancel_button.size = Vector2(82, 30)
	_warband_cancel_button.text = "\u53d6\u6d88"
	_warband_cancel_button.focus_mode = Control.FOCUS_NONE
	_warband_cancel_button.pressed.connect(_on_warband_cancel_pressed)
	_panel.add_child(_warband_cancel_button)

	_warband_disband_button = Button.new()
	_warband_disband_button.position = Vector2(1150, row2_y + 84)
	_warband_disband_button.size = Vector2(170, 30)
	_warband_disband_button.text = "\u89e3\u6563\u519b\u56e2"
	_warband_disband_button.focus_mode = Control.FOCUS_NONE
	_warband_disband_button.pressed.connect(_on_warband_disband_pressed)
	_panel.add_child(_warband_disband_button)

	_warband_cost_label = Label.new()
	_warband_cost_label.position = Vector2(760, row2_y + 84)
	_warband_cost_label.size = Vector2(380, 46)
	_warband_cost_label.add_theme_font_size_override("font_size", 14)
	_warband_cost_label.add_theme_color_override("font_color", Color(1.0, 0.82, 0.58))
	_warband_cost_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_panel.add_child(_warband_cost_label)


func _make_stat_label(x: float, y: float, title: String) -> Label:
	var title_lbl := Label.new()
	title_lbl.position = Vector2(x, y)
	title_lbl.text = title
	title_lbl.add_theme_font_size_override("font_size", 14)
	title_lbl.add_theme_color_override("font_color", Color(0.7, 0.7, 0.7))
	_panel.add_child(title_lbl)

	var val_lbl := Label.new()
	val_lbl.position = Vector2(x, y + 20)
	val_lbl.text = "0"
	val_lbl.add_theme_font_size_override("font_size", 22)
	val_lbl.add_theme_color_override("font_color", Color.WHITE)
	_panel.add_child(val_lbl)
	return val_lbl


func show_unit(unit: Dictionary) -> void:
	if unit.is_empty():
		hide()
		return

	var data: UnitData = unit["data"]
	var faction: int = unit["faction"]
	_current_unit_id = int(unit.get("id", -1))
	var color: Color = GameCatalog.faction_color(faction)

	# 阵营色条
	var bar: ColorRect = _panel.get_node("FactionBar")
	bar.color = color

	# 名称
	_name_label.text = data.unit_name
	_name_label.add_theme_color_override("font_color", color)

	# 分类
	_cat_label.text = CATEGORY_NAMES.get(data.category, "未知")

	# 状态
	var moved: bool = unit.get("has_moved", false)
	var attacked: bool = unit.get("has_attacked", false)
	if attacked:
		_status_label.text = "已攻击"
		_status_label.add_theme_color_override("font_color", Color(1.0, 0.3, 0.3))
	elif moved:
		_status_label.text = "已移动"
		_status_label.add_theme_color_override("font_color", Color(1.0, 0.8, 0.2))
	else:
		_status_label.text = "可行动"
		_status_label.add_theme_color_override("font_color", Color(0.3, 1.0, 0.3))

	var statuses: Dictionary = unit.get("statuses", {})
	var weaken_turns: int = int(statuses.get("poison_weakened_turns", 0))
	if weaken_turns > 0:
		_status_label.text = "\u865a\u5f31 %d \u56de\u5408" % weaken_turns
		_status_label.add_theme_color_override("font_color", Color(0.55, 1.0, 0.55))
	elif int(unit.get("warband_id", -1)) >= 0:
		_status_label.text = "\u519b\u56e2"
		_status_label.add_theme_color_override("font_color", Color(1.0, 0.42, 0.28))

	# HP 条
	var hp: int = unit.get("hp", data.hp_max)
	var hp_max: int = data.hp_max
	var ratio: float = float(hp) / float(hp_max) if hp_max > 0 else 0.0
	_hp_bar_fg.size.x = 160.0 * ratio
	if ratio > 0.5:
		_hp_bar_fg.color = Color(0.2, 0.8, 0.2)
	elif ratio > 0.25:
		_hp_bar_fg.color = Color(0.9, 0.7, 0.1)
	else:
		_hp_bar_fg.color = Color(0.9, 0.2, 0.1)
	_hp_label.text = "%d/%d" % [hp, hp_max]

	# 属性
	_atk_label.text = "%d/%d" % [data.atk, data.attack_range]
	_mov_label.text = "%d" % data.move_max
	var effective_vision: int = int(unit.get("effective_vision", data.vision))
	var vision_bonus: int = int(unit.get("vision_bonus", effective_vision - data.vision))
	if vision_bonus != 0:
		var bonus_prefix: String = "+" if vision_bonus > 0 else ""
		_vis_label.text = "%d (%s%d)" % [effective_vision, bonus_prefix, vision_bonus]
	else:
		_vis_label.text = str(effective_vision)
	_food_label.text = str(data.food_cost)
	_hint_label.text = _make_unit_hint(data)
	_update_warband_button(unit)

	show()
	queue_redraw()


func hide_panel() -> void:
	_current_unit_id = -1
	hide()


func _update_warband_button(unit: Dictionary) -> void:
	if _warband_button == null:
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
		_warband_button.text = "\u519b\u56e2\u6307\u6325\u4e2d"
	elif is_selecting:
		_warband_button.text = "\u9009\u62e9\u519b\u56e2\u4e2d"
	elif can_form:
		_warband_button.text = "\u519b\u56e2\u6307\u6325"
	else:
		_warband_button.text = "\u519b\u56e2\u6761\u4ef6\u4e0d\u8db3"


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


func _make_unit_hint(data: UnitData) -> String:
	var defense_text: String = ""
	if data.damage_reduction > 0:
		defense_text = "\u57fa\u7840\u51cf\u4f24 %d\u3002" % data.damage_reduction
	if data.category == UnitData.UnitCategory.SIEGE or "building_breaker" in data.tags:
		defense_text += "\u653b\u51fb\u5efa\u7b51 +2\u3002"
	if data.atk > 0 and "elf" in data.tags:
		defense_text += "\u5148\u624b\uff1a\u76ee\u6807\u5728\u81ea\u8eab\u89c6\u91ce\u5185\uff0c\u4e14\u81ea\u8eab\u4e0d\u5728\u76ee\u6807\u89c6\u91ce\u5185\u65f6\uff0c\u8ffd\u52a0\u534a\u4f24\u8fde\u51fb\u3002"
	if data.template_id == "unit.elf.scout":
		defense_text += "F \u952e\uff1a\u98ce\u884c\u65a5\u5019\u5929\u8d4b\uff0c\u6d88\u8017 1 AP \u63ed\u793a\u4e00\u7247\u533a\u57df\uff0c\u6bcf\u56de\u5408 1 \u6b21\uff0c\u72ec\u7acb\u51b7\u5374\u3002"
	if data.template_id == "unit.elf.guard":
		defense_text += "G \u952e\uff1a\u6708\u5f71\u523a\u5ba2\u5929\u8d4b\uff0c\u6d88\u8017 1 AP \u8ba9\u654c\u65b9\u7684\u4e00\u7247\u533a\u57df\u91cd\u65b0\u9677\u5165\u8ff7\u96fe\uff0c\u6bcf\u56de\u5408 1 \u6b21\uff0c\u72ec\u7acb\u51b7\u5374\u3002"
	if data.template_id == "unit.orc.slinger":
		return defense_text + "\u767d\u8272\u5706\u70b9=\u79fb\u52a8\uff1b\u7ea2\u8272\u65b9\u683c=\u653b\u51fb\u5c04\u7a0b\uff0c\u70b9\u654c\u4eba\u8fdc\u7a0b\u653b\u51fb\u3002\u70b9\u76f8\u90bb\u730e\u9f7f\u517d\u540e\uff0c\u9752\u8272\u5706\u70b9=\u6295\u63b7\u843d\u70b9\u3002"
	if data.attack_range > 1:
		return defense_text + "\u767d\u8272\u5706\u70b9=\u79fb\u52a8\uff1b\u7ea2\u8272\u65b9\u683c=\u653b\u51fb\u5c04\u7a0b\uff0c\u70b9\u654c\u4eba\u8fdc\u7a0b\u653b\u51fb\u3002"
	return defense_text + "\u767d\u8272\u5706\u70b9=\u53ef\u79fb\u52a8\u8303\u56f4\u3002"
