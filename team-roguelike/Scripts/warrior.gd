extends Node2D

@export var speed: float = 100
@export var attack_range: float = 60
@export var attack_cooldown: float = 1.2
@export var damage: int = 15
@export var health: int = 80
@export var wander_radius: float = 300

@export var cleave_cooldown: float = 4.0
@export var cleave_damage: int = 25
@export var cleave_radius: float = 100
@export var charge_cooldown: float = 6.0
@export var charge_damage: int = 20
@export var charge_speed: float = 400
@export var whirlwind_cooldown: float = 15.0
@export var whirlwind_damage: int = 40
@export var whirlwind_radius: float = 150
@export var whirlwind_duration: float = 3.0

var attack_timer: float = 0.0
var cleave_timer: float = 0.0
var charge_timer: float = 0.0
var whirlwind_timer: float = 0.0
var target: Node2D = null
var wander_target: Vector2
var wander_timer: float = 0.0
var is_attacking: bool = false
var is_charging: bool = false
var is_whirlwinding: bool = false
var whirlwind_time: float = 0.0
var charge_target_pos: Vector2

var sprite: Sprite2D
var original_color: Color = Color.WHITE

func _ready():
	add_to_group("characters")
	setup_visuals()
	choose_new_wander_target()
	cleave_timer = cleave_cooldown
	charge_timer = charge_cooldown
	whirlwind_timer = whirlwind_cooldown

func setup_visuals():
	if not has_node("Sprite2D"):
		sprite = Sprite2D.new()
		add_child(sprite)
		var img = Image.create(40, 40, false, Image.FORMAT_RGBA8)
		img.fill(Color.RED)
		sprite.texture = ImageTexture.create_from_image(img)
	else:
		sprite = get_node("Sprite2D")
	
	original_color = sprite.modulate

func _process(delta):
	attack_timer -= delta
	cleave_timer -= delta
	charge_timer -= delta
	whirlwind_timer -= delta
	wander_timer -= delta
	
	if is_whirlwinding:
		do_whirlwind(delta)
		return
	
	if is_charging:
		do_charge(delta)
		return
	
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
		look_at(target.global_position)
		
		if whirlwind_timer <= 0 and count_nearby_enemies() >= 4:
			whirlwind_timer = whirlwind_cooldown
			start_whirlwind()
		elif charge_timer <= 0 and distance > 150 and distance < 300:
			charge_timer = charge_cooldown
			start_charge(target.position)
		elif cleave_timer <= 0 and count_nearby_enemies() >= 2:
			cleave_timer = cleave_cooldown
			use_cleave()
		elif distance > attack_range:
			var direction = (target.position - position).normalized()
			position += direction * speed * delta
			position.x = clamp(position.x, -400, 400)
			position.y = clamp(position.y, -300, 300)
			is_attacking = false
			sprite.modulate = original_color
		elif attack_timer <= 0:
			attack_timer = attack_cooldown
			target.take_damage(damage)
			is_attacking = true
			attack_flash()
		else:
			is_attacking = false
	else:
		wander(delta)
		is_attacking = false
		sprite.modulate = original_color

func count_nearby_enemies() -> int:
	var count = 0
	var enemies = get_tree().get_nodes_in_group("enemies")
	for enemy in enemies:
		if is_instance_valid(enemy):
			if position.distance_to(enemy.position) <= cleave_radius:
				count += 1
	return count

func use_cleave():
	sprite.modulate = Color.ORANGE_RED
	
	var enemies = get_tree().get_nodes_in_group("enemies")
	for enemy in enemies:
		if is_instance_valid(enemy):
			var distance = position.distance_to(enemy.position)
			if distance <= cleave_radius:
				enemy.take_damage(cleave_damage)
	
	create_cleave_effect()
	
	await get_tree().create_timer(0.3).timeout
	if is_instance_valid(self):
		sprite.modulate = original_color

