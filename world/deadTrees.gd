@tool
extends Node3D
## Low poly dead trees: twisted trunk, forking bare branches, roots clawing into the ground.
## Builds a few random tree meshes on load (in the editor too) and scatters them over the island with MultiMeshes.
## In the editor, press Rebuild after changing settings.

@export_tool_button("Rebuild") var rebuild_button := _build
@export var terrain: Terrain3D
@export var tree_count := 6000
@export var variants := 6 # distinct tree meshes
@export var tree_seed := 3
@export var bark_color := Color(0.665, 0.341, 0.239, 1.0)
@export var view_distance := 1000.0 # chunks further than this aren't drawn (fog hides them)
## The same, but in the editor (lower = much faster editor viewport; the game uses view_distance).
@export var editor_view_distance := 300.0
@export var tree_scale := 1.0 # size multiplier (scaling the node itself does nothing; trees are placed in world space)
@export_group("Bark")
@export_range(0.0, 1.0) var tree_color_variance := 0.15 # how much each tree's tint differs from bark_color
@export_range(0.0, 0.5) var pixel_variance := 0.07 # random brightness noise per bark texel
@export_range(4, 128) var bark_resolution := 32 # bark texture width in pixels (height is twice this)

const SIDES := 6 # low poly: hexagonal branches
const CHUNK := 250.0 # metres per scatter chunk
const SEA_LEVEL := -10.0
const MAX_HEIGHT := 200.0 # no trees up on the mountains
const COLLIDE_CELL := 50.0 # metres per trunk lookup cell
const COLLIDE_RADIUS := 60.0 # trunks within this of the player get a collider
const COLLIDE_REFRESH := 10.0 # re-pick nearby trunks after the player moves this far

var _trunks := {} # Vector2i cell -> Array of Vector4(x, y, z, scale)
var _roots := {} # Vector2i cell -> Array of [Transform3D, variant], same order as _trunks
var _root_shapes: Array[Shape3D] = [] # per variant: trimesh of just the roots
var _body: StaticBody3D
var _root_body: StaticBody3D
var _collider_center := Vector3.INF
var _player: Node3D

func _ready() -> void:
	_build()

func _build() -> void:
	for child in get_children():
		child.queue_free()
	_trunks.clear()
	_roots.clear()
	_root_shapes.clear()
	_body = null
	_root_body = null
	_collider_center = Vector3.INF
	if not terrain or not terrain.data:
		return
	var mat := StandardMaterial3D.new()
	mat.albedo_color = bark_color
	mat.albedo_texture = _bark_texture()
	mat.texture_filter = BaseMaterial3D.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS # soft low-res look, like the terrain
	mat.vertex_color_use_as_albedo = true # per-tree tint comes in as the MultiMesh instance colour
	mat.roughness = 1.0
	mat.specular_mode = BaseMaterial3D.SPECULAR_DISABLED
	var rng := RandomNumberGenerator.new()
	rng.seed = tree_seed
	var meshes: Array[ArrayMesh] = []
	for v in variants:
		meshes.append(make_tree(tree_seed * 100 + v))
	var chunks := {} # Vector3i(cell x, cell z, variant) -> transforms; one MultiMesh each so far chunks get culled
	var placed := 0
	for i in tree_count * 4:
		if placed >= tree_count:
			break
		var p := Vector3(rng.randf_range(-5000, 5000), 0, rng.randf_range(-5000, 5000))
		p.y = terrain.data.get_height(p)
		if is_nan(p.y) or p.y < SEA_LEVEL + 1.5 or p.y > MAX_HEIGHT or Vector2(p.x, p.z).length() < 40.0:
			continue
		# mostly small trees, fewer as they get bigger, plus the odd giant
		var s := (0.25 + 0.75 * pow(rng.randf(), 3.0) if rng.randf() > 0.03 else rng.randf_range(1.5, 2.2)) * tree_scale
		var basis := Basis(Vector3.UP, rng.randf() * TAU).scaled(Vector3.ONE * s)
		var key := Vector3i(floori(p.x / CHUNK), floori(p.z / CHUNK), rng.randi() % variants)
		if not chunks.has(key):
			chunks[key] = []
		chunks[key].append(Transform3D(basis, p - Vector3.UP * 0.2))
		var cell := Vector2i(floori(p.x / COLLIDE_CELL), floori(p.z / COLLIDE_CELL))
		if not _trunks.has(cell):
			_trunks[cell] = []
			_roots[cell] = []
		_trunks[cell].append(Vector4(p.x, p.y - 0.2, p.z, s))
		_roots[cell].append([Transform3D(basis, p - Vector3.UP * 0.2), key.z])
		placed += 1
	for key: Vector3i in chunks:
		var mm := MultiMesh.new()
		mm.transform_format = MultiMesh.TRANSFORM_3D
		mm.use_colors = true
		mm.mesh = meshes[key.z]
		mm.instance_count = chunks[key].size()
		for i in chunks[key].size():
			mm.set_instance_transform(i, chunks[key][i])
			var shade := 1.0 + rng.randf_range(-1.0, 1.0) * tree_color_variance # lighter / darker
			var hue := rng.randf_range(-1.0, 1.0) * tree_color_variance * 0.3 # redder / browner
			mm.set_instance_color(i, Color(shade * (1.0 + hue), shade, shade * (1.0 - hue)))
		var mmi := MultiMeshInstance3D.new()
		mmi.multimesh = mm
		mmi.material_override = mat
		mmi.visibility_range_end = editor_view_distance if Engine.is_editor_hint() else view_distance
		mmi.top_level = true # instance transforms are world positions; set before add_child so the node's own transform is ignored
		add_child(mmi)

