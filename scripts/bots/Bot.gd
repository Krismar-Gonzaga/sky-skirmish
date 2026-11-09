class_name Bot
extends Player
## A Player driven by a BotBrain. Everything else is ordinary Player code.

var brain: BotBrain


## Call after the bot is in the tree. A positive hp_override sets custom health,
## as the Level 8 leader needs.
func setup(context: BotContext, difficulty_id: String, hp_override: float = 0.0) -> void:
	var stats: Dictionary = Difficulty.stats(difficulty_id)
	health.set_maximum(hp_override if hp_override > 0.0 else float(stats["hp"]))
	brain = BotBrain.new()
	add_child(brain)
	brain.configure(self, context, stats)
	input_provider = brain
