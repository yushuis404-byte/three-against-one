class_name BuildingData
## 建筑模板数据 — 通用建筑定义

enum BuildingCategory {
	CORE,
	ECONOMY,
	STORAGE,
	EXPANSION,
	SCOUT,
	RECRUITMENT,
	INDUSTRY,
	GOLD_CHAIN,
	RARE,
}

var name: String
var category: BuildingCategory
var footprint: Vector2i      # 宽×高（格数）
var cost_gold: int
var cost_wood: int
var cost_stone: int
var cost_iron: int
var cost_food: int
var hp_max: int
var production: Dictionary    # { resource_key: per_turn_amount }
var terrain_compatibility: Array[int]  # TerrainData.Terrain 枚举值列表
var max_per_faction: int
var description: String
var tech_tier: int = 0
var tags: Array[String] = []
var is_special_building: bool = false  # 特殊建筑标记（如金矿矿井需金矿资源点+驻兵产出）
var needs_resource_point: bool = false
var storage_level: int = 0
var storage_bonus: Dictionary = {}
var storage_bonus_by_level: Dictionary = {}
var max_level: int = 1
var upgrade_rules: Dictionary = {}
var preferred_worker_tag: String = ""  # Garrisoned workers with this tag provide the stronger production bonus.


func _init(p_name: String, p_cat: BuildingCategory, p_fp: Vector2i,
		p_gold: int, p_wood: int, p_stone: int, p_iron: int, p_food: int,
		p_hp: int, p_prod: Dictionary, p_terrain: Array[int],
		p_max: int, p_desc: String) -> void:
	name = p_name
	category = p_cat
	footprint = p_fp
	cost_gold = p_gold
	cost_wood = p_wood
	cost_stone = p_stone
	cost_iron = p_iron
	cost_food = p_food
	hp_max = p_hp
	production = p_prod
	terrain_compatibility = p_terrain
	max_per_faction = p_max
	description = p_desc


# ========== 静态工厂 ==========

static func town_hall() -> BuildingData:
	return BuildingData.new(
		"主城", BuildingCategory.CORE, Vector2i(2, 2),
		500, 0, 0, 0, 0,
		40, {},
		[TerrainData.Terrain.PLAIN_DWARF, TerrainData.Terrain.MOUNTAIN_DWARF,
		 TerrainData.Terrain.FOREST_ELF, TerrainData.Terrain.GLADE_ELF,
		 TerrainData.Terrain.WASTELAND_ORC, TerrainData.Terrain.SWAMP_ORC],
		1, "阵营核心，每阵营限 1 座，HP40 ATK5，淘汰条件"
	)

static func infra_lumber_camp() -> BuildingData:
	var b := BuildingData.new(
		"\u4f10\u6728\u573a", BuildingCategory.ECONOMY, Vector2i(1, 1),
		0, 8, 0, 0, 0,
		4, { "wood": 3 },
		[TerrainData.Terrain.PLAIN_DWARF, TerrainData.Terrain.FOREST_ELF,
		 TerrainData.Terrain.GLADE_ELF, TerrainData.Terrain.WASTELAND_ORC],
		7, "\u6bcf\u56de\u5408 +3 \u6728\u6750; \u7cbe\u7075\u5de5\u4eba +2, \u5176\u4ed6\u5de5\u4eba +1"
	)
	b.preferred_worker_tag = "elf"
	b.tech_tier = 0
	return b
static func infra_quarry() -> BuildingData:
	var b := BuildingData.new(
		"\u91c7\u77f3\u573a", BuildingCategory.ECONOMY, Vector2i(1, 1),
		0, 8, 2, 0, 0,
		4, { "stone": 3 },
		[TerrainData.Terrain.PLAIN_DWARF, TerrainData.Terrain.MOUNTAIN_DWARF,
		 TerrainData.Terrain.WASTELAND_ORC,
		 TerrainData.Terrain.FOREST_ELF,
		 TerrainData.Terrain.GLADE_ELF],
		7, "\u6bcf\u56de\u5408 +3 \u77f3\u6599; \u77ee\u4eba\u5de5\u4eba +2, \u5176\u4ed6\u5de5\u4eba +1"
	)
	b.preferred_worker_tag = "dwarf"
	b.tech_tier = 0
	return b
static func infra_farm() -> BuildingData:
	var b := BuildingData.new(
		"\u519c\u573a", BuildingCategory.ECONOMY, Vector2i(1, 1),
		0, 8, 0, 0, 2,
		4, { "food": 3 },
		[TerrainData.Terrain.PLAIN_DWARF, TerrainData.Terrain.GLADE_ELF,
		 TerrainData.Terrain.WASTELAND_ORC],
		7, "\u6bcf\u56de\u5408 +3 \u98df\u7269; \u517d\u4eba\u5de5\u4eba +2, \u5176\u4ed6\u5de5\u4eba +1"
	)
	b.preferred_worker_tag = "orc"
	b.tech_tier = 0
	return b
