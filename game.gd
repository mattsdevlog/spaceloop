extends Node2D

var main_menu: Control
var game_started: bool = false
var practice_mode: bool = false
var player_name: String = ""

func _ready() -> void:
	# Get menu reference
	main_menu = $MainMenu
	
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
	$Launchpad.visible = false
	$AsteroidSpawner.set_process(false)
	
	print("Menu ready, buttons connected")

func _on_play_pressed() -> void:
	print("Play button pressed - showing name entry")
	# Show name entry panel
	$MainMenu/PlayButton.visible = false
	$MainMenu/PracticeButton.visible = false
	$MainMenu/TitleLabel.visible = false
	$MainMenu/NameEntryPanel.visible = true
	$MainMenu/NameEntryPanel/NameInput.grab_focus()

func _on_practice_pressed() -> void:
	print("Practice button pressed")
	practice_mode = true
	start_game()

func start_game() -> void:
	game_started = true
	
	# Hide menu
	main_menu.visible = false
	
	# Show game elements
	$PlayerSpaceship.visible = true
	$Launchpad.visible = true
	
	if not practice_mode:
		# Normal mode - show planets and asteroids
		$PlanetLauncher.visible = true
		$AsteroidSpawner.set_process(true)
	else:
		# Practice mode - no planets or asteroids
		$PlanetLauncher.visible = false
		$AsteroidSpawner.set_process(false)
	
	# Unpause the game (not needed if we didn't pause)
	# get_tree().paused = false

func _on_name_submitted(text: String) -> void:
	# Called when Enter is pressed in the name input
	_on_name_confirm()

func _on_name_confirm() -> void:
	var name_input = $MainMenu/NameEntryPanel/NameInput
	player_name = name_input.text.strip_edges()
	
	if player_name.length() == 0:
		player_name = "Player"  # Default name
	
	print("Player name: ", player_name)
	
	# Store the name globally so multiplayer scene can access it
	Globals.player_name = player_name
	
	# Launch multiplayer
	get_tree().change_scene_to_file("res://scenes/multiplayer_game.tscn")
