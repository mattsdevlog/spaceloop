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
	var planets = []  # Array of planet data
	var asteroids = []  # Array of asteroid data
	var next_asteroid_id: int = 0
	var next_planet_id: int = 0
	var combined_score: int = 1  # Combined score countdown
	var is_ascending: bool = false  # Endgame state
	
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
	var name: String = "Player"
	
	func _init(id: int, color: int):
		peer_id = id
		color_index = color

func _ready():
	print("Starting dedicated server on port ", PORT)
	
	# Create multiplayer peer
	var peer = ENetMultiplayerPeer.new()
	var error = peer.create_server(PORT, MAX_PLAYERS * 10)  # Allow multiple games
	
	if error != OK:
		print("Failed to create server: ", error)
		return
		
	get_multiplayer().multiplayer_peer = peer
	
	# Connect signals
	get_multiplayer().peer_connected.connect(_on_peer_connected)
	get_multiplayer().peer_disconnected.connect(_on_peer_disconnected)
	
	# Start asteroid update timer
	var asteroid_timer = Timer.new()
	asteroid_timer.wait_time = 0.1  # 10 times per second
	asteroid_timer.timeout.connect(_update_asteroids)
	add_child(asteroid_timer)
	asteroid_timer.start()
	
	print("Server started successfully")

func _on_peer_connected(id: int):
	print("Player connected: ", id)

func _on_peer_disconnected(id: int):
	print("Player disconnected: ", id)
	_remove_player_from_game(id)

# RPC from client
@rpc("any_peer", "reliable")
func request_join_game(sender_peer_id: int, player_name: String = "Player"):
	var sender_id = get_multiplayer().get_remote_sender_id()
	print("Player ", sender_id, " (", player_name, ") requesting to join game")
	
	# Use the actual sender ID from multiplayer, not the passed parameter
	_handle_join_request(sender_id, player_name)

@rpc("any_peer", "reliable")
func update_player_full_state(sender_peer_id: int, position: Vector2, rotation: float, velocity: Vector2, fuel: float):
	var sender_id = get_multiplayer().get_remote_sender_id()
	_handle_player_full_state(sender_id, position, rotation, velocity, fuel)

@rpc("any_peer", "unreliable_ordered")
func update_player_inputs(sender_peer_id: int, input_left: bool, input_right: bool, input_up: bool):
	var sender_id = get_multiplayer().get_remote_sender_id()
	_handle_player_inputs(sender_id, input_left, input_right, input_up)


@rpc("any_peer", "reliable")
func player_scored(sender_peer_id: int, planet_index: int):
	var sender_id = get_multiplayer().get_remote_sender_id()
	_handle_player_score(sender_id, planet_index)

@rpc("any_peer", "reliable")
func planet_completed(planet_id: int):
	var sender_id = get_multiplayer().get_remote_sender_id()
	if sender_id in player_game_map:
		var game_id = player_game_map[sender_id]
		if game_id in games:
			var game = games[game_id]
			_handle_planet_completion(game, planet_id)

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

func _handle_join_request(sender_id: int, player_name: String = "Player"):
	# Find an available game or create new one
	var game = _find_available_game()
	if not game:
		game = _create_new_game()
	
	# Add player to game
	var color_index = game.players.size()  # 0, 1, or 2
	var player = PlayerData.new(sender_id, color_index)
	player.name = player_name
	game.players[sender_id] = player
	player_game_map[sender_id] = game.id
	
	# Send game info to the joining player (including player name)
	rpc_id(sender_id, "joined_game", game.id, color_index, _get_game_player_list(game))
	
	# If game has started, send current score
	if game.started:
		rpc_id(sender_id, "update_combined_score", game.combined_score)
	
	# Notify other players in the game
	for peer_id in game.players:
		if peer_id != sender_id:
			rpc_id(peer_id, "player_joined", sender_id, color_index, player_name)
	
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
	print("Created new game: ", game_id)
	return game

func _generate_game_id() -> String:
	return "game_" + str(Time.get_ticks_msec())

