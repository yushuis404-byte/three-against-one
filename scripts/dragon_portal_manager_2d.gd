extends Node2D

const DragonPortalConfirmPanelScript := preload("res://scripts/ui/dragon_portal_confirm_panel.gd")

signal portal_hovered(text: String)

const MAX_UNITS_PER_TELEPORT := 6
const INTERACTION_RANGE := 5
const EXIT_AP_COST_PER_UNIT := 1
const PORTAL_SIZE := Vector2i(1, 1)
const TILE_SIZE := 32.0
const PORTAL_TEXTURE: Texture2D = preload("res://assets/texture/dragon door.png")

var _grid_manager: Node = null
var _unit_manager: Node = null
var _turn_manager: Node = null
var _confirm_panel: DragonPortalConfirmPanel = null
var _portals: Array[Dictionary] = []
var _last_hover_text := ""
var _fog_of_war: Node = null


func _ready() -> void:
	z_index = 2
	_bind_siblings()
	_build_portals()
	_ensure_confirm_panel()
	set_process(true)
	queue_redraw()


func set_turn_manager(turn_manager: Node) -> void:
	_turn_manager = turn_manager


func _process(_delta: float) -> void:
	_update_hover_text()


func _input(event: InputEvent) -> void:
	if not (event is InputEventMouseButton):
		return
	var mouse_event: InputEventMouseButton = event
	if mouse_event.button_index != MOUSE_BUTTON_LEFT or not mouse_event.pressed:
		return
	if _confirm_panel != null and _confirm_panel.visible:
		return
	var grid_pos: Vector2i = _world_to_grid(get_global_mouse_position())
	var portal_end: Dictionary = _get_portal_end_at(grid_pos)
	if portal_end.is_empty():
		return
	get_viewport().set_input_as_handled()
	_request_portal_use(portal_end)


func _draw() -> void:
	var viewer: int = int(_turn_manager.get("current_player")) if _turn_manager != null else -1
	for portal in _portals:
		var outer_anchor: Vector2i = portal.get("outer_anchor", Vector2i.ZERO)
		var inner_anchor: Vector2i = portal.get("inner_anchor", Vector2i.ZERO)
		if viewer < 0 or _is_cell_visible(viewer, outer_anchor):
			_draw_portal_end(portal, "outer")
		if viewer < 0 or _is_cell_visible(viewer, inner_anchor):
			_draw_portal_end(portal, "inner")


func _bind_siblings() -> void:
	if get_parent() == null:
		return
	_grid_manager = get_parent().get_node_or_null("GridManager2D")
	_unit_manager = get_parent().get_node_or_null("UnitManager2D")
	set_turn_manager(get_parent().get_node_or_null("TurnManager2D"))
	_fog_of_war = get_parent().get_node_or_null("FogOfWar2D")


func _build_portals() -> void:
	_portals = [
		_make_portal("elf", "精灵龙门", 0, Vector2i(50, 21), Vector2i(50, 24)),
		_make_portal("dwarf", "矮人龙门", 1, Vector2i(44, 33), Vector2i(46, 30)),
		_make_portal("orc", "兽人龙门", 2, Vector2i(56, 33), Vector2i(53, 30)),
	]


func _make_portal(id: String, display_name: String, faction: int, outer_origin: Vector2i, inner_origin: Vector2i) -> Dictionary:
	return {
		"id": id,
		"display_name": display_name,
		"faction": faction,
		"outer_cells": _rect_cells(outer_origin, PORTAL_SIZE),
		"inner_cells": _rect_cells(inner_origin, PORTAL_SIZE),
		"outer_anchor": outer_origin,
		"inner_anchor": inner_origin,
	}


func _rect_cells(origin: Vector2i, footprint: Vector2i) -> Array[Vector2i]:
	var cells: Array[Vector2i] = []
	for y in range(origin.y, origin.y + footprint.y):
		for x in range(origin.x, origin.x + footprint.x):
			cells.append(Vector2i(x, y))
	return cells


func _ensure_confirm_panel() -> void:
	if _confirm_panel != null:
		return
	var ui_root: Node = null
	if get_parent() != null and get_parent().get_parent() != null:
		ui_root = get_parent().get_parent().get_node_or_null("UI")
	if ui_root == null:
		return
	_confirm_panel = DragonPortalConfirmPanelScript.new()
	_confirm_panel.name = "DragonPortalConfirmPanel"
	_confirm_panel.z_index = 120
	ui_root.add_child(_confirm_panel)
	_confirm_panel.confirmed.connect(_on_confirm_panel_confirmed)


