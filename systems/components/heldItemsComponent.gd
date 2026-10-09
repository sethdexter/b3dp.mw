class_name HeldItemsComponent
extends Node3D

## Shows equipped hand items in first person.
## Put under the Camera3D with Marker3D children named after equipment slots
## ("right_hand", "left_hand"). Move the markers in the editor to adjust hand position.
## Per-item placement comes from the item's original .tres (heldPosition / heldRotation / heldScale).

@export var equipment: EquipmentComponent

## slot name -> spawned Node3D
var _spawned: Dictionary[String, Node3D] = {}

func _ready() -> void:
	if not equipment:
		push_error("HeldItemsComponent: assign 'equipment' in the Inspector.")
		return
	equipment.equipment_changed.connect(_on_equipment_changed)
	for slot in equipment.equipment:
		_on_equipment_changed(slot, equipment.equipment[slot])

func _on_equipment_changed(slot: String, item: Item) -> void:
	var marker := get_node_or_null(slot) as Node3D
	if marker == null:
		return # slot isn't shown in first person (head, chest...)

	if _spawned.has(slot):
		_spawned[slot].queue_free()
		_spawned.erase(slot)

	if item == null:
		return
	var scene: PackedScene = item.get_held_scene()
	if scene == null:
		return

	var node := scene.instantiate() as Node3D
	if node == null:
		return
	_make_visual_only(node)
	node.position = item.get_held_position()
	node.rotation_degrees = item.get_held_rotation()
	node.scale = item.get_held_scale()
	marker.add_child(node)
	_spawned[slot] = node

## World/pickup scenes come with collision and interaction; strip them for the hand copy.
func _make_visual_only(root: Node) -> void:
	for child in root.get_children():
		_make_visual_only(child)
	if root is InteractableComponent:
		root.get_parent().remove_child(root)
		root.queue_free()
	elif root is CollisionObject3D:
		root.collision_layer = 0
		root.collision_mask = 0
	elif root is CollisionShape3D:
		root.disabled = true
	elif root is GeometryInstance3D and not root is GPUParticles3D:
		root.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
