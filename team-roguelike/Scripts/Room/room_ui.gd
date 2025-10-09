extends CanvasLayer

@onready var room_label = $RoomLabel
@onready var soul_label = $SoulLabel

var soul_count := 0

func _ready():
	room_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	room_label.vertical_alignment = VERTICAL_ALIGNMENT_TOP
	room_label.position = Vector2(0, 20)
	room_label.size = Vector2(get_viewport().size.x, 50)
	room_label.add_theme_font_size_override("font_size", 32)

	soul_label.position = Vector2(20, 20)
	soul_label.add_theme_font_size_override("font_size", 28)
	update_soul_count()
	add_to_group("room_ui")

func update_room_number(room_number: int):
	room_label.text = "Room: %d" % room_number

func add_soul():
	soul_count += 1
	update_soul_count()

func update_soul_count():
	soul_label.text = "Souls: %d" % soul_count
