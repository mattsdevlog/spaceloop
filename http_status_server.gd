extends Node

# HTTP Server for status queries
var tcp_server: TCPServer
var port: int = 8911  # Different port from game server
var ascended_players_ref = null  # Reference to main server's ascended list
var games_ref = null  # Reference to main server's games

func _ready():
	tcp_server = TCPServer.new()
	var error = tcp_server.listen(port)
	if error != OK:
		print("Failed to start HTTP server on port ", port)
	else:
		print("HTTP status server started on port ", port)

func _process(_delta):
	if not tcp_server.is_listening():
		return
		
	# Check for new connections
	if tcp_server.is_connection_available():
		var client = tcp_server.take_connection()
		_handle_client(client)

func _handle_client(client: StreamPeerTCP):
	# Read the HTTP request
	var request = ""
	var timeout = 0.5
	var start_time = Time.get_ticks_msec() / 1000.0
	
	while client.get_status() == StreamPeerTCP.STATUS_CONNECTED:
		if Time.get_ticks_msec() / 1000.0 - start_time > timeout:
			break
			
		if client.get_available_bytes() > 0:
			var data = client.get_utf8_string(client.get_available_bytes())
			request += data
			
			# Check if we have a complete request
			if request.find("\r\n\r\n") != -1 or request.find("\n\n") != -1:
				break
	
	# Parse the request
	var lines = request.split("\n")
	if lines.size() == 0:
		client.disconnect_from_host()
		return
		
	var request_line = lines[0].strip_edges()
	var parts = request_line.split(" ")
	
	if parts.size() < 2:
		client.disconnect_from_host()
		return
		
	var method = parts[0]
	var path = parts[1]
	
	# Handle different endpoints
	if method == "GET":
		if path == "/ascended":
			_send_ascended_list(client)
		elif path == "/players":
			_send_player_count(client)
		elif path == "/status":
			_send_full_status(client)
		else:
			_send_404(client)
	else:
		_send_404(client)
	
	# Close connection
	client.disconnect_from_host()

func _send_ascended_list(client: StreamPeerTCP):
	var ascended_list = []
	if ascended_players_ref:
		ascended_list = ascended_players_ref
	
	var json_data = JSON.stringify({
		"ascended_players": ascended_list,
		"count": ascended_list.size()
	})
	
	_send_http_response(client, 200, "OK", json_data, "application/json")

func _send_player_count(client: StreamPeerTCP):
	var total_players = 0
	if games_ref:
		for game_id in games_ref:
			total_players += games_ref[game_id].players.size()
	
	var json_data = JSON.stringify({
		"online_players": total_players
	})
	
	_send_http_response(client, 200, "OK", json_data, "application/json")

func _send_full_status(client: StreamPeerTCP):
	var total_players = 0
	var games_count = 0
	
	if games_ref:
		games_count = games_ref.size()
		for game_id in games_ref:
			total_players += games_ref[game_id].players.size()
	
	var ascended_list = []
	if ascended_players_ref:
		ascended_list = ascended_players_ref
	
	var json_data = JSON.stringify({
		"online_players": total_players,
		"active_games": games_count,
		"ascended_players": ascended_list,
		"ascended_count": ascended_list.size()
	})
	
	_send_http_response(client, 200, "OK", json_data, "application/json")

func _send_404(client: StreamPeerTCP):
	_send_http_response(client, 404, "Not Found", "Not Found", "text/plain")

func _send_http_response(client: StreamPeerTCP, code: int, status: String, body: String, content_type: String):
	var response = "HTTP/1.1 %d %s\r\n" % [code, status]
	response += "Content-Type: %s\r\n" % content_type
	response += "Content-Length: %d\r\n" % body.length()
	response += "Access-Control-Allow-Origin: *\r\n"  # Allow CORS
	response += "Connection: close\r\n"
	response += "\r\n"
	response += body
	
	client.put_data(response.to_utf8_buffer())

func set_references(ascended_players, games):
	ascended_players_ref = ascended_players
	games_ref = games