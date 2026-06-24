class_name VictoryService
extends Node

const GameStageRulesScript = preload("res://scripts/rules/game_stage_rules.gd")
const RESOURCE_SCORE_RULES := {
	"gold": {"divisor": 1, "points": 4, "cap": 160},
	"gold_ore": {"divisor": 1, "points": 1, "cap": 80},
	"magic_dust": {"divisor": 1, "points": 2, "cap": 80},
	"fire_dragon_blood": {"divisor": 1, "points": 8, "cap": 96},
	"frost_dragon_blood": {"divisor": 1, "points": 8, "cap": 96},
	"toxic_dragon_blood": {"divisor": 1, "points": 8, "cap": 96},
	"ancient_wood": {"divisor": 2, "points": 1, "cap": 60},
	"iron": {"divisor": 3, "points": 1, "cap": 60},
	"wood": {"divisor": 5, "points": 1, "cap": 40},
	"stone": {"divisor": 5, "points": 1, "cap": 40},
	"food": {"divisor": 5, "points": 1, "cap": 40},
}
const BUILDING_SCORE_CAP := 220
const UNIT_SCORE_CAP := 160

signal conquest_victory_declared(winner: int, reason: String)
signal final_scoring_started(scores: Array, winner: int)

var _turn_manager: Node = null
var _building_manager: Node = null
var _unit_manager: Node = null
var _resource_tracker: Node = null
var _technology_service: Node = null
var _game_over := false


func setup(
		turn_manager: Node,
		building_manager: Node,
		unit_manager: Node,
		resource_tracker: Node,
		technology_service: Node) -> void:
	_turn_manager = turn_manager
	_building_manager = building_manager
	_unit_manager = unit_manager
	_resource_tracker = resource_tracker
	_technology_service = technology_service
	if _turn_manager != null:
		if _turn_manager.has_signal("player_turn_started") and not _turn_manager.player_turn_started.is_connected(_on_player_turn_started):
			_turn_manager.player_turn_started.connect(_on_player_turn_started)
		if _turn_manager.has_signal("round_ended") and not _turn_manager.round_ended.is_connected(_on_round_ended):
			_turn_manager.round_ended.connect(_on_round_ended)


func is_game_over() -> bool:
	return _game_over


func check_now() -> void:
	if _game_over:
		return
	_check_conquest()


func get_alive_players() -> Array[int]:
	var alive: Array[int] = []
	for player in range(3):
		if _has_core_building(player):
			alive.append(player)
	return alive


func calculate_scores() -> Array:
	var scores: Array = []
	for player in range(3):
		scores.append(_calculate_player_score(player))
	return scores


func _on_player_turn_started(_player: int) -> void:
	_check_conquest()


func _on_round_ended(round_number: int) -> void:
	if _game_over:
		return
	if _check_conquest():
		return
	if round_number >= GameStageRulesScript.get_stage_end_round(GameStageRulesScript.TOTAL_STAGES):
		_trigger_final_scoring()


func _check_conquest() -> bool:
	if _game_over:
		return false
	var alive: Array[int] = get_alive_players()
	if alive.size() == 1:
		_game_over = true
		var winner: int = alive[0]
		_stop_turn_manager()
		conquest_victory_declared.emit(winner, "only_core_survivor")
		return true
	return false


func _trigger_final_scoring() -> void:
	_game_over = true
	var scores: Array = calculate_scores()
	var winner: int = _get_score_winner(scores)
	_stop_turn_manager()
	final_scoring_started.emit(scores, winner)


func _calculate_player_score(player: int) -> Dictionary:
	var score := 0
	var breakdown := {}
	var core_score := 100 if _has_core_building(player) else 0
	breakdown["core"] = core_score
	score += core_score

	var building_score := _calculate_building_score(player)
	breakdown["buildings"] = building_score
	score += building_score

	var unit_score := _calculate_unit_score(player)
	breakdown["units"] = unit_score
	score += unit_score

	var tech_score := _count_player_technologies(player) * 5
	breakdown["technologies"] = tech_score
	score += tech_score

	var resource_score := _calculate_resource_score(player)
	breakdown["resources"] = resource_score
	score += resource_score

	return {
		"player": player,
		"score": score,
		"breakdown": breakdown,
	}


func _get_score_winner(scores: Array) -> int:
	var winner := -1
	var best := -999999
	for item in scores:
		var entry: Dictionary = item
		var score: int = int(entry.get("score", 0))
		if score > best:
			best = score
			winner = int(entry.get("player", -1))
	return winner


func _has_core_building(player: int) -> bool:
	if _building_manager == null or not _building_manager.has_method("get_all_buildings"):
		return false
	var buildings: Array = _building_manager.get_all_buildings()
	for building in buildings:
		if int(building.get("faction", -1)) != player:
			continue
		var data: BuildingData = building.get("data", null)
		if data != null and data.category == BuildingData.BuildingCategory.CORE:
			return true
	return false


