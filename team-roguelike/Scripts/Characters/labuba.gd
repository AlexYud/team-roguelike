extends "res://Scripts/base_character.gd"

@export var orb_count: int = 2
@export var orb_cap: int = 10
@export var orb_growth_interval: float = 5.0
@export var orb_regen_interval: float = 2.5
@export var orb_radius: float = 120
@export var orb_speed: float = 2
@export var orb_damage: int = 16
@export var orb_hit_cooldown: float = 0.6
@export var orb_base_hit_radius: float = 28.0

@export var bloom_cooldown: float = 8.0
@export var bloom_duration: float = 5.0
@export var bloom_speed_boost: float = 2.0
@export var bloom_damage_boost: float = 1.1

@export var ember_base_damage: int = 150
@export var ember_bonus_per_orb: int = 25
@export var ember_base_radius: float = 250
@export var ember_radius_per_orb: float = 30
@export var ember_cooldown: float = 8.0

@export var ember_cost: int = 100
@export var fury_per_hit: int = 2
@export var max_fury: int = 100

var bloom_timer: float = 0.0
var bloom_active: bool = false
var ember_cd_timer: float = 0.0
var orbs: Array = []
var orb_angle: float = 0.0
var orb_regen_timer: float = 0.0
var orb_growth_timer: float = 0.0
var fury: int = 0
var basic_unlocked: bool = false
var ult_unlocked: bool = false
var start_orb_count: int = 3

func character_ready():
	speed = 210
	damage = orb_damage
	health = 90
	max_health = 90
	crit_chance = 0.10
	crit_damage_multiplier = 1.5
	attack_range = orb_radius * 2.5
	start_orb_count = orb_count
	create_orbs(orb_count)
	orb_growth_timer = orb_growth_interval
	orb_regen_timer = orb_regen_interval

func update_ability_timers(delta: float):
	if bloom_timer > 0.0:
		bloom_timer -= delta
	if ember_cd_timer > 0.0:
		ember_cd_timer -= delta
	var speed_mult = bloom_speed_boost if bloom_active and basic_unlocked else 1.0
	orb_angle += orb_speed * speed_mult * delta
	update_orb_positions()
	orb_regen_timer -= delta
	if orb_regen_timer <= 0 and orbs.size() < orb_count:
		add_orb()
		orb_regen_timer = orb_regen_interval
	orb_growth_timer -= delta
	if orb_growth_timer <= 0.0 and orb_count < orb_cap:
		orb_count += 1
		orb_growth_timer = orb_growth_interval

func basic_attack(enemy: Node2D):
	pass

func use_abilities(enemies: Array) -> bool:
	if basic_unlocked and not bloom_active and bloom_timer <= 0.0 and _should_bloom(enemies):
		cast_bloom()
		return true
	if ult_unlocked and auto_ult_enabled and ember_cd_timer <= 0.0 and orbs.size() > 0 and fury >= ember_cost:
		var count = orbs.size()
		var radius = ember_base_radius + ember_radius_per_orb * count
		var in_blast := 0
		for e in enemies:
			if is_instance_valid(e) and global_position.distance_to(e.global_position) <= radius:
				in_blast += 1
		if in_blast >= 3 or _is_surrounded(enemies):
			cast_ember_cataclysm()
			return true
	return false

func _is_surrounded(enemies: Array) -> bool:
	var around := 0
	for e in enemies:
		if is_instance_valid(e) and global_position.distance_to(e.global_position) <= safe_distance * 0.9:
			around += 1
	return around >= 3

func _near_boundary(margin: float) -> bool:
	var minx = Global.BOUNDS.position.x
	var maxx = Global.BOUNDS.end.x
	var miny = Global.BOUNDS.position.y
	var maxy = Global.BOUNDS.end.y
	return position.x <= minx + margin or position.x >= maxx - margin or position.y <= miny + margin or position.y >= maxy - margin

func _should_bloom(enemies: Array) -> bool:
	if _is_surrounded(enemies):
		return true
	if _near_boundary(84.0):
		for e in enemies:
			if is_instance_valid(e) and global_position.distance_to(e.global_position) <= orb_radius * 1.1:
				return true
	return false

func create_orbs(count: int):
	for i in range(count):
		var orb = Orb.new()
		orb.damage = orb_damage
		orb.caster = self
		orb.hit_cooldown = orb_hit_cooldown
		orb.hit_radius = orb_base_hit_radius
		orb.base_hit_radius = orb_base_hit_radius
		add_child(orb)
		orbs.append(orb)
		_spawn_orb_summon_fx(orb.global_position)
	update_orb_positions()

func update_orb_positions():
	for i in range(orbs.size()):
		if is_instance_valid(orbs[i]):
			var angle = orb_angle + (TAU / max(1, orbs.size())) * i
			var r = orb_radius
			orbs[i].global_position = global_position + Vector2(cos(angle), sin(angle)) * r

func cast_bloom():
	bloom_active = true
	bloom_timer = bloom_duration
	for orb in orbs:
		if is_instance_valid(orb):
			orb.damage = int(orb_damage * bloom_damage_boost)
	await get_tree().create_timer(bloom_duration).timeout
	if is_instance_valid(self):
		end_bloom()

func end_bloom():
	bloom_active = false
	for orb in orbs:
		if is_instance_valid(orb):
			orb.damage = orb_damage
	bloom_timer = bloom_cooldown

