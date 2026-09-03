extends SceneTree


func _init() -> void:
	var world: PredictionWorld = PredictionWorld.new()
	var predicted_position: Vector2 = Vector2.ZERO
	for _tick_index: int in range(60):
		predicted_position = world.advance(Vector2.RIGHT)
	if not is_equal_approx(predicted_position.x, 4.0):
		_fail("Expected four meters of movement after one second")
		return
	var recorded_position: Vector2 = world.position_at_time(1.0)
	if not recorded_position.is_equal_approx(predicted_position):
		_fail("Recorded state at one second differs from current state")
		return
	print("PREDICTION_WORLD_RUNTIME_PASS")
	quit(0)


func _fail(message: String) -> void:
	push_error(message)
	quit(1)
