class_name ExpeditionManualPanel
extends Control

const PANEL_COLOR := Color(0.035, 0.028, 0.020, 0.94)
const BORDER_COLOR := Color(0.72, 0.56, 0.30, 0.65)
const SIDEBAR_COLOR := Color(0.08, 0.065, 0.045, 0.88)
const CONTENT_COLOR := Color(0.10, 0.085, 0.060, 0.86)
const CLOSE_SIZE := Vector2(72.0, 28.0)

var _category_buttons: Dictionary = {}
var _item_buttons: Array[Button] = []
var _categories: Array[Dictionary] = []
var _collapsed_categories: Dictionary = {}
var _selected_category := ""
var _selected_item := ""
var _title_label: Label = null
var _subtitle_label: Label = null
var _category_box: VBoxContainer = null
var _item_box: VBoxContainer = null
var _content_label: RichTextLabel = null
var _close_button: Button = null
var _prev_button: Button = null
var _next_button: Button = null


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_STOP
	clip_contents = true
	_build_content()
	_build_ui()
	_build_directory()
	_select_first_item()


func _build_ui() -> void:
	var root := PanelContainer.new()
	root.name = "ExpeditionManualRoot"
	root.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.mouse_filter = Control.MOUSE_FILTER_STOP
	var root_style := StyleBoxFlat.new()
	root_style.bg_color = PANEL_COLOR
	root_style.border_color = BORDER_COLOR
	root_style.set_border_width_all(2)
	root_style.set_corner_radius_all(6)
	root.add_theme_stylebox_override("panel", root_style)
	add_child(root)

	var outer_margin := MarginContainer.new()
	outer_margin.add_theme_constant_override("margin_left", 24)
	outer_margin.add_theme_constant_override("margin_top", 18)
	outer_margin.add_theme_constant_override("margin_right", 24)
	outer_margin.add_theme_constant_override("margin_bottom", 18)
	root.add_child(outer_margin)

	var layout := VBoxContainer.new()
	layout.add_theme_constant_override("separation", 10)
	outer_margin.add_child(layout)

	var header := HBoxContainer.new()
	header.custom_minimum_size = Vector2(0.0, 32.0)
	layout.add_child(header)

	var header_text := VBoxContainer.new()
	header_text.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	header.add_child(header_text)

	_title_label = Label.new()
	_title_label.text = "远征手册"
	_title_label.add_theme_font_size_override("font_size", 24)
	_title_label.add_theme_color_override("font_color", Color(0.96, 0.86, 0.58))
	_title_label.visible = false
	header_text.add_child(_title_label)

	_subtitle_label = Label.new()
	_subtitle_label.text = "开拓指南 / 图鉴 / 阵营档案 / 战术笔记 / 传说"
	_subtitle_label.add_theme_font_size_override("font_size", 13)
	_subtitle_label.add_theme_color_override("font_color", Color(0.78, 0.70, 0.58))
	_subtitle_label.visible = false
	header_text.add_child(_subtitle_label)

	_close_button = Button.new()
	_close_button.text = "关闭"
	_close_button.custom_minimum_size = CLOSE_SIZE
	_close_button.focus_mode = Control.FOCUS_NONE
	_close_button.pressed.connect(_on_close_pressed)
	header.add_child(_close_button)

	var body := HBoxContainer.new()
	body.size_flags_vertical = Control.SIZE_EXPAND_FILL
	body.add_theme_constant_override("separation", 14)
	layout.add_child(body)

	var category_panel := PanelContainer.new()
	category_panel.custom_minimum_size = Vector2(380.0, 0.0)
	var side_style := StyleBoxFlat.new()
	side_style.bg_color = SIDEBAR_COLOR
	side_style.border_color = Color(0.50, 0.38, 0.22, 0.55)
	side_style.set_border_width_all(1)
	side_style.set_corner_radius_all(4)
	category_panel.add_theme_stylebox_override("panel", side_style)
	body.add_child(category_panel)

	var category_margin := MarginContainer.new()
	category_margin.add_theme_constant_override("margin_left", 12)
	category_margin.add_theme_constant_override("margin_top", 12)
	category_margin.add_theme_constant_override("margin_right", 12)
	category_margin.add_theme_constant_override("margin_bottom", 12)
	category_panel.add_child(category_margin)

	var left_page := VBoxContainer.new()
	left_page.add_theme_constant_override("separation", 10)
	category_margin.add_child(left_page)

	var item_scroll := ScrollContainer.new()
	item_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	item_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	left_page.add_child(item_scroll)

	_item_box = VBoxContainer.new()
	_item_box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_item_box.add_theme_constant_override("separation", 7)
	item_scroll.add_child(_item_box)

	var note_label := Label.new()
	note_label.text = "远征者批注：先看见，再决定。"
	note_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	note_label.add_theme_font_size_override("font_size", 13)
	note_label.add_theme_color_override("font_color", Color(0.74, 0.66, 0.50))
	left_page.add_child(note_label)

	_prev_button = Button.new()
	_prev_button.text = "上一页"
	_prev_button.custom_minimum_size = Vector2(96.0, 32.0)
	_prev_button.focus_mode = Control.FOCUS_NONE
	_prev_button.pressed.connect(_on_prev_pressed)
	left_page.add_child(_prev_button)

	var content_panel := PanelContainer.new()
	content_panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	content_panel.size_flags_vertical = Control.SIZE_EXPAND_FILL
	var content_style := StyleBoxFlat.new()
	content_style.bg_color = CONTENT_COLOR
	content_style.border_color = Color(0.58, 0.44, 0.24, 0.60)
	content_style.set_border_width_all(1)
	content_style.set_corner_radius_all(4)
	content_panel.add_theme_stylebox_override("panel", content_style)
	body.add_child(content_panel)

	var content_margin := MarginContainer.new()
	content_margin.add_theme_constant_override("margin_left", 24)
	content_margin.add_theme_constant_override("margin_top", 22)
	content_margin.add_theme_constant_override("margin_right", 24)
	content_margin.add_theme_constant_override("margin_bottom", 22)
	content_panel.add_child(content_margin)

	var right_page := VBoxContainer.new()
	right_page.add_theme_constant_override("separation", 10)
	content_margin.add_child(right_page)

	_content_label = RichTextLabel.new()
	_content_label.bbcode_enabled = true
	_content_label.fit_content = false
	_content_label.scroll_active = true
	_content_label.selection_enabled = false
	_content_label.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_content_label.add_theme_font_size_override("normal_font_size", 17)
	_content_label.add_theme_font_size_override("bold_font_size", 19)
	_content_label.add_theme_color_override("default_color", Color(0.92, 0.86, 0.74))
	right_page.add_child(_content_label)

	var next_row := HBoxContainer.new()
	next_row.alignment = BoxContainer.ALIGNMENT_END
	right_page.add_child(next_row)

	_next_button = Button.new()
	_next_button.text = "下一页"
	_next_button.custom_minimum_size = Vector2(96.0, 32.0)
	_next_button.focus_mode = Control.FOCUS_NONE
	_next_button.pressed.connect(_on_next_pressed)
	next_row.add_child(_next_button)


