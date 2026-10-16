@tool
extends Node3D
## Placeholder person: a tall hooded robe with a pointed hood, a void for a face and two dim eyes.
## Built from primitives (in the editor too) until real models exist. Pivot at the feet, faces -Z.

@export var height := 3.0:
	set(v): height = v; _build()
@export var cloak_color := Color(0.32, 0.27, 0.22):
	set(v): cloak_color = v; _build()
@export var eye_color := Color(1.0, 0.75, 0.3):
	set(v): eye_color = v; _build()
## Carries a staff (drifters) or a short blade (bandits) in the right hand.
@export_enum("none", "staff", "blade") var carries := 1:
	set(v): carries = v; _build()
## Each spawned figure gets a slightly different cloak shade.
@export_range(0.0, 0.5) var color_variance := 0.15

func _ready() -> void:
	if not Engine.is_editor_hint():
		cloak_color = cloak_color.lightened(randf() * color_variance).darkened(randf() * color_variance)
	_build()

func _build() -> void:
	if not is_inside_tree():
		return
	for c in get_children():
		c.queue_free()
	var s := height / 3.0
	var cloth := _mat(cloak_color)
	var dark := _mat(Color(0.02, 0.02, 0.02))
	var wood := _mat(Color(0.3, 0.2, 0.12))
	var glow := _mat(eye_color)
	glow.emission_enabled = true
	glow.emission = eye_color
	glow.emission_energy_multiplier = 2.0
	var robe := CylinderMesh.new()
	robe.top_radius = 0.28; robe.bottom_radius = 0.62; robe.height = 2.3; robe.radial_segments = 7
	_part(robe, cloth, Vector3(0, 1.15, 0), s)
	var hood := SphereMesh.new()
	hood.radius = 0.36; hood.height = 0.72; hood.radial_segments = 7; hood.rings = 4
	_part(hood, cloth, Vector3(0, 2.5, 0.04), s)
	var point := CylinderMesh.new()
	point.top_radius = 0.0; point.bottom_radius = 0.3; point.height = 0.6; point.radial_segments = 7
	_part(point, cloth, Vector3(0, 2.85, 0.14), s).rotation_degrees.x = 25 # hood tip droops back
	var face := SphereMesh.new()
	face.radius = 0.24; face.height = 0.44; face.radial_segments = 7; face.rings = 4
	_part(face, dark, Vector3(0, 2.47, -0.16), s)
	var eye := SphereMesh.new()
	eye.radius = 0.035; eye.height = 0.07; eye.radial_segments = 4; eye.rings = 2
	for x in [-0.08, 0.08]:
		_part(eye, glow, Vector3(x, 2.5, -0.38), s)
	var sleeve := CapsuleMesh.new()
	sleeve.radius = 0.12; sleeve.height = 1.1; sleeve.radial_segments = 6; sleeve.rings = 2
	for x in [-0.42, 0.42]:
		_part(sleeve, cloth, Vector3(x, 1.75, -0.05), s).rotation_degrees.z = 8 * signf(x)
	if carries == 1:
		var staff := CylinderMesh.new()
		staff.top_radius = 0.035; staff.bottom_radius = 0.045; staff.height = 3.2; staff.radial_segments = 5
		_part(staff, wood, Vector3(0.55, 1.5, -0.25), s).rotation_degrees.x = -6
	elif carries == 2:
		var blade := BoxMesh.new()
		blade.size = Vector3(0.05, 0.9, 0.12)
		_part(blade, _mat(Color(0.45, 0.45, 0.42)), Vector3(0.5, 0.95, -0.3), s).rotation_degrees.x = -20

func _part(mesh: Mesh, mat: Material, at: Vector3, s: float) -> MeshInstance3D:
	var m := MeshInstance3D.new()
	m.mesh = mesh
	m.material_override = mat
	m.position = at * s
	m.scale = Vector3.ONE * s
	add_child(m) # no owner: rebuilt on load, never saved into the scene
	return m

func _mat(c: Color) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_color = c
	m.roughness = 1.0
	m.specular_mode = BaseMaterial3D.SPECULAR_DISABLED
	return m
