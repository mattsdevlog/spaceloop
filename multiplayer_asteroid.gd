extends Node2D

# Asteroid properties (controlled by server)
var velocity: Vector2 = Vector2.ZERO
var rotation_speed: float = 0.0
var asteroid_radius: float = 30.0
var polygon_points: PackedVector2Array = PackedVector2Array()
var asteroid_color: Color = Color.WHITE

# For smooth interpolation
var target_position: Vector2 = Vector2.ZERO
var last_update_time: float = 0.0
var update_interval: float = 0.1  # Expected time between server updates (10 times per second)

func _ready() -> void:
	# Generate shape based on seed for consistency
	generate_shape()
	
	# Add to asteroids group for collision detection
	add_to_group("asteroids")
	
	# Initialize target position
	target_position = position

func check_spaceship_collision() -> void:
	# Get all spaceships
	var multiplayer_game = get_node_or_null("/root/MultiplayerGame")
	if not multiplayer_game:
		return
		
	var players_container = multiplayer_game.get_node_or_null("Players")
	if not players_container:
		return
		
	for spaceship in players_container.get_children():
		if not is_instance_valid(spaceship):
			continue
			
		# Make sure it's actually a spaceship
		if not "is_shattered" in spaceship:
			continue
			
		if spaceship.is_shattered:
			continue
			
		var distance = global_position.distance_to(spaceship.global_position)
		var min_distance = asteroid_radius + 30.0  # Spaceship radius
		
		if distance < min_distance:
			# Only the local player should handle their own collision
			if spaceship.is_multiplayer_authority():
				spaceship.shatter(global_position)

func generate_shape() -> void:
	# Create a polygon with 5-8 vertices
	var num_vertices = randi_range(5, 8)
	polygon_points.clear()
	
	for i in range(num_vertices):
		var angle = (i * TAU / num_vertices) + randf_range(-0.3, 0.3)
		var radius = asteroid_radius * randf_range(0.7, 1.3)
		var point = Vector2(cos(angle) * radius, sin(angle) * radius)
		polygon_points.append(point)

func _process(delta: float) -> void:
	# Update rotation locally (visual only)
	rotation += rotation_speed * delta
	
	# Smooth movement using velocity prediction
	# Move based on velocity between server updates
	position += velocity * delta
	
	# Also interpolate towards target position to correct drift
	var time_since_update = Time.get_ticks_msec() / 1000.0 - last_update_time
	if time_since_update < update_interval * 2:  # Only interpolate if update is recent
		var interpolation_factor = delta * 5.0  # Smooth correction
		position = position.lerp(target_position + velocity * time_since_update, interpolation_factor)
	
	# Check for spaceship collisions
	check_spaceship_collision()

func update_from_server(new_position: Vector2, new_velocity: Vector2) -> void:
	# Store the target position
	target_position = new_position
	velocity = new_velocity
	last_update_time = Time.get_ticks_msec() / 1000.0
	
	# If position is too far off, snap to it
	var distance = position.distance_to(new_position)
	if distance > 100:  # Threshold for snapping
		position = new_position

func _draw() -> void:
	# Draw the asteroid polygon
	if polygon_points.size() > 2:
		draw_polygon(polygon_points, PackedColorArray([asteroid_color]))
		
		# Draw outline for better visibility
		for i in range(polygon_points.size()):
			var next = (i + 1) % polygon_points.size()
			draw_line(polygon_points[i], polygon_points[next], asteroid_color, 2.0)

func get_radius() -> float:
	return asteroid_radius