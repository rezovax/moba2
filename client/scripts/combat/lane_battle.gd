extends Node3D

const CREEPS_PER_WAVE: int = 3
const ROW_SPACING: float = 1.15
const RADIANT_SPAWN_X: float = -8.1
const DIRE_SPAWN_X: float = 8.1
const RETARGET_INTERVAL: float = 0.2

@export var creep_scene: PackedScene

var _radiant_army: Array[LaneCreep] = []
var _dire_army: Array[LaneCreep] = []
var _wave_number: int = 0
var _retarget_cooldown: float = 0.0
var _displayed_seconds: int = -1

@onready var _radiant_creeps: Node3D = $RadiantCreeps
@onready var _dire_creeps: Node3D = $DireCreeps
@onready var _wave_timer: Timer = $WaveTimer
@onready var _wave_label: Label = $LaneHud/Layout/WaveLabel


func _ready() -> void:
	if creep_scene == null:
		push_error("LaneBattle requires a creep scene.")
		return
	_spawn_wave()
	_update_hud()


func _physics_process(delta: float) -> void:
	_retarget_cooldown -= delta
	if _retarget_cooldown > 0.0:
		return
	_retarget_cooldown = RETARGET_INTERVAL
	_retarget_armies()


func _process(_delta: float) -> void:
	var seconds_left: int = ceili(_wave_timer.time_left)
	if seconds_left == _displayed_seconds:
		return
	_displayed_seconds = seconds_left
	_update_hud()


func _on_wave_timer_timeout() -> void:
	_spawn_wave()


func _spawn_wave() -> void:
	_wave_number += 1
	for row_index: int in range(CREEPS_PER_WAVE):
		var row_z: float = (float(row_index) - 1.0) * ROW_SPACING
		_spawn_creep(LaneCreep.Team.RADIANT, Vector3(RADIANT_SPAWN_X, 0.0, row_z))
		_spawn_creep(LaneCreep.Team.DIRE, Vector3(DIRE_SPAWN_X, 0.0, row_z))
	_retarget_armies()
	_update_hud()


func _spawn_creep(creep_team: LaneCreep.Team, spawn_position: Vector3) -> void:
	var creep: LaneCreep = creep_scene.instantiate() as LaneCreep
	if creep == null:
		push_error("The configured creep scene must create a LaneCreep.")
		return
	var parent: Node3D = _radiant_creeps
	var direction: float = 1.0
	if creep_team == LaneCreep.Team.DIRE:
		parent = _dire_creeps
		direction = -1.0
	parent.add_child(creep)
	creep.position = spawn_position
	creep.setup(creep_team, direction)
	_register_creep(creep)


func _register_creep(creep: LaneCreep) -> void:
	if creep.team == LaneCreep.Team.RADIANT:
		_radiant_army.append(creep)
	else:
		_dire_army.append(creep)
	var connection_error: Error = creep.defeated.connect(_on_creep_defeated) as Error
	if connection_error != OK:
		push_error("Could not connect creep defeat signal.")


func _on_creep_defeated(creep: LaneCreep) -> void:
	_radiant_army.erase(creep)
	_dire_army.erase(creep)
	creep.queue_free()
	_retarget_armies()


func _retarget_armies() -> void:
	_assign_targets(_radiant_army, _dire_army)
	_assign_targets(_dire_army, _radiant_army)


func _assign_targets(army: Array[LaneCreep], enemies: Array[LaneCreep]) -> void:
	for creep: LaneCreep in army:
		creep.assign_target(_find_closest_enemy(creep, enemies))


func _find_closest_enemy(creep: LaneCreep, enemies: Array[LaneCreep]) -> LaneCreep:
	var closest_enemy: LaneCreep = null
	var closest_distance: float = INF
	for enemy: LaneCreep in enemies:
		var distance: float = creep.global_position.distance_squared_to(enemy.global_position)
		if distance < closest_distance:
			closest_distance = distance
			closest_enemy = enemy
	return closest_enemy


func _update_hud() -> void:
	var seconds_left: int = ceili(_wave_timer.time_left)
	_wave_label.text = "ВОЛНА %d  ·  СЛЕДУЮЩАЯ ЧЕРЕЗ %d" % [_wave_number, seconds_left]
