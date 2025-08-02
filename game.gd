extends Node2D

var main_menu: Control
var game_started: bool = false
var practice_mode: bool = false
var player_name: String = ""
var current_menu_index: int = 0
var menu_buttons: Array = []
var online_players_label: Label
var ascended_label: Label
var ascended_names: Label
var scroll_container: ScrollContainer
var scroll_speed: float = 50.0
var scroll_position: float = 0.0
var ascended_list: Array = []

func _ready() -> void:
	# Get menu reference
	main_menu = $MainMenu
	online_players_label = $MainMenu/OnlinePlayersLabel
	ascended_label = $MainMenu/AscendedLabel
	ascended_names = $MainMenu/ScrollContainer/AscendedNames
	scroll_container = $MainMenu/ScrollContainer
	
	# Set up menu buttons array
	menu_buttons = [$MainMenu/PlayButton, $MainMenu/PracticeButton]
	
	# Connect button signals
	$MainMenu/PlayButton.pressed.connect(_on_play_pressed)
	$MainMenu/PracticeButton.pressed.connect(_on_practice_pressed)
	$MainMenu/NameEntryPanel/ConfirmButton.pressed.connect(_on_name_confirm)
	$MainMenu/NameEntryPanel/NameInput.text_submitted.connect(_on_name_submitted)
	$MainMenu/NameEntryPanel/NameInput.text_changed.connect(_on_name_text_changed)
	
	# Don't pause the game - just hide game elements
	# get_tree().paused = true
	
	# Hide game elements initially
	$PlayerSpaceship.visible = false
	$PlanetLauncher.visible = false
	$PlanetLauncher.set_process(false)  # Stop planet spawning
	$Launchpad.visible = false
	$AsteroidSpawner.set_process(false)
	
	# Focus on first button
	menu_buttons[0].grab_focus()
	
	# Enable player count display
	online_players_label.visible = true
	
	# Request ascended players list via HTTP
	_request_ascended_list_http()
	
	# Set up timer to refresh data periodically
	var refresh_timer = Timer.new()
	refresh_timer.wait_time = 10.0  # Refresh every 10 seconds
	refresh_timer.timeout.connect(_request_ascended_list_http)
	add_child(refresh_timer)
	refresh_timer.start()
	
	#print("Menu ready, buttons connected")

func _on_play_pressed() -> void:
	#print("Play button pressed - showing name entry")
	# Show name entry panel
	$MainMenu/PlayButton.visible = false
	$MainMenu/PracticeButton.visible = false
	$MainMenu/TitleLabel.visible = false
	$MainMenu/NameEntryPanel.visible = true
	
	# Clear any existing text
	$MainMenu/NameEntryPanel/NameInput.text = ""
	
	# Ensure the confirm button is enabled
	$MainMenu/NameEntryPanel/ConfirmButton.disabled = false
	
	# Defer the focus grab to avoid Enter key propagation
	$MainMenu/NameEntryPanel/NameInput.call_deferred("grab_focus")

func _on_practice_pressed() -> void:
	#print("Practice button pressed")
	practice_mode = true
	start_game()

func start_game() -> void:
	game_started = true
	
	# Hide menu
	main_menu.visible = false
	
	# Show game elements
	$PlayerSpaceship.visible = true
	$Launchpad.visible = true
	$PlanetLauncher.visible = true
	$PlanetLauncher.set_process(true)  # Start planet spawning
	$AsteroidSpawner.set_process(true)
	
	# Both practice and normal mode now have planets and asteroids
	
	# Unpause the game (not needed if we didn't pause)
	# get_tree().paused = false

func _on_name_submitted(text: String) -> void:
	# Called when Enter is pressed in the name input
	_on_name_confirm()

func _on_name_confirm() -> void:
	print("START button pressed!")
	var name_input = $MainMenu/NameEntryPanel/NameInput
	player_name = name_input.text.strip_edges()
	
	if player_name.length() == 0:
		player_name = "Player"  # Default name
	
	# Filter the player name for inappropriate content
	player_name = ProfanityFilter.filter_text(player_name)
	
	print("Player name: ", player_name)
	
	# Store the name globally so multiplayer scene can access it
	Globals.player_name = player_name
	
	# Launch multiplayer
	print("Attempting to change scene to multiplayer...")
	var result = get_tree().change_scene_to_file("res://scenes/multiplayer_game.tscn")
	if result != OK:
		print("Failed to change scene! Error code: ", result)

