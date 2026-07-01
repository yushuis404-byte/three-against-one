class_name GoblinHexCardLibrary
extends RefCounted

const RARITY_BLACK := "black"
const RARITY_SILVER := "silver"
const RARITY_GOLD := "gold"
const RARITY_PRISMATIC := "prismatic"

const RARITY_NAMES := {
	RARITY_BLACK: "黑色",
	RARITY_SILVER: "银色",
	RARITY_GOLD: "金色",
	RARITY_PRISMATIC: "彩色",
}

const RARITY_COLORS := {
	RARITY_BLACK: Color(0.10, 0.11, 0.13),
	RARITY_SILVER: Color(0.72, 0.76, 0.82),
	RARITY_GOLD: Color(1.00, 0.72, 0.18),
	RARITY_PRISMATIC: Color(0.75, 0.42, 1.00),
}

const CATEGORY_NAMES := {
	"economy": "经济",
	"development": "发展",
	"building": "建筑",
	"combat": "战力",
	"exploration": "探索",
	"sustain": "防守",
	"hybrid": "综合",
	"faction": "专属",
}

const MODIFIER_NAMES := {
	"storage_flat_bonus": "资源上限",
	"resource_production_bonus": "建筑产出",
	"garrison_production_bonus": "驻扎产出",
	"recruit_food_discount": "招募食物折扣",
	"first_recruit_ap_discount": "招募 AP 折扣",
	"recruit_turn_discount": "招募回合缩短",
	"building_upgrade_ap_discount": "建筑升级 AP 折扣",
	"unit_move_bonus": "单位移动",
	"unit_attack_bonus": "单位攻击",
	"unit_vision_bonus": "单位视野",
	"damage_reduction_bonus": "单位减伤",
	"melee_attack_bonus": "近战攻击",
	"light_unit_attack_bonus": "轻装攻击",
	"gold_ore_production_bonus": "金矿石产出",
	"iron_production_bonus": "铁矿产出",
	"ancient_wood_production_bonus": "古木产出",
	"elf_fog_duration_bonus": "精灵迷雾持续",
	"elf_fog_radius_bonus": "精灵迷雾范围",
	"elf_first_strike_damage_bonus": "精灵先手追击",
	"dwarf_building_aura_defense": "矮人建筑光环",
	"orc_kill_reward_bonus": "兽人击杀掠夺",
}


static func get_trigger_rounds() -> Array[int]:
	return [7, 22, 37]


static func get_rarity_weights(round_number: int) -> Dictionary:
	match round_number:
		7:
			return {RARITY_BLACK: 50, RARITY_SILVER: 45, RARITY_GOLD: 5, RARITY_PRISMATIC: 0}
		22:
			return {RARITY_BLACK: 15, RARITY_SILVER: 45, RARITY_GOLD: 35, RARITY_PRISMATIC: 5}
		37:
			return {RARITY_BLACK: 0, RARITY_SILVER: 25, RARITY_GOLD: 50, RARITY_PRISMATIC: 25}
	return {RARITY_BLACK: 0, RARITY_SILVER: 40, RARITY_GOLD: 45, RARITY_PRISMATIC: 15}


