class_name ArcherArrow
extends CharacterBody3D

@export var default_speed: float = 32.0
@export var default_damage: float = 25.0
@export var lifetime: float = 5.0
@export var impact_scene: PackedScene

var _damage: float = 25.0
var _age: float = 0.0
var _is_launched: bool = false


func launch(
	direction: Vector3,
	shooter: PhysicsBody3D,
	launch_speed: float = 0.0,
	launch_damage: float = 0.0,
) -> void:
	add_collision_exception_with(shooter)
	var resolved_speed: float = default_speed
	var resolved_damage: float = default_damage
	if launch_speed > 0.0:
		resolved_speed = launch_speed
	if launch_damage > 0.0:
		resolved_damage = launch_damage
	_damage = resolved_damage
	velocity = direction * resolved_speed
	look_at(global_position + direction, Vector3.UP)
	_is_launched = true


func _physics_process(delta: float) -> void:
	_age += delta
	if _age >= lifetime:
		queue_free()
		return
	if not _is_launched:
		return
	var collision: KinematicCollision3D = move_and_collide(velocity * delta)
	if collision != null:
		_handle_impact(collision)


func _handle_impact(collision: KinematicCollision3D) -> void:
	var collider: Object = collision.get_collider()
	var point: Vector3 = collision.get_position()
	var normal: Vector3 = collision.get_normal()
	if collider.has_method(&"take_damage"):
		collider.call(&"take_damage", _damage, point, normal)
	_spawn_impact(point, normal)
	queue_free()


func _spawn_impact(point: Vector3, normal: Vector3) -> void:
	if impact_scene == null:
		return
	var impact: Node3D = impact_scene.instantiate() as Node3D
	if impact == null:
		push_error("The configured impact scene must create a Node3D.")
		return
	get_parent().add_child(impact)
	impact.global_position = point + normal * 0.03
	var look_up: Vector3 = Vector3.UP
	if absf(normal.dot(look_up)) > 0.98:
		look_up = Vector3.FORWARD
	impact.look_at(point + normal, look_up)
