extends Node2D

# Asteroid properties
var velocity: Vector2 = Vector2.ZERO
var rotation_speed: float = 0.0
var asteroid_radius: float = 30.0
var original_radius: float = 30.0  # Store original size
var polygon_points: PackedVector2Array = PackedVector2Array()
var asteroid_color: Color = Color(0.996, 0.686, 0.204)
var mass: float = 1.0  # For collision response
var is_fragment: bool = false  # Prevent fragments from creating more fragments

var lifetime: float = 0.0  # For fragment fade out
var max_lifetime: float = 1.5  # Fragments exist for 1.5 seconds
var initial_radius: float = 0.0  # To track shrinking

func _ready() -> void:
	# Generate random polygon shape
	generate_random_shape()
	
	# Add to asteroids group for collision detection
	add_to_group("asteroids")

func generate_random_shape() -> void:
	# Create a random polygon with 5-8 vertices
	var num_vertices = randi_range(5, 8)
	polygon_points.clear()
	
	for i in range(num_vertices):
		var angle = (i * TAU / num_vertices) + randf_range(-0.3, 0.3)
		var radius = asteroid_radius * randf_range(0.7, 1.3)
		var point = Vector2(cos(angle) * radius, sin(angle) * radius)
		polygon_points.append(point)

func initialize(start_position: Vector2, direction: Vector2, speed: float) -> void:
	global_position = start_position
	velocity = direction.normalized() * speed
	rotation_speed = randf_range(-2.0, 2.0)  # Random rotation speed
	asteroid_radius = randf_range(20, 40)  # Random size
	original_radius = asteroid_radius  # Store original size
	mass = asteroid_radius / 30.0  # Mass proportional to size
	generate_random_shape()

func _process(delta: float) -> void:
	# Handle fragment lifetime
	if is_fragment:
		lifetime += delta
		if lifetime >= max_lifetime:
			queue_free()
			return
		
		# Shrink and fade
		var progress = lifetime / max_lifetime
		asteroid_radius = initial_radius * (1.0 - progress * 0.8)  # Shrink to 20% of original size
		asteroid_color.a = 1.0 - progress  # Fade to transparent
		generate_random_shape()  # Regenerate shape with new radius
		queue_redraw()
	
	# Apply gravity from planets (but not for fragments)
	if not is_fragment:
		apply_gravity(delta)
		# Check for bouncing off gravity fields
		check_gravity_field_collision()
	
	# Check collisions with other asteroids
	check_asteroid_collisions()
	
	# Check collision with spaceship (pixel-perfect if close)
	check_spaceship_collision()
	
	# Check collision with ground
	check_ground_collision()
	
	# Check collisions with planets (but not for fragments)
	if not is_fragment:
		check_planet_collisions()
	
	# Update position
	position += velocity * delta
	
	# No friction - asteroids maintain velocity
	
	# Update rotation
	rotation += rotation_speed * delta
	
	# Remove if off screen
	var viewport = get_viewport_rect()
	if position.x < -100 or position.x > viewport.size.x + 100:
		queue_free()
	if position.y < -100 or position.y > viewport.size.y + 100:
		queue_free()

func _draw() -> void:
	# Draw the asteroid polygon
	if polygon_points.size() > 2:
		var color = asteroid_color
		
		# Don't draw filled polygon - outline only
		# draw_polygon(polygon_points, PackedColorArray([color]))
		
		# Always draw outline
		for i in range(polygon_points.size()):
			var next = (i + 1) % polygon_points.size()
			draw_line(polygon_points[i], polygon_points[next], color, 2.0)

func get_radius() -> float:
	return asteroid_radius

func apply_gravity(delta: float) -> void:
	var planets = get_tree().get_nodes_in_group("planets")
	var total_gravity = Vector2.ZERO
	
	for planet in planets:
		if not is_instance_valid(planet):
			continue
			
		var distance = global_position.distance_to(planet.global_position)
		
		# Check if within planet's gravity influence
		if distance <= planet.gravity_influence_distance:
			# Simplified gravity calculation
			var gravity_factor = 1.0 - (distance / planet.gravity_influence_distance)
			gravity_factor = gravity_factor * gravity_factor
			
			var force_magnitude = planet.gravity_strength * gravity_factor * planet.mass
			var direction = (planet.global_position - global_position).normalized()
			total_gravity += direction * force_magnitude
	
	# Apply gravity to velocity
	velocity += total_gravity * delta

