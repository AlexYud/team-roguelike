extends Node2D

@export var speed: float = 200
@export var attack_range: float = 250
@export var attack_cooldown: float = 1.0
@export var damage: int = 10
@export var health: int = 60
@export var wander_radius: float = 300
@export var safe_distance: float = 180
@export var retreat_speed_multiplier: float = 1.3

# Necromancer abilities
@export var soul_drain_cooldown: float = 2.5
@export var soul_drain_damage: int = 15
@export var soul_drain_heal: int = 8
@export var summon_skeleton_cooldown: float = 8.0
@export var skeleton_health: int = 25
@export var skeleton_damage: int = 8
@export var death_nova_cooldown: float = 12.0
@export var death_nova_damage: int = 35
@export var death_nova_radius: float = 200
@export var raise_dead_cooldown: float = 18.0
@export var zombie_duration: float = 15.0

# Reaction time and smoothness
@export var reaction_time: float = 0.35
@export var rotation_smoothness: float = 7.0
@export var cast_chance_while_retreating: float = 0.6

var attack_timer: float = 0.0
var soul_drain_timer: float = 0.0
var summon_timer: float = 0.0
var nova_timer: float = 0.0
var raise_dead_timer: float = 0.0
var reaction_timer: float = 0.0
var target: Node2D = null
var wander_target: Vector2
var wander_timer: float = 0.0
var current_state: String = "idle"
var previous_state: String = "idle"
var target_rotation: float = 0.0
var is_casting: bool = false

var sprite: Sprite2D
var original_color: Color = Color.WHITE
var active_minions: Array = []

func _ready():
	add_to_group("characters")
	setup_visuals()
	choose_new_wander_target()
	soul_drain_timer = soul_drain_cooldown
	summon_timer = summon_skeleton_cooldown
	nova_timer = death_nova_cooldown
	raise_dead_timer = raise_dead_cooldown

func setup_visuals():
	if not has_node("Sprite2D"):
		sprite = Sprite2D.new()
		add_child(sprite)
		var img = Image.create(32, 32, false, Image.FORMAT_RGBA8)
		img.fill(Color.PURPLE)
		sprite.texture = ImageTexture.create_from_image(img)
	else:
		sprite = get_node("Sprite2D")
	
	original_color = sprite.modulate

func _process(delta):
	attack_timer -= delta
	soul_drain_timer -= delta
	summon_timer -= delta
	nova_timer -= delta
	raise_dead_timer -= delta
	wander_timer -= delta
	reaction_timer -= delta
	
	# Clean up dead minions
	active_minions = active_minions.filter(func(m): return is_instance_valid(m))
	
	var enemies = get_tree().get_nodes_in_group("enemies")
	if enemies.size() > 0:
		target = enemies[0]
		for e in enemies:
			if position.distance_to(e.position) < position.distance_to(target.position):
				target = e
	else:
		target = null
	
	# Smooth rotation
	rotation = lerp_angle(rotation, target_rotation, rotation_smoothness * delta)
	
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
		elif distance > attack_range + 80:
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
		sprite.modulate = original_color

func pursue_enemy(delta: float):
	var direction = (target.position - position).normalized()
	position += direction * speed * 0.6 * delta
	position.x = clamp(position.x, -400, 400)
	position.y = clamp(position.y, -300, 300)
	
	target_rotation = (target.global_position - global_position).angle()
	sprite.modulate = original_color

func combat_stance(enemies: Array):
	target_rotation = (target.global_position - global_position).angle()
	
	var enemy_count = count_nearby_enemies(enemies)
	
	# Priority: Death Nova > Raise Dead > Summon Skeleton > Soul Drain > Basic Attack
	if nova_timer <= 0 and enemy_count >= 4:
		nova_timer = death_nova_cooldown
		cast_death_nova()
	elif raise_dead_timer <= 0 and check_for_corpses():
		raise_dead_timer = raise_dead_cooldown
		cast_raise_dead()
	elif summon_timer <= 0 and active_minions.size() < 3:
		summon_timer = summon_skeleton_cooldown
		cast_summon_skeleton()
	elif soul_drain_timer <= 0 and health < 60:
		soul_drain_timer = soul_drain_cooldown
		cast_soul_drain(target)
	elif attack_timer <= 0:
		attack_timer = attack_cooldown
		cast_dark_bolt(target)
	else:
		sprite.modulate = original_color

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
		
		# Check boundaries
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
		
		# Look at closest enemy while retreating
		target_rotation = (closest_enemy.global_position - global_position).angle()
		
		# Cast while kiting
		if randf() < cast_chance_while_retreating:
			if soul_drain_timer <= 0:
				soul_drain_timer = soul_drain_cooldown * 1.3
				cast_soul_drain(closest_enemy)
			elif attack_timer <= 0:
				attack_timer = attack_cooldown * 1.2
				cast_dark_bolt(closest_enemy)
		
		sprite.modulate = Color.DARK_VIOLET
	else:
		sprite.modulate = original_color

