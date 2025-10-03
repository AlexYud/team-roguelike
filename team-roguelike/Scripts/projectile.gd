extends Node2D

var target: Node2D = null
var damage: int = 20
var speed: float = 300
var is_fireball: bool = false
var lifetime: float = 3.0

func _ready():
	# Auto-destroy after lifetime
	await get_tree().create_timer(lifetime).timeout
	if is_instance_valid(self):
		queue_free()

func _process(delta):
	if not target or not is_instance_valid(target):
		queue_free()
		return
	
	# Move towards target
	var direction = (target.global_position - global_position).normalized()
	global_position += direction * speed * delta
	look_at(target.global_position)
	
	# Check collision with target
	var distance = global_position.distance_to(target.global_position)
	if distance < 20:  # hit detection
		if target.has_method("take_damage"):
			target.take_damage(damage)
		
		# Fireball AOE damage
		if is_fireball:
			create_explosion()
		
		queue_free()

func create_explosion():
	# Find nearby enemies and damage them
	var enemies = get_tree().get_nodes_in_group("enemies")
	for enemy in enemies:
		if enemy != target and is_instance_valid(enemy):
			var dist = global_position.distance_to(enemy.global_position)
			if dist < 80:  # explosion radius
				enemy.take_damage(damage / 2)  # half damage to nearby
	
	# Visual explosion effect
	for i in range(8):
		var particle = Sprite2D.new()
		var img = Image.create(12, 12, false, Image.FORMAT_RGBA8)
		img.fill(Color.ORANGE)
		particle.texture = ImageTexture.create_from_image(img)
		get_parent().add_child(particle)
		particle.global_position = global_position
		
		var angle = (TAU / 8) * i
		var end_pos = global_position + Vector2(cos(angle), sin(angle)) * 60
		
		var tween = create_tween()
		tween.tween_property(particle, "global_position", end_pos, 0.3)
		tween.parallel().tween_property(particle, "modulate:a", 0.0, 0.3)
		tween.tween_callback(particle.queue_free)