func check_asteroid_collisions() -> void:
	var asteroids = get_tree().get_nodes_in_group("asteroids")
	for other in asteroids:
		if other == self or not is_instance_valid(other):
			continue
		
		# Only process collision if this asteroid has lower instance ID (prevents double processing)
		if get_instance_id() > other.get_instance_id():
			continue
		
		# Simple circle-based collision for performance
		var distance = global_position.distance_to(other.global_position)
		var min_distance = asteroid_radius + other.asteroid_radius
		
		if distance < min_distance:
			# Collision detected - bounce!
			var collision_normal = (global_position - other.global_position).normalized()
			var overlap = min_distance - distance
			
			# Prevent division by zero
			if distance < 0.001:
				collision_normal = Vector2.UP
				distance = 0.001
			
			# Separate overlapping asteroids
			position += collision_normal * (overlap * 0.5)
			other.position -= collision_normal * (overlap * 0.5)
			
			# Calculate relative velocity
			var relative_velocity = velocity - other.velocity
			var velocity_along_normal = relative_velocity.dot(collision_normal)
			
			# Do not resolve if velocities are separating
			if velocity_along_normal > 0:
				continue
			
			# Calculate restitution (bounciness) - perfect elastic collision
			var restitution = 1.0  # Perfect bounce
			var impulse = 2 * velocity_along_normal / (mass + other.mass)
			
			# Apply impulse to velocities
			velocity -= impulse * other.mass * collision_normal * restitution
			other.velocity += impulse * mass * collision_normal * restitution

func check_planet_collisions() -> void:
	var planets = get_tree().get_nodes_in_group("planets")
	for planet in planets:
		if not is_instance_valid(planet):
			continue
			
		var distance = global_position.distance_to(planet.global_position)
		var min_distance = asteroid_radius + planet.radius
		
		if distance < min_distance:
			# Collision with planet - shatter!
			shatter()
			return

func shatter() -> void:
	# Don't create fragments from fragments
	if is_fragment:
		queue_free()
		return
		
	# Create 2-3 smaller asteroid fragments (reduced for performance)
	var num_fragments = randi_range(2, 3)
	var asteroid_scene = load("res://scenes/asteroid.tscn")
	
	# Calculate bounce back direction (opposite of current velocity)
	var bounce_direction = -velocity.normalized()
	if bounce_direction.length() < 0.1:
		bounce_direction = Vector2.UP
	
	for i in range(num_fragments):
		var fragment = asteroid_scene.instantiate()
		# Use call_deferred to avoid immediate collision processing
		get_parent().call_deferred("add_child", fragment)
		
		# Set fragment properties
		fragment.is_fragment = true
		fragment.asteroid_radius = asteroid_radius * randf_range(0.3, 0.5)
		fragment.initial_radius = fragment.asteroid_radius  # Store for shrinking
		fragment.mass = fragment.asteroid_radius / 30.0
		fragment.global_position = global_position + Vector2(randf_range(-10, 10), randf_range(-10, 10))
		
		# Give fragments velocity in opposite direction with spread
		var spread_angle = randf_range(-PI/4, PI/4)  # 45 degree spread
		var fragment_direction = bounce_direction.rotated(spread_angle)
		var scatter_speed = randf_range(50, 100)  # Much slower scatter
		fragment.velocity = fragment_direction * scatter_speed
		
		# Very slow rotation for fragments
		fragment.rotation_speed = randf_range(-0.5, 0.5)
		
		# Generate shape for fragment
		fragment.generate_random_shape()
	
	# Remove the original asteroid
	queue_free()

func check_polygon_collision(other_asteroid) -> Dictionary:
	# Check if two asteroid polygons collide
	var my_transform = Transform2D(rotation, global_position)
	var other_transform = Transform2D(other_asteroid.rotation, other_asteroid.global_position)
	
	# Check all edges of this asteroid against the other
	for i in range(polygon_points.size()):
		var next_i = (i + 1) % polygon_points.size()
		var edge_start = my_transform * polygon_points[i]
		var edge_end = my_transform * polygon_points[next_i]
		var edge_normal = (edge_end - edge_start).rotated(PI/2).normalized()
		
		# Project both asteroids onto this edge normal
		var my_projection = get_polygon_projection(polygon_points, my_transform, edge_normal)
		var other_projection = get_polygon_projection(other_asteroid.polygon_points, other_transform, edge_normal)
		
		# Check if projections overlap
		if my_projection.y < other_projection.x or other_projection.y < my_projection.x:
			# No overlap on this axis - no collision
			return {"collided": false}
	
	# Check all edges of other asteroid
	for i in range(other_asteroid.polygon_points.size()):
		var next_i = (i + 1) % other_asteroid.polygon_points.size()
		var edge_start = other_transform * other_asteroid.polygon_points[i]
		var edge_end = other_transform * other_asteroid.polygon_points[next_i]
		var edge_normal = (edge_end - edge_start).rotated(PI/2).normalized()
		
		# Project both asteroids onto this edge normal
		var my_projection = get_polygon_projection(polygon_points, my_transform, edge_normal)
		var other_projection = get_polygon_projection(other_asteroid.polygon_points, other_transform, edge_normal)
		
		# Check if projections overlap
		if my_projection.y < other_projection.x or other_projection.y < my_projection.x:
			# No overlap on this axis - no collision
			return {"collided": false}
	
	# All axes have overlap - collision detected!
	# Find the minimum overlap to determine collision normal
	var min_overlap = INF
	var collision_normal = Vector2.ZERO
	
	# Check overlap on all axes again to find minimum
	for i in range(polygon_points.size()):
		var next_i = (i + 1) % polygon_points.size()
		var edge_start = my_transform * polygon_points[i]
		var edge_end = my_transform * polygon_points[next_i]
		var edge_normal = (edge_end - edge_start).rotated(PI/2).normalized()
		
		var my_projection = get_polygon_projection(polygon_points, my_transform, edge_normal)
		var other_projection = get_polygon_projection(other_asteroid.polygon_points, other_transform, edge_normal)
		
		var overlap = min(my_projection.y - other_projection.x, other_projection.y - my_projection.x)
		if overlap < min_overlap:
			min_overlap = overlap
			collision_normal = edge_normal
			# Make sure normal points from other to this
			if (global_position - other_asteroid.global_position).dot(edge_normal) < 0:
				collision_normal = -edge_normal
	
	return {
		"collided": true,
		"normal": collision_normal,
		"overlap": min_overlap
	}

