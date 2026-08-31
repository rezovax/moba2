class_name ArcherInput
extends Node

var movement: Vector2 = Vector2.ZERO
var wants_run: bool = false
var wants_aim: bool = false
var wants_shoot: bool = false


func sample() -> void:
	movement = (
		Input
		. get_vector(
			"move_left",
			"move_right",
			"move_forward",
			"move_backward",
		)
	)
	wants_run = Input.is_action_pressed("run")
	wants_aim = Input.is_action_pressed("aim")
	wants_shoot = Input.is_action_pressed("shoot")
