extends Node2D

var launchpad_size: Vector2 = Vector2(100, 20)
var is_active: bool = false
var blink_timer: float = 0.0
var blink_phase: int = 0  # 0 = white, 1 = black
var protection_radius: float = 240.0
var arc_color: Color = Color(0.996, 0.686, 0.204, 0.3)
var arc_visible: bool = false
var arc_visibility_timer: float = 0.0
var arc_fade_time: float = 0.5
var detection_radius: float = 400.0
var wave_time: float = 0.0

func _ready() -> void:
	add_to_group("launchpad")

func _process(delta: float) -> void:
	wave_time += delta
	
	# Only update blink if active
	if is_active:
		blink_timer += delta
		if blink_timer >= 0.3:
			blink_timer = 0.0
			blink_phase = 1 - blink_phase  # Toggle between 0 and 1
			queue_redraw()
	
	# Check for asteroids
	var asteroids_nearby = false
	for asteroid in get_tree().get_nodes_in_group("asteroids"):
		if is_instance_valid(asteroid):
			if global_position.distance_to(asteroid.global_position) < detection_radius:
				asteroids_nearby = true
				break
	
	# Update arc visibility
	if asteroids_nearby:
		if not arc_visible:
			arc_visible = true
			queue_redraw()
		arc_visibility_timer = arc_fade_time
	else:
		arc_visibility_timer -= delta
		if arc_visibility_timer <= 0 and arc_visible:
			arc_visible = false
			arc_visibility_timer = 0
			queue_redraw()
	
	if arc_visible:
		queue_redraw()

func _draw() -> void:
	# Draw arc if visible
	if arc_visible:
		var alpha = min(1.0, arc_visibility_timer / 0.2)
		var current_color = Color(arc_color.r, arc_color.g, arc_color.b, arc_color.a * alpha)
		draw_animated_arc(Vector2.ZERO, protection_radius, -PI, 0, current_color, 3.0)
	
	# Draw launchpad
	var rect = Rect2(-launchpad_size.x / 2, -launchpad_size.y / 2, launchpad_size.x, launchpad_size.y)
	
	# Simple logic: golden yellow when not active, blink when active
	if not is_active:
		draw_rect(rect, Color(0.996, 0.686, 0.204))
	else:
		var color = Color(0.996, 0.686, 0.204) if blink_phase == 0 else Color(0.086, 0, 0.208)
		draw_rect(rect, color)
	
	# Border
	draw_rect(rect, Color(0.996, 0.686, 0.204), false, 2.0)

func activate() -> void:
	if not is_active:
		is_active = true
		blink_timer = 0.0
		blink_phase = 0
		queue_redraw()

func deactivate() -> void:
	if is_active:
		is_active = false
		blink_phase = 0  # Reset to white
		blink_timer = 0.0
		queue_redraw()

func is_spaceship_on_pad(spaceship_pos: Vector2) -> bool:
	var local_pos = spaceship_pos - global_position
	return abs(local_pos.x) <= 70 and abs(local_pos.y) <= 50

func check_asteroid_collision(asteroid_pos: Vector2, asteroid_radius: float) -> Dictionary:
	var distance = asteroid_pos.distance_to(global_position)
	var to_asteroid = asteroid_pos - global_position
	var angle = to_asteroid.angle()
	
	if angle >= -PI and angle <= 0 and distance - asteroid_radius <= protection_radius:
		return {
			"collided": true,
			"normal": to_asteroid.normalized(),
			"overlap": protection_radius - (distance - asteroid_radius) + 5
		}
	
	return {"collided": false}

func draw_animated_arc(center: Vector2, radius: float, start_angle: float, end_angle: float, color: Color, width: float) -> void:
	var points = []
	var segments = 50
	
	for i in range(segments + 1):
		var t = float(i) / float(segments)
		var angle = lerp(start_angle, end_angle, t)
		var squiggle = sin(angle * 6.0 + wave_time * 2.0) * 3.5
		squiggle += sin(angle * 4.2 - wave_time * 2.6) * 1.75
		var end_factor = 1.0 - pow(abs(t - 0.5) * 2.0, 2.0)
		squiggle *= end_factor
		
		var point_radius = radius + squiggle
		var point = center + Vector2(cos(angle), sin(angle)) * point_radius
		points.append(point)
	
	for i in range(points.size() - 1):
		draw_line(points[i], points[i + 1], color, width)