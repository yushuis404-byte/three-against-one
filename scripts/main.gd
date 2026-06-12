extends Node2D
## 主场景控制器 — 2.5D 三人竞技棋

@onready var camera: Camera2D = $GameCamera
@onready var grid_manager: Node2D = $GameBoard/GridManager2D
@onready var resource_manager: Node2D = $GameBoard/ResourceManager2D
@onready var debug_label: Label = $UI/DebugLabel

enum GameState { LOADING, PLAYING, TURN_RESOLVE, GAME_OVER }
var current_state: GameState = GameState.LOADING


func _ready() -> void:
	print("[Main] 项目启动 - Three Against One (2.5D)")
	_setup_game()


func _setup_game() -> void:
	current_state = GameState.PLAYING
	var tile_count: int = grid_manager.get_rendered_count()
	debug_label.text = "Three Against One v0.1 | 2.5D 开放世界 | %d 格\n空格+鼠标左键拖拽 平移 | 滚轮 缩放" % tile_count
	resource_manager.resource_hovered.connect(_on_resource_hovered)

	# 初始视野：揭示三阵营出生点周围
	var fog_mgr = $GameBoard/FogOfWar2D
	fog_mgr.reveal_area_immediate(0, 35, 13, 2)  # 精灵
	fog_mgr.reveal_area_immediate(0, 35, 43, 2)  # 矮人
	fog_mgr.reveal_area_immediate(0, 62, 35, 2)  # 兽人
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


func _on_fog_updated(player: int) -> void:
	var territory_mgr = $GameBoard/TerritoryManager2D
	territory_mgr.recalc_territory(player)


func _on_resource_hovered(text: String) -> void:
	if text.is_empty():
		debug_label.text = ""
	else:
		debug_label.text = text


func _input(event: InputEvent) -> void:
	if event.is_action_pressed("end_turn"):
		_on_end_turn()


func _on_end_turn() -> void:
	print("[Main] 结束回合 (待实现)")
