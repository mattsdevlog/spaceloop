extends Node2D

var asteroid_scene = preload("res://scenes/asteroid.tscn")

# Spawn timing
var spawn_timer: float = 0.0
var spawn_interval: float = 2.0  # Spawn every 2 seconds
var min_spawn_interval: float = 1.0
var max_spawn_interval: float = 3.0

# Asteroid properties
var min_speed: float = 50.0
var max_speed: float = 150.0

# Limit asteroids
var max_asteroids: int = 4

func _ready() -> void:
	# Set initial spawn interval
	spawn_interval = randf_range(min_spawn_interval, max_spawn_interval)

func _process(delta: float) -> void:
	spawn_timer += delta
	
	# Count current asteroids (excluding fragments)
	var asteroid_count = 0
	var asteroids = get_tree().get_nodes_in_group("asteroids")
	for asteroid in asteroids:
		if is_instance_valid(asteroid) and not asteroid.is_fragment:
			asteroid_count += 1
	
	# Only spawn if under limit
	if spawn_timer >= spawn_interval and asteroid_count < max_asteroids:
		spawn_asteroid()
		spawn_timer = 0.0
		spawn_interval = randf_range(min_spawn_interval, max_spawn_interval)

func spawn_asteroid() -> void:
	var asteroid = asteroid_scene.instantiate()
	get_parent().add_child(asteroid)
	
	var viewport = get_viewport_rect()
	var start_position: Vector2
	var direction: Vector2
	
	# Keep trying spawn positions until we find one outside gravity spheres
	var valid_spawn = false
	var attempts = 0
	while not valid_spawn and attempts < 10:
		attempts += 1
		
		# Hard limit to ensure asteroids never spawn below ground
		# Ground is at Y=1257, so max Y should be 1100 to give plenty of clearance
		var max_y = 1050  # Well above ground at Y=1257
		
		# Randomly choose left or right side
		if randf() < 0.5:
			# Spawn from left side
			start_position = Vector2(-50, randf_range(100, max_y))
			direction = Vector2(1, randf_range(-0.5, 0.5)).normalized()
		else:
			# Spawn from right side
			start_position = Vector2(viewport.size.x + 50, randf_range(100, max_y))
			direction = Vector2(-1, randf_range(-0.5, 0.5)).normalized()
		
		# Check if spawn position is outside all gravity spheres
		valid_spawn = true
		var planets = get_tree().get_nodes_in_group("planets")
		for planet in planets:
			if not is_instance_valid(planet):
				continue
			var distance = start_position.distance_to(planet.global_position)
			# Add extra margin (50 pixels) to ensure asteroid spawns well outside
			if distance < planet.gravity_influence_distance + 50:
				valid_spawn = false
				break
	
	var speed = randf_range(min_speed, max_speed)
	asteroid.initialize(start_position, direction, speed)
