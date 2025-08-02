extends Node2D

# Soft body properties
var points: Array = []
var rest_distances: Array = []
var radius: float = 10.0
var target_radius: float = 10.0  # The full size we want to reach
var current_radius: float = 2.0  # Start very small
var num_points: int = 8
var stiffness: float = 0.9  # Not used anymore but kept for compatibility
var damping: float = 0.95  # Increased to reduce oscillation
var pressure: float = 80.0  # Not used anymore but kept for compatibility
var initial_velocity: Vector2 = Vector2.ZERO
var lifetime: float = 3.0
var age: float = 0.0
var particle_color: Color = Color.WHITE

# Animation phases
var grow_time: float = 0.2  # Time to grow to full size
var pause_time: float = 0.3  # Time to stay at full size
var shrink_time: float = 0.15  # Time to shrink and disappear

# Physics properties
var gravity: Vector2 = Vector2(0, 100)  # Reduced gravity for slower falling

class Point:
	var position: Vector2
	var old_position: Vector2
	var velocity: Vector2
	var mass: float = 1.0
	
	func _init(pos: Vector2):
		position = pos
		old_position = pos
		velocity = Vector2.ZERO

func _ready() -> void:
	# Set z_index so particles appear behind spaceship
	z_index = -1
	
	# Store the target radius and start small
	target_radius = radius
	current_radius = 2.0
	
	# Wait a frame to ensure global_position is set correctly
	await get_tree().process_frame
	
	# Create points in a circle around the spawn position (starting small)
	for i in range(num_points):
		var angle = (i * TAU) / num_points
		var offset = Vector2(cos(angle), sin(angle)) * current_radius
		var pos = global_position + offset
		var point = Point.new(pos)
		point.velocity = initial_velocity
		points.append(point)
	
	# Calculate rest distances between adjacent points (at small size)
	for i in range(points.size()):
		var next = (i + 1) % points.size()
		var distance = points[i].position.distance_to(points[next].position)
		rest_distances.append(distance)

func _physics_process(delta: float) -> void:
	age += delta
	
	# Update size based on animation phase
	update_size()
	
	# Update physics
	update_points(delta)
	apply_constraints()
	handle_collisions()
	
	# Update alpha based on phase
	if age < grow_time + pause_time:
		particle_color.a = 1.0
	else:
		# Fade during shrink phase
		var shrink_progress = (age - grow_time - pause_time) / shrink_time
		particle_color.a = 1.0 - shrink_progress
	
	# Remove when lifetime expires
	if age >= grow_time + pause_time + shrink_time:
		queue_free()
	
	queue_redraw()

func update_size() -> void:
	var old_radius = current_radius
	
	if age < grow_time:
		# Growing phase
		var grow_progress = age / grow_time
		current_radius = lerp(2.0, target_radius, grow_progress)
	elif age < grow_time + pause_time:
		# Pause phase - stay at full size
		current_radius = target_radius
	else:
		# Shrinking phase
		var shrink_progress = (age - grow_time - pause_time) / shrink_time
		current_radius = lerp(target_radius, 0.0, shrink_progress)
	
	# Scale points based on radius change
	if old_radius > 0 and current_radius != old_radius:
		var scale_factor = current_radius / old_radius
		var center = get_center()
		
		for point in points:
			var offset = point.position - center
			point.position = center + offset * scale_factor
			point.old_position = center + (point.old_position - center) * scale_factor
		
		# Update rest distances
		for i in range(rest_distances.size()):
			rest_distances[i] *= scale_factor

func get_center() -> Vector2:
	var center = Vector2.ZERO
	for point in points:
		center += point.position
	return center / points.size()

func update_points(delta: float) -> void:
	for point in points:
		# Verlet integration
		var temp_pos = point.position
		point.position += (point.position - point.old_position) * damping + point.velocity * delta + gravity * delta * delta
		point.old_position = temp_pos
		point.velocity = Vector2.ZERO

func apply_constraints() -> void:
	# Get center position
	var center = Vector2.ZERO
	for point in points:
		center += point.position
	center /= points.size()
	
	# Force all points to maintain exact circular formation
	for i in range(points.size()):
		var angle = (i * TAU) / points.size()
		var target_pos = center + Vector2(cos(angle), sin(angle)) * current_radius
		# Strongly pull points to their ideal circular position
		points[i].position = points[i].position.lerp(target_pos, 0.8)
		
		# Adjust old position to maintain some velocity
		var velocity = points[i].position - points[i].old_position
		points[i].old_position = points[i].position - velocity * 0.9

