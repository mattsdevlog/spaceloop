extends Node2D

# Parameters for the semicircle
var radius: float = 50.0
var center: Vector2 = Vector2(0, 0) # Position of the semicircle's center
var start_angle: float = 0.0 # Start at 0 degrees (right)
var end_angle: float = -PI # End at -180 degrees (left, via top)
var segments: int = 32 # Number of segments for smoothness
var color: Color = Color.RED # Color of the semicircle
var width: float = 2.0 # Line width for the outline

@onready var tube = $Tube

var spaceship_scene = preload("res://scenes/spaceship.tscn")
var current_spaceship = null  # Track the currently launched spaceship

# Score tracking
var score: int = 0

func _ready() -> void:
	queue_redraw() # Use queue_redraw() in Godot 4

func _process(_delta: float) -> void:
	# Get mouse position and calculate angle
	var mouse_pos = get_global_mouse_position()
	var launcher_pos = global_position
	var angle = (mouse_pos - launcher_pos).angle()
	
	# Rotate the tube to face the mouse
	if tube:
		tube.rotation = angle

func _input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		launch_spaceship()

func launch_spaceship() -> void:
	# Check if there's already an active spaceship
	if current_spaceship != null and is_instance_valid(current_spaceship):
		return  # Don't launch a new one
	
	# Create spaceship instance
	var spaceship = spaceship_scene.instantiate()
	
	# Get launch position at the end of the tube
	var launch_offset = Vector2(80, 0).rotated(tube.rotation)
	spaceship.global_position = global_position + tube.position + launch_offset
	
	# Set spaceship rotation to match tube
	spaceship.rotation = tube.rotation
	
	# Add to parent scene
	get_parent().add_child(spaceship)
	
	# Launch in the direction the tube is pointing
	var launch_direction = Vector2.RIGHT.rotated(tube.rotation)
	spaceship.launch(launch_direction)
	
	# Track this spaceship
	current_spaceship = spaceship
	
	# Connect to the spaceship's tree_exiting signal to know when it's destroyed
	spaceship.tree_exiting.connect(_on_spaceship_destroyed)

func _on_spaceship_destroyed() -> void:
	current_spaceship = null

func increment_score() -> void:
	score += 1
	queue_redraw()  # Redraw to update score display

func _draw() -> void:
	# Draw the upward-facing semicircle
	draw_arc(center, radius, start_angle, end_angle, segments, color, width)
	
	# Draw score label
	var font = ThemeDB.fallback_font
	var score_text = "Score: " + str(score)
	var text_pos = Vector2(-50, -80)  # Position above launcher
	draw_string(font, text_pos, score_text, HORIZONTAL_ALIGNMENT_CENTER, -1, 24, Color(0.996, 0.686, 0.204))
