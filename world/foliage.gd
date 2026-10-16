extends Node3D
## Wispy grass and taller shoots that wave in the wind around the player, plus rocks scattered over the island.
## Reads the Terrain3D control map: both only grow on the grass texture.

@export var terrain: Terrain3D
@export var radius := 30.0 # foliage drawn this far around the player
@export var spacing := 0.6 # grid step between foliage candidates
## Extra grass this close to the player: from above you see the gaps underfoot that distance hides.
@export var near_radius := 10.0
## How many times denser it is right at your feet (fades back to normal by near_radius).
@export_range(1.0, 6.0, 0.5) var near_density := 3.0
@export var rebuild_distance := 6.0 # rebuild when the player moves this far
@export var rock_count := 700
@export var rock_seed := 7

const GRASS := 0 # texture ids, matching the texture_list in test_level.tscn
const SEA_LEVEL := -10.0
const ROCK_SCENES := ["res://world/props/rocks/RockA.tscn", "res://world/props/rocks/RockB.tscn", "res://world/props/rocks/RockC.tscn"]

const ROCK_CHUNK := 400.0 # metres per rock chunk

var _grass: MultiMeshInstance3D
var _shoots: MultiMeshInstance3D
var _center := Vector3.INF
var _player: Node3D
var _task := -1
var _result: Array[PackedFloat32Array]
var _base_shift := int(log(Terrain3DUtil.enc_base(1)) / log(2.0) + 0.5) # control map bit offsets
var _blend_shift := int(log(Terrain3DUtil.enc_blend(1)) / log(2.0) + 0.5)
var _rock_bodies := {} # Vector2i chunk -> physics body RID
var _rock_obstacles := []
var _rock_shapes := []

func _ready() -> void:
	assert(terrain, "Foliage needs the Terrain3D node")
	_player = get_tree().get_first_node_in_group("player")
	_grass = _make_layer(_strand_texture(8, Color(0.32, 0.22, 0.13), Color(0.78, 0.64, 0.45), 0.6), Vector2(0.7, 0.9), 0.3)
	_shoots = _make_layer(_strand_texture(4, Color(0.34, 0.2, 0.13), Color(0.88, 0.68, 0.45), 0.25), Vector2(0.45, 1.1), 0.08)
	_scatter_rocks()

func _process(_delta: float) -> void:
	if _task != -1:
		if not WorkerThreadPool.is_task_completed(_task):
			return
		WorkerThreadPool.wait_for_task_completion(_task)
		_task = -1
		_upload(_grass, _result[0])
		_upload(_shoots, _result[1])
	if _player and _player.global_position.distance_to(_center) > rebuild_distance:
		_center = _player.global_position
		var center := _center
		_task = WorkerThreadPool.add_task(func(): _result = _build(center))

# Runs on a worker thread: only reads terrain data and returns raw MultiMesh buffers.
func _build(center: Vector3) -> Array[PackedFloat32Array]:
	var grass := PackedFloat32Array()
	var shoots := PackedFloat32Array()
	var rng := RandomNumberGenerator.new()
	var data := terrain.data
	# pass 0: the whole patch. pass 1: a finer extra grid near the player, fading out by near_radius.
	for pass_i in 2:
		var s := spacing if pass_i == 0 else spacing / sqrt(maxf(near_density - 1.0, 0.01))
		var rad := radius if pass_i == 0 else near_radius
		if pass_i == 1 and near_density <= 1.0:
			break
		_scatter(center, s, rad, pass_i, grass, shoots, rng, data)
	return [grass, shoots]

