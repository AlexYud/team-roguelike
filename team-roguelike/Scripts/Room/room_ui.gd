extends CanvasLayer

signal autoplay_toggled(enabled: bool)
signal ult_pressed(index: int)

@onready var room_label = $RoomLabel
@onready var soul_label = $SoulLabel

var soul_count := 0
var party: Array = []
var bottom_panel: PanelContainer
var center_holder: CenterContainer
var bar: HBoxContainer
var autoplay_enabled: bool = true

var card_buttons: Array = []
var name_labels: Array = []
var hp_labels: Array = []
var fury_labels: Array = []
var auto_toggle: CheckButton

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
	_build_bottom_bar()
	set_process(true)

func _build_bottom_bar():
	bottom_panel = PanelContainer.new()
	add_child(bottom_panel)
	bottom_panel.anchor_left = 0.0
	bottom_panel.anchor_top = 1.0
	bottom_panel.anchor_right = 1.0
	bottom_panel.anchor_bottom = 1.0
	bottom_panel.offset_top = -110
	bottom_panel.offset_bottom = 0
	center_holder = CenterContainer.new()
	center_holder.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	center_holder.size_flags_vertical = Control.SIZE_FILL
	bottom_panel.add_child(center_holder)
	bar = HBoxContainer.new()
	bar.add_theme_constant_override("separation", 16)
	center_holder.add_child(bar)
	_create_card(0)
	_create_card(1)
	_create_card(2)
	auto_toggle = CheckButton.new()
	auto_toggle.text = "Auto Ult"
	auto_toggle.button_pressed = true
	auto_toggle.custom_minimum_size = Vector2(160, 72)
	auto_toggle.connect("toggled", Callable(self, "_on_toggle_autoplay"))
	bar.add_child(auto_toggle)

func _create_card(index: int):
	var card = Button.new()
	card.toggle_mode = false
	card.custom_minimum_size = Vector2(200, 90)
	card.focus_mode = Control.FOCUS_NONE
	card.connect("pressed", Callable(self, "_on_card_pressed").bind(index))
	bar.add_child(card)
	card_buttons.append(card)
	var vb = VBoxContainer.new()
	vb.alignment = BoxContainer.ALIGNMENT_CENTER
	vb.size_flags_vertical = Control.SIZE_EXPAND_FILL
	card.add_child(vb)
	var name_lbl = Label.new()
	name_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	name_lbl.add_theme_font_size_override("font_size", 22)
	vb.add_child(name_lbl)
	name_labels.append(name_lbl)
	var hp_lbl = Label.new()
	hp_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	hp_lbl.add_theme_font_size_override("font_size", 18)
	vb.add_child(hp_lbl)
	hp_labels.append(hp_lbl)
	var fury_lbl = Label.new()
	fury_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	fury_lbl.add_theme_font_size_override("font_size", 18)
	vb.add_child(fury_lbl)
	fury_labels.append(fury_lbl)

func update_room_number(room_number: int):
	room_label.text = "Room: %d" % room_number

func add_soul():
	soul_count += 1
	update_soul_count()

func update_soul_count():
	soul_label.text = "Souls: %d" % soul_count

func configure_for_party(p: Array):
	party = p
	_refresh_cards()

func _on_toggle_autoplay(pressed: bool):
	autoplay_enabled = pressed
	emit_signal("autoplay_toggled", autoplay_enabled)

func _on_card_pressed(idx: int):
	emit_signal("ult_pressed", idx)

func _process(_delta):
	_refresh_cards()

func _refresh_cards():
	for i in range(3):
		var btn: Button = card_buttons[i]
		var name_lbl: Label = name_labels[i]
		var hp_lbl: Label = hp_labels[i]
		var fury_lbl: Label = fury_labels[i]
		var alive := i < party.size() and is_instance_valid(party[i])
		btn.disabled = not alive
		if alive:
			var ch: Node = party[i]
			var nm := String(ch.get_meta("char_name","Character"))
			var hp := int(ch.get("health") if ch.get("health") != null else 0)
			var mhp := int(ch.get("max_health") if ch.get("max_health") != null else max(1,hp))
			var fy := int(ch.get("fury") if ch.get("fury") != null else 0)
			var mfy := int(ch.get("max_fury") if ch.get("max_fury") != null else 0)
			name_lbl.text = nm
			hp_lbl.text = "HP %d/%d" % [hp, mhp]
			if mfy > 0:
				fury_lbl.text = "Fury %d/%d" % [fy, mfy]
			else:
				fury_lbl.text = "Fury —"
		else:
			name_lbl.text = "Empty"
			hp_lbl.text = "HP —"
			fury_lbl.text = "Fury —"
