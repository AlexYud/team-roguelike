extends Node2D

@export var enemy_scene: PackedScene
@export var enemy_count: int = 10
@export var spawn_delay: float = 0.9
@export var spawn_delay_decrease: float = 0.12
@export var min_spawn_delay: float = 0.03
@export var health_scale_per_room: float = 0.10
@export var damage_scale_per_room: float = 0.08
@export var enemy_density_growth: float = 1.35
@export var enemy_cap: int = 300

signal cleared
signal room_changed(room_number: int)

@onready var monster_spawn_points = $MonsterSpawnPoints.get_children() if has_node("MonsterSpawnPoints") else []
@onready var character_spawn_points = $CharacterSpawnPoints.get_children() if has_node("CharacterSpawnPoints") else []

var check_timer: Timer
var enemies_to_spawn: int = 0
var spawn_timer: Timer
var current_room: int = 1

func _ready():
	pass

func start_room():
	var density_multiplier: float = pow(enemy_density_growth, float(max(0, current_room - 1)))
	enemies_to_spawn = int(min(ceil(float(enemy_count) * density_multiplier), float(enemy_cap)))
	emit_signal("room_changed", current_room)

	var current_spawn_delay: float = max(min_spawn_delay, spawn_delay - float(current_room - 1) * spawn_delay_decrease)

	spawn_timer = Timer.new()
	spawn_timer.wait_time = current_spawn_delay
	spawn_timer.one_shot = false
	add_child(spawn_timer)
	spawn_timer.connect("timeout", Callable(self, "_spawn_next_wave"))
	spawn_timer.start()

	check_timer = Timer.new()
	check_timer.wait_time = 0.3
	check_timer.one_shot = false
	check_timer.autostart = true
	add_child(check_timer)
	check_timer.connect("timeout", Callable(self, "_on_check_clear"))

func _spawn_next_wave():
	if enemies_to_spawn <= 0:
		spawn_timer.stop()
		return
	var batch_cap: int = clamp(4 + int(float(current_room - 1) * 0.5), 4, 12)
	var batch_size: int = min(batch_cap, enemies_to_spawn)
	for i in range(batch_size):
		spawn_single_enemy()
		enemies_to_spawn -= 1

func spawn_single_enemy():
	if enemy_scene == null:
		push_error("Enemy scene not assigned")
		return
	var enemy: Node2D = enemy_scene.instantiate()
	add_child(enemy)
	if monster_spawn_points.size() > 0:
		var random_spawn: Node2D = monster_spawn_points[randi() % monster_spawn_points.size()]
		enemy.global_position = random_spawn.global_position
	else:
		enemy.global_position = Vector2(
			randf_range(Global.BOUNDS.position.x, Global.BOUNDS.end.x),
			randf_range(Global.BOUNDS.position.y, Global.BOUNDS.end.y)
		)

	scale_enemy_stats(enemy)
	enemy.add_to_group("enemies")

func scale_enemy_stats(enemy: Node2D):
	var health_multiplier: float = 1.0 + float(current_room - 1) * health_scale_per_room
	var damage_multiplier: float = 1.0 + float(current_room - 1) * damage_scale_per_room
	if "max_health" in enemy:
		enemy.max_health = max(1, int(float(enemy.max_health) * health_multiplier))
		if "health" in enemy:
			enemy.health = enemy.max_health
	if "damage" in enemy:
		enemy.damage = max(1, int(float(enemy.damage) * damage_multiplier))

func _on_check_clear():
	if enemies_to_spawn == 0 and get_tree().get_nodes_in_group("enemies").size() == 0:
		check_timer.stop()
		current_room += 1
		emit_signal("cleared")

func get_current_room() -> int:
	return current_room

func reset_room_counter():
	current_room = 1
