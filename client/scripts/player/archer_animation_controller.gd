class_name ArcherAnimationController
extends AnimationTree

const ANIMATION_BLEND_RATE: float = 10.0

var _walk_speed: float = 2.4
var _run_speed: float = 5.8
var _locomotion_blend: Vector2 = Vector2.ZERO


func _ready() -> void:
	_configure_locomotion_loops()
	_configure_tree()


func configure_speeds(walk_speed: float, run_speed: float) -> void:
	_walk_speed = walk_speed
	_run_speed = run_speed
	_configure_tree()


func update_locomotion(planar_velocity: Vector3, visual_basis: Basis, delta: float) -> void:
	var local_velocity: Vector3 = visual_basis.inverse() * planar_velocity
	var target_blend: Vector2 = Vector2(local_velocity.x, -local_velocity.z) / _run_speed
	_locomotion_blend = (
		_locomotion_blend
		. lerp(
			target_blend.limit_length(1.0),
			minf(delta * ANIMATION_BLEND_RATE, 1.0),
		)
	)
	set("parameters/Locomotion/blend_position", _locomotion_blend)


func play_attack() -> void:
	set(
		"parameters/Attack/request",
		AnimationNodeOneShot.ONE_SHOT_REQUEST_FIRE,
	)


func _configure_locomotion_loops() -> void:
	var animation_player: AnimationPlayer = get_node(anim_player) as AnimationPlayer
	var animation_names: Array[StringName] = [
		&"Idle",
		&"Walk",
		&"Run",
		&"Run_Back",
		&"Run_Left",
		&"Run_Right",
	]
	for animation_name: StringName in animation_names:
		var animation: Animation = animation_player.get_animation(animation_name)
		if animation != null:
			animation.loop_mode = Animation.LOOP_LINEAR


func _configure_tree() -> void:
	var blend_tree: AnimationNodeBlendTree = AnimationNodeBlendTree.new()
	var locomotion: AnimationNodeBlendSpace2D = _create_locomotion_blend()
	var attack: AnimationNodeAnimation = _animation_node(&"Idle_Gun_Shoot")
	var one_shot: AnimationNodeOneShot = AnimationNodeOneShot.new()
	one_shot.fadein_time = 0.08
	one_shot.fadeout_time = 0.14
	blend_tree.add_node("Locomotion", locomotion, Vector2(0.0, 80.0))
	blend_tree.add_node("AttackAnimation", attack, Vector2(0.0, 220.0))
	blend_tree.add_node("Attack", one_shot, Vector2(260.0, 100.0))
	blend_tree.connect_node("Attack", 0, "Locomotion")
	blend_tree.connect_node("Attack", 1, "AttackAnimation")
	blend_tree.connect_node("output", 0, "Attack")
	tree_root = blend_tree
	active = true


func _create_locomotion_blend() -> AnimationNodeBlendSpace2D:
	var locomotion: AnimationNodeBlendSpace2D = AnimationNodeBlendSpace2D.new()
	locomotion.min_space = Vector2(-1.0, -1.0)
	locomotion.max_space = Vector2(1.0, 1.0)
	locomotion.sync = true
	var walk_ratio: float = _walk_speed / _run_speed
	locomotion.add_blend_point(_animation_node(&"Idle"), Vector2.ZERO, -1, &"idle")
	(
		locomotion
		. add_blend_point(
			_animation_node(&"Walk"),
			Vector2(0.0, walk_ratio),
			-1,
			&"walk",
		)
	)
	locomotion.add_blend_point(_animation_node(&"Run"), Vector2(0.0, 1.0), -1, &"run")
	locomotion.add_blend_point(_animation_node(&"Run_Back"), Vector2(0.0, -1.0), -1, &"back")
	locomotion.add_blend_point(_animation_node(&"Run_Left"), Vector2(-1.0, 0.0), -1, &"left")
	locomotion.add_blend_point(_animation_node(&"Run_Right"), Vector2(1.0, 0.0), -1, &"right")
	return locomotion


func _animation_node(animation_name: StringName) -> AnimationNodeAnimation:
	var animation: AnimationNodeAnimation = AnimationNodeAnimation.new()
	animation.animation = animation_name
	return animation
