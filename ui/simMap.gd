extends Control
## Debug overlay (press M): the whole island from above with every camp and person in the Camps simulation.
## Fires: orange = drifter camp, red = bandit, green = goblin, purple = orc, hollow ring = empty. Dots match
## (drifters yellow),
## white ring = a real character near you. Blue lines = roaming bands heading for their next waypoint,
## red lines = raids. Encounters: grey square = remains (hollow once looted), white star = cairn torch;
## lone wanderers and goblin packs show as their dots only. Grey x = hanged / a body, hollow orange = cold fire,
## blue = bell shrine. White arrow = you.
## N / Shift+N = watch the next / previous person (every living non-bandit human) (yellow capsule when they're too far off to have a body);
## mouse orbits round them, wheel zooms, B = back to you. Everything within 300 m of them is marked in the key's
## colours: people too far from you to have a body as capsules, camps / springs / fungus / cairns... as posts.

var camps: Node # the Camps node
var _bg: ImageTexture
const RES := 256 # heightmap pixels across

func _ready() -> void:
	visible = false
	set_anchors_and_offsets_preset(PRESET_FULL_RECT)
	mouse_filter = MOUSE_FILTER_IGNORE

func _unhandled_input(event: InputEvent) -> void:
	if not (event is InputEventKey and event.pressed and not event.echo):
		return
	if event.keycode == KEY_M:
		visible = not visible
		if visible and not _bg:
			_bg = ImageTexture.create_from_image(_island())
	elif event.keycode == KEY_N: # watch the next wanderer from above
		var all: Array = camps.folk.filter(func(f): return not f.dead and f.camp.kind == "drifter") # every living human who isn't a bandit
		if all.is_empty():
			return
		_watch = all[posmod(all.find(_watch) + (-1 if event.shift_pressed else 1), all.size())] # Shift+N = back one
		# the map stays up if it was open: you can keep cycling with it showing
		if not _cam:
			_cam = Camera3D.new()
			_cam.far = 2000.0
			# brighter ambient for this camera's view only: no lights are added, so nothing in the game sees it
			var we := get_tree().current_scene.find_child("WorldEnvironment", true, false) as WorldEnvironment
			if we and we.environment:
				_cam.environment = we.environment.duplicate()
				_cam.environment.ambient_light_energy = WATCH_AMBIENT
			_marker = MeshInstance3D.new()
			var m := CapsuleMesh.new()
			m.radius = 0.4
			m.height = 1.8
			var mat := StandardMaterial3D.new()
			mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
			mat.albedo_color = Color(1.0, 0.9, 0.3)
			m.material = mat
			_marker.mesh = m
			camps.add_child(_cam)
			camps.add_child(_marker)
		if not _cam.current:
			_prev = get_viewport().get_camera_3d()
		_cam.top_level = true
		_marker.top_level = true
		_cam.current = true
		_marker.visible = true
	elif event.keycode == KEY_B and _watch: # back to you
		_stop_watching()

# While watching, the mouse orbits the camera round them (wheel zooms) instead of turning you.
func _input(event: InputEvent) -> void:
	if not _watch:
		return
	if event is InputEventMouseMotion:
		_yaw -= event.relative.x * 0.005
		_pitch = clampf(_pitch - event.relative.y * 0.005, -1.45, -0.05)
		get_viewport().set_input_as_handled()
	elif event is InputEventMouseButton and event.pressed and event.button_index in [MOUSE_BUTTON_WHEEL_UP, MOUSE_BUTTON_WHEEL_DOWN]:
		_zoom = clampf(_zoom * (0.9 if event.button_index == MOUSE_BUTTON_WHEEL_UP else 1.1), 3.0, 120.0)
		get_viewport().set_input_as_handled()

const WATCH_AMBIENT := 0.5 # the level's is 0.02
var _yaw := 0.0
var _pitch := -1.05 # radians below level
var _zoom := 16.0 # metres from them
var _focus := Vector3.INF # smoothed point the camera circles

var _watch # the Folk being watched, or null
var _cam: Camera3D
var _prev: Camera3D # your camera, to go back to
var _marker: MeshInstance3D # stands in for them when they're too far away to have a body