static func infra_warehouse() -> BuildingData:
	return warehouse_lv1()


static func warehouse_lv1() -> BuildingData:
	var b := BuildingData.new(
		"\u4ed3\u5e93 Lv1", BuildingCategory.STORAGE, Vector2i(1, 1),
		0, 25, 15, 0, 0,
		6, {},
		[TerrainData.Terrain.PLAIN_DWARF, TerrainData.Terrain.FOREST_ELF,
		 TerrainData.Terrain.MOUNTAIN_DWARF, TerrainData.Terrain.GLADE_ELF,
		 TerrainData.Terrain.WASTELAND_ORC],
		3, "\u8d44\u6e90\u50a8\u5b58\u4e0a\u9650 +20"
	)
	b.storage_level = 1
	b.storage_bonus = _storage_bonus_for(20)
	b.storage_bonus_by_level = {
		1: _storage_bonus_for(20),
		2: _storage_bonus_for(55),
		3: _storage_bonus_for(115),
	}
	b.max_level = 3
	b.tech_tier = 1
	b.upgrade_rules = {
		2: {
			"cost": {"wood": 30, "stone": 20, "iron": 5},
			"requires_garrison_worker": true,
		},
		3: {
			"cost": {"wood": 50, "stone": 35, "iron": 15, "food": 5},
			"requires_garrison_worker": true,
		},
	}
	return b

static func t1_mine() -> BuildingData:
	var b := BuildingData.new(
		"\u77ff\u4e95", BuildingCategory.INDUSTRY, Vector2i(1, 1),
		0, 25, 20, 0, 0,
		6, { "iron": 2 },
		[TerrainData.Terrain.MOUNTAIN_DWARF],
		6, "\u6bcf\u56de\u5408 +2 \u94c1\u77ff; \u77ee\u4eba\u5de5\u4eba +2, \u5176\u4ed6\u5de5\u4eba +1"
	)
	b.preferred_worker_tag = "dwarf"
	b.tech_tier = 1
	return b
static func t1_extraction_tower() -> BuildingData:
	var b := BuildingData.new(
		"\u8403\u53d6\u5854", BuildingCategory.RARE, Vector2i(1, 1),
		0, 35, 25, 5, 0,
		6, { "magic_dust": 2 },
		[TerrainData.Terrain.RUINS],
		6, "\u6bcf\u56de\u5408 +2 \u9b54\u5c18; \u7cbe\u7075\u5de5\u4eba +2, \u5176\u4ed6\u5de5\u4eba +1"
	)
	b.preferred_worker_tag = "elf"
	b.tech_tier = 3
	return b
static func t1_ancient_wood_harvest() -> BuildingData:
	var b := BuildingData.new(
		"\u53e4\u6728\u91c7\u96c6\u573a", BuildingCategory.RARE, Vector2i(1, 1),
		0, 40, 20, 0, 5,
		6, { "ancient_wood": 2 },
		[TerrainData.Terrain.FOREST_ELF],
		6, "\u6bcf\u56de\u5408 +2 \u53e4\u6728; \u7cbe\u7075\u5de5\u4eba +2, \u5176\u4ed6\u5de5\u4eba +1"
	)
	b.preferred_worker_tag = "elf"
	b.tech_tier = 3
	return b
static func barracks_lv1() -> BuildingData:
	var b := BuildingData.new(
		"\u5175\u8425", BuildingCategory.RECRUITMENT, Vector2i(1, 1),
		0, 40, 25, 0, 10,
		8, {},
		[TerrainData.Terrain.PLAIN_DWARF, TerrainData.Terrain.FOREST_ELF,
		 TerrainData.Terrain.GLADE_ELF, TerrainData.Terrain.WASTELAND_ORC],
		99, "Lv1 \u53ef\u62db\u52df\u5b88\u536b\u3001\u65a5\u5019"
	)
	b.tech_tier = 1
	b.tags = ["recruit", "military", "barracks"]
	return b

static func scout_post() -> BuildingData:
	var b := BuildingData.new(
		"\u4fa6\u5bdf\u54e8", BuildingCategory.SCOUT, Vector2i(1, 1),
		0, 20, 10, 0, 0,
		4, {},
		[TerrainData.Terrain.PLAIN_DWARF, TerrainData.Terrain.FOREST_ELF,
		 TerrainData.Terrain.MOUNTAIN_DWARF, TerrainData.Terrain.GLADE_ELF,
		 TerrainData.Terrain.WASTELAND_ORC],
		4, "\u89c6\u91ce +2"
	)
	b.tech_tier = 1
	b.tags = ["scout", "vision"]
	return b