## True if a tree's trunk or roots reach within `clearance` metres of p (the tall inner roots: about 2x the tree scale).
func tree_near(p: Vector3, clearance: float) -> bool:
	var reach := 2.0 * 2.2 * tree_scale + clearance # biggest tree's roots
	for cz in range(floori((p.z - reach) / COLLIDE_CELL), floori((p.z + reach) / COLLIDE_CELL) + 1):
		for cx in range(floori((p.x - reach) / COLLIDE_CELL), floori((p.x + reach) / COLLIDE_CELL) + 1):
			for t: Vector4 in _trunks.get(Vector2i(cx, cz), []):
				if Vector2(t.x - p.x, t.z - p.z).length() < 2.0 * t.w + clearance:
					return true
	return false

# Only trunks near the player get colliders: 80k static bodies would choke physics.
func _process(_delta: float) -> void:
	if Engine.is_editor_hint() or _trunks.is_empty():
		return
	if not is_instance_valid(_player):
		_player = get_tree().get_first_node_in_group("player")
		if not _player:
			return
	var at := _player.global_position
	if at.distance_to(_collider_center) < COLLIDE_REFRESH:
		return
	_collider_center = at
	if not _body:
		_body = StaticBody3D.new()
		_body.add_to_group("navmesh") # mobs path around trunks near the player
		_body.top_level = true # colliders are placed in world space
		add_child(_body)
		_root_body = StaticBody3D.new()
		_root_body.top_level = true
		add_child(_root_body)
	var shapes := _body.get_children()
	var root_cols := _root_body.get_children()
	var used := 0
	var reach := ceili(COLLIDE_RADIUS / COLLIDE_CELL)
	var c0 := Vector2i(floori(at.x / COLLIDE_CELL), floori(at.z / COLLIDE_CELL))
	for cz in range(c0.y - reach, c0.y + reach + 1):
		for cx in range(c0.x - reach, c0.x + reach + 1):
			var cell_trunks: Array = _trunks.get(Vector2i(cx, cz), [])
			for k in cell_trunks.size():
				var t: Vector4 = cell_trunks[k]
				if Vector2(t.x - at.x, t.z - at.z).length() > COLLIDE_RADIUS:
					continue
				var rc: CollisionShape3D
				if used < root_cols.size():
					rc = root_cols[used]
					rc.disabled = false
				else:
					rc = CollisionShape3D.new()
					_root_body.add_child(rc)
				var tree: Array = _roots[Vector2i(cx, cz)][k]
				rc.shape = _root_shapes[tree[1]]
				rc.transform = tree[0]
				var col: CollisionShape3D
				if used < shapes.size():
					col = shapes[used]
					col.disabled = false
				else:
					col = CollisionShape3D.new()
					col.shape = CylinderShape3D.new()
					_body.add_child(col)
				var cyl := col.shape as CylinderShape3D
				cyl.radius = 0.4 * t.w # trunk is 0.5 thick at the base, tapering; slightly inside so it doesn't feel sticky
				cyl.height = 3.5 * t.w # trunk only; branches and roots don't collide
				col.position = Vector3(t.x, t.y + cyl.height * 0.5 - 0.3 * t.w, t.z)
				used += 1
	for i in range(used, shapes.size()):
		shapes[i].disabled = true
	for i in range(used, root_cols.size()):
		root_cols[i].disabled = true

func make_tree(seed_: int) -> ArrayMesh:
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var lean := Vector3(rng.randf_range(-0.35, 0.35), 1.0, rng.randf_range(-0.35, 0.35)).normalized()
	_branch(st, rng, Vector3(0, -0.3, 0), lean, rng.randf_range(3.0, 4.5), 0.5, 3, 5, 0.06)
	var roots := SurfaceTool.new() # built separately so they can get their own collision shape
	roots.begin(Mesh.PRIMITIVE_TRIANGLES)
	for r in rng.randi_range(4, 6): # roots: start low on the trunk, arc outward and dive into the ground
		var a := TAU * (r + rng.randf_range(-0.3, 0.3)) / 5.0
		var dir := Vector3(cos(a), rng.randf_range(0.0, 0.25), sin(a)).normalized()
		_branch(roots, rng, Vector3(0, rng.randf_range(0.4, 0.8), 0), dir, rng.randf_range(1.5, 2.6), 0.3, 1, 5, -0.2)
	var root_mesh := roots.commit()
	_root_shapes.append(root_mesh.create_trimesh_shape())
	st.append_from(root_mesh, 0, Transform3D.IDENTITY)
	st.generate_normals()
	st.index()
	# Auto-generated LODs: distant trees draw a few hundred triangles instead of ~1.6k.
	var im := ImporterMesh.new()
	im.add_surface(Mesh.PRIMITIVE_TRIANGLES, st.commit_to_arrays())
	im.generate_lods(25.0, 60.0, [])
	return im.get_mesh()

