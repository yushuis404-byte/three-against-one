class_name LordTemplate
extends "res://scripts/templates/game_template.gd"
## Reusable lord definition for civilization routes, unlocks, and passive modifiers.

enum Civilization { ELF, DWARF, ORC, NEUTRAL }
enum Axis { INFORMATION, SPACE, WAR }

@export var civilization: Civilization = Civilization.NEUTRAL
@export var primary_axis: Axis = Axis.INFORMATION
@export var axis_values: Dictionary = {
	"information": 0,
	"space": 0,
	"war": 0,
}
@export var required_lord_tags: Array = []
@export var exclusive_lord_tags: Array = []
@export var unlock_unit_ids: Array = []
@export var unlock_building_ids: Array = []
@export var unlock_recipe_ids: Array = []
@export var unlock_action_ids: Array = []
@export var passive_modifiers: Dictionary = {}


static func make_basic(
		p_id: String,
		p_name: String,
		p_civilization: Civilization,
		p_primary_axis: Axis,
		p_axis_values: Dictionary,
		p_tags: Array = []) -> LordTemplate:
	var template: LordTemplate = load("res://scripts/templates/lord_template.gd").new()
	template.id = p_id
	template.display_name = p_name
	template.civilization = p_civilization
	template.primary_axis = p_primary_axis
	template.axis_values = p_axis_values.duplicate(true)
	template.tags = p_tags.duplicate()
	return template


func create_variant(new_id: String, overrides: Dictionary) -> LordTemplate:
	var variant: LordTemplate = duplicate(true)
	variant.id = new_id
	for key in overrides.keys():
		variant.set(String(key), overrides[key])
	return variant


func get_axis_value(axis_key: String) -> int:
	return int(axis_values.get(axis_key, 0))


func get_modifier(key: String, default_value: Variant = 0) -> Variant:
	return passive_modifiers.get(key, default_value)


func unlocks_unit(unit_id: String) -> bool:
	return unit_id in unlock_unit_ids


func unlocks_building(building_id: String) -> bool:
	return building_id in unlock_building_ids


func unlocks_recipe(recipe_id: String) -> bool:
	return recipe_id in unlock_recipe_ids


func unlocks_action(action_id: String) -> bool:
	return action_id in unlock_action_ids


func can_stack_with(other_lord: LordTemplate) -> bool:
	if other_lord == null:
		return true
	if has_any_tag(other_lord.exclusive_lord_tags):
		return false
	if other_lord.has_any_tag(exclusive_lord_tags):
		return false
	return true
