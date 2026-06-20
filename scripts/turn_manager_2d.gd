extends Node
## 同步回合管理器 — 三玩家轮流操作，全部结束后统一推进
##
## 信号供其他系统接入（资源产出、科技、建造等）
## Hotseat 模式：空格键依次操作精灵→矮人→兽人

signal round_started(round: int)
signal player_turn_started(player: int)
signal player_turn_ended(player: int)
signal round_ended(round: int)
signal neutral_turn_started()
signal neutral_turn_ended()
signal ap_changed(player: int, ap: int)

enum TurnPhase { ROUND_START, PLAYER_TURN, ROUND_END, NEUTRAL_TURN }

var round_number := 0
var current_player := 0
var turn_phase: TurnPhase = TurnPhase.ROUND_START
var player_ap := [6, 6, 6]
var player_finished := [false, false, false]

const AP_PER_ROUND := 12
const AP_MAX := 12


func start_game() -> void:
	## 游戏开始时启动第一回合
	_start_new_round()


func _start_new_round() -> void:
	round_number += 1
	turn_phase = TurnPhase.ROUND_START

	for p in range(3):
		player_ap[p] = mini(player_ap[p] + AP_PER_ROUND, AP_MAX)
		player_finished[p] = false

	round_started.emit(round_number)
	_start_player_turn(0)


func _start_player_turn(player: int) -> void:
	current_player = player
	turn_phase = TurnPhase.PLAYER_TURN
	player_turn_started.emit(player)


func end_player_turn(player: int) -> void:
	if player != current_player or turn_phase != TurnPhase.PLAYER_TURN:
		return

	player_turn_ended.emit(player)
	player_finished[player] = true

	if player_finished.all(func(f): return f):
		_end_round()
	else:
		var next := (player + 1) % 3
		while player_finished[next]:
			next = (next + 1) % 3
		_start_player_turn(next)


func _end_round() -> void:
	turn_phase = TurnPhase.ROUND_END
	round_ended.emit(round_number)
	# 在所有玩家回合结束后、下一回合开始前，插入中立阶段
	_start_neutral_turn()


func _start_neutral_turn() -> void:
	turn_phase = TurnPhase.NEUTRAL_TURN
	neutral_turn_started.emit()

	# 如果 AI 触发了战斗（Timer 异步），等待战斗结束后再继续
	var nmgr := get_parent().get_node_or_null("NeutralUnitManager2D")
	if nmgr != null and nmgr.has_method("is_in_combat") and nmgr.is_in_combat():
		await get_tree().process_frame
		while is_instance_valid(nmgr) and nmgr.is_in_combat():
			await get_tree().create_timer(0.5).timeout

	neutral_turn_ended.emit()
	_start_new_round()


func spend_ap(player: int, amount: int) -> bool:
	if player_ap[player] >= amount:
		player_ap[player] -= amount
		ap_changed.emit(player, player_ap[player])
		return true
	return false


func get_ap(player: int) -> int:
	return player_ap[player]
