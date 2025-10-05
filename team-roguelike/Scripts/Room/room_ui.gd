extends CanvasLayer

@onready var room_label = $RoomLabel

func _ready():
	room_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	room_label.vertical_alignment = VERTICAL_ALIGNMENT_TOP
	room_label.position = Vector2(0, 20)
	room_label.size = Vector2(get_viewport().size.x, 50)
	
	room_label.add_theme_font_size_override("font_size", 32)

func update_room_number(room_number: int):
	room_label.text = "Room: %d" % room_number
