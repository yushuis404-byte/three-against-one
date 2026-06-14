class_name BuildingTemplate
extends "res://scripts/templates/game_template.gd"
## Reusable building definition for placement, production, garrison, and recruitment.

const ResourceAmountScript := preload("res://scripts/templates/resource_amount.gd")

enum BuildingRole { INFRA, RESOURCE, GOLD_CHAIN, MILITARY, SCOUT, RECRUIT, TOWN_HALL, SPECIAL }

@export var role: BuildingRole = BuildingRole.INFRA
@export var footprint: Vector2i = Vector2i.ONE
@export var hp_max: int = 1
@export var build_cost: Array = []
@export var production: Array = []
@export var terrain_compatibility: Array[int] = []
@export var max_per_faction: int = 99
@export var ap_cost: int = 2
@export var requires_territory: bool = true
@export var needs_resource_point: bool = false
@export var required_resource_tags: Array = []
@export var can_garrison: bool = false
@export var garrison_capacity: int = 0
@export var allowed_garrison_unit_tags: Array = []
@export var recruit_options: Array = []


func get_cost_dict() -> Dictionary:
	return ResourceAmountScript.list_to_dict(build_cost)


func allows_unit(unit_template: Resource) -> bool:
	if unit_template == null:
		return false
	if allowed_garrison_unit_tags.is_empty():
		return can_garrison
	return unit_template.has_any_tag(allowed_garrison_unit_tags)


func has_recruit_option(unit_id: String) -> bool:
	for unit_template in recruit_options:
		if unit_template != null and unit_template.id == unit_id:
			return true
	return false
