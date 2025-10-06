extends "res://Scripts/base_character.gd"

@export var charge_cooldown: float = 8.0
@export var charge_damage: int = 20
@export var charge_speed: float = 600
@export var charge_duration: float = 0.4

@export var berserk_cooldown: float = 20.0
@export var berserk_duration: float = 5.0
@export var berserk_damage_boost: int = 10
@export var berserk_speed_boost: float = 50
@export var berserk_attack_speed_boost: float = 0.3

var charge_timer: float = 0.0
var berserk_timer: float = 0.0
var is_charging: bool = false
var is_berserk: bool = false
var charge_target_pos: Vector2
var original_damage: int
var original_speed: float
var original_attack_cooldown: float

func character_ready():
	charge_timer = charge_cooldown
	berserk_timer = berserk_cooldown
	speed = 180
	attack_range = 80
	attack_cooldown = 0.8
	damage = 18
	health = 120
	max_health = 120
	safe_distance = 50
	retreat_speed_multiplier = 1.1
	crit_chance = 0.15
	crit_damage_multiplier = 2.0
	original_damage = damage
	original_speed = speed
	original_attack_cooldown = attack_cooldown

func update_ability_timers(delta: float):
	charge_timer -= delta
	berserk_timer -= delta
	
	if is_charging:
		execute_charge(delta)

func get_retreat_color() -> Color:
	return Color.STEEL_BLUE

func retreat_action():
	if charge_timer <= 0 and randf() < 0.4 and is_instance_valid(target):
		var distance_to_target = position.distance_to(target.position)
		if distance_to_target > attack_range + 50 and distance_to_target < 300:
			charge_timer = charge_cooldown * 1.2
			start_charge(target)

func use_abilities(enemies: Array) -> bool:
	var distance_to_target = position.distance_to(target.position)
	
	if berserk_timer <= 0 and (health < max_health * 0.5 or count_nearby_enemies(enemies, 200) >= 3):
		berserk_timer = berserk_cooldown
		activate_berserk()
		return true
	
	elif charge_timer <= 0 and distance_to_target > attack_range + 50 and distance_to_target < 300:
		charge_timer = charge_cooldown
		start_charge(target)
		return true
	
	return false

func basic_attack(enemy: Node2D):
	cast_melee_strike(enemy)

func count_nearby_enemies(enemies: Array, radius: float) -> int:
	var count = 0
	for enemy in enemies:
		if is_instance_valid(enemy):
			if position.distance_to(enemy.position) <= radius:
				count += 1
	return count

func start_charge(enemy: Node2D):
	if is_instance_valid(enemy):
		is_charging = true
		charge_target_pos = enemy.global_position
		
		if animated_sprite:
			animated_sprite.modulate = Color.CYAN
		
		for i in range(3):
			await get_tree().create_timer(0.1).timeout
			create_charge_trail()

func execute_charge(delta: float):
	var direction = (charge_target_pos - global_position).normalized()
	var move_distance = charge_speed * delta
	
	global_position += direction * move_distance
	global_position.x = clamp(global_position.x, -400, 400)
	global_position.y = clamp(global_position.y, -300, 300)
	
	var enemies = get_tree().get_nodes_in_group("enemies")
	for enemy in enemies:
		if is_instance_valid(enemy):
			if global_position.distance_to(enemy.global_position) < 40:
				deal_damage_to(enemy, charge_damage)
				create_impact_effect(enemy.global_position)
	
	charge_duration -= delta
	if charge_duration <= 0 or global_position.distance_to(charge_target_pos) < 30:
		is_charging = false
		charge_duration = 0.4
		if animated_sprite and not is_berserk:
			animated_sprite.modulate = original_color

func create_charge_trail():
	for i in range(6):
		var particle = Sprite2D.new()
		var img = Image.create(12, 12, false, Image.FORMAT_RGBA8)
		img.fill(Color.CYAN if i % 2 == 0 else Color.LIGHT_BLUE)
		particle.texture = ImageTexture.create_from_image(img)
		get_parent().add_child(particle)
		particle.global_position = global_position + Vector2(randf_range(-15, 15), randf_range(-15, 15))
		
		var tween = create_tween()
		tween.tween_property(particle, "modulate:a", 0.0, 0.5)
		tween.tween_callback(particle.queue_free)

func activate_berserk():
	is_berserk = true
	damage = original_damage + berserk_damage_boost
	speed = original_speed + berserk_speed_boost
	attack_cooldown = original_attack_cooldown - berserk_attack_speed_boost
	
	if animated_sprite:
		animated_sprite.modulate = Color.ORANGE_RED
	
	create_berserk_flames()
	
	await get_tree().create_timer(berserk_duration).timeout
	
	if is_instance_valid(self):
		is_berserk = false
		damage = original_damage
		speed = original_speed
		attack_cooldown = original_attack_cooldown
		if animated_sprite:
			animated_sprite.modulate = original_color

func create_berserk_flames():
	var flame_particles = []
	
	for i in range(16):
		var particle = Sprite2D.new()
		var img = Image.create(12, 12, false, Image.FORMAT_RGBA8)
		img.fill(Color.ORANGE_RED if i % 2 == 0 else Color.ORANGE)
		particle.texture = ImageTexture.create_from_image(img)
		get_parent().add_child(particle)
		flame_particles.append(particle)
	
	var elapsed = 0.0
	while elapsed < berserk_duration and is_instance_valid(self):
		for i in range(flame_particles.size()):
			if is_instance_valid(flame_particles[i]):
				var angle = (TAU / 16) * i + elapsed * 4
				var radius = 40 + sin(elapsed * 6) * 10
				var offset = Vector2(cos(angle), sin(angle)) * radius
				flame_particles[i].global_position = global_position + offset
				flame_particles[i].modulate = Color.ORANGE_RED if (i + int(elapsed * 10)) % 2 == 0 else Color.ORANGE
		
		await get_tree().create_timer(0.016).timeout
		elapsed += 0.016
	
	for particle in flame_particles:
		if is_instance_valid(particle):
			var tween = create_tween()
			tween.tween_property(particle, "modulate:a", 0.0, 0.3)
			tween.tween_callback(particle.queue_free)

func cast_melee_strike(enemy: Node2D):
	if not is_instance_valid(enemy):
		return
	
	var distance = global_position.distance_to(enemy.global_position)
	if distance <= attack_range:
		deal_damage_to(enemy, damage)
		create_impact_effect(enemy.global_position)
		
		cast_flash(Color.WHITE)

func create_impact_effect(impact_position: Vector2):
	for i in range(8):
		var particle = Sprite2D.new()
		var img = Image.create(8, 8, false, Image.FORMAT_RGBA8)
		img.fill(Color.WHITE if i % 2 == 0 else Color.LIGHT_GRAY)
		particle.texture = ImageTexture.create_from_image(img)
		get_parent().add_child(particle)
		particle.global_position = impact_position
		
		var angle = (TAU / 8) * i
		var end_pos = impact_position + Vector2(cos(angle), sin(angle)) * 30
		
		var tween = create_tween()
		tween.tween_property(particle, "global_position", end_pos, 0.2)
		tween.parallel().tween_property(particle, "modulate:a", 0.0, 0.2)
		tween.tween_callback(particle.queue_free)
