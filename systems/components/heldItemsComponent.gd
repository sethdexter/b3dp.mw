class_name HeldItemsComponent
extends Node3D

## Shows equipped hand items in first person.
## Put under the Camera3D with Marker3D children named after equipment slots
## ("right_hand", "left_hand"). Move the markers in the editor to adjust hand position.
## Per-item placement comes from the item's original .tres (heldPosition / heldRotation / heldScale).

@export var equipment: EquipmentComponent
## Optional: held items sway along with the head bob.
@export var head_bob: Node # HeadBobComponent

@export_group("Right hand", "right_")
## How far the item lags behind looking up/down (0 = locked to the camera, 1 = stays level).
@export_range(0.0, 1.0, 0.01) var right_pitch_lag := 0.15
## When turning, the item trails behind by up to this many degrees, then catches up.
@export_range(0.0, 30.0, 0.5, "suffix:deg") var right_turn_lag_max_deg := 6.0
## How fast the item catches up after a turn (higher = snappier).
@export_range(0.5, 40.0, 0.5) var right_turn_catch_up := 10.0
## Extra on-screen sway while walking.
@export_range(0.0, 0.1, 0.001, "suffix:m") var right_bob_sway := 0.012
## How far the item trails the camera's bob (radians of the stride cycle).
@export_range(0.0, 3.0, 0.05) var right_bob_lag := 0.6

@export_group("Left hand", "left_")
@export_range(0.0, 1.0, 0.01) var left_pitch_lag := 0.15
@export_range(0.0, 30.0, 0.5, "suffix:deg") var left_turn_lag_max_deg := 6.0
@export_range(0.5, 40.0, 0.5) var left_turn_catch_up := 10.0
@export_range(0.0, 0.1, 0.001, "suffix:m") var left_bob_sway := 0.012
@export_range(0.0, 3.0, 0.05) var left_bob_lag := 0.6

## slot name -> spawned Node3D
var _spawned: Dictionary[String, Node3D] = {}
## slot name -> the item's own placement, before any sway
var _rest: Dictionary[String, Transform3D] = {}
var _yaw_lag: Dictionary[String, float] = {}
var _last_yaw := NAN

func _ready() -> void:
	if not equipment:
		push_error("HeldItemsComponent: assign 'equipment' in the Inspector.")
		return
	equipment.equipment_changed.connect(_on_equipment_changed)
	for slot in equipment.equipment:
		_on_equipment_changed(slot, equipment.equipment[slot])

func _process(delta: float) -> void:
	var cam := get_parent() as Node3D
	if not cam:
		return
	var yaw := cam.global_rotation.y
	var turned := 0.0 if is_nan(_last_yaw) else wrapf(yaw - _last_yaw, -PI, PI)
	_last_yaw = yaw
	for slot in _spawned:
		var hand := "left_" if slot == "left_hand" else "right_" # any other slot uses the right hand's settings
		var limit: float = deg_to_rad(get(hand + "turn_lag_max_deg"))
		var lag: float = clampf(_yaw_lag.get(slot, 0.0) - turned, -limit, limit)
		lag = lerpf(lag, 0.0, 1.0 - exp(-get(hand + "turn_catch_up") * delta))
		_yaw_lag[slot] = lag
		var bob: Vector3 = head_bob.held_offset(get(hand + "bob_sway"), get(hand + "bob_lag")) if head_bob else Vector3.ZERO
		# sway pivots at the eye (this node's origin); undo the hand marker's own transform so melee swings on it still work
		var sway := Transform3D(Basis.from_euler(Vector3(-cam.rotation.x * get(hand + "pitch_lag"), lag, 0.0)), bob)
		var marker := _spawned[slot].get_parent() as Node3D
		_spawned[slot].transform = marker.transform.affine_inverse() * sway * marker.transform * _rest[slot]

func _on_equipment_changed(slot: String, item: Item) -> void:
	var marker := get_node_or_null(slot) as Node3D
	if marker == null:
		return # slot isn't shown in first person (head, chest...)

	if _spawned.has(slot):
		_spawned[slot].queue_free()
		_spawned.erase(slot)
		_rest.erase(slot)

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
	_rest[slot] = node.transform

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
