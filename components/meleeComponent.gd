@tool
class_name MeleeComponent
extends Node

## Left click swings the equipped right-hand weapon.
## A hit only lands if the weapon model itself passes through a character's collider during the strike.
## Damage comes from CombatComponent.attack().
## Ignored while the inventory/container UI is open (it uses left click).
## Editor preview group: shows a weapon in a swing in the viewport for tuning `swings` (never saved, editor only).

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
## Last fraction of the swing (during the return to rest) where clicking again starts the next swing right away.
@export_range(0.0, 0.5) var chain_window: float = 0.3

@export_group("Editor preview")
## Weapon to hold in the preview (an Item .tres). Its attackSpeed sets the timeline length.
@export var preview_item: Resource:
	set(v):
		preview_item = v
		_clear_preview()
		notify_property_list_changed()
## Key in swings, e.g. "sword_right".
@export var preview_swing := "sword_right"
## Seconds into the swing: rest -> windup -> strike -> back to rest.
@export_range(0.0, 1.0, 0.01, "suffix:s") var preview_timeline := 0.0
## Loop the swing automatically.
@export var preview_play := false
## 1 = game speed, 4 = four times slower.
@export_range(1.0, 10.0, 0.5) var preview_slow_motion := 1.0
@export var show_preview := false:
	set(v):
		show_preview = v
		_clear_preview()

var _busy := false
var _swing_tween: Tween
var _chain_at_msec := 0 # from this time the current swing can be interrupted by the next one
var _rest_rotation := Vector3.ZERO
var _rest_position := Vector3.ZERO
var _blade_weapon: WeaponItem # set while the blade can connect
var _blade_prev: Array[Vector3] = [] # blade points last physics frame, for sweeping between frames
var _blade_shape := CapsuleShape3D.new()
var _ghost: Node3D # editor preview weapon, never saved
var _held_dirs: Array[String] = [] # move keys held right now, oldest first; the last one picks the swing

func _ready() -> void:
	if not character:
		character = get_parent() as BaseCharacter
	if swing_pivot:
		_rest_rotation = swing_pivot.rotation_degrees
		_rest_position = swing_pivot.position

# same actions the controller moves with (move_* if the project has them, otherwise ui_*); backwards uses the standing attack
const MOVE_DIRS := {"move_forward": "forward", "move_back": "still", "move_left": "left", "move_right": "right",
	"ui_up": "forward", "ui_down": "still", "ui_left": "left", "ui_right": "right"}

# _input, not _unhandled_input, so no key press or release is missed
func _input(event: InputEvent) -> void:
	if Engine.is_editor_hint() or event.is_echo():
		return
	for action in MOVE_DIRS:
		if event.is_action_pressed(action):
			_held_dirs.erase(action)
			_held_dirs.append(action)
		elif event.is_action_released(action):
			_held_dirs.erase(action)

func _unhandled_input(event: InputEvent) -> void:
	if Engine.is_editor_hint():
		return
	var pressed := false
	if InputMap.has_action("attack"):
		pressed = event.is_action_pressed("attack")
	else:
		pressed = event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT
	if pressed and not _inventory_open() and not character.is_dead:
		swing()

func swing() -> void:
	if _busy and Time.get_ticks_msec() < _chain_at_msec:
		return
	var weapon := _weapon()
	if weapon == null:
		print("No weapon equipped.")
		return
	var stats := character.statComponent
	if stats and not stats.has_stamina(swing_stamina_cost):
		print("Too tired to swing.")
		return
	var s: Resource = _pick_swing(weapon)
	if not swing_pivot or not s:
		return
	if stats:
		stats.spend_stamina(swing_stamina_cost)
	if _swing_tween and _swing_tween.is_valid():
		_swing_tween.kill() # chaining: the next swing winds up from wherever the last one got to
	_blade_weapon = null
	_busy = true

	# attackSpeed = seconds per swing (0.4 by default).
	var duration := maxf(0.15, weapon.attackSpeed)
	var windup := duration * hit_moment
	var recover := duration - windup
	_chain_at_msec = Time.get_ticks_msec() + int(duration * (1.0 - chain_window) * 1000.0)

	var t := create_tween()
	_swing_tween = t
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
	t.tween_callback(_end_swing) # not awaited: a chained swing kills this tween, and a killed tween never finishes

