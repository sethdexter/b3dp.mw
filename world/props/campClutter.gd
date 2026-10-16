extends RefCounted
## Builds a random little set piece in the style of the start scene: a barrel (or crate) used as a table with
## bottles, a coin pile, a coin bag or a dagger on top; a crate or two beside it, sometimes stacked; staffs and
## the black sword leaning on whatever is there; odds and ends dropped on the floor nearby. Every pose below is copied from the start scene, then turned
## and shuffled, so each piece is different but placed the same way. Pivot = the ground under the anchor.

const M := "res://assets/models/%s.glb"
const FLOOR := 1.0 # barrels and crates are 2 m cubes pivoted at their centre

# Things on the table top: [model, basis from the start scene, height above the top]
const ON_TOP := [
	["bottle", Basis(Vector3(0.111769, 0, -0.165855), Vector3(0, 0.2, 0), Vector3(0.165855, 0, 0.111769)), 0.065],
	["bottle03", Basis(Vector3(-0.13092549, 0.000107854, 0.09529568), Vector3(-8.7091335e-05, 0.0557867, -0.00018279254), Vector3(-0.08827728, -0.000535214, -0.12128269)), 0.0],
	["coinbag2", Basis(Vector3(0.028650977, 0.017739711, 0.24771845), Vector3(-0.022022203, 0.24856077, -0.015252958), Vector3(-0.24737474, -0.020073168, 0.030048788)), 0.098],
	["irondagger", Basis(Vector3(-0.455649, -9.2823e-10, 0.092785), Vector3(0.0927793, -0.00532231, 0.45562), Vector3(0.00106201, 0.46497, 0.00521528)), 0.023],
	["coins", Basis(Vector3(-0.319645, 0, -0.344569), Vector3(0, 0.47, 0), Vector3(0.344569, 0, -0.319645)), 0.009],
]
# Coins around the first one in the pile (local to it).
const PILE := [Vector3(0.337323, 0, 0), Vector3(0, 0.0324893, -0.272817), Vector3(-0.450711, 0, 0.0553608),
	Vector3(-0.438352, 0, 0.392457), Vector3(-0.178091, 0.0642552, 0.0453749)]
# Things leaned on a barrel/crate: [model, basis, offset from its centre] (all from the start scene).
const LEANERS := [
	["staff", Basis(Vector3(0.6301687, 0.0321749, -0.09896937), Vector3(-0.05121735, 0.61299, -0.12683293), Vector3(0.11200976, 0.168242, 0.7678903)), Vector3(0.9604397, 1.2900901, -0.29005313)],
	["staff02", Basis(Vector3(0.49610108, 0, -0.46406472), Vector3(-0.07262584, 0.662107, -0.07763962), Vector3(0.47483796, 0.111609, 0.5076179)), Vector3(1.1223788, 1.57741, -0.49628377)],
	["blackswordLATER", Basis(Vector3(0.528547, 0.00128198, -0.848904), Vector3(-0.747938, 0.473702, -0.464969), Vector3(0.401531, 0.880685, 0.251333)), Vector3(-1.19966, -0.285473, -0.758733)],
]

## Defaults for the knobs; the Camps node passes its Clutter sliders in `opt` (any missing key uses these).
const DEFAULTS := {
	"barrel_chance": 0.7, # table is a barrel (else a crate)
	"top_min": 2, "top_max": 4, # things on the table
	"crates_max": 2, "stack_chance": 0.45, # crates beside it / chance each gets one on top
	"leaners_max": 2, # staffs / sword leaned on things
	"floor_max": 3, # odds and ends on the ground
}

