extends Node2D

var chat_message: String = ""
var chat_message_full: String = ""
var chat_message_chars_shown: int = 0
var chat_message_timer: float = 0.0
var chat_typing_timer: float = 0.0
var chat_typing_speed: float = 20.0

func _ready():
	z_index = 10

func show_message(message: String, duration: float):
	chat_message_full = message
	chat_message = ""
	chat_message_chars_shown = 0
	chat_typing_timer = 0.0
	chat_message_timer = duration + (message.length() / chat_typing_speed)

func _process(delta: float):
	if chat_message_timer > 0:
		# Update typing effect
		if chat_message_chars_shown < chat_message_full.length():
			chat_typing_timer += delta
			var chars_to_show = int(chat_typing_timer * chat_typing_speed)
			if chars_to_show > chat_message_chars_shown:
				chat_message_chars_shown = min(chars_to_show, chat_message_full.length())
				chat_message = chat_message_full.substr(0, chat_message_chars_shown)
		
		chat_message_timer -= delta
		if chat_message_timer <= 0:
			chat_message = ""
			chat_message_full = ""
			chat_message_chars_shown = 0
		
		queue_redraw()

func _draw():
	if chat_message == "" or chat_message_timer <= 0:
		return
		
	var font = ThemeDB.fallback_font
	var font_size = 32
	
	# Calculate total width for centering
	var total_width = 0.0
	for i in range(chat_message.length()):
		var char = chat_message[i]
		total_width += font.get_string_size(char, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size).x
	
	# Draw each character with shake effect
	var current_x = -total_width/2
	var alpha = min(1.0, chat_message_timer / 0.5)  # Fade in/out
	if chat_message_timer < 0.5:
		alpha = chat_message_timer / 0.5  # Fade out
	
	for i in range(chat_message.length()):
		var char = chat_message[i]
		var char_width = font.get_string_size(char, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size).x
		
		# Add vertical shake effect - each character shakes independently
		var shake_amount = 1.0
		var time_offset = i * 0.3  # Different phase for each character
		var shake_y = sin(Time.get_ticks_msec() / 40.0 + time_offset) * shake_amount
		
		# Character position with vertical shake only
		var char_pos = Vector2(current_x, shake_y)
		
		# Draw the character
		var text_color = Color(1, 1, 1, alpha)
		draw_string(font, char_pos, char, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size, text_color)
		
		current_x += char_width