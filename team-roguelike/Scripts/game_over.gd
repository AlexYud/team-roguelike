extends Control

func _ready():
	$MarginContainer/MainContainer/Title.text = "GAME OVER"
	
	$MarginContainer/MainContainer/OverallStats.text = "Total Enemies Killed: %d\nTotal Damage Dealt: %d\nTotal Damage Taken: %d" % [
		Global.total_enemies_killed,
		Global.total_damage_dealt,
		Global.total_damage_taken
	]
	
	var char_container = $MarginContainer/MainContainer/ScrollContainer/CharacterStats
	for char_name in Global.character_stats.keys():
		var stats = Global.character_stats[char_name]
		var label = Label.new()
		label.text = "\n%s:\n  Kills: %d | Damage: %d | Taken: %d" % [
			char_name,
			stats.enemies_killed,
			stats.damage_dealt,
			stats.damage_taken
		]
		char_container.add_child(label)
	
	$MarginContainer/MainContainer/ReturnButton.connect("pressed", Callable(self, "_on_return_pressed"))

func _on_return_pressed():
	get_tree().change_scene_to_file("res://Scenes/lobby.tscn")
