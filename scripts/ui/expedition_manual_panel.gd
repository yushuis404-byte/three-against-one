class_name ExpeditionManualPanel
extends Control

const BOOK_TEXTURE: Texture2D = preload("res://assets/ui/手册底图.png")
const PREV_ICON: Texture2D = preload("res://assets/ui/上一页.png")
const NEXT_ICON: Texture2D = preload("res://assets/ui/下一页.png")
const CLOSE_ICON: Texture2D = preload("res://assets/ui/cross.svg")
const CLOSE_ICON_GRAY70: Texture2D = preload("res://assets/ui/cross_gray70.svg")
const CLOSE_ICON_BLACK: Texture2D = preload("res://assets/ui/cross_black.svg")

const TEXT_DARK := Color(0.10, 0.09, 0.075)
const TEXT_GRAY := Color(0.32, 0.30, 0.26)
const TEXT_MUTED := Color(0.45, 0.42, 0.36)
const SELECTED_COLOR := Color(0.06, 0.055, 0.045)
const DIRECTORY_BLACK_100 := Color(0.0, 0.0, 0.0)
const DIRECTORY_GRAY_90 := Color(0.10, 0.10, 0.10)
const DIRECTORY_GRAY_80 := Color(0.20, 0.20, 0.20)
const DIRECTORY_GRAY_70 := Color(0.30, 0.30, 0.30)
const HOVER_COLOR := Color(0.16, 0.14, 0.11)
const PANEL_SIZE := Vector2(1920.0, 1080.0)
const BOOK_MARGIN := Vector2(120.0, 88.0)
const SPINE_GAP := 114.0
const PAGE_INSET_LEFT := 80.0
const PAGE_INSET_RIGHT := 80.0
const PAGE_INSET_TOP := 82.0
const PAGE_INSET_BOTTOM := 110.0

var _categories: Array[Dictionary] = []
var _collapsed: Dictionary = {}
var _item_buttons: Array[Button] = []
var _selected_path: Array[String] = []
var _selected_item: Dictionary = {}

var _item_box: VBoxContainer = null
var _content_title: Label = null
var _content_body: RichTextLabel = null
var _entry_image: TextureRect = null
var _close_button: TextureButton = null
var _close_button_base_position := Vector2.ZERO
var _prev_button: TextureButton = null
var _next_button: TextureButton = null


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_STOP
	clip_contents = true
	_build_content()
	_build_ui()
	_build_directory()
	_select_first_item()