func count_nearby_enemies(enemies: Array) -> int:
	var count = 0
	for enemy in enemies:
		if is_instance_valid(enemy):
			if position.distance_to(enemy.position) <= death_nova_radius:
				count += 1
	return count

func check_for_corpses() -> bool:
	# Check if there are any dead enemies nearby (represented by low health enemies)
	var enemies = get_tree().get_nodes_in_group("enemies")
	for enemy in enemies:
		if is_instance_valid(enemy):
			if "health" in enemy and enemy.health <= 20:
				if position.distance_to(enemy.position) <= 200:
					return true
	return enemies.size() >= 3

func cast_dark_bolt(enemy: Node2D):
	var bolt = DarkBolt.new()
	bolt.target = enemy
	bolt.damage = damage
	bolt.speed = 350
	
	var proj_sprite = Sprite2D.new()
	bolt.add_child(proj_sprite)
	var img = Image.create(12, 12, false, Image.FORMAT_RGBA8)
	img.fill(Color.DARK_VIOLET)
	proj_sprite.texture = ImageTexture.create_from_image(img)
	
	get_parent().add_child(bolt)
	bolt.global_position = global_position
	
	cast_flash(Color.DARK_VIOLET)

func cast_soul_drain(enemy: Node2D):
	is_casting = true
	sprite.modulate = Color.GREEN_YELLOW
	
	# Create beam effect
	var beam = SoulDrainBeam.new()
	beam.caster = self
	beam.target = enemy
	beam.damage = soul_drain_damage
	beam.heal = soul_drain_heal
	get_parent().add_child(beam)
	
	await get_tree().create_timer(0.4).timeout
	if is_instance_valid(self):
		is_casting = false
		sprite.modulate = original_color

func cast_summon_skeleton():
	is_casting = true
	sprite.modulate = Color.CYAN
	
	create_summoning_circle(global_position)
	
	await get_tree().create_timer(0.5).timeout
	
	if is_instance_valid(self):
		var skeleton = Skeleton.new()
		skeleton.master = self
		skeleton.health = skeleton_health
		skeleton.damage = skeleton_damage
		get_parent().add_child(skeleton)
		skeleton.global_position = global_position + Vector2(randf_range(-40, 40), randf_range(-40, 40))
		
		active_minions.append(skeleton)
		
		is_casting = false
		sprite.modulate = original_color

func cast_death_nova():
	is_casting = true
	sprite.modulate = Color.BLACK
	
	# Charge up animation
	for i in range(3):
		await get_tree().create_timer(0.2).timeout
		create_nova_charge_particle()
	
	if is_instance_valid(self):
		# Explosion!
		create_death_nova_explosion()
		
		var enemies = get_tree().get_nodes_in_group("enemies")
		for enemy in enemies:
			if is_instance_valid(enemy):
				var distance = global_position.distance_to(enemy.global_position)
				if distance <= death_nova_radius:
					if enemy.has_method("take_damage"):
						enemy.take_damage(death_nova_damage)
		
		is_casting = false
		sprite.modulate = original_color

func cast_raise_dead():
	is_casting = true
	sprite.modulate = Color.DARK_GREEN
	
	var enemies = get_tree().get_nodes_in_group("enemies")
	var raised_count = 0
	
	for enemy in enemies:
		if is_instance_valid(enemy) and raised_count < 2:
			if position.distance_to(enemy.position) <= 200:
				create_raise_dead_effect(enemy.global_position)
				
				var zombie = Zombie.new()
				zombie.master = self
				zombie.lifetime = zombie_duration
				get_parent().add_child(zombie)
				zombie.global_position = enemy.global_position
				
				active_minions.append(zombie)
				raised_count += 1
				
				await get_tree().create_timer(0.3).timeout
	
	if is_instance_valid(self):
		is_casting = false
		sprite.modulate = original_color

func create_summoning_circle(pos: Vector2):
	for i in range(16):
		var particle = Sprite2D.new()
		var img = Image.create(6, 6, false, Image.FORMAT_RGBA8)
		img.fill(Color.CYAN)
		particle.texture = ImageTexture.create_from_image(img)
		get_parent().add_child(particle)
		
		var angle = (TAU / 16) * i
		var start_pos = pos + Vector2(cos(angle), sin(angle)) * 60
		particle.global_position = start_pos
		
		var tween = create_tween()
		tween.tween_property(particle, "global_position", pos, 0.5)
		tween.parallel().tween_property(particle, "modulate:a", 0.0, 0.5)
		tween.tween_callback(particle.queue_free)

