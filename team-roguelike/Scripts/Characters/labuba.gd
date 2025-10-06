extends "res://Scripts/base_character.gd"

@export var fire_bolt_cooldown: float = 1.5
@export var fire_bolt_damage: int = 15
@export var shotgun_cooldown: float = 5.0
@export var shotgun_damage: int = 12
@export var ultimate_cooldown: float = 20.0
@export var ultimate_damage: int = 50
@export var ultimate_radius: float = 200

var fire_bolt_timer: float = 0.0
var shotgun_timer: float = 0.0
var ultimate_timer: float = 0.0

func character_ready():
	fire_bolt_timer = fire_bolt_cooldown
	shotgun_timer = shotgun_cooldown
	ultimate_timer = ultimate_cooldown
	speed = 200
	attack_range = 220
	attack_cooldown = 1.2
	damage = 12
	health = 50
	max_health = 50
	safe_distance = 160
	retreat_speed_multiplier = 1.3
	crit_chance = 0.10
	crit_damage_multiplier = 1.75

func update_ability_timers(delta: float):
	fire_bolt_timer -= delta
	shotgun_timer -= delta
	ultimate_timer -= delta

func retreat_action():
	if shotgun_timer <= 0 and randf() < 0.5 and is_instance_valid(target):
		shotgun_timer = shotgun_cooldown * 1.2
		cast_shotgun(target)

func use_abilities(enemies: Array) -> bool:
	var nearby_count = count_nearby_enemies(enemies, ultimate_radius)
	var distance_to_target = position.distance_to(target.position)
	
	if ultimate_timer <= 0 and nearby_count >= 3:
		ultimate_timer = ultimate_cooldown
		cast_ultimate()
		return true
	elif shotgun_timer <= 0 and is_instance_valid(target) and distance_to_target <= attack_range * 1.2:
		shotgun_timer = shotgun_cooldown
		cast_shotgun(target)
		return true
	
	return false

func basic_attack(enemy: Node2D):
	if fire_bolt_timer <= 0:
		fire_bolt_timer = fire_bolt_cooldown
		cast_fire_bolt(enemy)

func count_nearby_enemies(enemies: Array, radius: float) -> int:
	var count = 0
	for enemy in enemies:
		if is_instance_valid(enemy):
			if position.distance_to(enemy.position) <= radius:
				count += 1
	return count

func cast_fire_bolt(enemy: Node2D):
	if not is_instance_valid(enemy):
		return

	cast_flash(Color.ORANGE_RED)
	
	var bolt = FireBolt.new()
	bolt.direction = (enemy.global_position - global_position).normalized()
	bolt.damage = fire_bolt_damage
	bolt.speed = 400
	bolt.caster = self
	get_parent().add_child(bolt)
	bolt.global_position = global_position

func cast_shotgun(enemy: Node2D):
	if not is_instance_valid(enemy):
		return

	cast_flash(Color.ORANGE)
	var base_direction = (enemy.global_position - global_position).normalized()
	var spread_angle = deg_to_rad(20)
	var directions = [
		base_direction.rotated(-spread_angle),
		base_direction,
		base_direction.rotated(spread_angle)
	]
	
	for dir in directions:
		var bolt = FireBolt.new()
		bolt.direction = dir
		bolt.damage = shotgun_damage
		bolt.speed = 450
		bolt.caster = self
		get_parent().add_child(bolt)
		bolt.global_position = global_position

func cast_ultimate():
	if animated_sprite:
		animated_sprite.modulate = Color.DARK_RED
	
	for i in range(3):
		await get_tree().create_timer(0.15).timeout
		create_ultimate_charge_ring(i)
	
	if is_instance_valid(self):
		create_ultimate_explosion()
		
		var enemies = get_tree().get_nodes_in_group("enemies")
		for enemy in enemies:
			if is_instance_valid(enemy):
				var distance = global_position.distance_to(enemy.global_position)
				if distance <= ultimate_radius:
					deal_damage_to(enemy, ultimate_damage)
		
		if animated_sprite:
			animated_sprite.modulate = original_color

func create_ultimate_charge_ring(ring_index: int):
	var radius = 60 + ring_index * 40
	for i in range(12):
		var particle = Sprite2D.new()
		var img = Image.create(8, 8, false, Image.FORMAT_RGBA8)
		img.fill(Color.RED if i % 2 == 0 else Color.ORANGE)
		particle.texture = ImageTexture.create_from_image(img)
		get_parent().add_child(particle)
		
		var angle = (TAU / 12) * i
		particle.global_position = global_position + Vector2(cos(angle), sin(angle)) * radius
		
		var tween = create_tween()
		tween.tween_property(particle, "global_position", global_position, 0.25)
		tween.parallel().tween_property(particle, "modulate:a", 0.0, 0.25)
		tween.tween_callback(particle.queue_free)

func create_ultimate_explosion():
	for i in range(32):
		var particle = Sprite2D.new()
		var img = Image.create(16, 16, false, Image.FORMAT_RGBA8)
		img.fill(Color.RED if i % 2 == 0 else Color.ORANGE)
		particle.texture = ImageTexture.create_from_image(img)
		get_parent().add_child(particle)
		particle.global_position = global_position
		
		var angle = (TAU / 32) * i
		var end_pos = global_position + Vector2(cos(angle), sin(angle)) * ultimate_radius
		
		var tween = create_tween()
		tween.tween_property(particle, "global_position", end_pos, 0.6)
		tween.parallel().tween_property(particle, "modulate:a", 0.0, 0.6)
		tween.tween_callback(particle.queue_free)

class FireBolt extends Node2D:
	var direction: Vector2 = Vector2.RIGHT
	var damage: int = 15
	var speed: float = 400
	var lifetime: float = 1.5
	var caster: Node2D = null
	
	func _ready():
		var proj_sprite = Sprite2D.new()
		add_child(proj_sprite)
		var img = Image.create(10, 10, false, Image.FORMAT_RGBA8)
		img.fill(Color.ORANGE_RED)
		proj_sprite.texture = ImageTexture.create_from_image(img)
		rotation = direction.angle()
		
		await get_tree().create_timer(lifetime).timeout
		if is_instance_valid(self):
			queue_free()
	
	func _process(delta):
		global_position += direction * speed * delta
		
		var enemies = get_tree().get_nodes_in_group("enemies")
		for enemy in enemies:
			if is_instance_valid(enemy):
				if global_position.distance_to(enemy.global_position) < 20:
					if caster:
						caster.deal_damage_to(enemy, damage)
					queue_free()
					return
