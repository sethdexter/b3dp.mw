extends NavigationRegion3D
## Keeps mob pathfinding baked in a square around the player, so mobs can path anywhere on the island.
## Re-bakes in the background whenever the player moves rebake_distance from the last bake.
## Walkable ground = the terrain, bodies in the "navmesh" group (the level, tree trunks near the player) and
## bodies in "navmesh_static" (static obstacles, or nodes with get_nav_obstacles() like the rocks: indexed once
## into a grid, then only nearby cells are read).

@export var terrain: Terrain3D
## Half the width of the baked square, in metres.
@export var bake_radius: float = 60.0
@export var rebake_distance: float = 20.0

var _player: Node3D
var _baked_at := Vector3.INF
var _baking := false
var _task := -1

func _ready() -> void:
	assert(navigation_mesh, "navBaker needs a NavigationMesh to use as its bake settings")

func _physics_process(_delta: float) -> void:
	if _baking:
		return
	if not is_instance_valid(_player):
		_player = get_tree().get_first_node_in_group("player")
		if not _player:
			return
	if _player.global_position.distance_to(_baked_at) < rebake_distance:
		return
	_bake_around(_player.global_position)

func _bake_around(center: Vector3) -> void:
	_baking = true
	_baked_at = center
	var aabb := AABB(center - Vector3(bake_radius, 200, bake_radius), Vector3(bake_radius * 2, 400, bake_radius * 2))
	var mesh: NavigationMesh = navigation_mesh.duplicate()
	mesh.filter_baking_aabb = aabb
	var source := NavigationMeshSourceGeometryData3D.new()
	_add_obstacles(source, center) # reads nodes, so stays on the main thread (~1-10 ms)
	# Terrain3D itself isn't safe to call from a thread (that crashed), so the worker builds the ground from plain
	# height reads, the same way the grass does, then bakes. Keeps walking hitch-free.
	var data: Terrain3DData = terrain.data if terrain else null
	var spacing: float = terrain.vertex_spacing if terrain else 1.0
	var me: WeakRef = weakref(self) # the level may be gone (quit) by the time the bake finishes
	_task = WorkerThreadPool.add_task(func():
		if data:
			source.add_faces(_ground_faces(data, aabb, spacing), Transform3D.IDENTITY)
		NavigationServer3D.bake_from_source_geometry_data(mesh, source)
		if me.get_ref():
			me.get_ref()._on_baked.call_deferred(mesh))

## Quitting mid-bake crashed the engine (the worker outlived the level): wait for it first.
func _exit_tree() -> void:
	if _task >= 0:
		WorkerThreadPool.wait_for_task_completion(_task)
		_task = -1

func _on_baked(mesh: NavigationMesh) -> void:
	if _task >= 0:
		WorkerThreadPool.wait_for_task_completion(_task) # already done: just releases it
		_task = -1
	navigation_mesh = mesh
	_baking = false

# Only collision shapes near the player: parsing the whole scene stalls for ~0.8 s.
func _add_obstacles(source: NavigationMeshSourceGeometryData3D, center: Vector3) -> void:
	var reach := bake_radius * 1.5
	for body in get_tree().get_nodes_in_group("navmesh"): # few nodes; tree trunk colliders move, so read them fresh
		for cs: CollisionShape3D in _shapes_of(body):
			if cs.disabled or not cs.shape:
				continue
			var faces := _faces_of(cs.shape)
			if cs.global_position.distance_to(center) <= reach + _size_of(cs.shape): # big level pieces always count
				source.add_faces(faces, cs.global_transform)
	if _grid.is_empty():
		_index_static()
	var r := ceili(reach / GRID)
	var c0 := Vector2i(floori(center.x / GRID), floori(center.z / GRID))
	for z in range(c0.y - r, c0.y + r + 1):
		for x in range(c0.x - r, c0.x + r + 1):
			for obstacle: Array in _grid.get(Vector2i(x, z), []):
				source.add_faces(_faces_of(obstacle[0]), obstacle[1])

const GRID := 32.0 # metres per static-obstacle cell
var _grid := {} # Vector2i cell -> Array of [Shape3D, world Transform3D]
var _face_cache := {} # Shape3D -> [faces, size]; rocks share a few shape resources

func _index_static() -> void:
	for body in get_tree().get_nodes_in_group("navmesh_static"):
		if body.has_method("get_nav_obstacles"): # node-less obstacles, e.g. Foliage's rocks
			for obstacle: Array in body.get_nav_obstacles():
				_add_static(obstacle[0], obstacle[1])
			continue
		for cs: CollisionShape3D in _shapes_of(body):
			if cs.shape and not cs.disabled:
				_add_static(cs.shape, cs.global_transform)
	if _grid.is_empty():
		_grid[Vector2i(1 << 30, 0)] = [] # nothing static: don't re-index every bake

func _add_static(shape: Shape3D, xform: Transform3D) -> void:
	var cell := Vector2i(floori(xform.origin.x / GRID), floori(xform.origin.z / GRID))
	if not _grid.has(cell):
		_grid[cell] = []
	_grid[cell].append([shape, xform])

func _shapes_of(body: Node) -> Array:
	var shapes: Array = body.find_children("*", "CollisionShape3D", true, false)
	if body is CollisionShape3D:
		shapes.append(body)
	return shapes

func _faces_of(shape: Shape3D) -> PackedVector3Array:
	if not shape in _face_cache:
		var m := shape.get_debug_mesh()
		_face_cache[shape] = [m.get_faces(), m.get_aabb().size.length()]
	return _face_cache[shape][0]

func _size_of(shape: Shape3D) -> float:
	return _face_cache[shape][1]

## Two triangles per terrain cell inside aabb, from height samples. Holes (NaN heights) are left out.
static func _ground_faces(data: Terrain3DData, aabb: AABB, spacing: float) -> PackedVector3Array:
	var faces := PackedVector3Array()
	var x0 := floorf(aabb.position.x / spacing) * spacing
	var z0 := floorf(aabb.position.z / spacing) * spacing
	var nx := int(ceilf(aabb.size.x / spacing)) + 1
	var nz := int(ceilf(aabb.size.z / spacing)) + 1
	var rows := []
	for j in nz:
		var row := PackedVector3Array()
		for i in nx:
			var p := Vector3(x0 + i * spacing, 0.0, z0 + j * spacing)
			p.y = data.get_height(p)
			row.append(p)
		rows.append(row)
	for j in nz - 1:
		var a: PackedVector3Array = rows[j]
		var b: PackedVector3Array = rows[j + 1]
		for i in nx - 1:
			if is_nan(a[i].y) or is_nan(a[i + 1].y) or is_nan(b[i].y) or is_nan(b[i + 1].y):
				continue
			faces.append_array([a[i], a[i + 1], b[i], a[i + 1], b[i + 1], b[i]])
	return faces
