extends Node2D
## 主场景控制器 — 2.5D 三人竞技棋

@onready var camera: Camera2D = $GameCamera
@onready var grid_manager: Node2D = $GameBoard/GridManager2D
@onready var resource_manager: Node2D = $GameBoard/ResourceManager2D
@onready var debug_label: Label = $UI/DebugLabel
@onready var turn_manager: Node = $GameBoard/TurnManager2D
@onready var unit_manager: Node2D = $GameBoard/UnitManager2D
@onready var building_manager: Node2D = $GameBoard/BuildingManager2D
@onready var turn_label: Label = $UI/TurnLabel
@onready var resource_tracker: Node = $GameBoard/ResourceTracker
@onready var resource_panel: Panel = $UI/ResourcePanel

enum GameState { LOADING, PLAYING, TURN_RESOLVE, GAME_OVER }
var current_state: GameState = GameState.LOADING


func _ready() -> void:
	print("[Main] 项目启动 - Three Against One (2.5D)")
	_setup_game()


func _setup_game() -> void:
	current_state = GameState.PLAYING
	var tile_count: int = grid_manager.get_rendered_count()
	debug_label.text = "Three Against One v0.1 | 2.5D 开放世界 | %d 格\n空格+鼠标左键拖拽 平移 | 滚轮 缩放 | Enter/Tab 结束回合" % tile_count
	resource_manager.resource_hovered.connect(_on_resource_hovered)

	# 初始视野：揭示三阵营出生点周围
	var fog_mgr = $GameBoard/FogOfWar2D
	fog_mgr.reveal_area_immediate(0, 35, 13, 2)  # 精灵
	fog_mgr.reveal_area_immediate(1, 35, 43, 2)  # 矮人
	fog_mgr.reveal_area_immediate(2, 62, 35, 2)  # 兽人
	fog_mgr.queue_redraw()
	print("[Main] 2.5D 游戏就绪")

	# 领土系统初始化
	var territory_mgr = $GameBoard/TerritoryManager2D
	territory_mgr.add_town_hall(0, Vector2i(35, 13))  # 精灵
	territory_mgr.add_town_hall(1, Vector2i(35, 43))  # 矮人
	territory_mgr.add_town_hall(2, Vector2i(62, 35))  # 兽人
	territory_mgr.recalc_territory(0)
	territory_mgr.recalc_territory(1)
	territory_mgr.recalc_territory(2)

	# 联通信號：迷雾动画完成后重算领土
	fog_mgr.fog_updated.connect(_on_fog_updated)
	# 建筑系统初始化
	fog_mgr.set_turn_manager(turn_manager)
	resource_manager.set_turn_manager(turn_manager)
	building_manager.set_turn_manager(turn_manager)
	building_manager.building_hovered.connect(_on_resource_hovered)
	_place_initial_buildings()

	# 回合系统初始化
	turn_manager.round_started.connect(_on_round_started)
	turn_manager.player_turn_started.connect(_on_player_turn_started)
	turn_manager.round_ended.connect(_on_round_ended)
	turn_manager.ap_changed.connect(_on_ap_changed)

	# 单位系统初始化
	unit_manager.set_turn_manager(turn_manager)
	unit_manager.place_initial_units()
	# 资源追踪系统初始化
	resource_tracker.set_turn_manager(turn_manager)
	resource_tracker.set_building_manager(building_manager)
	resource_tracker.resources_updated.connect(_on_resources_updated)
	_init_resource_labels()

	# 所有信号就绪后启动第一回合
	turn_manager.start_game()


func _on_fog_updated(player: int) -> void:
	var territory_mgr = $GameBoard/TerritoryManager2D
	territory_mgr.recalc_territory(player)
	resource_manager.queue_redraw()


func _on_resource_hovered(text: String) -> void:
	if text.is_empty():
		debug_label.text = ""
	else:
		debug_label.text = text


# 三阵营出生点坐标（领土系统 seed）
const FACTION_SPAWNS := [
	{ "player": 0, "th_pos": Vector2i(35, 13), "th_origin": Vector2i(34, 11) },
	{ "player": 1, "th_pos": Vector2i(35, 43), "th_origin": Vector2i(34, 41) },
	{ "player": 2, "th_pos": Vector2i(62, 35), "th_origin": Vector2i(61, 33) },
]


