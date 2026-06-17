extends Control
## 哥布林海克斯商队面板 — 卡牌选商品，最多选 3 个，价格递涨
##
## 弹出方式类似云顶选海克斯：4 张商品卡牌，点击选中/取消
## 独立于 BuildingUI，挂在 UI CanvasLayer 下

signal market_confirmed(player: int, selected_indices: Array)  # 确认交易
signal market_skipped(player: int)                              # 跳过

# ========== 面板尺寸 ==========
const PANEL_W := 800
const PANEL_H := 500
const CARD_W := 160
const CARD_H := 200
const CARD_GAP := 20

# ========== 商品数据结构 ==========
# # TODO: 奖励池内容待填充 — 当前为占位数据
var _placeholder_goods: Array = [
	{ "name": "木材", "icon": "🪵", "price": 10, "key": "wood", "tier": "basic" },
	{ "name": "石料", "icon": "🪨", "price": 10, "key": "stone", "tier": "basic" },
	{ "name": "铁矿", "icon": "⛏️", "price": 15, "key": "iron", "tier": "basic" },
	{ "name": "食物", "icon": "🍖", "price": 8, "key": "food", "tier": "basic" },
	{ "name": "魔尘", "icon": "✨", "price": 25, "key": "magic_dust", "tier": "rare" },
	{ "name": "古木", "icon": "🌲", "price": 20, "key": "ancient_wood", "tier": "rare" },
	{ "name": "金矿石", "icon": "💎", "price": 30, "key": "gold_ore", "tier": "rare" },
	{ "name": "金币", "icon": "🪙", "price": 15, "key": "gold", "tier": "basic" },
]

# ========== 状态 ==========
var _current_player: int = -1
var _offer_goods: Array = []        # 本次展示的商品列表（4 个）
var _selected: Array = []           # 已选商品的 indices
var _price_multiplier: float = 1.0  # 好感度价格倍率

# 外部引用
var _resource_tracker: Node = null
var _neutral_manager: Node = null

# UI 节点引用
var _bg: ColorRect = null
var _panel: ColorRect = null
var _title_label: Label = null
var _selected_label: Label = null
var _total_label: Label = null
var _confirm_btn: Button = null
var _skip_btn: Button = null
var _cards: Array = []  # Array[Dictionary] { rect, label, price_label, index, selected_rect }


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_STOP
	_build_ui()
	hide()


func set_resource_tracker(rt: Node) -> void:
	_resource_tracker = rt


func set_neutral_manager(nm: Node) -> void:
	_neutral_manager = nm


# ========== UI 构建 ==========

func _build_ui() -> void:
	# 半透明背景遮罩
	_bg = ColorRect.new()
	_bg.color = Color(0, 0, 0, 0.6)
	_bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_bg.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(_bg)

	# 主面板
	_panel = ColorRect.new()
	_panel.color = Color(0.12, 0.12, 0.15, 0.95)
	_panel.size = Vector2(PANEL_W, PANEL_H)
	_panel.position = Vector2(
		(get_viewport_rect().size.x - PANEL_W) / 2.0,
		(get_viewport_rect().size.y - PANEL_H) / 2.0
	)
	_panel.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(_panel)

	# 标题
	_title_label = Label.new()
	_title_label.text = "🧑‍🌾 哥布林商队抵达！"
	_title_label.add_theme_font_size_override("font_size", 24)
	_title_label.add_theme_color_override("font_color", Color(1, 0.85, 0.4))
	_title_label.position = Vector2(30, 20)
	_title_label.size = Vector2(PANEL_W - 60, 40)
	_panel.add_child(_title_label)

	# 已选计数
	_selected_label = Label.new()
	_selected_label.text = "已选 0/3"
	_selected_label.add_theme_font_size_override("font_size", 16)
	_selected_label.add_theme_color_override("font_color", Color.WHITE)
	_selected_label.position = Vector2(30, PANEL_H - 80)
	_selected_label.size = Vector2(150, 30)
	_panel.add_child(_selected_label)

	# 总价
	_total_label = Label.new()
	_total_label.text = "总价: 0 金币"
	_total_label.add_theme_font_size_override("font_size", 18)
	_total_label.add_theme_color_override("font_color", Color(1, 0.85, 0.2))
	_total_label.position = Vector2(200, PANEL_H - 80)
	_total_label.size = Vector2(200, 30)
	_panel.add_child(_total_label)

	# 确认按钮
	_confirm_btn = Button.new()
	_confirm_btn.text = "✅ 确认交易"
	_confirm_btn.position = Vector2(PANEL_W - 270, PANEL_H - 85)
	_confirm_btn.size = Vector2(120, 36)
	_confirm_btn.pressed.connect(_on_confirm)
	_panel.add_child(_confirm_btn)

	# 跳过按钮
	_skip_btn = Button.new()
	_skip_btn.text = "⏭️ 跳过"
	_skip_btn.position = Vector2(PANEL_W - 130, PANEL_H - 85)
	_skip_btn.size = Vector2(100, 36)
	_skip_btn.pressed.connect(_on_skip)
	_panel.add_child(_skip_btn)


