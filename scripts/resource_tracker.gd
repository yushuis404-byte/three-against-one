extends Node
## 资源追踪器 — 记录每阵营资源库存
##
## 在 round_ended 时从建筑收集产出，更新 UI 显示
## 作为 GameBoard 的子节点，由 main.gd 初始化

var _resources: Array = [{}, {}, {}]  # Array[Dictionary]
var _building_mgr: Node = null
var _turn_mgr: Node = null

# UI Label 引用：_label_refs["wood"] = Label 等
var _label_refs: Dictionary = {}
var _faction_label: Label = null

signal resources_updated(player: int)

const RESOURCE_KEYS := ["wood", "stone", "food", "iron", "magic_dust", "ancient_wood", "gold_ore"]
const RESOURCE_NAMES := {
	"wood": "木材",
	"stone": "石料",
	"food": "食物",
	"iron": "铁矿",
	"magic_dust": "魔尘",
	"ancient_wood": "古木",
	"gold_ore": "金矿",
}


func _ready() -> void:
	_init_resources()


func _init_resources() -> void:
	for p in range(3):
		var d: Dictionary = {}
		for key in RESOURCE_KEYS:
			d[key] = 0
		_resources[p] = d


func set_turn_manager(tm: Node) -> void:
	_turn_mgr = tm
	if tm:
		tm.round_ended.connect(_on_round_ended)


func set_building_manager(bm: Node) -> void:
	_building_mgr = bm


func set_faction_label(label: Label) -> void:
	_faction_label = label


func set_resource_label(key: String, label: Label) -> void:
	_label_refs[key] = label


func add_resource(player: int, key: String, amount: int) -> void:
	if not _resources[player].has(key):
		return
	_resources[player][key] += amount
	resources_updated.emit(player)


func get_resource(player: int, key: String) -> int:
	return _resources[player].get(key, 0)


func get_all(player: int) -> Dictionary:
	return _resources[player].duplicate()


func _on_round_ended(_round: int) -> void:
	if not _building_mgr or not _building_mgr.has_method("get_all_buildings"):
		return
	var buildings: Array = _building_mgr.get_all_buildings()
	for b in buildings:
		var prod: Dictionary = b["data"].production
		if prod.is_empty():
			continue
		var faction: int = b["faction"]
		for key in prod:
			add_resource(faction, key, prod[key])


func update_display(player: int) -> void:
	var res: Dictionary = _resources[player]

	# 阵营标题
	if _faction_label:
		var fname := ""
		match player:
			0: fname = "精灵"
			1: fname = "矮人"
			2: fname = "兽人"
		_faction_label.text = "[%s] 资源" % fname

	# 资源数值
	for key in RESOURCE_KEYS:
		if _label_refs.has(key):
			var label: Label = _label_refs[key]
			var name: String = RESOURCE_NAMES.get(key, key)
			label.text = "%s: %d" % [name, res.get(key, 0)]
