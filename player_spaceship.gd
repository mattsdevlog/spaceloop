extends Node2D

# Export variable to switch between single and dual rocket mode
@export var dual_rocket_mode: bool = false

# Movement properties
var velocity: Vector2 = Vector2.ZERO
var thrust_power: float = 300.0
var rotation_speed: float = 3.0  # radians per second
var max_speed: float = 400.0
var friction: float = 0.99  # Slight friction for better control
var angular_velocity: float = 0.0  # For physics-based rotation

# Smoke effect
var smoke_scene = preload("res://scenes/soft_body_particle.tscn")
var smoke_spawn_timer: float = 0.0
var smoke_spawn_interval: float = 0.033  # Spawn smoke every 0.033 seconds (30 per second) when thrusting

# Remote player input tracking
var remote_input_left: bool = false
var remote_input_right: bool = false
var remote_input_up: bool = false


# Fuel system
var max_fuel: float = 300.0
var current_fuel: float = 300.0
var fuel_consumption_rate: float = 20.0  # Fuel per second when thrusting
var fuel_recharge_rate: float = 50.0  # Fuel per second when landed

# Visual properties
var ship_color: Color = Color.CYAN

# Dual rocket mode variables
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
var player_name: String = ""

# Chat message display
var chat_message: String = ""
var chat_message_timer: float = 0.0
var chat_message_duration: float = 5.0  # Show messages for 5 seconds
var chat_message_full: String = ""  # Full message to type out
var chat_message_chars_shown: int = 0  # Number of characters currently shown
var chat_typing_speed: float = 20.0  # Characters per second
var chat_typing_timer: float = 0.0  # Timer for typing effect

# Orbit tracking
var orbiting_planet = null
var orbit_start_angle: float = 0.0
var orbit_current_angle: float = 0.0
var orbit_total_angle: float = 0.0
var has_completed_orbit: bool = false
var pending_score: bool = false  # True when orbit complete, waiting for launchpad
var completed_planet = null  # The planet that was successfully orbited
var orbit_started: bool = false  # Track if we've started counting the orbit
var tracked_planet = null  # The planet we're tracking progress on (persists when leaving gravity)
var is_ascension_mode: bool = false  # Unlimited fuel during ascension
var battle_mode: bool = false  # Shooting enabled
var can_shoot: bool = true
var shoot_cooldown: float = 0.5
var shoot_timer: float = 0.0
# Health removed - using fuel directly in battle mode
var projectile_scene = preload("res://scenes/projectile.tscn")

# Ground state
var is_on_ground: bool = false
var startup_grace: float = 0.1  # Grace period to avoid collision on startup
var landing_grace: float = 0.0  # Grace period after landing to stabilize

# Launch shake effect
var is_launching: bool = false
var launch_shake_timer: float = 0.0
var launch_shake_duration: float = 1.0
var launch_shake_intensity: float = 3.0
var shake_offset: Vector2 = Vector2.ZERO
var time_settled_on_pad: float = 0.0  # Time spaceship has been still on launchpad
var settle_threshold: float = 0.5  # Must be settled for this long before shake can re-enable
var max_settle_velocity: float = 10.0  # Max velocity to be considered "settled"

# UI Labels
var name_label: Label = null
var chat_display: Node2D = null

func _ready() -> void:
	# Set z_index so spaceship appears above smoke
	z_index = 1
	
	# Create name label
	name_label = Label.new()
	name_label.add_theme_font_size_override("font_size", 20)
	name_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	name_label.position = Vector2(0, -65)
	name_label.z_index = 10
	add_child(name_label)
	
	# Create chat display
	var ChatDisplay = preload("res://chat_display.gd")
	chat_display = Node2D.new()
	chat_display.set_script(ChatDisplay)
	chat_display.position = Vector2(0, -80)
	add_child(chat_display)
	
	# Check if this is a multiplayer game
	var is_multiplayer = get_parent() and get_parent().name == "Players"
	
	if not is_multiplayer:
		# Single player - Start on launchpad
		var launchpad = get_node_or_null("/root/Game/Launchpad")
		if launchpad:
			position = Vector2(launchpad.global_position.x, launchpad.global_position.y - 40)  # Adjusted for taller ship
			is_on_ground = true
			rotation = 0  # Point right (90 degrees clockwise from up)
			angular_velocity = 0.0  # Ensure no initial rotation
			velocity = Vector2.ZERO  # Ensure no initial velocity
			startup_grace = 0.5  # Give grace period on startup
			landing_grace = 0.5  # Also set landing grace to prevent immediate shattering
			time_settled_on_pad = settle_threshold  # Start with shake enabled
		else:
			position = Vector2(600, 400)
	else:
		# Multiplayer - position is set by multiplayer_game.gd
		is_on_ground = true
		rotation = 0
		angular_velocity = 0.0
		velocity = Vector2.ZERO
		startup_grace = 0.5
		landing_grace = 0.5
		time_settled_on_pad = settle_threshold + 0.1  # Ensure remote players can shake immediately

func _process(delta: float) -> void:
	# Update startup grace period
	if startup_grace > 0:
		startup_grace -= delta
	
	# Update landing grace period
	if landing_grace > 0:
		landing_grace -= delta
	
	# No shoot cooldown - removed for rapid fire
	
	if not is_shattered:
		handle_input(delta)
		apply_gravity(delta)
		update_physics(delta)
		check_screen_boundaries()
		check_planet_collision()
		check_launchpad()
		check_spaceship_collisions()
		
		# Handle shooting in battle mode
		if battle_mode and is_multiplayer_authority():
			handle_shooting()
		
		# Handle smoke effects for remote players
		if not is_multiplayer_authority() and get_multiplayer().has_multiplayer_peer():
			handle_remote_smoke_effects(delta)
	else:
		update_shatter(delta)
	
	# Keep labels upright and positioned above ship in global space
	if name_label:
		name_label.rotation = -rotation
		name_label.text = player_name
		name_label.visible = not is_shattered and player_name != ""
		
		# Position label above ship in global space
		if player_name != "":
			# Calculate global "up" position regardless of ship rotation
			var global_offset = Vector2(0, -85)
			name_label.position = global_offset.rotated(-rotation)
			name_label.position.x -= name_label.size.x / 2  # Center horizontally
	
	if chat_display:
		chat_display.rotation = -rotation
		chat_display.visible = not is_shattered
		
		# Position chat above name in global space
		var global_offset = Vector2(0, -115)
		chat_display.position = global_offset.rotated(-rotation)
	
	queue_redraw()

func handle_input(delta: float) -> void:
	# Determine input source based on authority
	var input_left: bool
	var input_right: bool
	var input_up: bool
	
	if is_multiplayer_authority() or not get_multiplayer().has_multiplayer_peer():
		# Local player or single player - use actual input
		input_left = Input.is_action_pressed("ui_left")
		input_right = Input.is_action_pressed("ui_right")
		input_up = Input.is_action_pressed("ui_up")
	else:
		# Remote player - use synced inputs
		input_left = remote_input_left
		input_right = remote_input_right
		input_up = remote_input_up
		
	if dual_rocket_mode:
		handle_dual_rocket_input(delta, input_left, input_right, input_up)
	else:
		handle_single_rocket_input(delta, input_left, input_right, input_up)
	
	# Recharge fuel only when on ground (or keep at max during ascension)
	if is_ascension_mode and not battle_mode:
		current_fuel = max_fuel
	elif not battle_mode:
		var any_rocket_firing = left_rocket_firing or right_rocket_firing or input_up
		if is_on_ground and not any_rocket_firing:
			current_fuel += fuel_recharge_rate * delta
			current_fuel = min(max_fuel, current_fuel)