func _request_portal_use(portal_end: Dictionary) -> void:
	_bind_siblings()
	if _turn_manager == null or _unit_manager == null:
		_show_notice("无法使用巨龙传送门", "传送门系统还没有连接回合或单位系统。")
		return

	var player: int = int(_turn_manager.get("current_player"))
	var portal_faction: int = int(portal_end.get("faction", -1))
	if player != portal_faction:
		_show_notice("无法使用巨龙传送门", "每个阵营只能使用自己对应的巨龙传送门。")
		return

	if _turn_manager.has_method("can_player_act") and not bool(_turn_manager.call("can_player_act", player)):
		_show_notice("无法使用巨龙传送门", "当前阵营已经结束行动，不能再使用传送门。")
		return

	var source_cells: Array = portal_end.get("source_cells", [])
	var selected_ids: Array = _unit_manager.call("get_selected_unit_ids")
	if selected_ids.is_empty():
		_show_notice("无法使用巨龙传送门", "请先选择需要传送的己方单位。")
		return

	var eligible_ids: Array = _unit_manager.call("get_selected_units_near_cells", selected_ids, source_cells, INTERACTION_RANGE, 0)
	if eligible_ids.is_empty():
		_show_notice("无法使用巨龙传送门", "选中的单位不在传送门 5 格范围内。")
		return

	var teleport_ids: Array[int] = []
	var limit: int = mini(MAX_UNITS_PER_TELEPORT, eligible_ids.size())
	for i in range(limit):
		teleport_ids.append(int(eligible_ids[i]))

	var direction: String = str(portal_end.get("direction", "enter"))
	var ap_cost := 0
	if direction == "exit":
		ap_cost = teleport_ids.size() * EXIT_AP_COST_PER_UNIT
		if _turn_manager.has_method("get_ap") and int(_turn_manager.call("get_ap", player)) < ap_cost:
			_show_notice("无法传出巨龙巢穴", "传出每个单位需要 1 AP，当前 AP 不足。")
			return

	var target_anchor: Vector2i = portal_end.get("target_anchor", Vector2i.ZERO)
	var payload := {
		"player": player,
		"unit_ids": teleport_ids,
		"target_anchor": target_anchor,
		"direction": direction,
		"ap_cost": ap_cost,
	}
	var title := "使用巨龙传送门"
	var body := _build_confirm_body(direction, selected_ids.size(), eligible_ids.size(), teleport_ids.size(), ap_cost)
	if _confirm_panel == null:
		_ensure_confirm_panel()
	if _confirm_panel == null:
		_execute_portal_payload(payload)
		return
	_confirm_panel.show_request(title, body, payload, true)


func _build_confirm_body(direction: String, selected_count: int, eligible_count: int, teleport_count: int, ap_cost: int) -> String:
	var target_text := "进入巨龙巢穴内部"
	if direction == "exit":
		target_text = "返回阵营外部入口"
	var lines: Array[String] = []
	lines.append("将传送 %d 个单位：%s。" % [teleport_count, target_text])
	if selected_count > eligible_count:
		lines.append("已选择 %d 个单位，其中 %d 个在传送门 5 格范围内。" % [selected_count, eligible_count])
	if eligible_count > MAX_UNITS_PER_TELEPORT:
		lines.append("一次最多传送 %d 个单位，本次会传送距离最近的 %d 个。" % [MAX_UNITS_PER_TELEPORT, teleport_count])
	if direction == "enter":
		lines.append("没有点出瘴气护盾科技时，巢穴内会持续受到瘴气伤害。")
	else:
		lines.append("传出需要消耗 %d AP，每个单位 1 AP。" % ap_cost)
	return "\n".join(lines)


func _on_confirm_panel_confirmed(payload: Dictionary) -> void:
	_execute_portal_payload(payload)


