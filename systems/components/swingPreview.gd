@tool
extends Node
## Editor-only: shows a held weapon in a melee swing pose so you can tune MeleeComponent.swings in the viewport.
## Tick show_preview, pick a swing, then drag timeline (seconds, 0 to the weapon's attackSpeed) or tick play.
## Same timing and easing as MeleeComponent: rest -> windup -> strike -> back to rest.
## The preview is never saved and the real hand marker isn't touched. Does nothing in game.

@export var melee: Node
## The hand marker the swing moves (melee's swing_pivot). Set here because the editor can't read melee's node links.
@export var hand: Node3D
## Weapon to hold in the preview (an Item .tres). Its attackSpeed sets the timeline length.
@export var preview_item: Resource:
	set(v):
		preview_item = v
		_clear()
		notify_property_list_changed()
## Key in melee.swings, e.g. "sword_right".
@export var swing := "sword_right"
## Seconds into the swing.
@export_range(0.0, 1.0, 0.01, "suffix:s") var timeline := 0.0
## Loop the swing automatically.
@export var play := false
## Slow the playback down to study it: 1 = game speed, 4 = four times slower.
@export_range(1.0, 10.0, 0.5) var slow_motion := 1.0
@export var show_preview := false:
	set(v):
		show_preview = v
		_clear()

var _ghost: Node3D

func _validate_property(property: Dictionary) -> void:
	if property.name == "timeline":
		property.hint_string = "0,%s,0.01,suffix:s" % _duration() # slider ends at the weapon's attackSpeed

func _duration() -> float:
	return maxf(0.15, float(preview_item.get("attackSpeed")) if preview_item else 0.4) # same floor as MeleeComponent

func _process(delta: float) -> void:
	if not Engine.is_editor_hint():
		set_process(false)
		return
	if not show_preview or not melee or not hand:
		_clear()
		return
	var swings: Dictionary = melee.get("swings")
	var s: Resource = swings.get(swing) if swings else null
	if not s:
		_clear()
		return
	if not is_instance_valid(_ghost):
		_spawn(hand)
	var d := _duration()
	if play:
		timeline = fmod(timeline + delta / slow_motion, d + 0.3) # brief pause at rest before looping
	var p := _pose(s, minf(timeline, d), d)
	_ghost.rotation_degrees = hand.rotation_degrees + p[0]
	_ghost.position = hand.position + p[1]

## [rotation offset, position offset] at time t, matching the tweens in MeleeComponent.swing().
func _pose(s: Resource, t: float, d: float) -> Array:
	var h: float = melee.get("hit_moment")
	var windup := d * h * 0.6
	var strike := d * h * 0.4
	var recover := d - windup - strike
	var wr: Vector3 = s.get("windup_rotation")
	var wo: Vector3 = s.get("windup_offset")
	var sr: Vector3 = s.get("strike_rotation")
	var so: Vector3 = s.get("strike_offset")
	if t < windup:
		var k: float = Tween.interpolate_value(0.0, 1.0, t, windup, Tween.TRANS_SINE, Tween.EASE_OUT)
		return [Vector3.ZERO.lerp(wr, k), Vector3.ZERO.lerp(wo, k)]
	if t < windup + strike:
		var lead: bool = s.get("hand_leads")
		var kr: float = Tween.interpolate_value(0.0, 1.0, t - windup, strike, Tween.TRANS_CUBIC if lead else Tween.TRANS_QUAD, Tween.EASE_IN)
		var kp: float = Tween.interpolate_value(0.0, 1.0, t - windup, strike, Tween.TRANS_SINE if lead else Tween.TRANS_QUAD, Tween.EASE_OUT if lead else Tween.EASE_IN)
		return [wr.lerp(sr, kr), wo.lerp(so, kp)]
	var k: float = Tween.interpolate_value(0.0, 1.0, t - windup - strike, recover, Tween.TRANS_SINE, Tween.EASE_IN_OUT)
	return [sr.lerp(Vector3.ZERO, k), so.lerp(Vector3.ZERO, k)]

func _spawn(marker: Node3D) -> void:
	_ghost = Node3D.new()
	_ghost.name = "_swing_preview"
	marker.get_parent().add_child(_ghost) # no owner, so it's never written into the scene
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

func _clear() -> void:
	if is_instance_valid(_ghost):
		_ghost.queue_free()
	_ghost = null

func _exit_tree() -> void:
	_clear()