func handle_single_rocket_input(delta: float, input_left: bool, input_right: bool, input_up: bool) -> void:
	left_rocket_firing = false
	right_rocket_firing = false
	
	# Rotation - always allow rotation
	if input_left:
		angular_velocity -= rotation_speed * 2 * delta
	if input_right:
		angular_velocity += rotation_speed * 2 * delta
	angular_velocity = clamp(angular_velocity, -rotation_speed, rotation_speed)
	
	# Thrust (only if we have fuel or in ascension mode)
	if input_up and (current_fuel > 0 or is_ascension_mode):
		# Check if we're starting to launch (for all players including remote)
		if is_on_ground and not is_launching and time_settled_on_pad >= settle_threshold:
			is_launching = true
			launch_shake_timer = 0.0
		
		var thrust_direction = Vector2.UP.rotated(rotation)
		velocity += thrust_direction * thrust_power * delta
		
		# Consume fuel (unless in ascension mode)
		if not is_ascension_mode:
			current_fuel -= fuel_consumption_rate * delta
			current_fuel = max(0, current_fuel)
		
		# Limit max speed
		if velocity.length() > max_speed:
			velocity = velocity.normalized() * max_speed
		
		# Spawn smoke particles locally for all players
		smoke_spawn_timer += delta
		if smoke_spawn_timer >= smoke_spawn_interval:
			spawn_smoke_burst()
			smoke_spawn_timer = 0.0
	else:
		# Reset smoke timer when not thrusting
		smoke_spawn_timer = 0.0

func handle_dual_rocket_input(delta: float, input_left: bool, input_right: bool, input_up: bool) -> void:
	left_rocket_firing = false
	right_rocket_firing = false
	var left_smoke_timer: float = 0.0
	var right_smoke_timer: float = 0.0
	
	# Left arrow fires RIGHT rocket (turns ship left)
	if input_left and (current_fuel > 0 or is_ascension_mode):
		right_rocket_firing = true
		
		# Check if we're starting to launch
		if is_on_ground and not is_launching and time_settled_on_pad >= settle_threshold:
			is_launching = true
			launch_shake_timer = 0.0
		
		var thrust_direction = Vector2.UP.rotated(rotation)
		velocity += thrust_direction * thrust_power * 0.5 * delta  # Half power per rocket
		
		# Apply torque (right rocket creates counter-clockwise rotation)
		angular_velocity -= 4.0 * delta  # Increased rotational velocity
		
		# Consume fuel (unless in ascension mode)
		if not is_ascension_mode:
			current_fuel -= fuel_consumption_rate * 0.5 * delta
			current_fuel = max(0, current_fuel)
	
	# Right arrow fires LEFT rocket (turns ship right)
	if input_right and (current_fuel > 0 or is_ascension_mode):
		left_rocket_firing = true
		
		# Check if we're starting to launch
		if is_on_ground and not is_launching and time_settled_on_pad >= settle_threshold:
			is_launching = true
			launch_shake_timer = 0.0
		
		var thrust_direction = Vector2.UP.rotated(rotation)
		velocity += thrust_direction * thrust_power * 0.5 * delta  # Half power per rocket
		
		# Apply torque (left rocket creates clockwise rotation)
		angular_velocity += 4.0 * delta  # Increased rotational velocity
		
		# Consume fuel (unless in ascension mode)
		if not is_ascension_mode:
			current_fuel -= fuel_consumption_rate * 0.5 * delta
			current_fuel = max(0, current_fuel)
	
	# Handle smoke spawning independently for each rocket
	smoke_spawn_timer += delta
	if smoke_spawn_timer >= smoke_spawn_interval:
		if left_rocket_firing:
			spawn_dual_rocket_smoke(true)  # true = left rocket
		if right_rocket_firing:
			spawn_dual_rocket_smoke(false)  # false = right rocket
		if left_rocket_firing or right_rocket_firing:
			smoke_spawn_timer = 0.0
	
	if not (left_rocket_firing or right_rocket_firing):
		smoke_spawn_timer = 0.0
	
	# Limit max speed
	if velocity.length() > max_speed:
		velocity = velocity.normalized() * max_speed

