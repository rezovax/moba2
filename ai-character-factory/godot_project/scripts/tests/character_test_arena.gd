extends Node3D

const STEP_DELAY: float = 0.5
const DEATH_DELAY: float = 1.0

var hero: HeroBase
var capture_dir: String = ""

@onready var camera: Camera3D = $Camera3D


func _ready() -> void:
	capture_dir = OS.get_environment("FACTORY_CAPTURE_DIR")
	var scene_path: String = OS.get_environment("FACTORY_HERO_SCENE")
	if scene_path.is_empty():
		scene_path = "res://generated/test_hero/test_hero.tscn"
	var packed_scene: PackedScene = load(scene_path) as PackedScene
	if packed_scene == null:
		_fail("cannot load hero scene: %s" % scene_path)
		return
	hero = packed_scene.instantiate() as HeroBase
	if hero == null:
		_fail("generated scene root is not HeroBase")
		return
	add_child(hero)
	camera.look_at_from_position(Vector3(2.8, 2.8, 4.0), Vector3(0.0, 0.9, 0.0))
	_run_sequence()


func _run_sequence() -> void:
	await get_tree().create_timer(STEP_DELAY).timeout
	_capture("idle")
	hero.set_move_input(Vector3(0.0, 0.0, -0.25))
	await get_tree().create_timer(STEP_DELAY).timeout
	_capture("run")
	hero.set_move_input(Vector3.ZERO)
	_assert_action(hero.attack(), "attack")
	await get_tree().create_timer(STEP_DELAY).timeout
	_capture("attack")
	_assert_action(hero.cast_ability(0), "cast")
	await get_tree().create_timer(STEP_DELAY).timeout
	_capture("cast")
	hero.apply_damage(10.0)
	await get_tree().create_timer(STEP_DELAY).timeout
	_capture("hit")
	hero.apply_damage(10000.0)
	await get_tree().create_timer(DEATH_DELAY).timeout
	_capture("death")
	print("CHARACTER_TEST_PASS idle run attack cast hit death")
	get_tree().quit(0)


func _assert_action(success: bool, action: String) -> void:
	if not success:
		_fail("animation contract failed: %s" % action)


func _capture(stage: String) -> void:
	if capture_dir.is_empty() or DisplayServer.get_name() == "headless":
		return
	DirAccess.make_dir_recursive_absolute(capture_dir)
	var image: Image = get_viewport().get_texture().get_image()
	var error: Error = image.save_png(capture_dir.path_join("godot_%s.png" % stage))
	if error != OK:
		push_warning("Screenshot failed for %s: %s" % [stage, error_string(error)])


func _fail(message: String) -> void:
	push_error("CHARACTER_TEST_FAIL %s" % message)
	get_tree().quit(1)
