extends Node2D

@export var health: int = 30
@export var speed: float = 100
@export var attack_range: float = 50
@export var attack_cooldown: float = 1.5
@export var damage: int = 5
@export var crit_chance: float = 0.08
@export var crit_damage_multiplier: float = 1.5
@export var knockback_distance: float = 40.0
@export var knockback_duration: float = 0.15

var target: Node2D = null
var attack_timer: float = 0.0
var is_attacking: bool = false
var is_knocked_back: bool = false
var sprite: Sprite2D
var original_color: Color = Color.WHITE
var is_dying: bool = false

func _ready():
	add_to_group("enemies")
	setup_visuals()
	target = find_nearest_target()

func setup_visuals():
	if not has_node("Sprite2D"):
		sprite = Sprite2D.new()
		add_child(sprite)
		var img = Image.create(32, 32, false, Image.FORMAT_RGBA8)
		img.fill(Color.RED)
		sprite.texture = ImageTexture.create_from_image(img)
	else:
		sprite = get_node("Sprite2D")
	sprite.z_as_relative = true
	sprite.z_index = 0
	original_color = sprite.modulate

func find_nearest_target():
	var characters = get_tree().get_nodes_in_group("characters")
	if characters.size() == 0:
		return null
	var nearest = null
	var nearest_distance = INF
	for character in characters:
		var distance = position.distance_to(character.position)
		if distance < nearest_distance:
			nearest_distance = distance
			nearest = character
	return nearest

func _process(delta):
	z_index = int(global_position.y)
	
	if is_knocked_back:
		return
	if target == null or not is_instance_valid(target):
		target = find_nearest_target()
		if target == null:
			return

	attack_timer -= delta
	if target and is_instance_valid(target):
		var distance = position.distance_to(target.position)
		if distance > attack_range:
			var direction = (target.position - position).normalized()
			position += direction * speed * delta
			position.x = clamp(position.x, Global.BOUNDS.position.x, Global.BOUNDS.end.x)
			position.y = clamp(position.y, Global.BOUNDS.position.y, Global.BOUNDS.end.y)
			is_attacking = false
			sprite.modulate = original_color
		elif attack_timer <= 0:
			attack_timer = attack_cooldown
			var final_damage = damage
			var is_crit = false
			if randf() < crit_chance:
				final_damage = int(damage * crit_damage_multiplier)
				is_crit = true
			target.take_damage(final_damage, is_crit)
			is_attacking = true
			attack_flash()
		else:
			is_attacking = false

func attack_flash():
	sprite.modulate = Color.ORANGE
	await get_tree().create_timer(0.1).timeout
	if is_instance_valid(self):
		sprite.modulate = original_color

func take_damage(amount: int, is_crit: bool = false) -> bool:
	if is_dying or health <= 0:
		return false

	health -= amount
	damage_flash()
	spawn_damage_number(amount, is_crit)
	
	if health <= 0:
		is_dying = true
		apply_knockback() 
		_spawn_soul_effect()
		queue_free()
		return true
	
	apply_knockback() 
	return false

func apply_knockback():
	if is_knocked_back:
		return
	is_knocked_back = true
	var knockback_dir = Vector2.ZERO
	if target and is_instance_valid(target):
		knockback_dir = (global_position - target.global_position).normalized()
	else:
		knockback_dir = Vector2(randf_range(-1, 1), randf_range(-1, 1)).normalized()

	var start_pos = global_position
	var end_pos = start_pos + knockback_dir * knockback_distance
	end_pos.x = clamp(end_pos.x, Global.BOUNDS.position.x, Global.BOUNDS.end.x)
	end_pos.y = clamp(end_pos.y, Global.BOUNDS.position.y, Global.BOUNDS.end.y)
	
	var tween = create_tween()
	tween.tween_property(self, "global_position", end_pos, knockback_duration).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	await tween.finished
	if is_instance_valid(self):
		is_knocked_back = false

func damage_flash():
	sprite.modulate = Color.WHITE * 2
	await get_tree().create_timer(0.1).timeout
	if is_instance_valid(self):
		sprite.modulate = original_color

func spawn_damage_number(amount: int, is_crit: bool = false):
	var damage_label = DamageNumber.new()
	damage_label.damage = amount
	damage_label.is_crit = is_crit
	var offset = Vector2(randf_range(-15, 15), randf_range(-10, 10))
	damage_label.global_position = global_position + offset
	damage_label.z_index = 1000
	get_parent().add_child(damage_label)

func _spawn_soul_effect():
	var soul_particle_scene = preload("res://Scenes/SoulParticle.tscn")
	var soul_particle = soul_particle_scene.instantiate()
	var label_pos := Vector2.ZERO
	var ui = get_tree().get_first_node_in_group("room_ui")
	if ui:
		var label = ui.get_node("SoulLabel")
		label_pos = label.get_global_position() + Vector2(20, 20)
	get_parent().add_child(soul_particle)
	soul_particle.global_position = global_position
	soul_particle.target_position = label_pos
	soul_particle.z_index = 999

class DamageNumber extends Node2D:
	var damage: int = 0
	var is_crit: bool = false
	var label: Label
	func _ready():
		label = Label.new()
		add_child(label)
		if is_crit:
			label.text = str(damage) + "!"
			label.add_theme_font_size_override("font_size", 56)
			label.add_theme_color_override("font_color", Color.ORANGE)
		else:
			label.text = str(damage)
			label.add_theme_font_size_override("font_size", 36)
			label.add_theme_color_override("font_color", Color(1, 1, 0))
		label.add_theme_color_override("font_outline_color", Color.BLACK)
		label.add_theme_constant_override("outline_size", 3)
		label.position = Vector2(-20, -40)
		scale = Vector2(0.7, 0.7)
		modulate = Color(1, 1, 1, 1)
		var tween = create_tween()
		var end_scale = Vector2(1.8, 1.8) if is_crit else Vector2(1.5, 1.5)
		tween.tween_property(self, "scale", end_scale, 0.08)
		tween.tween_property(self, "scale", Vector2(1.0, 1.0), 0.12)
		tween.tween_property(self, "global_position", global_position + Vector2(0, -40), 0.6)
		tween.tween_property(self, "modulate:a", 0.0, 0.6)
		await tween.finished
		if is_instance_valid(self):
			queue_free()
