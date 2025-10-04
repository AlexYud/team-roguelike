extends Node2D

@export var enemy_scene: PackedScene
@export var spawn_rate: float = 0.5
@export var event_check_interval: float = 15.0
@export var meteor_shower_duration: float = 8.0
@export var blood_moon_duration: float = 12.0
@export var blessing_duration: float = 10.0

var spawn_timer: float = 0.0
var event_timer: float = 0.0
var characters: Array = []
var current_event: String = "none"
var event_time_remaining: float = 0.0
var spawn_rate_modifier: float = 1.0
var damage_modifier: float = 1.0
var event_label: Label
var event_background: ColorRect
@onready var spawn_points = $SpawnPoints.get_children() if has_node("SpawnPoints") else []

func _ready():
	spawn_selected_characters()
	characters = get_tree().get_nodes_in_group("characters")
	event_timer = event_check_interval
	setup_ui()

func spawn_selected_characters():
	var i = 0
	for char_name in Global.selected_characters:
		var path = "res://Scenes/Characters/%s.tscn" % char_name
		print(path)
		var char_scene = load(path)
		if char_scene:
			var character = char_scene.instantiate()
			if i < spawn_points.size():
				character.position = spawn_points[i].position
			else:
				character.position = Vector2((i - 1) * 150, 0)
			add_child(character)
			i += 1
		else:
			push_error("Could not load character scene: " + path)

func setup_ui():
	event_background = ColorRect.new()
	event_background.size = Vector2(600, 80)
	event_background.position = Vector2(-300, -350)
	event_background.color = Color(0, 0, 0, 0.7)
	event_background.visible = false
	add_child(event_background)
	event_label = Label.new()
	event_label.position = Vector2(-290, -340)
	event_label.size = Vector2(580, 60)
	event_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	event_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	event_label.add_theme_font_size_override("font_size", 28)
	event_label.add_theme_color_override("font_color", Color.WHITE)
	event_label.add_theme_color_override("font_outline_color", Color.BLACK)
	event_label.add_theme_constant_override("outline_size", 4)
	event_label.visible = false
	add_child(event_label)

func _process(delta):
	spawn_timer -= delta
	event_timer -= delta
	event_time_remaining -= delta
	if spawn_timer <= 0:
		spawn_timer = spawn_rate * spawn_rate_modifier
		spawn_enemy()
	if event_timer <= 0 and current_event == "none":
		event_timer = event_check_interval
		check_for_event()
	if current_event != "none":
		update_event(delta)
		update_event_ui()
		if event_time_remaining <= 0:
			end_event()

func check_for_event():
	var chance = randf()
	if chance < 0.25:
		start_meteor_shower()
	elif chance < 0.5:
		start_blood_moon()
	elif chance < 0.75:
		start_divine_blessing()

func start_meteor_shower():
	current_event = "meteor_shower"
	event_time_remaining = meteor_shower_duration
	spawn_rate_modifier = 0.6
	show_event_announcement("☄️ METEOR SHOWER ☄️", Color.ORANGE)
	create_screen_flash(Color.ORANGE)

func start_blood_moon():
	current_event = "blood_moon"
	event_time_remaining = blood_moon_duration
	spawn_rate_modifier = 0.4
	damage_modifier = 1.5
	show_event_announcement("🌙 BLOOD MOON RISES 🌙", Color.DARK_RED)
	create_screen_flash(Color.RED)
	apply_blood_moon_effect()

func start_divine_blessing():
	current_event = "blessing"
	event_time_remaining = blessing_duration
	show_event_announcement("✨ DIVINE BLESSING ✨", Color.GOLD)
	create_screen_flash(Color.GOLD)
	heal_all_characters(30)

func update_event(delta):
	match current_event:
		"meteor_shower":
			if randf() < 0.3 * delta:
				spawn_meteor()
		"blood_moon":
			update_blood_moon_visuals()

func spawn_meteor():
	var meteor = Meteor.new()
	var spawn_x = randf_range(-400, 400)
	meteor.start_position = Vector2(spawn_x, -350)
	meteor.target_position = Vector2(randf_range(-350, 350), randf_range(-250, 250))
	add_child(meteor)

func apply_blood_moon_effect():
	var enemies = get_tree().get_nodes_in_group("enemies")
	for enemy in enemies:
		if is_instance_valid(enemy) and enemy.has_node("Sprite2D"):
			var sprite = enemy.get_node("Sprite2D")
			sprite.modulate = Color.RED * 1.3

func update_blood_moon_visuals():
	var pulse = (sin(Time.get_ticks_msec() * 0.003) + 1.0) * 0.5
	event_background.color = Color(0.3 + pulse * 0.2, 0, 0, 0.5)

func heal_all_characters(amount: int):
	characters = get_tree().get_nodes_in_group("characters")
	for character in characters:
		if is_instance_valid(character):
			if character.has_method("heal"):
				character.heal(amount)
			elif "health" in character:
				character.health += amount
			spawn_heal_effect(character.global_position, amount)
			create_blessing_particles(character.global_position)

func spawn_heal_effect(pos: Vector2, amount: int):
	var heal_label = Label.new()
	add_child(heal_label)
	heal_label.global_position = pos + Vector2(-20, -40)
	heal_label.text = "+" + str(amount)
	heal_label.add_theme_font_size_override("font_size", 24)
	heal_label.add_theme_color_override("font_color", Color.GREEN)
	heal_label.add_theme_color_override("font_outline_color", Color.DARK_GREEN)
	heal_label.add_theme_constant_override("outline_size", 3)
	var tween = create_tween()
	tween.tween_property(heal_label, "position:y", heal_label.position.y - 60, 1.5)
	tween.parallel().tween_property(heal_label, "modulate:a", 0.0, 1.5)
	tween.tween_callback(heal_label.queue_free)