func _build_ui() -> void:
	var book := TextureRect.new()
	book.texture = BOOK_TEXTURE
	book.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	book.stretch_mode = TextureRect.STRETCH_SCALE
	book.position = BOOK_MARGIN
	book.size = PANEL_SIZE - BOOK_MARGIN * 2.0
	book.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(book)

	_close_button = TextureButton.new()
	_close_button.texture_normal = CLOSE_ICON_GRAY70
	_close_button.texture_hover = CLOSE_ICON_BLACK
	_close_button.texture_pressed = CLOSE_ICON_BLACK
	_close_button.texture_disabled = CLOSE_ICON_GRAY70
	_close_button.ignore_texture_size = true
	_close_button.stretch_mode = TextureButton.STRETCH_KEEP_ASPECT_CENTERED
	_close_button.focus_mode = Control.FOCUS_NONE
	_close_button_base_position = Vector2(PANEL_SIZE.x - BOOK_MARGIN.x - 128.0, BOOK_MARGIN.y + 70.0)
	_close_button.position = _close_button_base_position
	_close_button.size = Vector2(28.0, 28.0)
	_close_button.button_down.connect(_on_close_button_down)
	_close_button.button_up.connect(_on_close_button_up)
	add_child(_close_button)

	var content_origin := BOOK_MARGIN + Vector2(50.0, 0.0)
	var content_size := PANEL_SIZE - BOOK_MARGIN * 2.0 - Vector2(100.0, 100.0)
	var page_width := (content_size.x - SPINE_GAP) * 0.5
	var page_height := content_size.y

	var left_rect := Rect2(
		content_origin + Vector2(PAGE_INSET_LEFT, PAGE_INSET_TOP),
		Vector2(page_width - PAGE_INSET_LEFT - 80.0, page_height - PAGE_INSET_TOP - PAGE_INSET_BOTTOM + 30.0)
	)
	var right_rect := Rect2(
		content_origin + Vector2(page_width + SPINE_GAP + 42.0, PAGE_INSET_TOP),
		Vector2(page_width - PAGE_INSET_RIGHT - 42.0, page_height - PAGE_INSET_TOP - PAGE_INSET_BOTTOM + 30.0)
	)

	var left_scroll := ScrollContainer.new()
	left_scroll.position = left_rect.position
	left_scroll.size = left_rect.size
	left_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	left_scroll.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(left_scroll)

	_item_box = VBoxContainer.new()
	_item_box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_item_box.add_theme_constant_override("separation", 5)
	left_scroll.add_child(_item_box)

	var right_page := VBoxContainer.new()
	right_page.position = right_rect.position
	right_page.size = right_rect.size
	right_page.add_theme_constant_override("separation", 12)
	right_page.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(right_page)

	_content_title = Label.new()
	_content_title.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_content_title.add_theme_font_size_override("font_size", 24)
	_content_title.add_theme_color_override("font_color", TEXT_DARK)
	right_page.add_child(_content_title)

	_entry_image = TextureRect.new()
	_entry_image.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_entry_image.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	_entry_image.custom_minimum_size = Vector2(0.0, 260.0)
	_entry_image.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_entry_image.visible = false
	right_page.add_child(_entry_image)

	_content_body = RichTextLabel.new()
	_content_body.bbcode_enabled = false
	_content_body.fit_content = false
	_content_body.scroll_active = true
	_content_body.selection_enabled = false
	_content_body.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_content_body.add_theme_font_size_override("normal_font_size", 17)
	_content_body.add_theme_color_override("default_color", TEXT_DARK)
	right_page.add_child(_content_body)

	_prev_button = TextureButton.new()
	_prev_button.texture_normal = PREV_ICON
	_prev_button.texture_hover = PREV_ICON
	_prev_button.texture_pressed = PREV_ICON
	_prev_button.texture_disabled = PREV_ICON
	_prev_button.ignore_texture_size = true
	_prev_button.stretch_mode = TextureButton.STRETCH_KEEP_ASPECT_CENTERED
	_prev_button.position = Vector2(left_rect.position.x, BOOK_MARGIN.y + book.size.y - 124.0)
	_prev_button.size = Vector2(80.0, 42.0)
	_prev_button.focus_mode = Control.FOCUS_NONE
	_prev_button.pressed.connect(_on_prev_pressed)
	add_child(_prev_button)

	_next_button = TextureButton.new()
	_next_button.texture_normal = NEXT_ICON
	_next_button.texture_hover = NEXT_ICON
	_next_button.texture_pressed = NEXT_ICON
	_next_button.texture_disabled = NEXT_ICON
	_next_button.ignore_texture_size = true
	_next_button.stretch_mode = TextureButton.STRETCH_KEEP_ASPECT_CENTERED
	_next_button.position = Vector2(right_rect.position.x + right_rect.size.x - 80.0, BOOK_MARGIN.y + book.size.y - 124.0)
	_next_button.size = Vector2(80.0, 42.0)
	_next_button.focus_mode = Control.FOCUS_NONE
	_next_button.pressed.connect(_on_next_pressed)
	add_child(_next_button)