func _get_game_player_list(game: GameState) -> Array:
	var player_list = []
	for player in game.players.values():
		player_list.append({
			"peer_id": player.peer_id,
			"color_index": player.color_index,
			"name": player.name
		})
	return player_list

func _start_game(game: GameState):
	game.started = true
	print("Starting game: ", game.id)
	
	# Generate initial planets
	_generate_planets_for_game(game)
	
	# Start asteroid spawning timer for this game
	_start_asteroid_spawner(game)
	
	# Send initial game state to all players
	for peer_id in game.players:
		rpc_id(peer_id, "game_started")
		# Send planet data
		for planet in game.planets:
			rpc_id(peer_id, "spawn_planet", planet.id, planet.position, planet.radius, planet.color)
		# Send initial score
		rpc_id(peer_id, "update_combined_score", game.combined_score)

func _generate_planets_for_game(game: GameState):
	# Generate 1 initial planet with color
	# Use deterministic values based on planet ID for consistency
	var planet_id = game.next_planet_id
	
	# Generate deterministic position
	var pos_x = 200 + (planet_id * 137) % 800  # Using prime number for better distribution
	var pos_y = 300 + (planet_id * 241) % 600
	
	# Generate deterministic radius
	var radius = 50 + (planet_id * 73) % 50
	
	# Generate deterministic color using planet ID
	var r = ((planet_id * 73) % 256) / 255.0
	var g = ((planet_id * 179) % 256) / 255.0
	var b = ((planet_id * 283) % 256) / 255.0
	
	var planet_data = {
		"id": planet_id,
		"position": Vector2(pos_x, pos_y),
		"radius": radius,
		"color": Color(r, g, b)
	}
	game.planets.append(planet_data)
	game.next_planet_id += 1

func _start_asteroid_spawner(game: GameState):
	# Create a timer for asteroid spawning
	var timer = Timer.new()
	timer.wait_time = 2.0
	timer.timeout.connect(_spawn_asteroid_for_game.bind(game))
	timer.name = "AsteroidTimer_" + game.id
	add_child(timer)
	timer.start()

func _spawn_asteroid_for_game(game: GameState):
	if not game.started or game.is_ascending:
		return
		
	# Limit asteroids
	var active_asteroids = 0
	for asteroid in game.asteroids:
		if asteroid.active:
			active_asteroids += 1
	
	if active_asteroids >= 4:
		return
	
	# Create new asteroid with valid spawn position
	var valid_spawn = false
	var attempts = 0
	var start_pos: Vector2
	var direction: Vector2
	
	while not valid_spawn and attempts < 10:
		attempts += 1
		
		var side = randf() < 0.5
		# Keep asteroids well above ground level (ground is at y=1257)
		start_pos = Vector2(-50 if side else 1250, randf_range(100, 1050))
		direction = Vector2(1 if side else -1, randf_range(-0.5, 0.5)).normalized()
		
		# Check if spawn position is outside all gravity spheres
		valid_spawn = true
		for planet in game.planets:
			var distance = start_pos.distance_to(planet.position)
			# Add margin to ensure asteroid spawns well outside
			if distance < 350:  # 300 (gravity radius) + 50 (margin)
				valid_spawn = false
				break
	
	var speed = randf_range(50, 150)
	
	var asteroid_data = {
		"id": game.next_asteroid_id,
		"position": start_pos,
		"velocity": direction * speed,
		"rotation": 0.0,
		"rotation_speed": randf_range(-2.0, 2.0),
		"radius": randf_range(20, 40),
		"active": true,
		"seed": randi()  # Random seed for shape generation
	}
	
	game.asteroids.append(asteroid_data)
	game.next_asteroid_id += 1
	
	# Send to all players in game
	for peer_id in game.players:
		rpc_id(peer_id, "spawn_asteroid", asteroid_data.id, asteroid_data.position, 
			asteroid_data.velocity, asteroid_data.rotation_speed, asteroid_data.radius, asteroid_data.seed)

