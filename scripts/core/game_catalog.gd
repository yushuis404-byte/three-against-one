class_name GameCatalog
extends RefCounted
## Shared names and ids used by gameplay and UI code.

const RESOURCE_KEYS := ["wood", "stone", "food", "iron", "magic_dust", "gold", "ancient_wood", "gold_ore", "fire_dragon_blood", "frost_dragon_blood", "toxic_dragon_blood"]

const RESOURCE_NAMES := {
	"gold": "金币",
	"wood": "木材",
	"stone": "石料",
	"food": "食物",
	"iron": "铁矿",
	"magic_dust": "魔尘",
	"ancient_wood": "古木",
	"gold_ore": "金矿石",
	"fire_dragon_blood": "火焰龙血",
	"frost_dragon_blood": "冰霜龙血",
	"toxic_dragon_blood": "毒液龙血",
}

# 亚龙 ID → 掉落龙血资源键名
const DRAGON_BLOOD_DROPS := {
	"neutral.wyvern.fire": "fire_dragon_blood",
	"neutral.wyvern.frost": "frost_dragon_blood",
	"neutral.wyvern.toxic": "toxic_dragon_blood",
}

const FACTION_NAMES := ["精灵", "矮人", "兽人"]

const FACTION_COLORS := [
	Color(0.18, 0.60, 0.15),
	Color(0.80, 0.65, 0.10),
	Color(0.80, 0.25, 0.15),
]


static func resource_name(key: String) -> String:
	return RESOURCE_NAMES.get(key, key)


static func faction_name(faction: int) -> String:
	if faction >= 0 and faction < FACTION_NAMES.size():
		return FACTION_NAMES[faction]
	return "中立"


static func faction_color(faction: int) -> Color:
	if faction >= 0 and faction < FACTION_COLORS.size():
		return FACTION_COLORS[faction]
	return Color.WHITE
