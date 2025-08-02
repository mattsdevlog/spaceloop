extends Node2D

# Movement properties
var velocity: Vector2 = Vector2.ZERO
var angular_velocity: float = 0.0
var thrust_power: float = 150.0  # Per rocket
var max_speed: float = 400.0
var friction: float = 0.99

# Smoke effect
var smoke_scene = preload("res://scenes/soft_body_particle.tscn")
var left_smoke_timer: float = 0.0
var right_smoke_timer: float = 0.0
var smoke_spawn_interval: float = 0.033

# Fuel system
var max_fuel: float = 300.0
var current_fuel: float = 300.0
var fuel_consumption_rate: float = 15.0  # Per rocket
var fuel_recharge_rate: float = 50.0

# Visual properties
var ship_color: Color = Color.MAGENTA
var rocket_width: float = 8.0
var rocket_height: float = 20.0
var body_width: float = 30.0
var body_height: float = 15.0

# Rocket states
var left_rocket_firing: bool = false
var right_rocket_firing: bool = false

# Gravity state
var is_near_planet: bool = false

# Shatter effect variables
var is_shattered: bool = false
var pieces: Array = []
var shatter_timer: float = 0.0
var fade_duration: float = 2.0
var respawn_delay: float = 1.0

# Score tracking
var score: int = 0

# Orbit tracking
var orbiting_planet = null
var orbit_start_angle: float = 0.0
var orbit_current_angle: float = 0.0
var orbit_total_angle: float = 0.0
var has_completed_orbit: bool = false
var pending_score: bool = false
var completed_planet = null
var orbit_started: bool = false
var tracked_planet = null

# Ground state
var is_on_ground: bool = false
var startup_grace: float = 0.1
var landing_grace: float = 0.0

func _ready() -> void:
	z_index = 1
	
	# Start on launchpad
	var launchpad = get_node_or_null("/root/Game/Launchpad")
	if launchpad:
		position = Vector2(launchpad.global_position.x, launchpad.global_position.y - 25)
		is_on_ground = true
		rotation = 0
		angular_velocity = 0.0
		velocity = Vector2.ZERO
		startup_grace = 0.5
		landing_grace = 0.5
	else:
		position = Vector2(600, 400)

func _process(delta: float) -> void:
	if startup_grace > 0:
		startup_grace -= delta
	
	if landing_grace > 0:
		landing_grace -= delta
	
	if not is_shattered:
		handle_input(delta)
		apply_gravity(delta)
		update_physics(delta)
		check_screen_boundaries()
		check_planet_collision()
		check_launchpad()
	else:
		update_shatter(delta)
	
	queue_redraw()

func handle_input(delta: float) -> void:
	left_rocket_firing = false
	right_rocket_firing = false
	
	# Left rocket control
	if Input.is_action_pressed("ui_left") and current_fuel > 0:
		left_rocket_firing = true
		# Left rocket pushes the ship to rotate clockwise and move right/forward
		var left_rocket_pos = Vector2(-body_width/2, body_height/2).rotated(rotation)
		var thrust_direction = Vector2.UP.rotated(rotation)
		
		# Apply thrust
		velocity += thrust_direction * thrust_power * delta
		
		# Apply torque (left rocket creates clockwise rotation)
		angular_velocity += 2.0 * delta
		
		# Consume fuel
		current_fuel -= fuel_consumption_rate * delta
		current_fuel = max(0, current_fuel)
		
		# Spawn smoke
		left_smoke_timer += delta
		if left_smoke_timer >= smoke_spawn_interval:
			spawn_smoke_burst(true)
			left_smoke_timer = 0.0
	else:
		left_smoke_timer = 0.0
	
	# Right rocket control
	if Input.is_action_pressed("ui_right") and current_fuel > 0:
		right_rocket_firing = true
		# Right rocket pushes the ship to rotate counter-clockwise and move left/forward
		var right_rocket_pos = Vector2(body_width/2, body_height/2).rotated(rotation)
		var thrust_direction = Vector2.UP.rotated(rotation)
		
		# Apply thrust
		velocity += thrust_direction * thrust_power * delta
		
		# Apply torque (right rocket creates counter-clockwise rotation)
		angular_velocity -= 2.0 * delta
		
		# Consume fuel
		current_fuel -= fuel_consumption_rate * delta
		current_fuel = max(0, current_fuel)
		
		# Spawn smoke
		right_smoke_timer += delta
		if right_smoke_timer >= smoke_spawn_interval:
			spawn_smoke_burst(false)
			right_smoke_timer = 0.0
	else:
		right_smoke_timer = 0.0
	
	# Limit max speed
	if velocity.length() > max_speed:
		velocity = velocity.normalized() * max_speed
	
	# Recharge fuel only when on ground
	if is_on_ground and not left_rocket_firing and not right_rocket_firing:
		current_fuel += fuel_recharge_rate * delta
		current_fuel = min(max_fuel, current_fuel)

