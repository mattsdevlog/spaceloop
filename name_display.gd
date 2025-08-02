extends Node2D

var player_name: String = ""

func _ready():
	z_index = 10

func set_player_name(name: String):
	player_name = name
	queue_redraw()

func _draw():
	if player_name == "":
		return
		
	var font = ThemeDB.fallback_font
	var font_size = 28
	
	# Calculate total width for centering
	var text_size = font.get_string_size(player_name, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size)
	var total_width = text_size.x
	
	# Draw the name centered
	var text_height = font.get_height(font_size)
	var text_pos = Vector2(-total_width/2, text_height/2 - 2)
	var text_color = Color(1, 1, 1, 1)
	draw_string(font, text_pos, player_name, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size, text_color)