## While the map or the watch camera is up you can't die: health is locked and hunger / thirst stay full.
func _protect_player() -> void:
	var p = camps._player
	if not is_instance_valid(p):
		return
	var on: bool = visible or _watch != null
	var stats = p.get("statComponent")
	if stats and stats.health:
		stats.health.locked = on or SimClock.speed > 1 # fast-forward keeps its own lock
		if on:
			stats.health.change_current(stats.health.get_max_value())
	var needs = p.get_node_or_null("needs")
	if on and needs:
		needs.hunger = 100.0
		needs.thirst = 100.0

func _process(delta: float) -> void:
	_protect_player()
	if visible and Engine.get_process_frames() % 6 == 0:
		queue_redraw() # ~10 times a second is plenty to watch it move
	if _watch:
		var p: Vector3 = _watch.node.global_position if is_instance_valid(_watch.node) else _watch.pos
		var h: float = camps.terrain.data.get_height(p)
		if not is_nan(h):
			p.y = h
		_marker.visible = not is_instance_valid(_watch.node)
		_around_t -= delta
		if _around_t <= 0.0:
			_around_t = 0.25
			_show_around(p)
		_marker.global_position = p + Vector3(0, 0.9, 0)
		var target := p + Vector3(0, 1, 0)
		_focus = target if _focus.distance_to(target) > 50.0 else _focus.lerp(target, minf(1.0, delta * 3.0)) # jump to a new person, glide after the same one
		_cam.global_position = _focus + Basis.from_euler(Vector3(_pitch, _yaw, 0)) * Vector3(0, 0, _zoom)
		_cam.look_at(_focus)
		if not _info:
			_info = Label.new()
			_info.position = Vector2(16, 16)
			_info.add_theme_font_size_override("font_size", 14)
			_info.add_theme_constant_override("outline_size", 4)
			get_parent().add_child(_info)
		_info.visible = true
		_info.text = _describe(_watch)
		if not _world_log:
			_world_log = Label.new()
			_world_log.add_theme_font_size_override("font_size", 12)
			_world_log.add_theme_constant_override("outline_size", 4)
			_world_log.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
			_world_log.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART # long lines wrap instead of running off the left
			get_parent().add_child(_world_log)
		_world_log.visible = true
		_world_log.position = Vector2(get_viewport_rect().size.x - 520, 16)
		_world_log.size = Vector2(504, 0)
		var w := "Across the island:\n"
		for i in range(camps.world_log.size() - 1, maxi(-1, camps.world_log.size() - 25), -1):
			var e: Dictionary = camps.world_log[i]
			w += "%s %s  (%.0fs)\n" % [e.who, e.text, SimClock.now - e.t]
		_world_log.text = w
		if _watch.dead:
			_stop_watching()

var _info: Label # the watched person's action and stats, down the left
var _world_log: Label # what everyone's been up to lately, down the right

func _describe(f) -> String:
	var c = f.camp
	var s := "%s\n%s\n\nDoing: %s\n" % [f.name if f.name != "" else "(unnamed)",
		"has a body (near you)" if is_instance_valid(f.node) else "sim only (no body: too far from you)", _doing(f)]
	s += "\nNeeds:\n"
	for k in f.needs:
		s += "  %s %.0f\n" % [k, f.needs[k]]
	s += "\nTraits:\n"
	for k in f.traits:
		s += "  %s %.2f\n" % [k, f.traits[k]]
	if not f.memories.is_empty():
		s += "\nRemembers:\n"
		for m in f.memories:
			s += "  %s\n" % m.what
	if not f.job.is_empty():
		s += "\nJob: %s\n" % str(f.job)
	if not f.inv.is_empty():
		s += "\nCarrying: %s\n" % ", ".join(f.inv.keys().map(func(k): return "%s x%d" % [k, f.inv[k]]))
	if not f.history.is_empty():
		s += "\nLately:\n"
		for i in range(f.history.size() - 1, maxi(-1, f.history.size() - 9), -1):
			s += "  %4.0fs ago  %s\n" % [SimClock.now - f.history[i].t, f.history[i].text]
	if c.wild == "" and c.stocked:
		s += "\nCamp barrel: %d water skins   crate: %s\n" % [c.barrel.get("water_skin", 0), ", ".join(c.crate.keys().map(func(k): return "%s x%d" % [k, c.crate[k]]))]
	return s

