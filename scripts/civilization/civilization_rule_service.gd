class_name CivilizationRuleService
extends Node
## Unified query surface for player civilization routes.

signal route_changed(player: int)

@export var elf_state_path: NodePath = NodePath("../ElfCivilizationState")
@export var dwarf_state_path: NodePath = NodePath("../DwarfCivilizationState")
@export var orc_state_path: NodePath = NodePath("../OrcCivilizationState")

var _states: Dictionary = {}


func _ready() -> void:
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
	for player in [0, 1, 2]:
		result.append(get_state_summary(player))
	return result


func add_lord(player: int, lord_id: String) -> bool:
	var state: CivilizationRouteState = get_route_state(player)
	return state.add_lord(lord_id) if state != null else false


func remove_lord(player: int, lord_id: String) -> bool:
	var state: CivilizationRouteState = get_route_state(player)
	return state.remove_lord(lord_id) if state != null else false


func _register_state(player: int, state: Node) -> void:
	if state == null:
		push_warning("[CivilizationRuleService] Missing route state for player %d" % player)
		return
	_states[player] = state
	if state.has_signal("route_changed"):
		state.route_changed.connect(_on_route_changed)


func _on_route_changed(player: int) -> void:
	route_changed.emit(player)
