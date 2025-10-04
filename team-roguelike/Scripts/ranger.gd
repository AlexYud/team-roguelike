extends Node2D

@export var speed: float = 300
@export var attack_range: float = 200
@export var attack_cooldown: float = 0.8
@export var damage: int = 8
@export var health: int = 40
@export var wander_radius: float = 300
@export var safe_distance: float = 150
@export var retreat_speed_multiplier: float = 1.5

@export var arrow_cooldown: float = 2.0
@export var arrow_damage: int = 20
@export var multi_shot_cooldown: float = 5.0
@export var multi_shot_damage: int = 15
@export var rain_of_arrows_cooldown: float = 12.0
@export var rain_damage: int = 30
@export var rain_count: int = 8

# Reaction time and smoothness
@export var reaction_time: float = 0.3
@export var rotation_smoothness: float = 8.0
@export var kite_shot_chance: float = 0.7 
@onready var anim_sprite: AnimatedSprite2D = $AnimatedSprite2D

var attack_timer: float = 0.0
var arrow_timer: float = 0.0
var multi_shot_timer: float = 0.0
var rain_timer: float = 0.0
var reaction_timer: float = 0.0
var target: Node2D = null
var wander_target: Vector2
var wander_timer: float = 0.0
var is_attacking: bool = false
var current_state: String = "idle"
var previous_state: String = "idle"
var target_rotation: float = 0.0

var sprite: Sprite2D
var original_color: Color = Color.WHITE
var is_moving: bool = false
var last_position: Vector2

func _ready():
	add_to_group("characters")
	setup_visuals()
	choose_new_wander_target()
	arrow_timer = arrow_cooldown
	multi_shot_timer = multi_shot_cooldown
	rain_timer = rain_of_arrows_cooldown
	anim_sprite.play("breathe")
	last_position = position

func setup_visuals():
	if not has_node("Sprite2D"):
		sprite = Sprite2D.new()
	else:
		sprite = get_node("Sprite2D")
	
	original_color = sprite.modulate

func _process(delta):
	attack_timer -= delta
	arrow_timer -= delta
	multi_shot_timer -= delta
	rain_timer -= delta
	wander_timer -= delta
	reaction_timer -= delta
	
	# Check if character is moving
	var velocity = (position - last_position) / delta if delta > 0 else Vector2.ZERO
	is_moving = velocity.length() > 0
	last_position = position
	
	# Update animation based on movement
	update_animation()
	
	# Update sprite flip based on facing direction
	update_sprite_flip()
	
	var enemies = get_tree().get_nodes_in_group("enemies")
	if enemies.size() > 0:
		target = enemies[0]
		for e in enemies:
			if position.distance_to(e.position) < position.distance_to(target.position):
				target = e
	else:
		target = null
	
	if target and is_instance_valid(target):
		var distance = position.distance_to(target.position)
		
		var closest_enemy_distance = distance
		var closest_enemy = target
		for enemy in enemies:
			if is_instance_valid(enemy):
				var dist = position.distance_to(enemy.position)
				if dist < closest_enemy_distance:
					closest_enemy_distance = dist
					closest_enemy = enemy
		
		# Determine new state
		var new_state = "idle"
		if closest_enemy_distance < safe_distance:
			new_state = "retreating"
		elif distance > attack_range + 50:
			new_state = "pursuing"
		else:
			new_state = "combat"
		
		# Check if state changed
		if new_state != current_state:
			previous_state = current_state
			current_state = new_state
			reaction_timer = reaction_time
		
		# Only act after reaction time
		if reaction_timer <= 0:
			if current_state == "retreating":
				retreat_from_enemies(enemies, delta, closest_enemy)
			elif current_state == "pursuing":
				pursue_enemy(delta)
			elif current_state == "combat":
				combat_stance(enemies)
		else:
			# During reaction time, continue previous action but slower
			if previous_state == "retreating":
				retreat_from_enemies(enemies, delta * 0.5, closest_enemy)
			elif previous_state == "pursuing":
				pursue_enemy(delta * 0.5)
	else:
		current_state = "wandering"
		wander(delta)
		is_attacking = false
		sprite.modulate = original_color

