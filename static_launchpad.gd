extends Node2D

var launchpad_size: Vector2 = Vector2(100, 20)
var protection_radius: float = 240.0
var arc_color: Color = Color(0.996, 0.686, 0.204, 0.3)
var arc_visible: bool = false
var arc_visibility_timer: float = 0.0
var arc_fade_time: float = 0.5
var detection_radius: float = 400.0
var wave_time: float = 0.0

# Blinking overlay
var blink_overlay: Node2D = null
var is_active: bool = false

func _ready() -> void:
	add_to_group("launchpad")
	
	# Create blinking overlay as child
	blink_overlay = Node2D.new()
	blink_overlay.name = "BlinkOverlay"
	blink_overlay.visible = false
	blink_overlay.z_index = 1
	add_child(blink_overlay)
	
	# Give the overlay its own script
	var overlay_script = GDScript.new()
	overlay_script.source_code = """
extends Node2D

var blink_timer: float = 0.0
var blink_on: bool = true

func _process(delta: float) -> void:
	if visible:
		blink_timer += delta
		if blink_timer >= 0.3:
			blink_timer = 0.0
			blink_on = not blink_on
			queue_redraw()

func _draw() -> void:
	if visible:
		var color = Color(0.996, 0.686, 0.204) if blink_on else Color(0.086, 0, 0.208)
		var rect = Rect2(-50, -10, 100, 20)
		draw_rect(rect, color)
"""
	overlay_script.reload()
	blink_overlay.set_script(overlay_script)

func _process(delta: float) -> void:
	wave_time += delta
	
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
	
	# Always draw base launchpad as golden yellow
	var rect = Rect2(-launchpad_size.x / 2, -launchpad_size.y / 2, launchpad_size.x, launchpad_size.y)
	draw_rect(rect, Color(0.996, 0.686, 0.204))
	draw_rect(rect, Color(0.996, 0.686, 0.204), false, 2.0)

func activate() -> void:
	is_active = true
	if blink_overlay:
		blink_overlay.visible = true
		blink_overlay.set("blink_timer", 0.0)
		blink_overlay.set("blink_on", true)

func deactivate() -> void:
	is_active = false
	if blink_overlay:
		blink_overlay.visible = false

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