func _build_content() -> void:
	_categories = [
		{
			"id": "guide",
			"title": "开拓指南",
			"children": [
				_make_text_item("游戏目标", "在五个阶段内扩张、建设、战争并争取胜利。\n\n你可以通过摧毁其他玩家主城、阶段结束得分，或围绕巨龙巢穴取得高级龙族科技来接近胜利。\n\n边境不是只奖励最会打架的人。看见更多、站住关键位置、让资源变成军力，才是长期优势。"),
				_make_text_item("回合流程", "单机模式中玩家依次行动；联机模式中三名玩家同时行动，全部确认后统一结算回合型内容。\n\n先结束回合意味着进入等待，也意味着把最后的临场调整机会交出去。"),
				_make_text_item("行动点 AP", "AP 用于移动、建造、战斗、采集、招募和部分技能。\n\n不要把所有 AP 都花在赶路上。真正决定局势的，往往不是你走了多远，而是你停在了哪里。"),
				_make_text_item("迷雾与视野", "单位和建筑会揭示周围区域。不同玩家拥有独立视野，迷雾外的信息不会共享。\n\n看见敌人之前，敌人可能已经看见你。视野本身就是一种资源。"),
				_make_text_item("资源采集", "单位站在可采资源点上会开始 5 秒采集。完成时消耗 1 AP 并获得资源；移动、攻击、死亡或执行其他动作会取消采集。\n\n快采集不等于安全采集。资源点的位置经常比它产出什么更重要。"),
				_make_text_item("战斗规则", "单位进入攻击后会按攻击频率持续作战，直到目标死亡、离开或战斗被系统打断。远程单位可以在射程内攻击，近战单位需要靠近。"),
			],
		},
		{
			"id": "codex",
			"title": "图鉴",
			"children": [
				{
					"id": "units",
					"title": "单位",
					"children": _make_unit_tree(),
				},
				_make_text_item("建筑", "条目结构：名称、类型、占地、成本、生命、入驻上限、产出或特殊效果。\n\n主城提供核心生存，仓库扩展储量，资源建筑连接生产链，兵营承担招募，塔防建筑提供自动防御。"),
				_make_text_item("资源点", "条目结构：名称、类型、产出、出现位置、战略用途。\n\n食物支撑招募，木材与石料支撑建设，铁矿进入中期工业，金币和龙族材料推动高级路线。"),
				_make_text_item("科技", "科技树不是独立分支，而是通用、阵营、巨龙之间交错的网络。部分高级兽人科技需要龙族战利品作为前置。"),
			],
		},
		{
			"id": "factions",
			"title": "阵营档案",
			"children": [
				_make_text_item("精灵", "关键词：森林、机动、视野、魔法。\n\n精灵适合围绕探索、视野、机动和魔法资源展开。它们不一定拥有最强的正面战斗力，但擅长提前发现机会。"),
				_make_text_item("矮人", "关键词：石墙、工业、矿脉、堡垒。\n\n矮人适合建筑经营、矿产开发、防御工事和重工业。发展较慢，但站稳后能形成坚固阵地。"),
				_make_text_item("兽人", "关键词：战争、兽群、压迫、以战养战。\n\n兽人适合军事压力、资源掠夺、部队协同和快速冲突。军团行动是兽人的核心节奏。"),
			],
		},
		{
			"id": "notes",
			"title": "战术笔记",
			"children": [
				_make_text_item("不要只看最近的资源", "最近的资源能养活你。\n关键位置的资源才能保护你。\n\n一座远处的铁矿，不一定只是为了采集。它也可能是一枚钉子，迫使敌人绕路、分兵，或者提前暴露自己的意图。"),
				_make_text_item("斥候不是为了活到最后", "斥候的价值，不在于它能不能打赢敌人。\n\n它的价值在于：它是否替你看见了敌人不想让你看见的东西。"),
				_make_text_item("种田不是安全", "边境上没有真正安全的后方。\n\n当你以为自己正在稳定发展时，敌人可能已经在你的视野边缘集结了第一支部队。"),
				_make_text_item("三方博弈", "三人对抗里，领先者会天然吸引压力。\n\n不要只问自己能不能赢这场战斗，也要问：这场战斗结束后，第三个人会得到什么。"),
			],
		},
		{
			"id": "lore",
			"title": "传说",
			"children": [
				_make_text_item("巨龙山传说", "没有人知道巨龙山究竟是山，还是一具沉睡的骸骨。\n\n精灵说它仍在呼吸，矮人说它内部藏着火，兽人则相信它终有一天会醒来。"),
				_make_text_item("符文碑残文之一", "当三族的旗帜再次插入边境，\n山心之龙将听见铁与火的声音。"),
				_make_text_item("古龙遗迹", "这里不是一座废墟。\n至少最早的远征者不是这样称呼它的。\n\n他们说，这些石柱曾经围绕着某种比王国更古老的东西。后来，柱子倒下了，王国也倒下了，只有龙晶仍在夜里发光。"),
			],
		},
	]


func _make_text_item(title: String, body: String) -> Dictionary:
	return {
		"id": title,
		"title": title,
		"body": body,
	}


func _make_unit_tree() -> Array[Dictionary]:
	var groups: Dictionary = {
		"精灵": [],
		"矮人": [],
		"兽人": [],
		"中立": [],
	}
	for entry in _make_unit_entries():
		var faction: String = str(entry.get("faction", "中立"))
		if not groups.has(faction):
			groups[faction] = []
		groups[faction].append(entry)
	var result: Array[Dictionary] = []
	for faction_name in ["精灵", "矮人", "兽人", "中立"]:
		result.append({
			"id": "unit_" + faction_name,
			"title": faction_name,
			"children": groups[faction_name],
		})
	return result


