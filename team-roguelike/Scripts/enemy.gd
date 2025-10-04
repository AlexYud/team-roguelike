extends Node2D

@export var health: int = 30
@export var speed: float = 100
@export var attack_range: float = 50
@export var attack_cooldown: float = 1.5
@export var damage: int = 5

var target: Node2D = null
var attack_timer: float = 0.0
var is_attacking: bool = false

# Visual feedback
var sprite: Sprite2D
var original_color: Color = Color.WHITE

func _ready():
	add_to_group("enemies")
	setup_visuals()

func setup_visuals():
	# Create a simple visual if you don't have one
	if not has_node("Sprite2D"):
		sprite = Sprite2D.new()
		add_child(sprite)
		# Create a simple colored square as placeholder
		var img = Image.create(32, 32, false, Image.FORMAT_RGBA8)
		img.fill(Color.RED)
		sprite.texture = ImageTexture.create_from_image(img)
	else:
		sprite = get_node("Sprite2D")
	
	original_color = sprite.modulate

func _process(delta):
	attack_timer -= delta
	
	if target and is_instance_valid(target):
		var distance = position.distance_to(target.position)
		
		# Move towards target if out of attack range
		if distance > attack_range:
			var direction = (target.position - position).normalized()
			position += direction * speed * delta
			# Keep within bounds
			position.x = clamp(position.x, -400, 400)
			position.y = clamp(position.y, -300, 300)
			is_attacking = false
			sprite.modulate = original_color
		# Attack if in range
		elif attack_timer <= 0:
			attack_timer = attack_cooldown
			target.take_damage(damage)
			is_attacking = true
			attack_flash()
		else:
			is_attacking = false

func attack_flash():
	# Flash orange when attacking
	sprite.modulate = Color.ORANGE
	await get_tree().create_timer(0.1).timeout
	if is_instance_valid(self):
		sprite.modulate = original_color

func take_damage(amount: int):
	health -= amount
	damage_flash()
	spawn_damage_number(amount)
	
	if health <= 0:
		queue_free()

func damage_flash():
	# Flash white when taking damage
	sprite.modulate = Color.WHITE * 2
	await get_tree().create_timer(0.1).timeout
	if is_instance_valid(self):
		sprite.modulate = original_color

func spawn_damage_number(amount: int):
	var damage_label = DamageNumber.new()
	damage_label.damage = amount
	
	# Add some random offset so multiple hits don't stack perfectly
	var offset = Vector2(randf_range(-15, 15), randf_range(-10, 10))
	damage_label.global_position = global_position + offset
	
	get_parent().add_child(damage_label)

class DamageNumber extends Node2D:
	var damage: int = 0
	var lifetime: float = 1.0
	var float_speed: float = 50.0
	var fade_start: float = 0.5
	var label: Label
	
	func _ready():
		# Create label
		label = Label.new()
		add_child(label)
		
		# Set text
		label.text = str(damage)
		
		# Style the label
		label.add_theme_font_size_override("font_size", 20)
		label.add_theme_color_override("font_color", Color.WHITE)
		label.add_theme_color_override("font_outline_color", Color.BLACK)
		label.add_theme_constant_override("outline_size", 3)
		
		# Center the label
		label.position = Vector2(-20, -30)
		
		# Add scale pop effect
		scale = Vector2(0.5, 0.5)
		var tween = create_tween()
		tween.tween_property(self, "scale", Vector2(1.2, 1.2), 0.1)
		tween.tween_property(self, "scale", Vector2(1.0, 1.0), 0.1)
	
	func _process(delta):
		# Float upward
		position.y -= float_speed * delta
		
		# Fade out
		lifetime -= delta
		if lifetime < fade_start:
			var alpha = lifetime / fade_start
			modulate.a = alpha
		
		# Remove when lifetime expires
		if lifetime <= 0:
			queue_free()