func update_physics(delta: float) -> void:
	# For remote players, update ground state based on position
	if not is_multiplayer_authority() and get_multiplayer().has_multiplayer_peer():
		var ground_y = 1221
		var ship_bottom = position.y + 30
		is_on_ground = ship_bottom >= ground_y - 5
	
	# Update launch shake
	if is_launching:
		launch_shake_timer += delta
		if launch_shake_timer < launch_shake_duration:
			# Calculate shake offset
			var shake_progress = launch_shake_timer / launch_shake_duration
			var current_intensity = launch_shake_intensity * (1.0 - shake_progress * 0.8)  # Diminish over time
			shake_offset.x = sin(launch_shake_timer * 30.0) * current_intensity  # Rapid oscillation
			shake_offset.y = sin(launch_shake_timer * 25.0) * current_intensity * 0.3  # Smaller vertical shake
		else:
			# End of shake
			shake_offset = Vector2.ZERO
			if not is_on_ground:
				is_launching = false
	
	# Apply angular velocity
	rotation += angular_velocity * delta
	angular_velocity *= 0.98  # Angular damping
	
	# Apply velocity
	position += velocity * delta
	
	# Apply friction
	velocity *= friction
	
	# Skip collision checks during startup grace period
	if startup_grace > 0:
		return
	
	# Check launchpad collision with square bottom
	var on_launchpad = false
	var is_multiplayer = get_parent() and get_parent().name == "Players"
	
	if is_multiplayer:
		# Check all 3 launchpads in multiplayer
		var launchpad_x_positions = [300, 600, 900]
		var launchpad_y = 1221
		
		for x_pos in launchpad_x_positions:
			if check_platform_collision(launchpad_y - 10, x_pos - 50, x_pos + 50, delta):
				on_launchpad = true
				break
	else:
		# Single player - check single launchpad
		var launchpad = get_node_or_null("/root/Game/Launchpad")
		if launchpad:
			on_launchpad = check_platform_collision(launchpad.global_position.y - 10, 
												   launchpad.global_position.x - 50,
												   launchpad.global_position.x + 50,
												   delta)
		
	# Track settling time on launchpad
	# Also check if we're close to the launchpad (more forgiving for settle detection)
	var close_to_pad = false
	
	if is_multiplayer:
		# Check proximity to any launchpad
		var launchpad_positions = [Vector2(300, 1221), Vector2(600, 1221), Vector2(900, 1221)]
		for pad_pos in launchpad_positions:
			var distance_to_pad = global_position.distance_to(pad_pos)
			var y_distance = abs(global_position.y - (pad_pos.y - 40))
			if distance_to_pad < 100 and y_distance < 20:
				close_to_pad = true
				break
	else:
		# Single player proximity check
		var launchpad = get_node_or_null("/root/Game/Launchpad")
		if launchpad:
			var distance_to_pad = global_position.distance_to(launchpad.global_position)
			var y_distance = abs(global_position.y - (launchpad.global_position.y - 40))
			close_to_pad = distance_to_pad < 100 and y_distance < 20
	
	if on_launchpad or (close_to_pad and is_on_ground):
		# Check if player is not pressing burst key
		# Need to check if thrusting based on authority
		var is_thrusting = false
		if is_multiplayer_authority() or not get_multiplayer().has_multiplayer_peer():
			is_thrusting = Input.is_action_pressed("ui_up")
		else:
			is_thrusting = remote_input_up
		
		if not is_thrusting:
			time_settled_on_pad += delta
			# Reset launch state when on pad without thrust
			if is_launching:
				is_launching = false
				launch_shake_timer = 0.0
				shake_offset = Vector2.ZERO
		else:
			time_settled_on_pad = 0.0
	else:
		time_settled_on_pad = 0.0
	
	# Check ground collision if not on launchpad
	if not on_launchpad:
		var ground_node = get_node_or_null("/root/Game/Ground")
		if not ground_node:
			ground_node = get_node_or_null("/root/MultiplayerGame/Ground")
		if ground_node:
			var ground_y = ground_node.global_position.y
			var ship_bottom = global_position.y + 30  # Half of ship height (doubled)
			
			# Debug output
			if global_position.y > 1400:  # Only print when near ground
				print("Ship Y: ", global_position.y, " Ground Y: ", ground_y)
			
			# Check if ANY part of the ship hits the ground
			# Get all key points of the ship in world space
			var ship_transform = Transform2D(rotation, global_position)
			
			# Define ship boundary points (including nose, body corners, and wing tips)
			var check_points = [
				Vector2(0, -40),      # Nose tip
				Vector2(-10, -30),    # Nose left
				Vector2(10, -30),     # Nose right
				Vector2(-10, -30),    # Body top left
				Vector2(10, -30),     # Body top right
				Vector2(-10, 30),     # Body bottom left
				Vector2(10, 30),      # Body bottom right
				Vector2(-25, 30),     # Left wing tip
				Vector2(25, 30),      # Right wing tip
				Vector2(-10, 0),      # Left wing base
				Vector2(10, 0),       # Right wing base
				Vector2(0, 30)        # Bottom center
			]
			
			# Check if any point touches the ground
			var touching_ground = false
			for point in check_points:
				var world_point = ship_transform * point
				if world_point.y >= ground_y:
					touching_ground = true
					print("Ground collision at point ", point, "! World Y: ", world_point.y, " Ground Y: ", ground_y)
					break
			
			if touching_ground:
				# Hit ground - always shatter
				# Find the actual impact point
				var impact_point = global_position
				for point in check_points:
					var world_point = ship_transform * point
					if world_point.y >= ground_y:
						impact_point = world_point
						break
				shatter(impact_point)
				return
			else:
				is_on_ground = false
				# Reset launch state if we're not on ground anymore
				if is_launching and launch_shake_timer >= launch_shake_duration:
					is_launching = false

func apply_gravity(delta: float) -> void:
	# Check for planets and calculate gravity
	var planets = get_tree().get_nodes_in_group("planets")
	var near_planet = false
	var planet_gravity = Vector2.ZERO
	var closest_planet = null
	var closest_distance = INF
	
	for planet in planets:
		if not is_instance_valid(planet):
			continue
			
		var distance = global_position.distance_to(planet.global_position)
		
		# Check if within planet's gravity influence
		if distance <= planet.gravity_influence_distance:
			near_planet = true
			
			# Track closest planet for orbit detection
			if distance < closest_distance:
				closest_distance = distance
				closest_planet = planet
			
			# Simplified gravity calculation
			var gravity_factor = 1.0 - (distance / planet.gravity_influence_distance)
			gravity_factor = gravity_factor * gravity_factor
			
			var force_magnitude = planet.gravity_strength * gravity_factor * planet.mass
			var direction = (planet.global_position - global_position).normalized()
			planet_gravity += direction * force_magnitude
	
	# Apply appropriate gravity
	if near_planet and closest_planet:
		# Apply planetary gravity
		velocity += planet_gravity * delta
		is_near_planet = true
		
		# Track orbit progress
		update_orbit_tracking(closest_planet, delta)
	else:
		# Apply ground gravity when not near planets and not on ground
		if not is_on_ground:
			# Try both single-player and multiplayer paths
			var ground_node = get_node_or_null("/root/Game/Ground")
			if not ground_node:
				ground_node = get_node_or_null("/root/MultiplayerGame/Ground")
			
			if ground_node:
				# Check if above ground
				if global_position.y < ground_node.global_position.y:
					velocity.y += ground_node.gravity_strength * delta
		is_near_planet = false
		
		# Don't reset orbit tracking when leaving planet influence
		# Keep the visual progress showing
		if orbiting_planet and not pending_score:
			# Just clear the reference but keep the planet showing progress
			orbiting_planet = null

func get_bottom_corners() -> Array:
	# Returns [left_corner, right_corner] in world space
	var ship_transform = Transform2D(rotation, global_position)
	var half_width = 10.0
	var half_height = 30.0  # Doubled from 15 to 30
	
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
		return false  # No collision
	
	if not (left_over_platform or right_over_platform):
		return false  # Not over platform
	
	# Check if ship is landing butt-down (mostly upright)
	var norm_rot = fmod(rotation + PI, TAU) - PI
	var is_mostly_upright = abs(norm_rot) < PI/3  # Within 60 degrees of upright
	
	# Check for high-speed crash - but be more lenient if landing upright
	var crash_threshold = 500 if is_mostly_upright else 350
	if velocity.y > crash_threshold and landing_grace <= 0:
		shatter()
		return true
	
	is_on_ground = true
	
	# Handle different collision cases
	if left_below and right_below and left_over_platform and right_over_platform:
		# Both corners touching - stable landing
		# Only check if the ship is landing on its side (sides touching platform)
		# Check if the ship is rotated close to sideways (around ±90 degrees)
		# If the ship is around ±90 degrees, it means it's landing on its side
		if (abs(norm_rot - PI/2) < PI/4 or abs(norm_rot + PI/2) < PI/4) and landing_grace <= 0:
			# Ship is landing on its side - shatter
			shatter()
			return true
		handle_stable_landing(platform_y, left_corner, right_corner)
		# Set landing grace period
		landing_grace = 0.2  # Always set grace period when landing
	elif left_below and left_over_platform:
		# Left corner pivot
		handle_corner_pivot(left_corner, platform_y, true, delta)
	elif right_below and right_over_platform:
		# Right corner pivot
		handle_corner_pivot(right_corner, platform_y, false, delta)
	
	return true

func handle_stable_landing(platform_y: float, left_corner: Vector2, right_corner: Vector2) -> void:
	# Calculate average penetration
	var avg_penetration = ((left_corner.y + right_corner.y) / 2.0) - platform_y
	
	# Lift ship to sit on platform
	global_position.y -= avg_penetration
	
	# Stop downward motion
	velocity.y = min(velocity.y, 0)
	
	# Dampen rotation toward level
	angular_velocity *= 0.7
	
	# Apply friction
	velocity.x *= 0.9

