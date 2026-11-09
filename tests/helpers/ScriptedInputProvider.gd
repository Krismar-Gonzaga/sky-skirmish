extends InputProvider
## Test double: returns whatever input the test sets.

var input: PlayerInput = PlayerInput.new()


func poll(_aim_origin: Vector2) -> PlayerInput:
	return input
