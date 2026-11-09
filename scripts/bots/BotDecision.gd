class_name BotDecision
extends RefCounted
## The bot state machine's transition rules, separate from nodes for testing.

enum State { PATROL, CHASE, ATTACK, RETREAT }


## has_target: the bot knows about an enemy. can_shoot: it is visible and in range.
## A retreating bot keeps retreating until recovered, or it would flip back and
## forth around the threshold while regenerating.
static func next_state(
		current: State,
		health_ratio: float,
		has_target: bool,
		can_shoot: bool,
		retreat_below: float,
		recover_at: float
) -> State:
	if health_ratio < retreat_below:
		return State.RETREAT
	if current == State.RETREAT and health_ratio < recover_at:
		return State.RETREAT
	if can_shoot:
		return State.ATTACK
	if has_target:
		return State.CHASE
	return State.PATROL
