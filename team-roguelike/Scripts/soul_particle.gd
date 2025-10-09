extends Node2D
@export var speed: float = 900.0
@onready var particles := $Particles
var target_position: Vector2 = Vector2.ZERO
var _started: bool = false
var _core: Sprite2D
var _glow: Sprite2D
var _travel_progress: float = 0.0
var _wave_offset: float = 0.0
var _wave_frequency: float = 0.0
var _wave_amplitude: float = 0.0
var _start_position: Vector2 = Vector2.ZERO
var _direction: Vector2 = Vector2.ZERO
var _trail_timer: float = 0.0
var _is_moving: bool = false
var _trail_particles: Array = []

func _ready():
	if not has_node("Core"):
		_core = Sprite2D.new()
		_core.name = "Core"
		_core.texture = _create_circle_texture(8, Color(0.45, 0.95, 1.0, 1.0))
		_core.centered = true
		_core.z_index = 2000
		add_child(_core)
	else:
		_core = $Core
	
	_glow = Sprite2D.new()
	_glow.name = "Glow"
	_glow.texture = _create_circle_texture(16, Color(0.45, 0.95, 1.0, 0.3))
	_glow.centered = true
	_glow.z_index = 1999
	add_child(_glow)
	
	_core.scale = Vector2.ONE * 1.2
	_glow.scale = Vector2.ONE * 1.5
	modulate = Color(1, 1, 1, 1)
	
	_wave_offset = randf() * TAU
	_wave_frequency = randf_range(3.0, 6.0)
	_wave_amplitude = randf_range(40.0, 80.0)
	
	if particles:
		particles.emitting = true
		particles.one_shot = true
		if not particles.has_method("set_lifetime"):
			particles.lifetime = 1.0
			particles.amount = 36
	
	_calculate_target_position()
	set_process(true)

func _calculate_target_position() -> void:
	var room_ui = get_tree().get_first_node_in_group("room_ui")
	
	if room_ui and room_ui.has_node("SoulLabel"):
		var soul_label = room_ui.get_node("SoulLabel")
		var label_screen_pos = soul_label.global_position
		
		var camera = get_viewport().get_camera_2d()
		if camera:
			var viewport_size = get_viewport().get_visible_rect().size
			var zoom = camera.zoom if camera.zoom else Vector2.ONE
			target_position = camera.global_position + (label_screen_pos - viewport_size / 2.0) / zoom
		else:
			target_position = label_screen_pos
	else:
		target_position = Vector2(20, 20)

func _process(delta: float) -> void:
	if not _started and target_position != Vector2.ZERO:
		_started = true
		_start_movement()
	
	if not _started:
		global_position += Vector2(0, -8) * delta
	
	if _is_moving:
		_update_wavy_movement(delta)
		_update_effects(delta)
		_spawn_trail(delta)

func _start_movement() -> void:
	_start_position = global_position
	_direction = (target_position - global_position).normalized()
	_is_moving = true
	
	var dist = global_position.distance_to(target_position)
	var travel_time = clamp(dist / speed, 0.25, 1.25)
	
	var tw = create_tween()
	tw.tween_property(self, "_travel_progress", 1.0, travel_time).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	tw.parallel().tween_property(_core, "scale", Vector2(0.5, 0.5), travel_time)
	tw.parallel().tween_property(self, "modulate:a", 0.0, travel_time * 0.9)
	tw.tween_callback(Callable(self, "_on_reached_target"))

func _update_wavy_movement(delta: float) -> void:
	var base_pos = _start_position.lerp(target_position, _travel_progress)
	
	var perpendicular = Vector2(-_direction.y, _direction.x)
	var wave = sin(_travel_progress * _wave_frequency * TAU + _wave_offset) * _wave_amplitude * (1.0 - _travel_progress)
	
	global_position = base_pos + perpendicular * wave

func _update_effects(delta: float) -> void:
	var pulse = 1.0 + sin(Time.get_ticks_msec() * 0.008) * 0.3
	_glow.scale = Vector2.ONE * 2.0 * pulse
	
	var rotation_speed = 3.0
	_core.rotation += rotation_speed * delta

func _spawn_trail(delta: float) -> void:
	if not _is_moving:
		return
	_trail_timer += delta
	if _trail_timer >= 0.03:
		_trail_timer = 0.0
		_create_trail_particle()

func _create_trail_particle() -> void:
	var trail = Sprite2D.new()
	trail.texture = _create_circle_texture(6, Color(0.45, 0.95, 1.0, 0.6))
	trail.global_position = global_position + Vector2(randf_range(-5, 5), randf_range(-5, 5))
	trail.z_index = 1998
	get_parent().add_child(trail)
	_trail_particles.append(trail)
	
	var tw = create_tween()
	tw.tween_property(trail, "modulate:a", 0.0, 0.4)
	tw.parallel().tween_property(trail, "scale", Vector2(0.3, 0.3), 0.4)
	tw.tween_callback(func(): 
		if is_instance_valid(trail):
			_trail_particles.erase(trail)
			trail.queue_free()
	)

func _on_reached_target() -> void:
	var room_ui = get_tree().get_first_node_in_group("room_ui")
	if room_ui and room_ui.has_method("add_soul"):
		room_ui.add_soul()
	
	_is_moving = false
	set_process(false)
	
	if particles:
		particles.emitting = false
		particles.visible = false
	
	for trail in _trail_particles:
		if is_instance_valid(trail):
			var quick_fade = create_tween()
			quick_fade.tween_property(trail, "modulate:a", 0.0, 0.1)
			quick_fade.tween_callback(func():
				if is_instance_valid(trail):
					trail.queue_free()
			)
	_trail_particles.clear()
	
	var final_tween = create_tween()
	final_tween.tween_property(_core, "scale", Vector2(2.0, 2.0), 0.15)
	final_tween.parallel().tween_property(self, "modulate:a", 0.0, 0.15)
	final_tween.tween_callback(queue_free)

func _create_circle_texture(radius: int, color: Color) -> ImageTexture:
	var size = radius * 2
	var img = Image.create(size, size, false, Image.FORMAT_RGBA8)
	
	for y in range(size):
		for x in range(size):
			var dx = x - radius + 0.5
			var dy = y - radius + 0.5
			var d = sqrt(dx * dx + dy * dy)
			if d <= radius:
				var alpha = color.a * (1.0 - (d / radius) * 0.3)
				img.set_pixel(x, y, Color(color.r, color.g, color.b, alpha))
			else:
				img.set_pixel(x, y, Color(0, 0, 0, 0))
	
	return ImageTexture.create_from_image(img)