func _handle_player_full_state(sender_id: int, position: Vector2, rotation: float, velocity: Vector2, fuel: float):
	if sender_id in player_game_map:
		var game_id = player_game_map[sender_id]
		if game_id in games:
			var game = games[game_id]
			if sender_id in game.players:
				# Store state for server tracking
				var player = game.players[sender_id]
				player.position = position
				player.rotation = rotation
				player.velocity = velocity
				
				# Relay full state to other players in the same game
				for peer_id in game.players:
					if peer_id != sender_id:
						rpc_id(peer_id, "player_full_state_updated", sender_id, position, rotation, velocity, fuel)


func _handle_player_inputs(sender_id: int, input_left: bool, input_right: bool, input_up: bool):
	if sender_id in player_game_map:
		var game_id = player_game_map[sender_id]
		if game_id in games:
			var game = games[game_id]
			if sender_id in game.players:
				# Relay input state to other players for visual effects
				for peer_id in game.players:
					if peer_id != sender_id:
						rpc_id(peer_id, "player_inputs_updated", sender_id, input_left, input_right, input_up)

func _handle_player_score(sender_id: int, planet_index: int):
	if sender_id in player_game_map:
		var game_id = player_game_map[sender_id]
		if game_id in games:
			var game = games[game_id]
			
			# Decrement combined score
			game.combined_score = max(0, game.combined_score - 1)
			
			# Relay score update to all players in the game
			for peer_id in game.players:
				rpc_id(peer_id, "player_scored_update", sender_id, planet_index)
				rpc_id(peer_id, "update_combined_score", game.combined_score)
			
			# Check for ascension
			if game.combined_score <= 0 and not game.is_ascending:
				_start_ascension(game)

func _handle_planet_completion(game: GameState, planet_id: int):
	# Remove the old planet
	for i in range(game.planets.size()):
		if game.planets[i].id == planet_id:
			game.planets.remove_at(i)
			break
	
	# Notify all players to remove the planet
	for peer_id in game.players:
		rpc_id(peer_id, "destroy_planet", planet_id)
	
	# Spawn a new planet after a short delay
	var timer = Timer.new()
	timer.wait_time = 2.0
	timer.one_shot = true
	timer.timeout.connect(_spawn_new_planet.bind(game))
	add_child(timer)
	timer.start()

func _spawn_new_planet(game: GameState):
	# Don't spawn new planets during ascension
	if game.is_ascending:
		return
	
	# Generate new planet with color
	# Use deterministic values based on planet ID for consistency
	var planet_id = game.next_planet_id
	
	# Generate deterministic position
	var pos_x = 200 + (planet_id * 137) % 800  # Using prime number for better distribution
	var pos_y = 300 + (planet_id * 241) % 600
	
	# Generate deterministic radius
	var radius = 50 + (planet_id * 73) % 50
	
	# Generate deterministic color using planet ID
	var r = ((planet_id * 73) % 256) / 255.0
	var g = ((planet_id * 179) % 256) / 255.0
	var b = ((planet_id * 283) % 256) / 255.0
	
	var planet_data = {
		"id": planet_id,
		"position": Vector2(pos_x, pos_y),
		"radius": radius,
		"color": Color(r, g, b)
	}
	game.planets.append(planet_data)
	game.next_planet_id += 1
	
	# Send to all players
	for peer_id in game.players:
		rpc_id(peer_id, "spawn_planet", planet_data.id, planet_data.position, planet_data.radius, planet_data.color)

# RPC definitions (empty stubs for server)
@rpc("authority", "reliable")
func joined_game(server_game_id: String, color_index: int, player_list: Array):
	pass

@rpc("authority", "reliable")
func player_joined(peer_id: int, color_index: int, player_name: String = "Player"):
	pass

@rpc("authority", "reliable")
func player_left(peer_id: int):
	pass

@rpc("authority", "reliable")
func game_started():
	pass

@rpc("authority", "reliable")
func player_full_state_updated(peer_id: int, position: Vector2, rotation: float, velocity: Vector2, fuel: float):
	pass

