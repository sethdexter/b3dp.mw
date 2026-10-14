class_name MeleeComponent
extends Node

## Left click swings the equipped right-hand weapon.
## A hit only lands if the weapon model itself passes through a character's collider during the strike.
## Damage comes from CombatComponent.attack().
## Ignored while the inventory/container UI is open (it uses left click).

@export var character: BaseCharacter
## Node rotated for the swing animation (the right hand marker).
@export var swing_pivot: Node3D

## Stamina per swing. Can't swing without enough.
@export var swing_stamina_cost: float = 1.0

@export_group("Swing animation")
## Attacks per weapon category and move direction, keyed "<category>_<still|forward|left|right>".
## Moving backwards uses _still. A missing key falls back to "<category>_still".
@export var swings: Dictionary[String, Resource] = {} # MeleeSwing values
## Blade hit volume radius in metres. Bigger = more forgiving.
@export_range(0.02, 0.4, 0.01, "suffix:m") var blade_thickness: float = 0.15
## Fraction of the swing spent winding up and striking; the rest is the return to rest (0-1).
## The blade can connect from the start of the strike until the swing ends.
@export_range(0.0, 1.0) var hit_moment: float = 0.45

var _busy := false
var _rest_rotation := Vector3.ZERO
var _rest_position := Vector3.ZERO
var _blade_weapon: WeaponItem # set while the blade can connect
var _blade_prev: Array[Vector3] = [] # blade points last physics frame, for sweeping between frames
var _blade_shape := CapsuleShape3D.new()

func _ready() -> void:
	if not character:
		character = get_parent() as BaseCharacter
	if swing_pivot:
		_rest_rotation = swing_pivot.rotation_degrees
		_rest_position = swing_pivot.position

func _unhandled_input(event: InputEvent) -> void:
	var pressed := false
	if InputMap.has_action("attack"):
		pressed = event.is_action_pressed("attack")
	else:
		pressed = event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT
	if pressed and not _inventory_open() and not character.is_dead:
		swing()

