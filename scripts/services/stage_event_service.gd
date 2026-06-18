extends Node
class_name StageEventService
## Emits shared timeline events based on major-stage rules.

signal stage_started(stage: int, round_number: int)
signal goblin_market_started(stage: int, round_number: int)

const GameStageRulesScript = preload("res://scripts/rules/game_stage_rules.gd")

var _turn_manager: Node = null
var _last_stage_round := -1
var _last_goblin_market_round := -1


func set_turn_manager(turn_manager: Node) -> void:
	if _turn_manager and _turn_manager.round_started.is_connected(_on_round_started):
		_turn_manager.round_started.disconnect(_on_round_started)
	_turn_manager = turn_manager
	if _turn_manager and not _turn_manager.round_started.is_connected(_on_round_started):
		_turn_manager.round_started.connect(_on_round_started)


func get_stage_for_round(round_number: int) -> int:
	return GameStageRulesScript.get_stage_for_round(round_number)


func get_round_in_stage(round_number: int) -> int:
	return GameStageRulesScript.get_round_in_stage(round_number)


func is_stage_start_round(round_number: int) -> bool:
	return GameStageRulesScript.is_stage_start_round(round_number)


func _on_round_started(round_number: int) -> void:
	if not GameStageRulesScript.is_stage_start_round(round_number):
		return

	var stage: int = GameStageRulesScript.get_stage_for_round(round_number)
	if _last_stage_round != round_number:
		_last_stage_round = round_number
		stage_started.emit(stage, round_number)

	if GameStageRulesScript.is_goblin_market_stage_start(round_number) and _last_goblin_market_round != round_number:
		_last_goblin_market_round = round_number
		goblin_market_started.emit(stage, round_number)
