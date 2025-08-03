extends Node2D

# Network configuration
const SERVER_IP = "35.188.127.102"  # Google Cloud server IP
const SERVER_PORT = 8910

# Player colors - all golden yellow
const PLAYER_COLORS = [
	Color(0.996, 0.686, 0.204),           # Player 1
	Color(0.996, 0.686, 0.204),           # Player 2
	Color(0.996, 0.686, 0.204)            # Player 3
]

# Game state
var my_peer_id: int = -1
var my_color_index: int = -1
var game_id: String = ""
var players = {}  # Dictionary of peer_id -> player node
var player_names = {}  # Dictionary of peer_id -> player name
var is_game_started: bool = false
var combined_score: int = 5  # Combined score countdown
var is_ascending: bool = false  # Endgame state
var score_fade_timer: float = 0.0
var camera_start_y: float = 700.0
var battle_phase: int = 0  # 0=none, 1=survive msg, 2=shoot msg, 3=battle, 4=victory
var battle_timer: float = 0.0
var all_players_ascended: bool = false
var victory_phase: int = 0  # 0=none, 1=congrats, 2=worth, 3=fading, 4=white, 5=done
var victory_timer: float = 0.0
var winner_id: int = -1

# References
@onready var waiting_label = $UI/WaitingLabel
@onready var player_count_label = $UI/PlayerCount
@onready var players_container = $Players
@onready var chat_input = $UI/ChatInput
@onready var score_label = $UI/ScoreLabel
@onready var ascend_label = $UI/AscendLabel
@onready var survive_label = $UI/SurviveLabel
@onready var shoot_label = $UI/ShootLabel
@onready var congrats_label = $UI/CongratsLabel
@onready var worth_label = $UI/WorthLabel
@onready var white_fade = $UI/WhiteFade
@onready var camera = $Camera2D
@onready var exit_confirm_panel = $UI/ExitConfirmPanel
@onready var yes_button = $UI/ExitConfirmPanel/YesButton
@onready var no_button = $UI/ExitConfirmPanel/NoButton
@onready var loop_star_label = $UI/LoopStarLabel

# Audio
var space_music: AudioStreamPlayer = null

# Game objects
var server_asteroids = {}  # Dictionary of asteroid_id -> asteroid node
var server_planets = {}  # Dictionary of planet_id -> planet node