static func outpost() -> BuildingData:
	var b := BuildingData.new(
		"\u524d\u54e8\u7ad9", BuildingCategory.EXPANSION, Vector2i(1, 1),
		0, 30, 20, 0, 5,
		10, {},
		[TerrainData.Terrain.PLAIN_DWARF, TerrainData.Terrain.FOREST_ELF,
		 TerrainData.Terrain.MOUNTAIN_DWARF, TerrainData.Terrain.GLADE_ELF,
		 TerrainData.Terrain.WASTELAND_ORC, TerrainData.Terrain.SWAMP_ORC],
		4, "\u6269\u5f20\u9886\u571f\u8303\u56f4\uff0c\u7528\u4e8e\u63a7\u5236\u8d44\u6e90\u70b9\u548c\u5efa\u7acb\u524d\u7ebf\u57fa\u5730"
	)
	b.tech_tier = 1
	b.tags = ["expansion", "territory"]
	return b

static func recruit_camp() -> BuildingData:
	var b := BuildingData.new(
		"\u62db\u52df\u8425", BuildingCategory.RECRUITMENT, Vector2i(1, 1),
		0, 20, 15, 0, 0,
		4, {},
		[TerrainData.Terrain.PLAIN_DWARF, TerrainData.Terrain.MOUNTAIN_DWARF,
		 TerrainData.Terrain.FOREST_ELF, TerrainData.Terrain.GLADE_ELF,
		 TerrainData.Terrain.WASTELAND_ORC, TerrainData.Terrain.SWAMP_ORC],
		3, "\u62db\u52df\u5de5\u4eba"
	)
	b.tech_tier = 1
	b.tags = ["recruit", "worker", "recruit_camp"]
	return b

static func get_templates() -> Dictionary:
	## 返回按分类分组的全部建筑模板
	return {
		BuildingCategory.CORE: [town_hall()],
		BuildingCategory.ECONOMY: [infra_lumber_camp(), infra_quarry(), infra_farm()],
		BuildingCategory.STORAGE: [infra_warehouse()],
		BuildingCategory.EXPANSION: [outpost()],
		BuildingCategory.SCOUT: [scout_post()],
		BuildingCategory.RECRUITMENT: [recruit_camp(), barracks_lv1()],
		BuildingCategory.INDUSTRY: [t1_mine()],
		BuildingCategory.GOLD_CHAIN: [gold_mine_shaft(), mint()],
		BuildingCategory.RARE: [t1_extraction_tower(), t1_ancient_wood_harvest()],
	}


static func _storage_bonus_for(amount: int) -> Dictionary:
	return {
		"wood": amount,
		"stone": amount,
		"food": amount,
		"iron": amount,
		"magic_dust": amount,
		"ancient_wood": amount,
		"gold_ore": amount,
	}


static func gold_mine_shaft() -> BuildingData:
	var b := BuildingData.new(
		"金矿矿井", BuildingCategory.GOLD_CHAIN, Vector2i(1, 1),
		0, 20, 15, 0, 0,
		6, {},
		[TerrainData.Terrain.PLAIN_DWARF, TerrainData.Terrain.MOUNTAIN_DWARF,
		 TerrainData.Terrain.FOREST_ELF, TerrainData.Terrain.GLADE_ELF,
		 TerrainData.Terrain.WASTELAND_ORC, TerrainData.Terrain.SWAMP_ORC,
		 TerrainData.Terrain.RUINS],
		2, "需建在金矿上，需入驻工人，每驻 1 工 → +2 金矿石/回合"
	)
	b.is_special_building = true
	b.needs_resource_point = true
	b.tech_tier = 2
	return b


static func mint() -> BuildingData:
	var b := BuildingData.new(
		"金币铸造厂", BuildingCategory.GOLD_CHAIN, Vector2i(1, 1),
		0, 30, 20, 5, 0,
		6, {},
		[TerrainData.Terrain.PLAIN_DWARF, TerrainData.Terrain.MOUNTAIN_DWARF,
		 TerrainData.Terrain.FOREST_ELF, TerrainData.Terrain.GLADE_ELF,
		 TerrainData.Terrain.WASTELAND_ORC, TerrainData.Terrain.SWAMP_ORC,
		 TerrainData.Terrain.RUINS],
		2, "需入驻工人，消耗金矿石产出金币。每驻 1 工 → +2 金币/回合（消耗 1 金矿石）"
	)
	b.is_special_building = true
	b.tech_tier = 2
	return b
