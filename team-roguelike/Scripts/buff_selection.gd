extends Control

signal buff_selected(buff_name: String)

var buffs: Array = [
	{"name": "Attack Up", "description": "+10 Damage"},
	{"name": "Speed Up", "description": "+20% Speed"},
	{"name": "Health Up", "description": "+50 Max Health"},
	{"name": "Attack Speed", "description": "-20% Cooldown"},
	{"name": "Range Up", "description": "+30% Range"}
]

func _ready():
	var buttons = $CanvasLayer/CenterContainer/HBoxContainer.get_children()
	var selected_buffs = buffs.duplicate()
	selected_buffs.shuffle()
	
	for i in range(3):
		var button = buttons[i]
		var buff = selected_buffs[i]
		button.text = buff.name + "\n" + buff.description
		button.connect("pressed", Callable(self, "_on_buff_selected").bind(buff.name))

func _on_buff_selected(buff_name: String):
	emit_signal("buff_selected", buff_name)
	queue_free()