func _ready():
	print("Multiplayer game starting...")
	print("Attempting to connect to server at ", SERVER_IP, ":", SERVER_PORT)
	
	# Connect to server using WebSocket (works for both native and HTML5)
	var peer = WebSocketMultiplayerPeer.new()
	var url
	
	# For HTML5, check if we're on HTTPS
	if OS.has_feature("web"):
		print("Running in HTML5/Web environment")
		# Check if we're on HTTPS
		if JavaScriptBridge.eval("window.location.protocol === 'https:'"):
			print("ERROR: Game is served over HTTPS but server only supports non-secure WebSocket (ws://)")
			print("Browsers block non-secure WebSocket connections from secure pages")
			print("Solution: The server needs SSL certificates for wss:// support")
			_show_connection_error("Cannot connect to server from secure page. Please use the desktop version.")
			_return_to_menu()
			return
	
	url = "ws://" + SERVER_IP + ":" + str(SERVER_PORT)
	
	print("Connecting to WebSocket URL: ", url)
	var error = peer.create_client(url)
	print("WebSocket create_client returned: ", error)
	
	if error != OK:
		print("Failed to create client: ", error)
		_return_to_menu()
		return
	
	print("ENet client created successfully, waiting for connection...")
	get_multiplayer().multiplayer_peer = peer
	var multiplayer = get_multiplayer()
	if multiplayer:
		my_peer_id = multiplayer.get_unique_id()
	else:
		my_peer_id = -1
	
	# Connect multiplayer signals
	get_multiplayer().connected_to_server.connect(_on_connected_to_server)
	get_multiplayer().connection_failed.connect(_on_connection_failed)
	get_multiplayer().server_disconnected.connect(_on_server_disconnected)
	
	# Add a connection timeout
	_start_connection_timeout()
	
	# Show waiting UI
	waiting_label.visible = true
	_update_player_count()
	
	# Initialize score display (hidden until game starts)
	if score_label:
		score_label.text = "%d" % combined_score
		score_label.visible = false
	
	# Initialize victory UI elements
	if congrats_label:
		congrats_label.visible = false
	if worth_label:
		worth_label.visible = false
	if white_fade:
		white_fade.visible = false
		white_fade.color = Color(0.996, 0.686, 0.204, 0)
		white_fade.z_index = 100  # Make sure it's on top
	
	# Set text colors to golden yellow for all labels except score_label (which should be dark purple)
	var golden_yellow = Color(0.996, 0.686, 0.204)
	for label in [waiting_label, player_count_label, ascend_label, 
				  survive_label, shoot_label, congrats_label, worth_label, loop_star_label]:
		if label:
			label.modulate = golden_yellow
	
	# Store camera start position
	if camera:
		camera_start_y = camera.position.y
	
	# Connect exit confirmation buttons
	if yes_button:
		yes_button.pressed.connect(_on_exit_yes_pressed)
	if no_button:
		no_button.pressed.connect(_on_exit_no_pressed)
	
	# Connect chat input text changed to force uppercase
	if chat_input:
		chat_input.text_changed.connect(_on_chat_text_changed)
	
	# Create space music player
	space_music = AudioStreamPlayer.new()
	var music_stream = load("res://assets/space_music.ogg")
	if music_stream:
		if music_stream is AudioStreamOggVorbis:
			music_stream.loop = true  # OGG files use 'loop' property
		space_music.stream = music_stream
		space_music.volume_db = -10.0  # Adjust volume as needed
		space_music.bus = "Master"  # Ensure it's on the master bus
		add_child(space_music)
	

var connection_timeout_timer: Timer = null

func _start_connection_timeout():
	connection_timeout_timer = Timer.new()
	connection_timeout_timer.wait_time = 5.0  # 5 seconds timeout
	connection_timeout_timer.one_shot = true
	connection_timeout_timer.timeout.connect(_on_connection_timeout)
	add_child(connection_timeout_timer)
	connection_timeout_timer.start()

func _on_connection_timeout():
	print("Connection timeout - failed to connect to server")
	if get_multiplayer().has_multiplayer_peer():
		var peer_state = get_multiplayer().multiplayer_peer.get_connection_status()
		print("Peer connection state: ", peer_state)
	_return_to_menu()

func _on_connected_to_server():
	print("Connected to server! My ID: ", my_peer_id)
	# Cancel the timeout
	if connection_timeout_timer:
		connection_timeout_timer.stop()
		connection_timeout_timer.queue_free()
		connection_timeout_timer = null
	# Request to join a game with player name
	var player_name = Globals.player_name if Globals.player_name != "" else "Player"
	# Filter the name before sending to server
	var filtered_name = ProfanityFilter.filter_text(player_name)
	rpc_id(1, "request_join_game", my_peer_id, filtered_name)

func _on_connection_failed():
	print("Connection failed signal received")
	# Cancel the timeout
	if connection_timeout_timer:
		connection_timeout_timer.stop()
		connection_timeout_timer.queue_free()
		connection_timeout_timer = null
	_return_to_menu()

func _on_server_disconnected():
	print("Server disconnected")
	_return_to_menu()

func _show_connection_error(message: String):
	# Show error message to player
	if waiting_label:
		waiting_label.text = message
		waiting_label.visible = true
	# Wait a bit before returning to menu
	await get_tree().create_timer(3.0).timeout

func _return_to_menu():
	# Stop music before changing scene
	if space_music and space_music.playing:
		space_music.stop()
	
	# Disconnect from server first
	var multiplayer = get_multiplayer()
	if multiplayer and multiplayer.has_multiplayer_peer():
		multiplayer.multiplayer_peer.close()
	
	# Use call_deferred to ensure scene change happens at the right time
	call_deferred("_deferred_scene_change")

