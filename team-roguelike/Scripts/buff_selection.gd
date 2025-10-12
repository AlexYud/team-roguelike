extends Control

signal upgrade_selected(payload: Dictionary)
signal buff_selected(buff_name: String)

var party: Array[Node] = []

func init_with_party(p: Array) -> void:
	party.clear()
	for n in p:
		if is_instance_valid(n):
			party.append(n as Node)

func _ready() -> void:
	var container: HBoxContainer = $CanvasLayer/CenterContainer/HBoxContainer
	var buttons: Array[Button] = []
	for child in container.get_children():
		if child is Button:
			buttons.append(child as Button)

	var options: Array[Dictionary] = _build_options()
	var count: int = min(3, min(buttons.size(), options.size()))
	for i in range(count):
		var btn: Button = buttons[i]
		var opt: Dictionary = options[i]
		var title := String(opt["title"])
		var desc := String(opt["description"])
		btn.text = "%s\n%s" % [title, desc]
		btn.connect("pressed", Callable(self, "_on_pick").bind(opt))
	for j in range(count, buttons.size()):
		buttons[j].visible = false

func _on_pick(opt: Dictionary) -> void:
	emit_signal("upgrade_selected", opt)
	emit_signal("buff_selected", String(opt.get("upgrade_id", "")))
	queue_free()

func _build_options() -> Array[Dictionary]:
	var opts: Array[Dictionary] = []

	var alive: Array[Node] = []
	for c in party:
		if is_instance_valid(c):
			alive.append(c)

	if alive.is_empty():
		return _fallback_generic()

	for c in alive:
		var name := String(c.get_meta("char_name", ""))
		if name == "":
			continue

		if name == "Labuba":
			var basic_ready: bool = false
			if c.has_method("is_basic_unlocked"):
				basic_ready = bool(c.call("is_basic_unlocked"))
			var ult_ready: bool = false
			if c.has_method("is_ult_unlocked"):
				ult_ready = bool(c.call("is_ult_unlocked"))

			if not basic_ready:
				opts.append({
					"char_name": name,
					"upgrade_id": "labuba_basic",
					"title": "Labuba — Unlock Infernal Bloom",
					"description": "Enable orb-speed burst."
				})
			elif not ult_ready:
				opts.append({
					"char_name": name,
					"upgrade_id": "labuba_ult",
					"title": "Labuba — Unlock Ember Cataclysm",
					"description": "Enable explosive ultimate."
				})
			else:
				var pool: Array[Dictionary] = [
					{"char_name": name, "upgrade_id": "labuba_speed",   "title": "Labuba — +15% Move Speed", "description": "Reposition faster."},
					{"char_name": name, "upgrade_id": "labuba_damage",  "title": "Labuba — +20% Orb Damage", "description": "Increase DPS."},
					{"char_name": name, "upgrade_id": "labuba_range",   "title": "Labuba — +20% Orb Range",  "description": "Larger orbit."},
					{"char_name": name, "upgrade_id": "labuba_crit",    "title": "Labuba — +5% Crit Chance", "description": "More crits."},
					{"char_name": name, "upgrade_id": "labuba_critdmg", "title": "Labuba — +25% Crit Damage","description": "Bigger crits."}
				]
				pool.shuffle()
				opts.append(pool[0])

		elif name == "Linguis":
			var basic_ready_l: bool = false
			if c.has_method("is_basic_unlocked"):
				basic_ready_l = bool(c.call("is_basic_unlocked"))
			var ult_ready_l: bool = false
			if c.has_method("is_ult_unlocked"):
				ult_ready_l = bool(c.call("is_ult_unlocked"))

			if not basic_ready_l:
				opts.append({
					"char_name": name,
					"upgrade_id": "linguis_basic",
					"title": "Linguis — Unlock Crimson Slam",
					"description": "Radial shockwave crowd control."
				})
			elif not ult_ready_l:
				opts.append({
					"char_name": name,
					"upgrade_id": "linguis_ult",
					"title": "Linguis — Unlock Blood Frenzy",
					"description": "Berserk mode with lifesteal."
				})
			else:
				var pool_l: Array[Dictionary] = [
					{"char_name": name, "upgrade_id": "linguis_speed",   "title": "Linguis — +15% Move Speed", "description": "Close gaps faster."},
					{"char_name": name, "upgrade_id": "linguis_damage",  "title": "Linguis — +20% Damage",     "description": "Harder hits."},
					{"char_name": name, "upgrade_id": "linguis_range",   "title": "Linguis — +20% Range",      "description": "Longer reach."},
					{"char_name": name, "upgrade_id": "linguis_crit",    "title": "Linguis — +5% Crit Chance", "description": "More crits."},
					{"char_name": name, "upgrade_id": "linguis_critdmg", "title": "Linguis — +25% Crit Damage","description": "Bigger crits."}
				]
				pool_l.shuffle()
				opts.append(pool_l[0])

		else:
			var pool_other: Array[Dictionary] = [
				{"char_name": name, "upgrade_id": "generic_speed",  "title": name + " — +15% Move Speed", "description": "Reposition faster."},
				{"char_name": name, "upgrade_id": "generic_damage", "title": name + " — +20% Damage",     "description": "Hit harder."},
				{"char_name": name, "upgrade_id": "generic_range",  "title": name + " — +20% Range",      "description": "Keep distance."}
			]
			pool_other.shuffle()
			opts.append(pool_other[0])

	opts.shuffle()
	while opts.size() < 3:
		var fb: Array[Dictionary] = _fallback_generic()
		fb.shuffle()
		opts.append(fb[0])
	if opts.size() > 3:
		opts.resize(3)
	return opts

func _fallback_generic() -> Array[Dictionary]:
	return [
		{"char_name": "", "upgrade_id": "generic_speed",  "title": "Team — +15% Move Speed", "description": "Reposition faster."},
		{"char_name": "", "upgrade_id": "generic_damage", "title": "Team — +20% Damage",     "description": "Hit harder."},
		{"char_name": "", "upgrade_id": "generic_range",  "title": "Team — +20% Range",      "description": "Keep distance."}
	]