## A sentence or two on what someone's up to right now, and why.
func _doing(f) -> String:
	var c = f.camp
	var now: float = SimClock.now
	var life = camps.get_node_or_null("camplife")
	var dir := func(to: Vector3) -> String:
		return "%.0f m %s" % [camps._dist(f.pos, to), Talker._compass(to - f.pos)]
	# chores
	if not f.task.is_empty():
		var t: Dictionary = f.task
		var carrying: String = life._pack_text(f.inv) if life and not f.inv.is_empty() else "nothing"
		match [t.type, t.phase]:
			["water", "out"]:
				return "Walking to a spring %s to fill water skins: the camp barrel's running low." % dir.call(t.to)
			["water", "work"]:
				return "Filling water skins at the spring (%.0f s more)." % maxf(0.0, t.until - now)
			["forage", "out"]:
				return "Walking %s to %s: the camp crate's running low." % [dir.call(t.to), "pick ash fungus" if t.get("spot") else "hunt in the dark"]
			["forage", "work"]:
				return "%s (%.0f s more)." % ["Picking ash fungus" if t.get("spot") else "Hunting", maxf(0.0, t.until - now)]
			["trade", "out"]:
				return "Walking %s with the camp's coin to buy %s from a neighbouring camp." % [dir.call(t.to), "water" if t.want == "water" else "food"]
			["supply", "out"]:
				return "Carrying food %s to a hungry camp: theirs has plenty to spare." % dir.call(t.to)
			["evacuate", "out"]:
				return "Leaving with the rest of the camp for a better-stocked fire %s: there was nothing left." % dir.call(t.to)
			[_, "back"]:
				return "Heading home %s with %s." % [dir.call(t.to), carrying]
	# what they are now
	if c.wild == "starved":
		if f.job.has("fed"):
			return "Back on their feet after being fed, about to set off."
		var cause: String = " from thirst" if f.needs.get("water", 100.0) <= 0.0 else (" with no light" if f.needs.get("light", 100.0) <= 0.0 else " from hunger")
		if f.hp < 100.0:
			return "Collapsed%s, health %.0f and going. Dies unless someone brings food or water." % [cause, f.hp]
		return "Slumped in the dark%s, begging anyone who passes for food." % cause
	if c.raid:
		return "Attacking a %s %s." % [c.raid.kind, dir.call(c.raid.pos)]
	if c.roaming:
		var j: Dictionary = c.job
		var torch := ""
		if j.has("fuel"):
			var spares := 0
			for o in camps._alive(c.members):
				spares += o.inv.get("torch", 0)
			torch = " Torch: %s, %d spare%s." % ["%.0f s left" % j.fuel if j.fuel >= 1.0 else "out", spares, "" if spares == 1 else "s"]
		var goal = j.get("goal")
		if goal:
			var why: String = {"spring": "low on water", "fungus": "low on food",
				"cairn": "torch nearly out, a cairn's light is the nearest fire"}.get(goal.wild, "needs a fire (torch, rest, maybe food)")
			var what: String = {"spring": "a spring", "fungus": "ash fungus", "cairn": "a cairn's light"}.get(goal.wild, "a %s fire" % goal.kind)
			return "Heading for %s %s: %s.%s" % [what, dir.call(goal.pos), why, torch]
		match c.wild:
			"wanderer":
				return ("Looking for a drifter fire to settle at." if c.job.get("settles", false) else "Wandering the dark.") + torch
			"pilgrims":
				return "Walking with the pilgrims toward the bell." + torch
			"stalker":
				return "Hunting you."
			"pack":
				return "Roaming the dark with the pack."
			"homeward":
				return "Heading home to their %s %s." % ["den" if c.kind in ["goblin", "orc"] else "fire", dir.call(c.pos)] + torch
			"lurer":
				return "Walking out into the dark %s, a torch in hand." % dir.call(c.pos)
		return "On the road." + torch
	match c.wild:
		"mourner":
			return "Kneeling at a grave. Won't speak; leave food and they might."
		"toll":
			return "Waiting on the road for travellers to pay the toll."
		"ambush":
			return "Lying in wait in the dark."
		"falselight":
			return "Holding up a torch in the dark, waiting for something to come to the light."
	if c.wild == "":
		var at_fire: bool = camps._dist(f.pos, c.pos) < 30.0
		var n: int = camps._alive(c.members).size()
		var low := []
		if c.stocked and life:
			if c.barrel.get("water_skin", 0) < life.water_low * n:
				low.append("water")
			if life.count_food(c.crate) < life.food_low * n:
				low.append("food")
		var mood := (" The camp is short of %s." % " and ".join(low)) if not low.is_empty() else ""
		return ("Resting by the %s fire with %d other%s." % [c.kind, n - 1, "" if n == 2 else "s"] if at_fire else "Near the %s camp." % c.kind) + mood
	return "%s %s." % [c.kind, c.wild]

