extends Node2D

const RADIUS: float = 46.0
const MAX_SPEED: float = 520.0
const ACCELERATION: float = 1650.0
const FRICTION: float = 2100.0
const SIDE_MARGIN: float = 64.0
const BALL_COLOR: Color = Color("ffca57")
const BALL_SHADE: Color = Color("d97941")
const BALL_DETAIL: Color = Color("fff0bd")

var _horizontal_speed: float = 0.0


func _ready() -> void:
	queue_redraw()


func _physics_process(delta: float) -> void:
	var direction: float = Input.get_axis("move_left", "move_right")
	var change_rate: float = FRICTION
	if not is_zero_approx(direction):
		change_rate = ACCELERATION
	var target_speed: float = direction * MAX_SPEED
	_horizontal_speed = move_toward(_horizontal_speed, target_speed, change_rate * delta)
	_move_ball(delta)


func _draw() -> void:
	draw_circle(Vector2.ZERO, RADIUS + 7.0, Color(0.0, 0.0, 0.0, 0.2))
	draw_circle(Vector2.ZERO, RADIUS, BALL_SHADE)
	draw_circle(Vector2(-8.0, -9.0), RADIUS - 6.0, BALL_COLOR)
	draw_arc(Vector2.ZERO, RADIUS - 12.0, -1.1, 1.1, 24, BALL_DETAIL, 7.0)
	draw_line(Vector2(-RADIUS + 9.0, 0.0), Vector2(RADIUS - 9.0, 0.0), BALL_DETAIL, 6.0)
	draw_circle(Vector2.ZERO, 8.0, BALL_DETAIL)


func _move_ball(delta: float) -> void:
	var left_limit: float = SIDE_MARGIN + RADIUS
	var right_limit: float = get_viewport_rect().size.x - SIDE_MARGIN - RADIUS
	var travel: float = _horizontal_speed * delta
	var next_x: float = clampf(position.x + travel, left_limit, right_limit)
	var actual_travel: float = next_x - position.x
	position.x = next_x
	rotation += actual_travel / RADIUS
	if not is_equal_approx(actual_travel, travel):
		_horizontal_speed = 0.0
