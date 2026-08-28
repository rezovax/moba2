class_name TargetingSystem
extends Node

signal target_changed(target: Node3D)

var current_target: Node3D


func set_target(target: Node3D) -> void:
	current_target = target
	target_changed.emit(current_target)


func clear_target() -> void:
	current_target = null
	target_changed.emit(current_target)


func has_target() -> bool:
	return is_instance_valid(current_target)
