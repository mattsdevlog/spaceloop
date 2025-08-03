extends Node2D

# Server configuration
const PORT = 8910
const MAX_PLAYERS = 3

# Game state
var games = {}  # Dictionary of game_id -> GameState
var player_game_map = {}  # Dictionary of player_id -> game_id
var status_connections = []  # List of peer_ids that are just checking status
var ascended_players = []  # List of player names who have won

var all_connected_peers = []  # List of all connected peer IDs
const ASCENDED_FILE = "user://ascended_players.txt"

func _ready():
	print("Starting dedicated server on port ", PORT)
	
	# Create multiplayer peer - Use WebSocket for web compatibility
	var peer = WebSocketMultiplayerPeer.new()
	
	# Try binding to localhost specifically
	print("Creating WebSocket server on port ", PORT)
	var error = peer.create_server(PORT, "127.0.0.1")
	
	if error != OK:
		print("Failed to create server on localhost, trying all interfaces...")
		error = peer.create_server(PORT, "*")
		
	if error != OK:
		print("Failed to create server on port ", PORT, ": ", error)
		return
		
	get_multiplayer().multiplayer_peer = peer
	print("Server started successfully on port ", PORT)
	
	# Rest of the server code remains the same...