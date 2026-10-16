class_name HeadBobComponent
extends Node

## First-person head bob: the camera dips and sways while walking. Held items read held_offset() to sway along.
## Scales with speed, fades out when standing still, in the air or dead.

@export var character: CharacterBody3D
@export var camera_node: Node3D

## Metres the camera dips per step at reference speed.
@export_range(0.0, 0.2, 0.001, "suffix:m") var bob_amount: float = 0.035
## Side-to-side sway, as a fraction of the dip.
@export_range(0.0, 2.0, 0.05) var sway_ratio: float = 0.5
## Strides per second at reference speed (two dips per stride).
@export_range(0.1, 5.0, 0.05) var bob_frequency: float = 1.8
## Speed that gives a full-size bob (the controller's run speed). Faster = bigger, up to max_scale.
@export_range(0.5, 10.0, 0.1, "suffix:m/s") var reference_speed: float = 3.8
@export_range(1.0, 3.0, 0.05) var max_scale: float = 1.6
## How far the view sinks when fully crouched.
@export_range(0.0, 2.0, 0.05, "suffix:m") var crouch_drop: float = 1.0
## How fast the bob eases in and out.
@export_range(1.0, 30.0, 0.5) var smoothing: float = 8.0

var _phase := 0.0
var _weight := 0.0
var _camera_rest := Vector3.ZERO

func _ready() -> void:
	if not character:
		character = get_parent() as CharacterBody3D
	if camera_node:
		_camera_rest = camera_node.position

func _process(delta: float) -> void:
	if not character or not camera_node:
		return
	var speed := Vector2(character.velocity.x, character.velocity.z).length()
	var grounded: bool = character.is_on_floor() and character.get("is_dead") != true
	var target := clampf(speed / reference_speed, 0.0, max_scale) if grounded else 0.0
	_weight = lerpf(_weight, target, 1.0 - exp(-smoothing * delta)) # ease in/out instead of snapping
	_phase = fmod(_phase + delta * TAU * bob_frequency * maxf(_weight, 0.3), TAU * 2.0)
	var amp := bob_amount * _weight
	# dip twice per stride, sway side to side once
	var controller = character.get("controllerComponent")
	var crouch: float = controller.crouch_blend if controller else 0.0
	camera_node.position = _camera_rest + Vector3(sin(_phase) * amp * sway_ratio, -absf(sin(_phase)) * amp - crouch_drop * crouch, 0.0)

## Offset for a held item that sways `sway` metres and trails the camera's bob by `lag` radians of the stride.
func held_offset(sway: float, lag: float) -> Vector3:
	var p := _phase - lag
	var h := sway * _weight
	return Vector3(sin(p) * h, -absf(sin(p)) * h, 0.0)
