class_name CivilizationRouteState
extends Node
## Per-player civilization route state. Aggregates lord templates into queryable unlocks and modifiers.

signal route_changed(player: int)

@export var player: int = 0
@export var primary_lord_id: String = ""
@export var starting_lord_ids: Array = []
@export var template_registry_path: NodePath = NodePath("../TemplateRegistry")

var _template_registry: Node = null
var _lord_ids: Array = []
var _axis_values: Dictionary = {
	"information": 0,
	"space": 0,
	"war": 0,
}
var _unlocked_unit_ids: Array = []
var _unlocked_building_ids: Array = []
var _unlocked_recipe_ids: Array = []
var _unlocked_action_ids: Array = []
var _passive_modifiers: Dictionary = {}


func _ready() -> void:
	_template_registry = get_node_or_null(template_registry_path)
	if _template_registry == null:
		_template_registry = get_parent().get_node_or_null("TemplateRegistry")
	_initialize_route()


func _initialize_route() -> void:
	_lord_ids.clear()
	if not primary_lord_id.is_empty():
		_lord_ids.append(primary_lord_id)
	for lord_id in starting_lord_ids:
		var id_text: String = str(lord_id)
		if not id_text.is_empty() and not (id_text in _lord_ids):
			_lord_ids.append(id_text)
	_rebuild_state()


func add_lord(lord_id: String) -> bool:
	if lord_id.is_empty() or lord_id in _lord_ids:
		return false
	var lord: LordTemplate = _get_lord(lord_id)
	if lord == null:
		push_warning("[Civilization] Missing lord template: %s" % lord_id)
		return false
	for existing_id in _lord_ids:
		var existing: LordTemplate = _get_lord(str(existing_id))
		if existing != null and not lord.can_stack_with(existing):
			return false
	_lord_ids.append(lord_id)
	_rebuild_state()
	route_changed.emit(player)
	return true


func remove_lord(lord_id: String) -> bool:
	if not (lord_id in _lord_ids):
		return false
	_lord_ids.erase(lord_id)
	_rebuild_state()
	route_changed.emit(player)
	return true


func has_lord(lord_id: String) -> bool:
	return lord_id in _lord_ids


func get_lord_ids() -> Array:
	return _lord_ids.duplicate()


func get_axis_value(axis_key: String) -> int:
	return int(_axis_values.get(axis_key, 0))


func get_axis_values() -> Dictionary:
	return _axis_values.duplicate(true)


func get_unlocked_units() -> Array:
	return _unlocked_unit_ids.duplicate()


func get_unlocked_buildings() -> Array:
	return _unlocked_building_ids.duplicate()


func get_unlocked_recipes() -> Array:
	return _unlocked_recipe_ids.duplicate()


func get_unlocked_actions() -> Array:
	return _unlocked_action_ids.duplicate()


func unlocks_unit(unit_id: String) -> bool:
	return unit_id in _unlocked_unit_ids


func unlocks_building(building_id: String) -> bool:
	return building_id in _unlocked_building_ids


func unlocks_recipe(recipe_id: String) -> bool:
	return recipe_id in _unlocked_recipe_ids


func unlocks_action(action_id: String) -> bool:
	return action_id in _unlocked_action_ids


func get_modifier(key: String, default_value: Variant = 0) -> Variant:
	return _passive_modifiers.get(key, default_value)


func get_modifier_int(key: String, default_value: int = 0) -> int:
	return int(_passive_modifiers.get(key, default_value))


func get_passive_modifiers() -> Dictionary:
	return _passive_modifiers.duplicate(true)


func get_state_summary() -> Dictionary:
	return {
		"player": player,
		"primary_lord_id": primary_lord_id,
		"lord_ids": get_lord_ids(),
		"axis_values": get_axis_values(),
		"unlocked_units": get_unlocked_units(),
		"unlocked_buildings": get_unlocked_buildings(),
		"unlocked_recipes": get_unlocked_recipes(),
		"unlocked_actions": get_unlocked_actions(),
		"passive_modifiers": get_passive_modifiers(),
	}


func _rebuild_state() -> void:
	_axis_values = {
		"information": 0,
		"space": 0,
		"war": 0,
	}
	_unlocked_unit_ids.clear()
	_unlocked_building_ids.clear()
	_unlocked_recipe_ids.clear()
	_unlocked_action_ids.clear()
	_passive_modifiers.clear()

	for lord_id in _lord_ids:
		var lord: LordTemplate = _get_lord(str(lord_id))
		if lord == null:
			push_warning("[Civilization] Skipping missing lord template: %s" % str(lord_id))
			continue
		_merge_axis_values(lord.axis_values)
		_append_unique_many(_unlocked_unit_ids, lord.unlock_unit_ids)
		_append_unique_many(_unlocked_building_ids, lord.unlock_building_ids)
		_append_unique_many(_unlocked_recipe_ids, lord.unlock_recipe_ids)
		_append_unique_many(_unlocked_action_ids, lord.unlock_action_ids)
		_merge_modifiers(lord.passive_modifiers)


func _get_lord(lord_id: String) -> LordTemplate:
	if _template_registry == null or not _template_registry.has_method("get_lord"):
		return null
	var lord: Resource = _template_registry.call("get_lord", lord_id)
	return lord as LordTemplate


func _merge_axis_values(values: Dictionary) -> void:
	for key in values.keys():
		var axis_key: String = str(key)
		_axis_values[axis_key] = int(_axis_values.get(axis_key, 0)) + int(values[key])


func _append_unique_many(target: Array, values: Array) -> void:
	for value in values:
		var id_text: String = str(value)
		if id_text.is_empty() or id_text in target:
			continue
		target.append(id_text)


func _merge_modifiers(values: Dictionary) -> void:
	for key in values.keys():
		var modifier_key: String = str(key)
		var incoming: Variant = values[key]
		if incoming is int or incoming is float:
			_passive_modifiers[modifier_key] = _passive_modifiers.get(modifier_key, 0) + incoming
		else:
			_passive_modifiers[modifier_key] = incoming
