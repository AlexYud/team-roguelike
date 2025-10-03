extends Node2D

@export var speed: float = 200
@export var attack_range: float = 220
@export var attack_cooldown: float = 1.1
@export var damage: int = 12
@export var health: int = 70
@export var max_health: int = 70
@export var wander_radius: float = 300
@export var safe_distance: float = 160
@export var retreat_speed_multiplier: float = 1.4

# Cleric abilities
@export var heal_cooldown: float = 4.0
@export var heal_amount: int = 25
@export var heal_range: float = 250
@export var smite_cooldown: float = 3.0
@export var smite_damage: int = 30
@export var holy_nova_cooldown: float = 10.0
@export var holy_nova_damage: int = 20
@export var holy_nova_heal: int = 15
@export var holy_nova_radius: float = 180
@export var divine_shield_cooldown: float = 15.0
@export var shield_duration: float = 5.0
@export var shield_damage_reduction: float = 0.7

# Reaction time and smoothness
@export var reaction_time: float = 0.3
@export var rotation_smoothness: float = 8.0
@export var cast_chance_while_retreating: float = 0.5

var attack_timer: float = 0.0
var heal_timer: float = 0.0
var smite_timer: float = 0.0
var nova_timer: float = 0.0
var shield_timer: float = 0.0
var shield_active_timer: float = 0.0
var reaction_timer: float = 0.0
var target: Node2D = null
var wander_target: Vector2
var wander_timer: float = 0.0
var current_state: String = "idle"
var previous_state: String = "idle"
var target_rotation: float = 0.0
var is_casting: bool = false
var has_shield: bool = false

var sprite: Sprite2D
var shield_sprite: Sprite2D
var original_color: Color = Color.WHITE

func _ready():
	add_to_group("characters")
	setup_visuals()
	choose_new_wander_target()
	heal_timer = heal_cooldown
	smite_timer = smite_cooldown
	nova_timer = holy_nova_cooldown
	shield_timer = divine_shield_cooldown

func setup_visuals():
	if not has_node("Sprite2D"):
		sprite = Sprite2D.new()
		add_child(sprite)
		var img = Image.create(32, 32, false, Image.FORMAT_RGBA8)
		img.fill(Color.GOLD)
		sprite.texture = ImageTexture.create_from_image(img)
	else:
		sprite = get_node("Sprite2D")
	
	# Shield visual
	shield_sprite = Sprite2D.new()
	add_child(shield_sprite)
	var shield_img = Image.create(48, 48, false, Image.FORMAT_RGBA8)
	shield_img.fill(Color(0.5, 0.8, 1.0, 0.3))
	shield_sprite.texture = ImageTexture.create_from_image(shield_img)
	shield_sprite.visible = false
	
	original_color = sprite.modulate

func _process(delta):
	attack_timer -= delta
	heal_timer -= delta
	smite_timer -= delta
	nova_timer -= delta
	shield_timer -= delta
	shield_active_timer -= delta
	wander_timer -= delta
	reaction_timer -= delta
	
	# Shield management
	if has_shield and shield_active_timer <= 0:
		deactivate_shield()
	
	# Shield pulse effect
	if has_shield:
		shield_sprite.modulate.a = 0.3 + sin(Time.get_ticks_msec() * 0.005) * 0.2
	
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
	position += direction * speed * 0.65 * delta
	position.x = clamp(position.x, -400, 400)
	position.y = clamp(position.y, -300, 300)
	
	target_rotation = (target.global_position - global_position).angle()
	sprite.modulate = original_color

