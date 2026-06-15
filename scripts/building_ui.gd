extends Control
## 建造面板 UI — 双栏布局：左侧分类 + 右侧卡片网格 + 底部详情

signal building_selected(data: BuildingData)

var _turn_manager: Node = null
var _building_manager: Node = null
var _resource_tracker: Node = null
var _current_player := 0
var _selected_cat: BuildingData.BuildingCategory = BuildingData.BuildingCategory.INFRA

# 节点引用
var _title_label: Label
var _sidebar: VBoxContainer
var _card_grid: GridContainer
var _detail_name: Label
var _detail_cost: Label
var _detail_desc: Label
var _cat_buttons: Dictionary = {}  # BuildingCategory → Button

const CATEGORY_NAMES := {
	BuildingData.BuildingCategory.INFRA: "基础",
	BuildingData.BuildingCategory.T1_RESOURCE: "资源",
	BuildingData.BuildingCategory.MILITARY: "军事",
	BuildingData.BuildingCategory.SCOUT: "侦察",
	BuildingData.BuildingCategory.RECRUIT: "招募",
	BuildingData.BuildingCategory.TOWN_HALL: "主城",
}

const RESOURCE_NAMES := {
	"wood": "木材", "stone": "石料", "food": "食物",
	"iron": "铁矿", "magic_dust": "魔尘", "ancient_wood": "古木", "gold_ore": "金矿石",
}

const COST_NAMES := {
	"gold": "金币", "wood": "木材", "stone": "石料",
	"iron": "铁矿", "food": "食物",
}

const CATEGORY_ORDER := [
	BuildingData.BuildingCategory.INFRA,
	BuildingData.BuildingCategory.T1_RESOURCE,
	BuildingData.BuildingCategory.MILITARY,
	BuildingData.BuildingCategory.SCOUT,
	BuildingData.BuildingCategory.RECRUIT,
	BuildingData.BuildingCategory.TOWN_HALL,
]


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_PASS  # 根节点不拦截地图区域的点击
	_build_ui()
	_select_category(BuildingData.BuildingCategory.INFRA)


func set_turn_manager(tm: Node) -> void:
	_turn_manager = tm


func set_building_manager(bm: Node) -> void:
	_building_manager = bm


func set_resource_tracker(rt: Node) -> void:
	_resource_tracker = rt


func refresh(player: int) -> void:
	_current_player = player
	if _title_label:
		var fname := ""
		match player:
			0: fname = "精灵"
			1: fname = "矮人"
			2: fname = "兽人"
		_title_label.text = "[%s] 建造" % fname
	# 刷新当前分类的卡片（更新已建数量）
	_select_category(_selected_cat)


# ========== UI 构建 ==========

