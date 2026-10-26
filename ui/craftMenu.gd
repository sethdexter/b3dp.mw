extends VBoxContainer
## C: what you can make (items/crafting.gd), laid out like the inventory's lists (a chest's side: bottom left):
## parchment rows with the pick highlighted, what it needs below, the keys under that. Wheel (or Up / Down) picks,
## LMB makes it. Some need a tool in your pack or the light of a fire.

const Crafting := preload("res://items/crafting.gd")
const FONT := preload("res://assets/fonts/MononokiNerdFont-Regular.ttf")
const ROW := Color(0.92, 0.87, 0.74) # the inventory's parchment white
const PICKED := Color(1.0, 0.95, 0.6)
const SHORT := Color(0.55, 0.5, 0.42) # can't make it yet
var _ids: Array = Crafting.RECIPES.keys()
var _pick := 0
var _rows := VBoxContainer.new()
var _details := Label.new()
var _keys := Label.new()
var _hi := StyleBoxFlat.new()
var _none := StyleBoxEmpty.new()

func _ready() -> void:
	visible = false
	add_to_group("ui_panel")
	set_anchors_and_offsets_preset(PRESET_BOTTOM_LEFT) # where a chest's list sits
	offset_left = 24.0
	offset_right = 424.0
	offset_top = -624.0
	offset_bottom = -24.0
	grow_vertical = GROW_DIRECTION_BEGIN
	alignment = BoxContainer.ALIGNMENT_END
	mouse_filter = MOUSE_FILTER_IGNORE
	add_theme_constant_override("separation", 6)
	_rows.add_theme_constant_override("separation", 2)
	_rows.mouse_filter = MOUSE_FILTER_IGNORE
	add_child(_rows)
	for l: Label in [_details, _keys]:
		l.add_theme_font_override("font", FONT)
		l.mouse_filter = MOUSE_FILTER_IGNORE
		l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		l.custom_minimum_size = Vector2(280, 0)
		add_child(l)
	_details.add_theme_font_size_override("font_size", 13)
	_details.add_theme_color_override("font_color", Color(0.7, 0.7, 0.7))
	_keys.add_theme_font_size_override("font_size", 12)
	_keys.add_theme_color_override("font_color", Color(0.45, 0.41, 0.33)) # the inventory's hint line
	_keys.text = "wheel pick  lmb make  c close"
	for s: StyleBox in [_hi, _none]:
		s.content_margin_left = 3
		s.content_margin_right = 3
	_hi.bg_color = Color(0.55, 0.45, 0.3, 0.45)

func close_unless(keep: Node) -> void:
	if keep != self:
		visible = false

## A chest, a trader or your pack opened: it takes this side of the screen, so the list closes.
func _process(_delta: float) -> void:
	if visible:
		var p := _player()
		for c in (p.get_children() if p else []):
			if c is PlayerInventoryUI and c.is_open:
				visible = false

func _player() -> Node:
	return get_tree().get_first_node_in_group("player")

func _input(event: InputEvent) -> void: # (before the rest: LMB makes things here, not a swing)
	if event is InputEventKey and event.pressed and not event.echo and event.keycode == KEY_C:
		visible = not visible
		if visible:
			get_tree().call_group("ui_panel", "close_unless", self)
		_show()
		get_viewport().set_input_as_handled()
		return
	if not visible:
		return
	var step := 0
	if event is InputEventKey and event.pressed:
		if event.keycode == KEY_UP: step = -1
		elif event.keycode == KEY_DOWN: step = 1
	elif event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT: # make it (and no swing)
		_make()
		get_viewport().set_input_as_handled()
		return
	elif event is InputEventMouseButton and event.pressed and event.button_index in [MOUSE_BUTTON_WHEEL_UP, MOUSE_BUTTON_WHEEL_DOWN]:
		step = -1 if event.button_index == MOUSE_BUTTON_WHEEL_UP else 1
	if step != 0:
		_pick = posmod(_pick + step, _ids.size())
		_show()
		get_viewport().set_input_as_handled()

func _state() -> Array:
	var p := _player()
	var inv: InventoryComponent = p.get("inventoryComponent") if p else null
	if not inv:
		return []
	var dk = p.get_node_or_null("darkness")
	var st := Crafting.stock_of(inv)
	return [inv, st[0], st[1], dk != null and dk._at_fire()]

func _make() -> void:
	var s := _state()
	if s.is_empty():
		return
	var id: String = _ids[_pick]
	var short: String = Crafting.missing(id, s[1], s[2], s[3])
	if short != "":
		Talker.notify("You need %s." % short)
		return
	Crafting.make(id, s[0], get_node("/root/item_list"))
	Talker.notify("You make %s." % id.replace("_", " "))
	_show()

func _show() -> void:
	var s := _state()
	if s.is_empty() or not visible:
		return
	for c in _rows.get_children():
		c.queue_free()
	for i in _ids.size():
		var id: String = _ids[i]
		var r: Dictionary = Crafting.RECIPES[id]
		var n: int = r.makes.values()[0]
		var row := Label.new()
		row.text = id.replace("_", " ").capitalize() + ("  x%d" % n if n > 1 else "")
		row.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN # highlight only as wide as the text
		row.mouse_filter = MOUSE_FILTER_IGNORE
		row.add_theme_font_override("font", FONT)
		row.add_theme_font_size_override("font_size", 14)
		var can: bool = Crafting.missing(id, s[1], s[2], s[3]) == ""
		row.add_theme_color_override("font_color", PICKED if i == _pick else (ROW if can else SHORT))
		row.add_theme_stylebox_override("normal", _hi if i == _pick else _none)
		_rows.add_child(row)
	var id: String = _ids[_pick]
	var r: Dictionary = Crafting.RECIPES[id]
	var needs := ", ".join(r.needs.keys().map(func(k): return "%d %s" % [r.needs[k], k.replace("_", " ")]))
	var short: String = Crafting.missing(id, s[1], s[2], s[3])
	_details.text = "Needs %s%s%s" % [needs, (", and a " + r.tool) if r.tool != "" else "", ", at a fire" if r.at == "fire" else ""]
	if short != "":
		_details.text += "\nShort of %s" % short
