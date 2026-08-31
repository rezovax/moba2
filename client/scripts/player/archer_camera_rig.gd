class_name ArcherCameraRig
extends Node3D

@export_category("Target")
@export var target: Marker3D
@export var follow_sharpness: float = 18.0
@export_category("Orbit")
@export var sensitivity: float = 0.0025
@export var rotation_sharpness: float = 18.0
@export var minimum_pitch: float = -0.78
@export var maximum_pitch: float = -0.12
@export_category("Framing")
@export var normal_distance: float = 6.4
@export var aim_distance: float = 4.8
@export var normal_fov: float = 54.0
@export var aim_fov: float = 48.0

var _aiming: bool = false
var _yaw_target: float = 0.0
var _pitch_target: float = -0.42

@onready var _spring_arm: SpringArm3D = $SpringArm3D
@onready var _camera: Camera3D = $SpringArm3D/Camera3D
@onready var _aim_ray: RayCast3D = $SpringArm3D/Camera3D/AimRay


func _ready() -> void:
	top_level = true
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	_yaw_target = global_rotation.y
	_pitch_target = _spring_arm.rotation.x
	if target != null:
		global_position = target.global_position


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventMouseMotion and Input.mouse_mode == Input.MOUSE_MODE_CAPTURED:
		_update_orbit_target(event as InputEventMouseMotion)
	if event.is_action_pressed("ui_cancel"):
		Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	if event is InputEventMouseButton and event.is_pressed():
		Input.mouse_mode = Input.MOUSE_MODE_CAPTURED


func _process(delta: float) -> void:
	_follow_target(delta)
	_update_orbit(delta)
	_update_framing(delta)


func set_aiming(active: bool) -> void:
	_aiming = active


func world_direction(input_vector: Vector2) -> Vector3:
	var forward: Vector3 = planar_forward()
	var right: Vector3 = global_basis.x
	right.y = 0.0
	right = right.normalized()
	return (right * input_vector.x + forward * -input_vector.y).normalized()


func planar_forward() -> Vector3:
	var forward: Vector3 = -global_basis.z
	forward.y = 0.0
	return forward.normalized()


func aim_point() -> Vector3:
	_aim_ray.force_raycast_update()
	if _aim_ray.is_colliding():
		return _aim_ray.get_collision_point()
	return _aim_ray.to_global(_aim_ray.target_position)


func _update_orbit_target(mouse_motion: InputEventMouseMotion) -> void:
	_yaw_target -= mouse_motion.relative.x * sensitivity
	_pitch_target -= mouse_motion.relative.y * sensitivity
	_pitch_target = clampf(_pitch_target, minimum_pitch, maximum_pitch)


func _follow_target(delta: float) -> void:
	if target == null:
		return
	var weight: float = 1.0 - exp(-follow_sharpness * delta)
	global_position = global_position.lerp(target.global_position, weight)


func _update_orbit(delta: float) -> void:
	var weight: float = 1.0 - exp(-rotation_sharpness * delta)
	global_rotation.y = lerp_angle(global_rotation.y, _yaw_target, weight)
	_spring_arm.rotation.x = lerp_angle(_spring_arm.rotation.x, _pitch_target, weight)


func _update_framing(delta: float) -> void:
	var distance: float = aim_distance if _aiming else normal_distance
	var fov: float = aim_fov if _aiming else normal_fov
	var weight: float = 1.0 - exp(-rotation_sharpness * delta)
	_spring_arm.spring_length = lerpf(_spring_arm.spring_length, distance, weight)
	_camera.fov = lerpf(_camera.fov, fov, weight)
