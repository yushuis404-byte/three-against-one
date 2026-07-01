class_name GoblinHexService
extends Node
const GoblinHexCardLibraryScript := preload("res://scripts/rules/goblin_hex_card_library.gd")
signal choices_changed(player: int, round_number: int, choices: Array)
signal card_selected(player: int, round_number: int, card: Dictionary)
var _resource_tracker: Node = null
var _turn_manager: Node = null
var _technology_service: Node = null
var _current_round := 0
var _round_rarity: Dictionary = {}
var _choices: Dictionary = {}
var _refresh_used: Dictionary = {}
var _selected_cards: Dictionary = {}
var _permanent_modifiers: Array = [{}, {}, {}]
var _timed_effects: Array = [[], [], []]
func setup(resource_tracker: Node, turn_manager: Node, technology_service: Node) -> void:
	_resource_tracker = resource_tracker
	_turn_manager = turn_manager
	_technology_service = technology_service
	if _turn_manager != null:
		_current_round = int(_turn_manager.get("round_number"))
		if not _turn_manager.round_started.is_connected(_on_round_started):
			_turn_manager.round_started.connect(_on_round_started)
	if _technology_service != null and _technology_service.has_method("register_modifier_source"):
		_technology_service.call("register_modifier_source", self)
func is_hex_round(round_number: int) -> bool:
	return round_number in GoblinHexCardLibraryScript.get_trigger_rounds()
func can_player_choose(player: int, round_number: int) -> bool:
	if player < 0 or player >= 3:
		return false
	if not is_hex_round(round_number):
		return false
	return not _selected_cards.has(_player_round_key(player, round_number))
func prepare_round(round_number: int) -> String:
	if not is_hex_round(round_number):
		return ""
	if _round_rarity.has(round_number):
		return str(_round_rarity[round_number])
	var rarity: String = _roll_rarity_for_round(round_number)
	_round_rarity[round_number] = rarity
	return rarity
func get_round_rarity(round_number: int) -> String:
	if not _round_rarity.has(round_number):
		return prepare_round(round_number)
	return str(_round_rarity[round_number])
func get_choices(player: int, round_number: int) -> Array:
	if player < 0 or player >= 3:
		return []
	if not is_hex_round(round_number):
		return []
	var key: String = _player_round_key(player, round_number)
	if not _choices.has(key):
		_choices[key] = _generate_choices(player, round_number)
		_refresh_used[key] = [false, false, false]
	return _duplicate_cards(_choices[key])
func get_refresh_used(player: int, round_number: int) -> Array:
	var key: String = _player_round_key(player, round_number)
	if not _refresh_used.has(key):
		return [false, false, false]
	return _refresh_used[key].duplicate()
func refresh_choice(player: int, round_number: int, index: int) -> bool:
	if not can_player_choose(player, round_number):
		return false
	if index < 0 or index >= 3:
		return false
	var key: String = _player_round_key(player, round_number)
	if not _choices.has(key):
		_choices[key] = _generate_choices(player, round_number)
		_refresh_used[key] = [false, false, false]
	var used: Array = _refresh_used[key]
	if bool(used[index]):
		return false
	var choices: Array = _choices[key]
	var rarity: String = get_round_rarity(round_number)
	var replacement: Dictionary = _draw_replacement_card(player, round_number, rarity, choices, index)
	if replacement.is_empty():
		return false
	choices[index] = replacement
	used[index] = true
	_choices[key] = choices
	_refresh_used[key] = used
	choices_changed.emit(player, round_number, get_choices(player, round_number))
	return true
func select_choice(player: int, round_number: int, index: int) -> Dictionary:
	if not can_player_choose(player, round_number):
		return {}
	if index < 0 or index >= 3:
		return {}
	var choices: Array = get_choices(player, round_number)
	if index >= choices.size():
		return {}
	var card: Dictionary = choices[index]
	_apply_card_effect(player, round_number, card)
	_selected_cards[_player_round_key(player, round_number)] = card.duplicate(true)
	card_selected.emit(player, round_number, card.duplicate(true))
	return card.duplicate(true)
