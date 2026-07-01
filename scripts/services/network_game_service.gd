class_name NetworkGameService
extends Node

signal network_status_changed(text: String)
signal local_faction_changed(player: int)
signal remote_snapshot_received(snapshot: Dictionary)

const DEFAULT_PORT := 24531
const MAX_PLAYERS := 3

var local_faction := 0
var peer_to_faction: Dictionary = {}
var faction_to_peer: Dictionary = {}

var _turn_manager: Node = null
var _serializer: GameStateSerializer = null
var _unit_manager: Node = null
var _building_manager: Node = null
var _gathering_manager: Node = null
var _technology_service: Node = null
var _wall_blueprint_manager: Node = null
var _is_network_game := false


func setup(turn_manager: Node, serializer: GameStateSerializer) -> void:
	_turn_manager = turn_manager
	_serializer = serializer
	if _turn_manager != null:
		if _turn_manager.has_signal("player_ready_changed"):
			_turn_manager.player_ready_changed.connect(_on_turn_state_changed.unbind(2))
		if _turn_manager.has_signal("round_action_started"):
			_turn_manager.round_action_started.connect(_on_turn_state_changed.unbind(1))
		if _turn_manager.has_signal("round_resolve_started"):
			_turn_manager.round_resolve_started.connect(_on_turn_state_changed.unbind(1))
		if _turn_manager.has_signal("round_ended"):
			_turn_manager.round_ended.connect(_on_turn_state_changed.unbind(1))


func set_unit_manager(unit_manager: Node) -> void:
	_unit_manager = unit_manager


func set_building_manager(building_manager: Node) -> void:
	_building_manager = building_manager


func set_gathering_manager(gathering_manager: Node) -> void:
	_gathering_manager = gathering_manager


func set_technology_service(technology_service: Node) -> void:
	_technology_service = technology_service


func set_wall_blueprint_manager(wall_blueprint_manager: Node) -> void:
	_wall_blueprint_manager = wall_blueprint_manager


func get_turn_manager() -> Node:
	return _turn_manager


func is_network_game() -> bool:
	return _is_network_game


func is_host() -> bool:
	return multiplayer.multiplayer_peer != null and multiplayer.is_server()


func get_lan_addresses() -> PackedStringArray:
	var result := PackedStringArray()
	for address in IP.get_local_addresses():
		var value := str(address)
		if value.begins_with("127."):
			continue
		if value == "0.0.0.0":
			continue
		if not value.contains("."):
			continue
		result.append(value)
	return result


func host_game(port: int = DEFAULT_PORT) -> bool:
	var peer := ENetMultiplayerPeer.new()
	var err := peer.create_server(port, MAX_PLAYERS)
	if err != OK:
		network_status_changed.emit("创建房间失败: %s" % str(err))
		return false
	multiplayer.multiplayer_peer = peer
	_is_network_game = true
	local_faction = 0
	peer_to_faction.clear()
	faction_to_peer.clear()
	peer_to_faction[1] = 0
	faction_to_peer[0] = 1
	_enable_sync_turns()
	multiplayer.peer_connected.connect(_on_peer_connected)
	multiplayer.peer_disconnected.connect(_on_peer_disconnected)
	local_faction_changed.emit(local_faction)
	network_status_changed.emit("已创建局域网房间，等待玩家加入")
	_broadcast_snapshots()
	return true


func join_game(address: String, port: int = DEFAULT_PORT) -> bool:
	var peer := ENetMultiplayerPeer.new()
	var err := peer.create_client(address, port)
	if err != OK:
		network_status_changed.emit("加入房间失败: %s" % str(err))
		return false
	multiplayer.multiplayer_peer = peer
	_is_network_game = true
	_enable_sync_turns()
	multiplayer.connected_to_server.connect(_on_connected_to_server)
	multiplayer.connection_failed.connect(_on_connection_failed)
	multiplayer.server_disconnected.connect(_on_server_disconnected)
	network_status_changed.emit("正在加入局域网房间 %s:%d" % [address, port])
	return true


func leave_game() -> void:
	if multiplayer.multiplayer_peer != null:
		multiplayer.multiplayer_peer.close()
	multiplayer.multiplayer_peer = null
	_is_network_game = false
	network_status_changed.emit("已离开联机房间")