static func get_cards() -> Array:
	return [
		_card("common.supply", "商队补给", "economy", -1, _tiers({"wood": 6, "stone": 6, "food": 4}, {"wood": 10, "stone": 10, "food": 8}, {"wood": 18, "stone": 18, "food": 12, "gold": 1}, {"wood": 28, "stone": 28, "food": 20, "gold": 3})),
		_card("common.rare_crate", "稀有货箱", "economy", -1, _tiers({"magic_dust": 2}, {"magic_dust": 3, "ancient_wood": 2}, {"magic_dust": 5, "ancient_wood": 4, "gold_ore": 3}, {"magic_dust": 8, "ancient_wood": 7, "gold_ore": 6})),
		_card("common.coin_contract", "金币契约", "economy", -1, _tiers({"gold": 2}, {"gold": 4}, {"gold": 7, "gold_ore": 4}, {"gold": 10, "gold_ore": 8})),
		_card("common.ore_purchase", "矿石收购", "economy", -1, _tiers({"stone": 8, "iron": 4}, {"stone": 12, "iron": 7}, {"stone": 18, "iron": 12}, {"stone": 28, "iron": 18, "mithril": 2})),
		_card("common.storage", "仓储扩建", "development", -1, _modifier_tiers("storage_flat_bonus", [5, 10, 16, 24], 0)),
		_card("common.investment", "商会投资", "development", -1, _modifier_tiers("resource_production_bonus", [1, 1, 2, 3], 3)),
		_card("common.worker_pact", "工人协议", "development", -1, _modifier_tiers("recruit_food_discount", [1, 1, 2, 3], 3, {"first_recruit_ap_discount": [0, 1, 1, 1]})),
		_card("common.production_plan", "生产排期", "development", -1, _modifier_tiers("garrison_production_bonus", [1, 1, 2, 2], 3)),
		_card("common.fast_build", "快速施工", "building", -1, _modifier_tiers("building_upgrade_ap_discount", [1, 1, 1, 2], 3)),
		_card("common.foundation", "加固地基", "building", -1, _modifier_tiers("damage_reduction_bonus", [1, 1, 2, 3], 2)),
		_card("common.garrison_bonus", "驻扎奖励", "building", -1, _modifier_tiers("garrison_production_bonus", [1, 2, 3, 4], 3)),
		_card("common.upgrade_blueprint", "升级图纸", "building", -1, _modifier_tiers("building_upgrade_ap_discount", [1, 1, 2, 2], 4)),
		_card("common.mercenary_training", "佣兵训练", "combat", -1, _modifier_tiers("unit_attack_bonus", [1, 1, 2, 3], 2)),
		_card("common.march_horn", "行军号角", "combat", -1, _modifier_tiers("unit_move_bonus", [1, 1, 1, 2], 1)),
		_card("common.sharp_weapons", "锋利武器", "combat", -1, _modifier_tiers("melee_attack_bonus", [1, 1, 2, 3], 2)),
		_card("common.tactical_plan", "战术预案", "combat", -1, _ap_tiers([1, 2, 3, 4], {"unit_attack_bonus": [0, 0, 1, 1]})),
		_card("common.goblin_map", "哥布林地图", "exploration", -1, _modifier_tiers("unit_vision_bonus", [1, 1, 2, 3], 3)),
		_card("common.pathfinder_pack", "远行背包", "exploration", -1, _modifier_tiers("unit_move_bonus", [1, 1, 1, 2], 2, {"unit_vision_bonus": [1, 1, 2, 2]})),
		_card("common.neutral_intel", "中立情报", "exploration", -1, _modifier_tiers("unit_vision_bonus", [1, 2, 2, 3], 2)),
		_card("common.safe_route", "安全路线", "exploration", -1, _modifier_tiers("damage_reduction_bonus", [1, 1, 2, 2], 2)),
		_card("common.fortification", "防御工事", "sustain", -1, _modifier_tiers("damage_reduction_bonus", [1, 1, 2, 3], 2)),
		_card("common.field_medicine", "急救药剂", "sustain", -1, _modifier_tiers("unit_vision_bonus", [0, 1, 1, 1], 2, {"damage_reduction_bonus": [1, 1, 1, 2]})),
		_card("common.expedition_economy", "远征经济", "hybrid", -1, _hybrid_tiers({"wood": 4, "food": 4}, {"wood": 8, "food": 8, "gold": 1}, {"wood": 12, "food": 12, "gold": 2}, {"wood": 20, "food": 20, "gold": 4}, "unit_move_bonus", [0, 1, 1, 2])),
		_card("common.military_industry", "军工协作", "hybrid", -1, _hybrid_tiers({"iron": 3}, {"iron": 6, "stone": 6}, {"iron": 10, "stone": 10}, {"iron": 16, "stone": 16, "steel": 2}, "unit_attack_bonus", [0, 1, 1, 2])),
		_card("elf.mist_court", "雾幕王庭", "faction", 0, _modifier_tiers("elf_fog_duration_bonus", [1, 1, 2, 3], 0, {"elf_fog_radius_bonus": [0, 0, 1, 1]})),
		_card("elf.moon_hunt", "月影狩猎", "faction", 0, _modifier_tiers("elf_first_strike_damage_bonus", [1, 1, 2, 3], 3)),
		_card("elf.wind_command", "风行军令", "faction", 0, _modifier_tiers("unit_move_bonus", [1, 1, 2, 2], 2, {"unit_vision_bonus": [1, 1, 1, 2]})),
		_card("elf.ancient_echo", "古树回响", "faction", 0, _modifier_tiers("unit_vision_bonus", [1, 2, 2, 3], 3, {"light_unit_attack_bonus": [0, 1, 1, 2]})),
		_card("dwarf.mountain_oath", "山脉誓约", "faction", 1, _modifier_tiers("damage_reduction_bonus", [1, 1, 2, 3], 3)),
		_card("dwarf.deep_forge", "深炉武装", "faction", 1, _modifier_tiers("melee_attack_bonus", [1, 1, 2, 2], 3, {"damage_reduction_bonus": [0, 1, 1, 2]})),
		_card("dwarf.mine_empire", "矿脉帝国", "faction", 1, _modifier_tiers("iron_production_bonus", [1, 2, 3, 4], 3, {"gold_ore_production_bonus": [1, 1, 2, 3]})),
		_card("dwarf.rune_armor", "符文护甲", "faction", 1, _modifier_tiers("damage_reduction_bonus", [1, 2, 2, 3], 2, {"storage_flat_bonus": [0, 0, 5, 10]})),
		_card("orc.blood_axe_frenzy", "血斧狂潮", "faction", 2, _modifier_tiers("orc_kill_reward_bonus", [1, 1, 2, 3], 3, {"unit_attack_bonus": [0, 1, 1, 2]})),
		_card("orc.war_drum", "战鼓震地", "faction", 2, _modifier_tiers("unit_attack_bonus", [1, 1, 2, 3], 1, {"unit_move_bonus": [1, 1, 1, 2]})),
		_card("orc.plunder_license", "掠夺许可证", "faction", 2, _modifier_tiers("orc_kill_reward_bonus", [1, 2, 3, 4], 3)),
		_card("orc.savage_supply", "蛮荒补给", "faction", 2, _hybrid_tiers({"food": 6, "wood": 6}, {"food": 10, "wood": 10}, {"food": 16, "wood": 16, "gold": 1}, {"food": 24, "wood": 24, "gold": 3}, "unit_attack_bonus", [0, 0, 1, 2])),
	]