func update_animation():
	if is_moving:
		if anim_sprite.animation != "walking":
			anim_sprite.play("walking")
	else:
		if anim_sprite.animation != "breathe":
			anim_sprite.play("breathe")

func update_sprite_flip():
	# Flip sprite based on target rotation or movement direction
	var facing_angle = target_rotation
	
	# Normalize angle to -PI to PI range
	while facing_angle > PI:
		facing_angle -= TAU
	while facing_angle < -PI:
		facing_angle += TAU
	
	# Flip sprite if facing left (angle between -PI/2 and PI/2 means facing right)
	if facing_angle > PI / 2 or facing_angle < -PI / 2:
		anim_sprite.flip_h = true
	else:
		anim_sprite.flip_h = false

func pursue_enemy(delta: float):
	var direction = (target.position - position).normalized()
	position += direction * speed * 0.7 * delta
	position.x = clamp(position.x, -400, 400)
	position.y = clamp(position.y, -300, 300)
	
	target_rotation = (target.global_position - global_position).angle()
	is_attacking = false
	sprite.modulate = original_color

func combat_stance(enemies: Array):
	target_rotation = (target.global_position - global_position).angle()
	
	if rain_timer <= 0 and enemies.size() >= 4:
		rain_timer = rain_of_arrows_cooldown
		use_rain_of_arrows()
	elif multi_shot_timer <= 0 and enemies.size() >= 3:
		multi_shot_timer = multi_shot_cooldown
		use_multi_shot(enemies)
	elif arrow_timer <= 0:
		arrow_timer = arrow_cooldown
		shoot_arrow(target)
	else:
		is_attacking = false
		sprite.modulate = original_color

func shoot_arrow(enemy: Node2D):
	var arrow = Arrow.new()
	arrow.target = enemy
	arrow.damage = arrow_damage
	arrow.speed = 450
	
	var proj_sprite = Sprite2D.new()
	arrow.add_child(proj_sprite)
	var img = Image.create(10, 10, false, Image.FORMAT_RGBA8)
	img.fill(Color.BROWN)
	proj_sprite.texture = ImageTexture.create_from_image(img)
	
	get_parent().add_child(arrow)
	arrow.global_position = global_position

func retreat_from_enemies(enemies: Array, delta: float, closest_enemy: Node2D):
	var retreat_direction = Vector2.ZERO
	var threat_count = 0
	
	for enemy in enemies:
		if is_instance_valid(enemy):
			var distance = position.distance_to(enemy.position)
			if distance < safe_distance * 1.5:
				var away_direction = (position - enemy.position).normalized()
				var threat_weight = 1.0 - (distance / (safe_distance * 1.5))
				retreat_direction += away_direction * threat_weight
				threat_count += 1
	
	if threat_count > 0:
		retreat_direction = retreat_direction.normalized()
		
		# Check boundaries and adjust direction
		var edge_buffer = 50
		var future_pos = position + retreat_direction * speed * retreat_speed_multiplier * delta
		
		if future_pos.x < -400 + edge_buffer or future_pos.x > 400 - edge_buffer:
			retreat_direction.x *= -0.5
		if future_pos.y < -300 + edge_buffer or future_pos.y > 300 - edge_buffer:
			retreat_direction.y *= -0.5
		
		retreat_direction = retreat_direction.normalized()
		
		# Move away from enemies
		position += retreat_direction * speed * retreat_speed_multiplier * delta
		position.x = clamp(position.x, -400, 400)
		position.y = clamp(position.y, -300, 300)
		
		# IMPORTANT: Look AT the closest enemy while retreating (not away)
		target_rotation = (closest_enemy.global_position - global_position).angle()
		
		# Shoot while kiting if cooldown is ready and random chance
		if arrow_timer <= 0 and randf() < kite_shot_chance:
			arrow_timer = arrow_cooldown * 1.2  # Slightly longer cooldown while kiting
			shoot_arrow(closest_enemy)
		
		sprite.modulate = Color.LIGHT_BLUE
		is_attacking = false
	else:
		sprite.modulate = original_color