func combat_stance(enemies: Array):
	target_rotation = (target.global_position - global_position).angle()
	
	var ally_needs_healing = find_wounded_ally()
	var enemy_count = count_nearby_enemies(enemies)
	
	# Priority: Shield (low health) > Heal allies > Holy Nova (many enemies) > Smite > Holy Bolt
	if shield_timer <= 0 and not has_shield and health < max_health * 0.4:
		shield_timer = divine_shield_cooldown
		cast_divine_shield()
	elif heal_timer <= 0 and ally_needs_healing:
		heal_timer = heal_cooldown
		cast_heal(ally_needs_healing)
	elif nova_timer <= 0 and enemy_count >= 3:
		nova_timer = holy_nova_cooldown
		cast_holy_nova()
	elif smite_timer <= 0:
		smite_timer = smite_cooldown
		cast_smite(target)
	elif attack_timer <= 0:
		attack_timer = attack_cooldown
		cast_holy_bolt(target)
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
		
		# Emergency shield while retreating
		if shield_timer <= 0 and not has_shield and health < max_health * 0.3:
			shield_timer = divine_shield_cooldown
			cast_divine_shield()
		# Cast while kiting
		elif randf() < cast_chance_while_retreating:
			if smite_timer <= 0:
				smite_timer = smite_cooldown * 1.3
				cast_smite(closest_enemy)
			elif attack_timer <= 0:
				attack_timer = attack_cooldown * 1.2
				cast_holy_bolt(closest_enemy)
		
		sprite.modulate = Color.LIGHT_BLUE
	else:
		sprite.modulate = original_color

func find_wounded_ally() -> Node2D:
	var characters = get_tree().get_nodes_in_group("characters")
	var most_wounded = null
	var lowest_health_percent = 1.0
	
	for character in characters:
		if is_instance_valid(character) and character != self:
			if "health" in character and "max_health" in character:
				var health_percent = float(character.health) / float(character.max_health)
				if health_percent < 0.7 and health_percent < lowest_health_percent:
					var distance = position.distance_to(character.position)
					if distance <= heal_range:
						most_wounded = character
						lowest_health_percent = health_percent
	
	return most_wounded

func count_nearby_enemies(enemies: Array) -> int:
	var count = 0
	for enemy in enemies:
		if is_instance_valid(enemy):
			if position.distance_to(enemy.position) <= holy_nova_radius:
				count += 1
	return count

func cast_holy_bolt(enemy: Node2D):
	var bolt = HolyBolt.new()
	bolt.target = enemy
	bolt.damage = damage
	bolt.speed = 380
	
	var proj_sprite = Sprite2D.new()
	bolt.add_child(proj_sprite)
	var img = Image.create(10, 10, false, Image.FORMAT_RGBA8)
	img.fill(Color.YELLOW)
	proj_sprite.texture = ImageTexture.create_from_image(img)
	
	get_parent().add_child(bolt)
	bolt.global_position = global_position
	
	cast_flash(Color.YELLOW)

func cast_heal(ally: Node2D):
	is_casting = true
	sprite.modulate = Color.AQUAMARINE
	
	create_heal_beam(ally)
	
	if "health" in ally and "max_health" in ally:
		ally.health = min(ally.health + heal_amount, ally.max_health)
	elif "health" in ally:
		ally.health += heal_amount
	
	spawn_heal_indicator(ally.global_position, heal_amount)
	create_heal_particles(ally.global_position)
	
	await get_tree().create_timer(0.3).timeout
	if is_instance_valid(self):
		is_casting = false
		sprite.modulate = original_color

func cast_smite(enemy: Node2D):
	is_casting = true
	sprite.modulate = Color.WHITE
	
	# Lightning strike from above
	create_smite_lightning(enemy.global_position)
	
	await get_tree().create_timer(0.3).timeout
	
	if is_instance_valid(self) and is_instance_valid(enemy):
		if enemy.has_method("take_damage"):
			enemy.take_damage(smite_damage)
		
		is_casting = false
		sprite.modulate = original_color

