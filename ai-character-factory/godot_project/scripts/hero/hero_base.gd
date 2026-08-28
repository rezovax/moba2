class_name HeroBase
extends CharacterBody3D

@export var stats: HeroStats

@onready var visual_root: Node3D = $VisualRoot
@onready var motor: HeroMotor = $HeroMotor
@onready var health: HealthComponent = $Combat/HealthComponent
@onready var combat: CombatController = $Combat/CombatController
@onready var abilities: AbilityController = $Abilities/AbilityController
@onready var animations: HeroAnimationController = $AnimationController


func _ready() -> void:
	if stats == null:
		stats = HeroStats.new()
	motor.configure(stats.move_speed)
	health.configure(stats.max_health)
	combat.configure(animations)
	abilities.configure(animations)
	health.damaged.connect(_on_damaged)
	health.died.connect(_on_died)
	animations.configure(visual_root)


func _physics_process(delta: float) -> void:
	motor.tick(self, delta)


func set_move_input(value: Vector3) -> void:
	motor.set_move_input(value)
	animations.play_contract("run" if not value.is_zero_approx() else "idle")


func attack() -> bool:
	return combat.attack()


func cast_ability(slot: int) -> bool:
	return abilities.cast(slot)


func apply_damage(amount: float) -> void:
	health.apply_damage(amount)


func _on_damaged(_amount: float) -> void:
	combat.react_to_hit()


func _on_died() -> void:
	motor.set_move_input(Vector3.ZERO)
	combat.die()
