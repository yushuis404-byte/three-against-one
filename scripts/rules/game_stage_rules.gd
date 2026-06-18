extends RefCounted
class_name GameStageRules
## Shared major-stage timing rules.
##
## One major stage contains 15 rounds. The full match has 5 stages:
## stage 1 = rounds 1-15, stage 2 = rounds 16-30, ... stage 5 = rounds 61-75.

const ROUNDS_PER_STAGE := 15
const TOTAL_STAGES := 5
const FIRST_STAGE := 1
const LAST_STAGE := TOTAL_STAGES
const FIRST_GOBLIN_MARKET_STAGE := 2


static func get_stage_for_round(round_number: int) -> int:
	if round_number <= 0:
		return 0
	var stage: int = int((round_number - 1) / ROUNDS_PER_STAGE) + 1
	return clampi(stage, FIRST_STAGE, LAST_STAGE)


static func get_round_in_stage(round_number: int) -> int:
	if round_number <= 0:
		return 0
	return ((round_number - 1) % ROUNDS_PER_STAGE) + 1


static func get_stage_start_round(stage: int) -> int:
	if stage < FIRST_STAGE or stage > LAST_STAGE:
		return -1
	return (stage - 1) * ROUNDS_PER_STAGE + 1


static func get_stage_end_round(stage: int) -> int:
	if stage < FIRST_STAGE or stage > LAST_STAGE:
		return -1
	return stage * ROUNDS_PER_STAGE


static func is_stage_start_round(round_number: int) -> bool:
	return round_number > 0 and get_round_in_stage(round_number) == 1


static func is_within_total_stages(round_number: int) -> bool:
	return round_number >= 1 and round_number <= ROUNDS_PER_STAGE * TOTAL_STAGES


static func is_goblin_market_stage_start(round_number: int) -> bool:
	if not is_within_total_stages(round_number):
		return false
	if not is_stage_start_round(round_number):
		return false
	return get_stage_for_round(round_number) >= FIRST_GOBLIN_MARKET_STAGE