func handle_corner_pivot(corner: Vector2, platform_y: float, is_left: bool, delta: float) -> void:
	# Create pivot point at platform level
	var pivot = Vector2(corner.x, platform_y)
	
	# Calculate torque from gravity
	var lever_arm = global_position.x - pivot.x
	var gravity_torque = lever_arm * 0.02  # Gravity effect
	angular_velocity += gravity_torque
	
	# Apply damping
	angular_velocity *= 0.95
	
	# Rotate around pivot
	var new_angle = rotation + angular_velocity * delta
	
	# Calculate where the corner would be after rotation
	var offset_from_center = Vector2(-10 if is_left else 10, 30)  # Doubled height
	var new_corner = global_position + offset_from_center.rotated(new_angle)
	
	# Adjust position to keep corner at pivot
	global_position += pivot - new_corner
	rotation = new_angle
	
	# Stop vertical motion, reduce horizontal
	velocity.y = 0
	velocity.x *= 0.85
	
	# Check for tip over - only shatter if landing on side
	# Normalize rotation to [-PI, PI]
	var norm_rot = fmod(rotation + PI, TAU) - PI
	# Only shatter if the ship has tipped far enough to be landing on its side
	if (abs(norm_rot - PI/2) < PI/6 or abs(norm_rot + PI/2) < PI/6) and landing_grace <= 0:
		# Ship has tipped onto its side
		shatter()

func _draw() -> void:
	# Apply shake offset visually
	var apply_shake = false
	var current_shake_offset = Vector2.ZERO
	
	if is_multiplayer_authority() or not get_multiplayer().has_multiplayer_peer():
		# Local player or single player - use local shake state
		if is_launching and launch_shake_timer < launch_shake_duration:
			apply_shake = true
			current_shake_offset = shake_offset
	else:
		# Remote player - use local shake state (calculated from physics)
		if is_launching and launch_shake_timer < launch_shake_duration:
			apply_shake = true
			current_shake_offset = shake_offset
	
	if apply_shake:
		draw_set_transform(current_shake_offset, 0.0, Vector2.ONE)
	
	if not is_shattered:
		# Choose color based on gravity state
		var current_color = ship_color
		if is_near_planet:
			if orbiting_planet:
				# Show orbit progress with color gradient
				var orbit_progress = abs(orbit_total_angle) / (TAU * 0.75)
				current_color = Color.CYAN.lerp(Color.YELLOW, orbit_progress)
			else:
				current_color = Color.GREEN
		
		# Draw ship body (rectangle) as fuel gauge with square bottom
		var body_size = Vector2(20, 60)  # Doubled height from 30 to 60
		var body_pos = Vector2(-body_size.x / 2, -body_size.y / 2)
		
		# Draw empty fuel tank (dark background)
		draw_rect(Rect2(body_pos, body_size), Color(0.2, 0.2, 0.2))
		
		# Draw fuel level
		var fuel_percentage = current_fuel / max_fuel
		var fuel_height = body_size.y * fuel_percentage
		var fuel_pos = Vector2(body_pos.x, body_pos.y + body_size.y - fuel_height)
		var fuel_size = Vector2(body_size.x, fuel_height)
		
		# Choose fuel color based on level
		var fuel_color = current_color
		if fuel_percentage < 0.25:
			fuel_color = Color.RED  # Low fuel warning
		elif fuel_percentage < 0.5:
			fuel_color = Color.ORANGE  # Medium fuel
		
		draw_rect(Rect2(fuel_pos, fuel_size), fuel_color)
		
		# Draw outline with emphasis on square bottom
		draw_rect(Rect2(body_pos, body_size), current_color, false, 2.0)
		
		# Draw thicker bottom edge to emphasize square bottom
		var bottom_left = Vector2(body_pos.x, body_pos.y + body_size.y)
		var bottom_right = Vector2(body_pos.x + body_size.x, body_pos.y + body_size.y)
		draw_line(bottom_left, bottom_right, current_color, 3.0)
		
		# Draw ship nose (sharper triangle with full body width base)
		var triangle_points = PackedVector2Array([
			Vector2(0, -40),      # Tip (pointing up) - adjusted for taller body
			Vector2(-10, -30),    # Left corner - full body width
			Vector2(10, -30)      # Right corner - full body width
		])
		draw_polygon(triangle_points, PackedColorArray([current_color]))
		
		# Draw wings (triangles from midpoint to bottom of body)
		var left_wing_points = PackedVector2Array([
			Vector2(-10, 0),      # Wing base at body midpoint
			Vector2(-25, 30),     # Wing tip at bottom level (doubled)
			Vector2(-10, 30)      # Back to body bottom (doubled)
		])
		draw_polygon(left_wing_points, PackedColorArray([current_color]))
		
		var right_wing_points = PackedVector2Array([
			Vector2(10, 0),       # Wing base at body midpoint
			Vector2(25, 30),      # Wing tip at bottom level (doubled)
			Vector2(10, 30)       # Back to body bottom (doubled)
		])
		draw_polygon(right_wing_points, PackedColorArray([current_color]))
		
		# Draw dual rocket engines if in dual rocket mode
		if dual_rocket_mode:
			# Left rocket
			var left_rocket_rect = Rect2(-15, 25, 6, 10)
			draw_rect(left_rocket_rect, current_color)
			
			# Right rocket
			var right_rocket_rect = Rect2(9, 25, 6, 10)
			draw_rect(right_rocket_rect, current_color)
			
			# Draw thrust flames for dual rockets
			if left_rocket_firing and current_fuel > 0:
				var left_flame_points = PackedVector2Array([
					Vector2(-12, 35),
					Vector2(-15, 42),
					Vector2(-9, 42)
				])
				draw_polygon(left_flame_points, PackedColorArray([Color.ORANGE]))
			
			if right_rocket_firing and current_fuel > 0:
				var right_flame_points = PackedVector2Array([
					Vector2(12, 35),
					Vector2(9, 42),
					Vector2(15, 42)
				])
				draw_polygon(right_flame_points, PackedColorArray([Color.ORANGE]))
		
		# Draw thrust indicator when thrusting (and have fuel) - only in single rocket mode
		var should_show_thrust = false
		if is_multiplayer_authority() or not get_multiplayer().has_multiplayer_peer():
			# Local player or single player - check input
			should_show_thrust = not dual_rocket_mode and Input.is_action_pressed("ui_up") and (current_fuel > 0 or is_ascension_mode)
		else:
			# Remote player - use synced thrust state
			should_show_thrust = not dual_rocket_mode and remote_input_up and (current_fuel > 0 or is_ascension_mode)
		
		if should_show_thrust:
			var thrust_points = PackedVector2Array([
				Vector2(-5, 30),      # Left (doubled)
				Vector2(0, 40),       # Bottom tip (doubled)
				Vector2(5, 30)        # Right (doubled)
			])
			draw_polygon(thrust_points, PackedColorArray([Color.ORANGE]))
			
			# Debug: Draw spawn point for smoke
			var spawn_offset = Vector2(0, 35)  # Adjusted for taller ship
			draw_circle(spawn_offset, 3, Color.RED)
		
		# Debug: Draw bottom corners
		var debug_bottom_left = Vector2(-10, 30)  # Doubled
		var debug_bottom_right = Vector2(10, 30)  # Doubled
		draw_circle(debug_bottom_left, 2, Color.GREEN)
		draw_circle(debug_bottom_right, 2, Color.GREEN)
		
		# Removed "Return to pad!" text - launchpad now blinks instead
	else:
		# Draw shattered pieces
		for piece in pieces:
			var transform = Transform2D()
			transform = transform.rotated(piece.rotation)
			transform = transform.translated(piece.position - position)
			
			draw_set_transform_matrix(transform)
			
			var color = ship_color
			color.a = piece.alpha
			
			if piece.has("is_top_half") and piece.is_top_half:
				# Draw top half of ship (nose and upper body)
				# The top half body goes from y=-15 to y=15 (30 pixels tall)
				var body_rect = Rect2(-10, -15, 20, 30)
				
				# Draw empty fuel tank background
				var dark_color = Color(0.2, 0.2, 0.2)
				dark_color.a = piece.alpha
				draw_rect(body_rect, dark_color, true)
				
				# Draw fuel level in upper body (shows fuel from 50% to 100%)
				if piece.has("fuel_percentage") and piece.fuel_percentage > 0.5:
					# Top half only shows fuel above 50%
					var top_half_fuel = (piece.fuel_percentage - 0.5) * 2.0  # Convert 0.5-1.0 to 0.0-1.0
					var fuel_height = 30 * top_half_fuel
					# Fuel fills from bottom up: starts at y=15, goes up by fuel_height
					var fuel_rect = Rect2(-10, 15 - fuel_height, 20, fuel_height)
					
					# Choose fuel color based on level
					var fuel_color = color
					if piece.fuel_percentage < 0.25:
						fuel_color = Color.RED
					elif piece.fuel_percentage < 0.5:
						fuel_color = Color.ORANGE
					fuel_color.a = piece.alpha
					
					draw_rect(fuel_rect, fuel_color, true)
				
				# Draw body outline
				draw_rect(body_rect, color, false, 2.0)
				
				# Draw nose (extends above the body)
				var nose_points = PackedVector2Array([
					Vector2(0, -25),
					Vector2(-10, -15),
					Vector2(10, -15)
				])
				draw_polygon(nose_points, PackedColorArray([color]))
			elif piece.has("is_bottom_half") and piece.is_bottom_half:
				# Draw bottom half (lower body and wings)
				# The bottom half body goes from y=-15 to y=15 (30 pixels tall)
				var body_rect = Rect2(-10, -15, 20, 30)
				
				# Draw empty fuel tank background
				var dark_color = Color(0.2, 0.2, 0.2)
				dark_color.a = piece.alpha
				draw_rect(body_rect, dark_color, true)
				
				# Draw fuel level in lower body (shows fuel from 0% to 50%)
				if piece.has("fuel_percentage") and piece.fuel_percentage > 0:
					# Bottom half shows fuel up to 50%
					var bottom_half_fuel = min(piece.fuel_percentage * 2.0, 1.0)  # Convert 0.0-0.5 to 0.0-1.0
					var fuel_height = 30 * bottom_half_fuel
					# Fuel fills from bottom up: starts at y=15, goes up by fuel_height
					var fuel_rect = Rect2(-10, 15 - fuel_height, 20, fuel_height)
					
					# Choose fuel color based on level
					var fuel_color = color
					if piece.fuel_percentage < 0.25:
						fuel_color = Color.RED
					elif piece.fuel_percentage < 0.5:
						fuel_color = Color.ORANGE
					fuel_color.a = piece.alpha
					
					draw_rect(fuel_rect, fuel_color, true)
				
				# Draw body outline
				draw_rect(body_rect, color, false, 2.0)
				
				# Draw left wing (connects to body)
				var left_wing = PackedVector2Array([
					Vector2(-10, -15),
					Vector2(-25, 15),
					Vector2(-10, 15)
				])
				draw_polygon(left_wing, PackedColorArray([color]))
				
				# Draw right wing (connects to body)
				var right_wing = PackedVector2Array([
					Vector2(10, -15),
					Vector2(25, 15),
					Vector2(10, 15)
				])
				draw_polygon(right_wing, PackedColorArray([color]))
			else:
				# Draw debris as small rectangles
				var rect = Rect2(-piece.size / 2, piece.size)
				draw_rect(rect, color, true)
			
			draw_set_transform_matrix(Transform2D())
	
	# Reset transform after shake
	if apply_shake:
		draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
	

