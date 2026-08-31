class_name ArrowImpact
extends Node3D

@export var lifetime: float = 0.28

@onready var _flash: MeshInstance3D = $Flash
@onready var _light: OmniLight3D = $OmniLight3D


func _ready() -> void:
	var tween: Tween = create_tween()
	tween = tween.set_parallel(true)
	_keep_tweener(tween.tween_property(_flash, "scale", Vector3.ONE * 2.4, lifetime))
	_keep_tweener(tween.tween_property(_flash, "transparency", 1.0, lifetime))
	_keep_tweener(tween.tween_property(_light, "light_energy", 0.0, lifetime))
	tween = tween.set_parallel(false)
	_keep_tweener(tween.tween_callback(queue_free))


func _keep_tweener(tweener: Tweener) -> void:
	assert(is_instance_valid(tweener))
