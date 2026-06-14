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
var template_id: String = ""
var tags: Array[String] = []


func _init(p_name: String, p_cat: UnitCategory, p_move: int, p_atk: int, p_hp: int, p_vision: int, p_food: int = 1):
	unit_name = p_name
	category = p_cat
	move_max = p_move
	atk = p_atk
	hp_max = p_hp
	vision = p_vision
	food_cost = p_food


static func from_template(template: Resource) -> UnitData:
	if template == null or not template.has_method("to_unit_data"):
		return UnitData.new("", UnitCategory.SPECIAL, 0, 0, 1, 0, 0)
	var data: UnitData = template.call("to_unit_data")
	data.template_id = str(template.get("id"))
	var template_tags: Array = template.get("tags")
	data.tags = []
	for tag in template_tags:
		data.tags.append(str(tag))
	return data


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