func update_orbit_tracking(planet, delta: float) -> void:
	var to_spaceship = global_position - planet.global_position
	var current_angle = to_spaceship.angle()
	
	if orbiting_planet != planet:
		# Switch to tracking new planet but preserve any progress
		orbiting_planet = planet
		
		# Only reset if we haven't started tracking yet or it's a different planet
		if not orbit_started or tracked_planet != planet:
			orbit_start_angle = current_angle
			orbit_current_angle = current_angle
			orbit_total_angle = 0.0
			has_completed_orbit = false
			orbit_started = true
			tracked_planet = planet
			# Tell planet to start tracking
			planet.start_orbit_tracking(self, orbit_start_angle)
		else:
			# Re-entering gravity of same planet we were tracking
			orbit_current_angle = current_angle
			# Resume visual tracking
			planet.start_orbit_tracking(self, orbit_start_angle)
			var progress = abs(orbit_total_angle) / (TAU * 0.75)
			var direction = 1 if orbit_total_angle > 0 else -1
			planet.update_orbit_progress(progress, direction)
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
		
		# Update planet's progress display
		var progress = abs(orbit_total_angle) / (TAU * 0.75)
		var direction = 1 if orbit_total_angle > 0 else -1  # Positive for CCW, negative for CW
		planet.update_orbit_progress(progress, direction)
		
		# Check for complete orbit (270 degrees is enough)
		if abs(orbit_total_angle) >= TAU * 0.75 and not has_completed_orbit:
			has_completed_orbit = true
			planet.complete_orbit()  # Trigger the fill-in animation
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
	orbit_started = false  # Reset this so we can track a new planet

func on_orbit_completed() -> void:
	# Set pending score - need to return to launchpad
	pending_score = true
	completed_planet = orbiting_planet  # Store the planet that was orbited
	
	# Activate launchpad visual
	var launchpad = get_node_or_null("/root/Game/Launchpad")
	if launchpad:
		launchpad.activate()
	else:
		# In multiplayer, notify server to activate the player's launchpad
		var multiplayer_client = get_node_or_null("/root/MultiplayerGame")
		if multiplayer_client and is_multiplayer_authority():
			var color_index = multiplayer_client.my_color_index
			# Send RPC to server to activate launchpad for all clients
			multiplayer_client.rpc_id(1, "request_activate_launchpad", multiplayer_client.my_peer_id, color_index + 1)