func _deferred_scene_change():
	var tree = get_tree()
	if tree:
		tree.change_scene_to_file("res://scenes/game.tscn")
	else:
		push_error("Cannot change scene: get_tree() returned null")

func _process(delta: float):
	# Keep chat input focused unless exit panel is shown
	if chat_input and chat_input.visible and not chat_input.has_focus() and not exit_confirm_panel.visible:
		chat_input.grab_focus()
	
	if is_ascending:
		# Fade out score
		if score_fade_timer < 1.0:
			score_fade_timer += delta
			if score_label:
				score_label.modulate.a = 1.0 - score_fade_timer
				if score_fade_timer >= 1.0:
					score_label.visible = false
		
		# Update camera based on player positions
		update_ascending_camera()
		
		# Check if all players have ascended
		if not all_players_ascended:
			check_all_players_ascended()
	
	# Handle battle phase transitions
	if battle_phase > 0:
		battle_timer += delta
		
		if battle_phase == 1:  # Survive message
			if battle_timer >= 5.0:
				survive_label.visible = false
				shoot_label.visible = true
				battle_phase = 2
				battle_timer = 0.0
				enable_battle_mode()  # Enable shooting when message appears
		elif battle_phase == 2:  # Shoot message
			if battle_timer >= 5.0:
				shoot_label.visible = false
				battle_phase = 3
				battle_timer = 0.0
		elif battle_phase == 3:  # Battle in progress
			# Check for victory condition
			check_victory_condition()
	
	# Handle victory sequence
	if victory_phase > 0:
		victory_timer += delta
		
		if victory_phase == 1:  # Congrats message
			if victory_timer >= 5.0:
				if congrats_label:
					congrats_label.visible = false
				if worth_label:
					worth_label.visible = true
				victory_phase = 2
				victory_timer = 0.0
		elif victory_phase == 2:  # Worth message
			if victory_timer >= 5.0:
				if worth_label:
					worth_label.visible = false
				victory_phase = 3
				victory_timer = 0.0
		elif victory_phase == 3:  # Fading to white
			var fade_progress = min(victory_timer / 3.0, 1.0)  # 3 seconds to fade
			if white_fade:
				white_fade.visible = true
				white_fade.color.a = fade_progress
			
			if victory_timer >= 3.0:
				victory_phase = 4
				victory_timer = 0.0
		elif victory_phase == 4:  # Full white
			if victory_timer >= 3.0:
				# Return to main menu
				_return_to_menu()

func start_ascension():
	is_ascending = true
	score_fade_timer = 0.0
	
	# Show ascend label
	if ascend_label:
		ascend_label.visible = true
	
	# Start playing space music with a small delay
	if space_music and not space_music.playing:
		await get_tree().create_timer(0.1).timeout
		space_music.play()
	
	# Turn off ground gravity
	var ground = get_node_or_null("Ground")
	if ground:
		ground.gravity_strength = 0.0
	
	# Give all players max fuel and enable unlimited fuel
	for player in players.values():
		if is_instance_valid(player):
			player.set_ascension_mode()
	
	# Notify server to stop spawning planets
	var multiplayer = get_multiplayer()
	if multiplayer and multiplayer.has_multiplayer_peer():
		rpc_id(1, "notify_ascension_started", my_peer_id)

func update_ascending_camera():
	if not camera:
		return
	
	# Check if camera reached the top limit
	if camera.position.y <= -200:
		# Hide ascend label when we reach the top
		if ascend_label and ascend_label.visible:
			ascend_label.visible = false
		return
	
	# Only follow the local player
	if my_peer_id not in players:
		return
		
	var local_player = players[my_peer_id]
	if not is_instance_valid(local_player) or local_player.is_shattered:
		return
	
	# If local player reaches the middle of the screen, start scrolling
	var screen_middle_y = camera.position.y
	if local_player.global_position.y < screen_middle_y:
		# Smoothly scroll upward, but stop at y=-200
		var target_y = max(local_player.global_position.y, -200.0)
		camera.position.y = lerp(float(camera.position.y), target_y, 0.05)
		
		# Check if we just reached the limit
		if camera.position.y <= -199.0:  # Close enough to -200
			# Hide ascend label
			if ascend_label:
				ascend_label.visible = false

