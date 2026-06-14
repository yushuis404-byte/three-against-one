class_name BuildingData
## 建筑模板数据 — 通用建筑定义

enum BuildingCategory {
	INFRA,         # 基础设施（伐木场/采石场/农场/仓库/金矿矿井/金币铸造厂）
	T1_RESOURCE,   # T1 资源采集（矿井/萃取塔/古木采集场）
	GOLD_CHAIN,    # 金币链（金矿矿井）
	MILITARY,      # 军事（兵营）
	SCOUT,         # 侦察（侦察哨）
	RECRUIT,       # 招募（招募营）
	TOWN_HALL,     # 主城
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
var is_special_building: bool = false  # 特殊建筑标记（如金矿矿井需金矿资源点+驻兵产出）
var needs_resource_point: bool = false  # 是否需要金矿资源点（金矿矿井需 true）


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
		"主城", BuildingCategory.TOWN_HALL, Vector2i(2, 2),
		500, 0, 0, 0, 0,
		40, {},
		[TerrainData.Terrain.PLAIN_DWARF, TerrainData.Terrain.MOUNTAIN_DWARF,
		 TerrainData.Terrain.FOREST_ELF, TerrainData.Terrain.GLADE_ELF,
		 TerrainData.Terrain.WASTELAND_ORC, TerrainData.Terrain.SWAMP_ORC],
		1, "阵营核心，每阵营限 1 座，HP40 ATK5，淘汰条件"
	)

static func infra_lumber_camp() -> BuildingData:
	return BuildingData.new(
		"伐木场", BuildingCategory.INFRA, Vector2i(1, 1),
		0, 3, 0, 0, 0,
		4, { "wood": 3 },
		[TerrainData.Terrain.PLAIN_DWARF, TerrainData.Terrain.FOREST_ELF,
		 TerrainData.Terrain.GLADE_ELF, TerrainData.Terrain.WASTELAND_ORC],
		7, "每回合 +3 木材"
	)

static func infra_quarry() -> BuildingData:
	return BuildingData.new(
		"采石场", BuildingCategory.INFRA, Vector2i(1, 1),
		0, 5, 0, 0, 0,
		4, { "stone": 3 },
		[TerrainData.Terrain.PLAIN_DWARF, TerrainData.Terrain.MOUNTAIN_DWARF,
		 TerrainData.Terrain.WASTELAND_ORC,
		 TerrainData.Terrain.FOREST_ELF,
		 TerrainData.Terrain.GLADE_ELF],
		7, "每回合 +3 石料"
	)

static func infra_farm() -> BuildingData:
	return BuildingData.new(
		"农场", BuildingCategory.INFRA, Vector2i(1, 1),
		0, 0, 0, 0, 3,
		4, { "food": 3 },
		[TerrainData.Terrain.PLAIN_DWARF, TerrainData.Terrain.GLADE_ELF,
		 TerrainData.Terrain.WASTELAND_ORC],
		7, "每回合 +3 食物"
	)

static func infra_warehouse() -> BuildingData:
	return BuildingData.new(
		"仓库", BuildingCategory.INFRA, Vector2i(1, 1),
		100, 30, 30, 0, 0,
		6, {},
		[TerrainData.Terrain.PLAIN_DWARF, TerrainData.Terrain.FOREST_ELF,
		 TerrainData.Terrain.MOUNTAIN_DWARF, TerrainData.Terrain.GLADE_ELF,
		 TerrainData.Terrain.WASTELAND_ORC],
		4, "被掠夺时库存保护 20%（可叠加）"
	)

static func t1_mine() -> BuildingData:
	return BuildingData.new(
		"矿井", BuildingCategory.T1_RESOURCE, Vector2i(1, 1),
		80, 30, 20, 0, 0,
		6, { "iron": 2 },
		[TerrainData.Terrain.MOUNTAIN_DWARF],
		6, "每回合 +2 铁矿，仅限山地"
	)

static func t1_extraction_tower() -> BuildingData:
	return BuildingData.new(
		"萃取塔", BuildingCategory.T1_RESOURCE, Vector2i(1, 1),
		80, 30, 20, 0, 0,
		6, { "magic_dust": 2 },
		[TerrainData.Terrain.RUINS],
		6, "每回合 +2 魔力尘，仅限遗迹"
	)