## Everything near the person being watched, as markers coloured like the map key: other people who are too
## far from you to have a body (capsules), and camps, fires, springs, fungus, cairns, remains, bells... (posts).
const AROUND := 300.0 # metres
const HERD := Color(0.65, 0.45, 0.25)
## How long the red pulse lasts when something goes into the island log (real seconds).
const PULSE_SECONDS := 2.5
var _around: Array[Node3D] = []
var _around_t := 0.0

func _spot_color(c) -> Color:
	match c.wild:
		"": return Color(0.85, 0.85, 0.85) if camps._alive(c.members).is_empty() else camps.KIND_COLORS[c.kind]
		"coldfire": return Color(1.0, 0.55, 0.1)
		"spring": return Color(0.2, 0.9, 0.9)
		"fungus": return Color(0.55, 0.75, 0.35)
		"salt": return Color(0.95, 0.92, 0.85)
		"cairn", "falselight": return Color.WHITE
		"remains": return Color(0.7, 0.7, 0.7)
		"hanged", "starved_dead": return Color(0.7, 0.7, 0.7)
		"bell": return Color(0.4, 0.7, 1.0)
		"herd": return HERD
	return Color(0, 0, 0, 0) # people encounters show as their people

func _show_around(at: Vector3) -> void:
	var want: Array = [] # [position, colour, is_person, label]
	for c in camps.camps:
		if c.roaming or camps._dist(c.pos, at) > AROUND:
			continue
		var col := _spot_color(c)
		if col.a > 0.0:
			want.append([c.pos, col, false, ("%s camp" % c.kind) if c.wild == "" else c.wild.replace("_", " ").capitalize()])
	for f in camps.folk:
		if f.dead or f == _watch or is_instance_valid(f.node) or camps._dist(f.pos, at) > AROUND:
			continue # people near you have real bodies already
		want.append([f.pos, Color(1.0, 0.9, 0.3) if f.camp.kind == "drifter" else camps.KIND_COLORS[f.camp.kind], true, f.name])
	while _around.size() < want.size():
		var m := _make_marker()
		camps.add_child(m)
		_around.append(m)
	for i in _around.size():
		var m: Node3D = _around[i]
		m.visible = i < want.size()
		if not m.visible:
			continue
		var w: Array = want[i]
		var pos: Vector3 = w[0]
		var h: float = camps.terrain.data.get_height(pos)
		m.global_position = Vector3(pos.x, (h if not is_nan(h) else pos.y), pos.z)
		var person: bool = w[2]
		(m.get_child(0) as MeshInstance3D).visible = person
		(m.get_child(1) as MeshInstance3D).visible = not person
		for k in 2:
			((m.get_child(k) as MeshInstance3D).material_override as StandardMaterial3D).albedo_color = w[1]
		var label := m.get_child(2) as Label3D
		label.text = w[3]
		label.modulate = w[1]
		label.position.y = 2.6 if person else 7.0

## One reusable marker: a capsule (a person), a tall post (a place) and a label; only one shape shows at a time.
func _make_marker() -> Node3D:
	var root := Node3D.new()
	root.top_level = true
	var cap := CapsuleMesh.new()
	cap.radius = 0.4
	cap.height = 1.8
	var post := CylinderMesh.new()
	post.top_radius = 0.25
	post.bottom_radius = 0.25
	post.height = 6.0
	for k in 2:
		var mi := MeshInstance3D.new()
		mi.mesh = cap if k == 0 else post
		mi.position.y = 0.9 if k == 0 else 3.0
		var mat := StandardMaterial3D.new()
		mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		mi.material_override = mat
		root.add_child(mi)
	var label := Label3D.new()
	label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	label.fixed_size = true
	label.pixel_size = 0.0008
	label.outline_size = 6
	label.no_depth_test = true
	root.add_child(label)
	return root

