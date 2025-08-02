extends Node2D

var launchpad_size: Vector2 = Vector2(100, 20)
var blink_timer: float = 0.0
var blink_visible: bool = true
var is_blinking: bool = false
var scored: bool = false  # Track if player has scored
var protection_radius: float = 240.0
var arc_color: Color = Color(1.0, 1.0, 1.0, 0.3)
var arc_visible: bool = false
var arc_visibility_timer: float = 0.0
var detection_radius: float = 400.0
var wave_time: float = 0.0

func _ready() -> void:
	add_to_group("launchpad")

func _process(delta: float) -> void:
	wave_time += delta
	
	# Only update blink if blinking and haven't scored
	if is_blinking and not scored:
		blink_timer += delta
		if blink_timer >= 0.3:
			blink_timer = 0.0
			blink_visible = not blink_visible
			visible = blink_visible  # Use node visibility instead of redraw
			#print("[LAUNCHPAD] Blinking: visible=", visible)
	elif scored:
		# Force visible if scored
		#print("[LAUNCHPAD] Scored state - forcing visible")
		visible = true
		is_blinking = false
	
	# Check for asteroids
	var asteroids_nearby = false
	for asteroid in get_tree().get_nodes_in_group("asteroids"):
		if is_instance_valid(asteroid) and global_position.distance_to(asteroid.global_position) < detection_radius:
			asteroids_nearby = true
			break
	
	# Update arc
	if asteroids_nearby and not arc_visible:
		arc_visible = true
		arc_visibility_timer = 0.5
		queue_redraw()
	elif not asteroids_nearby and arc_visible:
		arc_visibility_timer -= delta
		if arc_visibility_timer <= 0:
			arc_visible = false
			queue_redraw()

func _draw() -> void:
	# Draw arc if visible
	if arc_visible:
		var alpha = min(1.0, arc_visibility_timer / 0.2)
		var current_color = Color(arc_color.r, arc_color.g, arc_color.b, arc_color.a * alpha)
		draw_animated_arc(Vector2.ZERO, protection_radius, -PI, 0, current_color, 3.0)
	
	# Always draw as white
	var rect = Rect2(-launchpad_size.x / 2, -launchpad_size.y / 2, launchpad_size.x, launchpad_size.y)
	draw_rect(rect, Color.WHITE)
	draw_rect(rect, Color.WHITE, false, 2.0)

func activate() -> void:
	#print("[LAUNCHPAD] activate() called, scored=", scored, " is_blinking=", is_blinking)
	if not scored:  # Only activate if haven't scored
		is_blinking = true
		blink_timer = 0.0
		blink_visible = true
		visible = true
		#print("[LAUNCHPAD] Started blinking - is_blinking=true")
	else:
		#print("[LAUNCHPAD] Not activating - already scored")
		pass

func deactivate() -> void:
	#print("[LAUNCHPAD] deactivate() called - BEFORE: is_blinking=", is_blinking, " scored=", scored, " visible=", visible)
	is_blinking = false
	visible = true  # Always visible when not blinking
	blink_visible = true
	scored = true  # Mark as scored when deactivated
	#print("[LAUNCHPAD] deactivate() AFTER: is_blinking=", is_blinking, " scored=", scored, " visible=", visible)

func reset_for_next_orbit() -> void:
	#print("[LAUNCHPAD] reset_for_next_orbit() called - BEFORE: scored=", scored, " is_blinking=", is_blinking)
	scored = false  # Allow scoring again
	is_blinking = false
	visible = true
	#print("[LAUNCHPAD] reset_for_next_orbit() AFTER: scored=", scored, " is_blinking=", is_blinking)

func is_spaceship_on_pad(spaceship_pos: Vector2) -> bool:
	var local_pos = spaceship_pos - global_position
	var result = abs(local_pos.x) <= 70 and abs(local_pos.y) <= 50
	if result:
		#print("[LAUNCHPAD] Spaceship IS on pad")
	return result

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
	for i in range(51):
		var t = float(i) / 50.0
		var angle = lerp(start_angle, end_angle, t)
		var squiggle = sin(angle * 6.0 + wave_time * 2.0) * 3.5
		squiggle += sin(angle * 4.2 - wave_time * 2.6) * 1.75
		squiggle *= 1.0 - pow(abs(t - 0.5) * 2.0, 2.0)
		
		var point_radius = radius + squiggle
		points.append(center + Vector2(cos(angle), sin(angle)) * point_radius)
	
	for i in range(points.size() - 1):
		draw_line(points[i], points[i + 1], color, width)