func create_nova_charge_particle():
	for i in range(6):
		var particle = Sprite2D.new()
		var img = Image.create(8, 8, false, Image.FORMAT_RGBA8)
		img.fill(Color.BLACK)
		particle.texture = ImageTexture.create_from_image(img)
		get_parent().add_child(particle)
		
		var angle = randf() * TAU
		var start_pos = global_position + Vector2(cos(angle), sin(angle)) * 100
		particle.global_position = start_pos
		
		var tween = create_tween()
		tween.tween_property(particle, "global_position", global_position, 0.3)
		tween.tween_callback(particle.queue_free)

func create_death_nova_explosion():
	for i in range(32):
		var particle = Sprite2D.new()
		var img = Image.create(12, 12, false, Image.FORMAT_RGBA8)
		img.fill(Color.DARK_VIOLET if i % 2 == 0 else Color.BLACK)
		particle.texture = ImageTexture.create_from_image(img)
		get_parent().add_child(particle)
		particle.global_position = global_position
		
		var angle = (TAU / 32) * i
		var end_pos = global_position + Vector2(cos(angle), sin(angle)) * death_nova_radius
		
		var tween = create_tween()
		tween.tween_property(particle, "global_position", end_pos, 0.6)
		tween.parallel().tween_property(particle, "modulate:a", 0.0, 0.6)
		tween.tween_callback(particle.queue_free)

func create_raise_dead_effect(pos: Vector2):
	for i in range(12):
		var particle = Sprite2D.new()
		var img = Image.create(8, 8, false, Image.FORMAT_RGBA8)
		img.fill(Color.DARK_GREEN)
		particle.texture = ImageTexture.create_from_image(img)
		get_parent().add_child(particle)
		particle.global_position = pos + Vector2(0, 30)
		
		var end_pos = pos + Vector2(randf_range(-40, 40), randf_range(-60, -20))
		
		var tween = create_tween()
		tween.tween_property(particle, "global_position", end_pos, 0.8)
		tween.parallel().tween_property(particle, "modulate:a", 0.0, 0.8)
		tween.tween_callback(particle.queue_free)

func cast_flash(color: Color):
	sprite.modulate = color
	await get_tree().create_timer(0.1).timeout
	if is_instance_valid(self):
		sprite.modulate = original_color

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

func take_damage(amount: int):
	health -= amount
	damage_flash()
	spawn_damage_number(amount)
	if health <= 0:
		queue_free()

func damage_flash():
	sprite.modulate = Color.WHITE * 2
	await get_tree().create_timer(0.1).timeout
	if is_instance_valid(self):
		sprite.modulate = original_color

func spawn_damage_number(amount: int):
	var damage_label = DamageNumber.new()
	damage_label.damage = amount
	var offset = Vector2(randf_range(-15, 15), randf_range(-10, 10))
	damage_label.global_position = global_position + offset
	get_parent().add_child(damage_label)

# Inner classes
class DarkBolt extends Node2D:
	var target: Node2D = null
	var damage: int = 10
	var speed: float = 350
	var lifetime: float = 3.0
	
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
		
		if global_position.distance_to(target.global_position) < 20:
			if target.has_method("take_damage"):
				target.take_damage(damage)
			queue_free()

class SoulDrainBeam extends Line2D:
	var caster: Node2D
	var target: Node2D
	var damage: int = 15
	var heal: int = 8
	var lifetime: float = 0.4
	var has_damaged: bool = false
	
	func _ready():
		width = 3
		default_color = Color.GREEN_YELLOW
		
		await get_tree().create_timer(lifetime).timeout
		queue_free()
	
	func _process(delta):
		if not caster or not is_instance_valid(caster) or not target or not is_instance_valid(target):
			queue_free()
			return
		
		clear_points()
		add_point(caster.global_position)
		add_point(target.global_position)
		
		if not has_damaged:
			has_damaged = true
			if target.has_method("take_damage"):
				target.take_damage(damage)
			if "health" in caster:
				caster.health = min(caster.health + heal, 60)
				spawn_heal_indicator(caster.global_position, heal)
	
	func spawn_heal_indicator(pos: Vector2, amount: int):
		var heal_number = Node2D.new()
		get_parent().add_child(heal_number)
		heal_number.global_position = pos
		
		var label = Label.new()
		heal_number.add_child(label)
		label.position = Vector2(-15, -40)
		label.text = "+" + str(amount)
		label.add_theme_font_size_override("font_size", 18)
		label.add_theme_color_override("font_color", Color.GREEN)
		label.add_theme_color_override("font_outline_color", Color.DARK_GREEN)
		label.add_theme_constant_override("outline_size", 2)
		
		var tween = heal_number.create_tween()
		tween.tween_property(heal_number, "position:y", heal_number.position.y - 40, 1.0)
		tween.parallel().tween_property(heal_number, "modulate:a", 0.0, 1.0)
		tween.tween_callback(heal_number.queue_free)