func _stop_watching() -> void:
	for m in _around:
		m.visible = false
	_watch = null
	_marker.visible = false
	if _info:
		_info.visible = false
	if _world_log:
		_world_log.visible = false
	if is_instance_valid(_prev):
		_prev.current = true
	else:
		_cam.current = false

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
		if c.wild == "salt":
			draw_circle(to_map.call(c.pos), 2.0, Color(0.95, 0.92, 0.85))
			continue
		if c.wild == "herd": # bigger = more head
			draw_circle(to_map.call(c.pos), 1.0 + c.job.get("count", 0) * 0.25, HERD)
			continue
		if c.wild != "" and not c.roaming:
			continue # an ambush: just its red dots
		if c.roaming and c.wild != "":
			continue
		if c.roaming:
			for f in c.members:
				if not f.dead: # blue = drifters on the move, red = a bandit war band
					if not c.raid: # raids get their own arrows below
						draw_line(to_map.call(f.pos), to_map.call(c.pos), Color(1, 0.2, 0.1, 0.5) if c.bandit else Color(0.4, 0.6, 1.0, 0.7))
					break
			continue
		var alive: int = c.members.filter(func(f): return not f.dead).size()
		if alive == 0:
			draw_arc(to_map.call(c.pos), 5.0, 0, TAU, 12, Color(0.85, 0.85, 0.85), 1.5) # abandoned fire
		else:
			draw_circle(to_map.call(c.pos), 5.0, camps.KIND_COLORS[c.kind])
	for c in camps.camps: # who's attacking whom: an arrow from the attackers to their target
		if c.raid:
			_arrow(to_map.call(_lead(c)), to_map.call(_lead(c.raid)), Color(1, 0.2, 0.1, 0.9), 2.0)
	for f in camps.folk:
		if f.dead:
			continue
		var p: Vector2 = to_map.call(f.pos)
		draw_circle(p, 2.0, Color(1.0, 0.9, 0.3) if f.camp.kind == "drifter" else camps.KIND_COLORS[f.camp.kind])
		if f.node:
			draw_arc(p, 4.0, 0, TAU, 8, Color.WHITE, 1.0)
		if not f.task.is_empty(): # chores: green = foraging, cyan = fetching water, yellow = carrying food, orange = leaving
			var col: Color = {"forage": Color(0.5, 0.85, 0.3), "water": Color(0.2, 0.9, 0.9), "supply": Color(1.0, 0.9, 0.3), "evacuate": Color(1.0, 0.55, 0.1)}.get(f.task.type, Color.WHITE)
			_arrow(p, to_map.call(f.task.to), col, 1.0)
		if f == _watch:
			draw_arc(p, 8.0, 0, TAU, 16, Color(1, 0.15, 0.1), 2.0) # who the watch camera is on
	if is_instance_valid(camps._player):
		var p: Vector2 = to_map.call(camps._player.global_position)
		var fwd: Vector3 = -camps._player.global_transform.basis.z
		var d := Vector2(fwd.x, fwd.z).normalized() * 9.0
		draw_colored_polygon([p + d, p - d * 0.5 + d.orthogonal() * 0.5, p - d * 0.5 - d.orthogonal() * 0.5], Color.WHITE)
	var alive_folk: int = camps.folk.filter(func(f): return not f.dead).size()
	draw_string(get_theme_default_font(), rect.position + Vector2(8, 20),
		"%d camps   %d characters alive   %d bands roaming   %d raids" % [
			camps.camps.filter(func(c): return not c.roaming and c.wild == "").size(), alive_folk,
			camps.camps.filter(func(c): return c.roaming).size(), camps.camps.filter(func(c): return c.raid != null).size()],
		HORIZONTAL_ALIGNMENT_LEFT, -1, 14, Color.WHITE)
	# Something just went into the island log: a red pulse where it happened.
	var now_ms := Time.get_ticks_msec()
	var pulsing := false
	for e in camps.world_log:
		var age: float = (now_ms - e.get("ms", -100000)) / (PULSE_SECONDS * 1000.0)
		if age >= 0.0 and age < 1.0 and e.has("pos"):
			pulsing = true
			draw_arc(to_map.call(e.pos), lerpf(2.0, 16.0, age), 0, TAU, 16, Color(1, 0.1, 0.05, 1.0 - age), 2.0)
	if pulsing and Engine.get_process_frames() % 2 == 0:
		queue_redraw.call_deferred() # smooth while a pulse is going (otherwise the usual ~10 a second)
	_draw_key(Vector2(rect.end.x + 12, rect.position.y + 10))
	var meet = camps.get_node_or_null("meetings")
	var life = camps.get_node_or_null("camplife")
	var lines: Array[String] = []
	if meet:
		lines.append_array(meet.log_lines)
	if life:
		lines.append_array(life.log_lines)
	for i in lines.size(): # what's been happening between the groups, newest at the bottom
		draw_string(get_theme_default_font(), rect.position + Vector2(8, rect.size.y - 12 - (lines.size() - 1 - i) * 16),
			lines[i], HORIZONTAL_ALIGNMENT_LEFT, -1, 12, Color(0.95, 0.85, 0.7))

