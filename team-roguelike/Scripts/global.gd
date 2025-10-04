extends Node

var selected_characters: Array[String] = []

var total_enemies_killed: int = 0
var total_damage_dealt: int = 0
var total_damage_taken: int = 0

var character_stats: Dictionary = {}

func reset_stats():
	total_enemies_killed = 0
	total_damage_dealt = 0
	total_damage_taken = 0
	character_stats.clear()

func init_character_stats(char_name: String):
	character_stats[char_name] = {
		"enemies_killed": 0,
		"damage_dealt": 0,
		"damage_taken": 0
	}