func _scatter(center: Vector3, s: float, rad: float, salt: int, grass: PackedFloat32Array, shoots: PackedFloat32Array,
		rng: RandomNumberGenerator, data: Terrain3DData) -> void:
	var steps := int(rad / s)
	var r2 := rad * rad
	var gx0 := int(floor(center.x / s))
	var gz0 := int(floor(center.z / s))
	for gz in range(gz0 - steps, gz0 + steps + 1):
		for gx in range(gx0 - steps, gx0 + steps + 1):
			rng.seed = hash(Vector3i(gx, gz, salt)) # same blades every time this spot is rebuilt
			var p := Vector3((gx + rng.randf()) * s, 0, (gz + rng.randf()) * s)
			var dx := p.x - center.x
			var dz := p.z - center.z
			var d2 := dx * dx + dz * dz
			if d2 > r2 or rng.randf() < smoothstep(rad * 0.5, rad, sqrt(d2)): # thins out toward the edge so it fades instead of ending in a line
				continue
			var ctrl: int = data.get_control(p)
			if (ctrl >> _blend_shift) & 0xFF > 127: # mid-blend between textures: skip
				continue
			var id := (ctrl >> _base_shift) & 0x1F
			var layer: PackedFloat32Array
			if id == GRASS:
				layer = shoots if rng.randf() < 0.15 else grass # some taller shoots mixed in
			else:
				continue
			p.y = data.get_height(p)
			if is_nan(p.y) or p.y < SEA_LEVEL + 0.5:
				continue
			var a := rng.randf() * TAU
			var sc := rng.randf_range(0.6, 1.4)
			var c := cos(a) * sc
			var sn := sin(a) * sc
			# MultiMesh TRANSFORM_3D row layout: basis rows + origin, Y-rotation and uniform scale only
			layer.append_array([c, 0.0, sn, p.x, 0.0, sc, 0.0, p.y, -sn, 0.0, c, p.z])

func _upload(layer: MultiMeshInstance3D, buffer: PackedFloat32Array) -> void:
	layer.multimesh.instance_count = buffer.size() / 12
	layer.multimesh.buffer = buffer

func _make_layer(tex: Texture2D, size: Vector2, sway: float) -> MultiMeshInstance3D:
	var mat := ShaderMaterial.new()
	mat.shader = preload("res://world/foliage.gdshader")
	mat.set_shader_parameter("tex", tex)
	mat.set_shader_parameter("sway", sway)
	var mm := MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	mm.mesh = _cross_mesh(size)
	var mmi := MultiMeshInstance3D.new()
	mmi.multimesh = mm
	mmi.material_override = mat
	mmi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	mmi.layers = 2 # render layer 2: the skylight skips it (light_cull_mask in test_level.tscn) so grass doesn't shine in the moonlight
	add_child(mmi)
	mmi.top_level = true # instance transforms are world positions
	return mmi

# two quads crossed in an X, base at the origin
func _cross_mesh(size: Vector2) -> Mesh:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	for a in [0.0, PI / 2.0]:
		var d := Vector3(cos(a), 0, sin(a)) * size.x * 0.5
		var up := Vector3.UP * size.y
		var quad := [[-d, Vector2(0, 1)], [d, Vector2(1, 1)], [d + up, Vector2(1, 0)], [-d + up, Vector2(0, 0)]]
		for i in [0, 1, 2, 0, 2, 3]:
			st.set_normal(Vector3.UP)
			st.set_uv(quad[i][1])
			st.add_vertex(quad[i][0])
	return st.commit()

# tiny pixel texture of curved strands, base colour fading to tip colour
func _strand_texture(strands: int, base: Color, tip: Color, lean: float) -> Texture2D:
	const H := 64 # texture height in pixels; strands use the full height
	var img := Image.create_empty(16, H, false, Image.FORMAT_RGBA8)
	var rng := RandomNumberGenerator.new()
	rng.seed = strands
	for s in strands:
		var x0 := rng.randf_range(3.0, 12.0)
		var bend := rng.randf_range(-lean, lean) * 16.0
		var top := rng.randi_range(H / 2 - 2, H - 1)
		for y in top:
			var t := float(y) / (H - 1)
			var x := clampi(int(x0 + bend * t * t), 0, 15)
			img.set_pixel(x, H - 1 - y, base.lerp(tip, t))
			if t < 0.5: # thicker at the root
				img.set_pixel(clampi(x + 1, 0, 15), H - 1 - y, base.lerp(tip, t))
	return ImageTexture.create_from_image(img)