func _execute_portal_payload(payload: Dictionary) -> void:
	if _turn_manager == null or _unit_manager == null:
		return
	var player: int = int(payload.get("player", -1))
	if player != int(_turn_manager.get("current_player")):
		_show_notice("无法使用巨龙传送门", "当前已经不是发起传送的玩家回合。")
		return
	if _turn_manager.has_method("can_player_act") and not bool(_turn_manager.call("can_player_act", player)):
		_show_notice("无法使用巨龙传送门", "当前阵营已经结束行动，不能再使用传送门。")
		return

	var ap_cost: int = int(payload.get("ap_cost", 0))
	if ap_cost > 0:
		if not _turn_manager.has_method("spend_ap") or not bool(_turn_manager.call("spend_ap", player, ap_cost)):
			_show_notice("无法传出巨龙巢穴", "传出所需 AP 不足。")
			return

	var unit_ids: Array = payload.get("unit_ids", [])
	var target_anchor: Vector2i = payload.get("target_anchor", Vector2i.ZERO)
	var forbidden_cells: Array[Vector2i] = []
	if str(payload.get("direction", "enter")) == "enter":
		forbidden_cells.append(target_anchor)
	var result: Dictionary = _unit_manager.call("teleport_units_to_nearest_empty", unit_ids, target_anchor, randi(), forbidden_cells)
	if not bool(result.get("success", false)):
		_show_notice("无法使用巨龙传送门", "出口附近没有足够空格，传送没有执行。")
		if ap_cost > 0 and _turn_manager.has_method("add_ap"):
			_turn_manager.call("add_ap", player, ap_cost)
		return
	queue_redraw()


func _show_notice(title: String, body: String) -> void:
	if _confirm_panel == null:
		_ensure_confirm_panel()
	if _confirm_panel != null:
		_confirm_panel.show_request(title, body, {}, false)
	else:
		print("[DragonPortal] %s: %s" % [title, body])


func _get_portal_end_at(grid_pos: Vector2i) -> Dictionary:
	for portal in _portals:
		var outer_cells: Array = portal.get("outer_cells", [])
		if grid_pos in outer_cells:
			return {
				"portal_id": str(portal.get("id", "")),
				"faction": int(portal.get("faction", -1)),
				"source_cells": outer_cells,
				"target_anchor": portal.get("inner_anchor", Vector2i.ZERO),
				"direction": "enter",
			}
		var inner_cells: Array = portal.get("inner_cells", [])
		if grid_pos in inner_cells:
			return {
				"portal_id": str(portal.get("id", "")),
				"faction": int(portal.get("faction", -1)),
				"source_cells": inner_cells,
				"target_anchor": portal.get("outer_anchor", Vector2i.ZERO),
				"direction": "exit",
			}
	return {}


func _draw_portal_end(portal: Dictionary, side: String) -> void:
	var anchor: Vector2i = portal.get("%s_anchor" % side, Vector2i.ZERO)
	var portal_center := _grid_to_world(anchor.x, anchor.y)
	var tex_size := 48.0
	draw_texture_rect(PORTAL_TEXTURE, Rect2(portal_center - Vector2(tex_size, tex_size) * 0.5, Vector2(tex_size, tex_size)), false)


func _is_cell_visible(player: int, cell: Vector2i) -> bool:
	if _fog_of_war == null or not _fog_of_war.has_method("get_fog"):
		return true
	return _fog_of_war.get_fog(player, cell.x, cell.y) <= 0.0



func _update_hover_text() -> void:
	var grid_pos: Vector2i = _world_to_grid(get_global_mouse_position())
	var portal_end: Dictionary = _get_portal_end_at(grid_pos)
	var text := ""
	if not portal_end.is_empty():
		var direction: String = str(portal_end.get("direction", "enter"))
		if direction == "enter":
			text = "巨龙传送门：选择 5 格内单位进入巢穴"
		else:
			text = "巨龙传送门：选择 5 格内单位传出，每个单位 1 AP"
	if text == _last_hover_text:
		return
	_last_hover_text = text
	portal_hovered.emit(text)


func _grid_to_world(grid_x: int, grid_y: int) -> Vector2:
	if _grid_manager != null and _grid_manager.has_method("grid_to_world"):
		return _grid_manager.call("grid_to_world", grid_x, grid_y)
	var offset := Vector2(-49.5 * TILE_SIZE, -27.5 * TILE_SIZE)
	return Vector2(grid_x * TILE_SIZE + offset.x, grid_y * TILE_SIZE + offset.y)


func _world_to_grid(world_pos: Vector2) -> Vector2i:
	if _grid_manager != null and _grid_manager.has_method("world_to_grid"):
		return _grid_manager.call("world_to_grid", world_pos)
	var offset := Vector2(-49.5 * TILE_SIZE, -27.5 * TILE_SIZE)
	return Vector2i(int(roundf((world_pos.x - offset.x) / TILE_SIZE)), int(roundf((world_pos.y - offset.y) / TILE_SIZE)))
