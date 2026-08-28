class_name HeroMotor
extends Node

var move_speed: float = 5.0
var move_input: Vector3 = Vector3.ZERO


func configure(speed: float) -> void:
	move_speed = maxf(speed, 0.1)


func set_move_input(value: Vector3) -> void:
	move_input = value.limit_length(1.0)


func tick(body: CharacterBody3D, delta: float) -> void:
	body.velocity.x = move_input.x * move_speed
	body.velocity.z = move_input.z * move_speed
	if not body.is_on_floor():
		body.velocity.y -= 20.0 * delta
	body.move_and_slide()
