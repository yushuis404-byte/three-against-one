extends Control
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

const FACTION_COLORS := [
	Color(0.18, 0.60, 0.15),
	Color(0.80, 0.65, 0.10),
	Color(0.80, 0.25, 0.15),
]
const FACTION_NAMES := ["精灵", "矮人", "兽人"]

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
	var color: Color = FACTION_COLORS[faction]

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
	_atk_label.text = str(data.atk)
	_mov_label.text = "%d" % data.move_max
	_vis_label.text = str(data.vision)
	_food_label.text = str(data.food_cost)

	show()
	queue_redraw()


func hide_panel() -> void:
	hide()
