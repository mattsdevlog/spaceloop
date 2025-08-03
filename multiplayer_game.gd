extends Node2D

# Network configuration
const SERVER_IP = "127.0.0.1"  # Change this to your server IP
const SERVER_PORT = 8910

# Player colors
const PLAYER_COLORS = [
	Color.YELLOW,           # Player 1
	Color.LIGHT_BLUE,       # Player 2
	Color(1.0, 0.3, 0.3)   # Player 3 (Red)
]

# Game state
var my_peer_id: int = -1
var my_color_index: int = -1
var game_id: String = ""
var players = {}  # Dictionary of peer_id -> player node
var is_game_started: bool = false

# References
@onready var waiting_label = $UI/WaitingLabel
@onready var player_count_label = $UI/PlayerCount
@onready var players_container = $Players

func _ready():
	#print("Multiplayer game starting...")
	
	# Connect to server
	var peer = ENetMultiplayerPeer.new()
	var error = peer.create_client(SERVER_IP, SERVER_PORT)
	
	if error != OK:
		#print("Failed to connect to server: ", error)
		_return_to_menu()
		return
	
	multiplayer.multiplayer_peer = peer
	my_peer_id = peer.get_unique_id()
	
	# Connect multiplayer signals
	multiplayer.connected_to_server.connect(_on_connected_to_server)
	multiplayer.connection_failed.connect(_on_connection_failed)
	multiplayer.server_disconnected.connect(_on_server_disconnected)
	
	# Show waiting UI
	waiting_label.visible = true
	_update_player_count()

func _on_connected_to_server():
	#print("Connected to server!")
	# Request to join a game
	rpc_id(1, "request_join_game")

func _on_connection_failed():
	#print("Failed to connect to server")
	_return_to_menu()

func _on_server_disconnected():
	#print("Server disconnected")
	_return_to_menu()

func _return_to_menu():
	get_tree().change_scene_to_file("res://scenes/game.tscn")

@rpc("authority", "reliable")
func joined_game(server_game_id: String, color_index: int, player_list: Array):
	#print("Joined game: ", server_game_id, " as color ", color_index)
	game_id = server_game_id
	my_color_index = color_index
	
	# Create local player
	_create_player(my_peer_id, my_color_index, true)
	
	# Create other players already in game
	for player_data in player_list:
		if player_data.peer_id != my_peer_id:
			_create_player(player_data.peer_id, player_data.color_index, false)
	
	_update_player_count()

@rpc("authority", "reliable")
func player_joined(peer_id: int, color_index: int):
	#print("Player joined: ", peer_id, " with color ", color_index)
	_create_player(peer_id, color_index, false)
	_update_player_count()

@rpc("authority", "reliable")
func player_left(peer_id: int):
	#print("Player left: ", peer_id)
	if peer_id in players:
		players[peer_id].queue_free()
		players.erase(peer_id)
	_update_player_count()

@rpc("authority", "reliable")
func game_started():
	#print("Game started!")
	is_game_started = true
	waiting_label.visible = false
	
	# Enable all players
	for player in players.values():
		player.set_physics_process(true)

func _create_player(peer_id: int, color_index: int, is_local: bool) -> Node2D:
	# Load player scene
	var player_scene = load("res://scenes/player_spaceship.tscn")
	var player = player_scene.instantiate()
	
	# Configure player
	player.name = "Player_" + str(peer_id)
	player.set_multiplayer_authority(peer_id)
	
	# Set color
	player.ship_color = PLAYER_COLORS[color_index]
	
	# Position on appropriate launchpad
	var launchpad_positions = [
		Vector2(300, 1221 - 40),   # Left launchpad
		Vector2(600, 1221 - 40),   # Middle launchpad
		Vector2(900, 1221 - 40)    # Right launchpad
	]
	player.position = launchpad_positions[color_index]
	
	# Add network component if not local
	if not is_local:
		player.set_physics_process(false)  # Remote players don't process physics locally
		_add_network_sync(player, peer_id)
	else:
		# For local player, set up network sync for sending
		_setup_local_player_sync(player)
	
	# Add to scene
	players_container.add_child(player)
	players[peer_id] = player
	
	# Disable until game starts
	if not is_game_started:
		player.set_physics_process(false)
	
	return player

func _add_network_sync(player: Node2D, peer_id: int):
	# Add a script to handle network updates for remote players
	var sync_script = GDScript.new()
	sync_script.source_code = """
extends Node

var spaceship: Node2D
var peer_id: int

func _ready():
	spaceship = get_parent()
	set_physics_process(true)

func update_from_network(position: Vector2, rotation: float, velocity: Vector2):
	spaceship.position = position
	spaceship.rotation = rotation
	spaceship.velocity = velocity
"""
	
	var sync_node = Node.new()
	sync_node.name = "NetworkSync"
	sync_node.set_script(sync_script)
	player.add_child(sync_node)
	sync_node.peer_id = peer_id

func _setup_local_player_sync(player: Node2D):
	# Override the player's _physics_process to send network updates
	player.set_meta("is_network_player", true)
	
	# Create a timer for network updates
	var timer = Timer.new()
	timer.name = "NetworkTimer"
	timer.wait_time = 0.05  # 20 updates per second
	timer.timeout.connect(_send_player_update.bind(player))
	player.add_child(timer)
	timer.start()

func _send_player_update(player: Node2D):
	if is_game_started and is_instance_valid(player):
		rpc_id(1, "update_player_state", player.position, player.rotation, player.velocity)

@rpc("authority", "unreliable")
func player_state_updated(peer_id: int, position: Vector2, rotation: float, velocity: Vector2):
	if peer_id in players and peer_id != my_peer_id:
		var player = players[peer_id]
		if player.has_node("NetworkSync"):
			player.get_node("NetworkSync").update_from_network(position, rotation, velocity)

@rpc("authority", "reliable")
func player_scored_update(peer_id: int, planet_index: int):
	#print("Player ", peer_id, " scored on planet ", planet_index)
	# TODO: Update UI with scores
	pass

func _update_player_count():
	var count = players.size()
	player_count_label.text = "Players: %d/3" % count
	
	if count < 3:
		waiting_label.text = "Waiting for players... (%d/3)" % count
	else:
		waiting_label.text = "Game starting!"

# Server RPCs (defined here for the client to call)
@rpc("any_peer", "reliable")
func request_join_game():
	pass

@rpc("any_peer", "unreliable")
func update_player_state(position: Vector2, rotation: float, velocity: Vector2):
	pass

@rpc("any_peer", "reliable")
func player_scored(planet_index: int):
	pass
