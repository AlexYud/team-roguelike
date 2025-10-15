extends "res://Scripts/base_character.gd"

@export var slam_cooldown: float = 6.0
@export var slam_radius: float = 144.0
@export var slam_damage_pct: float = 0.6
@export var slam_knockback: float = 60.0
@export var slam_fury_bonus: int = 5

@export var frenzy_duration: float = 6.0
@export var frenzy_attack_speed_mult: float = 1.4
@export var frenzy_speed_mult: float = 1.25
@export var frenzy_damage_mult: float = 1.25
@export var frenzy_lifesteal: float = 0.15
@export var frenzy_fury_cost: int = 100

@export var fury_per_hit: int = 2
@export var max_fury: int = 100

@export var swing_duration: float = 0.25
@export var swing_half_width: float = 54.0
@export var swing_backreach: float = 24.0
@export var chase_reach_bonus: float = 48.0
@export var fleeing_lead_pct: float = 0.5
@export var fleeing_lead_cap: float = 90.0
@export var lunge_step: float = 18.0

var slam_timer: float = 0.0
var frenzy_timer: float = 0.0
var is_frenzy: bool = false
var fury: int = 0

var base_damage: int
var base_speed: float
var base_cooldown: float

var swing_timer: float = 0.0
var swing_hit: Dictionary = {}
var swing_dir: Vector2 = Vector2.RIGHT

var basic_unlocked: bool = false
var ult_unlocked: bool = false

func character_ready() -> void:
	speed = 180.0
	attack_range = 70.0
	attack_cooldown = 1.0
	damage = 7
	health = 140
	max_health = 140
	safe_distance = 0.0
	crit_chance = 0.05
	crit_damage_multiplier = 1.5
	base_damage = damage
	base_speed = speed
	base_cooldown = attack_cooldown
	slam_timer = 1
	frenzy_timer = 0.0

func update_ability_timers(delta: float) -> void:
	if slam_timer > 0.0:
		slam_timer -= delta
	if is_frenzy:
		if frenzy_timer > 0.0:
			frenzy_timer -= delta
		if frenzy_timer <= 0.0:
			_end_frenzy()
	if swing_timer > 0.0:
		swing_timer -= delta
		_melee_sweep_frame()
		if swing_timer <= 0.0:
			swing_hit.clear()

func use_abilities(enemies: Array) -> bool:
	if enemies.is_empty():
		return false
	if ult_unlocked and auto_ult_enabled and (not is_frenzy) and fury >= frenzy_fury_cost and (_is_surrounded(enemies) or health <= max_health * 0.5):
		_start_frenzy()
		return true
	if basic_unlocked and slam_timer <= 0.0:
		var hit_count: int = _count_enemies_in_radius(slam_radius)
		if hit_count >= 2 or _is_surrounded(enemies):
			_cast_crimson_slam()
			return true
	return false

func combat_stance(enemies: Array, delta: float) -> void:
	if not is_instance_valid(target):
		return
	var distance_to_target: float = position.distance_to(target.position)
	var effective_range: float = attack_range + chase_reach_bonus
	if distance_to_target > effective_range:
		var direction: Vector2 = (target.position - position).normalized()
		move_with_boundary_slide(direction, 0.85, delta)
	else:
		if not use_abilities(enemies) and attack_timer <= 0.0 and swing_timer <= 0.0:
			attack_timer = attack_cooldown
			basic_attack(target)

func basic_attack(enemy: Node2D) -> void:
	if is_instance_valid(enemy):
		var d: Vector2 = (enemy.global_position - global_position)
		if d.length() > 0.001:
			swing_dir = d.normalized()
	elif is_instance_valid(target):
		var d2: Vector2 = (target.global_position - global_position)
		if d2.length() > 0.001:
			swing_dir = d2.normalized()
	else:
		swing_dir = Vector2.RIGHT
	var np: Vector2 = global_position + swing_dir * lunge_step
	np.x = clamp(np.x, Global.BOUNDS.position.x, Global.BOUNDS.end.x)
	np.y = clamp(np.y, Global.BOUNDS.position.y, Global.BOUNDS.end.y)
	global_position = np
	swing_hit.clear()
	swing_timer = swing_duration
	_melee_sweep_frame()