# ========== 展示 ==========

func show_market(player: int, price_multiplier: float) -> void:
	## 弹出资哥布林商队面板
	_current_player = player
	_price_multiplier = price_multiplier
	_selected = []

	# 生成本次商品（4 个），质量受好感度影响
	_offer_goods = _generate_offer(price_multiplier)
	_selected_label.text = "已选 0/3"
	_update_total()

	# 重建卡牌
	_rebuild_cards()
	show()


func _generate_offer(price_mult: float) -> Array:
	## 生成 4 个商品，好感度低则替换稀有为基础
	## # TODO: 奖励池内容待填充
	var pool: Array = _placeholder_goods.duplicate()
	var result: Array = []

	# 好感度低 → 替换稀有为基础资源
	if price_mult >= 1.5:
		pool = pool.filter(func(g): return g["tier"] == "basic")

	# 乱序抽 4 个（用确定性 seed）
	var shuffled := _shuffle_array(pool, _current_player * 100 + GameCatalog.RESOURCE_KEYS.size())
	for i in range(mini(4, shuffled.size())):
		var goods = shuffled[i].duplicate()
		goods["price"] = int(goods["price"] * price_mult)
		result.append(goods)

	# 补足到 4 个
	while result.size() < 4:
		result.append({ "name": "木材", "icon": "🪵", "price": int(10 * price_mult), "key": "wood", "tier": "basic" })

	return result


func _shuffle_array(arr: Array, seed_val: int) -> Array:
	## 确定性洗牌
	var result := arr.duplicate()
	var s := seed_val
	for i in range(result.size() - 1, 0, -1):
		s = (s * 1103515245 + 12345) & 0x7fffffff
		var j := s % (i + 1)
		var tmp = result[i]
		result[i] = result[j]
		result[j] = tmp
	return result


