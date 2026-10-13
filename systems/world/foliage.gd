extends Node3D
## Wispy grass and taller shoots that wave in the wind around the player, plus rocks scattered over the island.
## Reads the Terrain3D control map: both only grow on the grass texture.

@export var terrain: Terrain3D
@export var radius := 30.0 # foliage drawn this far around the player
@export var spacing := 0.6 # grid step between foliage candidates
@export var rebuild_distance := 6.0 # rebuild when the player moves this far
@export var rock_count := 700
@export var rock_seed := 7

const GRASS := 0 # texture ids, matching the texture_list in test_level.tscn
const SEA_LEVEL := -10.0
const ROCK_SCENES := ["res://demo/assets/models/RockA.tscn", "res://demo/assets/models/RockB.tscn", "res://demo/assets/models/RockC.tscn"]

var _grass: MultiMeshInstance3D
var _shoots: MultiMeshInstance3D
var _center := Vector3.INF
var _player: Node3D
var _task := -1
var _result: Array[PackedFloat32Array]
var _base_shift := int(log(Terrain3DUtil.enc_base(1)) / log(2.0) + 0.5) # control map bit offsets
var _blend_shift := int(log(Terrain3DUtil.enc_blend(1)) / log(2.0) + 0.5)

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
	var steps := int(radius / spacing)
	var r2 := radius * radius
	var gx0 := int(floor(center.x / spacing))
	var gz0 := int(floor(center.z / spacing))
	for gz in range(gz0 - steps, gz0 + steps + 1):
		for gx in range(gx0 - steps, gx0 + steps + 1):
			rng.seed = hash(Vector2i(gx, gz)) # same blades every time this spot is rebuilt
			var p := Vector3((gx + rng.randf()) * spacing, 0, (gz + rng.randf()) * spacing)
			var dx := p.x - center.x
			var dz := p.z - center.z
			var d2 := dx * dx + dz * dz
			if d2 > r2 or rng.randf() < smoothstep(radius * 0.5, radius, sqrt(d2)): # thins out toward the edge so it fades instead of ending in a line
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
	return [grass, shoots]

func _upload(layer: MultiMeshInstance3D, buffer: PackedFloat32Array) -> void:
	layer.multimesh.instance_count = buffer.size() / 12
	layer.multimesh.buffer = buffer

func _make_layer(tex: Texture2D, size: Vector2, sway: float) -> MultiMeshInstance3D:
	var mat := ShaderMaterial.new()
	mat.shader = preload("res://systems/world/foliage.gdshader")
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
	var img := Image.create_empty(16, 32, false, Image.FORMAT_RGBA8)
	var rng := RandomNumberGenerator.new()
	rng.seed = strands
	for s in strands:
		var x0 := rng.randf_range(3.0, 12.0)
		var bend := rng.randf_range(-lean, lean) * 16.0
		var top := rng.randi_range(14, 31)
		for y in top:
			var t := float(y) / 31.0
			var x := clampi(int(x0 + bend * t * t), 0, 15)
			img.set_pixel(x, 64 - y, base.lerp(tip, t))
			if t < 0.5: # thicker at the root
				img.set_pixel(clampi(x + 1, 0, 15), 31 - y, base.lerp(tip, t))
	return ImageTexture.create_from_image(img)

func _scatter_rocks() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = rock_seed
	var scenes := ROCK_SCENES.map(func(path): return load(path))
	var mat := StandardMaterial3D.new()
	mat.albedo_texture = load("res://assets/terrain/lowres/rock030_alb_ht_96.png")
	mat.albedo_color = Color(0.55, 0.5, 0.45)
	mat.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST_WITH_MIPMAPS
	mat.uv1_scale = Vector3(2, 2, 2)
	mat.specular_mode = BaseMaterial3D.SPECULAR_DISABLED
	var placed := 0
	for i in rock_count * 4:
		if placed >= rock_count:
			break
		var p := Vector3(rng.randf_range(-5000, 5000), 0, rng.randf_range(-5000, 5000))
		p.y = terrain.data.get_height(p)
		if is_nan(p.y) or p.y < SEA_LEVEL + 1.0 or Vector2(p.x, p.z).length() < 60.0: # keep spawn clear
			continue
		var rock: Node3D = scenes[rng.randi() % scenes.size()].instantiate()
		var s := rng.randf_range(0.15, 0.9) if rng.randf() < 0.85 else rng.randf_range(1.0, 2.0) # mostly small, a few boulders
		rock.transform = Transform3D(Basis.from_euler(Vector3(rng.randf() * TAU, rng.randf() * TAU, rng.randf() * TAU)).scaled(Vector3.ONE * s), p - Vector3.UP * s)
		for mesh: MeshInstance3D in rock.find_children("*", "MeshInstance3D"):
			mesh.material_override = mat
			mesh.visibility_range_end = 350.0 # fog hides them by then; saves most of the 700 draw calls
		add_child(rock)
		placed += 1

func _exit_tree() -> void:
	if _task != -1:
		WorkerThreadPool.wait_for_task_completion(_task)
