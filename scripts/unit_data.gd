class_name UnitData
## 单位模板数据

enum UnitCategory { WORKER, SCOUT, GUARD, ELITE, SIEGE, SPECIAL }

var unit_name: String
var category: UnitCategory
var move_max: int
var atk: int
var hp_max: int
var vision: int
var food_cost: int


func _init(p_name: String, p_cat: UnitCategory, p_move: int, p_atk: int, p_hp: int, p_vision: int, p_food: int = 1):
	unit_name = p_name
	category = p_cat
	move_max = p_move
	atk = p_atk
	hp_max = p_hp
	vision = p_vision
	food_cost = p_food


static func worker() -> UnitData:
	return UnitData.new("工人", UnitCategory.WORKER, 1, 0, 3, 1, 1)

static func scout() -> UnitData:
	return UnitData.new("斥候", UnitCategory.SCOUT, 3, 1, 3, 3, 1)

static func guard() -> UnitData:
	return UnitData.new("守卫", UnitCategory.GUARD, 1, 3, 6, 1, 2)


static func get_faction_name(faction: int) -> String:
	match faction:
		0: return "精灵"
		1: return "矮人"
		2: return "兽人"
	return "中立"
