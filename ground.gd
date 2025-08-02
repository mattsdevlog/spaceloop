extends Node2D

var ground_height: float = 3.0
var ground_color: Color = Color.WHITE
@export_range(0, 2000, 10) var gravity_strength: float = 120.0  # Reduced by 40% from 200
var radius: float = 100.0  # For collision detection with asteroids

func _ready() -> void:
	add_to_group("ground")
	queue_redraw()

func _draw() -> void:
	# Draw ground line
	var screen_width = 2000  # Wide enough to cover the screen
	draw_line(Vector2(-screen_width/2, 0), Vector2(screen_width/2, 0), ground_color, ground_height)
	
	# Draw ground fill below the line
	var fill_height = 500  # Height of the ground fill
	var rect = Rect2(Vector2(-screen_width/2, 0), Vector2(screen_width, fill_height))
	draw_rect(rect, Color(0.9, 0.9, 0.9, 1.0), true)  # Slightly darker white for ground fill