static func build(rng: RandomNumberGenerator, opt: Dictionary = {}) -> Node3D:
	var o := DEFAULTS.merged(opt, true)
	var root := Node3D.new()
	var hosts: Array[Node3D] = [] # barrels and crates things can lean on
	var anchor := _model(root, "barrel" if rng.randf() < o.barrel_chance else "crate", Transform3D(Basis(Vector3.UP, rng.randf() * TAU), Vector3.UP * FLOOR))
	hosts.append(anchor)
	# The table top: a few things, each in its own slice of the top so they don't overlap.
	var picks := _shuffled(range(ON_TOP.size()), rng)
	var a0 := rng.randf() * TAU
	var n := mini(rng.randi_range(o.top_min, maxi(o.top_min, o.top_max)), ON_TOP.size())
	for k in n:
		var it: Array = ON_TOP[picks[k]]
		var a := a0 + TAU * k / n
		var at: Vector3 = Vector3(cos(a), 0, sin(a)) * rng.randf_range(0.15, 0.45) + Vector3.UP * (FLOOR * 2.0 + it[2])
		var node := _model(root, "goldcoin" if it[0] == "coins" else it[0], Transform3D(Basis(Vector3.UP, rng.randf() * TAU) * it[1], at))
		node.set_meta("on", anchor)
		if it[0] == "coins":
			for p: Vector3 in PILE.slice(0, rng.randi_range(2, PILE.size())):
				_model(node, "goldcoin", Transform3D(Basis(Vector3.UP, rng.randf() * TAU), p))
	# Crates beside it, about where the start scene has them; sometimes one stacked on top. A spot that would
	# push into the barrel or another crate is re-rolled.
	for k in rng.randi_range(0, o.crates_max):
		for attempt in 8:
			var a := rng.randf() * TAU
			var x := Transform3D(Basis(Vector3.UP, rng.randf() * TAU), Vector3(cos(a), 0, sin(a)) * rng.randf_range(2.1, 2.6) + Vector3.UP * FLOOR)
			if not _clear("crate", x, hosts, []):
				continue
			var crate := _model(root, "crate", x)
			hosts.append(crate)
			var up := Transform3D(Basis(Vector3.UP, rng.randf_range(-0.3, 0.3)) * x.basis, x.origin + Vector3(rng.randf_range(-0.1, 0.1), 2.0, rng.randf_range(-0.1, 0.1)))
			if rng.randf() < o.stack_chance and _clear("crate", up, hosts.filter(func(h): return h != crate), []):
				var top := _model(root, "crate", up)
				top.set_meta("on", crate)
				hosts.append(top)
			break
	# Leaners: each takes the start scene's pose against a random host, turned to a random side of it. A pose
	# that would pass through any barrel, crate or other leaner is re-rolled; after 12 misses that one is left out.
	var placed: Array = [] # [model, transform] of leaners so far
	var leaners := _shuffled(LEANERS, rng)
	for k in mini(rng.randi_range(0, o.leaners_max), leaners.size()):
		var it: Array = leaners[k]
		for attempt in 12:
			var host: Node3D = hosts[rng.randi() % hosts.size()]
			if host.position.y > FLOOR + 1.0:
				continue # not against a stacked crate: it'd float
			var turn := Basis(Vector3.UP, rng.randf() * TAU)
			var x := Transform3D(turn * it[1], Vector3(host.position.x, 0.0, host.position.z) + turn * it[2] + Vector3.UP * FLOOR)
			if _clear(it[0], x, hosts, placed):
				_model(root, it[0], x).set_meta("on", host)
				placed.append([it[0], x])
				break
	# Odds and ends dropped on the floor around the barrels and crates (same poses as on the table, at ground level).
	for k in rng.randi_range(0, o.floor_max):
		var it: Array = ON_TOP[rng.randi() % ON_TOP.size()]
		var model: String = "goldcoin" if it[0] == "coins" else it[0]
		for attempt in 8:
			var host: Node3D = hosts[rng.randi() % hosts.size()]
			if host.position.y > FLOOR + 1.0:
				continue
			var a := rng.randf() * TAU
			var at: Vector3 = Vector3(host.position.x, 0.0, host.position.z) + Vector3(cos(a), 0, sin(a)) * rng.randf_range(1.3, 1.9) + Vector3.UP * it[2]
			var x := Transform3D(Basis(Vector3.UP, rng.randf() * TAU) * it[1], at)
			if _clear(model, x, hosts, placed):
				var node := _model(root, model, x)
				node.set_meta("on", host)
				placed.append([model, x])
				if it[0] == "coins":
					for p: Vector3 in PILE.slice(0, rng.randi_range(1, 3)):
						_model(node, "goldcoin", Transform3D(Basis(Vector3.UP, rng.randf() * TAU), p))
				break
	# Hang everything off what it rests on, so when the camp settles each barrel/crate onto the real ground
	# (tilting with the slope) its load comes with it. Only ground-level barrels/crates carry things, and they
	# stay put here, so their transforms are still in this piece's space.
	for item: Node3D in root.get_children():
		if item.has_meta("on"):
			var under: Node3D = item.get_meta("on")
			item.transform = under.transform.affine_inverse() * item.transform
			root.remove_child(item)
			under.add_child(item)
	return root

## True if `model` at `x` doesn't pass into any barrel/crate in `hosts` (and they don't pass into it, if it's a
## crate), and keeps a little gap from the leaners in `others`. Tested with a sample of each mesh's vertices.
static func _clear(model: String, x: Transform3D, hosts: Array, others: Array) -> bool:
	var pts := _points(model)
	for h: Node3D in hosts:
		var to_h := h.transform.affine_inverse() * x
		for p in pts:
			if _inside(to_h * p, h.scene_file_path.contains("barrel")):
				return false
		if model == "crate" or model == "barrel":
			var to_me := x.affine_inverse() * h.transform
			for p in _points("barrel" if h.scene_file_path.contains("barrel") else "crate"):
				if _inside(to_me * p, model == "barrel"):
					return false
	for o: Array in others:
		for p in pts:
			var wp := x * p
			for q in _points(o[0]):
				if wp.distance_squared_to(o[1] * q) < 0.01: # within 10 cm
					return false
	return true

## Point (in a barrel's / crate's own space: 2 m, centred) is inside it, with a hair of slack for touching.
static func _inside(p: Vector3, barrel: bool) -> bool:
	if absf(p.y) > 0.97:
		return false
	return Vector2(p.x, p.z).length() < 0.92 if barrel else (absf(p.x) < 0.97 and absf(p.z) < 0.97)

static var _pts := {} # model -> sample of its mesh vertices in model space
static func _points(model: String) -> PackedVector3Array:
	if not _pts.has(model):
		var n: Node3D = load(M % model).instantiate()
		var out := PackedVector3Array()
		for m: MeshInstance3D in n.find_children("*", "MeshInstance3D", true, false):
			var t := Transform3D.IDENTITY
			var at: Node = m
			while at != n:
				t = (at as Node3D).transform * t
				at = at.get_parent()
			for sfc in m.mesh.get_surface_count():
				var v: PackedVector3Array = m.mesh.surface_get_arrays(sfc)[Mesh.ARRAY_VERTEX]
				for i in range(0, v.size(), maxi(1, v.size() / 120)):
					out.append(t * v[i])
		n.free()
		_pts[model] = out
	return _pts[model]

## Seeded shuffle, so a camp's set piece is the same every visit.
static func _shuffled(arr: Array, rng: RandomNumberGenerator) -> Array:
	var out := arr.duplicate()
	for i in range(out.size() - 1, 0, -1):
		var j := rng.randi_range(0, i)
		var t = out[i]
		out[i] = out[j]
		out[j] = t
	return out

static func _model(parent: Node3D, model: String, xform: Transform3D) -> Node3D:
	var n: Node3D = load(M % model).instantiate()
	n.transform = xform
	n.name = model
	parent.add_child(n)
	return n