func cast_holy_nova():
	is_casting = true
	sprite.modulate = Color.WHITE
	
	# Charge up
	for i in range(3):
		await get_tree().create_timer(0.15).timeout
		create_nova_charge_ring(i)
	
	if is_instance_valid(self):
		# Explosion!
		create_holy_nova_explosion()
		
		# Damage enemies
		var enemies = get_tree().get_nodes_in_group("enemies")
		for enemy in enemies:
			if is_instance_valid(enemy):
				var distance = global_position.distance_to(enemy.global_position)
				if distance <= holy_nova_radius:
					if enemy.has_method("take_damage"):
						enemy.take_damage(holy_nova_damage)
		
		# Heal allies
		var characters = get_tree().get_nodes_in_group("characters")
		for character in characters:
			if is_instance_valid(character):
				var distance = global_position.distance_to(character.global_position)
				if distance <= holy_nova_radius:
					if "health" in character and "max_health" in character:
						character.health = min(character.health + holy_nova_heal, character.max_health)
					elif "health" in character:
						character.health += holy_nova_heal
					spawn_heal_indicator(character.global_position, holy_nova_heal)
		
		is_casting = false
		sprite.modulate = original_color

func cast_divine_shield():
	has_shield = true
	shield_active_timer = shield_duration
	shield_sprite.visible = true
	
	sprite.modulate = Color.CYAN
	
	# Shield activation particles
	for i in range(16):
		var particle = Sprite2D.new()
		var img = Image.create(8, 8, false, Image.FORMAT_RGBA8)
		img.fill(Color.CYAN)
		particle.texture = ImageTexture.create_from_image(img)
		get_parent().add_child(particle)
		particle.global_position = global_position
		
		var angle = (TAU / 16) * i
		var end_pos = global_position + Vector2(cos(angle), sin(angle)) * 60
		
		var tween = create_tween()
		tween.tween_property(particle, "global_position", end_pos, 0.3)
		tween.parallel().tween_property(particle, "modulate:a", 0.0, 0.3)
		tween.tween_callback(particle.queue_free)
	
	await get_tree().create_timer(0.2).timeout
	if is_instance_valid(self):
		sprite.modulate = original_color

func deactivate_shield():
	has_shield = false
	shield_sprite.visible = false
	
	# Shield break particles
	for i in range(12):
		var particle = Sprite2D.new()
		var img = Image.create(6, 6, false, Image.FORMAT_RGBA8)
		img.fill(Color.CYAN)
		particle.texture = ImageTexture.create_from_image(img)
		get_parent().add_child(particle)
		particle.global_position = global_position
		
		var angle = randf() * TAU
		var end_pos = global_position + Vector2(cos(angle), sin(angle)) * 50
		
		var tween = create_tween()
		tween.tween_property(particle, "global_position", end_pos, 0.5)
		tween.parallel().tween_property(particle, "modulate:a", 0.0, 0.5)
		tween.tween_callback(particle.queue_free)

func create_heal_beam(target_node: Node2D):
	var beam = Line2D.new()
	beam.width = 4
	beam.default_color = Color.AQUAMARINE
	beam.add_point(global_position)
	beam.add_point(target_node.global_position)
	get_parent().add_child(beam)
	
	var tween = create_tween()
	tween.tween_property(beam, "modulate:a", 0.0, 0.4)
	tween.tween_callback(beam.queue_free)

func create_heal_particles(pos: Vector2):
	for i in range(10):
		var particle = Sprite2D.new()
		var img = Image.create(6, 6, false, Image.FORMAT_RGBA8)
		img.fill(Color.AQUAMARINE)
		particle.texture = ImageTexture.create_from_image(img)
		get_parent().add_child(particle)
		
		var start_pos = pos + Vector2(randf_range(-30, 30), randf_range(-30, 30))
		particle.global_position = start_pos
		
		var tween = create_tween()
		tween.tween_property(particle, "global_position", pos, 0.5)
		tween.parallel().tween_property(particle, "modulate:a", 0.0, 0.5)
		tween.tween_callback(particle.queue_free)

