class_name ArcherPlayer
extends CharacterBody3D

@onready var _input: ArcherInput = $ArcherInput
@onready var _motor: ArcherMotor = $ArcherMotor
@onready var _camera_rig: ArcherCameraRig = $CameraRig
@onready var _animation: ArcherAnimationController = $VisualRoot/AnimationTree
@onready var _weapon: ArcherWeaponController = $ArcherWeaponController
@onready var _visual_root: Node3D = $VisualRoot


func _ready() -> void:
	_animation.configure_speeds(_motor.walk_speed, _motor.run_speed)


func _physics_process(delta: float) -> void:
	_input.sample()
	_weapon.tick(delta)
	if _input.wants_shoot:
		_weapon.try_attack()
	var aiming: bool = _input.wants_aim or _weapon.is_busy()
	_camera_rig.set_aiming(aiming)
	_motor.physics_step(_input.movement, _input.wants_run, aiming, delta)
	_animation.update_locomotion(_motor.planar_velocity(), _visual_root.global_basis, delta)