func _build_ui() -> void:
	# 主面板
	var panel := Panel.new()
	panel.name = "BuildingPanel"
	panel.offset_left = 1400.0
	panel.offset_top = 52.0
	panel.offset_right = 1900.0
	panel.offset_bottom = 700.0
	add_child(panel)

	var margin := MarginContainer.new()
	margin.name = "Margin"
	margin.add_theme_constant_override("margin_left", 6)
	margin.add_theme_constant_override("margin_right", 6)
	margin.add_theme_constant_override("margin_top", 4)
	margin.add_theme_constant_override("margin_bottom", 4)
	panel.add_child(margin)

	var main_vbox := VBoxContainer.new()
	main_vbox.name = "MainVBox"
	main_vbox.add_theme_constant_override("separation", 4)
	margin.add_child(main_vbox)

	# 标题
	_title_label = Label.new()
	_title_label.name = "TitleLabel"
	_title_label.text = "[精灵] 建造"
	_title_label.add_theme_font_size_override("font_size", 16)
	main_vbox.add_child(_title_label)

	var sep1 := HSeparator.new()
	main_vbox.add_child(sep1)

	# 双栏区域
	var split := HBoxContainer.new()
	split.name = "SplitHBox"
	split.size_flags_vertical = Control.SIZE_EXPAND_FILL
	split.add_theme_constant_override("separation", 4)
	main_vbox.add_child(split)

	# 左侧分类栏
	_sidebar = VBoxContainer.new()
	_sidebar.name = "SideBar"
	_sidebar.custom_minimum_size.x = 80
	_sidebar.add_theme_constant_override("separation", 2)
	split.add_child(_sidebar)

	for cat in CATEGORY_ORDER:
		var btn := Button.new()
		btn.name = "Btn_%d" % cat
		btn.text = CATEGORY_NAMES.get(cat, "?")
		btn.flat = true
		btn.alignment = HORIZONTAL_ALIGNMENT_LEFT
		btn.add_theme_font_size_override("font_size", 13)
		btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		_sidebar.add_child(btn)
		_cat_buttons[cat] = btn
		var captured_cat: BuildingData.BuildingCategory = cat
		btn.pressed.connect(func(): _select_category(captured_cat))

	# 右侧卡片区
	_card_grid = GridContainer.new()
	_card_grid.name = "CardGrid"
	_card_grid.columns = 2
	_card_grid.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_card_grid.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_card_grid.add_theme_constant_override("h_separation", 6)
	_card_grid.add_theme_constant_override("v_separation", 6)
	split.add_child(_card_grid)

	# 底部分隔
	var sep2 := HSeparator.new()
	main_vbox.add_child(sep2)

	# 底部详情面板
	var detail_panel := Panel.new()
	detail_panel.name = "DetailPanel"
	detail_panel.custom_minimum_size.y = 60
	var detail_style := StyleBoxFlat.new()
	detail_style.bg_color = Color(0.08, 0.08, 0.08, 0.6)
	detail_style.border_color = Color(0.25, 0.25, 0.25, 0.4)
	detail_style.border_width_top = 1
	detail_style.corner_radius_top_left = 3
	detail_style.corner_radius_top_right = 3
	detail_style.corner_radius_bottom_left = 3
	detail_style.corner_radius_bottom_right = 3
	detail_panel.add_theme_stylebox_override("panel", detail_style)
	main_vbox.add_child(detail_panel)

	var detail_margin := MarginContainer.new()
	detail_margin.add_theme_constant_override("margin_left", 8)
	detail_margin.add_theme_constant_override("margin_right", 8)
	detail_margin.add_theme_constant_override("margin_top", 4)
	detail_margin.add_theme_constant_override("margin_bottom", 4)
	detail_panel.add_child(detail_margin)

	var detail_vbox := VBoxContainer.new()
	detail_vbox.add_theme_constant_override("separation", 2)
	detail_margin.add_child(detail_vbox)

	_detail_name = Label.new()
	_detail_name.text = "点击建筑查看详情"
	_detail_name.add_theme_font_size_override("font_size", 13)
	_detail_name.add_theme_color_override("font_color", Color(0.9, 0.9, 0.9))
	detail_vbox.add_child(_detail_name)

	_detail_cost = Label.new()
	_detail_cost.text = ""
	_detail_cost.add_theme_font_size_override("font_size", 12)
	_detail_cost.add_theme_color_override("font_color", Color(0.9, 0.9, 0.5))
	detail_vbox.add_child(_detail_cost)

	_detail_desc = Label.new()
	_detail_desc.text = ""
	_detail_desc.add_theme_font_size_override("font_size", 11)
	_detail_desc.add_theme_color_override("font_color", Color(0.7, 0.7, 0.7))
	detail_vbox.add_child(_detail_desc)


# ========== 分类切换 ==========

func _select_category(cat: BuildingData.BuildingCategory) -> void:
	_selected_cat = cat

	# 更新按钮高亮
	var selected_style := StyleBoxFlat.new()
	selected_style.bg_color = Color(0.24, 0.24, 0.24, 0.8)
	selected_style.corner_radius_top_left = 3
	selected_style.corner_radius_top_right = 3
	selected_style.corner_radius_bottom_left = 3
	selected_style.corner_radius_bottom_right = 3

	for c in _cat_buttons:
		var btn: Button = _cat_buttons[c]
		if c == cat:
			btn.add_theme_stylebox_override("normal", selected_style)
		else:
			btn.remove_theme_stylebox_override("normal")

	# 重建卡片
	_rebuild_cards(cat)