func use_multi_shot(enemies: Array):
	var targets = enemies.slice(0, 3)
	for enemy in targets:
		if is_instance_valid(enemy):
			var arrow = Arrow.new()
			arrow.target = enemy
			arrow.damage = multi_shot_damage
			arrow.speed = 500
			
			var proj_sprite = Sprite2D.new()
			arrow.add_child(proj_sprite)
			var img = Image.create(8, 8, false, Image.FORMAT_RGBA8)
			img.fill(Color.YELLOW)
			proj_sprite.texture = ImageTexture.create_from_image(img)
			
			get_parent().add_child(arrow)
			arrow.global_position = global_position
	
	sprite.modulate = Color.YELLOW
	await get_tree().create_timer(0.2).timeout
	if is_instance_valid(self):
		sprite.modulate = original_color

func use_rain_of_arrows():
	sprite.modulate = Color.CYAN
	
	var enemies = get_tree().get_nodes_in_group("enemies")
	var valid_enemies = []
	for enemy in enemies:
		if is_instance_valid(enemy):
			valid_enemies.append(enemy)
	
	for i in range(rain_count):
		await get_tree().create_timer(0.15).timeout
		if valid_enemies.size() == 0:
			break
		
		var random_enemy = valid_enemies[randi() % valid_enemies.size()]
		if is_instance_valid(random_enemy):
			spawn_rain_arrow(random_enemy)
	
	if is_instance_valid(self):
		sprite.modulate = original_color

func spawn_rain_arrow(enemy: Node2D):
	var start_pos = enemy.global_position + Vector2(randf_range(-100, 100), -200)
	
	var arrow = Arrow.new()
	arrow.target = enemy
	arrow.damage = rain_damage
	arrow.speed = 600
	arrow.is_rain_arrow = true
	
	var proj_sprite = Sprite2D.new()
	arrow.add_child(proj_sprite)
	var img = Image.create(12, 12, false, Image.FORMAT_RGBA8)
	img.fill(Color.CYAN)
	proj_sprite.texture = ImageTexture.create_from_image(img)
	
	get_parent().add_child(arrow)
	arrow.global_position = start_pos

func wander(delta):
	if wander_timer <= 0:
		choose_new_wander_target()
		wander_timer = randf_range(2.0, 5.0)
	
	var distance = position.distance_to(wander_target)
	if distance > 10:
		var direction = (wander_target - position).normalized()
		position += direction * speed * 0.5 * delta
		target_rotation = (wander_target - position).angle()
	
	position.x = clamp(position.x, -400, 400)
	position.y = clamp(position.y, -300, 300)

func choose_new_wander_target():
	var angle = randf_range(0, TAU)
	var distance = randf_range(50, wander_radius)
	wander_target = position + Vector2(cos(angle), sin(angle)) * distance
	wander_target.x = clamp(wander_target.x, -400, 400)
	wander_target.y = clamp(wander_target.y, -300, 300)

func attack_flash():
	sprite.modulate = Color.RED
	await get_tree().create_timer(0.1).timeout
	if is_instance_valid(self):
		sprite.modulate = original_color

func take_damage(amount: int):
	health -= amount
	damage_flash()
	if health <= 0:
		queue_free()

func damage_flash():
	sprite.modulate = Color.WHITE * 2
	await get_tree().create_timer(0.1).timeout
	if is_instance_valid(self):
		sprite.modulate = original_color

class Arrow extends Node2D:
	var target: Node2D = null
	var damage: int = 20
	var speed: float = 400
	var lifetime: float = 3.0
	var is_rain_arrow: bool = false
	
	func _ready():
		await get_tree().create_timer(lifetime).timeout
		if is_instance_valid(self):
			queue_free()
	
	func _process(delta):
		if not target or not is_instance_valid(target):
			queue_free()
			return
		
		var direction = (target.global_position - global_position).normalized()
		global_position += direction * speed * delta
		look_at(target.global_position)
		
		var distance = global_position.distance_to(target.global_position)
		if distance < 20:
			if target.has_method("take_damage"):
				target.take_damage(damage)
			queue_free()