func create_smite_lightning(pos: Vector2):
	# Lightning bolt from top
	var lightning_start = pos + Vector2(0, -250)
	
	for i in range(5):
		var segment = Line2D.new()
		segment.width = 4 - i * 0.5
		segment.default_color = Color.WHITE
		
		var current_pos = lightning_start
		segment.add_point(current_pos)
		
		for j in range(8):
			current_pos += Vector2(randf_range(-15, 15), 30)
			segment.add_point(current_pos)
		
		get_parent().add_child(segment)
		
		var tween = create_tween()
		tween.tween_property(segment, "modulate:a", 0.0, 0.2)
		tween.tween_callback(segment.queue_free)
		
		await get_tree().create_timer(0.05).timeout

func create_nova_charge_ring(ring_index: int):
	var radius = 40 + ring_index * 20
	for i in range(12):
		var particle = Sprite2D.new()
		var img = Image.create(6, 6, false, Image.FORMAT_RGBA8)
		img.fill(Color.WHITE)
		particle.texture = ImageTexture.create_from_image(img)
		get_parent().add_child(particle)
		
		var angle = (TAU / 12) * i
		particle.global_position = global_position + Vector2(cos(angle), sin(angle)) * radius
		
		var tween = create_tween()
		tween.tween_property(particle, "global_position", global_position, 0.3)
		tween.parallel().tween_property(particle, "modulate:a", 0.0, 0.3)
		tween.tween_callback(particle.queue_free)

func create_holy_nova_explosion():
	for i in range(32):
		var particle = Sprite2D.new()
		var img = Image.create(10, 10, false, Image.FORMAT_RGBA8)
		img.fill(Color.GOLD if i % 2 == 0 else Color.WHITE)
		particle.texture = ImageTexture.create_from_image(img)
		get_parent().add_child(particle)
		particle.global_position = global_position
		
		var angle = (TAU / 32) * i
		var end_pos = global_position + Vector2(cos(angle), sin(angle)) * holy_nova_radius
		
		var tween = create_tween()
		tween.tween_property(particle, "global_position", end_pos, 0.6)
		tween.parallel().tween_property(particle, "modulate:a", 0.0, 0.6)
		tween.tween_callback(particle.queue_free)

func spawn_heal_indicator(pos: Vector2, amount: int):
	var heal_number = Node2D.new()
	get_parent().add_child(heal_number)
	heal_number.global_position = pos
	
	var label = Label.new()
	heal_number.add_child(label)
	label.position = Vector2(-15, -40)
	label.text = "+" + str(amount)
	label.add_theme_font_size_override("font_size", 20)
	label.add_theme_color_override("font_color", Color.AQUAMARINE)
	label.add_theme_color_override("font_outline_color", Color.DARK_GREEN)
	label.add_theme_constant_override("outline_size", 3)
	
	var tween = heal_number.create_tween()
	tween.tween_property(heal_number, "position:y", heal_number.position.y - 50, 1.2)
	tween.parallel().tween_property(heal_number, "modulate:a", 0.0, 1.2)
	tween.tween_callback(heal_number.queue_free)

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
	if has_shield:
		amount = int(amount * (1.0 - shield_damage_reduction))
		create_shield_impact_effect()
	
	health -= amount
	damage_flash()
	spawn_damage_number(amount)
	
	if health <= 0:
		queue_free()

func create_shield_impact_effect():
	for i in range(8):
		var particle = Sprite2D.new()
		var img = Image.create(6, 6, false, Image.FORMAT_RGBA8)
		img.fill(Color.CYAN)
		particle.texture = ImageTexture.create_from_image(img)
		get_parent().add_child(particle)
		particle.global_position = global_position
		
		var angle = randf() * TAU
		var end_pos = global_position + Vector2(cos(angle), sin(angle)) * 40
		
		var tween = create_tween()
		tween.tween_property(particle, "global_position", end_pos, 0.3)
		tween.parallel().tween_property(particle, "modulate:a", 0.0, 0.3)
		tween.tween_callback(particle.queue_free)

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
class HolyBolt extends Node2D:
	var target: Node2D = null
	var damage: int = 12
	var speed: float = 380
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
