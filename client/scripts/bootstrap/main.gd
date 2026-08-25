extends Node2D

const BACKGROUND: Color = Color("071024")
const GRID: Color = Color("17345b")
const CYAN: Color = Color("41d9ff")
const MAGENTA: Color = Color("ff4fa3")
const TEXT: Color = Color("d8f6ff")

var _elapsed_seconds: float = 0.0


func _ready() -> void:
	get_window().title = "MOBA2 · Development Arena"
	queue_redraw()


func _process(delta: float) -> void:
	_elapsed_seconds += delta
	queue_redraw()


func _draw() -> void:
	var viewport_size: Vector2 = get_viewport_rect().size
	draw_rect(Rect2(Vector2.ZERO, viewport_size), BACKGROUND)
	_draw_grid(viewport_size)
	_draw_arena(viewport_size * 0.5)
	_draw_header(viewport_size)


func _draw_grid(viewport_size: Vector2) -> void:
	var spacing: float = 48.0
	var x: float = 0.0
	while x <= viewport_size.x:
		draw_line(Vector2(x, 0.0), Vector2(x, viewport_size.y), GRID, 1.0)
		x += spacing
	var y: float = 0.0
	while y <= viewport_size.y:
		draw_line(Vector2(0.0, y), Vector2(viewport_size.x, y), GRID, 1.0)
		y += spacing


func _draw_arena(center: Vector2) -> void:
	var pulse: float = (sin(_elapsed_seconds * 2.0) + 1.0) * 0.5
	var lane_width: float = 118.0 + pulse * 5.0
	draw_circle(center, 248.0, Color("0b1b35"))
	draw_arc(center, 250.0, 0.0, TAU, 96, CYAN, 3.0)
	draw_arc(center, lane_width, 0.0, TAU, 72, Color(CYAN, 0.35), 2.0)
	draw_line(center + Vector2(-390.0, 0.0), center + Vector2(390.0, 0.0), Color(CYAN, 0.45), 5.0)
	draw_line(
		center + Vector2(0.0, -250.0), center + Vector2(0.0, 250.0), Color(MAGENTA, 0.35), 3.0
	)
	_draw_core(center + Vector2(-390.0, 0.0), CYAN)
	_draw_core(center + Vector2(390.0, 0.0), MAGENTA)
	_draw_player(center, pulse)


func _draw_core(core_position: Vector2, color: Color) -> void:
	draw_circle(core_position, 56.0, Color(color, 0.14))
	draw_circle(core_position, 35.0, Color(color, 0.35))
	draw_arc(core_position, 56.0, 0.0, TAU, 48, color, 4.0)
	draw_circle(core_position, 13.0, color)


func _draw_player(center: Vector2, pulse: float) -> void:
	var radius: float = 24.0 + pulse * 3.0
	var points: PackedVector2Array = PackedVector2Array(
		[
			center + Vector2(0.0, -radius),
			center + Vector2(radius, 0.0),
			center + Vector2(0.0, radius),
			center + Vector2(-radius, 0.0),
		]
	)
	draw_colored_polygon(points, TEXT)
	draw_arc(center, 47.0 + pulse * 4.0, 0.0, TAU, 40, Color(TEXT, 0.45), 3.0)


func _draw_header(viewport_size: Vector2) -> void:
	var font: Font = ThemeDB.fallback_font
	var title_position: Vector2 = Vector2(44.0, 58.0)
	draw_string(font, title_position, "MOBA2", HORIZONTAL_ALIGNMENT_LEFT, -1.0, 34, TEXT)
	draw_string(
		font,
		title_position + Vector2(0.0, 31.0),
		"DEVELOPMENT ARENA  ·  GODOT 4.7  ·  SYSTEMS ONLINE",
		HORIZONTAL_ALIGNMENT_LEFT,
		-1.0,
		16,
		CYAN,
	)
	var status: String = "CLIENT BOOTSTRAP   |   60 FPS TARGET   |   SERVER: LATER"
	draw_string(
		font,
		Vector2(44.0, viewport_size.y - 42.0),
		status,
		HORIZONTAL_ALIGNMENT_LEFT,
		-1.0,
		15,
		Color(TEXT, 0.75),
	)