func _place_initial_buildings() -> void:
	## 每阵营：1 座主城（2×2）+ 1 座特色资源建筑
	## 精灵→伐木场，矮人→采石场，兽人→农场
	var faction_buildings := {
		0: BuildingData.infra_lumber_camp(),
		1: BuildingData.infra_quarry(),
		2: BuildingData.infra_farm(),
	}
	for s in FACTION_SPAWNS:
		var p: int = s["player"]
		var origin: Vector2i = s["th_origin"]

		# 主城
		building_manager.place_building(BuildingData.town_hall(), p, origin)

		# 特色资源建筑：在主城旁尝试偏移位置放置
		var infra: BuildingData = faction_buildings[p]
		var offsets := [
			Vector2i(-1, 0), Vector2i(2, 0),
			Vector2i(0, -1),
			Vector2i(-1, 1), Vector2i(2, 1),
			Vector2i(-1, -1), Vector2i(2, -1),
		]
		for off in offsets:
			var cand := Vector2i(origin.x + off.x, origin.y + off.y)
			if building_manager.place_building(infra, p, cand):
				break


const FACTION_NAMES := ["精灵", "矮人", "兽人"]
const FACTION_COLORS := [
	Color(0.18, 0.60, 0.15),
	Color(0.80, 0.65, 0.10),
	Color(0.80, 0.25, 0.15),
]


func _on_round_started(round: int) -> void:
	var p: int = turn_manager.current_player
	turn_label.text = "第 %d 回合 · %s" % [round, FACTION_NAMES[p]]
	turn_label.label_settings = _make_label_settings(FACTION_COLORS[p])


func _on_player_turn_started(player: int) -> void:
	turn_label.text = "第 %d 回合 · %s" % [turn_manager.round_number, FACTION_NAMES[player]]
	turn_label.label_settings = _make_label_settings(FACTION_COLORS[player])
	debug_label.text = "%s (AP: %d)" % [FACTION_NAMES[player], turn_manager.get_ap(player)]
	resource_tracker.update_display(player)


func _on_round_ended(round: int) -> void:
	turn_label.text = "第 %d 回合结束" % round
	debug_label.text = "结算中..."


func _on_ap_changed(player: int, ap: int) -> void:
	debug_label.text = "%s (AP: %d)" % [FACTION_NAMES[player], turn_manager.get_ap(player)]
	resource_tracker.update_display(player)


func _init_resource_labels() -> void:
	## 将 UI 面板中的 Label 引用传给 resource_tracker
	var panel: Panel = resource_panel
	if not panel:
		return
	var key_map := {"Wood": "wood", "Stone": "stone", "Food": "food", "Iron": "iron", "MagicDust": "magic_dust", "AncientWood": "ancient_wood", "GoldOre": "gold_ore"}
	for node_name in key_map:
		var label: Label = panel.get_node("VBox/Label" + node_name)
		if label:
			resource_tracker.set_resource_label(key_map[node_name], label)
	resource_tracker.set_faction_label(panel.get_node("VBox/FactionLabel"))


func _on_resources_updated(_player: int) -> void:
	var cp: int = turn_manager.current_player
	resource_tracker.update_display(cp)

func _make_label_settings(color: Color) -> LabelSettings:
	var s := LabelSettings.new()
	s.font_size = 22
	s.font_color = color
	s.outline_size = 2
	s.outline_color = Color(0, 0, 0, 0.6)
	return s


func _input(event: InputEvent) -> void:
	# Enter 或 Tab 都可结束回合（Tab 在编辑器内嵌模式可能被截获）
	if event is InputEventKey and event.pressed and not event.echo:
		if event.keycode == KEY_ENTER or event.keycode == KEY_TAB:
			_on_end_turn()


func _on_end_turn() -> void:
	if current_state != GameState.PLAYING:
		return
	turn_manager.end_player_turn(turn_manager.current_player)
