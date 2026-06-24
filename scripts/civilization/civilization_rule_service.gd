class_name CivilizationRuleService
extends Node
## Unified query surface for player civilization routes.

signal route_changed(player: int)

@export var elf_state_path: NodePath = NodePath("../ElfCivilizationState")
@export var dwarf_state_path: NodePath = NodePath("../DwarfCivilizationState")
@export var orc_state_path: NodePath = NodePath("../OrcCivilizationState")
@export var template_registry_path: NodePath = NodePath("../TemplateRegistry")

var _states: Dictionary = {}
var _template_registry: Node = null


func _ready() -> void:
	_template_registry = get_node_or_null(template_registry_path)
	if _template_registry == null:
		_template_registry = get_parent().get_node_or_null("TemplateRegistry")
	_register_state(0, get_node_or_null(elf_state_path))
	_register_state(1, get_node_or_null(dwarf_state_path))
	_register_state(2, get_node_or_null(orc_state_path))


func get_route_state(player: int) -> CivilizationRouteState:
	return _states.get(player, null) as CivilizationRouteState


func has_lord(player: int, lord_id: String) -> bool:
	var state: CivilizationRouteState = get_route_state(player)
	return state != null and state.has_lord(lord_id)


func get_lord_ids(player: int) -> Array:
	var state: CivilizationRouteState = get_route_state(player)
	return state.get_lord_ids() if state != null else []


func get_axis_value(player: int, axis_key: String) -> int:
	var state: CivilizationRouteState = get_route_state(player)
	return state.get_axis_value(axis_key) if state != null else 0


func get_axis_values(player: int) -> Dictionary:
	var state: CivilizationRouteState = get_route_state(player)
	return state.get_axis_values() if state != null else {}


func get_modifier(player: int, key: String, default_value: Variant = 0) -> Variant:
	var state: CivilizationRouteState = get_route_state(player)
	return state.get_modifier(key, default_value) if state != null else default_value


func get_modifier_int(player: int, key: String, default_value: int = 0) -> int:
	var state: CivilizationRouteState = get_route_state(player)
	return state.get_modifier_int(key, default_value) if state != null else default_value


func get_unlocked_units(player: int) -> Array:
	var state: CivilizationRouteState = get_route_state(player)
	return state.get_unlocked_units() if state != null else []


func get_unlocked_buildings(player: int) -> Array:
	var state: CivilizationRouteState = get_route_state(player)
	return state.get_unlocked_buildings() if state != null else []


func get_unlocked_recipes(player: int) -> Array:
	var state: CivilizationRouteState = get_route_state(player)
	return state.get_unlocked_recipes() if state != null else []


func get_unlocked_actions(player: int) -> Array:
	var state: CivilizationRouteState = get_route_state(player)
	return state.get_unlocked_actions() if state != null else []


func unlocks_unit(player: int, unit_id: String) -> bool:
	var state: CivilizationRouteState = get_route_state(player)
	return state != null and state.unlocks_unit(unit_id)


func unlocks_building(player: int, building_id: String) -> bool:
	var state: CivilizationRouteState = get_route_state(player)
	return state != null and state.unlocks_building(building_id)


func unlocks_recipe(player: int, recipe_id: String) -> bool:
	var state: CivilizationRouteState = get_route_state(player)
	return state != null and state.unlocks_recipe(recipe_id)


func unlocks_action(player: int, action_id: String) -> bool:
	var state: CivilizationRouteState = get_route_state(player)
	return state != null and state.unlocks_action(action_id)


func get_state_summary(player: int) -> Dictionary:
	var state: CivilizationRouteState = get_route_state(player)
	return state.get_state_summary() if state != null else {}


func get_all_state_summaries() -> Array:
	var result: Array = []
	for player_value in [0, 1, 2]:
		var player: int = int(player_value)
		result.append(get_state_summary(player))
	return result


func get_lord_template(lord_id: String) -> LordTemplate:
	if _template_registry == null or not _template_registry.has_method("get_lord"):
		return null
	var lord: Resource = _template_registry.call("get_lord", lord_id)
	return lord as LordTemplate


func get_candidate_lords(player: int) -> Array:
	if _template_registry == null or not _template_registry.has_method("get_lords_by_civilization"):
		return []
	var result: Array = _template_registry.call("get_lords_by_civilization", player)
	return result


func get_lord_summary(lord_id: String) -> Dictionary:
	var lord: LordTemplate = get_lord_template(lord_id)
	if lord == null:
		return {}
	return _make_lord_summary(lord)


