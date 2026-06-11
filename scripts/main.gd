extends Node2D
## 主场景控制器 — 2.5D 三人竞技棋

@onready var camera: Camera2D = $GameCamera
@onready var grid_manager: Node2D = $GameBoard/GridManager2D
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
	print("[Main] 2.5D 游戏就绪")


func _input(event: InputEvent) -> void:
	if event.is_action_pressed("end_turn"):
		_on_end_turn()


func _on_end_turn() -> void:
	print("[Main] 结束回合 (待实现)")
