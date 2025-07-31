extends RigidBody2D

var initial_velocity: Vector2 = Vector2.ZERO
var lifetime: float = 3.0
var age: float = 0.0
var radius: float = 10.0
var smoke_color: Color = Color.WHITE

func _ready() -> void:
	# Set up physics properties for jelly-like behavior
	gravity_scale = 0.5
	linear_damp = 0.5
	angular_damp = 0.5
	physics_material_override = PhysicsMaterial.new()
	physics_material_override.bounce = 0.8  # High bounce for jelly effect
	physics_material_override.friction = 0.1  # Low friction for smooth sliding
	
	# Apply initial velocity
	linear_velocity = initial_velocity
	
	# Add some random rotation
	angular_velocity = randf_range(-3.0, 3.0)
	
	# Set up collision
	var collision_shape = CollisionShape2D.new()
	var circle_shape = CircleShape2D.new()
	circle_shape.radius = radius
	collision_shape.shape = circle_shape
	add_child(collision_shape)
	
	# Set collision layers - smoke particles collide with everything including each other
	collision_layer = 4  # Smoke layer (bit 2)
	collision_mask = 7   # Collide with default (1), unused (2), and other smoke (4)

func _process(delta: float) -> void:
	age += delta
	
	# Fade out over time
	var progress = age / lifetime
	var alpha = 1.0 - progress
	smoke_color.a = alpha
	
	# Remove when lifetime expires
	if age >= lifetime:
		queue_free()
	
	queue_redraw()

func _draw() -> void:
	# Draw solid white circle
	draw_circle(Vector2.ZERO, radius, smoke_color)
	
	# Draw a subtle outline for definition
	draw_arc(Vector2.ZERO, radius, 0, TAU, 32, Color(0.9, 0.9, 0.9, smoke_color.a), 1.0)