func update_physics(delta: float) -> void:
	# Apply angular velocity
	rotation += angular_velocity * delta
	angular_velocity *= 0.95  # Angular damping
	
	# Apply velocity
	position += velocity * delta
	
	# Apply friction
	velocity *= friction
	
	# Skip collision checks during startup grace period
	if startup_grace > 0:
		return
	
	# Check launchpad collision
	var launchpad = get_node_or_null("/root/Game/Launchpad")
	var on_launchpad = false
	if launchpad:
		on_launchpad = check_platform_collision(launchpad.global_position.y - 10, 
											   launchpad.global_position.x - 50,
											   launchpad.global_position.x + 50,
											   delta)
	
	# Check ground collision if not on launchpad
	if not on_launchpad:
		var ground_node = get_node_or_null("/root/Game/Ground")
		if ground_node:
			var ground_y = ground_node.global_position.y
			var ship_bottom = global_position.y + body_height/2
			
			if ship_bottom >= ground_y:
				shatter()
				return
			else:
				is_on_ground = false

func get_bottom_corners() -> Array:
	var ship_transform = Transform2D(rotation, global_position)
	var half_width = body_width / 2
	var half_height = body_height / 2
	
	var left = ship_transform * Vector2(-half_width, half_height)
	var right = ship_transform * Vector2(half_width, half_height)
	
	return [left, right]

func check_platform_collision(platform_y: float, platform_left: float, platform_right: float, delta: float) -> bool:
	var corners = get_bottom_corners()
	var left_corner = corners[0]
	var right_corner = corners[1]
	
	# Check which corners are over the platform
	var left_over_platform = left_corner.x >= platform_left and left_corner.x <= platform_right
	var right_over_platform = right_corner.x >= platform_left and right_corner.x <= platform_right
	
	# Check which corners are below platform level
	var left_below = left_corner.y >= platform_y
	var right_below = right_corner.y >= platform_y
	
	# Determine collision state
	if not (left_below or right_below):
		return false
	
	if not (left_over_platform or right_over_platform):
		return false
	
	# Check if ship is landing butt-down (mostly upright)
	var norm_rot = fmod(rotation + PI, TAU) - PI
	var is_mostly_upright = abs(norm_rot) < PI/3
	
	# Check for high-speed crash
	var crash_threshold = 500 if is_mostly_upright else 350
	if velocity.y > crash_threshold and landing_grace <= 0:
		shatter()
		return true
	
	is_on_ground = true
	
	# Handle different collision cases
	if left_below and right_below and left_over_platform and right_over_platform:
		# Both corners touching - stable landing
		if (abs(norm_rot - PI/2) < PI/4 or abs(norm_rot + PI/2) < PI/4) and landing_grace <= 0:
			shatter()
			return true
		handle_stable_landing(platform_y, left_corner, right_corner)
		landing_grace = 0.2
	elif left_below and left_over_platform:
		handle_corner_pivot(left_corner, platform_y, true, delta)
	elif right_below and right_over_platform:
		handle_corner_pivot(right_corner, platform_y, false, delta)
	
	return true

func handle_stable_landing(platform_y: float, left_corner: Vector2, right_corner: Vector2) -> void:
	var avg_penetration = ((left_corner.y + right_corner.y) / 2.0) - platform_y
	global_position.y -= avg_penetration
	velocity.y = min(velocity.y, 0)
	angular_velocity *= 0.7
	velocity.x *= 0.9