func _rebuild_cards() -> void:
	## 清除并重建商品卡牌
	for c in _cards:
		if c.has("container") and is_instance_valid(c["container"]):
			c["container"].queue_free()
	_cards.clear()

	if _offer_goods.is_empty():
		return

	var total_w := _offer_goods.size() * CARD_W + (_offer_goods.size() - 1) * CARD_GAP
	var start_x := (PANEL_W - total_w) / 2.0
	var card_y := 70

	for i in range(_offer_goods.size()):
		var goods: Dictionary = _offer_goods[i]
		var cx := start_x + i * (CARD_W + CARD_GAP)

		var card := ColorRect.new()
		card.color = Color(0.18, 0.18, 0.22)
		card.size = Vector2(CARD_W, CARD_H)
		card.position = Vector2(cx, card_y)
		card.mouse_filter = Control.MOUSE_FILTER_STOP
		_panel.add_child(card)

		# 图标
		var icon_label := Label.new()
		icon_label.text = goods.get("icon", "📦")
		icon_label.add_theme_font_size_override("font_size", 40)
		icon_label.position = Vector2(CARD_W / 2.0 - 20, 15)
		icon_label.size = Vector2(40, 50)
		icon_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		card.add_child(icon_label)

		# 商品名
		var name_label := Label.new()
		name_label.text = goods["name"]
		name_label.add_theme_font_size_override("font_size", 16)
		name_label.add_theme_color_override("font_color", Color.WHITE)
		name_label.position = Vector2(5, 70)
		name_label.size = Vector2(CARD_W - 10, 30)
		name_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		card.add_child(name_label)

		# 价格
		var price_label := Label.new()
		price_label.text = "🪙 %d" % goods["price"]
		price_label.add_theme_font_size_override("font_size", 18)
		price_label.add_theme_color_override("font_color", Color(1, 0.85, 0.2))
		price_label.position = Vector2(5, 100)
		price_label.size = Vector2(CARD_W - 10, 30)
		price_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		card.add_child(price_label)

		# 选中高亮（不可见初始）
		var sel_rect := ColorRect.new()
		sel_rect.color = Color(0.3, 0.8, 0.3, 0.3)
		sel_rect.size = Vector2(CARD_W, CARD_H)
		sel_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
		sel_rect.visible = false
		card.add_child(sel_rect)

		# 点击检测
		var index := i
		var card_container := card
		card.gui_input.connect(func(event: InputEvent):
			if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
				_on_card_clicked(index)
		)

		_cards.append({
			"container": card_container,
			"name_label": name_label,
			"price_label": price_label,
			"index": index,
			"sel_rect": sel_rect,
		})


# ========== 交互 ==========

func _on_card_clicked(index: int) -> void:
	## 点击卡牌：选中/取消
	if _selected.has(index):
		_selected.erase(index)
	else:
		if _selected.size() >= 3:
			return  # 最多选 3 个
		_selected.append(index)

	_update_card_highlights()
	_selected_label.text = "已选 %d/3" % _selected.size()
	_update_total()


func _update_card_highlights() -> void:
	for c in _cards:
		var is_sel: bool = _selected.has(c["index"])
		c["sel_rect"].visible = is_sel


func _calculate_total(selected_indices: Array) -> int:
	## 计算总价：第 1 个原价，第 2 个 +50%，第 3 个 +100%
	var total := 0
	for i in range(selected_indices.size()):
		var idx: int = selected_indices[i]
		if idx >= 0 and idx < _offer_goods.size():
			var base_price: int = _offer_goods[idx]["price"]
			if i == 0:
				total += base_price
			elif i == 1:
				total += int(base_price * 1.5)
			else:
				total += int(base_price * 2.0)
	return total


func _update_total() -> void:
	_total_label.text = "总价: %d 金币" % _calculate_total(_selected)


func _on_confirm() -> void:
	if _selected.is_empty():
		return

	# 检查是否有足够金币
	if _resource_tracker:
		var total: int = _calculate_total(_selected)
		var current_gold: int = _resource_tracker.get_resource(_current_player, "gold")
		if current_gold < total:
			print("[市场] 阵营 %d 金币不足: 需要 %d, 持有 %d" % [_current_player, total, current_gold])
			return

		# 扣金币、给商品
		_resource_tracker.spend_resource(_current_player, "gold", total)
		for i in range(_selected.size()):
			var idx: int = _selected[i]
			var goods = _offer_goods[idx]
			_resource_tracker.add_resource(_current_player, goods["key"], 1)
			print("[市场] 阵营 %d 购买 %s，花费 %d 金币" % [_current_player, goods["name"], _offer_goods[idx]["price"]])

	market_confirmed.emit(_current_player, _selected)

	# 好感度不变
	hide()
	_current_player = -1


func _on_skip() -> void:
	market_skipped.emit(_current_player)
	hide()
	_current_player = -1
