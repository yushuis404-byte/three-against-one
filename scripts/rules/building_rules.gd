class_name BuildingRules
extends RefCounted
## Centralized building rule ids. Managers still own state and rendering.

const OUTPOST_NAME := "\u524d\u54e8\u7ad9"
const GOLD_MINE_SHAFT_NAME := "\u91d1\u77ff\u77ff\u4e95"
const MINT_NAME := "\u91d1\u5e01\u94f8\u9020\u5382"
const WATCH_TOWER_NAME := "\u77ad\u671b\u5854"
const FORGE_NAME := "\u7194\u7089"

const TEMPLATE_RECRUIT_CAMP := "building.recruit_camp"
const TEMPLATE_WATCH_TOWER := "building.watch_tower"
const TEMPLATE_FORGE := "building.forge"


static func is_outpost(data: BuildingData) -> bool:
	return data != null and data.name == OUTPOST_NAME


static func is_gold_mine_shaft(data: BuildingData) -> bool:
	return data != null and data.name == GOLD_MINE_SHAFT_NAME


static func is_mint(data: BuildingData) -> bool:
	return data != null and data.name == MINT_NAME


static func is_watch_tower(data: BuildingData) -> bool:
	return data != null and data.name == WATCH_TOWER_NAME


static func is_forge(data: BuildingData) -> bool:
	return data != null and data.name == FORGE_NAME


static func is_defense_building(data: BuildingData) -> bool:
	return data != null and ("defense" in data.tags or is_watch_tower(data))


static func get_faction_unit_prefix(faction: int) -> String:
	match faction:
		0:
			return "unit.elf"
		1:
			return "unit.dwarf"
		2:
			return "unit.orc"
	return ""


static func get_faction_recruit_template_ids(data: BuildingData, faction: int) -> Array:
	var prefix := get_faction_unit_prefix(faction)
	if prefix.is_empty() or data == null:
		return []
	if "recruit_camp" in data.tags:
		if faction == 0:
			return ["%s.worker" % prefix, "%s.guard" % prefix, "%s.scout" % prefix, "%s.ranger" % prefix, "%s.blade_dancer" % prefix, "%s.root_guard" % prefix]
		if faction == 1:
			return ["%s.worker" % prefix, "%s.guard" % prefix, "%s.scout" % prefix, "%s.shieldbearer" % prefix, "%s.crossbow" % prefix, "%s.sapper" % prefix]
		if faction == 2:
			return ["%s.worker" % prefix, "%s.mob" % prefix, "%s.guard" % prefix, "%s.bone_shield" % prefix, "%s.hide_tower" % prefix, "%s.scout" % prefix, "%s.slinger" % prefix]
		return ["%s.guard" % prefix, "%s.scout" % prefix, "%s.ranger" % prefix, "%s.blade_dancer" % prefix, "%s.root_guard" % prefix]
	return []


static func get_building_template_id(data: BuildingData) -> String:
	if data == null:
		return ""
	if "recruit_camp" in data.tags:
		return TEMPLATE_RECRUIT_CAMP
	if "watch_tower" in data.tags:
		return TEMPLATE_WATCH_TOWER
	if "forge" in data.tags:
		return TEMPLATE_FORGE
	return ""
