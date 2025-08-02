extends Node

# Server configuration
const IS_LOCAL = false  # Set to false for production
const LOCAL_IP = "127.0.0.1"
const PRODUCTION_IP = "YOUR_SERVER_IP"  # Replace with your server's public IP

static func get_server_ip() -> String:
	return LOCAL_IP if IS_LOCAL else PRODUCTION_IP

static func get_game_port() -> int:
	return 8910

static func get_http_port() -> int:
	return 8911