func _build_content() -> void:
	_categories = [
		{
			"id": "guide",
			"title": "开拓指南",
			"items": [
				{"title": "游戏目标", "body": "[b]结论[/b]\n在五个阶段内扩张、建设、战争并争取最高胜利条件。\n\n[b]规则说明[/b]\n你可以通过摧毁其他玩家主城、完成阶段结算得分，或围绕巨龙巢穴争夺高级龙族科技来接近胜利。\n\n[b]远征者经验[/b]\n边境不是只奖励最会打架的人。看见更多、站住关键位置、让资源变成军力，才是长期优势。"},
				{"title": "回合流程", "body": "[b]规则说明[/b]\n单机模式中玩家依次行动；联机模式中三名玩家同时行动，全部确认后统一结算回合型内容。\n\n[b]远征者经验[/b]\n先结束回合意味着你进入等待，也意味着你把最后的临场调整机会交了出去。"},
				{"title": "行动点 AP", "body": "[b]规则说明[/b]\nAP 用于移动、建造、战斗、采集、招募和部分技能。当前每回合刷新节奏偏快，用来鼓励更多主动行动。\n\n[b]远征者经验[/b]\n不要把所有 AP 都花在赶路上。真正决定局势的，往往不是你走了多远，而是你停在了哪里。"},
				{"title": "迷雾与视野", "body": "[b]规则说明[/b]\n单位和建筑会揭示周围区域。不同玩家拥有独立视野，迷雾外的信息不会共享。\n\n[b]远征者经验[/b]\n看见敌人之前，敌人可能已经看见你。视野本身就是一种资源。"},
				{"title": "资源采集", "body": "[b]规则说明[/b]\n单位站在可采资源点上会开始 5 秒采集。完成时消耗 1 AP 并获得资源；移动、攻击、死亡或执行其他动作会取消采集。\n\n[b]远征者经验[/b]\n快采集不等于安全采集。资源点的位置经常比它产出什么更重要。"},
				{"title": "战斗规则", "body": "[b]规则说明[/b]\n单位进入攻击后会按攻击频率持续作战，直到目标死亡、离开或战斗被系统打断。远程单位可以在射程内攻击，近战单位需要靠近。\n\n[b]远征者经验[/b]\n战斗不是目的，而是争夺地图控制权的手段。"},
			],
		},
		{
			"id": "codex",
			"title": "图鉴",
			"items": [
				{"title": "单位", "body": "[b]条目结构[/b]\n名称、类型、基础数值、招募来源、战略用途、背景描述。\n\n[b]当前重点[/b]\n工人负责建设与资源，斥候负责视野与机动，守卫与盾兵负责阵线，远程单位负责压制，龙族单位属于高价值战略力量。"},
				{"title": "建筑", "body": "[b]条目结构[/b]\n名称、类型、占地、成本、生命、入驻上限、产出或特殊效果。\n\n[b]当前重点[/b]\n主城提供核心生存，仓库扩展储量，资源建筑连接生产链，兵营承担招募，塔防建筑提供自动防御。"},
				{"title": "资源点", "body": "[b]条目结构[/b]\n名称、类型、产出、出现位置、战略用途。\n\n[b]当前重点[/b]\n食物支撑招募，木材与石料支撑建设，铁矿进入中期工业，金币和龙族材料推动高级路线。"},
				{"title": "中立生物", "body": "[b]当前重点[/b]\n亚龙、古龙、始祖龙共同构成巨龙巢穴玩法。击败龙族生物不仅是战斗目标，也会影响后续科技路线。"},
				{"title": "科技", "body": "[b]当前重点[/b]\n科技树不是独立分支，而是通用、阵营、巨龙之间交错的网络。部分高级兽人科技需要龙族战利品作为前置。"},
			],
		},
		{
			"id": "factions",
			"title": "阵营档案",
			"items": [
				{"title": "精灵", "body": "[b]关键词[/b]\n森林、机动、视野、魔法。\n\n[b]玩法倾向[/b]\n精灵适合围绕探索、视野、机动和魔法资源展开。它们不一定拥有最强的正面战斗力，但擅长提前发现机会。"},
				{"title": "矮人", "body": "[b]关键词[/b]\n石墙、工业、矿脉、堡垒。\n\n[b]玩法倾向[/b]\n矮人适合建筑经营、矿产开发、防御工事和重工业。发展较慢，但站稳后能形成坚固阵地。"},
				{"title": "兽人", "body": "[b]关键词[/b]\n战争、兽群、压迫、以战养战。\n\n[b]玩法倾向[/b]\n兽人适合军事压力、资源掠夺、部队协同和快速冲突。战团行动是兽人的核心节奏。"},
			],
		},
		{
			"id": "notes",
			"title": "战术笔记",
			"items": [
				{"title": "不要只看最近的资源", "body": "最近的资源能养活你。\n关键位置的资源才能保护你。\n\n一座远处的铁矿，不一定只是为了采集。它也可能是一枚钉子，迫使敌人绕路、分兵，或者提前暴露自己的意图。"},
				{"title": "斥候不是为了活到最后", "body": "斥候的价值，不在于它能不能打赢敌人。\n\n它的价值在于：它是否替你看见了敌人不想让你看见的东西。"},
				{"title": "种田不是安全", "body": "边境上没有真正安全的后方。\n\n当你以为自己正在稳定发展时，敌人可能已经在你的视野边缘集结了第一支部队。"},
				{"title": "三方博弈", "body": "三人对抗里，领先者会天然吸引压力。\n\n不要只问自己能不能赢这场战斗，也要问：这场战斗结束后，第三个人会得到什么。"},
			],
		},
		{
			"id": "lore",
			"title": "传说",
			"items": [
				{"title": "巨龙山传说", "body": "没有人知道巨龙山究竟是山，还是一具沉睡的骸骨。\n\n精灵说它仍在呼吸，矮人说它内部藏着火，兽人则相信它终有一天会醒来。\n\n三族都声称自己只是来开拓边境。但所有人的道路，最终都指向了那座山。"},
				{"title": "符文碑残文之一", "body": "当三族的旗帜再次插入边境，\n山心之龙将听见铁与火的声音。"},
				{"title": "古龙遗迹", "body": "这里不是一座废墟。\n至少最早的远征者不是这样称呼它的。\n\n他们说，这些石柱曾经围绕着某种比王国更古老的东西。后来，柱子倒下了，王国也倒下了，只有龙晶仍在夜里发光。"},
			],
		},
	]


