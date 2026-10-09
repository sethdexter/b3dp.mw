class_name DroppedItem
extends RigidBody3D

## An item lying in the world. Look at it and press E to pick it up.
## Visual = the item's held scene (stripped of collision/interaction), or a sack if it has none.

@export var fallback_visual: PackedScene = preload("res://coinbag.glb")
@export var throw_speed: float = 2.0

@onready var visual_root: Node3D = $visual
@onready var interactable: InteractableComponent = $InteractableComponent
@onready var prompt: Label = $InteractableComponent/prompt

func setup(p_item: Item, p_amount: int, at: Vector3, forward: Vector3) -> void:
	global_position = at
	linear_velocity = forward.normalized() * throw_speed
	interactable.item = p_item
	interactable.amount = p_amount
	prompt.text = "Take %s%s" % [p_item.Name, " x%d" % p_amount if p_amount > 1 else ""]

	var scene := p_item.get_held_scene()
	var node: Node3D = (scene if scene else fallback_visual).instantiate() as Node3D
	if node:
		_make_visual_only(node)
		if scene:
			node.scale = p_item.get_held_scale()
		visual_root.add_child(node)

## Strip collision/interaction from the visual copy.
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
