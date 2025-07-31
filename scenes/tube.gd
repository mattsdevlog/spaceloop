extends Node2D

# Parameters for the tube
var length: float = 80.0 # Length of the tube
var width: float = 20.0 # Width of the tube
var color: Color = Color.BLUE # Color of the tube
var filled: bool = true # Set to false for outline only
var line_width: float = 2.0 # Line width if not filled

func _ready() -> void:
	queue_redraw() # Trigger redraw in Godot 4

func _draw() -> void:
	# Draw the tube as a rectangle extending from the origin
	# The tube extends along the X axis (to the right in local space)
	# Centered vertically on the origin
	var rect_pos = Vector2(0, -width / 2)
	var rect_size = Vector2(length, width)
	draw_rect(Rect2(rect_pos, rect_size), color, filled, line_width if not filled else -1)