# RPC from server
@rpc("authority", "reliable")
func joined_game(server_game_id: String, color_index: int, player_list: Array):
	print("Joined game: ", server_game_id, " as color ", color_index, " my_peer_id: ", my_peer_id)
	print("Player list received: ", player_list)
	game_id = server_game_id
	my_color_index = color_index
	
	# Store player names
	for player_data in player_list:
		player_names[player_data.peer_id] = player_data.get("name", "Player")
	
	# Store our own name
	player_names[my_peer_id] = Globals.player_name if Globals.player_name != "" else "Player"
	
	# Create local player
	print("Creating local player with peer_id: ", my_peer_id, " color: ", my_color_index)
	_create_player(my_peer_id, my_color_index, true)
	
	# Create other players already in game
	for player_data in player_list:
		if player_data.peer_id != my_peer_id:
			print("Creating other player with peer_id: ", player_data.peer_id, " color: ", player_data.color_index)
			_create_player(player_data.peer_id, player_data.color_index, false)
	
	_update_player_count()
	
	# Show chat input immediately when joining
	chat_input.visible = true
	# Give initial focus to chat input
	chat_input.call_deferred("grab_focus")

@rpc("authority", "reliable")
func player_joined(peer_id: int, color_index: int, player_name: String = "Player"):
	#print("Player joined: ", peer_id, " (", player_name, ") with color ", color_index)
	# Filter the player name
	var filtered_name = ProfanityFilter.filter_text(player_name)
	player_names[peer_id] = filtered_name
	_create_player(peer_id, color_index, false)
	_update_player_count()

@rpc("authority", "reliable")
func player_left(peer_id: int):
	#print("Player left: ", peer_id)
	if peer_id in players and is_instance_valid(players[peer_id]):
		players[peer_id].queue_free()
		players.erase(peer_id)
	_update_player_count()

@rpc("authority", "reliable")
func game_started():
	#print("Game started!")
	is_game_started = true
	waiting_label.visible = false
	# Chat input already visible from joined_game
	# Show score label when game starts
	if score_label:
		score_label.visible = true
	
	# Show "LOOP THE STAR" message at game start
	if loop_star_label:
		loop_star_label.visible = true
		# Hide it after 5 seconds
		await get_tree().create_timer(5.0).timeout
		loop_star_label.visible = false

@rpc("authority", "reliable")
func player_full_state_updated(peer_id: int, position: Vector2, rotation: float, velocity: Vector2, fuel: float):
	if peer_id in players and peer_id != my_peer_id:
		var player = players[peer_id]
		# Apply state correction for remote players
		player.apply_state_correction(position, rotation, velocity, fuel)

@rpc("authority", "unreliable_ordered")
func player_inputs_updated(peer_id: int, input_left: bool, input_right: bool, input_up: bool):
	if peer_id in players and peer_id != my_peer_id:
		var player = players[peer_id]
		# Store the inputs for the remote player (for visual effects)
		player.remote_input_left = input_left
		player.remote_input_right = input_right
		player.remote_input_up = input_up

@rpc("authority", "reliable")
func player_scored_update(peer_id: int, planet_index: int):
	#print("Player ", peer_id, " scored on planet ", planet_index)
	# Decrement the combined score
	combined_score = max(0, combined_score - 1)
	_update_score_display()

@rpc("authority", "reliable")
func update_combined_score(new_score: int):
	combined_score = new_score
	_update_score_display()

@rpc("authority", "reliable")
func start_ascension_sequence():
	start_ascension()

func check_all_players_ascended():
	# Check if all living players have reached the top
	var all_at_top = true
	for player in players.values():
		if is_instance_valid(player) and not player.is_shattered:
			if player.global_position.y > -200:
				all_at_top = false
				break
	
	if all_at_top:
		all_players_ascended = true
		start_battle_phase()