func _build_directory() -> void:
	_clear_directory()
	if _collapsed_categories.is_empty():
		for i in range(_categories.size()):
			var init_category: Dictionary = _categories[i]
			_collapsed_categories[str(init_category.get("id", ""))] = i != 0
	for category in _categories:
		var category_id: String = str(category.get("id", ""))
		var category_title: String = str(category.get("title", category_id))
		var is_collapsed: bool = bool(_collapsed_categories.get(category_id, false))
		var header := Button.new()
		header.text = ("+ " if is_collapsed else "- ") + category_title
		header.custom_minimum_size = Vector2(0.0, 34.0)
		header.focus_mode = Control.FOCUS_NONE
		header.alignment = HORIZONTAL_ALIGNMENT_LEFT
		header.add_theme_font_size_override("font_size", 16)
		header.add_theme_color_override("font_color", Color(0.96, 0.82, 0.48))
		header.pressed.connect(_toggle_category.bind(category_id))
		_item_box.add_child(header)
		if is_collapsed:
			continue
		var items: Array = category.get("items", [])
		for item in items:
			var item_data: Dictionary = item
			var title: String = str(item_data.get("title", "未命名"))
			var button := Button.new()
			button.text = "    " + title
			button.custom_minimum_size = Vector2(0.0, 34.0)
			button.focus_mode = Control.FOCUS_NONE
			button.alignment = HORIZONTAL_ALIGNMENT_LEFT
			button.pressed.connect(_select_item_in_category.bind(category_id, title))
			_item_box.add_child(button)
			_item_buttons.append(button)