func request_action(action_type: String, payload: Dictionary) -> void:
	if not _is_network_game:
		return
	if is_host():
		_handle_action_request(local_faction, action_type, payload)
	else:
		rpc_id(1, "_rpc_action_request", local_faction, action_type, payload)


func request_end_round() -> void:
	request_action("end_round", {})


func _enable_sync_turns() -> void:
	if _turn_manager != null and _turn_manager.has_method("set_synchronous_mode_enabled"):
		_turn_manager.call("set_synchronous_mode_enabled", true)
	if _turn_manager != null and _turn_manager.has_method("set_view_player"):
		_turn_manager.call("set_view_player", local_faction)
	if _turn_manager != null:
		_turn_manager.current_player = local_faction


func _on_peer_connected(peer_id: int) -> void:
	if not is_host():
		return
	var faction := _get_next_free_faction()
	if faction < 0:
		multiplayer.multiplayer_peer.disconnect_peer(peer_id)
		return
	peer_to_faction[peer_id] = faction
	faction_to_peer[faction] = peer_id
	rpc_id(peer_id, "_rpc_assign_faction", faction)
	network_status_changed.emit("玩家加入: peer %d -> 阵营 %d" % [peer_id, faction])
	_broadcast_snapshots()


func _on_peer_disconnected(peer_id: int) -> void:
	if peer_to_faction.has(peer_id):
		var faction: int = int(peer_to_faction[peer_id])
		peer_to_faction.erase(peer_id)
		faction_to_peer.erase(faction)
	network_status_changed.emit("玩家离开: peer %d" % peer_id)
	_broadcast_snapshots()


func _on_connected_to_server() -> void:
	network_status_changed.emit("已连接，等待主机分配阵营")


func _on_connection_failed() -> void:
	_is_network_game = false
	network_status_changed.emit("连接失败")


func _on_server_disconnected() -> void:
	_is_network_game = false
	network_status_changed.emit("主机已断开")


func _get_next_free_faction() -> int:
	for faction in range(MAX_PLAYERS):
		if not faction_to_peer.has(faction):
			return faction
	return -1


func _handle_action_request(player: int, action_type: String, payload: Dictionary) -> void:
	if not is_host():
		return
	if player < 0 or player >= MAX_PLAYERS:
		return
	match action_type:
		"end_round":
			if _turn_manager != null and _turn_manager.has_method("confirm_player_ready"):
				_turn_manager.call("confirm_player_ready", player)
		"cancel_ready":
			if _turn_manager != null and _turn_manager.has_method("cancel_player_ready"):
				_turn_manager.call("cancel_player_ready", player)
		"unit_move":
			_handle_unit_move(player, payload)
		"unit_attack":
			_handle_unit_attack(player, payload)
		"throw_beast":
			_handle_throw_beast(player, payload)
		"unit_fog_reveal":
			_handle_unit_fog_skill(player, payload, true)
		"unit_fog_conceal":
			_handle_unit_fog_skill(player, payload, false)
		"warband_form":
			_handle_warband_form(player, payload)
		"warband_disband":
			_handle_warband_disband(player, payload)
		"wall_blueprint":
			_handle_wall_blueprint(player, payload)
		"build_place":
			_handle_build_place(player, payload)
		"recruit":
			_handle_recruit(player, payload)
		"gather_start":
			_handle_gather_start(player, payload)
		"gather_cancel":
			_handle_gather_cancel(player, payload)
		"tech_research":
			_handle_tech_research(player, payload)
		_:
			network_status_changed.emit("暂未接入联机操作: %s" % action_type)
	_broadcast_snapshots()


func _handle_unit_move(player: int, payload: Dictionary) -> void:
	if _unit_manager == null or not _unit_manager.has_method("request_network_move"):
		return
	var unit_id: int = int(payload.get("unit_id", -1))
	var target := Vector2i(int(payload.get("x", -1)), int(payload.get("y", -1)))
	var ok: bool = bool(_unit_manager.call("request_network_move", player, unit_id, target))
	if not ok:
		network_status_changed.emit("Unit move rejected")
	else:
		rpc("_rpc_apply_unit_move", player, unit_id, target.x, target.y)