func _end_swing() -> void:
	_blade_weapon = null
	_busy = false

## Attack for the weapon's category and the most recently pressed move key that's still held.
func _pick_swing(weapon: WeaponItem) -> Resource:
	var dir: String = MOVE_DIRS[_held_dirs.back()] if not _held_dirs.is_empty() else "still"
	var cat: String = weapon.category
	return swings.get("%s_%s" % [cat, dir], swings.get(cat + "_still"))

func _open_blade(weapon: WeaponItem) -> void:
	_blade_weapon = weapon
	_blade_prev = _blade_points()

func _physics_process(_delta: float) -> void:
	if Engine.is_editor_hint() or _blade_weapon == null:
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

# ---------- editor preview ----------

func _validate_property(property: Dictionary) -> void:
	if property.name == "preview_timeline":
		property.hint_string = "0,%s,0.01,suffix:s" % _preview_duration() # slider ends at the weapon's attackSpeed

func _preview_duration() -> float:
	return maxf(0.15, float(preview_item.get("attackSpeed")) if preview_item else 0.4) # same floor as swing()

func _process(delta: float) -> void:
	if not Engine.is_editor_hint():
		set_process(false)
		return
	var s: Resource = swings.get(preview_swing)
	if not show_preview or not swing_pivot or not s:
		_clear_preview()
		return
	if not is_instance_valid(_ghost):
		_spawn_preview()
	var d := _preview_duration()
	if preview_play:
		preview_timeline = fmod(preview_timeline + delta / preview_slow_motion, d + 0.3) # brief pause at rest
	var p := _preview_pose(s, minf(preview_timeline, d), d)
	_ghost.rotation_degrees = swing_pivot.rotation_degrees + p[0]
	_ghost.position = swing_pivot.position + p[1]

## [rotation offset, position offset] at time t, matching the tweens in swing().
func _preview_pose(s: Resource, t: float, d: float) -> Array:
	var windup := d * hit_moment * 0.6
	var strike := d * hit_moment * 0.4
	var recover := d - windup - strike
	var wr: Vector3 = s.get("windup_rotation")
	var wo: Vector3 = s.get("windup_offset")
	var sr: Vector3 = s.get("strike_rotation")
	var so: Vector3 = s.get("strike_offset")
	var lead: bool = s.get("hand_leads")
	if t < windup:
		var k: float = Tween.interpolate_value(0.0, 1.0, t, windup, Tween.TRANS_SINE, Tween.EASE_OUT)
		return [Vector3.ZERO.lerp(wr, k), Vector3.ZERO.lerp(wo, k)]
	if t < windup + strike:
		var kr: float = Tween.interpolate_value(0.0, 1.0, t - windup, strike, Tween.TRANS_CUBIC if lead else Tween.TRANS_QUAD, Tween.EASE_IN)
		var kp: float = Tween.interpolate_value(0.0, 1.0, t - windup, strike, Tween.TRANS_SINE if lead else Tween.TRANS_QUAD, Tween.EASE_OUT if lead else Tween.EASE_IN)
		return [wr.lerp(sr, kr), wo.lerp(so, kp)]
	var k: float = Tween.interpolate_value(0.0, 1.0, t - windup - strike, recover, Tween.TRANS_SINE, Tween.EASE_IN_OUT)
	return [sr.lerp(Vector3.ZERO, k), so.lerp(Vector3.ZERO, k)]

func _spawn_preview() -> void:
	_ghost = Node3D.new()
	_ghost.name = "_swing_preview"
	swing_pivot.get_parent().add_child(_ghost) # no owner, so it's never written into the scene; the real hand isn't moved
	if not preview_item:
		return
	var scene: PackedScene = preview_item.get("heldScene")
	if not scene:
		scene = preview_item.get("itemScene")
	if not scene:
		return
	var w := scene.instantiate() as Node3D
	if w:
		w.position = preview_item.get("heldPosition")
		w.rotation_degrees = preview_item.get("heldRotation")
		w.scale = preview_item.get("heldScale")
		_ghost.add_child(w)

func _clear_preview() -> void:
	if is_instance_valid(_ghost):
		_ghost.queue_free()
	_ghost = null

func _exit_tree() -> void:
	_clear_preview()
