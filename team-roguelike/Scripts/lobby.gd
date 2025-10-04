extends Control

@onready var character_grid = $MarginContainer/CharacterGrid
@onready var start_button = $StartRun

var animated_sprites: Array[AnimatedSprite2D] = []
var selected_characters: Array[String] = []

# Breathe animation tracking
var idle_frames: int = 0
var idle_threshold: int = 150

func _ready():
	# Get all AnimatedSprite2D nodes
	animated_sprites.append($AnimatedSprite2D)
	animated_sprites.append($AnimatedSprite2D2)
	animated_sprites.append($AnimatedSprite2D3)
	animated_sprites.append($AnimatedSprite2D4)
	
	# Start all sprites with idle animation
	for sprite in animated_sprites:
		if sprite:
			sprite.play("breathe")
	
	for button in character_grid.get_children():
		button.connect("pressed", Callable(self, "_on_character_pressed").bind(button.text))
	
	start_button.connect("pressed", Callable(self, "_on_start_run_pressed"))
	start_button.disabled = true

func _process(delta):
	idle_frames += 1
	
	# Update all sprite animations
	for sprite in animated_sprites:
		if sprite:
			if idle_frames < idle_threshold:
				if sprite.animation != "breathe":
					sprite.play("breathe")
			else:
				if sprite.sprite_frames.has_animation("breathe"):
					if sprite.animation != "breathe":
						sprite.play("breathe")

func _on_character_pressed(character_name: String):
	# Reset idle counter when user interacts
	idle_frames = 0
	
	if selected_characters.size() < 3:
		selected_characters.append(character_name)
	elif character_name in selected_characters:
		selected_characters.erase(character_name)
	
	for button in character_grid.get_children():
		if button.text in selected_characters:
			button.add_theme_color_override("font_color", Color.LIME_GREEN)
		else:
			button.add_theme_color_override("font_color", Color.WHITE)
	
	start_button.disabled = selected_characters.size() != 3

func _on_start_run_pressed():
	Global.selected_characters = selected_characters.duplicate()
	Global.reset_stats()
	get_tree().change_scene_to_file("res://Scenes/main.tscn")