func start_battle_phase():
	# Hide ASCEND label before showing battle messages
	if ascend_label:
		ascend_label.visible = false
	
	battle_phase = 1
	battle_timer = 0.0
	survive_label.visible = true
	
	# Notify server about battle phase
	var multiplayer = get_multiplayer()
	if multiplayer and multiplayer.has_multiplayer_peer():
		rpc_id(1, "notify_battle_phase_started", my_peer_id)

func enable_battle_mode():
	# Enable shooting for all players
	for player in players.values():
		if is_instance_valid(player):
			player.enable_shooting()

func check_victory_condition():
	# Count alive players
	var alive_players = []
	for player_id in players:
		var player = players[player_id]
		if is_instance_valid(player) and not player.is_shattered:
			alive_players.append(player_id)
	
	# Check if only one player remains
	if alive_players.size() == 1 and victory_phase == 0:
		winner_id = alive_players[0]
		start_victory_sequence()

func start_victory_sequence():
	battle_phase = 4  # Victory phase
	victory_phase = 1
	victory_timer = 0.0
	
	# Clear all projectiles
	var projectiles = get_tree().get_nodes_in_group("projectiles")
	for projectile in projectiles:
		projectile.queue_free()
	
	# Update congrats message with winner name
	if congrats_label:
		if winner_id in player_names:
			var winner_name = player_names[winner_id]
			congrats_label.text = "CONGRATS %s, YOU HAVE ASCENDED" % winner_name.to_upper()
		congrats_label.visible = true
	
	# Notify server if we are the winner
	var multiplayer = get_multiplayer()
	if winner_id == my_peer_id and multiplayer and multiplayer.has_multiplayer_peer():
		rpc_id(1, "notify_player_ascended", my_peer_id)

# RPC to server (defined for clarity)
@rpc("any_peer", "reliable")
func request_join_game(peer_id: int, player_name: String = "Player"):
	pass

@rpc("any_peer", "reliable")
func update_player_full_state(peer_id: int, position: Vector2, rotation: float, velocity: Vector2, fuel: float):
	pass

@rpc("any_peer", "unreliable_ordered")
func update_player_inputs(peer_id: int, input_left: bool, input_right: bool, input_up: bool):
	pass


@rpc("any_peer", "reliable")
func player_scored(peer_id: int, planet_index: int):
	pass


@rpc("any_peer", "reliable")
func planet_completed(planet_id: int):
	pass

@rpc("any_peer", "reliable")
func request_activate_launchpad(launchpad_index: int):
	pass

@rpc("any_peer", "reliable")
func request_deactivate_launchpad(launchpad_index: int):
	pass

@rpc("any_peer", "reliable")
func notify_ascension_started(sender_id: int):
	pass

@rpc("any_peer", "reliable")
func notify_battle_phase_started(sender_id: int):
	pass

@rpc("any_peer", "reliable")
func notify_player_ascended(sender_id: int):
	pass

@rpc("any_peer", "reliable")
func player_shot(shooter_id: int, position: Vector2, velocity: Vector2):
	pass

@rpc("any_peer", "reliable")
func player_died(player_id: int, killer_id: int):
	pass

@rpc("any_peer", "reliable")
func update_player_health(player_id: int, health: float):
	pass

# Planet and asteroid spawning RPCs
@rpc("authority", "reliable")
func spawn_planet(planet_id: int, position: Vector2, radius: float, color: Color):
	#print("Spawning planet ", planet_id, " at ", position, " with color ", color)
	
	# Create planet from scene
	var planet_scene = load("res://scenes/planet.tscn")
	var planet = planet_scene.instantiate()
	
	# Configure planet
	planet.position = position
	planet.radius = radius
	planet.planet_color = color
	planet.initialize(radius)
	
	# Add to scene
	add_child(planet)
	server_planets[planet_id] = planet

