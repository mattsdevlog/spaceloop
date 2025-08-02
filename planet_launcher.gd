extends Node2D

var planet_scene = preload("res://scenes/planet.tscn")

# Spawn timing
var min_spawn_time: float = 1.0
var max_spawn_time: float = 2.0
var spawn_timer: float = 0.0
var next_spawn_time: float = 0.0

# Track current planet
var current_planet = null

# Planet properties
var min_radius: float = 30.0
var max_radius: float = 80.0
@export_range(100, 1000, 10) var gravity_influence_distance: float = 400.0  # Distance at which planet disables ground gravity
@export_range(0, 2000, 10) var planet_gravity_strength: float = 800.0  # Gravitational pull strength of planets

# Spawn position (now for stationary planets)
var spawn_x_min: float = 300.0
var spawn_x_max: float = 800.0
var spawn_y_min: float = 200.0
var spawn_y_max: float = 800.0

func _ready() -> void:
	# Set initial spawn time
	next_spawn_time = randf_range(min_spawn_time, max_spawn_time)

func clear_planets() -> void:
	# Remove current planet if it exists
	if current_planet and is_instance_valid(current_planet):
		current_planet.queue_free()
		current_planet = null
	
	# Reset spawn timer
	spawn_timer = 0.0
	next_spawn_time = randf_range(min_spawn_time, max_spawn_time)

func _process(delta: float) -> void:
	# Only spawn a new planet if there isn't one already
	if current_planet == null or not is_instance_valid(current_planet):
		spawn_timer += delta
		
		if spawn_timer >= next_spawn_time:
			spawn_planet()
			spawn_timer = 0.0
			next_spawn_time = randf_range(min_spawn_time, max_spawn_time)

func spawn_planet() -> void:
	var planet = planet_scene.instantiate()
	
	# Set random properties
	var radius = randf_range(min_radius, max_radius)
	
	# Set properties before adding to scene
	planet.gravity_influence_distance = gravity_influence_distance
	planet.gravity_strength = planet_gravity_strength
	
	# Initialize planet (this sets radius and mass)
	planet.initialize(radius)
	
	# Add to parent
	get_parent().add_child(planet)
	
	# Position randomly on screen
	var spawn_x = randf_range(spawn_x_min, spawn_x_max)
	var spawn_y = randf_range(spawn_y_min, spawn_y_max)
	planet.global_position = Vector2(spawn_x, spawn_y)
	
	# Track this planet
	current_planet = planet