func get_lord_summaries(player: int) -> Array:
	var result: Array = []
	for lord in get_candidate_lords(player):
		var template: LordTemplate = lord as LordTemplate
		if template == null:
			continue
		var summary: Dictionary = _make_lord_summary(template)
		summary["add_info"] = get_lord_add_info(player, template.id)
		result.append(summary)
	return result


func get_lord_add_info(player: int, lord_id: String) -> Dictionary:
	var state: CivilizationRouteState = get_route_state(player)
	if state == null:
		return {"available": false, "reason": "state_missing"}
	if lord_id.is_empty():
		return {"available": false, "reason": "empty_id"}
	if state.has_lord(lord_id):
		return {"available": false, "reason": "already_owned"}
	var lord: LordTemplate = get_lord_template(lord_id)
	if lord == null:
		return {"available": false, "reason": "lord_missing"}
	var civilization: int = int(lord.civilization)
	if civilization != player and civilization != LordTemplate.Civilization.NEUTRAL:
		return {"available": false, "reason": "wrong_civilization"}
	for required_tag in lord.required_lord_tags:
		var tag_text: String = str(required_tag)
		if tag_text.is_empty():
			continue
		if not _route_has_lord_tag(state, tag_text):
			return {"available": false, "reason": "missing_required_tag", "tag": tag_text}
	for existing_id in state.get_lord_ids():
		var existing: LordTemplate = get_lord_template(str(existing_id))
		if existing != null and not lord.can_stack_with(existing):
			return {
				"available": false,
				"reason": "exclusive_conflict",
				"conflict_lord_id": existing.id,
			}
	return {"available": true, "reason": "ok"}


func can_add_lord(player: int, lord_id: String) -> bool:
	var info: Dictionary = get_lord_add_info(player, lord_id)
	return bool(info.get("available", false))


func get_lord_remove_info(player: int, lord_id: String) -> Dictionary:
	var state: CivilizationRouteState = get_route_state(player)
	if state == null:
		return {"available": false, "reason": "state_missing"}
	if lord_id.is_empty():
		return {"available": false, "reason": "empty_id"}
	if not state.has_lord(lord_id):
		return {"available": false, "reason": "not_owned"}
	if lord_id == state.primary_lord_id:
		return {"available": false, "reason": "primary_lord"}
	return {"available": true, "reason": "ok"}


func can_remove_lord(player: int, lord_id: String) -> bool:
	var info: Dictionary = get_lord_remove_info(player, lord_id)
	return bool(info.get("available", false))


func add_lord(player: int, lord_id: String) -> bool:
	var state: CivilizationRouteState = get_route_state(player)
	if state == null or not can_add_lord(player, lord_id):
		return false
	return state.add_lord(lord_id)


func remove_lord(player: int, lord_id: String) -> bool:
	var state: CivilizationRouteState = get_route_state(player)
	if state == null or not can_remove_lord(player, lord_id):
		return false
	return state.remove_lord(lord_id)


func _register_state(player: int, state: Node) -> void:
	if state == null:
		push_warning("[CivilizationRuleService] Missing route state for player %d" % player)
		return
	_states[player] = state
	if state.has_signal("route_changed"):
		state.route_changed.connect(_on_route_changed)


func _on_route_changed(player: int) -> void:
	route_changed.emit(player)


func _make_lord_summary(lord: LordTemplate) -> Dictionary:
	return {
		"id": lord.id,
		"display_name": lord.display_name,
		"description": lord.description,
		"civilization": int(lord.civilization),
		"primary_axis": int(lord.primary_axis),
		"axis_values": lord.axis_values.duplicate(true),
		"tags": lord.tags.duplicate(),
		"required_lord_tags": lord.required_lord_tags.duplicate(),
		"exclusive_lord_tags": lord.exclusive_lord_tags.duplicate(),
		"unlock_units": lord.unlock_unit_ids.duplicate(),
		"unlock_buildings": lord.unlock_building_ids.duplicate(),
		"unlock_recipes": lord.unlock_recipe_ids.duplicate(),
		"unlock_actions": lord.unlock_action_ids.duplicate(),
		"passive_modifiers": lord.passive_modifiers.duplicate(true),
	}


func _route_has_lord_tag(state: CivilizationRouteState, tag: String) -> bool:
	for lord_id in state.get_lord_ids():
		var lord: LordTemplate = get_lord_template(str(lord_id))
		if lord != null and lord.has_tag(tag):
			return true
	return false