func check_screen_boundaries() -> void:
	# Check if we're in ascension mode
	var multiplayer_client = get_node_or_null("/root/MultiplayerGame")
	var is_ascending = multiplayer_client and multiplayer_client.is_ascending
	
	# During ascension, only apply boundaries to local player
	if is_ascending and not is_multiplayer_authority():
		return
	
	# Before ascension, apply normal boundaries to all players
	if not is_ascending and not is_multiplayer_authority():
		# For non-local players before ascension, only apply basic boundaries
		var viewport = get_viewport_rect()
		var margin = 35
		var bounce_damping = 0.8
		
		# Left/right boundaries
		if position.x - margin < 0:
			position.x = margin
			velocity.x = abs(velocity.x) * bounce_damping
		elif position.x + margin > viewport.size.x:
			position.x = viewport.size.x - margin
			velocity.x = -abs(velocity.x) * bounce_damping
		
		# Top boundary at y=0 for non-local players before ascension
		if position.y - margin < 0:
			position.y = margin
			velocity.y = abs(velocity.y) * bounce_damping
		
		return
		
	# Local player boundaries
	var viewport = get_viewport_rect()
	var margin = 35  # Increased to account for taller ship and wings
	var bounce_damping = 0.8  # Reduce velocity on bounce
	
	# Get camera for top boundary
	var camera = get_viewport().get_camera_2d()
	var top_boundary = 0.0
	
	# Apply camera-based boundary during ascension for local player
	if camera and is_ascending:
		# Top boundary is half viewport height above camera center
		top_boundary = camera.global_position.y - viewport.size.y / 2
	
	# Left boundary
	if position.x - margin < 0:
		position.x = margin
		velocity.x = abs(velocity.x) * bounce_damping
	
	# Right boundary
	elif position.x + margin > viewport.size.x:
		position.x = viewport.size.x - margin
		velocity.x = -abs(velocity.x) * bounce_damping
	
	# Top boundary (camera-relative during ascension, otherwise y=0)
	if position.y - margin < top_boundary:
		position.y = top_boundary + margin
		velocity.y = abs(velocity.y) * bounce_damping
	
	# Bottom boundary - use camera position during ascension
	var bottom_boundary = viewport.size.y
	if camera and is_ascending:
		# Bottom boundary is half viewport height below camera center
		bottom_boundary = camera.global_position.y + viewport.size.y / 2
	
	if position.y + margin > bottom_boundary:
		position.y = bottom_boundary - margin
		velocity.y = -abs(velocity.y) * bounce_damping

func check_planet_collision() -> void:
	var planets = get_tree().get_nodes_in_group("planets")
	for planet in planets:
		if not is_instance_valid(planet):
			continue
		
		var distance = global_position.distance_to(planet.global_position)
		if distance <= planet.radius + 30:  # Increased for taller ship and wings
			# Calculate impact point on the line between ship and planet
			var to_planet = (planet.global_position - global_position).normalized()
			var impact_point = global_position + to_planet * 30
			shatter(impact_point)
			return
	
	# Check asteroid collisions
	var asteroids = get_tree().get_nodes_in_group("asteroids")
	for asteroid in asteroids:
		if not is_instance_valid(asteroid):
			continue
		
		var distance = global_position.distance_to(asteroid.global_position)
		if distance <= asteroid.get_radius() + 30:  # Increased for taller ship and wings
			# Calculate impact point on the line between ship and asteroid
			var to_asteroid = (asteroid.global_position - global_position).normalized()
			var impact_point = global_position + to_asteroid * 30
			shatter(impact_point)
			return

func shatter(impact_point: Vector2 = Vector2.ZERO) -> void:
	is_shattered = true
	pieces.clear()
	shatter_timer = 0.0
	
	# Reset orbit tracking if we were orbiting
	if orbiting_planet or tracked_planet:
		reset_orbit_tracking()
	
	# Calculate impact point in local space
	var local_impact = (impact_point - global_position).rotated(-rotation)
	
	# Determine which half of the ship was hit
	var impact_on_top = local_impact.y < 0
	
	# Calculate fuel percentage
	var fuel_percent = 0.0
	if max_fuel > 0:
		fuel_percent = current_fuel / max_fuel
	
	print("Shattering with fuel: ", current_fuel, "/", max_fuel, " = ", fuel_percent)
	
	# Create two main halves at their actual positions
	# Top half (nose and upper body) - positioned at the top section of the ship
	var top_half = {
		"position": position + Vector2(0, -15).rotated(rotation),  # Offset to top half position
		"velocity": Vector2.ZERO,  # Will be set based on impact
		"rotation": rotation,
		"angular_velocity": 0.0,  # Will be set based on impact
		"size": Vector2(30, 30),  # Top section size
		"is_top_half": true,
		"fuel_percentage": fuel_percent,  # Store fuel level
		"alpha": 1.0
	}
	
	# Bottom half (lower body and wings) - positioned at the bottom section of the ship
	var bottom_half = {
		"position": position + Vector2(0, 15).rotated(rotation),  # Offset to bottom half position
		"velocity": Vector2.ZERO,  # Will be set based on impact
		"rotation": rotation,
		"angular_velocity": 0.0,  # Will be set based on impact
		"size": Vector2(50, 30),  # Bottom section with wings
		"is_bottom_half": true,
		"fuel_percentage": fuel_percent,  # Store fuel level
		"alpha": 1.0
	}
	
	# Apply realistic physics based on impact
	if impact_point != Vector2.ZERO:
		# Calculate impact force direction (opposite of collision normal)
		var impact_force_direction = (global_position - impact_point).normalized()
		var impact_force_magnitude = 50.0  # Much slower movement
		
		# Simple separation based on which half was hit
		if impact_on_top:
			# Top half was hit - it moves away slowly
			top_half.velocity = Vector2(0, -30).rotated(rotation) + impact_force_direction * impact_force_magnitude
			bottom_half.velocity = Vector2(0, 30).rotated(rotation)
			
			# Gentle rotation
			top_half.angular_velocity = randf_range(0.5, 1.5) * sign(local_impact.x)
			bottom_half.angular_velocity = randf_range(0.2, 0.5) * -sign(local_impact.x)
		else:
			# Bottom half was hit - it moves away slowly
			bottom_half.velocity = Vector2(0, 30).rotated(rotation) + impact_force_direction * impact_force_magnitude
			top_half.velocity = Vector2(0, -30).rotated(rotation)
			
			# Gentle rotation
			bottom_half.angular_velocity = randf_range(0.5, 1.5) * sign(local_impact.x)
			top_half.angular_velocity = randf_range(0.2, 0.5) * -sign(local_impact.x)
		
		# Add tiny bit of randomness
		top_half.velocity += Vector2(randf_range(-10, 10), randf_range(-10, 10))
		bottom_half.velocity += Vector2(randf_range(-10, 10), randf_range(-10, 10))
	else:
		# No specific impact point - gentle separation
		top_half.velocity = Vector2(0, -30).rotated(rotation) + Vector2(randf_range(-20, 20), randf_range(-20, 20))
		bottom_half.velocity = Vector2(0, 30).rotated(rotation) + Vector2(randf_range(-20, 20), randf_range(-20, 20))
		top_half.angular_velocity = randf_range(-0.5, 0.5)
		bottom_half.angular_velocity = randf_range(-0.5, 0.5)
	
	pieces.append(top_half)
	pieces.append(bottom_half)
	
	# Add some smaller debris pieces
	for i in range(6):
		var piece = {
			"position": position + Vector2(randf_range(-20, 20), randf_range(-20, 20)),
			"velocity": Vector2(randf_range(-150, 150), randf_range(-100, 100)),
			"rotation": randf() * TAU,
			"angular_velocity": randf_range(-5, 5),
			"size": Vector2(randf_range(3, 8), randf_range(3, 8)),
			"is_debris": true,
			"alpha": 1.0
		}
		pieces.append(piece)
	
	# Clear velocity
	velocity = Vector2.ZERO

