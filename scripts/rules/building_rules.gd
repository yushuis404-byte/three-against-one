class_name BuildingRules
extends RefCounted
## Centralized building rule ids. Managers still own state and rendering.

const OUTPOST_NAME := "前哨站"
const GOLD_MINE_SHAFT_NAME := "金矿矿井"
const MINT_NAME := "金币铸造厂"

const TEMPLATE_RECRUIT_CAMP := "building.recruit_camp"
const TEMPLATE_BARRACKS_LV1 := "building.barracks_lv1"


static func is_outpost(data: BuildingData) -> bool:
	return data != null and data.name == OUTPOST_NAME


static func is_gold_mine_shaft(data: BuildingData) -> bool:
	return data != null and data.name == GOLD_MINE_SHAFT_NAME


static func is_mint(data: BuildingData) -> bool:
	return data != null and data.name == MINT_NAME


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
	if data.category == BuildingData.BuildingCategory.RECRUIT:
		return ["%s.worker" % prefix]
	if data.category == BuildingData.BuildingCategory.MILITARY:
		return ["%s.guard" % prefix, "%s.scout" % prefix]
	return []


static func get_building_template_id(data: BuildingData) -> String:
	if data == null:
		return ""
	if data.category == BuildingData.BuildingCategory.RECRUIT:
		return TEMPLATE_RECRUIT_CAMP
	if data.category == BuildingData.BuildingCategory.MILITARY:
		return TEMPLATE_BARRACKS_LV1
	return ""
