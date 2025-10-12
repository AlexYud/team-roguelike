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
@export var crit_chance: float = 0.05
@export var crit_damage_multiplier: float = 1.5
@export var knockback_distance: float = 40.0
@export var knockback_duration: float = 0.15

var attack_timer: float = 0.0
var reaction_timer: float = 0.0
var wander_timer: float = 0.0
var target: Node2D = null
var wander_target: Vector2
var current_state: String = "idle"
var previous_state: String = "idle"
var is_knocked_back: bool = false
var animated_sprite: AnimatedSprite2D
var original_color: Color = Color.WHITE
var char_name: String = ""
var is_moving: bool = false
var last_position: Vector2
var idle_frames: int = 0
var idle_threshold: int = 150
var spawned_effects: Array = []
var auto_ult_enabled: bool = true

func _ready():
	add_to_group("characters")
	char_name = get_meta("char_name", "Unknown")
	Global.init_character_stats(char_name)
	setup_visuals()
	choose_new_wander_target()
	character_ready()
	last_position = position

func character_ready():
	pass

func setup_visuals():
	animated_sprite = get_node_or_null("AnimatedSprite2D")
	if animated_sprite:
		animated_sprite.z_as_relative = true
		animated_sprite.z_index = 0
		original_color = animated_sprite.modulate

func _process(delta):
	z_index = int(global_position.y)
	if is_knocked_back:
		return
	attack_timer -= delta
	reaction_timer -= delta
	wander_timer -= delta
	var velocity = (position - last_position) / delta if delta > 0 else Vector2.ZERO
	is_moving = velocity.length() > 0.1
	last_position = position
	update_ability_timers(delta)
	var enemies = get_tree().get_nodes_in_group("enemies")
	target = find_closest_enemy(enemies) if enemies.size() > 0 else null
	if animated_sprite:
		animated_sprite.modulate = original_color
	if target and is_instance_valid(target):
		handle_combat(enemies, delta)
	else:
		current_state = "wandering"
		wander(delta)
	update_animation()
	update_sprite_direction()

func update_animation():
	if not animated_sprite: return
	var new_anim = "idle"
	if is_moving:
		idle_frames = 0
		new_anim = "walking"
	else:
		idle_frames += 1
		new_anim = "breathe" if idle_frames >= idle_threshold and animated_sprite.sprite_frames.has_animation("breathe") else "idle"
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
		animated_sprite.flip_h = look_at_pos.x < global_position.x

func update_ability_timers(_delta: float):
	pass

func find_closest_enemy(enemies: Array) -> Node2D:
	var best: Node2D = null
	var best_score: float = -1e12
	for e in enemies:
		var enemy := e as Node2D
		if enemy == null or not is_instance_valid(enemy):
			continue
		var d_self := position.distance_to(enemy.position)
		var score := -d_self
		var et = enemy.get("target")
		if et != null and et != self and et is Node and (et as Node).is_in_group("characters"):
			score += 600.0
			var et_pos: Vector2 = (et as Node2D).global_position if et is Node2D else enemy.position
			var e_ar: float = float(enemy.get("attack_range")) if enemy.get("attack_range") != null else 50.0
			var et_dist := et_pos.distance_to(enemy.global_position)
			if et_dist <= e_ar * 1.15:
				score += 250.0
			var ally_hp_val = et.get("health") if (et is Object) else null
			if ally_hp_val != null and int(ally_hp_val) <= 30:
				score += 120.0
		if d_self <= attack_range * 1.4:
			score += 60.0
		if score > best_score:
			best_score = score
			best = enemy
	return best

func handle_combat(enemies: Array, delta: float):
	if target == null or not is_instance_valid(target):
		return
	var closest_enemy := find_closest_enemy(enemies)
	if closest_enemy == null:
		return
	var distance_to_target = position.distance_to(target.position)
	var closest_enemy_distance = position.distance_to(closest_enemy.position)
	var target_is_attacking_ally := false
	var t = target.get("target")
	if t != null and t != self and t is Node and (t as Node).is_in_group("characters"):
		target_is_attacking_ally = true
	var new_state = "idle"
	if target_is_attacking_ally:
		if closest_enemy_distance < safe_distance * 0.6:
			new_state = "retreating"
		elif distance_to_target > attack_range * 0.5:
			new_state = "assist_pursuit"
		else:
			new_state = "combat"
	else:
		if closest_enemy_distance < safe_distance:
			new_state = "retreating"
		elif distance_to_target > attack_range + 80:
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

func execute_state(enemies: Array, delta: float, _closest_enemy: Node2D):
	match current_state:
		"retreating": retreat_from_enemies(enemies, delta)
		"pursuing": pursue_enemy(delta)
		"assist_pursuit": pursue_enemy_assist(delta)
		"combat": combat_stance(enemies, delta)

