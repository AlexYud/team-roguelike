extends "res://Scripts/base_character.gd"

# Warrior abilities
@export var charge_cooldown: float = 8.0
@export var charge_damage: int = 20
@export var charge_speed: float = 600
@export var charge_duration: float = 0.4

@export var defensive_stance_cooldown: float = 12.0
@export var defensive_stance_duration: float = 3.0
@export var damage_reduction: float = 0.5

@export var cleave_cooldown: float = 5.0
@export var cleave_damage: int = 25
@export var cleave_radius: float = 150

var charge_timer: float = 0.0
var defensive_stance_timer: float = 0.0
var cleave_timer: float = 0.0
var is_charging: bool = false
var is_defensive: bool = false
var charge_target_pos: Vector2

func character_ready():
	charge_timer = charge_cooldown
	defensive_stance_timer = defensive_stance_cooldown
	cleave_timer = cleave_cooldown
	speed = 180
	attack_range = 80
	attack_cooldown = 0.8
	damage = 18
	health = 120
	max_health = 120
	safe_distance = 50
	retreat_speed_multiplier = 1.1

func update_ability_timers(delta: float):
	charge_timer -= delta
	defensive_stance_timer -= delta
	cleave_timer -= delta
	
	if is_charging:
		execute_charge(delta)

func get_retreat_color() -> Color:
	return Color.STEEL_BLUE

func retreat_action(closest_enemy: Node2D):
	# Warriors rarely retreat, but use defensive stance when overwhelmed
	if defensive_stance_timer <= 0 and randf() < 0.3:
		defensive_stance_timer = defensive_stance_cooldown
		activate_defensive_stance()

func use_abilities(enemies: Array) -> bool:
	var distance_to_target = position.distance_to(target.position)
	var nearby_count = count_nearby_enemies(enemies, cleave_radius)
	
	# Prioritize cleave when multiple enemies are close
	if cleave_timer <= 0 and nearby_count >= 2 and distance_to_target <= cleave_radius:
		cleave_timer = cleave_cooldown
		cast_cleave(enemies)
		return true
	
	# Use charge to close distance or engage
	elif charge_timer <= 0 and distance_to_target > attack_range + 50 and distance_to_target < 300:
		charge_timer = charge_cooldown
		start_charge(target)
		return true
	
	# Defensive stance when health is low or multiple enemies nearby
	elif defensive_stance_timer <= 0 and (health < max_health * 0.4 or nearby_count >= 3):
		defensive_stance_timer = defensive_stance_cooldown
		activate_defensive_stance()
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
		
		# Create charge trail effect
		for i in range(3):
			await get_tree().create_timer(0.1).timeout
			create_charge_trail()

func execute_charge(delta: float):
	var direction = (charge_target_pos - global_position).normalized()
	var move_distance = charge_speed * delta
	
	global_position += direction * move_distance
	global_position.x = clamp(global_position.x, -400, 400)
	global_position.y = clamp(global_position.y, -300, 300)
	
	# Check for enemy collisions during charge
	var enemies = get_tree().get_nodes_in_group("enemies")
	for enemy in enemies:
		if is_instance_valid(enemy):
			if global_position.distance_to(enemy.global_position) < 40:
				deal_damage_to(enemy, charge_damage)
				create_impact_effect(enemy.global_position)
	
	# End charge after duration or reaching target
	charge_duration -= delta
	if charge_duration <= 0 or global_position.distance_to(charge_target_pos) < 30:
		is_charging = false
		charge_duration = 0.4
		if animated_sprite:
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

func activate_defensive_stance():
	is_defensive = true
	
	if animated_sprite:
		animated_sprite.modulate = Color.GOLD
	
	create_defensive_shield()
	
	await get_tree().create_timer(defensive_stance_duration).timeout
	
	if is_instance_valid(self):
		is_defensive = false
		if animated_sprite:
			animated_sprite.modulate = original_color

func create_defensive_shield():
	var shield_particles = []
	
	for i in range(12):
		var particle = Sprite2D.new()
		var img = Image.create(10, 10, false, Image.FORMAT_RGBA8)
		img.fill(Color.GOLD)
		particle.texture = ImageTexture.create_from_image(img)
		get_parent().add_child(particle)
		shield_particles.append(particle)
	
	var elapsed = 0.0
	while elapsed < defensive_stance_duration and is_instance_valid(self):
		for i in range(shield_particles.size()):
			if is_instance_valid(shield_particles[i]):
				var angle = (TAU / 12) * i + elapsed * 2
				var radius = 50
				var offset = Vector2(cos(angle), sin(angle)) * radius
				shield_particles[i].global_position = global_position + offset
		
		await get_tree().create_timer(0.016).timeout
		elapsed += 0.016
	
	for particle in shield_particles:
		if is_instance_valid(particle):
			particle.queue_free()

func cast_cleave(enemies: Array):
	if animated_sprite:
		animated_sprite.modulate = Color.ORANGE_RED
	
	create_cleave_effect()
	
	# Deal damage to all nearby enemies
	for enemy in enemies:
		if is_instance_valid(enemy):
			var distance = global_position.distance_to(enemy.global_position)
			if distance <= cleave_radius:
				deal_damage_to(enemy, cleave_damage)
				create_impact_effect(enemy.global_position)
	
	await get_tree().create_timer(0.3).timeout
	if is_instance_valid(self) and animated_sprite:
		animated_sprite.modulate = original_color

func create_cleave_effect():
	for i in range(16):
		var particle = Sprite2D.new()
		var img = Image.create(14, 14, false, Image.FORMAT_RGBA8)
		img.fill(Color.ORANGE_RED if i % 2 == 0 else Color.ORANGE)
		particle.texture = ImageTexture.create_from_image(img)
		get_parent().add_child(particle)
		
		var angle = (TAU / 16) * i
		var start_radius = 30
		var end_radius = cleave_radius
		
		particle.global_position = global_position + Vector2(cos(angle), sin(angle)) * start_radius
		
		var tween = create_tween()
		tween.tween_property(particle, "global_position", 
			global_position + Vector2(cos(angle), sin(angle)) * end_radius, 0.3)
		tween.parallel().tween_property(particle, "modulate:a", 0.0, 0.3)
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

func take_damage(amount: int):
	var actual_damage = amount
	
	# Apply damage reduction during defensive stance
	if is_defensive:
		actual_damage = int(amount * (1.0 - damage_reduction))
		create_block_effect()
	
	super.take_damage(actual_damage)

func create_block_effect():
	for i in range(6):
		var particle = Sprite2D.new()
		var img = Image.create(6, 6, false, Image.FORMAT_RGBA8)
		img.fill(Color.GOLD)
		particle.texture = ImageTexture.create_from_image(img)
		get_parent().add_child(particle)
		particle.global_position = global_position + Vector2(0, -20)
		
		var angle = (TAU / 6) * i
		var end_pos = global_position + Vector2(cos(angle), sin(angle)) * 40 + Vector2(0, -20)
		
		var tween = create_tween()
		tween.tween_property(particle, "global_position", end_pos, 0.3)
		tween.parallel().tween_property(particle, "modulate:a", 0.0, 0.3)
		tween.tween_callback(particle.queue_free)