@rpc("authority", "unreliable_ordered")
func player_inputs_updated(peer_id: int, input_left: bool, input_right: bool, input_up: bool):
	pass

@rpc("authority", "reliable")
func player_scored_update(peer_id: int, planet_index: int):
	pass

@rpc("authority", "reliable")
func spawn_planet(planet_id: int, position: Vector2, radius: float, color: Color):
	pass

@rpc("authority", "reliable")
func spawn_asteroid(asteroid_id: int, position: Vector2, velocity: Vector2, rotation_speed: float, radius: float, shape_seed: int):
	pass

@rpc("authority", "reliable")
func destroy_asteroid(asteroid_id: int):
	pass

@rpc("authority", "reliable")
func destroy_planet(planet_id: int):
	pass

@rpc("authority", "unreliable_ordered")
func update_asteroid(asteroid_id: int, position: Vector2, velocity: Vector2):
	pass

@rpc("authority", "reliable")
func receive_chat_message(sender_id: int, message: String):
	pass

@rpc("authority", "reliable")
func update_combined_score(score: int):
	pass

@rpc("authority", "reliable")
func activate_launchpad(launchpad_index: int):
	pass

@rpc("authority", "reliable")
func deactivate_launchpad(launchpad_index: int):
	pass

@rpc("authority", "reliable")
func start_ascension_sequence():
	pass

@rpc("authority", "reliable")
func spawn_remote_projectile(shooter_id: int, position: Vector2, velocity: Vector2):
	pass

@rpc("authority", "reliable")
func player_eliminated(player_id: int, killer_id: int):
	pass

@rpc("authority", "reliable")
func player_health_updated(player_id: int, health: float):
	pass

# Chat handling
@rpc("any_peer", "reliable")
func send_chat_message(sender_peer_id: int, message: String):
	var sender_id = get_multiplayer().get_remote_sender_id()
	if sender_id in player_game_map:
		var game_id = player_game_map[sender_id]
		if game_id in games:
			var game = games[game_id]
			# Relay chat message to all players in the game
			for peer_id in game.players:
				rpc_id(peer_id, "receive_chat_message", sender_id, message)

# Launchpad activation handling
@rpc("any_peer", "reliable")
func request_activate_launchpad(sender_peer_id: int, launchpad_index: int):
	var sender_id = get_multiplayer().get_remote_sender_id()
	if sender_id in player_game_map:
		var game_id = player_game_map[sender_id]
		if game_id in games:
			var game = games[game_id]
			# Notify all players in the game to activate the launchpad
			for peer_id in game.players:
				rpc_id(peer_id, "activate_launchpad", launchpad_index)

@rpc("any_peer", "reliable")
func request_deactivate_launchpad(sender_peer_id: int, launchpad_index: int):
	var sender_id = get_multiplayer().get_remote_sender_id()
	if sender_id in player_game_map:
		var game_id = player_game_map[sender_id]
		if game_id in games:
			var game = games[game_id]
			# Notify all players in the game to deactivate the launchpad
			for peer_id in game.players:
				rpc_id(peer_id, "deactivate_launchpad", launchpad_index)

# Removed spaceship_hit and position_corrected - collisions are now handled locally on clients

func _start_ascension(game: GameState):
	game.is_ascending = true
	print("Game ", game.id, " entering ascension phase!")
	
	# Notify all players to start ascension
	for peer_id in game.players:
		rpc_id(peer_id, "start_ascension_sequence")

# Handle ascension notification from client
@rpc("any_peer", "reliable")
func notify_ascension_started(sender_peer_id: int):
	var sender_id = get_multiplayer().get_remote_sender_id()
	if sender_id in player_game_map:
		var game_id = player_game_map[sender_id]
		if game_id in games:
			var game = games[game_id]
			# Mark game as ascending to stop planet spawning
			game.is_ascending = true

# Handle battle phase notification
@rpc("any_peer", "reliable")
func notify_battle_phase_started(sender_peer_id: int):
	var sender_id = get_multiplayer().get_remote_sender_id()
	if sender_id in player_game_map:
		var game_id = player_game_map[sender_id]
		if game_id in games:
			var game = games[game_id]
			# Battle phase - no server logic needed, just for tracking

