extends NavigationRegion3D
## Keeps mob pathfinding baked in a square around the player, so mobs can path anywhere on the island.
## Re-bakes in the background whenever the player moves rebake_distance from the last bake.
## Walkable ground = the terrain, bodies in the "navmesh" group (the level, tree trunks near the player) and
## bodies in "navmesh_static" (thousands of rocks: indexed once into a grid, then only nearby cells are read).

@export var terrain: Terrain3D
## Half the width of the baked square, in metres.
@export var bake_radius: float = 60.0
@export var rebake_distance: float = 20.0

var _player: Node3D
var _baked_at := Vector3.INF
var _baking := false

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
	_add_obstacles(source, center)
	if terrain:
		source.add_faces(terrain.generate_nav_mesh_source_geometry(aabb, false), Transform3D.IDENTITY)
	NavigationServer3D.bake_from_source_geometry_data_async(mesh, source, _on_baked.bind(mesh))

func _on_baked(mesh: NavigationMesh) -> void:
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
			for cs: CollisionShape3D in _grid.get(Vector2i(x, z), []):
				if is_instance_valid(cs) and not cs.disabled:
					source.add_faces(_faces_of(cs.shape), cs.global_transform)

const GRID := 32.0 # metres per static-obstacle cell
var _grid := {} # Vector2i cell -> Array of CollisionShape3D
var _face_cache := {} # Shape3D -> [faces, size]; rocks share a few shape resources

func _index_static() -> void:
	for body in get_tree().get_nodes_in_group("navmesh_static"):
		for cs: CollisionShape3D in _shapes_of(body):
			if cs.shape:
				var cell := Vector2i(floori(cs.global_position.x / GRID), floori(cs.global_position.z / GRID))
				if not _grid.has(cell):
					_grid[cell] = []
				_grid[cell].append(cs)
	if _grid.is_empty():
		_grid[Vector2i(1 << 30, 0)] = [] # nothing static: don't re-index every bake

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
