extends VBoxContainer
## F1: every control, as a list in the inventory's style, from the top left: parchment rows, dim headings, the key
## line under it. Panels don't overlay each other: opening one closes the others (group "ui_panel").

const FONT := preload("res://assets/fonts/MononokiNerdFont-Regular.ttf")
const ROWS := [
	["Moving", ""], ["WASD", "walk"], ["Shift", "sprint"], ["Caps", "walk / run"], ["Alt", "dash"], ["Space", "jump"], ["Ctrl", "crouch"],
	["Fighting", ""], ["LMB", "swing (the last move key picks the cut)"], ["RMB", "cast"], ["Z", "next spell"],
	["Around you", ""], ["E", "use, talk, feed a fire, chop, cut sap"], ["G", "make a fire"], ["J", "join a camp; again: take a role"],
	["Your things", ""], ["Tab", "pack (wheel pick, LMB use / take / store, RMB switch side, Q drop, Shift = stack)"], ["C", "crafting (wheel pick, LMB make)"],
	["The world", ""], ["F5 / F9", "save / load"], ["Shift+F9", "a fresh island"], ["M", "map (wheel: who N follows)"], ["N / B", "watch someone / back to you"], ["[ ]", "sim speed"]]

func _ready() -> void:
	visible = false
	add_to_group("ui_panel")
	set_anchors_and_offsets_preset(PRESET_TOP_LEFT)
	offset_left = 24.0
	offset_top = 24.0
	offset_right = 624.0
	mouse_filter = MOUSE_FILTER_IGNORE
	add_theme_constant_override("separation", 2)
	for r in ROWS:
		var l := Label.new()
		l.add_theme_font_override("font", FONT)
		l.mouse_filter = MOUSE_FILTER_IGNORE
		if r[1] == "": # a heading: the inventory's weight-line colour
			l.text = r[0]
			l.add_theme_font_size_override("font_size", 12)
			l.add_theme_color_override("font_color", Color(0.55, 0.5, 0.4))
		else:
			l.text = "%-9s %s" % [r[0], r[1]]
			l.add_theme_font_size_override("font_size", 14)
			l.add_theme_color_override("font_color", Color(0.92, 0.87, 0.74)) # parchment white
		add_child(l)
	var keys := Label.new()
	keys.text = "f1 close"
	keys.add_theme_font_override("font", FONT)
	keys.add_theme_font_size_override("font_size", 12)
	keys.add_theme_color_override("font_color", Color(0.45, 0.41, 0.33)) # the hint line
	add_child(keys)

func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo and event.keycode == KEY_F1:
		visible = not visible
		if visible:
			get_tree().call_group("ui_panel", "close_unless", self)
		get_viewport().set_input_as_handled()

func close_unless(keep: Node) -> void:
	if keep != self:
		visible = false