## Rocks are drawn with one MultiMesh per rock type per chunk and collide through bare physics-server bodies
## (one per chunk), so tens of thousands of rocks cost a few hundred draw calls and no scene nodes.
func _scatter_rocks() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = rock_seed
	var mat := StandardMaterial3D.new()
	mat.albedo_texture = load("res://assets/terrain/lowres/rock030_alb_ht_96.png")
	mat.albedo_color = Color(0.55, 0.5, 0.45)
	mat.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST_WITH_MIPMAPS
	mat.uv1_scale = Vector3(2, 2, 2)
	mat.specular_mode = BaseMaterial3D.SPECULAR_DISABLED
	var protos := [] # per rock type: [mesh, mesh offset, collision shape, shape offset]
	for path in ROCK_SCENES:
		var inst: Node3D = load(path).instantiate()
		var mi: MeshInstance3D = inst.find_children("*", "MeshInstance3D")[0]
		var cs: CollisionShape3D = inst.find_children("*", "CollisionShape3D")[0]
		protos.append([mi.mesh, mi.transform, cs.shape, cs.transform])
		inst.queue_free()
	var visuals := {} # Vector3i(chunk x, chunk z, rock type) -> Array[Transform3D]
	var space := get_world_3d().space
	var placed := 0
	for i in rock_count * 4:
		if placed >= rock_count:
			break
		var p := Vector3(rng.randf_range(-5000, 5000), 0, rng.randf_range(-5000, 5000))
		p.y = terrain.data.get_height(p)
		if is_nan(p.y) or p.y < SEA_LEVEL + 1.0 or Vector2(p.x, p.z).length() < 60.0: # keep spawn clear
			continue
		var type := rng.randi() % protos.size()
		var s := rng.randf_range(0.15, 0.9) if rng.randf() < 0.85 else rng.randf_range(1.0, 2.0) # mostly small, a few boulders
		var xform := Transform3D(Basis.from_euler(Vector3(rng.randf() * TAU, rng.randf() * TAU, rng.randf() * TAU)).scaled(Vector3.ONE * s), p - Vector3.UP * s)
		var cell := Vector2i(floori(p.x / ROCK_CHUNK), floori(p.z / ROCK_CHUNK))
		var key := Vector3i(cell.x, cell.y, type)
		if not visuals.has(key):
			visuals[key] = []
		visuals[key].append(xform * protos[type][1])
		if not _rock_bodies.has(cell):
			var body := PhysicsServer3D.body_create()
			PhysicsServer3D.body_set_mode(body, PhysicsServer3D.BODY_MODE_STATIC)
			PhysicsServer3D.body_set_collision_layer(body, 1)
			PhysicsServer3D.body_set_collision_mask(body, 3)
			PhysicsServer3D.body_set_space(body, space)
			_rock_bodies[cell] = body
		var shape_xform: Transform3D = xform * protos[type][3]
		PhysicsServer3D.body_add_shape(_rock_bodies[cell], protos[type][2].get_rid(), shape_xform)
		_rock_obstacles.append([protos[type][2], shape_xform])
		placed += 1
	_rock_shapes = protos.map(func(proto): return proto[2]) # keep the shapes alive while the bodies use them
	for key: Vector3i in visuals:
		var mm := MultiMesh.new()
		mm.transform_format = MultiMesh.TRANSFORM_3D
		mm.mesh = protos[key.z][0]
		mm.instance_count = visuals[key].size()
		for i in visuals[key].size():
			mm.set_instance_transform(i, visuals[key][i])
		var mmi := MultiMeshInstance3D.new()
		mmi.multimesh = mm
		mmi.material_override = mat
		mmi.visibility_range_end = 350.0 + ROCK_CHUNK * 0.71 # fog hides rocks by ~350 m; range is measured to the chunk centre
		mmi.top_level = true
		add_child(mmi)
	add_to_group("navmesh_static") # mobs path around rocks; navBaker reads them through get_nav_obstacles()

## [Shape3D, world Transform3D] for every rock, for navBaker.
func get_nav_obstacles() -> Array:
	return _rock_obstacles

func _exit_tree() -> void:
	if _task != -1:
		WorkerThreadPool.wait_for_task_completion(_task)
	for body: RID in _rock_bodies.values():
		PhysicsServer3D.free_rid(body)
	_rock_bodies.clear()
