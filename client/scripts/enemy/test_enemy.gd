class_name TestEnemy
extends StaticBody3D

enum LifeState {
	ALIVE,
	DYING,
}

@export var max_health: float = 100.0
@export var death_duration: float = 0.65

var _health: float = 100.0
var _life_state: LifeState = LifeState.ALIVE
var _visual_scale: Vector3 = Vector3.ONE

@onready var _health_bar: Node3D = $HealthBar
@onready var _health_fill: MeshInstance3D = $HealthBar/Fill
@onready var _body: MeshInstance3D = $Body
@onready var _collision_shape: CollisionShape3D = $CollisionShape3D


func _ready() -> void:
	_health = max_health


func take_damage(amount: float, _point: Vector3, _normal: Vector3) -> void:
	if _life_state != LifeState.ALIVE:
		return
	_health = maxf(_health - amount, 0.0)
	_update_health_bar()
	_visual_scale = Vector3(1.16, 0.84, 1.16)
	if is_zero_approx(_health):
		_start_death()


func _process(delta: float) -> void:
	_body.scale = _body.scale.lerp(_visual_scale, minf(delta * 18.0, 1.0))
	_visual_scale = _visual_scale.lerp(Vector3.ONE, minf(delta * 8.0, 1.0))


func _update_health_bar() -> void:
	var health_ratio: float = _health / max_health
	_health_fill.scale.x = health_ratio
	_health_fill.position.x = -0.58 * (1.0 - health_ratio)


func _start_death() -> void:
	_life_state = LifeState.DYING
	_collision_shape.set_deferred("disabled", true)
	_health_bar.visible = false
	var tween: Tween = create_tween()
	tween = tween.set_parallel(true)
	_keep_tweener(tween.tween_property(_body, "scale", Vector3(1.2, 0.08, 1.2), death_duration))
	_keep_tweener(tween.tween_property(_body, "transparency", 1.0, death_duration))
	tween = tween.set_parallel(false)
	_keep_tweener(tween.tween_callback(queue_free))


func _keep_tweener(tweener: Tweener) -> void:
	assert(is_instance_valid(tweener))