func create_cleave_effect():
	for i in range(12):
		var particle = Sprite2D.new()
		var img = Image.create(6, 6, false, Image.FORMAT_RGBA8)
		img.fill(Color.ORANGE_RED)
		particle.texture = ImageTexture.create_from_image(img)
		get_parent().add_child(particle)
		particle.global_position = global_position
		
		var angle = (TAU / 12) * i
		var end_pos = global_position + Vector2(cos(angle), sin(angle)) * cleave_radius
		
		var tween = create_tween()
		tween.tween_property(particle, "global_position", end_pos, 0.3)
		tween.parallel().tween_property(particle, "modulate:a", 0.0, 0.3)
		tween.tween_callback(particle.queue_free)

func start_charge(target_pos: Vector2):
	is_charging = true
	charge_target_pos = target_pos
	sprite.modulate = Color.YELLOW

func do_charge(delta):
	var direction = (charge_target_pos - global_position).normalized()
	var distance = global_position.distance_to(charge_target_pos)
	
	if distance < 20:
		is_charging = false
		sprite.modulate = original_color
		
		var enemies = get_tree().get_nodes_in_group("enemies")
		for enemy in enemies:
			if is_instance_valid(enemy):
				if global_position.distance_to(enemy.global_position) < 80:
					enemy.take_damage(charge_damage)
		return
	
	global_position += direction * charge_speed * delta
	position.x = clamp(position.x, -400, 400)
	position.y = clamp(position.y, -300, 300)
	
	var enemies = get_tree().get_nodes_in_group("enemies")
	for enemy in enemies:
		if is_instance_valid(enemy):
			if global_position.distance_to(enemy.global_position) < 40:
				enemy.take_damage(charge_damage)
				is_charging = false
				sprite.modulate = original_color
				return

func start_whirlwind():
	is_whirlwinding = true
	whirlwind_time = whirlwind_duration
	sprite.modulate = Color.PURPLE

func do_whirlwind(delta):
	whirlwind_time -= delta
	
	rotation += delta * 15
	
	var enemies = get_tree().get_nodes_in_group("enemies")
	for enemy in enemies:
		if is_instance_valid(enemy):
			var distance = global_position.distance_to(enemy.global_position)
			if distance <= whirlwind_radius:
				var pull_strength = 150
				var direction = (global_position - enemy.global_position).normalized()
				enemy.position += direction * pull_strength * delta
	
	if int(whirlwind_time * 10) % 3 == 0:
		for enemy in enemies:
			if is_instance_valid(enemy):
				if global_position.distance_to(enemy.global_position) <= whirlwind_radius:
					enemy.take_damage(whirlwind_damage / 6)
	
	create_whirlwind_particles()
	
	if whirlwind_time <= 0:
		is_whirlwinding = false
		rotation = 0
		sprite.modulate = original_color
		
		for enemy in enemies:
			if is_instance_valid(enemy):
				if global_position.distance_to(enemy.global_position) <= whirlwind_radius:
					enemy.take_damage(whirlwind_damage)

func create_whirlwind_particles():
	for i in range(2):
		var particle = Sprite2D.new()
		var img = Image.create(8, 8, false, Image.FORMAT_RGBA8)
		img.fill(Color.PURPLE)
		particle.texture = ImageTexture.create_from_image(img)
		get_parent().add_child(particle)
		
		var angle = randf() * TAU
		var radius = randf_range(50, whirlwind_radius)
		particle.global_position = global_position + Vector2(cos(angle), sin(angle)) * radius
		
		var tween = create_tween()
		tween.tween_property(particle, "modulate:a", 0.0, 0.5)
		tween.tween_callback(particle.queue_free)

func wander(delta):
	if wander_timer <= 0:
		choose_new_wander_target()
		wander_timer = randf_range(2.0, 5.0)
	
	var distance = position.distance_to(wander_target)
	if distance > 10:
		var direction = (wander_target - position).normalized()
		position += direction * speed * 0.5 * delta
		look_at(wander_target)
	
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
