extends Node
## 同步回合管理器 — 三玩家轮流操作，全部结束后统一推进
##
## 信号供其他系统接入（资源产出、科技、建造等）
## Hotseat 模式：空格键依次操作精灵→矮人→兽人

signal round_started(round: int)
signal player_turn_started(player: int)
signal player_turn_ended(player: int)
signal player_ready_changed(player: int, ready: bool)
signal view_player_changed(player: int)
signal round_action_started(round: int)
signal round_resolve_started(round: int)
signal round_ended(round: int)
signal neutral_turn_started()
signal neutral_turn_ended()
signal ap_changed(player: int, ap: int)

enum TurnPhase { ROUND_START, PLAYER_TURN, ROUND_ACTION, ROUND_RESOLVE, ROUND_END, NEUTRAL_TURN }

var round_number := 0
var current_player := 0
var view_player := 0
var turn_phase: TurnPhase = TurnPhase.ROUND_START
var player_ap := [6, 6, 6]
var player_finished := [false, false, false]
var player_ready := [false, false, false]
var game_stopped := false
var creative_mode_enabled := false
var synchronous_mode_enabled := false

const AP_PER_ROUND := 12
const AP_MAX := 12
const CREATIVE_AP_VALUE := 999
const PLAYER_COUNT := 3


func start_game() -> void:
	game_stopped = false
	## 游戏开始时启动第一回合
	_start_new_round()


func stop_game() -> void:
	game_stopped = true


func _start_new_round() -> void:
	if game_stopped:
		return
	round_number += 1
	turn_phase = TurnPhase.ROUND_START

	for p in range(PLAYER_COUNT):
		player_ap[p] = mini(player_ap[p] + AP_PER_ROUND, AP_MAX)
		player_finished[p] = false
		player_ready[p] = false

	round_started.emit(round_number)
	if synchronous_mode_enabled:
		_start_round_action()
	else:
		_start_player_turn(0)


func _start_round_action() -> void:
	if game_stopped:
		return
	turn_phase = TurnPhase.ROUND_ACTION
	round_action_started.emit(round_number)
	for p in range(PLAYER_COUNT):
		player_ready_changed.emit(p, false)
		player_turn_started.emit(p)


func _start_player_turn(player: int) -> void:
	if game_stopped:
		return
	current_player = player
	view_player = player
	view_player_changed.emit(player)
	turn_phase = TurnPhase.PLAYER_TURN
	player_turn_started.emit(player)


func end_player_turn(player: int) -> void:
	if game_stopped:
		return
	if synchronous_mode_enabled:
		confirm_player_ready(player)
		return
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


func confirm_player_ready(player: int) -> void:
	if game_stopped:
		return
	if not synchronous_mode_enabled:
		end_player_turn(player)
		return
	if player < 0 or player >= PLAYER_COUNT:
		return
	if turn_phase != TurnPhase.ROUND_ACTION:
		return
	if player_ready[player]:
		return
	player_ready[player] = true
	player_finished[player] = true
	player_turn_ended.emit(player)
	player_ready_changed.emit(player, true)
	if player_ready.all(func(ready): return ready):
		_resolve_synchronous_round()


func cancel_player_ready(player: int) -> void:
	if not synchronous_mode_enabled:
		return
	if player < 0 or player >= PLAYER_COUNT:
		return
	if turn_phase != TurnPhase.ROUND_ACTION:
		return
	if not player_ready[player]:
		return
	player_ready[player] = false
	player_finished[player] = false
	player_ready_changed.emit(player, false)


func can_player_act(player: int) -> bool:
	if game_stopped:
		return false
	if player < 0 or player >= PLAYER_COUNT:
		return false
	if synchronous_mode_enabled:
		return turn_phase == TurnPhase.ROUND_ACTION and not player_ready[player]
	return turn_phase == TurnPhase.PLAYER_TURN and player == current_player


