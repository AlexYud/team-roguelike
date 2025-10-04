extends Control

@onready var character_grid = $MarginContainer/CharacterGrid
@onready var start_button = $StartRun

var selected_characters: Array[String] = []

func _ready():
	for button in character_grid.get_children():
		button.connect("pressed", Callable(self, "_on_character_pressed").bind(button.text))
	start_button.connect("pressed", Callable(self, "_on_start_run_pressed"))
	start_button.disabled = true


func _on_character_pressed(character_name: String):
	if character_name in selected_characters:
		selected_characters.erase(character_name)
	elif selected_characters.size() < 3:
		selected_characters.append(character_name)

	for button in character_grid.get_children():
		if button.text in selected_characters:
			button.add_theme_color_override("font_color", Color(0,1,0))
		else:
			button.add_theme_color_override("font_color", Color(1,1,1))

	start_button.disabled = selected_characters.size() != 3

func _on_start_run_pressed():
	Global.selected_characters = selected_characters.duplicate()
	get_tree().change_scene_to_file("res://Scenes/main.tscn")
