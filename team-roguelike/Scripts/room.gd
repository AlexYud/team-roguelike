extends Node2D
@export var enemy_scene: PackedScene
@export var enemy_count: int = 5
@export var spawn_delay: float = 1
signal cleared
@onready var monster_spawn_points = $MonsterSpawnPoints.get_children() if has_node("MonsterSpawnPoints") else []
@onready var character_spawn_points = $CharacterSpawnPoints.get_children() if has_node("CharacterSpawnPoints") else []
var check_timer: Timer
var enemies_to_spawn: int = 0
var spawn_timer: Timer

func _ready():
	pass

func start_room():
	enemies_to_spawn = enemy_count
	
	spawn_timer = Timer.new()
	spawn_timer.wait_time = spawn_delay
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
	
	var batch_size = min(4, enemies_to_spawn)
	
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
		var random_spawn = monster_spawn_points[randi() % monster_spawn_points.size()]
		enemy.position = random_spawn.position
	else:
		enemy.position = Vector2(randf_range(-300, 300), randf_range(-200, 200))
	
	enemy.add_to_group("enemies")

func _on_check_clear():
	if enemies_to_spawn == 0 and get_tree().get_nodes_in_group("enemies").size() == 0:
		check_timer.stop()
		emit_signal("cleared")
