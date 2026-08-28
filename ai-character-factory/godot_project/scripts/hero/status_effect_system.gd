class_name StatusEffectSystem
extends Node

var active_effects: Dictionary[String, float] = {}


func apply_status(effect_id: String, duration: float) -> void:
	if effect_id.is_empty() or duration <= 0.0:
		return
	active_effects[effect_id] = duration


func clear_status(effect_id: String) -> void:
	active_effects.erase(effect_id)


func has_status(effect_id: String) -> bool:
	return active_effects.has(effect_id)


func clear_all() -> void:
	active_effects.clear()
