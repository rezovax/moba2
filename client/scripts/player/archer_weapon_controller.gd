class_name ArcherWeaponController
extends Node

enum AttackState {
	READY,
	WINDUP,
	RECOVERY,
}

@export_category("Timing")
@export var attack_windup: float = 0.28
@export var attack_recovery: float = 0.38
@export var attack_rate: float = 0.72
@export_category("Projectile")
@export var projectile_speed: float = 32.0
@export var projectile_damage: float = 25.0
@export var arrow_scene: PackedScene
@export_category("References")
@export var arrow_spawn: Marker3D
@export var camera_rig: ArcherCameraRig
@export var animation_controller: ArcherAnimationController
@export var legacy_weapon: MeshInstance3D

var _state: AttackState = AttackState.READY
var _timer: float = 0.0

@onready var _character: CharacterBody3D = get_parent() as CharacterBody3D


func _ready() -> void:
	legacy_weapon.visible = false
	if arrow_scene == null:
		push_error("ArcherWeaponController requires an arrow scene.")


func tick(delta: float) -> void:
	if _state == AttackState.READY:
		return
	_timer -= delta
	if _timer > 0.0:
		return
	if _state == AttackState.WINDUP:
		_release_arrow()
		_state = AttackState.RECOVERY
		_timer = maxf(attack_recovery, attack_rate - attack_windup)
	else:
		_state = AttackState.READY


func try_attack() -> void:
	if _state != AttackState.READY or arrow_scene == null:
		return
	_state = AttackState.WINDUP
	_timer = attack_windup
	animation_controller.play_attack()


func is_busy() -> bool:
	return _state != AttackState.READY


func _release_arrow() -> void:
	var arrow: ArcherArrow = arrow_scene.instantiate() as ArcherArrow
	if arrow == null:
		push_error("The configured arrow scene must create an ArcherArrow.")
		return
	_character.get_parent().add_child(arrow)
	arrow.global_position = arrow_spawn.global_position
	var direction: Vector3 = (camera_rig.aim_point() - arrow.global_position).normalized()
	arrow.launch(direction, _character, projectile_speed, projectile_damage)