# Handle shooting
@rpc("any_peer", "reliable")
func player_shot(shooter_id: int, position: Vector2, velocity: Vector2):
	var sender_id = get_multiplayer().get_remote_sender_id()
	if sender_id in player_game_map:
		var game_id = player_game_map[sender_id]
		if game_id in games:
			var game = games[game_id]
			# Relay shot to all other players
			for peer_id in game.players:
				if peer_id != sender_id:
					rpc_id(peer_id, "spawn_remote_projectile", sender_id, position, velocity)

# Handle player death
@rpc("any_peer", "reliable")
func player_died(player_id: int, killer_id: int):
	var sender_id = get_multiplayer().get_remote_sender_id()
	if sender_id in player_game_map:
		var game_id = player_game_map[sender_id]
		if game_id in games:
			var game = games[game_id]
			# Notify all players about the death
			for peer_id in game.players:
				rpc_id(peer_id, "player_eliminated", player_id, killer_id)

# Handle health updates
@rpc("any_peer", "reliable")
func update_player_health(player_id: int, health: float):
	var sender_id = get_multiplayer().get_remote_sender_id()
	if sender_id in player_game_map:
		var game_id = player_game_map[sender_id]
		if game_id in games:
			var game = games[game_id]
			# Relay health update to all players
			for peer_id in game.players:
				rpc_id(peer_id, "player_health_updated", player_id, health)