func swing() -> void:
	if _busy:
		return
	var weapon := _weapon()
	if weapon == null:
		print("No weapon equipped.")
		return
	var stats := character.statComponent
	if stats and not stats.has_stamina(swing_stamina_cost):
		print("Too tired to swing.")
		return
	if stats:
		stats.spend_stamina(swing_stamina_cost)
	_busy = true

	# attackSpeed = seconds per swing (0.4 by default).
	var duration := maxf(0.15, weapon.attackSpeed)
	var windup := duration * hit_moment
	var recover := duration - windup

	var s: Resource = _pick_swing(weapon)
	if not swing_pivot or not s:
		_busy = false
		return
	var t := create_tween()
	t.tween_property(swing_pivot, "rotation_degrees", _rest_rotation + s.windup_rotation, windup * 0.6) \
		.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	t.parallel().tween_property(swing_pivot, "position", _rest_position + s.windup_offset, windup * 0.6) \
		.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	t.tween_callback(_open_blade.bind(weapon))
	# hand_leads: the hand gets there first and the blade whips round after it (side sweeps)
	var pos_trans := Tween.TRANS_QUAD
	var pos_ease := Tween.EASE_IN
	if s.hand_leads:
		pos_trans = Tween.TRANS_SINE
		pos_ease = Tween.EASE_OUT
	t.tween_property(swing_pivot, "rotation_degrees", _rest_rotation + s.strike_rotation, windup * 0.4) \
		.set_trans(Tween.TRANS_CUBIC if s.hand_leads else Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	t.parallel().tween_property(swing_pivot, "position", _rest_position + s.strike_offset, windup * 0.4) \
		.set_trans(pos_trans).set_ease(pos_ease)
	t.tween_property(swing_pivot, "rotation_degrees", _rest_rotation, recover) \
		.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	t.parallel().tween_property(swing_pivot, "position", _rest_position, recover) \
		.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	await t.finished
	_blade_weapon = null
	_busy = false

## Attack for the weapon's category and the way the player is moving (dominant axis wins).
func _pick_swing(weapon: WeaponItem) -> Resource:
	var dir := "still"
	var controller = character.get("controllerComponent")
	var input: Vector2 = controller.input_dir if controller else Vector2.ZERO
	if input.length() > 0.3:
		if absf(input.y) >= absf(input.x):
			dir = "forward" if input.y < 0.0 else "still" # backwards uses the standing attack
		else:
			dir = "right" if input.x > 0.0 else "left"
	var cat: String = weapon.category
	return swings.get("%s_%s" % [cat, dir], swings.get(cat + "_still"))

func _open_blade(weapon: WeaponItem) -> void:
	_blade_weapon = weapon
	_blade_prev = _blade_points()

func _physics_process(_delta: float) -> void:
	if _blade_weapon == null:
		return
	var pts := _blade_points()
	if pts.is_empty():
		return
	# a thick capsule along the blade at this frame and at in-between poses since last frame,
	# so the whole swept arc counts and fast swings can't skip past a thin collider
	var steps := 1
	if _blade_prev.size() == 2:
		steps = clampi(ceili(_blade_prev[1].distance_to(pts[1]) / blade_thickness), 1, 8)
	for k in steps:
		var f := float(k + 1) / steps
		var a: Vector3 = pts[0] if _blade_prev.is_empty() else _blade_prev[0].lerp(pts[0], f)
		var b: Vector3 = pts[1] if _blade_prev.is_empty() else _blade_prev[1].lerp(pts[1], f)
		var target := _blade_overlap(a, b)
		if target and character.combatComponent:
			character.combatComponent.attack(target, _blade_weapon)
			_blade_weapon = null # one hit per swing
			return
	_blade_prev = pts

func _blade_overlap(a: Vector3, b: Vector3) -> BaseCharacter:
	var along := b - a
	var length := along.length()
	if length < 0.01:
		return null
	_blade_shape.radius = blade_thickness
	_blade_shape.height = length + blade_thickness * 2.0
	var y := along / length
	var x := y.cross(Vector3.UP if absf(y.y) < 0.99 else Vector3.RIGHT).normalized()
	var q := PhysicsShapeQueryParameters3D.new()
	q.shape = _blade_shape
	q.transform = Transform3D(Basis(x, y, x.cross(y)), (a + b) * 0.5)
	q.exclude = [character.get_rid()]
	for hit in character.get_world_3d().direct_space_state.intersect_shape(q, 8):
		var c := hit.collider as BaseCharacter
		if c:
			return c
	return null

## Hilt and tip of the held weapon in world space, from its meshes' bounding box (longest axis = blade).
func _blade_points() -> Array[Vector3]:
	if not swing_pivot or swing_pivot.get_child_count() == 0:
		return []
	var item := swing_pivot.get_child(0) as Node3D
	if not item:
		return []
	var box := AABB()
	var first := true
	for m: MeshInstance3D in item.find_children("*", "MeshInstance3D"):
		var b := (item.global_transform.affine_inverse() * m.global_transform) * m.get_aabb()
		box = b if first else box.merge(b)
		first = false
	if first:
		return []
	var axis := box.get_longest_axis_index()
	var a := box.get_center()
	var b2 := box.get_center()
	a[axis] = box.position[axis]
	b2[axis] = box.end[axis]
	var xf := item.global_transform
	var hilt := xf * a
	var tip := xf * b2
	if hilt.distance_to(swing_pivot.global_position) > tip.distance_to(swing_pivot.global_position):
		return [tip, hilt] # the end nearer the hand is the hilt
	return [hilt, tip]

func _weapon() -> WeaponItem:
	if character and character.equipmentComponent:
		return character.equipmentComponent.get_weapon()
	return null

func _inventory_open() -> bool:
	for child in character.get_children():
		if child is PlayerInventoryUI:
			return child.is_open
	return false