func _make_unit_entries() -> Array[Dictionary]:
	return [
		_unit_entry("精灵工人", "精灵", "工人", "采集 / 建造 / 入驻", "基础劳动力，负责资源采集、建筑建造和建筑入驻。", "res://assets/texture/character/elf/Worker/Elf-Worker-Idle.png"),
		_unit_entry("风行斥候", "精灵", "斥候", "视野 / 侦察 / 机动", "高视野机动单位，适合探索、监控边境和远程虚弱敌人。", "res://assets/texture/character/elf/Scout/Elf-Scout-Idle.png"),
		_unit_entry("月影刺客", "精灵", "近战", "突袭 / 收割", "擅长切入薄弱目标，依赖视野和机动创造攻击机会。", "res://assets/texture/character/elf/Moonshadow Assassin/Elf-Assassin-Idle.png"),
		_unit_entry("林影游侠", "精灵", "远程", "压制 / 拉扯", "在安全距离输出，适合与斥候视野和森林路线配合。", "res://assets/texture/character/elf/Ranger/Elf-Ranger-Idle.png"),
		_unit_entry("月刃舞者", "精灵", "近战", "机动 / 连续作战", "偏向中后期的精灵机动作战单位，用于撕开边境战线。", ""),
		_unit_entry("星藤守卫", "精灵", "肉盾", "守点 / 控制", "用于守住森林关键点和保护远程单位。", ""),
		_unit_entry("矮人工人", "矮人", "工人", "采集 / 建造 / 修复", "矮人的基础生产单位，适合入驻矿业建筑和修复防御建筑。", "res://assets/texture/character/dwarf/Worker/Dwarf-Worker-Idle.png"),
		_unit_entry("勘探者", "矮人", "斥候", "探矿 / 视野", "用于寻找矿脉、点亮资源区并给矮人工业路线铺路。", "res://assets/texture/character/dwarf/Prospector/Dwarf-Prospector-Idle.png"),
		_unit_entry("铁锤卫", "矮人", "近战", "前线 / 反击", "矮人基础近战卫士，适合守住防线缺口。", "res://assets/texture/character/dwarf/Hammer Guard/Dwarf-Hammer-Guard-Idle.png"),
		_unit_entry("盾誓卫", "矮人", "肉盾", "抗线 / 护卫", "承受伤害并保护弩手和塔防建筑。", ""),
		_unit_entry("山弩手", "矮人", "远程", "防线输出", "适合在城墙和塔防体系后方稳定输出。", "res://assets/texture/character/dwarf/Mountain Crossbow/Dwarf-Mountain-Crossbow-Idle.png"),
		_unit_entry("爆破工", "矮人", "特殊", "破墙 / 工程", "偏向工程破坏和阵地突破的特殊单位。", ""),
		_unit_entry("兽人工人", "兽人", "工人", "采集 / 建造", "兽人的基础劳动力，承担前期采集和战线建筑铺设。", "res://assets/texture/character/orc/Worker/Orc-Worker-Idle.png"),
		_unit_entry("猎齿兽", "兽人", "野兽", "高速 / 冲击", "可作为快速骚扰单位，也可以配合投石兵进行特殊投掷。", "res://assets/texture/character/Hunter-Beast/Hunter-tooth Beast.png"),
		_unit_entry("血斧兵", "兽人", "近战", "主力 / 进攻", "兽人基础进攻骨干，适合随军团冲锋压迫敌人。", "res://assets/texture/character/orc/Blood Axe Warrior/Orc-Idle.png"),
		_unit_entry("兽人杂兵", "兽人", "近战", "廉价 / 人海", "低成本单位，用数量制造占位、包围和消耗。", ""),
		_unit_entry("碎骨盾奴", "兽人", "肉盾", "廉价抗线", "低价肉盾单位，用来保护远程和维持军团阵型。", ""),
		_unit_entry("兽皮巨盾兵", "兽人", "肉盾", "高血量 / 推进", "更耐打的兽人盾兵，适合扛住正面火力。", ""),
		_unit_entry("兽人投石兵", "兽人", "远程", "远程 / 投掷猎齿兽", "射程较远，可消耗 AP 投掷猎齿兽，形成跨地形压力。", "res://assets/texture/character/orc/Orc-Slinger-Idle.png"),
		_unit_entry("屠龙战士", "兽人", "高级近战", "对龙 / 战利品路线", "需要龙族相关前置后解锁，代表兽人对巨龙科技的军事化利用。", ""),
		_unit_entry("龙骨巨盾兵", "兽人", "高级肉盾", "抗线 / 龙骨装备", "利用龙族材料强化防护的高阶盾兵。", ""),
		_unit_entry("龙血狂战士", "兽人", "高级近战", "爆发 / 高风险", "通过龙血路线强化攻击性的高阶兽人单位。", ""),
		_unit_entry("巨龙骑士", "兽人", "高级单位", "机动 / 终局压力", "兽人与龙族科技交汇后的高价值战略单位。", ""),
		_unit_entry("火焰亚龙", "中立", "亚龙", "范围攻击 / 火焰", "巨龙巢穴外围威胁之一，击败后可推动龙族相关路线。", "res://assets/texture/character/dragon/Fire-Dragon-Idle.png"),
		_unit_entry("冰霜亚龙", "中立", "亚龙", "控制 / 冰霜", "巨龙巢穴外围威胁之一，偏向限制和拖慢敌人。", "res://assets/texture/character/dragon/Ice-Dragon-Idle.png"),
		_unit_entry("毒液亚龙", "中立", "亚龙", "削弱 / 毒素", "巨龙巢穴外围威胁之一，擅长持续削弱目标。", "res://assets/texture/character/dragon/Poison-Dragon-Idle.png"),
		_unit_entry("古龙", "中立", "古龙", "高阶守卫", "守卫巨龙巢穴核心区域的强大中立单位。", "res://assets/texture/character/dragon/Ancient-Dragon-Idle.png"),
		_unit_entry("始祖龙", "中立", "首领", "巢穴核心 / 全局威胁", "占据巨龙巢穴中心的固定首领，攻击会威胁范围内玩家单位。", "res://assets/texture/character/dragon/Progenitor-Dragon-Idle.png"),
		_unit_entry("流浪商队", "中立", "事件", "贸易 / 机会", "阶段事件相关中立目标，用于补充资源和制造地图机会。", ""),
		_unit_entry("哥布林复仇队", "中立", "事件", "袭扰 / 阶段压力", "大阶段开始后出现的中立压力，用来打断过度安稳的发展。", ""),
	]