func _handle_unit_attack(player: int, payload: Dictionary) -> void:
	if _unit_manager == null or not _unit_manager.has_method("request_network_attack"):
		return
	var attacker_id: int = int(payload.get("attacker_id", -1))
	var target_id: int = int(payload.get("target_id", -1))
	var ok: bool = bool(_unit_manager.call("request_network_attack", player, attacker_id, target_id))
	if not ok:
		network_status_changed.emit("Unit attack rejected")
	else:
		rpc("_rpc_apply_unit_attack", player, attacker_id, target_id)


func _handle_throw_beast(player: int, payload: Dictionary) -> void:
	if _unit_manager == null or not _unit_manager.has_method("request_network_throw_beast"):
		return
	var slinger_id: int = int(payload.get("slinger_id", -1))
	var beast_id: int = int(payload.get("beast_id", -1))
	var target := Vector2i(int(payload.get("x", -1)), int(payload.get("y", -1)))
	var ok: bool = bool(_unit_manager.call("request_network_throw_beast", player, slinger_id, beast_id, target))
	if not ok:
		network_status_changed.emit("Throw beast rejected")
	else:
		rpc("_rpc_apply_throw_beast", player, slinger_id, beast_id, target.x, target.y)


func _handle_unit_fog_skill(player: int, payload: Dictionary, reveal: bool) -> void:
	if _unit_manager == null:
		return
	var method_name := "request_network_fog_reveal" if reveal else "request_network_fog_conceal"
	if not _unit_manager.has_method(method_name):
		return
	var caster_id: int = int(payload.get("caster_id", -1))
	var target := Vector2i(int(payload.get("x", -1)), int(payload.get("y", -1)))
	var ok: bool = bool(_unit_manager.call(method_name, player, caster_id, target))
	if not ok:
		network_status_changed.emit("Fog skill rejected")
	else:
		rpc("_rpc_apply_unit_fog_skill", player, caster_id, target.x, target.y, reveal)


func _handle_warband_form(player: int, payload: Dictionary) -> void:
	if _unit_manager == null or not _unit_manager.has_method("request_network_form_warband"):
		return
	var leader_id: int = int(payload.get("leader_id", -1))
	var member_ids: Array = payload.get("member_ids", [])
	var ok: bool = bool(_unit_manager.call("request_network_form_warband", player, leader_id, member_ids))
	if not ok:
		network_status_changed.emit("Warband form rejected")
	else:
		rpc("_rpc_apply_warband_form", player, leader_id, member_ids)


func _handle_warband_disband(player: int, payload: Dictionary) -> void:
	if _unit_manager == null or not _unit_manager.has_method("request_network_disband_warband"):
		return
	var unit_id: int = int(payload.get("unit_id", -1))
	var ok: bool = bool(_unit_manager.call("request_network_disband_warband", player, unit_id))
	if not ok:
		network_status_changed.emit("Warband disband rejected")
	else:
		rpc("_rpc_apply_warband_disband", player, unit_id)


func _handle_wall_blueprint(player: int, payload: Dictionary) -> void:
	if _wall_blueprint_manager == null or not _wall_blueprint_manager.has_method("request_network_wall_blueprint"):
		return
	var start_building_id: int = int(payload.get("start_building_id", -1))
	var end_building_id: int = int(payload.get("end_building_id", -1))
	var ok: bool = bool(_wall_blueprint_manager.call("request_network_wall_blueprint", player, start_building_id, end_building_id))
	if not ok:
		network_status_changed.emit("Wall blueprint rejected")
	else:
		rpc("_rpc_apply_wall_blueprint", player, start_building_id, end_building_id)


func _handle_build_place(player: int, payload: Dictionary) -> void:
	if _building_manager == null or not _building_manager.has_method("request_network_build"):
		return
	var building_key: Dictionary = payload.get("building", {})
	var target := Vector2i(int(payload.get("x", -1)), int(payload.get("y", -1)))
	var ok: bool = bool(_building_manager.call("request_network_build", player, building_key, target))
	if not ok:
		network_status_changed.emit("Build request rejected")
	else:
		rpc("_rpc_apply_build_place", player, building_key, target.x, target.y)


