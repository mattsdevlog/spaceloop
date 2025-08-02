extends Node

# Configuration for server IP
# Change this to your Oracle Cloud server's public IP
const SERVER_IP = "127.0.0.1"  # Replace with your Oracle server IP

# Export this as autoload singleton for easy access
static func get_server_ip() -> String:
	return SERVER_IP

static func get_game_port() -> int:
	return 8910

static func get_http_port() -> int:
	return 8911

static func get_game_server_url() -> String:
	return "http://" + SERVER_IP + ":" + str(get_game_port())

static func get_status_server_url() -> String:
	return "http://" + SERVER_IP + ":" + str(get_http_port()) + "/status"