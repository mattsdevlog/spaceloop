extends Node2D

# Server configuration
const PORT = 8910
const MAX_PLAYERS = 3

# Game state
var games = {}  # Dictionary of game_id -> GameState
var player_game_map = {}  # Dictionary of player_id -> game_id

class GameState:
	var id: String
	var players = {}  # Dictionary of peer_id -> PlayerData
	var started: bool = false
	var created_time: float
	
	func _init(game_id: String):
		id = game_id
		created_time = Time.get_ticks_msec() / 1000.0

class PlayerData:
	var peer_id: int
	var position: Vector2
	var rotation: float
	var velocity: Vector2
	var color_index: int  # 0=yellow, 1=light blue, 2=red
	var ready: bool = false
	
	func _init(id: int, color: int):
		peer_id = id
		color_index = color

func _ready():
	#print("Starting dedicated server on port ", PORT)
	
	# Create multiplayer peer
	var peer = ENetMultiplayerPeer.new()
	var error = peer.create_server(PORT, MAX_PLAYERS * 10)  # Allow multiple games
	
	if error != OK:
		#print("Failed to create server: ", error)
		return
		
	multiplayer.multiplayer_peer = peer
	
	# Connect signals
	multiplayer.peer_connected.connect(_on_peer_connected)
	multiplayer.peer_disconnected.connect(_on_peer_disconnected)
	
	#print("Server started successfully")

func _on_peer_connected(id: int):
	#print("Player connected: ", id)
	# Client will request to join a game

func _on_peer_disconnected(id: int):
	#print("Player disconnected: ", id)
	_remove_player_from_game(id)

func _remove_player_from_game(player_id: int):
	if player_id in player_game_map:
		var game_id = player_game_map[player_id]
		if game_id in games:
			var game = games[game_id]
			if player_id in game.players:
				game.players.erase(player_id)
				player_game_map.erase(player_id)
				
				# Notify other players
				for peer_id in game.players:
					rpc_id(peer_id, "player_left", player_id)
				
				# Remove empty games
				if game.players.is_empty():
					games.erase(game_id)

@rpc("any_peer", "call_remote", "reliable")
func request_join_game():
	var sender_id = multiplayer.get_remote_sender_id()
	#print("Player ", sender_id, " requesting to join game")
	
	# Find an available game or create new one
	var game = _find_available_game()
	if not game:
		game = _create_new_game()
	
	# Add player to game
	var color_index = game.players.size()  # 0, 1, or 2
	var player = PlayerData.new(sender_id, color_index)
	game.players[sender_id] = player
	player_game_map[sender_id] = game.id
	
	# Send game info to the joining player
	rpc_id(sender_id, "joined_game", game.id, color_index, _get_game_player_list(game))
	
	# Notify other players in the game
	for peer_id in game.players:
		if peer_id != sender_id:
			rpc_id(peer_id, "player_joined", sender_id, color_index)
	
	# Check if game is full and should start
	if game.players.size() == MAX_PLAYERS and not game.started:
		_start_game(game)

func _find_available_game() -> GameState:
	for game in games.values():
		if not game.started and game.players.size() < MAX_PLAYERS:
			# Check if game is not too old (5 minutes timeout)
			var age = Time.get_ticks_msec() / 1000.0 - game.created_time
			if age < 300:  # 5 minutes
				return game
	return null

func _create_new_game() -> GameState:
	var game_id = _generate_game_id()
	var game = GameState.new(game_id)
	games[game_id] = game
	#print("Created new game: ", game_id)
	return game

func _generate_game_id() -> String:
	return "game_" + str(Time.get_ticks_msec())

func _get_game_player_list(game: GameState) -> Array:
	var player_list = []
	for player in game.players.values():
		player_list.append({
			"peer_id": player.peer_id,
			"color_index": player.color_index
		})
	return player_list

func _start_game(game: GameState):
	game.started = true
	#print("Starting game: ", game.id)
	
	# Notify all players that game is starting
	for peer_id in game.players:
		rpc_id(peer_id, "game_started")

@rpc("any_peer", "call_remote", "unreliable")
func update_player_state(position: Vector2, rotation: float, velocity: Vector2):
	var sender_id = multiplayer.get_remote_sender_id()
	
	if sender_id in player_game_map:
		var game_id = player_game_map[sender_id]
		if game_id in games:
			var game = games[game_id]
			if sender_id in game.players:
				var player = game.players[sender_id]
				player.position = position
				player.rotation = rotation
				player.velocity = velocity
				
				# Relay to other players in the same game
				for peer_id in game.players:
					if peer_id != sender_id:
						rpc_id(peer_id, "player_state_updated", sender_id, position, rotation, velocity)

@rpc("any_peer", "call_remote", "reliable")
func player_scored(planet_index: int):
	var sender_id = multiplayer.get_remote_sender_id()
	
	if sender_id in player_game_map:
		var game_id = player_game_map[sender_id]
		if game_id in games:
			var game = games[game_id]
			
			# Relay score to all players in the game
			for peer_id in game.players:
				rpc_id(peer_id, "player_scored_update", sender_id, planet_index)

@rpc("any_peer", "call_remote", "reliable")
func request_player_count():
	var sender_id = multiplayer.get_remote_sender_id()
	
	# Count total players across all games
	var total_players = 0
	for game_id in games:
		total_players += games[game_id].players.size()
	
	# Send count back to requester
	rpc_id(sender_id, "receive_player_count", total_players)

# Client RPCs (empty implementations for server)
@rpc("authority", "call_remote", "reliable")
func joined_game(game_id: String, color_index: int, player_list: Array):
	pass

@rpc("authority", "call_remote", "reliable")
func player_joined(peer_id: int, color_index: int):
	pass

@rpc("authority", "call_remote", "reliable")
func player_left(peer_id: int):
	pass

@rpc("authority", "call_remote", "reliable")
func game_started():
	pass

@rpc("authority", "call_remote", "unreliable")
func player_state_updated(peer_id: int, position: Vector2, rotation: float, velocity: Vector2):
	pass

@rpc("authority", "call_remote", "reliable")
func player_scored_update(peer_id: int, planet_index: int):
	pass

@rpc("authority", "call_remote", "reliable")
func receive_player_count(count: int):
	pass