func get_modifier(player: int, key: String, default_value: int = 0) -> int:
	if player < 0 or player >= _permanent_modifiers.size():
		return default_value
	var total := 0
	var permanent: Dictionary = _permanent_modifiers[player]
	total += int(permanent.get(key, 0))
	var active_round: int = _get_active_round()
	var effects: Array = _timed_effects[player]
	for effect_variant in effects:
		var effect: Dictionary = effect_variant
		if int(effect.get("expires_round", -1)) < active_round:
			continue
		var modifiers: Dictionary = effect.get("modifiers", {})
		total += int(modifiers.get(key, 0))
	if total == 0:
		return default_value
	return total
func get_selected_card(player: int, round_number: int) -> Dictionary:
	var key: String = _player_round_key(player, round_number)
	if not _selected_cards.has(key):
		return {}
	return _selected_cards[key].duplicate(true)
func _on_round_started(round_number: int) -> void:
	_current_round = round_number
	_clear_expired_effects(round_number)
	if is_hex_round(round_number):
		prepare_round(round_number)
func _clear_expired_effects(round_number: int) -> void:
	for player in range(_timed_effects.size()):
		var kept: Array = []
		for effect_variant in _timed_effects[player]:
			var effect: Dictionary = effect_variant
			if int(effect.get("expires_round", -1)) >= round_number:
				kept.append(effect)
		_timed_effects[player] = kept
func _roll_rarity_for_round(round_number: int) -> String:
	var weights: Dictionary = GoblinHexCardLibraryScript.get_rarity_weights(round_number)
	var total := 0
	for rarity in weights:
		total += int(weights[rarity])
	if total <= 0:
		return GoblinHexCardLibraryScript.RARITY_SILVER
	var rng := RandomNumberGenerator.new()
	rng.randomize()
	var roll: int = rng.randi_range(1, total)
	var cursor := 0
	for rarity in [
			GoblinHexCardLibraryScript.RARITY_BLACK,
			GoblinHexCardLibraryScript.RARITY_SILVER,
			GoblinHexCardLibraryScript.RARITY_GOLD,
			GoblinHexCardLibraryScript.RARITY_PRISMATIC,
		]:
		cursor += int(weights.get(rarity, 0))
		if roll <= cursor:
			return str(rarity)
	return GoblinHexCardLibraryScript.RARITY_SILVER
func _generate_choices(player: int, round_number: int) -> Array:
	var rarity: String = get_round_rarity(round_number)
	var pool: Array = _eligible_cards(player, rarity)
	var shuffled: Array = _shuffle_cards(pool, round_number * 31 + player * 101)
	var result: Array = []
	var picked_faction := false
	for card_variant in shuffled:
		var card: Dictionary = card_variant
		if result.size() >= 3:
			break
		if _has_card_id(result, str(card.get("id", ""))):
			continue
		var faction: int = int(card.get("faction", -1))
		if faction >= 0 and picked_faction:
			continue
		if faction >= 0:
			picked_faction = true
		result.append(_visible_card(card, rarity))
	_ensure_category_mix(result, player, round_number, rarity)
	return result
func _draw_replacement_card(player: int, round_number: int, rarity: String, choices: Array, index: int) -> Dictionary:
	var pool: Array = _shuffle_cards(_eligible_cards(player, rarity), round_number * 401 + player * 37 + index * 19)
	for card_variant in pool:
		var card: Dictionary = card_variant
		var id: String = str(card.get("id", ""))
		var duplicate := false
		for i in range(choices.size()):
			if i == index:
				continue
			var existing: Dictionary = choices[i]
			if str(existing.get("id", "")) == id:
				duplicate = true
				break
		if duplicate:
			continue
		return _visible_card(card, rarity)
	return {}
func _eligible_cards(player: int, rarity: String) -> Array:
	var result: Array = []
	for card_variant in GoblinHexCardLibraryScript.get_cards():
		var card: Dictionary = card_variant
		var faction: int = int(card.get("faction", -1))
		if faction != -1 and faction != player:
			continue
		var tiers: Dictionary = card.get("tiers", {})
		if not tiers.has(rarity):
			continue
		result.append(card)
	return result