func handle_corner_pivot(corner: Vector2, platform_y: float, is_left: bool, delta: float) -> void:
	var pivot = Vector2(corner.x, platform_y)
	var lever_arm = global_position.x - pivot.x
	var gravity_torque = lever_arm * 0.02
	angular_velocity += gravity_torque
	angular_velocity *= 0.95
	
	var new_angle = rotation + angular_velocity * delta
	var offset_from_center = Vector2(-body_width/2 if is_left else body_width/2, body_height/2)
	var new_corner = global_position + offset_from_center.rotated(new_angle)
	
	global_position += pivot - new_corner
	rotation = new_angle
	
	velocity.y = 0
	velocity.x *= 0.85
	
	var norm_rot = fmod(rotation + PI, TAU) - PI
	if (abs(norm_rot - PI/2) < PI/6 or abs(norm_rot + PI/2) < PI/6) and landing_grace <= 0:
		shatter()

func _draw() -> void:
	if not is_shattered:
		var current_color = ship_color
		if is_near_planet:
			if orbiting_planet:
				var orbit_progress = abs(orbit_total_angle) / (TAU * 0.75)
				current_color = Color.MAGENTA.lerp(Color.YELLOW, orbit_progress)
			else:
				current_color = Color.GREEN
		
		# Draw main body
		var body_rect = Rect2(-body_width/2, -body_height/2, body_width, body_height)
		draw_rect(body_rect, Color(0.2, 0.2, 0.2))
		
		# Draw fuel level in body
		var fuel_percentage = current_fuel / max_fuel
		var fuel_height = body_height * fuel_percentage
		var fuel_rect = Rect2(-body_width/2, -body_height/2 + body_height - fuel_height, body_width, fuel_height)
		
		var fuel_color = current_color
		if fuel_percentage < 0.25:
			fuel_color = Color.RED
		elif fuel_percentage < 0.5:
			fuel_color = Color.ORANGE
		
		draw_rect(fuel_rect, fuel_color)
		draw_rect(body_rect, current_color, false, 2.0)
		
		# Draw left rocket
		var left_rocket_rect = Rect2(-body_width/2 - rocket_width/2, body_height/2 - rocket_height/2, rocket_width, rocket_height)
		draw_rect(left_rocket_rect, current_color)
		
		# Draw right rocket
		var right_rocket_rect = Rect2(body_width/2 - rocket_width/2, body_height/2 - rocket_height/2, rocket_width, rocket_height)
		draw_rect(right_rocket_rect, current_color)
		
		# Draw thrust flames when firing
		if left_rocket_firing and current_fuel > 0:
			var flame_points = PackedVector2Array([
				Vector2(-body_width/2, body_height/2 + rocket_height/2),
				Vector2(-body_width/2 - 5, body_height/2 + rocket_height/2 + 10),
				Vector2(-body_width/2 + 5, body_height/2 + rocket_height/2 + 10)
			])
			draw_polygon(flame_points, PackedColorArray([Color.ORANGE]))
		
		if right_rocket_firing and current_fuel > 0:
			var flame_points = PackedVector2Array([
				Vector2(body_width/2, body_height/2 + rocket_height/2),
				Vector2(body_width/2 - 5, body_height/2 + rocket_height/2 + 10),
				Vector2(body_width/2 + 5, body_height/2 + rocket_height/2 + 10)
			])
			draw_polygon(flame_points, PackedColorArray([Color.ORANGE]))
		
		# Draw score
		var font = ThemeDB.fallback_font
		var score_text = "Score: " + str(score)
		draw_string(font, Vector2(-30, -40), score_text, HORIZONTAL_ALIGNMENT_CENTER, -1, 20, Color.WHITE)
		
		if pending_score:
			draw_string(font, Vector2(-50, -60), "Return to pad!", HORIZONTAL_ALIGNMENT_CENTER, -1, 16, Color.YELLOW)
	else:
		# Draw shattered pieces
		for piece in pieces:
			var transform = Transform2D()
			transform = transform.rotated(piece.rotation)
			transform = transform.translated(piece.position - position)
			
			draw_set_transform_matrix(transform)
			
			var color = ship_color
			color.a = piece.alpha
			
			var rect = Rect2(-piece.size / 2, piece.size)
			draw_rect(rect, color, true)
			
			draw_set_transform_matrix(Transform2D())

