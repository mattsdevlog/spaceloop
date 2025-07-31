extends Node2D

var velocity: Vector2 = Vector2.ZERO
var speed: float = 200.0  # Reduced from 400
var boost_strength: float = 50.0  # Reduced from 150

# Shatter effect variables
var is_shattered: bool = false
var pieces: Array = []
var shatter_timer: float = 0.0
var fade_duration: float = 3.0  # Time for pieces to fade away (increased from 2.0)

# Gravity state
var is_near_planet: bool = false

# Orbit tracking
var orbiting_planet = null
var orbit_start_angle: float = 0.0
var orbit_current_angle: float = 0.0
var orbit_total_angle: float = 0.0
var has_completed_orbit: bool = false
var launcher_ref = null  # Reference to launcher for scoring

# Direction tracking for orbit stabilization
var initial_direction: Vector2 = Vector2.ZERO
var has_stabilized_orbit: bool = false

# Piece structure: {position: Vector2, velocity: Vector2, rotation: float, size: Vector2, alpha: float}

func _ready() -> void:
	queue_redraw()

func launch(direction: Vector2) -> void:
	velocity = direction.normalized() * speed

func _input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		if not is_shattered:
			# Apply a small boost in the current velocity direction
			var boost_direction = velocity.normalized()
			if boost_direction.length() > 0:
				velocity += boost_direction * boost_strength

func shatter() -> void:
	is_shattered = true
	pieces.clear()
	
	# Create random pieces
	var num_pieces = 8
	for i in range(num_pieces):
		var piece = {
			"position": position + Vector2(randf_range(-15, 15), randf_range(-10, 10)),
			"velocity": Vector2(randf_range(-50, 50), randf_range(-75, -25)),  # Slower upward velocity
			"rotation": randf() * TAU,
			"size": Vector2(randf_range(5, 12), randf_range(5, 12)),
			"alpha": 1.0
		}
		pieces.append(piece)



func _process(delta: float) -> void:
	if not is_shattered:
		# Check for planet collision and calculate gravity
		var planets = get_tree().get_nodes_in_group("planets")
		var near_planet = false
		var planet_gravity = Vector2.ZERO
		var closest_planet = null
		var closest_distance = INF
		
		for planet in planets:
			var distance = global_position.distance_to(planet.global_position)
			
			# Check for collision with planet
			if distance <= planet.radius:
				shatter()
				return
			
			# Check if within planet's gravity influence
			if distance <= planet.gravity_influence_distance:
				near_planet = true
				
				# Track closest planet for orbit detection
				if distance < closest_distance:
					closest_distance = distance
					closest_planet = planet
				
				# Simplified stronger gravity calculation
				# Use a more aggressive falloff for gameplay feel
				var gravity_factor = 1.0 - (distance / planet.gravity_influence_distance)
				gravity_factor = gravity_factor * gravity_factor  # Square for stronger effect near planet
				
				# Calculate force based on planet's gravity strength
				var force_magnitude = planet.gravity_strength * gravity_factor * planet.mass
				
				# Direction from spaceship to planet
				var direction = (planet.global_position - global_position).normalized()
				planet_gravity += direction * force_magnitude
				
		
		# Apply appropriate gravity
		if near_planet and closest_planet:
			# Track initial direction when first entering gravity
			if initial_direction == Vector2.ZERO and velocity.length() > 0:
				initial_direction = velocity.normalized()
				has_stabilized_orbit = false
			
			var current_speed = velocity.length()
			
			# Apply gravity to direction
			if current_speed > 0:
				# Add gravity influence to velocity
				var new_velocity = velocity + planet_gravity * delta
				var new_direction = new_velocity.normalized()
				
				# Check if we've been deflected by 45 degrees
				if not has_stabilized_orbit and initial_direction.length() > 0:
					var angle_change = initial_direction.angle_to(new_direction)
					if abs(angle_change) >= PI/4:  # 45 degrees
						# Calculate stable orbital speed for current distance
						var distance = global_position.distance_to(closest_planet.global_position)
						var orbital_speed = sqrt(closest_planet.gravity_strength * closest_planet.mass * 0.5 / distance) * 30
						orbital_speed = clamp(orbital_speed, 100, 300)  # Keep speed reasonable
						
						velocity = new_direction * orbital_speed
						has_stabilized_orbit = true
					else:
						# Normal speed maintenance before stabilization
						var target_speed = current_speed * 0.95 + 20
						velocity = new_direction * target_speed
				else:
					# After stabilization, maintain orbital speed
					velocity = new_direction * current_speed
			else:
				# If stopped, give a small push
				velocity = Vector2(50, 0)
			
			is_near_planet = true
			
			# Track orbit progress
			update_orbit_tracking(closest_planet, delta)
		else:
			# Apply ground gravity when not near planets
			var ground_node = get_node_or_null("/root/Game/Ground")
			if ground_node:
				velocity.y += ground_node.gravity_strength * delta
			is_near_planet = false
			
			# Reset orbit tracking when leaving planet influence
			if orbiting_planet:
				reset_orbit_tracking()
			
			# Reset direction tracking
			initial_direction = Vector2.ZERO
			has_stabilized_orbit = false
		
		# Trigger redraw to show gravity state
		queue_redraw()
		
		# Check ground collision
		var ground_node = get_node_or_null("/root/Game/Ground")
		if ground_node:
			var global_ground_y = ground_node.global_position.y
			if global_position.y >= global_ground_y:
				# Hit the ground - shatter the spaceship
				global_position.y = global_ground_y
				velocity = Vector2.ZERO
				shatter()
		
		# Update position
		position += velocity * delta
		
		# Rotate spaceship to face movement direction
		if velocity.length() > 0:
			rotation = velocity.angle()
		
		# Shatter spaceship if it goes off screen
		var viewport = get_viewport_rect()
		if position.x < -50 or position.x > viewport.size.x + 50 or position.y < -50:
			shatter()
	else:
		# Update shattered pieces
		shatter_timer += delta
		
		for piece in pieces:
			# Update piece position
			piece.position += piece.velocity * delta
			
			# Slow down horizontal movement
			piece.velocity.x *= 0.98
			
			# Slow upward movement but keep floating
			piece.velocity.y *= 0.95
			
			# Update rotation (slower)
			piece.rotation += delta * 1.0
			
			# Fade out
			piece.alpha = max(0, 1.0 - (shatter_timer / fade_duration))
		
		# Remove spaceship when fade is complete
		if shatter_timer >= fade_duration:
			queue_free()
		
		# Trigger redraw for pieces
		queue_redraw()

