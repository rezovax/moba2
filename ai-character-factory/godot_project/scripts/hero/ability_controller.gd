class_name AbilityController
extends Node

var animation_controller: HeroAnimationController


func configure(controller: HeroAnimationController) -> void:
	animation_controller = controller


func cast(slot: int) -> bool:
	if animation_controller == null or slot < 0 or slot > 3:
		return false
	var contract_name: String = "cast_ultimate" if slot == 3 else "cast_%02d" % (slot + 1)
	return animation_controller.play_contract(contract_name)