func set_view_player(player: int) -> void:
	if player < 0 or player >= PLAYER_COUNT:
		return
	view_player = player
	view_player_changed.emit(player)


func _resolve_synchronous_round() -> void:
	if game_stopped:
		return
	turn_phase = TurnPhase.ROUND_RESOLVE
	round_resolve_started.emit(round_number)
	_end_round()


func _end_round() -> void:
	turn_phase = TurnPhase.ROUND_END
	round_ended.emit(round_number)
	if game_stopped:
		return
	# 在所有玩家回合结束后、下一回合开始前，插入中立阶段
	_start_neutral_turn()


func _start_neutral_turn() -> void:
	if game_stopped:
		return
	turn_phase = TurnPhase.NEUTRAL_TURN
	neutral_turn_started.emit()

	# 如果 AI 触发了战斗（Timer 异步），等待战斗结束后再继续
	var nmgr := get_parent().get_node_or_null("NeutralUnitManager2D")
	if nmgr != null and nmgr.has_method("is_in_combat") and nmgr.is_in_combat():
		await get_tree().process_frame
		while is_instance_valid(nmgr) and nmgr.is_in_combat():
			await get_tree().create_timer(0.5).timeout

	neutral_turn_ended.emit()
	if game_stopped:
		return
	_start_new_round()


func spend_ap(player: int, amount: int) -> bool:
	if synchronous_mode_enabled and not can_player_act(player):
		return false
	if creative_mode_enabled:
		ap_changed.emit(player, get_ap(player))
		return true
	if player_ap[player] >= amount:
		player_ap[player] -= amount
		ap_changed.emit(player, player_ap[player])
		return true
	return false


func add_ap(player: int, amount: int) -> void:
	if player < 0 or player >= PLAYER_COUNT:
		return
	if amount <= 0:
		return
	if creative_mode_enabled:
		ap_changed.emit(player, get_ap(player))
		return
	player_ap[player] = mini(player_ap[player] + amount, AP_MAX)
	ap_changed.emit(player, player_ap[player])


func get_ap(player: int) -> int:
	if creative_mode_enabled:
		return CREATIVE_AP_VALUE
	return player_ap[player]


func set_creative_mode_enabled(enabled: bool) -> void:
	if creative_mode_enabled == enabled:
		return
	creative_mode_enabled = enabled
	for p in range(player_ap.size()):
		ap_changed.emit(p, get_ap(p))


func is_creative_mode_enabled() -> bool:
	return creative_mode_enabled


func set_synchronous_mode_enabled(enabled: bool) -> void:
	if synchronous_mode_enabled == enabled:
		return
	synchronous_mode_enabled = enabled
	for p in range(PLAYER_COUNT):
		player_ready[p] = false
		player_finished[p] = false
	if synchronous_mode_enabled and round_number > 0 and not game_stopped:
		_start_round_action()


func is_synchronous_mode_enabled() -> bool:
	return synchronous_mode_enabled


func is_player_ready(player: int) -> bool:
	if player < 0 or player >= PLAYER_COUNT:
		return false
	return bool(player_ready[player])


func get_ready_players() -> Array:
	return player_ready.duplicate()


func apply_network_snapshot(snapshot: Dictionary) -> void:
	if snapshot.has("round"):
		round_number = int(snapshot.get("round", round_number))
	if snapshot.has("turn_phase"):
		turn_phase = int(snapshot.get("turn_phase", turn_phase))
	if snapshot.has("player") and snapshot.has("ap"):
		var snapshot_player: int = int(snapshot.get("player", -1))
		if snapshot_player >= 0 and snapshot_player < PLAYER_COUNT:
			player_ap[snapshot_player] = int(snapshot.get("ap", player_ap[snapshot_player]))
			ap_changed.emit(snapshot_player, get_ap(snapshot_player))
	var ready: Array = snapshot.get("player_ready", [])
	for p in range(mini(PLAYER_COUNT, ready.size())):
		var value := bool(ready[p])
		player_ready[p] = value
		player_finished[p] = value