func spawn_smoke_burst(is_left: bool) -> void:
	var smoke = smoke_scene.instantiate()
	
	# Position at the bottom of the appropriate rocket
	var rocket_x = -body_width/2 if is_left else body_width/2
	var spawn_offset = Vector2(rocket_x, body_height/2 + rocket_height/2).rotated(rotation)
	smoke.global_position = global_position + spawn_offset
	
	get_parent().add_child(smoke)
	
	# Set smoke properties
	var base_direction = Vector2.DOWN.rotated(rotation)
	var spread_angle = randf_range(-0.4, 0.4)
	var smoke_direction = base_direction.rotated(spread_angle)
	
	var smoke_speed = randf_range(50, 100)
	smoke.initial_velocity = smoke_direction * smoke_speed + velocity * 0.1
	
	smoke.radius = randf_range(8, 12)
	smoke.num_points = randi_range(8, 12)
	smoke.stiffness = randf_range(0.85, 0.95)
	smoke.pressure = randf_range(70, 90)

# Copy all the gravity, orbit, collision, and other functions from player_spaceship.gd
func apply_gravity(delta: float) -> void:
	var planets = get_tree().get_nodes_in_group("planets")
	var near_planet = false
	var planet_gravity = Vector2.ZERO
	var closest_planet = null
	var closest_distance = INF
	
	for planet in planets:
		if not is_instance_valid(planet):
			continue
			
		var distance = global_position.distance_to(planet.global_position)
		
		if distance <= planet.gravity_influence_distance:
			near_planet = true
			
			if distance < closest_distance:
				closest_distance = distance
				closest_planet = planet
			
			var gravity_factor = 1.0 - (distance / planet.gravity_influence_distance)
			gravity_factor = gravity_factor * gravity_factor
			
			var force_magnitude = planet.gravity_strength * gravity_factor * planet.mass
			var direction = (planet.global_position - global_position).normalized()
			planet_gravity += direction * force_magnitude
	
	if near_planet and closest_planet:
		velocity += planet_gravity * delta
		is_near_planet = true
		update_orbit_tracking(closest_planet, delta)
	else:
		if not is_on_ground:
			var ground_node = get_node_or_null("/root/Game/Ground")
			if ground_node:
				if global_position.y < ground_node.global_position.y:
					velocity.y += ground_node.gravity_strength * delta
		is_near_planet = false
		
		if orbiting_planet and not pending_score:
			orbiting_planet = null

func update_orbit_tracking(planet, delta: float) -> void:
	var to_spaceship = global_position - planet.global_position
	var current_angle = to_spaceship.angle()

	if orbiting_planet != planet:
		orbiting_planet = planet
		
		if not orbit_started or tracked_planet != planet:
			orbit_start_angle = current_angle
			orbit_current_angle = current_angle
			orbit_total_angle = 0.0
			has_completed_orbit = false
			orbit_started = true
			tracked_planet = planet
			planet.start_orbit_tracking(self, orbit_start_angle)
		else:
			orbit_current_angle = current_angle
			planet.start_orbit_tracking(self, orbit_start_angle)
			var progress = abs(orbit_total_angle) / (TAU * 0.75)
			var direction = 1 if orbit_total_angle > 0 else -1
			planet.update_orbit_progress(progress, direction)
	else:
		var angle_delta = current_angle - orbit_current_angle
		
		if angle_delta > PI:
			angle_delta -= TAU
		elif angle_delta < -PI:
			angle_delta += TAU
		
		orbit_total_angle += angle_delta
		orbit_current_angle = current_angle
		
		var progress = abs(orbit_total_angle) / (TAU * 0.75)
		var direction = 1 if orbit_total_angle > 0 else -1
		planet.update_orbit_progress(progress, direction)
		
		if abs(orbit_total_angle) >= TAU * 0.75 and not has_completed_orbit:
			has_completed_orbit = true
			planet.complete_orbit()
			on_orbit_completed()

func reset_orbit_tracking() -> void:
	if orbiting_planet:
		orbiting_planet.stop_orbit_tracking()
	if tracked_planet and tracked_planet != orbiting_planet:
		tracked_planet.stop_orbit_tracking()
	orbiting_planet = null
	tracked_planet = null
	orbit_total_angle = 0.0
	has_completed_orbit = false
	orbit_started = false