static func describe_effects(effects: Dictionary) -> String:
	var parts: Array[String] = []
	var resources: Dictionary = effects.get("resources", {})
	if not resources.is_empty():
		parts.append("立即获得 %s。" % _format_resources(resources))
	var ap: int = int(effects.get("ap", 0))
	if ap > 0:
		parts.append("立即获得 %d AP。" % ap)
	var modifiers: Dictionary = effects.get("modifiers", {})
	if not modifiers.is_empty():
		var duration: int = int(effects.get("duration_rounds", 0))
		var prefix := "永久" if duration <= 0 else "持续 %d 回合" % duration
		parts.append("%s：%s。" % [prefix, _format_modifiers(modifiers)])
	if parts.is_empty():
		return "获得一项哥布林海克斯强化。"
	return "".join(parts)


static func _card(id: String, name: String, category: String, faction: int, tiers: Dictionary) -> Dictionary:
	return {"id": id, "name": name, "category": category, "faction": faction, "tiers": tiers}


static func _tiers(black: Dictionary, silver: Dictionary, gold: Dictionary, prismatic: Dictionary) -> Dictionary:
	return {
		RARITY_BLACK: {"resources": black},
		RARITY_SILVER: {"resources": silver},
		RARITY_GOLD: {"resources": gold},
		RARITY_PRISMATIC: {"resources": prismatic},
	}


static func _modifier_tiers(key: String, values: Array, duration: int, extra_values: Dictionary = {}) -> Dictionary:
	var result: Dictionary = {}
	var rarities := [RARITY_BLACK, RARITY_SILVER, RARITY_GOLD, RARITY_PRISMATIC]
	for i in range(rarities.size()):
		var modifiers: Dictionary = {}
		var value: int = int(values[i])
		if value > 0:
			modifiers[key] = value
		for extra_key in extra_values:
			var extra_list: Array = extra_values[extra_key]
			var extra_value: int = int(extra_list[i])
			if extra_value > 0:
				modifiers[str(extra_key)] = extra_value
		result[rarities[i]] = {"modifiers": modifiers, "duration_rounds": duration}
	return result


static func _ap_tiers(values: Array, extra_values: Dictionary = {}) -> Dictionary:
	var result: Dictionary = {}
	var rarities := [RARITY_BLACK, RARITY_SILVER, RARITY_GOLD, RARITY_PRISMATIC]
	for i in range(rarities.size()):
		var effects: Dictionary = {"ap": int(values[i])}
		if not extra_values.is_empty():
			var modifiers: Dictionary = {}
			for extra_key in extra_values:
				var extra_list: Array = extra_values[extra_key]
				var extra_value: int = int(extra_list[i])
				if extra_value > 0:
					modifiers[str(extra_key)] = extra_value
			if not modifiers.is_empty():
				effects["modifiers"] = modifiers
				effects["duration_rounds"] = 1
		result[rarities[i]] = effects
	return result


static func _hybrid_tiers(black: Dictionary, silver: Dictionary, gold: Dictionary, prismatic: Dictionary, modifier_key: String, values: Array) -> Dictionary:
	var tiers: Dictionary = _tiers(black, silver, gold, prismatic)
	var rarities := [RARITY_BLACK, RARITY_SILVER, RARITY_GOLD, RARITY_PRISMATIC]
	for i in range(rarities.size()):
		var value: int = int(values[i])
		if value <= 0:
			continue
		var effects: Dictionary = tiers[rarities[i]]
		effects["modifiers"] = {modifier_key: value}
		effects["duration_rounds"] = 2
		tiers[rarities[i]] = effects
	return tiers


static func _format_resources(resources: Dictionary) -> String:
	var parts: Array[String] = []
	for key in resources:
		parts.append("%s+%d" % [GameCatalog.resource_name(str(key)), int(resources[key])])
	return "、".join(parts)


static func _format_modifiers(modifiers: Dictionary) -> String:
	var parts: Array[String] = []
	for key in modifiers:
		var label: String = str(MODIFIER_NAMES.get(str(key), str(key)))
		parts.append("%s+%d" % [label, int(modifiers[key])])
	return "、".join(parts)