func _toggle_category(category_id: String) -> void:
	var current: bool = bool(_collapsed_categories.get(category_id, false))
	_collapsed_categories[category_id] = not current
	_build_directory()
	if not bool(_collapsed_categories.get(_selected_category, false)):
		_select_item(_selected_item)


func _select_first_item() -> void:
	for category in _categories:
		var items: Array = category.get("items", [])
		if items.size() > 0:
			var first_item: Dictionary = items[0]
			_select_item_in_category(str(category.get("id", "")), str(first_item.get("title", "")))
			return
	_selected_category = ""
	_selected_item = ""
	_content_label.text = ""


func _select_item_in_category(category_id: String, title: String) -> void:
	_selected_category = category_id
	_select_item(title)


func _select_category(id: String) -> void:
	_selected_category = id
	for key in _category_buttons.keys():
		var button: Button = _category_buttons[key]
		button.disabled = str(key) == id
	_clear_item_buttons()
	var category := _find_category(id)
	var items: Array = category.get("items", [])
	for item in items:
		var item_data: Dictionary = item
		var button := Button.new()
		button.text = str(item_data.get("title", "未命名"))
		button.custom_minimum_size = Vector2(0.0, 38.0)
		button.focus_mode = Control.FOCUS_NONE
		button.alignment = HORIZONTAL_ALIGNMENT_LEFT
		button.pressed.connect(_select_item.bind(str(item_data.get("title", ""))))
		_item_box.add_child(button)
		_item_buttons.append(button)
	if items.size() > 0:
		var first_item: Dictionary = items[0]
		_select_item(str(first_item.get("title", "")))
	else:
		_selected_item = ""
		_content_label.text = ""