func _unit_entry(title: String, faction: String, role: String, use_case: String, body: String, texture_path: String) -> Dictionary:
	return {
		"id": title,
		"title": title,
		"type": "unit",
		"faction": faction,
		"role": role,
		"use_case": use_case,
		"body": body,
		"texture_path": texture_path,
	}


func _build_directory() -> void:
	_clear_directory()
	for category in _categories:
		_add_directory_item(category, [], 0)


func _add_directory_item(item: Dictionary, parent_path: Array[String], level: int) -> void:
	var title: String = str(item.get("title", "未命名"))
	var path := parent_path.duplicate()
	path.append(title)
	var has_children := item.has("children")
	var key := "/".join(path)
	var is_collapsed: bool = bool(_collapsed.get(key, level > 1 and has_children))
	var button := Button.new()
	button.focus_mode = Control.FOCUS_NONE
	button.alignment = HORIZONTAL_ALIGNMENT_LEFT
	button.custom_minimum_size = Vector2(0.0, 32.0)
	button.text = _directory_prefix(level, has_children, is_collapsed, key == "/".join(_selected_path)) + title
	button.add_theme_font_size_override("font_size", _directory_font_size(level))
	button.add_theme_color_override("font_color", _directory_color(level, key == "/".join(_selected_path)))
	button.add_theme_stylebox_override("normal", _empty_style())
	button.add_theme_stylebox_override("hover", _empty_style())
	button.add_theme_stylebox_override("pressed", _empty_style())
	button.pressed.connect(_on_directory_pressed.bind(item, path, has_children))
	_item_box.add_child(button)
	_item_buttons.append(button)
	if has_children and not is_collapsed:
		var children: Array = item.get("children", [])
		for child in children:
			var child_item: Dictionary = child
			_add_directory_item(child_item, path, level + 1)


func _directory_prefix(level: int, has_children: bool, is_collapsed: bool, selected: bool) -> String:
	var indent := ""
	for i in range(level):
		indent += "   "
	if has_children:
		return indent + ("▸ " if is_collapsed else "▾ ")
	if selected:
		return indent + "▸ "
	return indent + "  "


func _directory_font_size(level: int) -> int:
	if level == 0:
		return 21
	if level == 1:
		return 19
	return 17


func _directory_color(level: int, selected: bool) -> Color:
	if selected:
		return DIRECTORY_BLACK_100
	if level == 0:
		return DIRECTORY_BLACK_100
	if level == 1:
		return DIRECTORY_GRAY_90
	if level == 2:
		return DIRECTORY_GRAY_80
	return DIRECTORY_GRAY_70


