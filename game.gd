extends Node2D

var main_menu: Control
var game_started: bool = false
var practice_mode: bool = false
var player_name: String = ""
var current_menu_index: int = 0
var menu_buttons: Array = []

func _ready() -> void:
	# Get menu reference
	main_menu = $MainMenu
	
	# Set up menu buttons array
	menu_buttons = [$MainMenu/PlayButton, $MainMenu/PracticeButton]
	
	# Connect button signals
	$MainMenu/PlayButton.pressed.connect(_on_play_pressed)
	$MainMenu/PracticeButton.pressed.connect(_on_practice_pressed)
	$MainMenu/NameEntryPanel/ConfirmButton.pressed.connect(_on_name_confirm)
	$MainMenu/NameEntryPanel/NameInput.text_submitted.connect(_on_name_submitted)
	
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
