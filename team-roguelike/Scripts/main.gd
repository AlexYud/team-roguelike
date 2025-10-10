extends Node2D

@export var room_scene: PackedScene = preload("res://Scenes/Room/room.tscn")
@export var enemy_scene: PackedScene
@export var lobby_scene_path: String = "res://Scenes/lobby.tscn"
@export var room_ui_scene: PackedScene = preload("res://Scenes/Room/roomUI.tscn")

var current_room_index: int = 0
var room_instance: Node = null
var party: Array = []
var room_ui: CanvasLayer = null
var game_over_shown: bool = false
var ui_layer: CanvasLayer

func _ready():
	ui_layer = CanvasLayer.new()
	add_child(ui_layer)
	setup_room_ui()
	spawn_party_characters()
	start_next_room()

func setup_room_ui():
	room_ui = room_ui_scene.instantiate()
	add_child(room_ui)

func spawn_party_characters():
	for char_name in Global.selected_characters:
		var path: String = "res://Scenes/Characters/%s.tscn" % char_name
		var char_scene = load(path)
		if char_scene:
			var character: Node2D = char_scene.instantiate()
			character.add_to_group("characters")
			character.set_meta("char_name", char_name)
			party.append(character)
			Global.init_character_stats(char_name)
		else:
			push_error("Could not load character scene: " + path)

func start_next_room():
	var temp_party = []
	for character in party:
		if is_instance_valid(character):
			if character.get_parent():
				character.get_parent().remove_child(character)
			temp_party.append(character)
	party = temp_party
	if room_instance:
		room_instance.queue_free()
	current_room_index += 1
	Global.last_room_reached = current_room_index
	var enemy_count: int = get_enemies_for_room(current_room_index)
	room_instance = room_scene.instantiate()
	room_instance.position = Vector2.ZERO
	room_instance.enemy_scene = enemy_scene
	room_instance.enemy_count = enemy_count
	room_instance.current_room = current_room_index
	room_instance.connect("cleared", Callable(self, "_on_room_cleared"))
	room_instance.connect("room_changed", Callable(self, "_on_room_changed"))
	add_child(room_instance)
	teleport_party_to_room(room_instance)
	room_instance.start_room()
	await get_tree().create_timer(0.5).timeout

func _on_room_changed(room_number: int):
	if is_instance_valid(room_ui):
		room_ui.update_room_number(room_number)

func teleport_party_to_room(room: Node):
	var spawn_points_node = room.get_node_or_null("CharacterSpawnPoints")
	var points = spawn_points_node.get_children() if spawn_points_node else []
	var i := 0
	for character in party:
		room.add_child(character)
		if i < points.size():
			character.global_position = points[i].global_position
		else:
			var spacing := 80.0
			var total_width := party.size() * spacing
			var start_x := Global.BOUNDS.position.x + (Global.BOUNDS.size.x - total_width) / 2.0
			var start_y := Global.BOUNDS.position.y + Global.BOUNDS.size.y * 0.3
			character.global_position = Vector2(start_x + i * spacing, start_y)
			character.global_position.x = clamp(character.global_position.x, Global.BOUNDS.position.x + 20, Global.BOUNDS.end.x - 20)
			character.global_position.y = clamp(character.global_position.y, Global.BOUNDS.position.y + 20, Global.BOUNDS.end.y - 20)
		i += 1

func get_enemies_for_room(idx: int) -> int:
	return 5 + (idx - 1) * 2

func _process(_delta):
	if game_over_shown:
		return
	var chars := get_tree().get_nodes_in_group("characters")
	if chars.size() == 0:
		show_game_over()

func show_game_over():
	if game_over_shown:
		return
	game_over_shown = true
	if is_instance_valid(room_ui):
		room_ui.visible = false
	var game_over_scene = load("res://Scenes/GameOver.tscn")
	var game_over = game_over_scene.instantiate()
	ui_layer.add_child(game_over)

func _on_room_cleared():
	var buff_scene = load("res://Scenes/BuffSelection.tscn")
	var buff_selection = buff_scene.instantiate()
	add_child(buff_selection)
	buff_selection.connect("buff_selected", Callable(self, "_on_buff_selected"))

func _on_buff_selected(buff_name: String):
	apply_buff_to_party(buff_name)
	start_next_room()

func apply_buff_to_party(buff_name: String):
	for character in party:
		if not is_instance_valid(character):
			continue
		match buff_name:
			"Attack Up":
				if character.get("damage") != null:
					character.damage += 10
			"Speed Up":
				if character.get("speed") != null:
					character.speed *= 1.2
			"Health Up":
				if character.get("max_health") != null:
					character.max_health += 50
					character.health += 50
			"Attack Speed":
				if character.get("attack_cooldown") != null:
					character.attack_cooldown *= 0.8
			"Range Up":
				if character.get("attack_range") != null:
					character.attack_range *= 1.3