func handle_collisions() -> void:
	var viewport = get_viewport_rect()
	
	# Check asteroid collisions - limit checks for performance
	# Only check when particle is large enough to matter
	if current_radius > 5.0 and randf() < 0.3:  # Only check 30% of frames
		var asteroids = get_tree().get_nodes_in_group("asteroids")
		var center = get_center()
		
		# Limit to nearest 3 asteroids
		var checked = 0
		for asteroid in asteroids:
			if checked >= 3 or not is_instance_valid(asteroid):
				continue
			
			var distance = center.distance_to(asteroid.global_position)
			
			if distance < asteroid.asteroid_radius + current_radius + 20:  # Check with margin
				checked += 1
				
				if distance < asteroid.asteroid_radius + current_radius:
					# Calculate push direction and force
					var push_direction = (asteroid.global_position - center).normalized()
					var overlap = (asteroid.asteroid_radius + current_radius) - distance
					
					# Push asteroid away with force proportional to overlap and particle size
					var push_force = overlap * 2.0 * (current_radius / target_radius)  # Scale by current size
					asteroid.velocity += push_direction * push_force
					
					# Simple particle response - just offset center
					for point in points:
						point.position += push_direction * overlap * -0.3
					break  # Only handle one collision per frame
	
	# Check player spaceship collision
	var spaceship = get_node_or_null("/root/Game/PlayerSpaceship")
	if spaceship and not spaceship.is_shattered:
		var ship_size = 20  # Approximate radius of the spaceship
		for point in points:
			var distance = point.position.distance_to(spaceship.global_position)
			if distance < ship_size + current_radius:
				# Push point out of spaceship
				var direction = (point.position - spaceship.global_position).normalized()
				point.position = spaceship.global_position + direction * (ship_size + current_radius)
				# Minimal bounce
				var vel = point.position - point.old_position
				point.old_position = point.position - vel * 0.2
	
	# Check launchpad collision
	var launchpad = get_node_or_null("/root/Game/Launchpad")
	if launchpad:
		var launchpad_top = launchpad.global_position.y - 10  # Half of launchpad height
		var launchpad_left = launchpad.global_position.x - 50  # Half of launchpad width
		var launchpad_right = launchpad.global_position.x + 50
		
		for point in points:
			# Check if point is within launchpad horizontal bounds
			if point.position.x >= launchpad_left and point.position.x <= launchpad_right:
				if point.position.y + current_radius > launchpad_top and point.position.y < launchpad_top + 20:
					# Hit launchpad - treat like ground
					point.position.y = launchpad_top - current_radius
					# Reduced bounce
					var vel = point.position - point.old_position
					point.old_position = point.position + vel * Vector2(0.5, -0.3)
	
	# Check ground collision
	var ground_node = get_node_or_null("/root/Game/Ground")
	if ground_node:
		var ground_y = ground_node.global_position.y
		for point in points:
			if point.position.y + current_radius > ground_y:
				point.position.y = ground_y - current_radius
				# Reduced bounce
				var vel = point.position - point.old_position
				point.old_position = point.position + vel * Vector2(0.5, -0.3)
	
	# Check planet collisions
	var planets = get_tree().get_nodes_in_group("planets")
	for planet in planets:
		if not is_instance_valid(planet):
			continue
		
		for point in points:
			var distance = point.position.distance_to(planet.global_position)
			if distance < planet.radius + current_radius:
				# Push point out of planet
				var direction = (point.position - planet.global_position).normalized()
				point.position = planet.global_position + direction * (planet.radius + current_radius)
				# Reduced bounce
				var vel = point.position - point.old_position
				point.old_position = point.position - vel * 0.3
	
	# Screen boundaries
	for point in points:
		if point.position.x - current_radius < 0:
			point.position.x = current_radius
			point.old_position.x = current_radius + (current_radius - point.old_position.x) * 0.5
		elif point.position.x + current_radius > viewport.size.x:
			point.position.x = viewport.size.x - current_radius
			point.old_position.x = (viewport.size.x - current_radius) - (point.old_position.x - (viewport.size.x - current_radius)) * 0.5
		
		# No top boundary - particles can go above y=0

func _draw() -> void:
	if points.size() < 3:
		return
	
	# Create polygon points relative to this node's position
	var polygon_points = PackedVector2Array()
	for point in points:
		polygon_points.append(point.position - global_position)
	
	# Draw filled polygon
	draw_polygon(polygon_points, PackedColorArray([particle_color]))
	
	# Draw outline
	var outline_color = Color(0.9, 0.9, 0.9, particle_color.a)
	for i in range(points.size()):
		var next = (i + 1) % points.size()
		draw_line(points[i].position - global_position, points[next].position - global_position, outline_color, 1.0)