func _rebuild_cards(cat: BuildingData.BuildingCategory) -> void:
	# 清空旧卡片
	for child in _card_grid.get_children():
		child.queue_free()

	var templates_by_cat: Dictionary = BuildingData.get_templates()
	var templates: Array = templates_by_cat.get(cat, [])

	var card_normal := _make_card_style()
	var card_hover := _make_card_hover_style()

	for t in templates:
		var d: BuildingData = t
		var card := Panel.new()
		card.name = "Card_%s" % d.name
		card.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		card.custom_minimum_size = Vector2(180, 70)
		card.add_theme_stylebox_override("panel", card_normal)
		card.mouse_filter = Control.MOUSE_FILTER_STOP
		_card_grid.add_child(card)

		# hover 效果
		card.mouse_entered.connect(func():
			card.add_theme_stylebox_override("panel", card_hover)
		)
		card.mouse_exited.connect(func():
			card.add_theme_stylebox_override("panel", card_normal)
		)

		# 点击 → 更新详情 + 发射信号
		var captured_d: BuildingData = d
		card.gui_input.connect(func(event: InputEvent):
			if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
				_update_detail(captured_d)
				building_selected.emit(captured_d)
		)

		var card_margin := MarginContainer.new()
		card_margin.mouse_filter = Control.MOUSE_FILTER_IGNORE
		card_margin.add_theme_constant_override("margin_left", 6)
		card_margin.add_theme_constant_override("margin_right", 6)
		card_margin.add_theme_constant_override("margin_top", 4)
		card_margin.add_theme_constant_override("margin_bottom", 4)
		card.add_child(card_margin)

		var card_vbox := VBoxContainer.new()
		card_vbox.mouse_filter = Control.MOUSE_FILTER_IGNORE
		card_vbox.add_theme_constant_override("separation", 1)
		card_margin.add_child(card_vbox)

		# 行1: 建筑名 + 已建数
		var row1 := HBoxContainer.new()
		row1.mouse_filter = Control.MOUSE_FILTER_IGNORE
		card_vbox.add_child(row1)

		var name_label := Label.new()
		name_label.text = d.name
		name_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
		name_label.add_theme_font_size_override("font_size", 13)
		name_label.add_theme_color_override("font_color", Color(0.9, 0.9, 0.9))
		name_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		row1.add_child(name_label)

		var built_count := _get_built_count(d.name)
		var count_label := Label.new()
		count_label.text = "%d/%d" % [built_count, d.max_per_faction]
		count_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
		count_label.add_theme_font_size_override("font_size", 11)
		count_label.add_theme_color_override("font_color", Color(0.55, 0.55, 0.55))
		row1.add_child(count_label)

		# 行2: 费用
		var cost_text := _format_cost(d)
		if not cost_text.is_empty():
			var cost_label := Label.new()
			cost_label.text = cost_text
			cost_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
			cost_label.add_theme_font_size_override("font_size", 11)
			cost_label.add_theme_color_override("font_color", Color(0.9, 0.9, 0.5))
			card_vbox.add_child(cost_label)

		# 行3: 产出
		var prod_text := _format_production(d)
		if not prod_text.is_empty():
			var prod_label := Label.new()
			prod_label.text = prod_text
			prod_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
			prod_label.add_theme_font_size_override("font_size", 11)
			prod_label.add_theme_color_override("font_color", Color(0.5, 0.9, 0.5))
			card_vbox.add_child(prod_label)


# ========== 详情面板 ==========

func _update_detail(d: BuildingData) -> void:
	var built_count := _get_built_count(d.name)
	_detail_name.text = "%s  (%d/%d)" % [d.name, built_count, d.max_per_faction]

	var cost_text := _format_cost(d)
	_detail_cost.text = "费用: %s" % cost_text if not cost_text.is_empty() else "费用: 免费"

	var prod_text := _format_production(d)
	_detail_desc.text = d.description


# ========== 样式 ==========

func _make_card_style() -> StyleBoxFlat:
	var s := StyleBoxFlat.new()
	s.bg_color = Color(0.12, 0.12, 0.12, 0.7)
	s.border_color = Color(0.3, 0.3, 0.3, 0.5)
	s.border_width_top = 1
	s.border_width_bottom = 1
	s.border_width_left = 1
	s.border_width_right = 1
	s.corner_radius_top_left = 4
	s.corner_radius_top_right = 4
	s.corner_radius_bottom_left = 4
	s.corner_radius_bottom_right = 4
	return s


func _make_card_hover_style() -> StyleBoxFlat:
	var s := StyleBoxFlat.new()
	s.bg_color = Color(0.18, 0.18, 0.18, 0.8)
	s.border_color = Color(0.5, 0.5, 0.5, 0.7)
	s.border_width_top = 1
	s.border_width_bottom = 1
	s.border_width_left = 1
	s.border_width_right = 1
	s.corner_radius_top_left = 4
	s.corner_radius_top_right = 4
	s.corner_radius_bottom_left = 4
	s.corner_radius_bottom_right = 4
	return s


# ========== 格式化 ==========

func _format_cost(d: BuildingData) -> String:
	var parts: PackedStringArray = []
	if d.cost_gold > 0: parts.append("%d%s" % [d.cost_gold, COST_NAMES["gold"]])
	if d.cost_wood > 0: parts.append("%d%s" % [d.cost_wood, COST_NAMES["wood"]])
	if d.cost_stone > 0: parts.append("%d%s" % [d.cost_stone, COST_NAMES["stone"]])
	if d.cost_iron > 0: parts.append("%d%s" % [d.cost_iron, COST_NAMES["iron"]])
	if d.cost_food > 0: parts.append("%d%s" % [d.cost_food, COST_NAMES["food"]])
	return " ".join(parts)


func _format_production(d: BuildingData) -> String:
	if d.production.is_empty():
		return ""
	var parts: PackedStringArray = []
	for key in d.production:
		var rname: String = RESOURCE_NAMES.get(key, key)
		parts.append("+%d%s/回合" % [d.production[key], rname])
	return " ".join(parts)


func _get_built_count(building_name: String) -> int:
	if not _building_manager or not _building_manager.has_method("count_buildings"):
		return 0
	return _building_manager.count_buildings(_current_player, building_name)