func cast_ember_cataclysm():
	if ember_cd_timer > 0.0 or orbs.size() == 0 or fury < ember_cost:
		return
	var count = orbs.size()
	var radius = ember_base_radius + ember_radius_per_orb * count
	var total_damage = ember_base_damage + ember_bonus_per_orb * count
	for orb in orbs:
		if is_instance_valid(orb):
			orb.queue_free()
	orbs.clear()
	create_explosion(radius, total_damage)
	fury = 0
	ember_cd_timer = ember_cooldown

func create_explosion(radius: float, damage: int):
	for i in range(24):
		var particle = Sprite2D.new()
		var img = Image.create(16, 16, false, Image.FORMAT_RGBA8)
		img.fill(Color.ORANGE_RED)
		particle.texture = ImageTexture.create_from_image(img)
		get_parent().add_child(particle)
		particle.global_position = global_position
		var angle = (TAU / 24) * i
		var end_pos = global_position + Vector2(cos(angle), sin(angle)) * radius
		var tween = create_tween()
		tween.tween_property(particle, "global_position", end_pos, 0.6)
		tween.parallel().tween_property(particle, "modulate:a", 0.0, 0.6)
		tween.tween_callback(particle.queue_free)
	var enemies = get_tree().get_nodes_in_group("enemies")
	for enemy in enemies:
		if is_instance_valid(enemy):
			if global_position.distance_to(enemy.global_position) <= radius:
				deal_damage_to(enemy, damage)

func add_orb():
	var orb = Orb.new()
	orb.damage = orb_damage
	orb.caster = self
	orb.hit_cooldown = orb_hit_cooldown
	orb.hit_radius = orb_base_hit_radius
	orb.base_hit_radius = orb_base_hit_radius
	add_child(orb)
	orbs.append(orb)
	_spawn_orb_summon_fx(orb.global_position)

func add_fury(amount: int):
	fury = clamp(fury + amount, 0, max_fury)

func restart_for_new_room():
	var keep_fury := fury
	bloom_active = false
	bloom_timer = 0.0
	ember_cd_timer = 0.0
	_cleanup_orbs()
	orb_count = start_orb_count
	create_orbs(orb_count)
	orb_growth_timer = orb_growth_interval
	orb_regen_timer = orb_regen_interval
	fury = keep_fury
	set_process(true)
	set_physics_process(true)

func is_basic_unlocked() -> bool:
	return basic_unlocked

func is_ult_unlocked() -> bool:
	return ult_unlocked

func apply_upgrade(upg: String):
	match upg:
		"labuba_basic":
			basic_unlocked = true
		"labuba_ult":
			ult_unlocked = true
		"labuba_speed":
			speed *= 1.15
		"labuba_damage":
			orb_damage = int(orb_damage * 1.2)
			for orb in orbs:
				if is_instance_valid(orb):
					orb.damage = orb_damage
		"labuba_range":
			attack_range *= 1.2
			orb_radius *= 1.2
		"labuba_crit":
			crit_chance = min(0.95, crit_chance + 0.05)
		"labuba_critdmg":
			crit_damage_multiplier += 0.25

func _spawn_orb_summon_fx(pos: Vector2):
	var fx := Node2D.new()
	get_parent().add_child(fx)
	fx.global_position = pos
	var ring := Sprite2D.new()
	var img := Image.create(18, 18, false, Image.FORMAT_RGBA8)
	img.fill(Color(1,0.55,0.1,1))
	ring.texture = ImageTexture.create_from_image(img)
	ring.modulate = Color(1,1,1,0.85)
	fx.add_child(ring)
	ring.scale = Vector2(0.4, 0.4)
	var t := create_tween()
	t.set_parallel(true)
	t.tween_property(ring, "scale", Vector2(1.6,1.6), 0.18)
	t.tween_property(ring, "modulate:a", 0.0, 0.18)
	t.tween_callback(fx.queue_free)

func _cleanup_orbs():
	for orb in orbs:
		if is_instance_valid(orb):
			orb.queue_free()
	orbs.clear()

func die():
	_cleanup_orbs()
	super.die()

class Orb extends Node2D:
	var damage: int = 16
	var caster: Node2D
	var hit_cooldown: float = 0.6
	var hit_radius: float = 28.0
	var base_hit_radius: float = 28.0
	var sprite: Sprite2D
	var _cool: Dictionary = {}
	func _ready():
		sprite = Sprite2D.new()
		add_child(sprite)
		var img = Image.create(12, 12, false, Image.FORMAT_RGBA8)
		img.fill(Color.ORANGE)
		sprite.texture = ImageTexture.create_from_image(img)
		_apply_visual()
	func set_hit_radius(r: float):
		hit_radius = max(10.0, r)
		_apply_visual()
	func _apply_visual():
		if sprite:
			var s = hit_radius / base_hit_radius if base_hit_radius > 0.0 else 1.0
			sprite.scale = Vector2(s, s)
	func _process(delta):
		var keys = _cool.keys()
		for k in keys:
			_cool[k] = float(_cool[k]) - delta
			if _cool[k] <= 0.0:
				_cool.erase(k)
		var enemies = get_tree().get_nodes_in_group("enemies")
		for enemy in enemies:
			if is_instance_valid(enemy) and global_position.distance_to(enemy.global_position) < hit_radius:
				var id = enemy.get_instance_id()
				if not _cool.has(id):
					if caster:
						caster.deal_damage_to(enemy, damage)
						if caster.has_method("add_fury"):
							caster.add_fury(caster.fury_per_hit)
					_cool[id] = hit_cooldown

func set_auto_ult_enabled(v: bool):
	auto_ult_enabled = v

func trigger_ult():
	if ult_unlocked and ember_cd_timer <= 0.0 and orbs.size() > 0 and fury >= ember_cost:
		cast_ember_cataclysm()
