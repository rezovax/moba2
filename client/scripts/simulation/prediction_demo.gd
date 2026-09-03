class_name PredictionDemo
extends Node2D

const MAP_CENTER: Vector2 = Vector2(640.0, 340.0)
const PIXELS_PER_METER: float = 50.0

var _world: PredictionWorld

@onready var _character: Polygon2D = $Character
@onready var _joystick: ConceptJoystick = $Interface/VirtualJoystick
@onready var _status: Label = $Interface/Status


func _ready() -> void:
	_world = PredictionWorld.new()
	_update_character(_world.current_position())
	_update_status()


func _physics_process(_delta: float) -> void:
	var movement: Vector2 = _movement_input()
	var world_position: Vector2 = _world.advance(movement)
	_update_character(world_position)
	_update_status()


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_cancel"):
		_world.reset()
		_update_character(_world.current_position())


func _movement_input() -> Vector2:
	var joystick_input: Vector2 = _joystick.direction()
	if not joystick_input.is_zero_approx():
		return joystick_input
	return Input.get_vector("move_left", "move_right", "move_forward", "move_backward")


func _update_character(world_position: Vector2) -> void:
	_character.position = MAP_CENTER + world_position * PIXELS_PER_METER


func _update_status() -> void:
	var game_time: float = _world.game_time_seconds()
	var minutes: int = floori(game_time / 60.0)
	var seconds: float = game_time - float(minutes * 60)
	_status.text = (
		"Rust World · %d:%05.2f · tick %d"
		% [
			minutes,
			seconds,
			_world.current_tick(),
		]
	)