func _input(event: InputEvent) -> void:
	# Handle ESC to return to menu from practice mode
	if event is InputEventKey and event.pressed:
		if event.keycode == KEY_ESCAPE and practice_mode and game_started:
			return_to_menu()
			return
	
	# Only handle menu navigation if menu is visible and name panel is not
	if not main_menu.visible or $MainMenu/NameEntryPanel.visible:
		return
		
	if event is InputEventKey and event.pressed:
		if event.keycode == KEY_DOWN:
			current_menu_index = (current_menu_index + 1) % menu_buttons.size()
			menu_buttons[current_menu_index].grab_focus()
		elif event.keycode == KEY_UP:
			current_menu_index = (current_menu_index - 1 + menu_buttons.size()) % menu_buttons.size()
			menu_buttons[current_menu_index].grab_focus()
		elif event.keycode == KEY_ENTER or event.keycode == KEY_KP_ENTER or event.keycode == KEY_SPACE:
			if current_menu_index == 0:
				_on_play_pressed()
			elif current_menu_index == 1:
				_on_practice_pressed()

func _on_name_text_changed(new_text: String) -> void:
	# Remove spaces and limit to 10 characters
	var filtered_text = new_text.replace(" ", "")
	if filtered_text.length() > 10:
		filtered_text = filtered_text.substr(0, 10)
	
	if filtered_text != new_text:
		$MainMenu/NameEntryPanel/NameInput.text = filtered_text
		$MainMenu/NameEntryPanel/NameInput.caret_column = filtered_text.length()

func return_to_menu() -> void:
	# Reset game state
	game_started = false
	practice_mode = false
	
	# Hide game elements
	$PlayerSpaceship.visible = false
	$PlayerSpaceship.velocity = Vector2.ZERO
	$PlayerSpaceship.position = Vector2(600, 1100)
	$PlayerSpaceship.rotation = 0
	$PlanetLauncher.visible = false
	$PlanetLauncher.set_process(false)
	$Launchpad.visible = false
	$AsteroidSpawner.set_process(false)
	
	# Clear any spawned objects
	if $PlanetLauncher.has_method("clear_planets"):
		$PlanetLauncher.clear_planets()
	if $AsteroidSpawner.has_method("clear_asteroids"):
		$AsteroidSpawner.clear_asteroids()
	
	# Show menu
	main_menu.visible = true
	$MainMenu/PlayButton.visible = true
	$MainMenu/PracticeButton.visible = true
	$MainMenu/TitleLabel.visible = true
	$MainMenu/NameEntryPanel.visible = false
	
	# Reset button focus
	current_menu_index = 0
	menu_buttons[0].grab_focus()

func _request_ascended_list_http():
	# Create HTTP request
	var http = HTTPRequest.new()
	add_child(http)
	http.request_completed.connect(_on_http_request_completed)
	
	# Request the status from HTTP server
	var error = http.request("http://127.0.0.1:8911/status")
	if error != OK:
		ascended_label.text = "SERVER OFFLINE"
		http.queue_free()

func _on_http_request_completed(result: int, response_code: int, headers: PackedStringArray, body: PackedByteArray):
	var http = get_node_or_null("HTTPRequest")
	if http:
		http.queue_free()
	
	if response_code != 200:
		ascended_label.text = "SERVER OFFLINE"
		return
	
	# Parse JSON response
	var json = JSON.new()
	var parse_result = json.parse(body.get_string_from_utf8())
	
	if parse_result != OK:
		ascended_label.text = "SERVER ERROR"
		return
	
	var data = json.data
	if data.has("ascended_players"):
		ascended_list = data.ascended_players
		_update_ascended_display()
	
	# Also update online players if available
	if data.has("online_players") and online_players_label:
		var count = data.online_players
		if count == 1:
			online_players_label.text = "1 PLAYER ONLINE"
		else:
			online_players_label.text = "%d PLAYERS ONLINE" % count
		online_players_label.visible = true

func _update_ascended_display():
	var count = ascended_list.size()
	if count == 1:
		ascended_label.text = "1 ASCENDED PLAYER"
	else:
		ascended_label.text = "%d ASCENDED PLAYERS" % count
	
	if count > 0:
		# Create scrolling text with player names
		var names_text = "   "  # Start with some padding
		for name in ascended_list:
			names_text += name + "   •   "
		names_text += names_text  # Duplicate for seamless scrolling
		ascended_names.text = names_text
		scroll_container.visible = true
	else:
		scroll_container.visible = false

func _process(delta: float) -> void:
	# Handle scrolling of ascended names
	if scroll_container and scroll_container.visible and ascended_names.text != "":
		scroll_position += scroll_speed * delta
		
		# Reset scroll position for seamless loop
		var text_width = ascended_names.get_theme_font("font").get_string_size(
			ascended_names.text.substr(0, ascended_names.text.length() / 2),
			HORIZONTAL_ALIGNMENT_LEFT, -1, 
			ascended_names.get_theme_font_size("font_size")
		).x
		
		if scroll_position > text_width:
			scroll_position -= text_width
		
		scroll_container.scroll_horizontal = int(scroll_position)