func create_blessing_particles(pos: Vector2):
	for i in range(8):
		var particle = Sprite2D.new()
		var img = Image.create(6, 6, false, Image.FORMAT_RGBA8)
		img.fill(Color.GOLD)
		particle.texture = ImageTexture.create_from_image(img)
		add_child(particle)
		particle.global_position = pos
		var angle = (TAU / 8) * i
		var end_pos = pos + Vector2(cos(angle), sin(angle)) * 60
		var tween = create_tween()
		tween.tween_property(particle, "global_position", end_pos, 0.8)
		tween.parallel().tween_property(particle, "modulate:a", 0.0, 0.8)
		tween.tween_callback(particle.queue_free)

func end_event():
	match current_event:
		"blood_moon":
			var enemies = get_tree().get_nodes_in_group("enemies")
			for enemy in enemies:
				if is_instance_valid(enemy) and enemy.has_node("Sprite2D"):
					var sprite = enemy.get_node("Sprite2D")
					sprite.modulate = Color.RED
	current_event = "none"
	spawn_rate_modifier = 1.0
	damage_modifier = 1.0
	event_timer = event_check_interval
	event_label.visible = false
	event_background.visible = false

func show_event_announcement(text: String, color: Color):
	event_label.text = text
	event_label.add_theme_color_override("font_color", color)
	event_label.visible = true
	event_background.visible = true
	event_background.color = Color(0, 0, 0, 0.7)
	event_label.scale = Vector2(0.5, 0.5)
	var tween = create_tween()
	tween.tween_property(event_label, "scale", Vector2(1.3, 1.3), 0.3)
	tween.tween_property(event_label, "scale", Vector2(1.0, 1.0), 0.2)

func update_event_ui():
	var time_left = int(ceil(event_time_remaining))
	match current_event:
		"meteor_shower":
			event_label.text = "☄️ METEOR SHOWER ☄️ [" + str(time_left) + "s]"
		"blood_moon":
			event_label.text = "🌙 BLOOD MOON 🌙 [" + str(time_left) + "s]"
		"blessing":
			event_label.text = "✨ DIVINE BLESSING ✨ [" + str(time_left) + "s]"

func create_screen_flash(color: Color):
	var flash = ColorRect.new()
	flash.size = Vector2(1000, 800)
	flash.position = Vector2(-500, -400)
	flash.color = color
	flash.color.a = 0.0
	add_child(flash)
	var tween = create_tween()
	tween.tween_property(flash, "color:a", 0.4, 0.2)
	tween.tween_property(flash, "color:a", 0.0, 0.3)
	tween.tween_callback(flash.queue_free)

func spawn_enemy():
	if enemy_scene == null:
		push_error("Enemy scene is not assigned!")
		return
	var enemy = enemy_scene.instantiate()
	add_child(enemy)
	enemy.position = Vector2(randf_range(-400, 400), randf_range(-300, 300))
	if current_event == "blood_moon" and "damage" in enemy:
		enemy.damage = int(enemy.damage * damage_modifier)
		if enemy.has_node("Sprite2D"):
			enemy.get_node("Sprite2D").modulate = Color.RED * 1.3
	characters = get_tree().get_nodes_in_group("characters")
	if characters.size() > 0:
		enemy.target = characters[randi() % characters.size()]

class Meteor extends Node2D:
	var start_position: Vector2
	var target_position: Vector2
	var speed: float = 400.0
	var damage: int = 50
	var explosion_radius: float = 80.0
	var sprite: Sprite2D
	var trail_timer: float = 0.0

	func _ready():
		global_position = start_position
		sprite = Sprite2D.new()
		add_child(sprite)
		var img = Image.create(16, 16, false, Image.FORMAT_RGBA8)
		img.fill(Color.ORANGE)
		sprite.texture = ImageTexture.create_from_image(img)
		look_at(target_position)

	func _process(delta):
		var direction = (target_position - global_position).normalized()
		global_position += direction * speed * delta
		trail_timer -= delta
		if trail_timer <= 0:
			trail_timer = 0.05
			spawn_trail()
		if global_position.distance_to(target_position) < 20:
			explode()

	func spawn_trail():
		var trail = Sprite2D.new()
		var img = Image.create(8, 8, false, Image.FORMAT_RGBA8)
		img.fill(Color.ORANGE_RED)
		trail.texture = ImageTexture.create_from_image(img)
		get_parent().add_child(trail)
		trail.global_position = global_position
		var tween = create_tween()
		tween.tween_property(trail, "modulate:a", 0.0, 0.5)
		tween.tween_callback(trail.queue_free)

	func explode():
		for i in range(20):
			var particle = Sprite2D.new()
			var img = Image.create(10, 10, false, Image.FORMAT_RGBA8)
			img.fill(Color.ORANGE if i % 2 == 0 else Color.YELLOW)
			particle.texture = ImageTexture.create_from_image(img)
			get_parent().add_child(particle)
			particle.global_position = global_position
			var angle = (TAU / 20) * i
			var end_pos = global_position + Vector2(cos(angle), sin(angle)) * explosion_radius
			var tween = create_tween()
			tween.tween_property(particle, "global_position", end_pos, 0.5)
			tween.parallel().tween_property(particle, "modulate:a", 0.0, 0.5)
			tween.tween_callback(particle.queue_free)
		var enemies = get_tree().get_nodes_in_group("enemies")
		for enemy in enemies:
			if is_instance_valid(enemy):
				var distance = global_position.distance_to(enemy.global_position)
				if distance <= explosion_radius:
					if enemy.has_method("take_damage"):
						enemy.take_damage(damage)
		queue_free()