func _handle_recruit(player: int, payload: Dictionary) -> void:
	if _building_manager == null or not _building_manager.has_method("request_network_recruit"):
		return
	var building_id: int = int(payload.get("building_id", -1))
	var unit_template_id: String = str(payload.get("unit_template_id", ""))
	var count: int = int(payload.get("count", 1))
	var ok: bool = bool(_building_manager.call("request_network_recruit", player, building_id, unit_template_id, count))
	if not ok:
		network_status_changed.emit("Recruit request rejected")
	else:
		rpc("_rpc_apply_recruit", player, building_id, unit_template_id, count)


func _handle_gather_start(player: int, payload: Dictionary) -> void:
	if _gathering_manager == null or not _gathering_manager.has_method("start_gather"):
		return
	var unit_id: int = int(payload.get("unit_id", -1))
	var target := Vector2i(int(payload.get("x", -1)), int(payload.get("y", -1)))
	var info: Array = payload.get("info", [])
	var ok: bool = bool(_gathering_manager.call("start_gather", unit_id, player, target, info))
	if not ok:
		network_status_changed.emit("Gather start rejected")
	else:
		rpc("_rpc_apply_gather_start", player, unit_id, target.x, target.y, info)


func _handle_gather_cancel(_player: int, payload: Dictionary) -> void:
	if _gathering_manager == null or not _gathering_manager.has_method("cancel_gather"):
		return
	var unit_id: int = int(payload.get("unit_id", -1))
	_gathering_manager.call("cancel_gather", unit_id)
	rpc("_rpc_apply_gather_cancel", unit_id)


func _handle_tech_research(player: int, payload: Dictionary) -> void:
	if _technology_service == null or not _technology_service.has_method("request_network_research"):
		return
	var technology_id: String = str(payload.get("technology_id", ""))
	var ok: bool = bool(_technology_service.call("request_network_research", player, technology_id))
	if not ok:
		network_status_changed.emit("Technology request rejected")
	else:
		rpc("_rpc_apply_tech_research", player, technology_id)


func _broadcast_snapshots() -> void:
	if not is_host() or _serializer == null:
		return
	for faction in range(MAX_PLAYERS):
		var snapshot: Dictionary = _serializer.make_player_snapshot(faction)
		if faction == local_faction:
			remote_snapshot_received.emit(snapshot)
			continue
		if faction_to_peer.has(faction):
			var peer_id: int = int(faction_to_peer[faction])
			rpc_id(peer_id, "_rpc_receive_snapshot", snapshot)


func broadcast_gather_complete(player: int, unit_id: int, pos: Vector2i, results: Array) -> void:
	if not is_host():
		return
	rpc("_rpc_apply_gather_complete", player, unit_id, pos.x, pos.y, results)
	_broadcast_snapshots()


func _on_turn_state_changed() -> void:
	_broadcast_snapshots()


@rpc("any_peer", "reliable")
func _rpc_action_request(player: int, action_type: String, payload: Dictionary) -> void:
	if not is_host():
		return
	var sender := multiplayer.get_remote_sender_id()
	if not peer_to_faction.has(sender):
		return
	var expected_player: int = int(peer_to_faction[sender])
	if player != expected_player:
		return
	_handle_action_request(player, action_type, payload)


@rpc("authority", "reliable")
func _rpc_assign_faction(player: int) -> void:
	local_faction = player
	_enable_sync_turns()
	local_faction_changed.emit(local_faction)
	network_status_changed.emit("已分配阵营: %s" % GameCatalog.faction_name(local_faction))


@rpc("authority", "reliable")
func _rpc_receive_snapshot(snapshot: Dictionary) -> void:
	if _turn_manager != null and _turn_manager.has_method("apply_network_snapshot"):
		_turn_manager.call("apply_network_snapshot", snapshot)
	remote_snapshot_received.emit(snapshot)


@rpc("authority", "reliable")
func _rpc_apply_unit_move(player: int, unit_id: int, x: int, y: int) -> void:
	if is_host():
		return
	if _unit_manager == null or not _unit_manager.has_method("request_network_move"):
		return
	_unit_manager.call("request_network_move", player, unit_id, Vector2i(x, y))