func _update_asteroids():
	# Update all asteroid positions in all games
	for game in games.values():
		if not game.started:
			continue
	
		# Update asteroids
		var asteroids_to_remove = []
		for asteroid in game.asteroids:
			if not asteroid.active:
				continue
				
			# Update position
			asteroid.position += asteroid.velocity * 0.1  # Match timer interval
			asteroid.rotation += asteroid.rotation_speed * 0.1
			
			# Check collisions with other asteroids
			for other_asteroid in game.asteroids:
				if other_asteroid.id == asteroid.id or not other_asteroid.active:
					continue
				
				# Only check asteroids with higher IDs to avoid double-checking
				if other_asteroid.id < asteroid.id:
					continue
				
				var distance = asteroid.position.distance_to(other_asteroid.position)
				var min_distance = asteroid.radius + other_asteroid.radius
				
				if distance < min_distance:
					# Collision detected!
					var collision_normal = (asteroid.position - other_asteroid.position).normalized()
					if distance < 0.001:
						collision_normal = Vector2.UP
						distance = 0.001
					
					# Separate overlapping asteroids
					var overlap = min_distance - distance
					asteroid.position += collision_normal * (overlap * 0.5)
					other_asteroid.position -= collision_normal * (overlap * 0.5)
					
					# Calculate relative velocity
					var relative_velocity = asteroid.velocity - other_asteroid.velocity
					var velocity_along_normal = relative_velocity.dot(collision_normal)
					
					# Only resolve if moving towards each other
					if velocity_along_normal < 0:
						# Calculate masses based on radius
						var mass1 = asteroid.radius / 30.0
						var mass2 = other_asteroid.radius / 30.0
						
						# Perfect elastic collision
						var impulse = 2 * velocity_along_normal / (mass1 + mass2)
						
						# Apply impulse to velocities
						asteroid.velocity -= impulse * mass2 * collision_normal
						other_asteroid.velocity += impulse * mass1 * collision_normal
						
						# Update clients immediately with new velocities
						for peer_id in game.players:
							rpc_id(peer_id, "update_asteroid", asteroid.id, asteroid.position, asteroid.velocity)
							rpc_id(peer_id, "update_asteroid", other_asteroid.id, other_asteroid.position, other_asteroid.velocity)
			
			# Apply gravity and check planet deflection
			for planet in game.planets:
				var to_planet = planet.position - asteroid.position
				var distance = to_planet.length()
				var gravity_radius = 300.0  # Default gravity influence distance
				
				# Check if asteroid is at the edge of gravity influence sphere
				var asteroid_edge_distance = distance - asteroid.radius
				
				if asteroid_edge_distance <= gravity_radius + 5:
					# Asteroid is near or inside gravity sphere
					var from_planet = -to_planet.normalized()
					
					# Check if we're near the boundary
					if asteroid_edge_distance > gravity_radius - 50:  # Near boundary zone
						var velocity_towards_planet = asteroid.velocity.dot(-from_planet)
						
						# Outside but moving in
						if asteroid_edge_distance > gravity_radius and velocity_towards_planet > 0:
							# Deflect off the gravity sphere
							asteroid.velocity = asteroid.velocity.reflect(from_planet)
							asteroid.velocity += from_planet * 50  # Add escape velocity
							
							# Update clients with new velocity
							for peer_id in game.players:
								rpc_id(peer_id, "update_asteroid", asteroid.id, asteroid.position, asteroid.velocity)
						
						# Inside the boundary - push out
						elif asteroid_edge_distance <= gravity_radius:
							var push_distance = gravity_radius - asteroid_edge_distance + 10
							asteroid.position += from_planet * push_distance
							
							# Ensure velocity points away
							if velocity_towards_planet > 0:
								asteroid.velocity = asteroid.velocity.reflect(from_planet)
							asteroid.velocity += from_planet * 100  # Strong escape velocity
							
							# Update clients with new position and velocity
							for peer_id in game.players:
								rpc_id(peer_id, "update_asteroid", asteroid.id, asteroid.position, asteroid.velocity)
					else:
						# Deep inside gravity well - apply gravity
						var gravity_factor = 1.0 - (distance / gravity_radius)
						gravity_factor = gravity_factor * gravity_factor
						
						var force_magnitude = 100.0 * gravity_factor  # Planet gravity strength (reduced by half)
						asteroid.velocity += -from_planet * force_magnitude * 0.1  # Apply over time interval
			
			# Send to all players
			for peer_id in game.players:
				rpc_id(peer_id, "update_asteroid", asteroid.id, asteroid.position, asteroid.velocity)
		
			# Check launchpad protective arcs
			var launchpad_positions = [Vector2(300, 1221), Vector2(600, 1221), Vector2(900, 1221)]
			var protection_radius = 240.0
			
			for pad_pos in launchpad_positions:
				var to_asteroid = asteroid.position - pad_pos
				var distance = to_asteroid.length()
				var angle = to_asteroid.angle()
				
				# Check if in upper hemisphere and close to arc
				if angle >= -PI and angle <= 0 and distance - asteroid.radius < protection_radius + 5:
					# Bounce off the arc
					var normal = to_asteroid.normalized()
					var overlap = protection_radius - (distance - asteroid.radius) + 5
					asteroid.position += normal * overlap
					
					# Reverse velocity component
					var velocity_along_normal = asteroid.velocity.dot(normal)
					if velocity_along_normal < 0:
						asteroid.velocity -= normal * velocity_along_normal * 2.0
						
						# Update all clients with new velocity
						for peer_id in game.players:
							rpc_id(peer_id, "update_asteroid", asteroid.id, asteroid.position, asteroid.velocity)
						break  # Only handle one collision per frame
			
			# Check if off-screen
			if asteroid.position.x < -100 or asteroid.position.x > 1300:
				asteroids_to_remove.append(asteroid.id)
				asteroid.active = false
				
				# Notify all players
				for peer_id in game.players:
					rpc_id(peer_id, "destroy_asteroid", asteroid.id)
			elif asteroid.position.y < -100 or asteroid.position.y > 1500:
				asteroids_to_remove.append(asteroid.id)
				asteroid.active = false
				
				# Notify all players
				for peer_id in game.players:
					rpc_id(peer_id, "destroy_asteroid", asteroid.id)
		
		# Clean up inactive asteroids periodically
		if game.asteroids.size() > 20:
			game.asteroids = game.asteroids.filter(func(a): return a.active)
