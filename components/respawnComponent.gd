class_name RespawnComponent
extends Node

## On death: camera slumps, screen fades to black, then the player respawns at the
## spawn point with full health/magicka/stamina.

@export var character: BaseCharacter
@export var camera: Node3D
@export var screen_effects: ScreenEffects
## Where to respawn. Empty = where the player started.
@export var spawn_point: Node3D

@export var fade_out_time: float = 1.4
@export var hold_time: float = 1.0
@export var fade_in_time: float = 1.0
## Camera drops this far and rolls this many degrees as you fall.
@export var death_camera_drop: float = 1.0
@export var death_camera_roll: float = 70.0

var _spawn_transform: Transform3D
var _camera_rest_position: Vector3
var _camera_rest_rotation: Vector3

func _ready() -> void:
	if not character:
		character = get_parent() as BaseCharacter
	_spawn_transform = spawn_point.global_transform if spawn_point else character.global_transform
	if camera:
		_camera_rest_position = camera.position
		_camera_rest_rotation = camera.rotation_degrees
	if character.statComponent:
		character.statComponent.s_has_died.connect(_on_died)

func _on_died() -> void:
	if character.is_dead:
		return
	character.is_dead = true
	_close_inventory()

	if camera:
		var slump := create_tween().set_parallel(true)
		slump.tween_property(camera, "position:y", _camera_rest_position.y - death_camera_drop, fade_out_time * 0.6) \
			.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
		slump.tween_property(camera, "rotation_degrees:z", death_camera_roll, fade_out_time * 0.6) \
			.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)

	if screen_effects:
		await screen_effects.fade_to(1.0, fade_out_time).finished
	else:
		await get_tree().create_timer(fade_out_time).timeout
	await get_tree().create_timer(hold_time).timeout
	_respawn()

func _respawn() -> void:
	character.global_transform = _spawn_transform
	character.velocity = Vector3.ZERO
	if camera:
		camera.position = _camera_rest_position
		camera.rotation_degrees = _camera_rest_rotation
	if character.statComponent:
		character.statComponent.restore_all()
	character.is_dead = false
	print("%s respawned." % character.Name)
	if screen_effects:
		screen_effects.fade_to(0.0, fade_in_time)

func _close_inventory() -> void:
	for child in character.get_children():
		if child is PlayerInventoryUI and child.is_open:
			child.close()
