extends Control
## Debug overlay (press M): the whole island from above with every camp and person in the Camps simulation.
## Fires: orange = drifter camp, red = bandit, green = goblin, purple = orc, hollow ring = empty. Dots match
## (drifters yellow),
## white ring = a real character near you. Blue lines = roaming bands heading for their next waypoint,
## red lines = raids. Encounters: grey square = remains (hollow once looted), white star = cairn torch;
## lone wanderers and goblin packs show as their dots only. Grey x = hanged / a body, hollow orange = cold fire,
## blue = bell shrine. White arrow = you.

var camps: Node # the Camps node
var _bg: ImageTexture
const RES := 256 # heightmap pixels across

func _ready() -> void:
	visible = false
	set_anchors_and_offsets_preset(PRESET_FULL_RECT)
	mouse_filter = MOUSE_FILTER_IGNORE

func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo and event.keycode == KEY_M:
		visible = not visible
		if visible and not _bg:
			_bg = ImageTexture.create_from_image(_island())

func _process(_delta: float) -> void:
	if visible and Engine.get_process_frames() % 6 == 0:
		queue_redraw() # ~10 times a second is plenty to watch it move

func _island() -> Image:
	var img := Image.create(RES, RES, false, Image.FORMAT_RGB8)
	var data: Terrain3DData = camps.terrain.data
	for y in RES:
		for x in RES:
			var h := data.get_height(_world(Vector2(x + 0.5, y + 0.5) / RES))
			if is_nan(h) or h < camps.SEA_LEVEL:
				img.set_pixel(x, y, Color(0.08, 0.12, 0.2))
			else:
				var t := clampf(h / 250.0, 0.0, 1.0)
				img.set_pixel(x, y, Color(0.22, 0.2, 0.14).lerp(Color(0.75, 0.72, 0.66), t))
	return img

# 0..1 map coords <-> world
func _world(uv: Vector2) -> Vector3:
	return Vector3((uv.x - 0.5) * camps.HALF_MAP * 2.0, 0, (uv.y - 0.5) * camps.HALF_MAP * 2.0)

func _draw() -> void:
	if not camps or not _bg:
		return
	var side := minf(size.x, size.y) * 0.9
	var rect := Rect2((size - Vector2(side, side)) * 0.5, Vector2(side, side))
	var to_map := func(p: Vector3) -> Vector2:
		return rect.position + (Vector2(p.x, p.z) / (camps.HALF_MAP * 2.0) + Vector2(0.5, 0.5)) * side
	draw_texture_rect(_bg, rect, false, Color(1, 1, 1, 0.9))
	for c in camps.camps:
		if c.wild == "remains":
			var r := Rect2(to_map.call(c.pos) - Vector2(3, 3), Vector2(6, 6))
			if c.looted:
				draw_rect(r, Color(0.7, 0.7, 0.7), false, 1.0)
			else:
				draw_rect(r, Color(0.7, 0.7, 0.7), true)
			continue
		if c.wild == "cairn" or c.wild == "falselight":
			draw_circle(to_map.call(c.pos), 2.5, Color.WHITE) # a false light looks just like a cairn, even here
			continue
		if c.wild == "hanged" or c.wild == "starved_dead":
			var hp: Vector2 = to_map.call(c.pos)
			draw_line(hp - Vector2(3, 3), hp + Vector2(3, 3), Color(0.7, 0.7, 0.7), 1.5)
			draw_line(hp - Vector2(3, -3), hp + Vector2(3, -3), Color(0.7, 0.7, 0.7), 1.5)
			continue
		if c.wild == "coldfire":
			draw_arc(to_map.call(c.pos), 4.0, 0, TAU, 10, Color(1.0, 0.55, 0.1), 1.5)
			continue
		if c.wild == "bell":
			draw_circle(to_map.call(c.pos), 4.0, Color(0.4, 0.7, 1.0))
			continue
		if c.wild == "spring":
			draw_circle(to_map.call(c.pos), 2.5, Color(0.2, 0.9, 0.9))
			continue
		if c.wild == "fungus":
			draw_circle(to_map.call(c.pos), 2.5, Color(0.55, 0.75, 0.35))
			continue
		if c.wild != "" and not c.roaming:
			continue # an ambush: just its red dots
		if c.roaming and c.wild != "":
			continue
		if c.roaming:
			for f in c.members:
				if not f.dead: # blue = drifters on the move, red = a bandit war band
					draw_line(to_map.call(f.pos), to_map.call(c.raid.pos if c.raid else c.pos), Color(1, 0.2, 0.1, 0.8) if c.bandit else Color(0.4, 0.6, 1.0, 0.7))
					break
			continue
		var alive: int = c.members.filter(func(f): return not f.dead).size()
		if alive == 0:
			draw_arc(to_map.call(c.pos), 5.0, 0, TAU, 12, Color(0.85, 0.85, 0.85), 1.5) # abandoned fire
		else:
			draw_circle(to_map.call(c.pos), 5.0, camps.KIND_COLORS[c.kind])
		if c.raid:
			draw_line(to_map.call(c.pos), to_map.call(c.raid.pos), Color(1, 0.2, 0.1, 0.8), 2.0)
	for f in camps.folk:
		if f.dead:
			continue
		var p: Vector2 = to_map.call(f.pos)
		draw_circle(p, 2.0, Color(1.0, 0.9, 0.3) if f.camp.kind == "drifter" else camps.KIND_COLORS[f.camp.kind])
		if f.node:
			draw_arc(p, 4.0, 0, TAU, 8, Color.WHITE, 1.0)
	if is_instance_valid(camps._player):
		var p: Vector2 = to_map.call(camps._player.global_position)
		var fwd: Vector3 = -camps._player.global_transform.basis.z
		var d := Vector2(fwd.x, fwd.z).normalized() * 9.0
		draw_colored_polygon([p + d, p - d * 0.5 + d.orthogonal() * 0.5, p - d * 0.5 - d.orthogonal() * 0.5], Color.WHITE)
	var alive_folk: int = camps.folk.filter(func(f): return not f.dead).size()
	draw_string(get_theme_default_font(), rect.position + Vector2(8, 20),
		"%d camps   %d people alive   %d bands roaming   %d raids" % [
			camps.camps.filter(func(c): return not c.roaming and c.wild == "").size(), alive_folk,
			camps.camps.filter(func(c): return c.roaming).size(), camps.camps.filter(func(c): return c.raid != null).size()],
		HORIZONTAL_ALIGNMENT_LEFT, -1, 14, Color.WHITE)
	_draw_key(Vector2(rect.end.x + 12, rect.position.y + 10))
	var meet = camps.get_node_or_null("meetings")
	if meet: # what's been happening between the groups, newest at the bottom
		for i in meet.log_lines.size():
			draw_string(get_theme_default_font(), rect.position + Vector2(8, rect.size.y - 12 - (meet.log_lines.size() - 1 - i) * 16),
				meet.log_lines[i], HORIZONTAL_ALIGNMENT_LEFT, -1, 12, Color(0.95, 0.85, 0.7))

