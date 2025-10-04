extends Node2D

@export var speed: float = 200
@export var attack_range: float = 200
@export var attack_cooldown: float = 1.0
@export var damage: int = 10
@export var health: int = 60
@export var max_health: int = 60
@export var wander_radius: float = 300
@export var safe_distance: float = 160
@export var retreat_speed_multiplier: float = 1.3
@export var reaction_time: float = 0.3

var attack_timer: float = 0.0
var reaction_timer: float = 0.0
var wander_timer: float = 0.0
var target: Node2D = null
var wander_target: Vector2
var current_state: String = "idle"
var previous_state: String = "idle"

var animated_sprite: AnimatedSprite2D
var original_color: Color = Color.WHITE
var char_name: String = ""

func _ready():
	add_to_group("characters")
	char_name = get_meta("char_name", "Unknown")
	setup_visuals()
	choose_new_wander_target()
	character_ready()

func character_ready():
	pass

func setup_visuals():
	animated_sprite = get_node_or_null("AnimatedSprite2D")
	if animated_sprite:
		original_color = animated_sprite.modulate
	else:
		push_error("This character is missing an AnimatedSprite2D node.")

func _process(delta):
	attack_timer -= delta
	reaction_timer -= delta
	wander_timer -= delta
	
	update_ability_timers(delta)
	
	var enemies = get_tree().get_nodes_in_group("enemies")
	if enemies.size() > 0:
		target = find_closest_enemy(enemies)
	else:
		target = null
	
	if target and is_instance_valid(target):
		handle_combat(enemies, delta)
	else:
		current_state = "wandering"
		wander(delta)
		if animated_sprite:
			animated_sprite.modulate = original_color

	update_animation()
	update_sprite_direction()

func update_animation():
	if not animated_sprite: return
	
	var new_anim = "Idle"
	match current_state:
		"wandering", "pursuing", "retreating":
			new_anim = "Walk"
		"idle", "combat":
			new_anim = "Idle"
	
	if animated_sprite.animation != new_anim:
		animated_sprite.play(new_anim)

func update_sprite_direction():
	if not animated_sprite: return
	
	var look_at_pos = Vector2.ZERO
	if target and is_instance_valid(target):
		look_at_pos = target.global_position
	elif current_state == "wandering":
		look_at_pos = wander_target
	
	if look_at_pos != Vector2.ZERO:
		if look_at_pos.x < global_position.x:
			animated_sprite.flip_h = true
		elif look_at_pos.x > global_position.x:
			animated_sprite.flip_h = false

func update_ability_timers(delta: float):
	pass

func find_closest_enemy(enemies: Array) -> Node2D:
	var closest = enemies[0]
	for e in enemies:
		if position.distance_to(e.position) < position.distance_to(closest.position):
			closest = e
	return closest

func handle_combat(enemies: Array, delta: float):
	var distance = position.distance_to(target.position)
	
	var closest_enemy_distance = distance
	var closest_enemy = target
	for enemy in enemies:
		if is_instance_valid(enemy):
			var dist = position.distance_to(enemy.position)
			if dist < closest_enemy_distance:
				closest_enemy_distance = dist
				closest_enemy = enemy
	
	var new_state = "idle"
	if closest_enemy_distance < safe_distance:
		new_state = "retreating"
	elif distance > attack_range + 80:
		new_state = "pursuing"
	else:
		new_state = "combat"
	
	if new_state != current_state:
		previous_state = current_state
		current_state = new_state
		reaction_timer = reaction_time
	
	if reaction_timer <= 0:
		execute_state(enemies, delta, closest_enemy)
	else:
		execute_previous_state(enemies, delta * 0.5, closest_enemy)

func execute_state(enemies: Array, delta: float, closest_enemy: Node2D):
	if current_state == "retreating":
		retreat_from_enemies(enemies, delta, closest_enemy)
	elif current_state == "pursuing":
		pursue_enemy(delta)
	elif current_state == "combat":
		combat_stance(enemies)

func execute_previous_state(enemies: Array, delta: float, closest_enemy: Node2D):
	if previous_state == "retreating":
		retreat_from_enemies(enemies, delta, closest_enemy)
	elif previous_state == "pursuing":
		pursue_enemy(delta)

func pursue_enemy(delta: float):
	var direction = (target.position - position).normalized()
	position += direction * speed * 0.65 * delta
	position.x = clamp(position.x, -400, 400)
	position.y = clamp(position.y, -300, 300)
	if animated_sprite:
		animated_sprite.modulate = original_color

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
		
		var edge_buffer = 50
		var future_pos = position + retreat_direction * speed * retreat_speed_multiplier * delta
		
		if future_pos.x < -400 + edge_buffer or future_pos.x > 400 - edge_buffer:
			retreat_direction.x *= -0.5
		if future_pos.y < -300 + edge_buffer or future_pos.y > 300 - edge_buffer:
			retreat_direction.y *= -0.5
		
		retreat_direction = retreat_direction.normalized()
		
		position += retreat_direction * speed * retreat_speed_multiplier * delta
		position.x = clamp(position.x, -400, 400)
		position.y = clamp(position.y, -300, 300)
		
		retreat_action(closest_enemy)
		if animated_sprite:
			animated_sprite.modulate = get_retreat_color()
	elif animated_sprite:
		animated_sprite.modulate = original_color

func retreat_action(closest_enemy: Node2D):
	pass

func get_retreat_color() -> Color:
	return Color.LIGHT_BLUE

func combat_stance(enemies: Array):
	if not use_abilities(enemies):
		if attack_timer <= 0:
			attack_timer = attack_cooldown
			basic_attack(target)
		elif animated_sprite:
			animated_sprite.modulate = original_color

func use_abilities(enemies: Array) -> bool:
	return false

func basic_attack(enemy: Node2D):
	pass

func wander(delta):
	if wander_timer <= 0:
		choose_new_wander_target()
		wander_timer = randf_range(2.0, 5.0)
	
	var distance = position.distance_to(wander_target)
	if distance > 10:
		var direction = (wander_target - position).normalized()
		position += direction * speed * 0.5 * delta
	
	position.x = clamp(position.x, -400, 400)
	position.y = clamp(position.y, -300, 300)

func choose_new_wander_target():
	var angle = randf_range(0, TAU)
	var distance = randf_range(50, wander_radius)
	wander_target = position + Vector2(cos(angle), sin(angle)) * distance
	wander_target.x = clamp(wander_target.x, -400, 400)
	wander_target.y = clamp(wander_target.y, -300, 300)

func take_damage(amount: int):
	Global.total_damage_taken += amount
	if char_name != "Unknown":
		Global.character_stats[char_name].damage_taken += amount
	
	health -= amount
	damage_flash()
	spawn_damage_number(amount)
	
	if health <= 0:
		queue_free()

func deal_damage_to(enemy: Node2D, amount: int):
	if enemy.has_method("take_damage"):
		enemy.take_damage(amount)
		Global.total_damage_dealt += amount
		if char_name != "Unknown":
			Global.character_stats[char_name].damage_dealt += amount

func damage_flash():
	if not animated_sprite: return
	animated_sprite.modulate = Color.WHITE * 2
	await get_tree().create_timer(0.1).timeout
	if is_instance_valid(self):
		animated_sprite.modulate = original_color

func cast_flash(color: Color):
	if not animated_sprite: return
	animated_sprite.modulate = color
	await get_tree().create_timer(0.1).timeout
	if is_instance_valid(self):
		animated_sprite.modulate = original_color

func spawn_damage_number(amount: int):
	var damage_label = DamageNumber.new()
	damage_label.damage = amount
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
