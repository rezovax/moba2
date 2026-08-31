class_name LaneCreep
extends Node3D

signal defeated(creep: LaneCreep)

enum Team {
	RADIANT,
	DIRE,
}

const MAX_HEALTH: float = 100.0
const MOVE_SPEED: float = 1.6
const ATTACK_RANGE: float = 1.15
const ATTACK_DAMAGE: float = 25.0
const ATTACK_INTERVAL: float = 0.8
const RADIANT_COLOR: Color = Color("54c9c0")
const DIRE_COLOR: Color = Color("db6269")

var team: Team = Team.RADIANT
var _health: float = MAX_HEALTH
var _move_direction: float = 1.0
var _attack_cooldown: float = 0.0
var _target: LaneCreep = null
var _is_defeated: bool = false

@onready var _body: MeshInstance3D = $Body
@onready var _health_fill: MeshInstance3D = $HealthBar/Fill


func setup(creep_team: Team, move_direction: float) -> void:
	team = creep_team
	_move_direction = move_direction
	_apply_team_color()
	rotation.y = 0.0
	if _move_direction < 0.0:
		rotation.y = PI


func assign_target(target: LaneCreep) -> void:
	_target = target


func take_damage(amount: float) -> void:
	if _is_defeated:
		return
	_health = maxf(_health - amount, 0.0)
	_update_health_bar()
	if is_zero_approx(_health):
		_is_defeated = true
		defeated.emit(self)


func is_defeated() -> bool:
	return _is_defeated


func _physics_process(delta: float) -> void:
	_attack_cooldown = maxf(_attack_cooldown - delta, 0.0)
	if _can_attack_target():
		_attack_target()
		return
	position.x += _move_direction * MOVE_SPEED * delta


func _process(delta: float) -> void:
	_body.scale = _body.scale.lerp(Vector3.ONE, minf(delta * 9.0, 1.0))


func _can_attack_target() -> bool:
	if not is_instance_valid(_target):
		return false
	if _target.is_defeated():
		return false
	return global_position.distance_to(_target.global_position) <= ATTACK_RANGE


func _attack_target() -> void:
	if _attack_cooldown > 0.0:
		return
	_attack_cooldown = ATTACK_INTERVAL
	_body.scale = Vector3(1.18, 0.86, 1.18)
	_target.take_damage(ATTACK_DAMAGE)


func _apply_team_color() -> void:
	var body_color: Color = RADIANT_COLOR
	if team == Team.DIRE:
		body_color = DIRE_COLOR
	var body_material: StandardMaterial3D = StandardMaterial3D.new()
	body_material.albedo_color = body_color
	body_material.metallic = 0.12
	body_material.roughness = 0.62
	_body.material_override = body_material


func _update_health_bar() -> void:
	var health_ratio: float = _health / MAX_HEALTH
	_health_fill.scale.x = health_ratio
	_health_fill.position.x = -0.46 * (1.0 - health_ratio)