## One tapered, wobbly limb; forks into thinner children at its end until depth runs out.
## bend pulls the direction up (branches) or down (roots) each segment.
func _branch(st: SurfaceTool, rng: RandomNumberGenerator, p: Vector3, dir: Vector3, length: float,
		radius: float, depth: int, segs: int, bend: float) -> void:
	var r := radius
	var v := rng.randf() # bark texture runs along the limb; random start so limbs don't line up
	# ring orientation carried from ring to ring so segments don't twist inside out
	var side := dir.cross(Vector3.FORWARD if absf(dir.dot(Vector3.FORWARD)) < 0.9 else Vector3.RIGHT).normalized()
	var ring := _ring(p, dir, side, r)
	_cap(st, ring, p - dir * r, v, true) # closed base so the inside never shows at joints
	for s in segs:
		var wobble := Vector3(rng.randf_range(-1, 1), rng.randf_range(-1, 1), rng.randf_range(-1, 1)) * 0.3
		dir = (dir + wobble + Vector3.UP * bend).normalized()
		side = (side - dir * side.dot(dir)).normalized()
		p += dir * length / segs
		var next_v := v + length / segs / (TAU * r) * 0.5 # texture is twice as tall as wide: keeps texels square
		r = lerpf(radius, radius * 0.65, float(s + 1) / segs)
		var next := _ring(p, dir, side, r)
		_connect(st, ring, next, v, next_v)
		ring = next
		v = next_v
	if depth == 0:
		_cap(st, ring, p + dir * r * 3.0, v) # pointy twig tip
		return
	_cap(st, ring, p + dir * r * 0.5, v) # rounded knot where the branch forks
	for c in (2 if rng.randf() < 0.7 else 3):
		var off := dir.cross(Vector3(rng.randf_range(-1, 1), rng.randf_range(-1, 1), rng.randf_range(-1, 1))).normalized()
		var child_dir := (dir + off * rng.randf_range(0.6, 1.3)).normalized()
		_branch(st, rng, p - dir * r, child_dir, length * rng.randf_range(0.7, 0.95), r * 0.7, depth - 1, 3, bend)

func _ring(center: Vector3, dir: Vector3, side: Vector3, r: float) -> PackedVector3Array:
	var up := dir.cross(side)
	var pts := PackedVector3Array()
	for i in SIDES:
		var a := TAU * i / SIDES
		pts.append(center + (side * cos(a) + up * sin(a)) * r)
	return pts

## Tube segment between two rings. u wraps once around the limb, v runs along it.
func _connect(st: SurfaceTool, a: PackedVector3Array, b: PackedVector3Array, va: float, vb: float) -> void:
	for i in SIDES:
		var j := (i + 1) % SIDES
		var u0 := float(i) / SIDES
		var u1 := float(i + 1) / SIDES
		for corner in [[a[i], u0, va], [b[i], u0, vb], [b[j], u1, vb], [a[i], u0, va], [b[j], u1, vb], [a[j], u1, va]]:
			st.set_uv(Vector2(corner[1], corner[2]))
			st.add_vertex(corner[0])

## Cone from the ring to tip; backward = tip points against the ring's winding (a branch's base).
func _cap(st: SurfaceTool, ring: PackedVector3Array, tip: Vector3, v: float, backward := false) -> void:
	for i in SIDES:
		var a := ring[i]
		var b := ring[(i + 1) % SIDES]
		var ua := float(i) / SIDES
		var ub := float(i + 1) / SIDES
		var tip_uv := Vector2((ua + ub) * 0.5, v + 0.05)
		var corners := [[a, ua], [b, ub]] if backward else [[b, ub], [a, ua]]
		for c in corners:
			st.set_uv(Vector2(c[1], v))
			st.add_vertex(c[0])
		st.set_uv(tip_uv)
		st.add_vertex(tip)

## Morrowind-ish bark: stringy vertical fibres with dark grooves, pixelated. Grey so bark_color tints it.
func _bark_texture() -> ImageTexture:
	var w := bark_resolution
	var img := Image.create_empty(w, w * 2, false, Image.FORMAT_RGBA8)
	var rng := RandomNumberGenerator.new()
	rng.seed = 11
	var fibres := []
	for x in w:
		fibres.append(rng.randf())
	var k := w / 32.0 # fibre wobble stays the same size at any resolution
	for y in w * 2:
		for x in w:
			var f: float = fibres[posmod(x + int(round(1.5 * k * sin(TAU * y / w + x * 0.7 / k))), w)] # fibres wander side to side
			var b := 0.6 + 0.4 * f + rng.randf_range(-pixel_variance, pixel_variance)
			if f < 0.22:
				b *= 0.8 # groove
			img.set_pixel(x, y, Color(b, b * 0.93, b * 0.86))
	img.generate_mipmaps()
	return ImageTexture.create_from_image(img)