func _melee_sweep_frame() -> void:
	var enemies: Array = get_tree().get_nodes_in_group("enemies")
	if enemies.is_empty():
		return
	var origin: Vector2 = global_position
	var reach_base: float = attack_range + chase_reach_bonus
	var any_hit: bool = false
	for e in enemies:
		var enemy: Node2D = e as Node2D
		if enemy == null or not is_instance_valid(enemy):
			continue
		var eid: int = enemy.get_instance_id()
		if swing_hit.has(eid):
			continue
		var enemy_speed: float = 0.0
		var spv: Variant = enemy.get("speed")
		if spv is float or spv is int:
			enemy_speed = float(spv)
		var lead: float = min(fleeing_lead_cap, enemy_speed * fleeing_lead_pct)
		var reach: float = reach_base + lead
		var v: Vector2 = enemy.global_position - origin
		var proj: float = v.dot(swing_dir)
		if proj < -swing_backreach or proj > reach:
			continue
		var lateral2: float = v.length_squared() - proj * proj
		var hw: float = swing_half_width + min(32.0, enemy_speed * 0.20)
		if lateral2 <= hw * hw:
			_deal_damage_with_stats(enemy, damage)
			_spawn_hit_fx(enemy.global_position)
			add_fury(fury_per_hit)
			swing_hit[eid] = true
			any_hit = true
	if not any_hit and is_instance_valid(target):
		var te: Node2D = target
		var tid: int = te.get_instance_id()
		if not swing_hit.has(tid):
			var d: float = origin.distance_to(te.global_position)
			var enemy_speed2: float = 0.0
			var sp2: Variant = te.get("speed")
			if sp2 is float or sp2 is int:
				enemy_speed2 = float(sp2)
			var lead2: float = min(fleeing_lead_cap, enemy_speed2 * fleeing_lead_pct)
			var tol: float = 10.0 + lead2 * 0.25
			if d <= reach_base + tol:
				_deal_damage_with_stats(te, damage)
				_spawn_hit_fx(te.global_position)
				add_fury(fury_per_hit)
				swing_hit[tid] = true
	if any_hit:
		cast_flash(Color.WHITE)

func _deal_damage_with_stats(enemy: Node2D, amt: int) -> void:
	deal_damage_to(enemy, amt)
	if is_frenzy:
		_apply_lifesteal(amt)

func _apply_lifesteal(amt: int) -> void:
	if frenzy_lifesteal <= 0.0:
		return
	var heal: int = int(round(float(amt) * frenzy_lifesteal))
	if heal <= 0:
		return
	health = clamp(health + heal, 0, max_health)
	_spawn_heal_fx()

func _cast_crimson_slam() -> void:
	slam_timer = slam_cooldown
	var n_hit: int = 0
	var enemies: Array = get_tree().get_nodes_in_group("enemies")
	var center: Vector2 = global_position
	for e in enemies:
		var enemy: Node2D = e as Node2D
		if enemy == null or not is_instance_valid(enemy):
			continue
		if center.distance_to(enemy.global_position) <= slam_radius:
			_deal_damage_with_stats(enemy, int(round(damage * slam_damage_pct)))
			var push_dir: Vector2 = (enemy.global_position - center).normalized()
			var end_pos: Vector2 = enemy.global_position + push_dir * slam_knockback
			end_pos.x = clamp(end_pos.x, Global.BOUNDS.position.x, Global.BOUNDS.end.x)
			end_pos.y = clamp(end_pos.y, Global.BOUNDS.position.y, Global.BOUNDS.end.y)
			var tw: Tween = create_tween()
			tw.tween_property(enemy, "global_position", end_pos, 0.12).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
			n_hit += 1
	_spawn_slam_fx(center)
	if n_hit >= 3:
		add_fury(slam_fury_bonus)

func _start_frenzy() -> void:
	is_frenzy = true
	frenzy_timer = frenzy_duration
	damage = int(round(base_damage * frenzy_damage_mult))
	speed = base_speed * frenzy_speed_mult
	attack_cooldown = base_cooldown / frenzy_attack_speed_mult
	fury = max(0, fury - frenzy_fury_cost)
	_spawn_frenzy_fx()

func _end_frenzy() -> void:
	is_frenzy = false
	damage = base_damage
	speed = base_speed
	attack_cooldown = base_cooldown

func add_fury(amount: int) -> void:
	fury = clamp(fury + amount, 0, max_fury)

func _count_enemies_in_radius(r: float) -> int:
	var enemies: Array = get_tree().get_nodes_in_group("enemies")
	var c: int = 0
	for e in enemies:
		var enemy: Node2D = e as Node2D
		if enemy != null and is_instance_valid(enemy) and global_position.distance_to(enemy.global_position) <= r:
			c += 1
	return c

func _is_surrounded(enemies: Array) -> bool:
	var near: int = 0
	var radius: float = 120.0
	for e in enemies:
		var enemy: Node2D = e as Node2D
		if enemy != null and is_instance_valid(enemy) and global_position.distance_to(enemy.global_position) <= radius:
			near += 1
	return near >= 3