func _visible_card(card: Dictionary, rarity: String) -> Dictionary:
	var tiers: Dictionary = card.get("tiers", {})
	var effects: Dictionary = {}
	if tiers.has(rarity) and tiers[rarity] is Dictionary:
		effects = tiers[rarity].duplicate(true)
	var category: String = str(card.get("category", ""))
	return {
		"id": str(card.get("id", "")),
		"name": str(card.get("name", "")),
		"category": category,
		"category_name": str(GoblinHexCardLibraryScript.CATEGORY_NAMES.get(category, category)),
		"faction": int(card.get("faction", -1)),
		"rarity": rarity,
		"rarity_name": str(GoblinHexCardLibraryScript.RARITY_NAMES.get(rarity, rarity)),
		"rarity_color": GoblinHexCardLibraryScript.RARITY_COLORS.get(rarity, Color.WHITE),
		"effects": effects,
		"description": GoblinHexCardLibraryScript.describe_effects(effects),
	}
func _ensure_category_mix(result: Array, player: int, round_number: int, rarity: String) -> void:
	if result.size() < 3:
		return
	var categories: Dictionary = {}
	for card_variant in result:
		var card: Dictionary = card_variant
		categories[str(card.get("category", ""))] = true
	if categories.size() >= 2:
		return
	var pool: Array = _shuffle_cards(_eligible_cards(player, rarity), round_number * 71 + player * 17)
	for candidate_variant in pool:
		var candidate: Dictionary = candidate_variant
		if _has_card_id(result, str(candidate.get("id", ""))):
			continue
		if str(candidate.get("category", "")) == str(result[0].get("category", "")):
			continue
		result[2] = _visible_card(candidate, rarity)
		return
func _apply_card_effect(player: int, round_number: int, card: Dictionary) -> void:
	var effects: Dictionary = card.get("effects", {})
	var resources: Dictionary = effects.get("resources", {})
	if _resource_tracker != null:
		for key in resources:
			_resource_tracker.call("add_resource", player, str(key), int(resources[key]))
		if _resource_tracker.has_method("update_display"):
			_resource_tracker.call("update_display", player)
	var ap: int = int(effects.get("ap", 0))
	if ap > 0 and _turn_manager != null and _turn_manager.has_method("add_ap"):
		_turn_manager.call("add_ap", player, ap)
	var modifiers: Dictionary = effects.get("modifiers", {})
	if modifiers.is_empty():
		return
	var duration: int = int(effects.get("duration_rounds", 0))
	if duration <= 0:
		_add_modifiers_to(_permanent_modifiers[player], modifiers)
	else:
		_timed_effects[player].append({
			"card_id": str(card.get("id", "")),
			"modifiers": modifiers.duplicate(true),
			"expires_round": round_number + duration - 1,
		})
func _add_modifiers_to(target: Dictionary, modifiers: Dictionary) -> void:
	for key in modifiers:
		var modifier_key: String = str(key)
		target[modifier_key] = int(target.get(modifier_key, 0)) + int(modifiers[key])
func _shuffle_cards(cards: Array, seed_value: int) -> Array:
	var result: Array = cards.duplicate(true)
	var rng := RandomNumberGenerator.new()
	rng.randomize()
	for warmup in range(maxi(0, seed_value % 7)):
		rng.randi()
	for i in range(result.size() - 1, 0, -1):
		var j: int = rng.randi_range(0, i)
		var tmp = result[i]
		result[i] = result[j]
		result[j] = tmp
	return result
func _has_card_id(cards: Array, id: String) -> bool:
	for card_variant in cards:
		var card: Dictionary = card_variant
		if str(card.get("id", "")) == id:
			return true
	return false
func _duplicate_cards(cards: Array) -> Array:
	var result: Array = []
	for card_variant in cards:
		var card: Dictionary = card_variant
		result.append(card.duplicate(true))
	return result
func _get_active_round() -> int:
	if _turn_manager != null:
		return int(_turn_manager.get("round_number"))
	return _current_round
func _player_round_key(player: int, round_number: int) -> String:
	return "%d:%d" % [round_number, player]
