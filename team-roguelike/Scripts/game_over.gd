extends Control

func _ready():
	set_anchors_preset(Control.PRESET_FULL_RECT)
	
	var margin_container = $MarginContainer
	margin_container.set_anchors_preset(Control.PRESET_FULL_RECT)
	margin_container.add_theme_constant_override("margin_left", 50)
	margin_container.add_theme_constant_override("margin_top", 50)
	margin_container.add_theme_constant_override("margin_right", 50)
	margin_container.add_theme_constant_override("margin_bottom", 50)
	
	$MarginContainer/MainContainer/Title.text = "GAME OVER"
	$MarginContainer/MainContainer/OverallStats.text = "Total Enemies Killed: %d\nTotal Damage Dealt: %d\nTotal Damage Taken: %d\nSouls Collected: %d\nLast Room: %d" % [
		Global.total_enemies_killed,
		Global.total_damage_dealt,
		Global.total_damage_taken,
		Global.souls_collected,
		Global.last_room_reached
	]
	var char_container = $MarginContainer/MainContainer/ScrollContainer/CharacterStats
	for char_name in Global.character_stats.keys():
		var stats = Global.character_stats[char_name]
		var label = Label.new()
		label.text = "\n%s:\n  Kills: %d | Damage: %d | Taken: %d" % [
			char_name,
			stats["enemies_killed"],
			stats["damage_dealt"],
			stats["damage_taken"]
		]
		label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		char_container.add_child(label)
	$MarginContainer/MainContainer/ReturnButton.connect("pressed", Callable(self, "_on_return_pressed"))

func _on_return_pressed():
	get_tree().change_scene_to_file("res://Scenes/lobby.tscn")
