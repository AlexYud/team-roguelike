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
	if char_name == "" or char_name == "Unknown":
		return
	if not character_stats.has(char_name):
		character_stats[char_name] = {
			"enemies_killed": 0,
			"damage_dealt": 0,
			"damage_taken": 0
		}

func add_damage_dealt(char_name: String, amount: int):
	total_damage_dealt += amount
	if char_name == "" or char_name == "Unknown":
		return
	init_character_stats(char_name)
	character_stats[char_name]["damage_dealt"] += amount

func add_damage_taken(char_name: String, amount: int):
	total_damage_taken += amount
	if char_name == "" or char_name == "Unknown":
		return
	init_character_stats(char_name)
	character_stats[char_name]["damage_taken"] += amount

func add_enemy_killed(char_name: String):
	total_enemies_killed += 1
	if char_name == "" or char_name == "Unknown":
		return
	init_character_stats(char_name)
	character_stats[char_name]["enemies_killed"] += 1