func _select_item(title: String) -> void:
	_selected_item = title
	for button in _item_buttons:
		button.disabled = button.text.strip_edges() == title
	var item := _find_item(_selected_category, title)
	var category := _find_category(_selected_category)
	var category_title: String = str(category.get("title", "远征手册"))
	var body: String = str(item.get("body", ""))
	_content_label.text = "[font_size=24][b]%s[/b][/font_size]\n[color=#c9b47d]%s / 已解锁[/color]\n\n[bgcolor=#2a2318][color=#d7c08a] 展示区 [/color][/bgcolor]\n这里后续可以根据条目类型显示单位立绘、建筑贴图、资源图标、阵营代表图或传说插图。\n\n[bgcolor=#322819][color=#f0d991] 摘要 [/color][/bgcolor]\n这是当前条目的规则、用途和世界观记录。\n\n%s" % [
		title,
		category_title,
		body,
	]
	_update_page_buttons()


func _find_category(id: String) -> Dictionary:
	for category in _categories:
		if str(category.get("id", "")) == id:
			return category
	return {}


func _find_item(category_id: String, title: String) -> Dictionary:
	var category := _find_category(category_id)
	var items: Array = category.get("items", [])
	for item in items:
		var item_data: Dictionary = item
		if str(item_data.get("title", "")) == title:
			return item_data
	return {}


func _clear_item_buttons() -> void:
	for button in _item_buttons:
		if is_instance_valid(button):
			button.queue_free()
	_item_buttons.clear()


func _clear_directory() -> void:
	if _item_box == null:
		return
	for child in _item_box.get_children():
		_item_box.remove_child(child)
		child.queue_free()
	_item_buttons.clear()


func _on_prev_pressed() -> void:
	_select_relative_item(-1)


func _on_next_pressed() -> void:
	_select_relative_item(1)


func _select_relative_item(delta: int) -> void:
	var flat_items: Array[Dictionary] = _get_flat_items()
	if flat_items.is_empty():
		return
	var current_index := 0
	for i in range(flat_items.size()):
		var entry: Dictionary = flat_items[i]
		if str(entry.get("category_id", "")) == _selected_category and str(entry.get("title", "")) == _selected_item:
			current_index = i
			break
	var next_index: int = clampi(current_index + delta, 0, flat_items.size() - 1)
	var next_entry: Dictionary = flat_items[next_index]
	var category_id: String = str(next_entry.get("category_id", ""))
	var title: String = str(next_entry.get("title", ""))
	_collapsed_categories[category_id] = false
	_build_directory()
	_select_item_in_category(category_id, title)


func _get_flat_items() -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	for category in _categories:
		var category_id: String = str(category.get("id", ""))
		var items: Array = category.get("items", [])
		for item in items:
			var item_data: Dictionary = item
			result.append({
				"category_id": category_id,
				"title": str(item_data.get("title", "")),
			})
	return result


func _update_page_buttons() -> void:
	var flat_items: Array[Dictionary] = _get_flat_items()
	var current_index := -1
	for i in range(flat_items.size()):
		var entry: Dictionary = flat_items[i]
		if str(entry.get("category_id", "")) == _selected_category and str(entry.get("title", "")) == _selected_item:
			current_index = i
			break
	if _prev_button != null:
		_prev_button.disabled = current_index <= 0
	if _next_button != null:
		_next_button.disabled = current_index < 0 or current_index >= flat_items.size() - 1


func _on_close_pressed() -> void:
	visible = false
