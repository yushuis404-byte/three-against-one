extends Node2D
## 采集管理器 — 独立管理工人的资源采集逻辑
##
## 工人移动到资源格时由 UnitManager2D 调用 start_gather() 登记
## 下一回合该阵营开始时结算：工人还在资源格上 → 获得资源 → 资源点消失

const RESOURCE_DISPLAY_NAMES: Dictionary = {
	"wood": "木材",
	"food": "食物",
	"stone": "石料",
	"iron": "铁矿",
	"gold_ore": "金矿石",
	"ancient_wood": "古木",
	"magic_dust": "魔尘",
}

const TILE_SIZE := 32.0
const GRID_CENTER := Vector2(49.5, 27.5)

var _turn_mgr: Node = null
var _unit_mgr: Node = null
var _res_mgr: Node = null
var _tracker: Node = null

var _pending_gathers: Array = []  # Array[Dictionary] — { faction, pos: Vector2i, info: Dictionary }


func _ready() -> void:
	_turn_mgr = get_parent().get_node("TurnManager2D")
	_unit_mgr = get_parent().get_node("UnitManager2D")
	_res_mgr = get_parent().get_node("ResourceManager2D")
	_tracker = get_parent().get_node("ResourceTracker")

	if _turn_mgr:
		_turn_mgr.player_turn_started.connect(_on_player_turn_started)


func start_gather(faction: int, pos: Vector2i, info: Array) -> void:
	## 被 UnitManager2D 调用：工人到达资源格，登记采集
	_pending_gathers.append({ "faction": faction, "pos": pos, "info": info })


func _on_player_turn_started(player: int) -> void:
	var i := 0
	while i < _pending_gathers.size():
		var g = _pending_gathers[i]
		if g["faction"] != player:
			i += 1
			continue

		# 检查工人是否还在资源格上
		var still_gathering := false
		if _unit_mgr and _unit_mgr.has_method("get_unit_at"):
			var unit: Dictionary = _unit_mgr.get_unit_at(g["pos"])
			if not unit.is_empty() and unit["faction"] == player:
				var data: UnitData = unit["data"]
				if _can_unit_complete_gather(data, g.get("info", [])):
					still_gathering = true

		if still_gathering:
			# 检查资源是否还存在
			if _res_mgr and _res_mgr.has_method("get_gather_result"):
				var results: Array = _res_mgr.get_gather_result(g["pos"].x, g["pos"].y)
				if not results.is_empty():
					if _tracker:
						for r in results:
							var entry: Dictionary = r
							_tracker.add_resource(player, entry["key"], entry["amount"])
					if _res_mgr.has_method("remove_resource"):
						_res_mgr.remove_resource(g["pos"].x, g["pos"].y)
					_show_gather_text(g["pos"], results)

		# 删除该条采集记录（无论成功与否）
		_pending_gathers.remove_at(i)


func _show_gather_text(grid_pos: Vector2i, results: Array) -> void:
	## 在资源格位置创建浮动文字 "+2 木材" 或 "+2 食物+2 木材" 并向上飘散消失
	var label := Label.new()
	var parts: PackedStringArray = []
	for r in results:
		var entry: Dictionary = r
		var display: String = RESOURCE_DISPLAY_NAMES.get(entry["key"], entry["key"])
		parts.append("+%d %s" % [entry["amount"], display])
	label.text = "\n".join(parts)
	label.add_theme_color_override("font_color", Color(0.5, 1.0, 0.5))
	label.add_theme_font_size_override("font_size", 14)
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART

	var world_pos := _grid_to_world(grid_pos.x, grid_pos.y)
	label.position = Vector2(world_pos.x - 40, world_pos.y - 30)
	add_child(label)

	var tween := create_tween()
	tween.set_trans(Tween.TRANS_SINE)
	tween.tween_property(label, "position", label.position + Vector2(0, -30), 1.0)
	tween.parallel().tween_property(label, "modulate:a", 0.0, 1.0)
	tween.tween_callback(label.queue_free)


func _can_unit_complete_gather(data: UnitData, gather_info: Array) -> bool:
	if data.category == UnitData.UnitCategory.WORKER:
		return true
	for result in gather_info:
		var entry: Dictionary = result
		if str(entry.get("key", "")) == "food":
			return true
	return false

func _grid_to_world(grid_x: int, grid_y: int) -> Vector2:
	var offset := Vector2(-GRID_CENTER.x * TILE_SIZE, -GRID_CENTER.y * TILE_SIZE)
	return Vector2(grid_x * TILE_SIZE + offset.x, grid_y * TILE_SIZE + offset.y)