static func t1_ancient_wood_harvest() -> BuildingData:
	return BuildingData.new(
		"古木采集场", BuildingCategory.T1_RESOURCE, Vector2i(1, 1),
		80, 30, 20, 0, 0,
		6, { "ancient_wood": 2 },
		[TerrainData.Terrain.FOREST_ELF],
		6, "每回合 +2 古木，仅限森林"
	)

static func barracks_lv1() -> BuildingData:
	return BuildingData.new(
		"兵营", BuildingCategory.MILITARY, Vector2i(1, 1),
		100, 50, 30, 0, 0,
		8, {},
		[TerrainData.Terrain.PLAIN_DWARF, TerrainData.Terrain.FOREST_ELF,
		 TerrainData.Terrain.GLADE_ELF, TerrainData.Terrain.WASTELAND_ORC],
		99, "Lv1 可招募守卫、斥候"
	)

static func scout_post() -> BuildingData:
	return BuildingData.new(
		"侦察哨", BuildingCategory.SCOUT, Vector2i(1, 1),
		80, 30, 20, 0, 0,
		4, {},
		[TerrainData.Terrain.PLAIN_DWARF, TerrainData.Terrain.FOREST_ELF,
		 TerrainData.Terrain.MOUNTAIN_DWARF, TerrainData.Terrain.GLADE_ELF,
		 TerrainData.Terrain.WASTELAND_ORC],
		4, "视野 +2"
	)

static func recruit_camp() -> BuildingData:
	return BuildingData.new(
		"招募营", BuildingCategory.RECRUIT, Vector2i(1, 1),
		0, 20, 15, 0, 0,
		4, {},
		[TerrainData.Terrain.PLAIN_DWARF, TerrainData.Terrain.MOUNTAIN_DWARF,
		 TerrainData.Terrain.FOREST_ELF, TerrainData.Terrain.GLADE_ELF,
		 TerrainData.Terrain.WASTELAND_ORC, TerrainData.Terrain.SWAMP_ORC],
		3, "按 R 键招募工人（耗 1 食物 + 1 AP）"
	)

static func get_templates() -> Dictionary:
	## 返回按分类分组的全部建筑模板
	return {
		BuildingCategory.INFRA: [infra_lumber_camp(), infra_quarry(), infra_farm(), infra_warehouse(), gold_mine_shaft(), mint()],
		BuildingCategory.T1_RESOURCE: [t1_mine(), t1_extraction_tower(), t1_ancient_wood_harvest()],
		BuildingCategory.MILITARY: [barracks_lv1()],
		BuildingCategory.SCOUT: [scout_post()],
		BuildingCategory.RECRUIT: [recruit_camp()],
		BuildingCategory.TOWN_HALL: [town_hall()],
	}


static func gold_mine_shaft() -> BuildingData:
	var b := BuildingData.new(
		"金矿矿井", BuildingCategory.INFRA, Vector2i(1, 1),
		0, 20, 15, 5, 0,
		6, {},
		[TerrainData.Terrain.PLAIN_DWARF, TerrainData.Terrain.MOUNTAIN_DWARF,
		 TerrainData.Terrain.FOREST_ELF, TerrainData.Terrain.GLADE_ELF,
		 TerrainData.Terrain.WASTELAND_ORC, TerrainData.Terrain.SWAMP_ORC,
		 TerrainData.Terrain.RUINS],
		2, "需建在金矿上，需入驻工人，每驻 1 工 → +2 金矿/回合"
	)
	b.is_special_building = true
	b.needs_resource_point = true
	return b


static func mint() -> BuildingData:
	var b := BuildingData.new(
		"金币铸造厂", BuildingCategory.INFRA, Vector2i(1, 1),
		0, 30, 20, 10, 0,
		6, {},
		[TerrainData.Terrain.PLAIN_DWARF, TerrainData.Terrain.MOUNTAIN_DWARF,
		 TerrainData.Terrain.FOREST_ELF, TerrainData.Terrain.GLADE_ELF,
		 TerrainData.Terrain.WASTELAND_ORC, TerrainData.Terrain.SWAMP_ORC,
		 TerrainData.Terrain.RUINS],
		2, "需入驻工人，消耗金矿产出金币。每驻 1 工 → +2 金币/回合（消耗 1 金矿）"
	)
	b.is_special_building = true
	return b
