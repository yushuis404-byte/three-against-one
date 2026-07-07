class_name UnitTemplate
extends "res://scripts/templates/game_template.gd"
## Reusable unit definition. Unit instances should store only state like hp and position.

enum UnitRole { WORKER, SCOUT, GUARD, ELITE, SIEGE, SPECIAL }

@export var role: UnitRole = UnitRole.WORKER
@export var move_max: int = 1
@export var atk: int = 0
@export var hp_max: int = 1
@export var vision: int = 1
@export var attack_range: int = 1
@export var attack_interval: float = 1.0
@export var damage_reduction: int = 0
@export var food_cost: int = 1
@export var recruit_cost: Array = []
@export var recruit_ap: int = 1
@export var recruit_ap_cost: int = 1
@export var recruit_turns: int = 1
@export var upkeep: Array = []
@export var can_gather: bool = false
@export var can_garrison: bool = true
@export var can_attack_units: bool = true
@export var can_attack_buildings: bool = false

# 中立单位 AI 行为
@export var ai_behavior: String = ""       # "guard" | "hidden_trader" | "revenge" | "ancient_dragon" | "progenitor_dragon"
@export var aggro_range: int = 0


static func make_basic(
		p_id: String,
		p_name: String,
		p_role: UnitRole,
		p_move: int,
		p_atk: int,
		p_hp: int,
		p_vision: int,
		p_tags: Array = []):
	var template = load("res://scripts/templates/unit_template.gd").new()
	template.id = p_id
	template.display_name = p_name
	template.role = p_role
	template.move_max = p_move
	template.atk = p_atk
	template.hp_max = p_hp
	template.vision = p_vision
	template.attack_range = 1
	template.attack_interval = 1.0
	template.damage_reduction = 0
	template.tags = p_tags.duplicate()
	template.can_gather = p_role == UnitRole.WORKER
	return template


func create_variant(new_id: String, overrides: Dictionary):
	var variant = duplicate(true)
	variant.id = new_id
	for key in overrides.keys():
		variant.set(String(key), overrides[key])
	return variant


func to_unit_data():
	var category := UnitData.UnitCategory.WORKER
	match role:
		UnitRole.WORKER:
			category = UnitData.UnitCategory.WORKER
		UnitRole.SCOUT:
			category = UnitData.UnitCategory.SCOUT
		UnitRole.GUARD:
			category = UnitData.UnitCategory.GUARD
		UnitRole.ELITE:
			category = UnitData.UnitCategory.ELITE
		UnitRole.SIEGE:
			category = UnitData.UnitCategory.SIEGE
		UnitRole.SPECIAL:
			category = UnitData.UnitCategory.SPECIAL
	return UnitData.new(display_name, category, move_max, atk, hp_max, vision, food_cost, attack_range, damage_reduction, attack_interval)