class Skeleton extends Node2D:
	var master: Node2D
	var health: int = 25
	var damage: int = 8
	var speed: float = 100
	var attack_range: float = 40
	var attack_cooldown: float = 1.2
	var attack_timer: float = 0.0
	var target: Node2D = null
	var sprite: Sprite2D
	
	func _ready():
		add_to_group("minions")
		sprite = Sprite2D.new()
		add_child(sprite)
		var img = Image.create(24, 24, false, Image.FORMAT_RGBA8)
		img.fill(Color.LIGHT_GRAY)
		sprite.texture = ImageTexture.create_from_image(img)
	
	func _process(delta):
		attack_timer -= delta
		
		var enemies = get_tree().get_nodes_in_group("enemies")
		if enemies.size() > 0:
			target = enemies[0]
			for e in enemies:
				if position.distance_to(e.position) < position.distance_to(target.position):
					target = e
		
		if target and is_instance_valid(target):
			var distance = position.distance_to(target.position)
			look_at(target.global_position)
			
			if distance > attack_range:
				var direction = (target.position - position).normalized()
				position += direction * speed * delta
			elif attack_timer <= 0:
				attack_timer = attack_cooldown
				target.take_damage(damage)
				sprite.modulate = Color.RED
				await get_tree().create_timer(0.1).timeout
				if is_instance_valid(self):
					sprite.modulate = Color.WHITE
	
	func take_damage(amount: int):
		health -= amount
		if health <= 0:
			queue_free()

class Zombie extends Node2D:
	var master: Node2D
	var lifetime: float = 15.0
	var health: int = 40
	var damage: int = 12
	var speed: float = 60
	var attack_range: float = 45
	var attack_cooldown: float = 1.5
	var attack_timer: float = 0.0
	var target: Node2D = null
	var sprite: Sprite2D
	
	func _ready():
		add_to_group("minions")
		sprite = Sprite2D.new()
		add_child(sprite)
		var img = Image.create(28, 28, false, Image.FORMAT_RGBA8)
		img.fill(Color.DARK_GREEN)
		sprite.texture = ImageTexture.create_from_image(img)
	
	func _process(delta):
		lifetime -= delta
		attack_timer -= delta
		
		if lifetime <= 0:
			decay()
			return
		
		var enemies = get_tree().get_nodes_in_group("enemies")
		if enemies.size() > 0:
			target = enemies[0]
			for e in enemies:
				if position.distance_to(e.position) < position.distance_to(target.position):
					target = e
		
		if target and is_instance_valid(target):
			var distance = position.distance_to(target.position)
			look_at(target.global_position)
			
			if distance > attack_range:
				var direction = (target.position - position).normalized()
				position += direction * speed * delta
			elif attack_timer <= 0:
				attack_timer = attack_cooldown
				target.take_damage(damage)
				sprite.modulate = Color.RED
				await get_tree().create_timer(0.1).timeout
				if is_instance_valid(self):
					sprite.modulate = Color.WHITE
	
	func decay():
		for i in range(6):
			var particle = Sprite2D.new()
			var img = Image.create(6, 6, false, Image.FORMAT_RGBA8)
			img.fill(Color.DARK_GREEN)
			particle.texture = ImageTexture.create_from_image(img)
			get_parent().add_child(particle)
			particle.global_position = global_position
			
			var end_pos = global_position + Vector2(randf_range(-30, 30), randf_range(-30, 30))
			var tween = create_tween()
			tween.tween_property(particle, "global_position", end_pos, 0.5)
			tween.parallel().tween_property(particle, "modulate:a", 0.0, 0.5)
			tween.tween_callback(particle.queue_free)
		
		queue_free()
	
	func take_damage(amount: int):
		health -= amount
		if health <= 0:
			decay()

class DamageNumber extends Node2D:
	var damage: int = 0
	var lifetime: float = 1.0
	var float_speed: float = 50.0
	var fade_start: float = 0.5
	var label: Label
	
	func _ready():
		label = Label.new()
		add_child(label)
		label.text = str(damage)
		label.add_theme_font_size_override("font_size", 20)
		label.add_theme_color_override("font_color", Color.WHITE)
		label.add_theme_color_override("font_outline_color", Color.BLACK)
		label.add_theme_constant_override("outline_size", 3)
		label.position = Vector2(-20, -30)
		
		scale = Vector2(0.5, 0.5)
		var tween = create_tween()
		tween.tween_property(self, "scale", Vector2(1.2, 1.2), 0.1)
		tween.tween_property(self, "scale", Vector2(1.0, 1.0), 0.1)
	
	func _process(delta):
		position.y -= float_speed * delta
		lifetime -= delta
		if lifetime < fade_start:
			modulate.a = lifetime / fade_start
		if lifetime <= 0:
			queue_free()