@rpc("authority", "reliable")
func spawn_asteroid(asteroid_id: int, position: Vector2, velocity: Vector2, rotation_speed: float, radius: float, shape_seed: int):
	#print("Spawning asteroid ", asteroid_id)
	
	# Create a simple asteroid that doesn't simulate physics locally
	var asteroid = Node2D.new()
	asteroid.set_script(load("res://multiplayer_asteroid.gd"))
	
	# Set seed for consistent shape across clients
	seed(shape_seed)
	
	# Configure asteroid
	asteroid.position = position
	asteroid.velocity = velocity
	asteroid.rotation_speed = rotation_speed
	asteroid.asteroid_radius = radius
	
	# Add to scene
	add_child(asteroid)
	server_asteroids[asteroid_id] = asteroid

@rpc("authority", "reliable")
func destroy_asteroid(asteroid_id: int):
	if asteroid_id in server_asteroids and is_instance_valid(server_asteroids[asteroid_id]):
		server_asteroids[asteroid_id].queue_free()
		server_asteroids.erase(asteroid_id)

@rpc("authority", "reliable")
func destroy_planet(planet_id: int):
	if planet_id in server_planets and is_instance_valid(server_planets[planet_id]):
		server_planets[planet_id].queue_free()
		server_planets.erase(planet_id)

@rpc("authority", "unreliable_ordered")
func update_asteroid(asteroid_id: int, position: Vector2, velocity: Vector2):
	if asteroid_id in server_asteroids and is_instance_valid(server_asteroids[asteroid_id]):
		server_asteroids[asteroid_id].update_from_server(position, velocity)


# Removed spaceship_hit and position_corrected - collisions are now handled locally

func _create_player(peer_id: int, color_index: int, is_local: bool) -> Node2D:
	# Check if player already exists
	if peer_id in players:
		print("WARNING: Player ", peer_id, " already exists! Skipping creation.")
		return players[peer_id]
	
	# Load player scene
	var player_scene = load("res://scenes/player_spaceship.tscn")
	var player = player_scene.instantiate()
	
	# Configure player
	player.name = "Player_" + str(peer_id)
	player.set_multiplayer_authority(peer_id)
	
	# Set color
	player.ship_color = PLAYER_COLORS[color_index]
	player.assigned_color_index = color_index
	
	# Set player name
	player.player_name = player_names.get(peer_id, "Player")
	
	# Position on appropriate launchpad
	var launchpad_positions = [
		Vector2(300, 1221 - 40),   # Left launchpad
		Vector2(600, 1221 - 40),   # Middle launchpad
		Vector2(900, 1221 - 40)    # Right launchpad
	]
	player.position = launchpad_positions[color_index]
	
	# Enable physics for all players
	player.set_physics_process(true)
	
	# Add to scene
	players_container.add_child(player)
	players[peer_id] = player
	
	# Physics is already enabled for all players above
	
	# Setup network sync for local player
	if is_local:
		_setup_local_player_sync(player)
	
	return player

func _setup_local_player_sync(player: Node2D):
	# Create a timer for full state updates (20/sec)
	var sync_timer = Timer.new()
	sync_timer.name = "NetworkSyncTimer"
	sync_timer.wait_time = 0.05  # 20 updates per second
	sync_timer.timeout.connect(_send_player_state.bind(player))
	player.add_child(sync_timer)
	sync_timer.start()

func _send_player_state(player: Node2D):
	if is_instance_valid(player):
		# Send full state to server including inputs for visual effects
		var input_left = Input.is_action_pressed("ui_left")
		var input_right = Input.is_action_pressed("ui_right")
		var input_up = Input.is_action_pressed("ui_up")
		
		rpc_id(1, "update_player_full_state", my_peer_id, player.position, 
			player.rotation, player.velocity, player.current_fuel)
		
		# Send inputs separately for visual effects
		rpc_id(1, "update_player_inputs", my_peer_id, input_left, input_right, input_up)


func _update_player_count():
	var count = players.size()
	player_count_label.text = "Players: %d/3" % count
	
	if count < 3:
		waiting_label.text = "Waiting for players\n(%d/3)" % count
	else:
		waiting_label.text = "Game starting!"