func execute_previous_state(enemies: Array, delta: float, _closest_enemy: Node2D):
	match previous_state:
		"retreating": retreat_from_enemies(enemies, delta)
		"pursuing": pursue_enemy(delta)
		"assist_pursuit": pursue_enemy_assist(delta)
		"combat": combat_stance(enemies, delta)

func pursue_enemy(delta: float):
	var direction = (target.position - position).normalized()
	move_with_boundary_slide(direction, 0.65, delta)

func pursue_enemy_assist(delta: float):
	var direction = (target.position - position).normalized()
	move_with_boundary_slide(direction, 0.95, delta)

func retreat_from_enemies(enemies: Array, delta: float):
	var retreat_direction = Vector2.ZERO
	var edge_influence_max = safe_distance * 1.5
	for enemy in enemies:
		if is_instance_valid(enemy):
			var distance = position.distance_to(enemy.position)
			if distance < edge_influence_max:
				retreat_direction += (position - enemy.position).normalized() * (1.0 - (distance / edge_influence_max))
	if retreat_direction.length_squared() > 0:
		retreat_direction = retreat_direction.normalized()
		move_with_boundary_slide(retreat_direction, retreat_speed_multiplier, delta)
		retreat_action()

func avoid_boundaries(direction: Vector2):
	var edge_margin = 100.0
	if position.x < Global.BOUNDS.position.x + edge_margin: direction.x = abs(direction.x)
	if position.x > Global.BOUNDS.end.x - edge_margin: direction.x = -abs(direction.x)
	if position.y < Global.BOUNDS.position.y + edge_margin: direction.y = abs(direction.y)
	if position.y > Global.BOUNDS.end.y - edge_margin: direction.y = -abs(direction.y)

func clamp_position():
	position.x = clamp(position.x, Global.BOUNDS.position.x, Global.BOUNDS.end.x)
	position.y = clamp(position.y, Global.BOUNDS.position.y, Global.BOUNDS.end.y)

func retreat_action():
	pass

func combat_stance(enemies: Array, delta: float):
	if not is_instance_valid(target): return
	var distance_to_target = position.distance_to(target.position)
	if distance_to_target > attack_range:
		var direction = (target.position - position).normalized()
		move_with_boundary_slide(direction, 0.8, delta)
	else:
		if not use_abilities(enemies) and attack_timer <= 0:
			attack_timer = attack_cooldown
			basic_attack(target)

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
		move_with_boundary_slide(direction, 0.5, delta)
	clamp_position()

func choose_new_wander_target():
	var angle = randf_range(0, TAU)
	var distance = randf_range(50, wander_radius)
	wander_target = position + Vector2(cos(angle), sin(angle)) * distance
	clamp_position()

func take_damage(amount: int, is_crit: bool = false):
	Global.add_damage_taken(char_name, amount)
	health -= amount
	damage_flash()
	spawn_damage_number(amount, is_crit)
	apply_knockback()
	if health <= 0: die()

func apply_knockback():
	if is_knocked_back: return
	is_knocked_back = true
	var knockback_dir = (global_position - target.global_position).normalized() if target and is_instance_valid(target) else Vector2(randf_range(-1, 1), randf_range(-1, 1)).normalized()
	var end_pos = global_position + knockback_dir * knockback_distance
	end_pos.x = clamp(end_pos.x, Global.BOUNDS.position.x, Global.BOUNDS.end.x)
	end_pos.y = clamp(end_pos.y, Global.BOUNDS.position.y, Global.BOUNDS.end.y)
	var tween = create_tween()
	tween.tween_property(self, "global_position", end_pos, knockback_duration).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	await tween.finished
	if is_instance_valid(self): is_knocked_back = false

func die():
	cleanup_effects()
	queue_free()

func cleanup_effects():
	for effect in spawned_effects:
		if is_instance_valid(effect): effect.queue_free()
	spawned_effects.clear()

func register_effect(effect: Node):
	spawned_effects.append(effect)
	spawned_effects = spawned_effects.filter(func(e): return is_instance_valid(e))

func deal_damage_to(enemy: Node2D, amount: int):
	if enemy.has_method("take_damage"):
		var final_damage = amount
		var is_crit = randf() < crit_chance
		if is_crit:
			final_damage = int(amount * crit_damage_multiplier)
		var died: bool = enemy.take_damage(final_damage, is_crit)
		Global.add_damage_dealt(char_name, final_damage)
		if died:
			Global.add_enemy_killed(char_name)
			on_enemy_killed()

func on_enemy_killed():
	pass

func damage_flash():
	if not animated_sprite: return
	var tween = create_tween()
	tween.set_parallel(true)
	tween.tween_property(animated_sprite, "modulate", Color.RED, 0.1).from(original_color)
	tween.tween_callback(func(): animated_sprite.modulate = original_color)