## Where a group's people actually are (a band's lead, a camp's fire).
func _lead(c) -> Vector3:
	if c.roaming:
		for f in c.members:
			if not f.dead:
				return f.pos
	return c.pos

## A line with an arrowhead at b.
func _arrow(a: Vector2, b: Vector2, col: Color, width: float) -> void:
	draw_line(a, b, col, width)
	var d := b - a
	if d.length() < 2.0:
		return
	d = d.normalized() * (6.0 + width * 2.0)
	draw_colored_polygon([b, b - d + d.orthogonal() * 0.5, b - d - d.orthogonal() * 0.5], col)

## The key, down the right of the map: each symbol drawn as it appears, with what it means.
func _draw_key(at: Vector2) -> void:
	var font := get_theme_default_font()
	var k: Dictionary = camps.KIND_COLORS
	var rows := [
		["dot", k.drifter, "Drifter camp"], ["dot", k.bandit, "Bandit camp"], ["dot", k.goblin, "Goblin camp"],
		["dot", k.orc, "Orc camp"], ["ring", Color(0.85, 0.85, 0.85), "Abandoned camp"],
		["ring", Color(1.0, 0.55, 0.1), "Cold fire"], ["small", Color(1.0, 0.9, 0.3), "Drifter"],
		["small", k.bandit, "Bandit"], ["small", k.goblin, "Goblin"], ["small", k.orc, "Orc"],
		["near", Color.WHITE, "Near you (real)"], ["ring", Color(1, 0.15, 0.1), "Watched (N)"], ["line", Color(0.4, 0.6, 1.0), "Drifters on the move"],
		["arrow_line", Color(1, 0.2, 0.1), "Attacking (arrow = target)"], ["arrow_line", Color(0.5, 0.85, 0.3), "Out foraging"],
		["arrow_line", Color(0.2, 0.9, 0.9), "Fetching water"], ["arrow_line", Color(1.0, 0.9, 0.3), "Carrying food to a camp"],
		["arrow_line", Color(1.0, 0.55, 0.1), "Leaving for another camp"], ["square", Color(0.7, 0.7, 0.7), "Remains (hollow: looted)"],
		["x", Color(0.7, 0.7, 0.7), "Hanged / a body"], ["tiny", Color.WHITE, "Cairn torch (or is it?)"],
		["dot", Color(0.4, 0.7, 1.0), "Bell shrine"], ["tiny", Color(0.2, 0.9, 0.9), "Spring (water)"],
		["tiny", Color(0.55, 0.75, 0.35), "Ash fungus (food)"], ["small", Color(0.95, 0.92, 0.85), "Salt crust"], ["tiny", HERD, "Game herd (size = head)"], ["ring", Color(1, 0.1, 0.05), "Just happened (log)"], ["arrow", Color.WHITE, "You"],
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
			"arrow_line": _arrow(p - Vector2(7, 0), p + Vector2(7, 0), col, 1.5)
			"square": draw_rect(Rect2(p - Vector2(3, 3), Vector2(6, 6)), col, true)
			"x":
				draw_line(p - Vector2(3, 3), p + Vector2(3, 3), col, 1.5)
				draw_line(p - Vector2(3, -3), p + Vector2(3, -3), col, 1.5)
			"arrow": draw_colored_polygon([p + Vector2(6, 0), p + Vector2(-3, 4), p + Vector2(-3, -4)], col)
		draw_string(font, p + Vector2(14, 5), r[2], HORIZONTAL_ALIGNMENT_LEFT, -1, 12, Color(0.9, 0.9, 0.9))