func get_polygon_projection(points: PackedVector2Array, transform: Transform2D, axis: Vector2) -> Vector2:
	# Project polygon onto axis and return min/max as Vector2(min, max)
	var min_proj = INF
	var max_proj = -INF
	
	for point in points:
		var world_point = transform * point
		var projection = world_point.dot(axis)
		min_proj = min(min_proj, projection)
		max_proj = max(max_proj, projection)
	
	return Vector2(min_proj, max_proj)

func check_spaceship_collision() -> void:
	var spaceship = get_node_or_null("/root/Game/PlayerSpaceship")
	if not spaceship or spaceship.is_shattered:
		return
	
	# First check distance to see if we need pixel-perfect collision
	var distance = global_position.distance_to(spaceship.global_position)
	var proximity_threshold = 200.0  # Only use pixel-perfect within 200 pixels
	
	# Quick circle check first
	var ship_radius = 30.0  # Approximate spaceship size
	if distance > asteroid_radius + ship_radius + proximity_threshold:
		return  # Too far away
	
	# Close enough - check for actual collision
	if distance < asteroid_radius + ship_radius:
		# Within collision range - use pixel-perfect if very close
		if distance < asteroid_radius + ship_radius + 50:
			# Very close - use pixel-perfect collision for accuracy
			# For now, just use circle collision and trigger shatter
			# In a full implementation, we'd check against ship polygon
			spaceship.shatter(global_position)
		else:
			# Not super close - simple circle collision is fine
			if distance < asteroid_radius + ship_radius:
				spaceship.shatter(global_position)

func check_gravity_field_collision() -> void:
	var planets = get_tree().get_nodes_in_group("planets")
	
	for planet in planets:
		if not is_instance_valid(planet):
			continue
		
		var to_planet = planet.global_position - global_position
		var distance = to_planet.length()
		var gravity_radius = planet.gravity_influence_distance
		
		# Check if asteroid edge is touching gravity sphere
		var asteroid_edge_distance = distance - asteroid_radius
		
		# Wider detection range to prevent getting stuck
		if asteroid_edge_distance <= gravity_radius + 5 and asteroid_edge_distance > gravity_radius - 50:
			# We're near the edge of the gravity sphere
			var from_planet = -to_planet.normalized()
			var velocity_towards_planet = velocity.dot(-from_planet)
			
			# Check if we're outside but moving in, or inside and need to be pushed out
			if asteroid_edge_distance > gravity_radius and velocity_towards_planet > 0:
				# Outside sphere, moving in - deflect
				velocity = velocity.reflect(from_planet)
				
				# Add some extra velocity to ensure asteroid moves away
				velocity += from_planet * 50
				
			elif asteroid_edge_distance <= gravity_radius:
				# Inside the boundary - push out forcefully
				var push_distance = gravity_radius - asteroid_edge_distance + 10
				position += from_planet * push_distance
				
				# Ensure velocity is pointing away
				if velocity_towards_planet > 0:
					velocity = velocity.reflect(from_planet)
				
				# Add escape velocity
				velocity += from_planet * 100

func check_ground_collision() -> void:
	var ground = get_tree().get_first_node_in_group("ground")
	if not ground:
		return
	
	# Simple circle-based collision for performance
	var ground_y = ground.global_position.y
	if global_position.y + asteroid_radius > ground_y:
		# Hit the ground - bounce!
		global_position.y = ground_y - asteroid_radius
		
		# Reverse Y velocity with no energy loss
		if velocity.y > 0:
			velocity.y *= -1.0  # Perfect bounce
	
	# Check all launchpad protection arcs
	var launchpads = get_tree().get_nodes_in_group("launchpad")
	for launchpad in launchpads:
		if not is_instance_valid(launchpad):
			continue
		var collision_data = launchpad.check_asteroid_collision(global_position, asteroid_radius)
		if collision_data.collided:
			# Bounce off the arc
			position += collision_data.normal * collision_data.overlap
			
			# Calculate bounce velocity
			var velocity_along_normal = velocity.dot(collision_data.normal)
			if velocity_along_normal < 0:
				velocity -= collision_data.normal * velocity_along_normal * 2.0  # Perfect bounce
			break  # Only handle one collision per frame