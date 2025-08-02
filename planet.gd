extends Node2D

var radius: float = 50.0
var planet_color: Color
var gravity_influence_distance: float = 250.0  # Distance at which this planet disables ground gravity
var gravity_strength: float = 400.0  # Gravitational pull strength (reduced by half)
var mass: float = 1.0  # Mass for gravity calculations

# Fade in/out properties
var fade_in_time: float = 1.0
var fade_out_time: float = 1.0
var current_alpha: float = 0.0
var is_fading_in: bool = true
var is_fading_out: bool = false
var fade_timer: float = 0.0
var has_been_orbited: bool = false

# Wave animation for gravity field
var wave_time: float = 0.0

# Orbit tracking for visual feedback
var orbiting_spaceship = null
var orbit_start_angle: float = 0.0
var orbit_progress: float = 0.0  # 0 to 1 representing completion
var orbit_completed: bool = false
var orbit_completion_animation: float = 0.0  # For animating the final arc fill
var orbit_direction: int = 1  # 1 for counter-clockwise, -1 for clockwise

func _ready() -> void:
	# Add to planets group
	add_to_group("planets")
	
	# Set to golden yellow
	planet_color = Color(0.996, 0.686, 0.204)
	queue_redraw()

func initialize(initial_radius: float) -> void:
	radius = initial_radius
	# Mass is proportional to area (radius squared)
	mass = (radius / 50.0) * (radius / 50.0)  # Normalized to 1.0 for 50 pixel radius

func _process(delta: float) -> void:
	# Update wave animation
	wave_time += delta
	
	# Handle fading
	if is_fading_in:
		fade_timer += delta
		current_alpha = fade_timer / fade_in_time
		if fade_timer >= fade_in_time:
			current_alpha = 1.0
			is_fading_in = false
			fade_timer = 0.0
	elif is_fading_out:
		fade_timer += delta
		current_alpha = 1.0 - (fade_timer / fade_out_time)
		if fade_timer >= fade_out_time:
			queue_free()
	
	# Animate orbit completion
	if orbit_completed and orbit_completion_animation < 1.0:
		orbit_completion_animation = min(1.0, orbit_completion_animation + delta * 3.0)  # Fill in over ~0.33 seconds
		queue_redraw()
	elif current_alpha < 1.0 or is_fading_in or is_fading_out:
		# Redraw if fading or animating
		queue_redraw()
	else:
		# Always redraw to animate the gravity sphere
		queue_redraw()

func mark_as_orbited() -> void:
	if not has_been_orbited:
		has_been_orbited = true
		is_fading_out = true
		fade_timer = 0.0

func start_orbit_tracking(spaceship, start_angle: float) -> void:
	orbiting_spaceship = spaceship
	orbit_start_angle = start_angle
	orbit_progress = 0.0
	orbit_direction = 1  # Will be updated by first progress update
	queue_redraw()

func update_orbit_progress(progress: float, direction: int) -> void:
	orbit_progress = clamp(progress, 0.0, 1.0)
	orbit_direction = direction
	queue_redraw()

func pause_orbit_tracking() -> void:
	# Just clear the spaceship reference but keep the progress visible
	orbiting_spaceship = null
	queue_redraw()

func stop_orbit_tracking() -> void:
	# Fully reset when spaceship crashes
	orbiting_spaceship = null
	orbit_progress = 0.0
	orbit_completed = false
	orbit_completion_animation = 0.0
	orbit_direction = 1
	queue_redraw()

func complete_orbit() -> void:
	orbit_completed = true
	orbit_completion_animation = 0.0
	queue_redraw()