func update_orbit_tracking(planet, delta: float) -> void:
	var to_spaceship = global_position - planet.global_position
	var current_angle = to_spaceship.angle()
	
	if orbiting_planet != planet:
		# Start tracking new planet
		orbiting_planet = planet
		orbit_start_angle = current_angle
		orbit_current_angle = current_angle
		orbit_total_angle = 0.0
		has_completed_orbit = false
	else:
		# Continue tracking orbit
		var angle_delta = current_angle - orbit_current_angle
		
		# Handle angle wrapping
		if angle_delta > PI:
			angle_delta -= TAU
		elif angle_delta < -PI:
			angle_delta += TAU
		
		orbit_total_angle += angle_delta
		orbit_current_angle = current_angle
		
		# Check for complete orbit (270 degrees is enough - more forgiving)
		if abs(orbit_total_angle) >= TAU * 0.75 and not has_completed_orbit:
			has_completed_orbit = true
			on_orbit_completed()

func reset_orbit_tracking() -> void:
	orbiting_planet = null
	orbit_total_angle = 0.0
	has_completed_orbit = false

func on_orbit_completed() -> void:
	# Find the launcher and increment score
	if not launcher_ref:
		launcher_ref = get_node_or_null("/root/Game/Launcher")
	
	if launcher_ref:
		launcher_ref.increment_score()
	
	# Mark the planet as orbited so it fades out
	if orbiting_planet:
		orbiting_planet.mark_as_orbited()

func _draw() -> void:
	if not is_shattered:
		# Choose color based on gravity state and orbit progress
		var ship_color = Color.GREEN
		if is_near_planet:
			if orbiting_planet:
				# Show orbit progress with color gradient
				var orbit_progress = abs(orbit_total_angle) / (TAU * 0.75)
				ship_color = Color.CYAN.lerp(Color.YELLOW, orbit_progress)
			else:
				ship_color = Color.CYAN  # Change color when in planet gravity
		
		# Draw square body
		var body_size = Vector2(30, 20)
		var body_pos = Vector2(-15, -body_size.y / 2)
		draw_rect(Rect2(body_pos, body_size), ship_color, true)
		
		# Draw triangle head (pointing right/forward)
		var triangle_points = PackedVector2Array([
			Vector2(25, 0),    # Tip (pointing forward)
			Vector2(15, -10),  # Top back
			Vector2(15, 10)    # Bottom back
		])
		draw_polygon(triangle_points, PackedColorArray([ship_color]))
	else:
		# Draw shattered pieces
		for piece in pieces:
			var transform = Transform2D()
			transform = transform.rotated(piece.rotation)
			transform = transform.translated(piece.position - position)
			
			draw_set_transform_matrix(transform)
			
			var color = Color.GREEN
			color.a = piece.alpha
			
			# Draw each piece as a small rectangle
			var rect = Rect2(-piece.size / 2, piece.size)
			draw_rect(rect, color, true)
			
			draw_set_transform_matrix(Transform2D())
