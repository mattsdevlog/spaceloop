extends Node2D

var launchpad_size: Vector2 = Vector2(100, 20)
var launchpad_color: Color = Color(0.3, 0.3, 0.3)
var active_color: Color = Color(0.5, 0.8, 0.5)
var is_active: bool = false
var blink_timer: float = 0.0
var blink_on: bool = true
var protection_radius: float = 240.0  # Radius of protective arc (doubled)
var arc_color: Color = Color(0.7, 0.7, 1.0, 0.3)  # Semi-transparent blue
var arc_visible: bool = false
var arc_visibility_timer: float = 0.0
var arc_fade_time: float = 0.5  # Time to fade out after no asteroids nearby
var detection_radius: float = 400.0  # Distance to detect approaching asteroids
var wave_time: float = 0.0  # For animating the wavy effect

func _ready() -> void:
	add_to_group("launchpad")
	set_process(true)

func _draw() -> void:
	# Draw protective arc only when visible
	if arc_visible:
		var alpha = min(1.0, arc_visibility_timer / 0.2)  # Fade in over 0.2 seconds
		var current_color = Color(arc_color.r, arc_color.g, arc_color.b, arc_color.a * alpha)
		draw_animated_arc(Vector2.ZERO, protection_radius, -PI, 0, current_color, 3.0)
	
	var color = launchpad_color
	if is_active:
		color = Color.YELLOW if blink_on else launchpad_color
	var rect = Rect2(-launchpad_size.x / 2, -launchpad_size.y / 2, launchpad_size.x, launchpad_size.y)
	draw_rect(rect, color)
	
	# Draw border
	draw_rect(rect, Color.WHITE, false, 2.0)
	
	# Draw landing indicators (removed - now the whole pad blinks yellow)

func activate() -> void:
	is_active = true
	blink_timer = 0.0
	blink_on = true
	queue_redraw()

func deactivate() -> void:
	is_active = false
	queue_redraw()

func is_spaceship_on_pad(spaceship_pos: Vector2) -> bool:
	var half_width = launchpad_size.x / 2
	var half_height = launchpad_size.y / 2
	
	var local_pos = spaceship_pos - global_position
	
	# Increased margin to account for taller spaceship
	return (abs(local_pos.x) <= half_width + 20 and 
			abs(local_pos.y) <= half_height + 40)

func check_asteroid_collision(asteroid_pos: Vector2, asteroid_radius: float) -> Dictionary:
	# Check if asteroid collides with protective arc
	var distance = asteroid_pos.distance_to(global_position)
	
	# Only check upper hemisphere (arc is from -PI to 0)
	var to_asteroid = asteroid_pos - global_position
	var angle = to_asteroid.angle()
	
	# Check if in upper hemisphere and close to arc
	# Add a small buffer (5 pixels) to ensure detection
	if angle >= -PI and angle <= 0 and distance - asteroid_radius < protection_radius + 5:
		# Check if asteroid is actually hitting the arc from outside
		if distance - asteroid_radius <= protection_radius:
			var collision_data = {
				"collided": true,
				"normal": to_asteroid.normalized(),
				"overlap": protection_radius - (distance - asteroid_radius) + 5
			}
			return collision_data
	
	return {"collided": false}

func _process(delta: float) -> void:
	# Update wave animation
	wave_time += delta
	
	# Check for nearby asteroids
	var asteroids_nearby = false
	var asteroids = get_tree().get_nodes_in_group("asteroids")
	
	for asteroid in asteroids:
		if not is_instance_valid(asteroid):
			continue
		
		var distance = global_position.distance_to(asteroid.global_position)
		if distance < detection_radius:
			asteroids_nearby = true
			break
	
	# Update arc visibility
	var old_arc_visible = arc_visible
	if asteroids_nearby:
		if not arc_visible:
			arc_visible = true
			queue_redraw()
		arc_visibility_timer = arc_fade_time
	else:
		arc_visibility_timer -= delta
		if arc_visibility_timer <= 0:
			if arc_visible:
				arc_visible = false
				queue_redraw()
			arc_visibility_timer = 0
	
	# Update blinking if active
	if is_active:
		blink_timer += delta
		if blink_timer >= 0.3:  # Blink every 0.3 seconds
			blink_timer = 0.0
			blink_on = not blink_on
			queue_redraw()
	
	# Only redraw if arc is visible and animating
	if arc_visible:
		queue_redraw()

func draw_animated_arc(center: Vector2, radius: float, start_angle: float, end_angle: float, color: Color, width: float) -> void:
	# Draw an animated wavy arc
	var points = []
	var segments = 50  # More segments for smoother animation
	var squiggle_amplitude = 3.5  # How wavy the line is (halved)
	var squiggle_frequency = 6.0  # How many waves in the arc (halved)
	var wave_speed = 2.0  # Speed of wave animation
	
	# The arc needs to extend down to ground level
	# Since we're drawing a full semicircle, just use -PI to 0
	var adjusted_start = -PI
	var adjusted_end = 0.0
	
	for i in range(segments + 1):
		var t = float(i) / float(segments)
		var angle = lerp(adjusted_start, adjusted_end, t)
		
		# Add animated squiggle offset based on angle and time
		var squiggle_offset = sin(angle * squiggle_frequency + wave_time * wave_speed) * squiggle_amplitude
		# Add a second wave for more organic movement
		squiggle_offset += sin(angle * squiggle_frequency * 0.7 - wave_time * wave_speed * 1.3) * squiggle_amplitude * 0.5
		
		# Reduce squiggle at the ends to ensure they touch ground
		var end_factor = 1.0 - pow(abs(t - 0.5) * 2.0, 2.0)  # Fade squiggle at ends
		squiggle_offset *= end_factor
		
		var point_radius = radius + squiggle_offset
		var point = center + Vector2(cos(angle), sin(angle)) * point_radius
		points.append(point)
	
	# Draw the squiggly line
	for i in range(points.size() - 1):
		draw_line(points[i], points[i + 1], color, width)
