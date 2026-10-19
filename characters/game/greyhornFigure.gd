@tool
extends Node3D
## Placeholder greyhorn: a gaunt grey grazer on four long legs, a low neck and swept-back horns, built from
## primitives until a real model exists. Pivot at the feet, faces -Z.
## Greyhorns browse the ash fungus out in the dark and shy away from people and fire: the one thing in the dark
## that is good to eat.

@export var coat_color := Color(0.42, 0.4, 0.37):
	set(v): coat_color = v; _build()
@export_range(0.0, 0.5) var color_variance := 0.12

func _ready() -> void:
	if not Engine.is_editor_hint():
		coat_color = coat_color.lightened(randf() * color_variance).darkened(randf() * color_variance)
	_build()

func _build() -> void:
	if not is_inside_tree():
		return
	for c in get_children():
		c.queue_free()
	var coat := _mat(coat_color)
	var horn := _mat(Color(0.75, 0.72, 0.64))
	var eye := _mat(Color(0.85, 0.85, 0.7))
	eye.emission_enabled = true
	eye.emission = Color(0.85, 0.85, 0.7)
	eye.emission_energy_multiplier = 0.6
	_box(Vector3(0.55, 0.55, 1.5), Vector3(0, 1.25, 0), coat) # body
	for x in [-0.2, 0.2]:
		for z in [-0.6, 0.6]:
			_box(Vector3(0.12, 1.0, 0.12), Vector3(x, 0.5, z), coat) # legs
	var neck := _box(Vector3(0.22, 0.6, 0.22), Vector3(0, 1.55, -0.85), coat)
	neck.rotation_degrees.x = 35.0
	_box(Vector3(0.26, 0.26, 0.5), Vector3(0, 1.75, -1.15), coat) # head, low and long
	for x in [-0.1, 0.1]:
		var h := _box(Vector3(0.05, 0.05, 0.55), Vector3(x * 1.6, 1.95, -0.95), horn)
		h.rotation_degrees = Vector3(25.0, x * 120.0, 0.0) # swept back
		_box(Vector3(0.05, 0.05, 0.05), Vector3(x * 1.4, 1.8, -1.38), eye)

func _box(size: Vector3, at: Vector3, mat: Material) -> MeshInstance3D:
	var m := MeshInstance3D.new()
	var mesh := BoxMesh.new()
	mesh.size = size
	m.mesh = mesh
	m.material_override = mat
	m.position = at
	add_child(m)
	return m

func _mat(c: Color) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_color = c
	m.roughness = 1.0
	return m
