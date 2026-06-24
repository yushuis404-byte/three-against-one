extends Node
## 资源追踪器 — 记录每阵营资源库存
##
## 在 round_ended 时从建筑收集产出，更新 UI 显示
## 作为 GameBoard 的子节点，由 main.gd 初始化

var _resources: Array = [{}, {}, {}]  # Array[Dictionary]
var _building_mgr: Node = null
var _turn_mgr: Node = null
var _technology_service: Node = null

const CAPPED_RESOURCE_KEYS := ["wood", "stone", "food", "iron", "magic_dust", "ancient_wood", "gold_ore"]
const BASE_RESOURCE_CAPS := {
	"wood": 50,
	"stone": 50,
	"food": 50,
	"iron": 40,
	"magic_dust": 30,
	"ancient_wood": 30,
	"gold_ore": 40,
}

# UI Label 引用：_label_refs["wood"] = Label 等
var _label_refs: Dictionary = {}
var _faction_label: Label = null

signal resources_updated(player: int)


func _ready() -> void:
	_init_resources()


func _init_resources() -> void:
	for p in range(3):
		var d: Dictionary = {}
		for key in GameCatalog.RESOURCE_KEYS:
			d[key] = 0
		d["gold"] = 0  # 初始金币
		_resources[p] = d


func set_turn_manager(tm: Node) -> void:
	_turn_mgr = tm
	if tm:
		tm.round_ended.connect(_on_round_ended)


func set_building_manager(bm: Node) -> void:
	_building_mgr = bm


func set_technology_service(service: Node) -> void:
	_technology_service = service


func set_faction_label(label: Label) -> void:
	_faction_label = label


func set_resource_label(key: String, label: Label) -> void:
	_label_refs[key] = label


func add_resource(player: int, key: String, amount: int) -> void:
	if not _resources[player].has(key):
		return
	var current: int = int(_resources[player][key])
	var next_value: int = current + amount
	var cap: int = get_resource_cap(player, key)
	if cap >= 0:
		next_value = mini(next_value, cap)
	_resources[player][key] = next_value
	resources_updated.emit(player)


func get_resource(player: int, key: String) -> int:
	return _resources[player].get(key, 0)


func spend_resource(player: int, key: String, amount: int) -> bool:
	## 扣减资源，返回是否成功（余额不足返回 false）
	if not _resources[player].has(key):
		return false
	if _resources[player][key] < amount:
		return false
	_resources[player][key] -= amount
	resources_updated.emit(player)
	return true


func get_all(player: int) -> Dictionary:
	return _resources[player].duplicate()


func get_resource_cap(player: int, key: String) -> int:
	if not (key in CAPPED_RESOURCE_KEYS):
		return -1
	var cap: int = int(BASE_RESOURCE_CAPS.get(key, 0))
	cap += _get_technology_modifier(player, "storage_flat_bonus")
	if not _building_mgr or not _building_mgr.has_method("get_all_buildings"):
		return cap
	var buildings: Array = _building_mgr.get_all_buildings()
	for building in buildings:
		if int(building.get("faction", -1)) != player:
			continue
		var data: BuildingData = building.get("data", null)
		if data == null:
			continue
		var level: int = int(building.get("level", maxi(1, data.storage_level)))
		var bonus: Dictionary = data.storage_bonus
		if not data.storage_bonus_by_level.is_empty():
			bonus = data.storage_bonus_by_level.get(level, data.storage_bonus)
		if bonus.has(key):
			cap += int(bonus[key])
	return cap


func get_resource_caps(player: int) -> Dictionary:
	var result: Dictionary = {}
	for key in CAPPED_RESOURCE_KEYS:
		result[key] = get_resource_cap(player, key)
	return result


func _on_round_ended(_round: int) -> void:
	if not _building_mgr or not _building_mgr.has_method("get_all_buildings"):
		return
	var buildings: Array = _building_mgr.get_all_buildings()
	for b in buildings:
		var prod: Dictionary = b["data"].production
		var faction: int = b["faction"]

		# 基础产出
		if not prod.is_empty():
			for key in prod:
				add_resource(faction, key, int(prod[key]) + _get_production_bonus(faction, str(key)))

		# 驻兵加成（独立判断，即使无基础产出也可能有加成）
		if _building_mgr.has_method("get_garrison_bonus"):
			var bonus: Dictionary = _building_mgr.get_garrison_bonus(b["id"])
			if not bonus.is_empty():
				for key in bonus:
					add_resource(faction, key, int(bonus[key]) + _get_garrison_production_bonus(faction))


	# 金币铸造厂：消耗金矿石 → 产出金币
	for b in buildings:
		if BuildingRules.is_mint(b["data"]):
			var faction: int = b["faction"]
			var garr: Array = b.get("garrison", [])
			var gcount := garr.size()
			if gcount > 0:
				var max_gold := gcount * 2 + _get_technology_modifier(faction, "mint_conversion_bonus")
				var ore_avail := get_resource(faction, "gold_ore")
				var ore_use := mini(max_gold, ore_avail)
				if ore_use > 0:
					spend_resource(faction, "gold_ore", ore_use)
					add_resource(faction, "gold", ore_use)
					print("[资源] 阵营 %d 金币铸造厂: 消耗 %d 金矿石 → 产出 %d 金币" % [faction, ore_use, ore_use])

func update_display(player: int) -> void:
	var res: Dictionary = _resources[player]

	# 阵营标题
	if _faction_label:
		_faction_label.text = "[%s] 资源" % GameCatalog.faction_name(player)

	# 资源数值
	for key in GameCatalog.RESOURCE_KEYS:
		if _label_refs.has(key):
			var label: Label = _label_refs[key]
			var name: String = GameCatalog.resource_name(key)
			var cap: int = get_resource_cap(player, key)
			if cap >= 0:
				label.text = "%s: %d/%d" % [name, res.get(key, 0), cap]
			else:
				label.text = "%s: %d" % [name, res.get(key, 0)]


func _get_production_bonus(player: int, key: String) -> int:
	match key:
		"iron":
			return _get_technology_modifier(player, "iron_production_bonus")
		"ancient_wood":
			return _get_technology_modifier(player, "ancient_wood_production_bonus")
		"gold_ore":
			return _get_technology_modifier(player, "gold_ore_production_bonus")
	return 0


func _get_garrison_production_bonus(player: int) -> int:
	return _get_technology_modifier(player, "garrison_production_bonus") + _get_technology_modifier(player, "worker_garrison_bonus")


func _get_technology_modifier(player: int, key: String) -> int:
	if _technology_service == null and is_inside_tree():
		_technology_service = get_parent().get_node_or_null("TechnologyService")
	if _technology_service != null and _technology_service.has_method("get_modifier"):
		return int(_technology_service.call("get_modifier", player, key, 0))
	return 0