func _empty_style() -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.0, 0.0, 0.0, 0.0)
	style.content_margin_left = 0.0
	style.content_margin_right = 0.0
	style.content_margin_top = 0.0
	style.content_margin_bottom = 0.0
	return style


func _on_directory_pressed(item: Dictionary, path: Array[String], has_children: bool) -> void:
	var key := "/".join(path)
	if has_children:
		_collapsed[key] = not bool(_collapsed.get(key, false))
		_build_directory()
	var selectable := not has_children or item.has("body") or item.has("texture_path")
	if selectable:
		_select_item(item, path)


func _select_first_item() -> void:
	var flat := _get_flat_items()
	if flat.is_empty():
		_content_title.text = ""
		_content_body.text = ""
		return
	var first: Dictionary = flat[0]
	_select_item(first.get("item", {}), first.get("path", []))


func _select_item(item: Dictionary, path: Array[String]) -> void:
	_selected_item = item
	_selected_path = path.duplicate()
	_expand_item_path(_selected_path)
	_content_title.text = str(item.get("title", "未命名"))
	_content_body.text = _format_item_text(item)
	_update_entry_image(item)
	_build_directory()
	_update_page_buttons()


func _format_item_text(item: Dictionary) -> String:
	if str(item.get("type", "")) == "unit":
		return _format_unit_entry_text(item)
	return str(item.get("body", ""))


func _format_unit_entry_text(item: Dictionary) -> String:
	var lines: Array[String] = []
	lines.append("阵营：" + str(item.get("faction", "未知")))
	lines.append("类型：" + str(item.get("role", "未知")))
	lines.append("定位：" + str(item.get("use_case", "未记录")))
	lines.append("")
	lines.append(str(item.get("body", "")))
	return "\n".join(lines)


func _update_entry_image(item: Dictionary) -> void:
	if _entry_image == null:
		return
	var path: String = str(item.get("texture_path", ""))
	if path.is_empty() or not ResourceLoader.exists(path):
		_entry_image.texture = null
		_entry_image.visible = false
		return
	_entry_image.texture = load(path)
	_entry_image.visible = true


func _expand_item_path(path: Array[String]) -> void:
	var current: Array[String] = []
	for i in range(maxi(0, path.size() - 1)):
		current.append(path[i])
		_collapsed["/".join(current)] = false


func _get_flat_items() -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	for category in _categories:
		_add_flat_items(category, [], result)
	return result


func _add_flat_items(item: Dictionary, parent_path: Array[String], result: Array[Dictionary]) -> void:
	var path := parent_path.duplicate()
	path.append(str(item.get("title", "未命名")))
	var children: Array = item.get("children", [])
	if item.has("body") or item.has("texture_path") or children.is_empty():
		result.append({
			"item": item,
			"path": path,
		})
	for child in children:
		var child_item: Dictionary = child
		_add_flat_items(child_item, path, result)


func _select_relative_item(delta: int) -> void:
	var flat := _get_flat_items()
	if flat.is_empty():
		return
	var current_index := 0
	var selected_key := "/".join(_selected_path)
	for i in range(flat.size()):
		var entry: Dictionary = flat[i]
		var path: Array[String] = entry.get("path", [])
		if "/".join(path) == selected_key:
			current_index = i
			break
	var next_index: int = clampi(current_index + delta, 0, flat.size() - 1)
	var next_entry: Dictionary = flat[next_index]
	_select_item(next_entry.get("item", {}), next_entry.get("path", []))


func _update_page_buttons() -> void:
	var flat := _get_flat_items()
	var current_index := -1
	var selected_key := "/".join(_selected_path)
	for i in range(flat.size()):
		var entry: Dictionary = flat[i]
		var path: Array[String] = entry.get("path", [])
		if "/".join(path) == selected_key:
			current_index = i
			break
	if _prev_button != null:
		_prev_button.disabled = current_index <= 0
	if _next_button != null:
		_next_button.disabled = current_index < 0 or current_index >= flat.size() - 1


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


func _on_close_button_down() -> void:
	if _close_button != null:
		_close_button.position = _close_button_base_position + Vector2(2.0, 2.0)


func _on_close_button_up() -> void:
	if _close_button != null:
		_close_button.position = _close_button_base_position
	_on_close_pressed()


func _on_close_pressed() -> void:
	visible = false