func _calculate_building_score(player: int) -> int:
	if _building_manager == null or not _building_manager.has_method("get_all_buildings"):
		return 0
	var total := 0
	for building in _building_manager.get_all_buildings():
		if int(building.get("faction", -1)) != player:
			continue
		total += _get_building_score(building)
	return mini(total, BUILDING_SCORE_CAP)


func _calculate_unit_score(player: int) -> int:
	if _unit_manager == null or not _unit_manager.has_method("get_all_units"):
		return 0
	var capped_total := 0
	var uncapped_total := 0
	for unit in _unit_manager.get_all_units():
		if int(unit.get("faction", -1)) != player:
			continue
		var unit_score: int = _get_unit_score(unit)
		if _is_uncapped_unit(unit):
			uncapped_total += unit_score
		else:
			capped_total += unit_score
	return mini(capped_total, UNIT_SCORE_CAP) + uncapped_total


func _get_building_score(building: Dictionary) -> int:
	var data: BuildingData = building.get("data", null)
	if data == null:
		return 0
	var base := 0
	match data.category:
		BuildingData.BuildingCategory.CORE:
			base = 100
		BuildingData.BuildingCategory.ECONOMY:
			base = 8
		BuildingData.BuildingCategory.STORAGE:
			var level: int = int(building.get("level", 1))
			if level <= 1:
				base = 10
			elif level == 2:
				base = 20
			else:
				base = 35
		BuildingData.BuildingCategory.RECRUITMENT:
			base = 15 if "barracks" in data.tags else 10
		BuildingData.BuildingCategory.SCOUT, BuildingData.BuildingCategory.EXPANSION:
			base = 12
		BuildingData.BuildingCategory.INDUSTRY:
			base = 16
		BuildingData.BuildingCategory.GOLD_CHAIN:
			base = 28 if BuildingRules.is_mint(data) else 22
		BuildingData.BuildingCategory.RARE:
			base = 24
		BuildingData.BuildingCategory.LORD_SPECIAL:
			base = 30
	if "dragon" in data.tags or "dragon_building" in data.tags:
		base = max(base, 40)
	var extra_level: int = maxi(0, int(building.get("level", 1)) - 1) * 6
	return base + extra_level


func _get_unit_score(unit: Dictionary) -> int:
	if not unit.has("data"):
		return 0
	var data: UnitData = unit["data"]
	var base := 0
	if "progenitor_blessed" in data.tags:
		base = 140
	elif "ancient_dragon" in data.tags or "dragon" in data.tags:
		base = 100
	elif "dragon_slayer" in data.tags:
		base = 32
	elif "dragonkin" in data.tags:
		base = 28
	else:
		match data.category:
			UnitData.UnitCategory.WORKER:
				base = 4
			UnitData.UnitCategory.SCOUT:
				base = 8
			UnitData.UnitCategory.GUARD:
				base = 10
			UnitData.UnitCategory.ELITE, UnitData.UnitCategory.SIEGE, UnitData.UnitCategory.SPECIAL:
				base = 18
	var hp: int = int(unit.get("hp", data.hp_max))
	var hp_max: int = maxi(1, data.hp_max)
	return int(ceil(float(base) * clampf(float(hp) / float(hp_max), 0.0, 1.0)))


func _is_uncapped_unit(unit: Dictionary) -> bool:
	if not unit.has("data"):
		return false
	var data: UnitData = unit["data"]
	return "dragon" in data.tags or "ancient_dragon" in data.tags or "progenitor_blessed" in data.tags


func _count_player_technologies(player: int) -> int:
	if _technology_service == null or not _technology_service.has_method("get_researched_ids"):
		return 0
	return _technology_service.get_researched_ids(player).size()


func _calculate_resource_score(player: int) -> int:
	if _resource_tracker == null or not _resource_tracker.has_method("get_all"):
		return 0
	var total_score := 0
	var resources: Dictionary = _resource_tracker.get_all(player)
	for key in resources:
		if not RESOURCE_SCORE_RULES.has(str(key)):
			continue
		var rule: Dictionary = RESOURCE_SCORE_RULES[str(key)]
		var amount: int = int(resources[key])
		var divisor: int = maxi(1, int(rule.get("divisor", 1)))
		var points: int = int(rule.get("points", 0))
		var cap: int = int(rule.get("cap", 0))
		var score: int = int(floor(float(amount) / float(divisor))) * points
		total_score += mini(score, cap)
	return total_score


func _stop_turn_manager() -> void:
	if _turn_manager != null and _turn_manager.has_method("stop_game"):
		_turn_manager.stop_game()
