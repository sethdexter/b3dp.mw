class_name MeleeComponent
extends Node

## Left click swings the equipped right-hand weapon.
## Hit check is a ray from the camera; damage comes from CombatComponent.attack().
## Ignored while the inventory/container UI is open (it uses left click).

@export var character: BaseCharacter
## Ray starts here, along its -Z (the camera).
@export var aim_origin: Node3D
## Node rotated for the swing animation (the right hand marker).
@export var swing_pivot: Node3D

@export_group("Reach")
## Reach in metres = base_reach * weapon.range.
@export var base_reach: float = 2.0

## Stamina per swing. Can't swing without enough.
@export var swing_stamina_cost: float = 1.0

@export_group("Swing animation")
@export var windup_rotation := Vector3(25, -20, 10)
@export var strike_rotation := Vector3(-55, 35, -15)
## Fraction of the swing at which the hit lands (0-1).
@export_range(0.0, 1.0) var hit_moment: float = 0.45

var _busy := false
var _rest_rotation := Vector3.ZERO

func _ready() -> void:
	if not character:
		character = get_parent() as BaseCharacter
	if swing_pivot:
		_rest_rotation = swing_pivot.rotation_degrees

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

	if swing_pivot:
		var t := create_tween()
		t.tween_property(swing_pivot, "rotation_degrees", _rest_rotation + windup_rotation, windup * 0.6) \
			.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
		t.tween_property(swing_pivot, "rotation_degrees", _rest_rotation + strike_rotation, windup * 0.4) \
			.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
		t.tween_callback(_strike.bind(weapon))
		t.tween_property(swing_pivot, "rotation_degrees", _rest_rotation, recover) \
			.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
		await t.finished
	else:
		await get_tree().create_timer(windup).timeout
		_strike(weapon)
		await get_tree().create_timer(recover).timeout
	_busy = false

func _strike(weapon: WeaponItem) -> void:
	var target := _find_target(base_reach * maxf(0.5, float(weapon.range)))
	if target and character.combatComponent:
		character.combatComponent.attack(target, weapon)

func _find_target(reach: float) -> BaseCharacter:
	if not aim_origin:
		return null
	var from := aim_origin.global_position
	var to := from - aim_origin.global_basis.z * reach
	var query := PhysicsRayQueryParameters3D.create(from, to)
	query.exclude = [character.get_rid()]
	var hit := character.get_world_3d().direct_space_state.intersect_ray(query)
	if hit.is_empty():
		return null
	return hit.collider as BaseCharacter

func _weapon() -> WeaponItem:
	if character and character.equipmentComponent:
		return character.equipmentComponent.get_weapon()
	return null

func _inventory_open() -> bool:
	for child in character.get_children():
		if child is PlayerInventoryUI:
			return child.is_open
	return false