func draw_animated_squiggly_circle(center: Vector2, radius: float, color: Color, width: float) -> void:
	# Draw an animated wavy circle
	var points = []
	var segments = 100  # More segments for smoother animation
	var squiggle_amplitude = 5.0  # How wavy the line is
	var squiggle_frequency = 8.0  # How many waves around the circle
	var wave_speed = 2.0  # Speed of wave animation
	
	for i in range(segments + 1):
		var angle = (i * TAU) / segments
		# Add animated squiggle offset based on angle and time
		var squiggle_offset = sin(angle * squiggle_frequency + wave_time * wave_speed) * squiggle_amplitude
		# Add a second wave for more organic movement
		squiggle_offset += sin(angle * squiggle_frequency * 0.7 - wave_time * wave_speed * 1.3) * squiggle_amplitude * 0.5
		
		var point_radius = radius + squiggle_offset
		var point = center + Vector2(cos(angle), sin(angle)) * point_radius
		points.append(point)
	
	# Draw the squiggly line
	for i in range(points.size() - 1):
		draw_line(points[i], points[i + 1], color, width)

func draw_squiggly_arc(center: Vector2, radius: float, start_angle: float, arc_length: float, 
					   color: Color, width: float, direction: int) -> void:
	# Draw a squiggly arc
	var points = []
	var segments = max(20, int(abs(arc_length) * 30))  # More segments for longer arcs
	var squiggle_amplitude = 3.0  # How wavy the line is
	var squiggle_frequency = 12.0  # How many waves in the arc
	
	for i in range(segments + 1):
		var t = float(i) / float(segments)
		var angle = start_angle + (arc_length * t * direction)
		# Add squiggle offset based on position along arc
		var squiggle_offset = sin(t * arc_length * squiggle_frequency) * squiggle_amplitude
		var point_radius = radius + squiggle_offset
		var point = center + Vector2(cos(angle), sin(angle)) * point_radius
		points.append(point)
	
	# Draw the squiggly line
	for i in range(points.size() - 1):
		draw_line(points[i], points[i + 1], color, width)

func _draw() -> void:
	# Apply alpha to colors
	var draw_color = Color(0.996, 0.686, 0.204, current_alpha)  # Golden yellow with alpha
	var outline_color = Color(0.8, 0.549, 0.163, current_alpha)  # Slightly darker golden for outline
	var influence_color = Color(0.996, 0.686, 0.204, 0.1 * current_alpha)  # Golden yellow with low alpha
	
	# Draw the planet circle
	draw_circle(Vector2.ZERO, radius, draw_color)
	
	# Draw orbit progress indicator - always show if there's progress
	if orbit_progress > 0 and not has_been_orbited:
		var progress_color = Color(0.996, 0.686, 0.204)
		progress_color.a = current_alpha
		var arc_radius = radius + 15  # Slightly outside the planet
		var arc_width = 8.0  # Thick border
		
		# Calculate the arc to draw
		var displayed_progress = orbit_progress
		if orbit_completed:
			# Animate from current progress to full circle
			# 1.333... = 1 / 0.75 to make full circle from 75% completion
			displayed_progress = lerp(orbit_progress, 1.0 / 0.75, orbit_completion_animation)
		
		# Check if we should draw a full circle
		if orbit_completed and orbit_completion_animation >= 1.0:
			# Draw complete circle to avoid gaps
			draw_arc(Vector2.ZERO, arc_radius, 0, TAU, 64, progress_color, arc_width)
		else:
			# Draw partial arc
			var arc_length = displayed_progress * TAU * 0.75  # 75% of circle = complete orbit
			
			# Handle direction - positive for counter-clockwise, negative for clockwise
			if orbit_direction > 0:
				# Counter-clockwise
				var end_angle = orbit_start_angle + arc_length
				if arc_length > 0.01:
					draw_arc(Vector2.ZERO, arc_radius, orbit_start_angle, end_angle, 
							max(8, int(arc_length * 10)), progress_color, arc_width)
			else:
				# Clockwise - draw from start backwards
				var end_angle = orbit_start_angle - arc_length
				if arc_length > 0.01:
					draw_arc(Vector2.ZERO, arc_radius, end_angle, orbit_start_angle, 
							max(8, int(arc_length * 10)), progress_color, arc_width)
	
	# Draw a darker outline (smooth)
	draw_arc(Vector2.ZERO, radius, 0, TAU, 64, outline_color, 3.0)
	
	# Draw gravity influence area with animated waves
	if gravity_influence_distance > radius and current_alpha > 0.5:
		draw_animated_squiggly_circle(Vector2.ZERO, gravity_influence_distance, influence_color, 4.0)