func cast_flash(color: Color):
	if not animated_sprite: return
	var tween = create_tween()
	tween.set_parallel(true)
	tween.tween_property(animated_sprite, "modulate", color, 0.1).from(original_color)
	tween.tween_callback(func(): animated_sprite.modulate = original_color)

func spawn_damage_number(amount: int, is_crit: bool = false):
	var damage_label = DamageNumber.new()
	damage_label.damage = amount
	damage_label.is_crit = is_crit
	var offset = Vector2(randf_range(-20, 20), randf_range(-15, 15))
	damage_label.global_position = global_position + offset
	damage_label.z_index = 1000
	get_parent().add_child(damage_label)

class DamageNumber extends Node2D:
	var damage: int = 0
	var is_crit: bool = false
	var lifetime: float = 1.2
	var float_speed: float = 80.0
	var fade_start: float = 0.7
	var label: Label
	func _ready():
		label = Label.new()
		add_child(label)
		label.text = str(damage)
		label.add_theme_font_size_override("font_size", 48)
		label.add_theme_color_override("font_color", Color.RED)
		label.add_theme_color_override("font_outline_color", Color.BLACK)
		label.add_theme_constant_override("outline_size", 5)
		if is_crit:
			label.add_theme_color_override("font_color", Color.FIREBRICK)
			label.add_theme_font_size_override("font_size", 64)
		label.position = Vector2(-40, -50)
		label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		scale = Vector2(0.3, 0.3)
		var tween = create_tween()
		tween.set_parallel(true)
		var end_scale = Vector2(1.5, 1.5) if is_crit else Vector2(1.2, 1.2)
		tween.tween_property(self, "scale", end_scale, 0.15).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
		tween.tween_property(label, "rotation", randf_range(-0.2, 0.2), 0.15)
		await tween.finished
		var shrink = create_tween()
		shrink.tween_property(self, "scale", Vector2(1.0, 1.0), 0.1)
	func _process(delta):
		position.y -= float_speed * delta
		lifetime -= delta
		if lifetime < fade_start:
			modulate.a = lifetime / fade_start
		if lifetime <= 0:
			queue_free()

func move_with_boundary_slide(direction: Vector2, speed_multiplier: float, delta: float):
	if direction == Vector2.ZERO:
		return
	var dir = direction.normalized()
	var vel = dir * speed * speed_multiplier * delta
	var minx = Global.BOUNDS.position.x
	var maxx = Global.BOUNDS.end.x
	var miny = Global.BOUNDS.position.y
	var maxy = Global.BOUNDS.end.y
	var next = position + vel
	var clamped = Vector2(clamp(next.x, minx, maxx), clamp(next.y, miny, maxy))
	var moved = clamped - position
	if moved.length_squared() < 0.0001:
		var slide_dir = compute_slide_direction(dir).normalized()
		var alt_vel = slide_dir * speed * speed_multiplier * delta
		var alt_next = position + alt_vel
		var alt_clamped = Vector2(clamp(alt_next.x, minx, maxx), clamp(alt_next.y, miny, maxy))
		var alt_moved = alt_clamped - position
		if alt_moved.length_squared() > moved.length_squared():
			position = alt_clamped
		else:
			var ortho = Vector2(-dir.y, dir.x)
			if randf() < 0.5:
				ortho = -ortho
			var jitter_vel = ortho * speed * speed_multiplier * 0.6 * delta
			var j_next = position + jitter_vel
			var j_clamped = Vector2(clamp(j_next.x, minx, maxx), clamp(j_next.y, miny, maxy))
			position = j_clamped
	else:
		position = clamped

func compute_slide_direction(direction: Vector2) -> Vector2:
	var minx = Global.BOUNDS.position.x
	var maxx = Global.BOUNDS.end.x
	var miny = Global.BOUNDS.position.y
	var maxy = Global.BOUNDS.end.y
	var near_eps = 4.0
	var near_left = position.x <= minx + near_eps
	var near_right = position.x >= maxx - near_eps
	var near_top = position.y <= miny + near_eps
	var near_bottom = position.y >= maxy - near_eps
	if (near_left or near_right) and (near_top or near_bottom):
		var center = (Global.BOUNDS.position + Global.BOUNDS.end) * 0.5
		return (center - position).normalized()
	if near_left or near_right:
		var sy = 1.0 if direction.y >= 0.0 else -1.0
		if near_top: sy = 1.0
		if near_bottom: sy = -1.0
		return Vector2(0, sy)
	if near_top or near_bottom:
		var sx = 1.0 if direction.x >= 0.0 else -1.0
		if near_left: sx = 1.0
		if near_right: sx = -1.0
		return Vector2(sx, 0)
	var ortho = Vector2(-direction.y, direction.x)
	if randf() < 0.5:
		ortho = -ortho
	return ortho.normalized()

func set_auto_ult_enabled(v: bool):
	auto_ult_enabled = v

func trigger_ult():
	return false
