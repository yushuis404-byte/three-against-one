class_name BuildingData
## 建筑模板数据 — 通用建筑定义

enum BuildingCategory {
	CORE,
	ECONOMY,
	SCOUT,
	DEFENSE,
	RECRUITMENT,
	INDUSTRY,
	LORD_SPECIAL,
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
var unique_effect_id: String = ""
var lord_requirement: String = ""
var civilization_tag: String = ""
var effect_radius: int = 0
var defense_attack_range: int = 0
var defense_attack_damage: int = 0
var defense_attack_cooldown: float = 0.0
var defense_attack_aoe_radius: int = 0
var is_special_building: bool = false  # 特殊建筑标记（如金矿矿井需金矿资源点+驻兵产出）
var needs_resource_point: bool = false
var storage_level: int = 0
var storage_bonus: Dictionary = {}
var storage_bonus_by_level: Dictionary = {}
var max_level: int = 1
var upgrade_rules: Dictionary = {}
var preferred_worker_tag: String = ""  # Garrisoned workers with this tag provide the stronger production bonus.
var garrison_capacity: int = 0
var garrison_repair_per_round: int = 1
var garrison_repair_requires_worker: bool = true


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
	garrison_capacity = _default_garrison_capacity(p_cat)


func get_garrison_rule_text() -> String:
	if garrison_capacity <= 0:
		return "不可入驻"
	return "入驻上限:%d 工人; 入驻工人每轮修复:%dHP" % [garrison_capacity, garrison_repair_per_round]


static func _default_garrison_capacity(p_cat: BuildingCategory) -> int:
	match p_cat:
		BuildingCategory.CORE:
			return 4
		BuildingCategory.SCOUT, BuildingCategory.DEFENSE, BuildingCategory.RECRUITMENT:
			return 1
		BuildingCategory.ECONOMY, BuildingCategory.INDUSTRY, BuildingCategory.LORD_SPECIAL:
			return 2
		_:
			return 0


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
		"\u4ed3\u5e93 Lv1", BuildingCategory.ECONOMY, Vector2i(1, 1),
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

static func forge() -> BuildingData:
	var b := BuildingData.new(
		"\u7194\u7089", BuildingCategory.INDUSTRY, Vector2i(1, 1),
		0, 20, 25, 5, 0,
		8, {},
		[TerrainData.Terrain.PLAIN_DWARF, TerrainData.Terrain.MOUNTAIN_DWARF,
		 TerrainData.Terrain.FOREST_ELF, TerrainData.Terrain.GLADE_ELF,
		 TerrainData.Terrain.WASTELAND_ORC, TerrainData.Terrain.RUINS],
		2, "\u77ee\u4eba\u5de5\u4e1a\u5efa\u7b51\uff1a\u6bcf\u56de\u5408\u5c06\u94c1\u77ff\u8f6c\u5316\u4e3a\u7cbe\u94a2\uff0c\u89e3\u9501\u79d8\u94f6\u5de5\u827a\u540e\u53ef\u8f6c\u5316\u79d8\u94f6"
	)
	b.tech_tier = 2
	b.lord_requirement = "lord.dwarf.stone_warden"
	b.civilization_tag = "dwarf"
	b.tags = ["industry", "forge", "conversion", "dwarf"]
	return b

static func t1_extraction_tower() -> BuildingData:
	var b := BuildingData.new(
		"\u8403\u53d6\u5854", BuildingCategory.INDUSTRY, Vector2i(1, 1),
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
		"\u53e4\u6728\u91c7\u96c6\u573a", BuildingCategory.INDUSTRY, Vector2i(1, 1),
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
	b.garrison_capacity = 2
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

static func watch_tower() -> BuildingData:
	var b := BuildingData.new(
		"\u77ad\u671b\u5854", BuildingCategory.SCOUT, Vector2i(1, 1),
		0, 15, 20, 5, 0,
		10, {},
		[TerrainData.Terrain.PLAIN_DWARF, TerrainData.Terrain.MOUNTAIN_DWARF,
		 TerrainData.Terrain.FOREST_ELF, TerrainData.Terrain.GLADE_ELF,
		 TerrainData.Terrain.WASTELAND_ORC, TerrainData.Terrain.SWAMP_ORC,
		 TerrainData.Terrain.RUINS],
		6, "\u77ee\u4eba\u9632\u7ebf\u5efa\u7b51\uff1a\u5360\u683c\u963b\u6321\u79fb\u52a8\uff0c\u63d0\u4f9b\u66f4\u5927\u9632\u7ebf\u89c6\u91ce"
	)
	b.tech_tier = 1
	b.effect_radius = 4
	b.lord_requirement = "lord.dwarf.stone_warden"
	b.civilization_tag = "dwarf"
	b.tags = ["defense", "watch_tower", "vision", "blocks_movement", "dwarf"]
	_configure_defense_attack(b, 3, 1, 2.0, 0)
	return b

static func ballista_tower() -> BuildingData:
	var b := BuildingData.new(
		"\u5f29\u70ae\u5854", BuildingCategory.DEFENSE, Vector2i(1, 1),
		0, 20, 35, 10, 0,
		14, {},
		[TerrainData.Terrain.PLAIN_DWARF, TerrainData.Terrain.MOUNTAIN_DWARF,
		 TerrainData.Terrain.FOREST_ELF, TerrainData.Terrain.GLADE_ELF,
		 TerrainData.Terrain.WASTELAND_ORC, TerrainData.Terrain.SWAMP_ORC,
		 TerrainData.Terrain.RUINS],
		4, "\u77ee\u4eba\u9632\u5fa1\u5efa\u7b51\uff1a\u5c04\u7a0b4\uff0c\u4f24\u5bb32\uff0c8\u79d2\u653b\u51fb\u4e00\u6b21"
	)
	b.tech_tier = 2
	b.effect_radius = 4
	b.lord_requirement = "lord.dwarf.stone_warden"
	b.civilization_tag = "dwarf"
	b.garrison_capacity = 1
	b.tags = ["defense", "ballista_tower", "ranged_tower", "blocks_movement", "dwarf"]
	_configure_defense_attack(b, 4, 2, 8.0, 0)
	return b

static func heavy_ballista_tower() -> BuildingData:
	var b := BuildingData.new(
		"\u9ad8\u7ea7\u5f29\u70ae", BuildingCategory.DEFENSE, Vector2i(1, 1),
		0, 30, 55, 20, 0,
		18, {},
		[TerrainData.Terrain.PLAIN_DWARF, TerrainData.Terrain.MOUNTAIN_DWARF,
		 TerrainData.Terrain.FOREST_ELF, TerrainData.Terrain.GLADE_ELF,
		 TerrainData.Terrain.WASTELAND_ORC, TerrainData.Terrain.SWAMP_ORC,
		 TerrainData.Terrain.RUINS],
		3, "\u77ee\u4eba\u9ad8\u7ea7\u9632\u5fa1\u5efa\u7b51\uff1a\u5c04\u7a0b4\uff0c\u4f24\u5bb33\uff0c8\u79d2\u653b\u51fb\u4e00\u6b21"
	)
	b.tech_tier = 3
	b.effect_radius = 4
	b.lord_requirement = "lord.dwarf.stone_warden"
	b.civilization_tag = "dwarf"
	b.garrison_capacity = 2
	b.tags = ["defense", "heavy_ballista", "ranged_tower", "blocks_movement", "dwarf"]
	_configure_defense_attack(b, 4, 3, 8.0, 0)
	return b

static func stone_cannon_tower() -> BuildingData:
	var b := BuildingData.new(
		"\u788e\u77f3\u70ae\u53f0", BuildingCategory.DEFENSE, Vector2i(1, 1),
		0, 15, 45, 8, 0,
		12, {},
		[TerrainData.Terrain.PLAIN_DWARF, TerrainData.Terrain.MOUNTAIN_DWARF,
		 TerrainData.Terrain.FOREST_ELF, TerrainData.Terrain.GLADE_ELF,
		 TerrainData.Terrain.WASTELAND_ORC, TerrainData.Terrain.SWAMP_ORC,
		 TerrainData.Terrain.RUINS],
		4, "\u77ee\u4eba\u8303\u56f4\u9632\u5fa1\u5efa\u7b51\uff1a\u5c04\u7a0b4\uff0c\u4f24\u5bb31\uff0c12\u79d2\u653b\u51fb\u4e00\u6b21\uff0c\u547d\u4e2d\u76ee\u6807\u5468\u56f41\u683c"
	)
	b.tech_tier = 2
	b.effect_radius = 4
	b.lord_requirement = "lord.dwarf.stone_warden"
	b.civilization_tag = "dwarf"
	b.garrison_capacity = 2
	b.tags = ["defense", "stone_cannon", "aoe_tower", "blocks_movement", "dwarf"]
	_configure_defense_attack(b, 4, 1, 12.0, 1)
	return b

static func _configure_defense_attack(b: BuildingData, attack_range: int, damage: int, cooldown: float, aoe_radius: int) -> void:
	b.defense_attack_range = attack_range
	b.defense_attack_damage = damage
	b.defense_attack_cooldown = cooldown
	b.defense_attack_aoe_radius = aoe_radius

static func outpost() -> BuildingData:
	var b := BuildingData.new(
		"\u524d\u54e8\u7ad9", BuildingCategory.ECONOMY, Vector2i(1, 1),
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


static func lord_wind_speaking_tree() -> BuildingData:
	var b := BuildingData.new(
		"\u98ce\u8bed\u53e4\u6811", BuildingCategory.LORD_SPECIAL, Vector2i(1, 1),
		0, 30, 20, 0, 0,
		8, { "ancient_wood": 1 },
		[TerrainData.Terrain.FOREST_ELF, TerrainData.Terrain.GLADE_ELF],
		1, "\u7cbe\u7075\u9886\u4e3b\u7279\u8272\u5efa\u7b51\uff1a\u5468\u56f4\u89c6\u91ce +1\uff0c\u6bcf\u56de\u5408 +1 \u53e4\u6728"
	)
	b.tech_tier = 2
	b.unique_effect_id = "elf.wind_speaking_tree"
	b.effect_radius = 3
	b.lord_requirement = "lord.elf.wind_seer"
	b.civilization_tag = "elf"
	b.preferred_worker_tag = "elf"
	b.tags = ["lord_building", "elf", "vision", "ancient_wood"]
	return b


static func lord_rootweb_shrine() -> BuildingData:
	var b := BuildingData.new(
		"\u6839\u7f51\u5723\u575b", BuildingCategory.LORD_SPECIAL, Vector2i(1, 1),
		0, 40, 10, 0, 0,
		7, {},
		[TerrainData.Terrain.FOREST_ELF, TerrainData.Terrain.GLADE_ELF],
		2, "\u7cbe\u7075\u9886\u4e3b\u7279\u8272\u5efa\u7b51\uff1a\u68ee\u6797\u673a\u52a8\u4e0e\u6839\u7f51\u901a\u9053\u6548\u679c\u6302\u70b9"
	)
	b.tech_tier = 2
	b.unique_effect_id = "elf.rootweb_shrine"
	b.effect_radius = 4
	b.lord_requirement = "lord.elf.root_keeper"
	b.civilization_tag = "elf"
	b.tags = ["lord_building", "elf", "mobility", "forest"]
	return b


static func lord_moonshadow_watchtower() -> BuildingData:
	var b := BuildingData.new(
		"\u6708\u5f71\u54e8\u5854", BuildingCategory.LORD_SPECIAL, Vector2i(1, 1),
		0, 25, 15, 0, 0,
		5, {},
		[TerrainData.Terrain.PLAIN_DWARF, TerrainData.Terrain.FOREST_ELF,
		 TerrainData.Terrain.MOUNTAIN_DWARF, TerrainData.Terrain.GLADE_ELF,
		 TerrainData.Terrain.WASTELAND_ORC, TerrainData.Terrain.SWAMP_ORC,
		 TerrainData.Terrain.RUINS],
		2, "\u7cbe\u7075\u9886\u4e3b\u7279\u8272\u5efa\u7b51\uff1a\u5f3a\u5316\u4fa6\u5bdf\u548c\u8fdc\u7a0b\u5148\u624b\u6548\u679c\u6302\u70b9"
	)
	b.tech_tier = 1
	b.unique_effect_id = "elf.moonshadow_watchtower"
	b.effect_radius = 4
	b.lord_requirement = "lord.elf.moon_hunter"
	b.civilization_tag = "elf"
	b.tags = ["lord_building", "elf", "scout", "vision"]
	return b


static func lord_deep_forge_workshop() -> BuildingData:
	var b := BuildingData.new(
		"\u6df1\u7089\u5de5\u574a", BuildingCategory.LORD_SPECIAL, Vector2i(1, 1),
		0, 25, 35, 5, 0,
		8, {},
		[TerrainData.Terrain.PLAIN_DWARF, TerrainData.Terrain.FOREST_ELF,
		 TerrainData.Terrain.MOUNTAIN_DWARF, TerrainData.Terrain.GLADE_ELF,
		 TerrainData.Terrain.WASTELAND_ORC, TerrainData.Terrain.SWAMP_ORC,
		 TerrainData.Terrain.RUINS],
		1, "\u77ee\u4eba\u9886\u4e3b\u7279\u8272\u5efa\u7b51\uff1a\u94c1\u77ff\u5230\u91d1\u5e01\u7684\u8f6c\u6362\u6548\u679c\u6302\u70b9"
	)
	b.tech_tier = 2
	b.unique_effect_id = "dwarf.deep_forge_workshop"
	b.effect_radius = 0
	b.lord_requirement = "lord.dwarf.forge_master"
	b.civilization_tag = "dwarf"
	b.preferred_worker_tag = "dwarf"
	b.tags = ["lord_building", "dwarf", "industry", "conversion"]
	return b


static func lord_iron_oath_fortress() -> BuildingData:
	var b := BuildingData.new(
		"\u94c1\u8a93\u5821\u5792", BuildingCategory.LORD_SPECIAL, Vector2i(1, 1),
		0, 20, 50, 10, 0,
		14, {},
		[TerrainData.Terrain.PLAIN_DWARF, TerrainData.Terrain.FOREST_ELF,
		 TerrainData.Terrain.MOUNTAIN_DWARF, TerrainData.Terrain.GLADE_ELF,
		 TerrainData.Terrain.WASTELAND_ORC, TerrainData.Terrain.SWAMP_ORC,
		 TerrainData.Terrain.RUINS],
		1, "\u77ee\u4eba\u9886\u4e3b\u7279\u8272\u5efa\u7b51\uff1a\u9632\u5b88\u3001\u9886\u571f\u538b\u5236\u548c\u51cf\u4f24\u6548\u679c\u6302\u70b9"
	)
	b.tech_tier = 2
	b.unique_effect_id = "dwarf.iron_oath_fortress"
	b.effect_radius = 3
	b.lord_requirement = "lord.dwarf.stone_warden"
	b.civilization_tag = "dwarf"
	b.tags = ["lord_building", "dwarf", "defense", "territory"]
	return b


static func lord_vein_lift() -> BuildingData:
	var b := BuildingData.new(
		"\u5ca9\u8109\u5347\u964d\u673a", BuildingCategory.LORD_SPECIAL, Vector2i(1, 1),
		0, 20, 25, 0, 0,
		7, {},
		[TerrainData.Terrain.MOUNTAIN_DWARF],
		2, "\u77ee\u4eba\u9886\u4e3b\u7279\u8272\u5efa\u7b51\uff1a\u5c71\u5730\u673a\u52a8\u548c\u76f8\u90bb\u77ff\u4e95\u589e\u4ea7\u6548\u679c\u6302\u70b9"
	)
	b.tech_tier = 1
	b.unique_effect_id = "dwarf.vein_lift"
	b.effect_radius = 2
	b.lord_requirement = "lord.dwarf.mountain_engineer"
	b.civilization_tag = "dwarf"
	b.tags = ["lord_building", "dwarf", "mountain", "mobility"]
	return b


static func lord_war_drum_camp() -> BuildingData:
	var b := BuildingData.new(
		"\u6218\u9f13\u8425\u5730", BuildingCategory.LORD_SPECIAL, Vector2i(1, 1),
		0, 30, 15, 0, 5,
		7, {},
		[TerrainData.Terrain.WASTELAND_ORC, TerrainData.Terrain.SWAMP_ORC,
		 TerrainData.Terrain.PLAIN_DWARF],
		2, "\u517d\u4eba\u9886\u4e3b\u7279\u8272\u5efa\u7b51\uff1a\u8fd1\u6218\u653b\u51fb\u548c\u62db\u52df\u52a0\u901f\u6548\u679c\u6302\u70b9"
	)
	b.tech_tier = 1
	b.unique_effect_id = "orc.war_drum_camp"
	b.effect_radius = 3
	b.lord_requirement = "lord.orc.blood_chief"
	b.civilization_tag = "orc"
	b.preferred_worker_tag = "orc"
	b.tags = ["lord_building", "orc", "war", "recruit_speed"]
	return b


static func lord_plunder_banner() -> BuildingData:
	var b := BuildingData.new(
		"\u63a0\u593a\u65d7\u67f1", BuildingCategory.LORD_SPECIAL, Vector2i(1, 1),
		0, 25, 20, 0, 10,
		6, {},
		[TerrainData.Terrain.PLAIN_DWARF, TerrainData.Terrain.FOREST_ELF,
		 TerrainData.Terrain.MOUNTAIN_DWARF, TerrainData.Terrain.GLADE_ELF,
		 TerrainData.Terrain.WASTELAND_ORC, TerrainData.Terrain.SWAMP_ORC,
		 TerrainData.Terrain.RUINS],
		2, "\u517d\u4eba\u9886\u4e3b\u7279\u8272\u5efa\u7b51\uff1a\u8fb9\u5883\u9a9a\u6270\u3001\u654c\u65b9\u4ea7\u51fa\u524a\u5f31\u548c\u51fb\u6740\u6536\u76ca\u6548\u679c\u6302\u70b9"
	)
	b.tech_tier = 2
	b.unique_effect_id = "orc.plunder_banner"
	b.effect_radius = 3
	b.lord_requirement = "lord.orc.raider"
	b.civilization_tag = "orc"
	b.tags = ["lord_building", "orc", "raid", "border"]
	return b


static func lord_flesh_pen() -> BuildingData:
	var b := BuildingData.new(
		"\u8840\u8089\u56f4\u680f", BuildingCategory.LORD_SPECIAL, Vector2i(1, 1),
		0, 30, 10, 0, 15,
		7, {},
		[TerrainData.Terrain.WASTELAND_ORC, TerrainData.Terrain.SWAMP_ORC,
		 TerrainData.Terrain.PLAIN_DWARF],
		2, "\u517d\u4eba\u9886\u4e3b\u7279\u8272\u5efa\u7b51\uff1a\u98df\u7269\u8f6c\u519b\u529b\u3001\u961f\u5217\u52a0\u901f\u548c\u6b7b\u4ea1\u8fd4\u8fd8\u6548\u679c\u6302\u70b9"
	)
	b.tech_tier = 2
	b.unique_effect_id = "orc.flesh_pen"
	b.effect_radius = 2
	b.lord_requirement = "lord.orc.flesh_binder"
	b.civilization_tag = "orc"
	b.tags = ["lord_building", "orc", "food", "recruit_speed"]
	return b

static func get_templates() -> Dictionary:
	## 返回按分类分组的全部建筑模板
	return {
		BuildingCategory.CORE: [town_hall()],
		BuildingCategory.ECONOMY: [infra_lumber_camp(), infra_quarry(), infra_farm(), infra_warehouse(), outpost(), gold_mine_shaft(), mint()],
		BuildingCategory.SCOUT: [scout_post(), watch_tower()],
		BuildingCategory.DEFENSE: [ballista_tower(), heavy_ballista_tower(), stone_cannon_tower()],
		BuildingCategory.RECRUITMENT: [recruit_camp(), barracks_lv1()],
		BuildingCategory.INDUSTRY: [t1_mine(), forge(), t1_extraction_tower(), t1_ancient_wood_harvest()],
		BuildingCategory.LORD_SPECIAL: [lord_wind_speaking_tree(), lord_rootweb_shrine(), lord_moonshadow_watchtower(), lord_deep_forge_workshop(), lord_iron_oath_fortress(), lord_vein_lift(), lord_war_drum_camp(), lord_plunder_banner(), lord_flesh_pen()],
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
		"mithril": amount,
		"steel": amount,
	}


static func gold_mine_shaft() -> BuildingData:
	var b := BuildingData.new(
		"金矿矿井", BuildingCategory.ECONOMY, Vector2i(1, 1),
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
		"金币铸造厂", BuildingCategory.ECONOMY, Vector2i(1, 1),
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