## The key, down the right of the map: each symbol drawn as it appears, with what it means.
func _draw_key(at: Vector2) -> void:
	var font := get_theme_default_font()
	var k: Dictionary = camps.KIND_COLORS
	var rows := [
		["dot", k.drifter, "Drifter camp"], ["dot", k.bandit, "Bandit camp"], ["dot", k.goblin, "Goblin camp"],
		["dot", k.orc, "Orc camp"], ["ring", Color(0.85, 0.85, 0.85), "Abandoned camp"],
		["ring", Color(1.0, 0.55, 0.1), "Cold fire"], ["small", Color(1.0, 0.9, 0.3), "Drifter"],
		["small", k.bandit, "Bandit"], ["small", k.goblin, "Goblin"], ["small", k.orc, "Orc"],
		["near", Color.WHITE, "Near you (real)"], ["line", Color(0.4, 0.6, 1.0), "Drifters on the move"],
		["line", Color(1, 0.2, 0.1), "War band / raid"], ["square", Color(0.7, 0.7, 0.7), "Remains (hollow: looted)"],
		["x", Color(0.7, 0.7, 0.7), "Hanged / a body"], ["tiny", Color.WHITE, "Cairn torch (or is it?)"],
		["dot", Color(0.4, 0.7, 1.0), "Bell shrine"], ["tiny", Color(0.2, 0.9, 0.9), "Spring (water)"],
		["tiny", Color(0.55, 0.75, 0.35), "Ash fungus (food)"], ["arrow", Color.WHITE, "You"],
	]
	draw_rect(Rect2(at - Vector2(6, 6), Vector2(200, rows.size() * 18 + 8)), Color(0, 0, 0, 0.55))
	for i in rows.size():
		var r: Array = rows[i]
		var p := at + Vector2(8, i * 18 + 6)
		var col: Color = r[1]
		match r[0]:
			"dot": draw_circle(p, 5.0, col)
			"ring": draw_arc(p, 5.0, 0, TAU, 12, col, 1.5)
			"small": draw_circle(p, 2.0, col)
			"tiny": draw_circle(p, 2.5, col)
			"near":
				draw_circle(p, 2.0, Color(1.0, 0.9, 0.3))
				draw_arc(p, 4.0, 0, TAU, 8, col, 1.0)
			"line": draw_line(p - Vector2(7, 0), p + Vector2(7, 0), col, 2.0)
			"square": draw_rect(Rect2(p - Vector2(3, 3), Vector2(6, 6)), col, true)
			"x":
				draw_line(p - Vector2(3, 3), p + Vector2(3, 3), col, 1.5)
				draw_line(p - Vector2(3, -3), p + Vector2(3, -3), col, 1.5)
			"arrow": draw_colored_polygon([p + Vector2(6, 0), p + Vector2(-3, 4), p + Vector2(-3, -4)], col)
		draw_string(font, p + Vector2(14, 5), r[2], HORIZONTAL_ALIGNMENT_LEFT, -1, 12, Color(0.9, 0.9, 0.9))
