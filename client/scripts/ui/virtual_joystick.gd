class_name ConceptJoystick
extends Control

const OUTER_RADIUS: float = 76.0
const KNOB_RADIUS: float = 30.0
const IDLE_COLOR: Color = Color(0.25, 0.54, 0.74, 0.28)
const ACTIVE_COLOR: Color = Color(0.35, 0.78, 1.0, 0.55)
const KNOB_COLOR: Color = Color(0.65, 0.9, 1.0, 0.9)

var _direction: Vector2 = Vector2.ZERO
var _touch_index: int = -1
var _mouse_active: bool = false


func direction() -> Vector2:
	return _direction


func _draw() -> void:
	var center: Vector2 = size * 0.5
	var outer_color: Color = ACTIVE_COLOR if not _direction.is_zero_approx() else IDLE_COLOR
	draw_circle(center, OUTER_RADIUS, outer_color)
	draw_circle(center + _direction * OUTER_RADIUS, KNOB_RADIUS, KNOB_COLOR)


func _gui_input(event: InputEvent) -> void:
	if event is InputEventScreenTouch:
		_handle_touch(event as InputEventScreenTouch)
	elif event is InputEventScreenDrag:
		_handle_drag(event as InputEventScreenDrag)
	elif event is InputEventMouseButton:
		_handle_mouse_button(event as InputEventMouseButton)
	elif event is InputEventMouseMotion:
		_handle_mouse_motion(event as InputEventMouseMotion)


func _handle_touch(event: InputEventScreenTouch) -> void:
	if event.pressed and _touch_index == -1:
		_touch_index = event.index
		_set_direction(event.position)
	elif not event.pressed and event.index == _touch_index:
		_release_touch()


func _handle_drag(event: InputEventScreenDrag) -> void:
	if event.index == _touch_index:
		_set_direction(event.position)


func _handle_mouse_button(event: InputEventMouseButton) -> void:
	if event.button_index != MOUSE_BUTTON_LEFT:
		return
	_mouse_active = event.pressed
	if _mouse_active:
		_set_direction(event.position)
	else:
		_clear_direction()


func _handle_mouse_motion(event: InputEventMouseMotion) -> void:
	if _mouse_active:
		_set_direction(event.position)


func _set_direction(local_position: Vector2) -> void:
	var offset: Vector2 = local_position - size * 0.5
	_direction = offset.limit_length(OUTER_RADIUS) / OUTER_RADIUS
	queue_redraw()


func _release_touch() -> void:
	_touch_index = -1
	_clear_direction()


func _clear_direction() -> void:
	_direction = Vector2.ZERO
	queue_redraw()
