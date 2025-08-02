extends SceneTree

func _init():
	#print("Initializing Spaceloop Server...")
	
	# Create a root node for the server
	var server_root = Node2D.new()
	server_root.name = "ServerRoot"
	root.add_child(server_root)
	
	# Create server node
	var server = Node2D.new()
	server.name = "Server"
	server.set_script(load("res://server.gd"))
	server_root.add_child(server)
	
	#print("Server node added to scene tree")
	
	# Keep the server running
	set_auto_accept_quit(false)

func _finalize():
	#print("Server shutting down...")