@rpc("authority", "reliable")
func _rpc_apply_unit_attack(player: int, attacker_id: int, target_id: int) -> void:
	if is_host():
		return
	if _unit_manager == null or not _unit_manager.has_method("request_network_attack"):
		return
	_unit_manager.call("request_network_attack", player, attacker_id, target_id)


@rpc("authority", "reliable")
func _rpc_apply_throw_beast(player: int, slinger_id: int, beast_id: int, x: int, y: int) -> void:
	if is_host():
		return
	if _unit_manager == null or not _unit_manager.has_method("request_network_throw_beast"):
		return
	_unit_manager.call("request_network_throw_beast", player, slinger_id, beast_id, Vector2i(x, y))


@rpc("authority", "reliable")
func _rpc_apply_unit_fog_skill(player: int, caster_id: int, x: int, y: int, reveal: bool) -> void:
	if is_host():
		return
	if _unit_manager == null:
		return
	var method_name := "request_network_fog_reveal" if reveal else "request_network_fog_conceal"
	if not _unit_manager.has_method(method_name):
		return
	_unit_manager.call(method_name, player, caster_id, Vector2i(x, y))


@rpc("authority", "reliable")
func _rpc_apply_warband_form(player: int, leader_id: int, member_ids: Array) -> void:
	if is_host():
		return
	if _unit_manager == null or not _unit_manager.has_method("request_network_form_warband"):
		return
	_unit_manager.call("request_network_form_warband", player, leader_id, member_ids)


@rpc("authority", "reliable")
func _rpc_apply_warband_disband(player: int, unit_id: int) -> void:
	if is_host():
		return
	if _unit_manager == null or not _unit_manager.has_method("request_network_disband_warband"):
		return
	_unit_manager.call("request_network_disband_warband", player, unit_id)


@rpc("authority", "reliable")
func _rpc_apply_wall_blueprint(player: int, start_building_id: int, end_building_id: int) -> void:
	if is_host():
		return
	if _wall_blueprint_manager == null or not _wall_blueprint_manager.has_method("request_network_wall_blueprint"):
		return
	_wall_blueprint_manager.call("request_network_wall_blueprint", player, start_building_id, end_building_id)


@rpc("authority", "reliable")
func _rpc_apply_build_place(player: int, building_key: Dictionary, x: int, y: int) -> void:
	if is_host():
		return
	if _building_manager == null or not _building_manager.has_method("request_network_build"):
		return
	_building_manager.call("request_network_build", player, building_key, Vector2i(x, y))


@rpc("authority", "reliable")
func _rpc_apply_recruit(player: int, building_id: int, unit_template_id: String, count: int) -> void:
	if is_host():
		return
	if _building_manager == null or not _building_manager.has_method("request_network_recruit"):
		return
	_building_manager.call("request_network_recruit", player, building_id, unit_template_id, count)


@rpc("authority", "reliable")
func _rpc_apply_gather_start(player: int, unit_id: int, x: int, y: int, info: Array) -> void:
	if is_host():
		return
	if _gathering_manager == null or not _gathering_manager.has_method("start_gather"):
		return
	_gathering_manager.call("start_gather", unit_id, player, Vector2i(x, y), info)


@rpc("authority", "reliable")
func _rpc_apply_gather_cancel(unit_id: int) -> void:
	if is_host():
		return
	if _gathering_manager == null or not _gathering_manager.has_method("cancel_gather"):
		return
	_gathering_manager.call("cancel_gather", unit_id)


@rpc("authority", "reliable")
func _rpc_apply_gather_complete(player: int, unit_id: int, x: int, y: int, results: Array) -> void:
	if is_host():
		return
	if _gathering_manager == null or not _gathering_manager.has_method("apply_network_gather_complete"):
		return
	_gathering_manager.call("apply_network_gather_complete", player, unit_id, Vector2i(x, y), results)


@rpc("authority", "reliable")
func _rpc_apply_tech_research(player: int, technology_id: String) -> void:
	if is_host():
		return
	if _technology_service == null:
		return
	if _technology_service.has_method("research_local"):
		_technology_service.call("research_local", player, technology_id)