func update_shatter(delta: float) -> void:
	shatter_timer += delta
	
	# Update pieces
	for piece in pieces:
		piece.position += piece.velocity * delta
		piece.velocity.x *= 0.99  # Less friction for smoother movement
		piece.velocity.y += 50 * delta  # Much less gravity for floating effect
		
		# Update rotation with angular velocity
		if piece.has("angular_velocity"):
			piece.rotation += piece.angular_velocity * delta
		else:
			piece.rotation += delta * 0.5  # Slower default rotation
		
		piece.alpha = max(0, 1.0 - (shatter_timer / fade_duration))
	
	# Respawn after delay (but not in battle mode)
	if shatter_timer >= fade_duration + respawn_delay and not battle_mode:
		respawn()

func respawn() -> void:
	is_shattered = false
	pieces.clear()
	shatter_timer = 0.0
	
	# Check if this is a multiplayer game
	var is_multiplayer = get_parent() and get_parent().name == "Players"
	
	if is_multiplayer:
		# Multiplayer respawn - find the correct launchpad based on color
		var my_authority = get_multiplayer_authority()
		var players_node = get_parent()
		var game_node = players_node.get_parent()
		
		# Determine which launchpad based on player order/color
		var launchpad_positions = [
			Vector2(300, 1221 - 40),   # Left launchpad
			Vector2(600, 1221 - 40),   # Middle launchpad  
			Vector2(900, 1221 - 40)    # Right launchpad
		]
		
		# Find player's color index by checking ship color
		var color_index = 0
		if ship_color == Color.YELLOW:
			color_index = 0
		elif ship_color == Color.LIGHT_BLUE:
			color_index = 1
		else:  # Red
			color_index = 2
			
		position = launchpad_positions[color_index]
		rotation = 0
	else:
		# Single player respawn
		var launchpad = get_node_or_null("/root/Game/Launchpad")
		if launchpad:
			position = Vector2(launchpad.global_position.x, launchpad.global_position.y - 40)
			rotation = 0
		else:
			var ground_node = get_node_or_null("/root/Game/Ground")
			if not ground_node:
				ground_node = get_node_or_null("/root/MultiplayerGame/Ground")
			if ground_node:
				position = Vector2(600, ground_node.global_position.y - 45)
			else:
				position = Vector2(600, 400)
	
	# Deactivate launchpad if we had a pending score (check before resetting)
	var had_pending_score = pending_score
	if had_pending_score:
		if is_multiplayer:
			# In multiplayer, notify server to deactivate
			var multiplayer_client = get_node_or_null("/root/MultiplayerGame")
			if multiplayer_client and is_multiplayer_authority():
				var color_index = multiplayer_client.my_color_index
				multiplayer_client.rpc_id(1, "request_deactivate_launchpad", multiplayer_client.my_peer_id, color_index + 1)
		else:
			# Single player
			var launchpad = get_node_or_null("/root/Game/Launchpad")
			if launchpad:
				launchpad.deactivate()
	
	# Reset other properties
	velocity = Vector2.ZERO
	angular_velocity = 0.0  # Reset angular velocity
	current_fuel = max_fuel
	is_on_ground = true
	is_near_planet = false
	orbiting_planet = null
	tracked_planet = null
	has_completed_orbit = false
	pending_score = false
	completed_planet = null
	orbit_started = false  # Reset orbit tracking
	orbit_total_angle = 0.0
	startup_grace = 0.5  # Longer grace period
	landing_grace = 0.0  # Reset landing grace
	is_launching = false  # Reset launch state
	launch_shake_timer = 0.0
	shake_offset = Vector2.ZERO


func check_launchpad() -> void:
	if not pending_score:
		return
	
	var on_pad = false
	var launchpad_found = null
	
	# Check single player launchpad first
	var single_launchpad = get_node_or_null("/root/Game/Launchpad")
	if single_launchpad:
		on_pad = single_launchpad.is_spaceship_on_pad(global_position)
		if on_pad:
			launchpad_found = single_launchpad
	else:
		# Check multiplayer launchpads
		var launchpads = []
		launchpads.append(get_node_or_null("/root/MultiplayerGame/Launchpad1"))
		launchpads.append(get_node_or_null("/root/MultiplayerGame/Launchpad2"))
		launchpads.append(get_node_or_null("/root/MultiplayerGame/Launchpad3"))
		
		for pad in launchpads:
			if pad and pad.is_spaceship_on_pad(global_position):
				on_pad = true
				launchpad_found = pad
				break
	
	if on_pad and is_on_ground and launchpad_found:
		# Score the point
		score += 1
		pending_score = false
		print("Score! Total: ", score)
		
		# Handle launchpad deactivation
		var is_multiplayer_game = get_multiplayer().has_multiplayer_peer()
		if is_multiplayer_game:
			# In multiplayer, notify server to deactivate for all clients
			var multiplayer_client = get_node_or_null("/root/MultiplayerGame")
			if multiplayer_client and is_multiplayer_authority():
				var color_index = multiplayer_client.my_color_index
				multiplayer_client.rpc_id(1, "request_deactivate_launchpad", multiplayer_client.my_peer_id, color_index + 1)
				
				if completed_planet:
					# Find planet ID by checking server_planets
					for planet_id in multiplayer_client.server_planets:
						if multiplayer_client.server_planets[planet_id] == completed_planet:
							print("Notifying server about planet completion: ", planet_id)
							multiplayer_client.rpc_id(1, "planet_completed", planet_id)
							# Also notify about score for countdown
							multiplayer_client.rpc_id(1, "player_scored", multiplayer_client.my_peer_id, planet_id)
							break
		else:
			# Single player - deactivate directly
			launchpad_found.deactivate()
		
		# Mark the planet as orbited so it fades out
		if completed_planet and is_instance_valid(completed_planet):
			print("Marking planet as orbited")
			completed_planet.mark_as_orbited()
			completed_planet = null
		else:
			print("No valid completed_planet to mark as orbited")
		
		# Reset orbit tracking now that we've successfully scored
		reset_orbit_tracking()

func spawn_smoke_burst() -> void:
	# Create one soft body particle at a time
	var smoke = smoke_scene.instantiate()
	
	# Position at the back of the spaceship (spaceship points up by default)
	var spawn_offset = Vector2(0, 35).rotated(rotation)  # Adjusted for taller ship
	
	# Set initial velocity opposite to thrust direction with wider spread
	var base_direction = Vector2.DOWN.rotated(rotation)
	var spread_angle = randf_range(-0.6, 0.6)  # About 34 degrees spread on each side
	var smoke_direction = base_direction.rotated(spread_angle)
	
	# Smoke moves opposite to thrust but slower
	var smoke_speed = randf_range(50, 100)  # Much slower initial speed
	smoke.initial_velocity = smoke_direction * smoke_speed + velocity * 0.1
	
	# Randomize properties
	smoke.radius = randf_range(10, 15)
	smoke.num_points = randi_range(8, 12)  # More points for smoother circles
	smoke.stiffness = randf_range(0.85, 0.95)  # Much stiffer
	smoke.pressure = randf_range(70, 90)  # Higher pressure
	# Lifetime is now handled by animation phases in the particle itself
	
	# Add to the root of the scene for proper positioning
	var root = get_tree().root.get_child(0)
	root.add_child(smoke)
	smoke.global_position = global_position + spawn_offset

