extends Node

signal connected_to_server
signal connection_failed
signal server_disconnected
signal player_connected(peer_id)
signal player_disconnected(peer_id)

const SERVER_PORT = 8910

var peer: MultiplayerPeer
var is_server: bool = false

func create_server() -> int:
	peer = ENetMultiplayerPeer.new()
	var error = peer.create_server(SERVER_PORT, 30)
	
	if error == OK:
		get_multiplayer().multiplayer_peer = peer
		is_server = true
		
		# Connect server signals
		get_multiplayer().peer_connected.connect(_on_peer_connected)
		get_multiplayer().peer_disconnected.connect(_on_peer_disconnected)
	
	return error

func connect_to_server(address: String) -> int:
	peer = ENetMultiplayerPeer.new()
	var error = peer.create_client(address, SERVER_PORT)
	
	if error == OK:
		get_multiplayer().multiplayer_peer = peer
		is_server = false
		
		# Connect client signals
		get_multiplayer().connected_to_server.connect(_on_connected_to_server)
		get_multiplayer().connection_failed.connect(_on_connection_failed)
		get_multiplayer().server_disconnected.connect(_on_server_disconnected)
	
	return error

func _on_peer_connected(id: int):
	print("Peer connected: ", id)
	player_connected.emit(id)

func _on_peer_disconnected(id: int):
	print("Peer disconnected: ", id)
	player_disconnected.emit(id)

func _on_connected_to_server():
	print("Connected to server")
	connected_to_server.emit()

func _on_connection_failed():
	print("Failed to connect to server")
	connection_failed.emit()

func _on_server_disconnected():
	print("Disconnected from server")
	server_disconnected.emit()

func get_unique_id() -> int:
	if peer:
		return peer.get_unique_id()
	return -1

func close_connection():
	if peer:
		peer.close()
		get_multiplayer().multiplayer_peer = null