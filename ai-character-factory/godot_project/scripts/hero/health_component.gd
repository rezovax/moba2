class_name HealthComponent
extends Node

signal health_changed(current: float, maximum: float)
signal damaged(amount: float)
signal died

var maximum_health: float = 100.0
var current_health: float = 100.0


func configure(value: float) -> void:
	maximum_health = maxf(value, 1.0)
	current_health = maximum_health
	health_changed.emit(current_health, maximum_health)


func apply_damage(amount: float) -> void:
	if amount <= 0.0 or current_health <= 0.0:
		return
	current_health = maxf(0.0, current_health - amount)
	damaged.emit(amount)
	health_changed.emit(current_health, maximum_health)
	if current_health == 0.0:
		died.emit()


func is_dead() -> bool:
	return current_health <= 0.0