func handle_remote_smoke_effects(delta: float) -> void:
	# Handle smoke spawning for remote players based on their state
	if dual_rocket_mode:
		# Handle dual rocket smoke
		smoke_spawn_timer += delta
		if smoke_spawn_timer >= smoke_spawn_interval:
			# Note: for remote players, left_rocket_firing and right_rocket_firing
			# are set by handle_dual_rocket_input based on remote inputs
			if left_rocket_firing and (current_fuel > 0 or is_ascension_mode):
				spawn_dual_rocket_smoke(true)
			if right_rocket_firing and (current_fuel > 0 or is_ascension_mode):
				spawn_dual_rocket_smoke(false)
			if (left_rocket_firing or right_rocket_firing) and (current_fuel > 0 or is_ascension_mode):
				smoke_spawn_timer = 0.0
		
		if not (left_rocket_firing or right_rocket_firing) or (current_fuel <= 0 and not is_ascension_mode):
			smoke_spawn_timer = 0.0
	else:
		# Handle single thruster smoke
		if remote_input_up and (current_fuel > 0 or is_ascension_mode):
			smoke_spawn_timer += delta
			if smoke_spawn_timer >= smoke_spawn_interval:
				spawn_smoke_burst()
				smoke_spawn_timer = 0.0
		else:
			smoke_spawn_timer = 0.0


func check_spaceship_collisions() -> void:
	# Only check collisions in multiplayer
	if not get_multiplayer().has_multiplayer_peer():
		return
		
	# Get other spaceships
	var spaceships = get_tree().get_nodes_in_group("spaceships")
	if spaceships.is_empty():
		# Try to find players in multiplayer
		var multiplayer_game = get_node_or_null("/root/MultiplayerGame")
		if multiplayer_game:
			var players_container = multiplayer_game.get_node_or_null("Players")
			if players_container:
				spaceships = players_container.get_children()
	
	for other in spaceships:
		if other == self or not is_instance_valid(other):
			continue
		
		# Make sure it's actually a spaceship with the is_shattered property
		if not "is_shattered" in other or other.is_shattered:
			continue
			
		var distance = global_position.distance_to(other.global_position)
		var min_distance = 60.0  # Two spaceship radii
		
		if distance < min_distance and distance > 0.001:
			# Collision detected - calculate bounce
			var collision_normal = (global_position - other.global_position).normalized()
			var overlap = min_distance - distance
			
			# Separate the spaceships
			position += collision_normal * (overlap * 0.5)
			other.position -= collision_normal * (overlap * 0.5)
			
			# Calculate relative velocity
			var relative_velocity = velocity - other.velocity
			var velocity_along_normal = relative_velocity.dot(collision_normal)
			
			# Only resolve if moving towards each other
			if velocity_along_normal < 0:
				# Apply impulse for bounce
				var restitution = 0.8
				var impulse = collision_normal * velocity_along_normal * restitution
				
				velocity -= impulse
				other.velocity += impulse

func apply_state_correction(new_position: Vector2, new_rotation: float, new_velocity: Vector2, new_fuel: float) -> void:
	# Only apply corrections for remote players
	if is_multiplayer_authority() or not get_multiplayer().has_multiplayer_peer():
		return
	
	# Direct state update from server
	position = new_position
	rotation = new_rotation
	velocity = new_velocity
	current_fuel = new_fuel

func angle_difference(from: float, to: float) -> float:
	var diff = to - from
	while diff > PI:
		diff -= TAU
	while diff < -PI:
		diff += TAU
	return diff

func spawn_dual_rocket_smoke(is_left: bool) -> void:
	var smoke = smoke_scene.instantiate()
	
	# Position at the appropriate rocket
	var rocket_x = -12 if is_left else 12
	var spawn_offset = Vector2(rocket_x, 38).rotated(rotation)
	
	# Add to the root of the scene for proper positioning
	var root = get_tree().root.get_child(0)
	root.add_child(smoke)
	smoke.global_position = global_position + spawn_offset
	
	# Set smoke properties
	var base_direction = Vector2.DOWN.rotated(rotation)
	var spread_angle = randf_range(-0.3, 0.3)
	var smoke_direction = base_direction.rotated(spread_angle)
	
	var smoke_speed = randf_range(40, 80)
	smoke.initial_velocity = smoke_direction * smoke_speed + velocity * 0.1
	
	smoke.radius = randf_range(8, 12)
	smoke.num_points = randi_range(8, 10)
	smoke.stiffness = randf_range(0.85, 0.95)
	smoke.pressure = randf_range(70, 90)

func show_chat_message(message: String) -> void:
	if chat_display:
		chat_display.show_message(message, chat_message_duration)

func set_ascension_mode() -> void:
	is_ascension_mode = true
	current_fuel = max_fuel  # Fill fuel to max

func enable_shooting() -> void:
	battle_mode = true
	# During battle mode, fuel gauge shows health
	# Keep current fuel as is

func handle_shooting() -> void:
	if Input.is_action_just_pressed("ui_accept"):  # Space key
		shoot_projectile()

func shoot_projectile() -> void:
	# No cooldown - allow rapid fire
	
	# Create projectile
	var projectile = projectile_scene.instantiate()
	var root = get_tree().root.get_child(0)
	root.add_child(projectile)
	
	# Position at nose of ship
	var spawn_offset = Vector2(0, -40).rotated(rotation)
	projectile.global_position = global_position + spawn_offset
	
	# Set velocity in direction ship is facing
	var shoot_direction = Vector2.UP.rotated(rotation)
	projectile.velocity = shoot_direction * 500 + velocity * 0.5
	projectile.shooter_id = get_multiplayer_authority()
	
	# Notify server about shooting
	if get_multiplayer().has_multiplayer_peer():
		var multiplayer_client = get_node_or_null("/root/MultiplayerGame")
		if multiplayer_client:
			multiplayer_client.rpc_id(1, "player_shot", get_multiplayer_authority(), 
				projectile.global_position, projectile.velocity)

func take_damage(damage: float, attacker_id: int) -> void:
	if is_shattered or not battle_mode:
		return
	
	# Only the authority can take damage
	if not is_multiplayer_authority():
		return
	
	# Damage reduces fuel by 20% of max fuel
	var fuel_damage = max_fuel * (damage / 100.0)
	current_fuel -= fuel_damage
	current_fuel = max(0, current_fuel)
	
	# Notify all clients about fuel change via server
	if get_multiplayer().has_multiplayer_peer():
		var multiplayer_client = get_node_or_null("/root/MultiplayerGame")
		if multiplayer_client:
			# Send fuel update to server to relay to all clients
			multiplayer_client.rpc_id(1, "update_player_health", get_multiplayer_authority(), current_fuel)
	
	if current_fuel <= 0:
		# Shatter the spaceship
		shatter(global_position)
		
		# Notify server about death
		if get_multiplayer().has_multiplayer_peer():
			var multiplayer_client = get_node_or_null("/root/MultiplayerGame")
			if multiplayer_client:
				multiplayer_client.rpc_id(1, "player_died", get_multiplayer_authority(), attacker_id)

func set_health(new_fuel: float) -> void:
	# Called on remote clients to update fuel display
	current_fuel = new_fuel