func _update_score_display():
	if score_label:
		score_label.text = "%d" % combined_score
		
		# Check for endgame
		if combined_score <= 0 and not is_ascending:
			start_ascension()

func _input(event):
	if event is InputEventKey and event.pressed:
		# Handle Enter for chat
		if event.keycode == KEY_ENTER or event.keycode == KEY_KP_ENTER:
			if chat_input and chat_input.has_focus():
				var message = chat_input.text.strip_edges().to_upper()
				if message.length() > 0:
					# Filter the message before sending
					var filtered_message = ProfanityFilter.filter_text(message)
					# Send to server
					rpc_id(1, "send_chat_message", my_peer_id, filtered_message)
					chat_input.text = ""
				# Accept the event to prevent default behavior
				get_viewport().set_input_as_handled()
		# Handle ESC for exit confirmation
		elif event.keycode == KEY_ESCAPE:
			# Toggle exit confirmation panel
			if exit_confirm_panel:
				if exit_confirm_panel.visible:
					_on_exit_no_pressed()
				else:
					exit_confirm_panel.visible = true
					yes_button.grab_focus()
					# Disable chat input focus while popup is shown
					chat_input.release_focus()

# RPC to server
@rpc("any_peer", "reliable")
func send_chat_message(sender_id: int, message: String):
	pass

@rpc("any_peer", "reliable")
func request_player_count(peer_id: int):
	pass

@rpc("any_peer", "reliable")
func request_ascended_list():
	pass

# RPC from server
@rpc("authority", "reliable")
func receive_chat_message(sender_id: int, message: String):
	if sender_id in players:
		var player = players[sender_id]
		if is_instance_valid(player):
			player.show_chat_message(message)

@rpc("authority", "reliable")
func activate_launchpad(launchpad_index: int):
	var launchpad_name = "Launchpad" + str(launchpad_index)
	var launchpad = get_node_or_null(launchpad_name)
	if launchpad:
		launchpad.activate()

@rpc("authority", "reliable")
func deactivate_launchpad(launchpad_index: int):
	var launchpad_name = "Launchpad" + str(launchpad_index)
	var launchpad = get_node_or_null(launchpad_name)
	if launchpad:
		launchpad.deactivate()

@rpc("authority", "reliable")
func spawn_remote_projectile(shooter_id: int, pos: Vector2, vel: Vector2):
	# Create projectile from remote player
	var projectile_scene = preload("res://scenes/projectile.tscn")
	var projectile = projectile_scene.instantiate()
	add_child(projectile)
	projectile.global_position = pos
	projectile.velocity = vel
	projectile.shooter_id = shooter_id
	
	# Play shoot sound at the projectile position if from another player
	if shooter_id != my_peer_id and shooter_id in players:
		var shooting_player = players[shooter_id]
		if is_instance_valid(shooting_player) and shooting_player.shoot_audio:
			shooting_player.shoot_audio.play()

@rpc("authority", "reliable")
func player_eliminated(player_id: int, killer_id: int):
	# Handle player elimination
	if player_id in players:
		var player = players[player_id]
		if is_instance_valid(player) and not player.is_shattered:
			player.shatter(player.global_position)

@rpc("authority", "reliable")
func player_health_updated(player_id: int, health: float):
	# Update player's health display
	if player_id in players:
		var player = players[player_id]
		if is_instance_valid(player):
			player.set_health(health)

func _on_exit_yes_pressed():
	# Return to menu (disconnection is handled in _return_to_menu)
	_return_to_menu()

func _on_exit_no_pressed():
	# Hide confirmation panel and refocus chat
	if exit_confirm_panel:
		exit_confirm_panel.visible = false
	if chat_input and chat_input.visible:
		chat_input.grab_focus()

func _on_chat_text_changed(new_text: String):
	# Force uppercase
	var upper_text = new_text.to_upper()
	if upper_text != new_text:
		chat_input.text = upper_text
		chat_input.caret_column = upper_text.length()

@rpc("authority", "reliable")
func receive_player_count(count: int):
	pass

@rpc("authority", "reliable")
func receive_ascended_list(players: Array):
	pass
