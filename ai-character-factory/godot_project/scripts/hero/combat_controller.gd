class_name CombatController
extends Node

var animation_controller: HeroAnimationController


func configure(controller: HeroAnimationController) -> void:
	animation_controller = controller


func attack() -> bool:
	if animation_controller == null:
		return false
	return animation_controller.play_contract("attack_01")


func react_to_hit() -> bool:
	if animation_controller == null:
		return false
	return animation_controller.play_contract("hit")


func die() -> bool:
	if animation_controller == null:
		return false
	return animation_controller.play_contract("death")
