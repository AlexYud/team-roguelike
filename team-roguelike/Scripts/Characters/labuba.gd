extends "res://Scripts/base_character.gd"

@export var fire_bolt_cooldown: float = 1.5
@export var fire_bolt_damage: int = 15
@export var stun_cooldown: float = 6.0
@export var stun_damage: int = 10
@export var stun_duration: float = 2.0
@export var ultimate_cooldown: float = 20.0
@export var ultimate_damage: int = 50
@export var ultimate_radius: float = 200

var fire_bolt_timer: float = 0.0
var stun_timer: float = 0.0
var ultimate_timer: float = 0.0

func character_ready():
	fire_bolt_timer = fire_bolt_cooldown
	stun_timer = stun_cooldown
	ultimate_timer = ultimate_cooldown
	speed = 200
	attack_range = 220
	attack_cooldown = 1.2
	damage = 12
	health = 50
	max_health = 50
	safe_distance = 160
	retreat_speed_multiplier = 1.3

func update_ability_timers(delta: float):
	fire_bolt_timer -= delta
	stun_timer -= delta
	ultimate_timer -= delta

func get_retreat_color() -> Color:
	return Color.ORANGE_RED

func retreat_action(closest_enemy: Node2D):
	if fire_bolt_timer <= 0 and randf() < 0.5:
		fire_bolt_timer = fire_bolt_cooldown * 1.2
		cast_fire_bolt(closest_enemy)

func use_abilities(enemies: Array) -> bool:
	var nearby_count = count_nearby_enemies(enemies, ultimate_radius)
	
	if ultimate_timer <= 0 and nearby_count >= 3:
		ultimate_timer = ultimate_cooldown
		cast_ultimate()
		return true
	elif stun_timer <= 0:
		stun_timer = stun_cooldown
		cast_stun(target)
		return true
	elif fire_bolt_timer <= 0:
		fire_bolt_timer = fire_bolt_cooldown
		cast_fire_bolt(target)
		return true
	
	return false

func basic_attack(enemy: Node2D):
	cast_fire_bolt(enemy)

func count_nearby_enemies(enemies: Array, radius: float) -> int:
	var count = 0
	for enemy in enemies:
		if is_instance_valid(enemy):
			if position.distance_to(enemy.position) <= radius:
				count += 1
	return count

func cast_fire_bolt(enemy: Node2D):
	var bolt = FireBolt.new()
	bolt.target = enemy
	bolt.damage = fire_bolt_damage
	bolt.speed = 380
	bolt.caster = self
	
	var proj_sprite = Sprite2D.new()
	bolt.add_child(proj_sprite)
	var img = Image.create(10, 10, false, Image.FORMAT_RGBA8)
	img.fill(Color.ORANGE_RED)
	proj_sprite.texture = ImageTexture.create_from_image(img)
	
	get_parent().add_child(bolt)
	bolt.global_position = global_position
	
	cast_flash(Color.ORANGE_RED)

func cast_stun(enemy: Node2D):
	if animated_sprite:
		animated_sprite.modulate = Color.YELLOW
	
	var stun_projectile = StunProjectile.new()
	stun_projectile.target = enemy
	stun_projectile.damage = stun_damage
	stun_projectile.stun_duration = stun_duration
	stun_projectile.speed = 300
	stun_projectile.caster = self
	
	var proj_sprite = Sprite2D.new()
	stun_projectile.add_child(proj_sprite)
	var img = Image.create(14, 14, false, Image.FORMAT_RGBA8)
	img.fill(Color.YELLOW)
	proj_sprite.texture = ImageTexture.create_from_image(img)
	
	get_parent().add_child(stun_projectile)
	stun_projectile.global_position = global_position
	
	await get_tree().create_timer(0.2).timeout
	if is_instance_valid(self) and animated_sprite:
		animated_sprite.modulate = original_color

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
	var target: Node2D = null
	var damage: int = 15
	var speed: float = 380
	var lifetime: float = 3.0
	var caster: Node2D = null
	
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
			if caster:
				caster.deal_damage_to(target, damage)
			queue_free()

class StunProjectile extends Node2D:
	var target: Node2D = null
	var damage: int = 10
	var stun_duration: float = 2.0
	var speed: float = 300
	var lifetime: float = 3.0
	var caster: Node2D = null
	
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
			if caster:
				caster.deal_damage_to(target, damage)
			apply_stun(target)
			queue_free()
	
	func apply_stun(enemy: Node2D):
		if "speed" in enemy:
			var original_speed = enemy.speed
			enemy.speed = 0
			
			create_stun_effect(enemy)
			
			await get_tree().create_timer(stun_duration).timeout
			if is_instance_valid(enemy):
				enemy.speed = original_speed
	
	func create_stun_effect(enemy: Node2D):
		for i in range(8):
			var particle = Sprite2D.new()
			var img = Image.create(6, 6, false, Image.FORMAT_RGBA8)
			img.fill(Color.YELLOW)
			particle.texture = ImageTexture.create_from_image(img)
			get_parent().add_child(particle)
			
			var angle = (TAU / 8) * i
			var start_angle = angle
			particle.global_position = enemy.global_position + Vector2(0, -30)
			
			var radius = 25
			var rotation_speed = 3.0
			
			for j in range(int(stun_duration * 60)):
				await get_tree().create_timer(1.0 / 60.0).timeout
				if is_instance_valid(enemy) and is_instance_valid(particle):
					start_angle += rotation_speed / 60.0
					var offset = Vector2(cos(start_angle), sin(start_angle)) * radius
					particle.global_position = enemy.global_position + offset + Vector2(0, -30)
				else:
					break
			
			if is_instance_valid(particle):
				particle.queue_free()