func _spawn_hit_fx(pos: Vector2) -> void:
	for i in range(6):
		var p: Sprite2D = Sprite2D.new()
		var img: Image = Image.create(6, 6, false, Image.FORMAT_RGBA8)
		img.fill(Color(1, 1, 1, 1))
		p.texture = ImageTexture.create_from_image(img)
		add_child(p)
		register_effect(p)
		p.global_position = pos
		var ang: float = (TAU / 6.0) * float(i)
		var endp: Vector2 = pos + Vector2(cos(ang), sin(ang)) * 22.0
		var tw: Tween = create_tween()
		tw.tween_property(p, "global_position", endp, 0.15)
		tw.parallel().tween_property(p, "modulate:a", 0.0, 0.15)
		tw.tween_callback(p.queue_free)

func _spawn_slam_fx(center: Vector2) -> void:
	var rings: int = 3
	for r in range(rings):
		var ring: Node2D = Node2D.new()
		add_child(ring)
		register_effect(ring)
		ring.global_position = center
		var spr: Sprite2D = Sprite2D.new()
		var img: Image = Image.create(20, 20, false, Image.FORMAT_RGBA8)
		img.fill(Color(0.8, 0.1, 0.1, 0.9))
		spr.texture = ImageTexture.create_from_image(img)
		ring.add_child(spr)
		spr.scale = Vector2(0.2, 0.2)
		var tw: Tween = create_tween()
		tw.set_parallel(true)
		var scale_to: float = 2.0 + 0.35 * float(r)
		tw.tween_property(spr, "scale", Vector2(scale_to, scale_to), 0.18 + 0.05 * float(r))
		tw.tween_property(spr, "modulate:a", 0.0, 0.18 + 0.05 * float(r))
		tw.tween_callback(ring.queue_free)

func _spawn_frenzy_fx() -> void:
	var fx: Node2D = Node2D.new()
	add_child(fx)
	register_effect(fx)
	var parts: Array = []
	for i in range(14):
		var p: Sprite2D = Sprite2D.new()
		var img: Image = Image.create(10, 10, false, Image.FORMAT_RGBA8)
		img.fill(Color(0.9, 0.2, 0.1, 0.9))
		p.texture = ImageTexture.create_from_image(img)
		fx.add_child(p)
		parts.append(p)
	var elapsed: float = 0.0
	while elapsed < frenzy_duration and is_instance_valid(self) and is_instance_valid(fx):
		fx.global_position = global_position
		for i in range(parts.size()):
			var p2: Sprite2D = parts[i] as Sprite2D
			if p2 == null or not is_instance_valid(p2):
				continue
			var ang: float = (TAU / 14.0) * float(i) + elapsed * 8.0
			var rad: float = 36.0 + sin(elapsed * 5.0 + float(i)) * 8.0
			p2.position = Vector2(cos(ang), sin(ang)) * rad
		await get_tree().create_timer(0.016).timeout
		elapsed += 0.016
	if not is_instance_valid(fx):
		return
	for p3 in parts:
		var spr: Sprite2D = p3 as Sprite2D
		if spr != null and is_instance_valid(spr):
			var fade: Tween = create_tween()
			fade.tween_property(spr, "modulate:a", 0.0, 0.25)
			fade.tween_callback(spr.queue_free)
	var tw: Tween = create_tween()
	tw.tween_interval(0.26)
	tw.tween_callback(fx.queue_free)

func _spawn_heal_fx() -> void:
	var p: Sprite2D = Sprite2D.new()
	var img: Image = Image.create(12, 12, false, Image.FORMAT_RGBA8)
	img.fill(Color(0.2, 1.0, 0.2, 1.0))
	p.texture = ImageTexture.create_from_image(img)
	add_child(p)
	register_effect(p)
	p.global_position = global_position + Vector2(0, -20)
	var tw: Tween = create_tween()
	tw.tween_property(p, "global_position", p.global_position + Vector2(0, -26), 0.25)
	tw.parallel().tween_property(p, "modulate:a", 0.0, 0.25)
	tw.tween_callback(p.queue_free)

func is_basic_unlocked() -> bool:
	return basic_unlocked

func is_ult_unlocked() -> bool:
	return ult_unlocked

func apply_upgrade(upg: String) -> void:
	match upg:
		"linguis_basic":
			basic_unlocked = true
		"linguis_ult":
			ult_unlocked = true
		"linguis_speed":
			speed *= 1.15
			base_speed = speed
		"linguis_damage":
			damage = int(round(damage * 1.2))
			base_damage = damage
		"linguis_range":
			attack_range *= 1.2
		"linguis_crit":
			crit_chance = min(0.95, crit_chance + 0.05)
		"linguis_critdmg":
			crit_damage_multiplier += 0.25

func set_auto_ult_enabled(v: bool):
	auto_ult_enabled = v

func trigger_ult():
	if ult_unlocked and not is_frenzy and fury >= frenzy_fury_cost:
		_start_frenzy()
