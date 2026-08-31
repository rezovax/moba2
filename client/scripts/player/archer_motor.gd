class_name ArcherMotor
extends Node

@export_category("Movement")
@export var walk_speed: float = 2.4
@export var run_speed: float = 5.8
@export var acceleration: float = 14.0
@export var deceleration: float = 20.0
@export var rotation_speed: float = 8.0
@export var reverse_speed_factor: float = 0.18
@export_category("Grounding")
@export var gravity: float = 24.0
@export var floor_stick_velocity: float = 0.5
@export_category("References")
@export var visual_root: Node3D
@export var camera_rig: ArcherCameraRig
@export var ground_check: RayCast3D

@onready var _body: CharacterBody3D = get_parent() as CharacterBody3D


func physics_step(
	input_vector: Vector2,
	running: bool,
	aiming: bool,
	delta: float,
) -> void:
	var move_direction: Vector3 = camera_rig.world_direction(input_vector)
	var target_speed: float = run_speed if running else walk_speed
	var target_velocity: Vector3 = _target_velocity(move_direction, target_speed, aiming)
	_apply_planar_velocity(target_velocity, move_direction, delta)
	_apply_gravity(delta)
	_update_facing(move_direction, aiming, delta)
	var collided: bool = _body.move_and_slide()
	if collided and _body.is_on_floor():
		_body.velocity.y = -floor_stick_velocity


func planar_velocity() -> Vector3:
	return Vector3(_body.velocity.x, 0.0, _body.velocity.z)


func _target_velocity(
	move_direction: Vector3,
	target_speed: float,
	aiming: bool,
) -> Vector3:
	if move_direction.is_zero_approx():
		return Vector3.ZERO
	if aiming:
		return move_direction * target_speed
	var facing: Vector3 = -visual_root.global_basis.z
	var alignment: float = clampf(facing.dot(move_direction), -1.0, 1.0)
	var direction_factor: float = remap(alignment, -1.0, 1.0, reverse_speed_factor, 1.0)
	return move_direction * target_speed * direction_factor


func _apply_planar_velocity(
	target_velocity: Vector3,
	move_direction: Vector3,
	delta: float,
) -> void:
	var current: Vector2 = Vector2(_body.velocity.x, _body.velocity.z)
	var target: Vector2 = Vector2(target_velocity.x, target_velocity.z)
	var change_rate: float = acceleration
	if target.is_zero_approx() or current.dot(Vector2(move_direction.x, move_direction.z)) < 0.0:
		change_rate = deceleration
	var next_velocity: Vector2 = current.move_toward(target, change_rate * delta)
	_body.velocity.x = next_velocity.x
	_body.velocity.z = next_velocity.y


func _apply_gravity(delta: float) -> void:
	var grounded: bool = _body.is_on_floor() or ground_check.is_colliding()
	if grounded and _body.velocity.y <= 0.0:
		_body.velocity.y = -floor_stick_velocity
	else:
		_body.velocity.y -= gravity * delta


func _update_facing(move_direction: Vector3, aiming: bool, delta: float) -> void:
	var facing_direction: Vector3 = camera_rig.planar_forward() if aiming else move_direction
	if facing_direction.length_squared() < 0.01:
		return
	var target_yaw: float = atan2(-facing_direction.x, -facing_direction.z)
	var weight: float = 1.0 - exp(-rotation_speed * delta)
	visual_root.rotation.y = lerp_angle(visual_root.rotation.y, target_yaw, weight)
