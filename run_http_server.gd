extends SceneTree

func _init():
	print("Starting HTTP Status Server...")
	
	# Create a root node
	var root_node = Node.new()
	root_node.name = "HTTPServerRoot"
	root.add_child(root_node)
	
	# Create HTTP server node
	var http_server = Node.new()
	http_server.name = "HTTPStatusServer"
	http_server.set_script(load("res://http_status_server.gd"))
	root_node.add_child(http_server)
	
	print("HTTP Status Server initialized on port 8911")
	
	# Keep running
	set_auto_accept_quit(false)

func _finalize():
	print("HTTP Status Server shutting down...")