func on_orbit_completed() -> void:
	pending_score = true
	completed_planet = orbiting_planet
	
	var launchpad = get_node_or_null("/root/Game/Launchpad")
	if launchpad:
		launchpad.activate()

func check_screen_boundaries() -> void:
	var viewport = get_viewport_rect()
	var margin = max(body_width/2, body_height/2)
	var bounce_damping = 0.8
	
	if position.x - margin < 0:
		position.x = margin
		velocity.x = abs(velocity.x) * bounce_damping
	elif position.x + margin > viewport.size.x:
		position.x = viewport.size.x - margin
		velocity.x = -abs(velocity.x) * bounce_damping
	
	if position.y - margin < 0:
		position.y = margin
		velocity.y = abs(velocity.y) * bounce_damping
	elif position.y + margin > viewport.size.y:
		position.y = viewport.size.y - margin
		velocity.y = -abs(velocity.y) * bounce_damping

func check_planet_collision() -> void:
	var planets = get_tree().get_nodes_in_group("planets")
	for planet in planets:
		if not is_instance_valid(planet):
			continue
		
		var distance = global_position.distance_to(planet.global_position)
		if distance <= planet.radius + max(body_width/2, body_height/2):
			shatter()
			return
	
	var asteroids = get_tree().get_nodes_in_group("asteroids")
	for asteroid in asteroids:
		if not is_instance_valid(asteroid):
			continue
		
		var distance = global_position.distance_to(asteroid.global_position)
		if distance <= asteroid.get_radius() + max(body_width/2, body_height/2):
			shatter()
			return

func shatter() -> void:
	is_shattered = true
	pieces.clear()
	shatter_timer = 0.0
	
	if orbiting_planet or tracked_planet:
		reset_orbit_tracking()
	
	var num_pieces = 8
	for i in range(num_pieces):
		var piece = {
			"position": position + Vector2(randf_range(-15, 15), randf_range(-10, 10)),
			"velocity": Vector2(randf_range(-100, 100), randf_range(-150, -50)),
			"rotation": randf() * TAU,
			"size": Vector2(randf_range(5, 12), randf_range(5, 12)),
			"alpha": 1.0
		}
		pieces.append(piece)
	
	velocity = Vector2.ZERO

func update_shatter(delta: float) -> void:
	shatter_timer += delta
	
	for piece in pieces:
		piece.position += piece.velocity * delta
		piece.velocity.x *= 0.98
		piece.velocity.y += 200 * delta
		piece.rotation += delta * 2.0
		piece.alpha = max(0, 1.0 - (shatter_timer / fade_duration))
	
	if shatter_timer >= fade_duration + respawn_delay:
		respawn()

func respawn() -> void:
	is_shattered = false
	pieces.clear()
	shatter_timer = 0.0
	
	var launchpad = get_node_or_null("/root/Game/Launchpad")
	if launchpad:
		position = Vector2(launchpad.global_position.x, launchpad.global_position.y - 25)
		rotation = 0
	else:
		var ground_node = get_node_or_null("/root/Game/Ground")
		if ground_node:
			position = Vector2(600, ground_node.global_position.y - 30)
		else:
			position = Vector2(600, 400)
	
	velocity = Vector2.ZERO
	angular_velocity = 0.0
	current_fuel = max_fuel
	is_on_ground = true
	is_near_planet = false
	orbiting_planet = null
	tracked_planet = null
	has_completed_orbit = false
	pending_score = false
	completed_planet = null
	orbit_started = false
	orbit_total_angle = 0.0
	startup_grace = 0.5
	landing_grace = 0.0
	
	if launchpad:
		launchpad.deactivate()

func check_launchpad() -> void:
	if not pending_score:
		return
	
	var launchpad = get_node_or_null("/root/Game/Launchpad")
	if not launchpad:
		return
	
	if launchpad.is_spaceship_on_pad(global_position) and is_on_ground:
		score += 1
		pending_score = false
		
		launchpad.deactivate()
		
		if completed_planet and is_instance_valid(completed_planet):
			#print("Marking planet as orbited")
			completed_planet.mark_as_orbited()
			completed_planet = null
		else:
			#print("No valid completed_planet to mark as orbited")
			pass
		
		reset_orbit_tracking()
