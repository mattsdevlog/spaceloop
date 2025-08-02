extends Area2D

var velocity: Vector2 = Vector2.ZERO
var shooter_id: int = -1
var damage: float = 20.0  # 20% of health per hit
var lifetime: float = 5.0

func _ready():
	add_to_group("projectiles")
	
	# Set up collision
	var collision_shape = CollisionShape2D.new()
	var circle_shape = CircleShape2D.new()
	circle_shape.radius = 3.0
	collision_shape.shape = circle_shape
	add_child(collision_shape)
	
	# Connect area entered signal
	area_entered.connect(_on_area_entered)
	body_entered.connect(_on_body_entered)

func _physics_process(delta: float):
	position += velocity * delta
	
	lifetime -= delta
	if lifetime <= 0:
		queue_free()
	
	# Remove if off screen (account for camera position)
	var viewport = get_viewport_rect()
	var camera = get_viewport().get_camera_2d()
	
	if position.x < -50 or position.x > viewport.size.x + 50:
		queue_free()
		
	# Use camera-relative boundaries for vertical check
	if camera:
		var top_bound = camera.global_position.y - viewport.size.y / 2 - 100
		var bottom_bound = camera.global_position.y + viewport.size.y / 2 + 100
		if global_position.y < top_bound or global_position.y > bottom_bound:
			queue_free()
	else:
		if position.y < -500 or position.y > viewport.size.y + 50:
			queue_free()
	
	# Check collision with spaceships
	check_spaceship_collisions()

func _draw():
	# Draw a simple circle projectile
	draw_circle(Vector2.ZERO, 3.0, Color.YELLOW)
	draw_circle(Vector2.ZERO, 2.0, Color.WHITE)

func _on_area_entered(area):
	# Not used - spaceships are Node2D not Area2D
	pass

func _on_body_entered(body):
	# Hit something solid, destroy projectile
	queue_free()

func check_spaceship_collisions():
	# Get all player spaceships
	var multiplayer_client = get_node_or_null("/root/MultiplayerGame")
	if not multiplayer_client:
		return
	
	for player_id in multiplayer_client.players:
		var spaceship = multiplayer_client.players[player_id]
		if not is_instance_valid(spaceship) or spaceship.is_shattered:
			continue
		
		# Don't hit the shooter
		if player_id == shooter_id:
			continue
		
		# Check distance for collision (spaceships have ~30 unit radius)
		var distance = global_position.distance_to(spaceship.global_position)
		if distance < 30.0:
			# Hit detected!
			# Call take_damage - it will check authority internally
			if spaceship.has_method("take_damage"):
				spaceship.take_damage(damage, shooter_id)
			
			queue_free()
			break