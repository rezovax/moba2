class_name HeroAnimationController
extends AnimationTree

signal contract_ready
signal animation_missing(contract_name: String, source_name: String)

@export var animation_map: Dictionary[String, String] = {}
@export var loop_map: Dictionary[String, bool] = {}

var animation_player: AnimationPlayer
var playback: AnimationNodeStateMachinePlayback


func configure(visual_root: Node) -> void:
	animation_player = _find_animation_player(visual_root)
	if animation_player == null:
		push_error("Character asset has no AnimationPlayer")
		return
	_build_state_machine()
	call_deferred("_activate_tree")


func play_contract(contract_name: String) -> bool:
	if playback == null or not animation_map.has(contract_name):
		return false
	playback.travel(contract_name)
	return true


func has_contract(contract_name: String) -> bool:
	if animation_player == null or not animation_map.has(contract_name):
		return false
	return animation_player.has_animation(animation_map[contract_name])


func _build_state_machine() -> void:
	var state_machine: AnimationNodeStateMachine = AnimationNodeStateMachine.new()
	for contract_name: String in animation_map:
		var source_name: String = animation_map[contract_name]
		if not animation_player.has_animation(source_name):
			animation_missing.emit(contract_name, source_name)
			continue
		var animation_node: AnimationNodeAnimation = AnimationNodeAnimation.new()
		animation_node.animation = source_name
		var animation: Animation = animation_player.get_animation(source_name)
		if animation != null and loop_map.get(contract_name, false):
			animation.loop_mode = Animation.LOOP_LINEAR
		state_machine.add_node(contract_name, animation_node)
	tree_root = state_machine
	anim_player = get_path_to(animation_player)


func _activate_tree() -> void:
	active = true
	playback = get("parameters/playback") as AnimationNodeStateMachinePlayback
	if has_contract("idle"):
		playback.start("idle")
	contract_ready.emit()


func _find_animation_player(node: Node) -> AnimationPlayer:
	if node is AnimationPlayer:
		return node as AnimationPlayer
	for child: Node in node.get_children():
		var found: AnimationPlayer = _find_animation_player(child)
		if found != null:
			return found
	return null
