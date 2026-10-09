class_name TrainingDummy
extends Node

## Behaviour for a training dummy: falls to the floor, wobbles when hit,
## topples over at 0 health, then stands back up with full health.
## With fights_back on, it turns to face the player and swings when they're close.

@export var character: BaseCharacter
## Node that wobbles/topples (pivot should be at the dummy's feet).
@export var visual: Node3D
@export var respawn_time: float = 3.0
@export var wobble_degrees: float = 12.0

@export_group("Fighting back")
@export var fights_back := true
## Starts tracking the player within this distance (metres).
@export var aggro_range: float = 4.0
## Swings when the player is within this distance.
@export var attack_range: float = 1.8
@export var attack_damage: int = 2
## Seconds between swings.
@export var attack_interval: float = 1.6
## How fast it turns to face the player.
@export var turn_speed: float = 6.0

@onready var _collision: CollisionShape3D = character.get_node_or_null("CollisionShape3D") if character else null

var _start_position: Vector3
var _down := false
var _wobble: Tween
var _attacking := false
var _next_attack_msec := 0

func _ready() -> void:
	if not character:
		character = get_parent() as BaseCharacter
	if not character or not character.statComponent:
		push_error("TrainingDummy: needs a BaseCharacter parent with a StatsComponent.")
		return
	_start_position = character.global_position
	var health: Stat = character.statComponent.health
	health.value_changed.connect(_on_health_changed)
	health.depleted.connect(_on_depleted)

var _last_health := -1

func _on_health_changed(current: int, _max_val: int) -> void:
	if _last_health >= 0 and current < _last_health and not _down:
		_play_wobble()
	_last_health = current

func _play_wobble() -> void:
	if not visual:
		return
	if _wobble and _wobble.is_valid():
		_wobble.kill()
	visual.rotation_degrees.x = 0.0
	_wobble = create_tween()
	_wobble.tween_property(visual, "rotation_degrees:x", -wobble_degrees, 0.06)
	_wobble.tween_property(visual, "rotation_degrees:x", wobble_degrees * 0.5, 0.12)
	_wobble.tween_property(visual, "rotation_degrees:x", 0.0, 0.18)

func _on_depleted() -> void:
	if _down:
		return
	_down = true
	print("%s is knocked down." % character.Name)
	if _wobble and _wobble.is_valid():
		_wobble.kill()
	if _collision:
		_collision.set_deferred("disabled", true)
	if visual:
		var fall := create_tween()
		fall.tween_property(visual, "rotation_degrees:x", -85.0, 0.5) \
			.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	await get_tree().create_timer(respawn_time).timeout
	_stand_up()

func _stand_up() -> void:
	var health: Stat = character.statComponent.health
	health.change_current(health.get_max_value())
	_last_health = health.currentValue
	if visual:
		var rise := create_tween()
		rise.tween_property(visual, "rotation_degrees:x", 0.0, 0.6) \
			.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
		await rise.finished
	if _collision:
		_collision.disabled = false
	_down = false

func _physics_process(delta: float) -> void:
	if not character:
		return
	# Simple gravity so it settles on whatever floor it's placed above.
	if not character.is_on_floor():
		character.velocity.y -= ProjectSettings.get_setting("physics/3d/default_gravity") * delta
	else:
		character.velocity.y = 0.0
	character.velocity.x = 0.0
	character.velocity.z = 0.0
	character.move_and_slide()
	if fights_back and not _down:
		_update_fighting(delta)
	if character.global_position.y < -50.0:
		character.global_position = _start_position
		character.velocity = Vector3.ZERO

# --- fighting back ----------------------------------------------------------

func _find_player() -> BaseCharacter:
	var players := get_tree().get_nodes_in_group("player")
	return players[0] as BaseCharacter if not players.is_empty() else null

func _update_fighting(delta: float) -> void:
	var player := _find_player()
	if not player:
		return
	var to_player := player.global_position - character.global_position
	to_player.y = 0.0
	var dist := to_player.length()
	if dist > aggro_range or dist < 0.01:
		return

	# Turn to face the player (yaw only).
	var target_yaw := atan2(-to_player.x, -to_player.z)
	character.rotation.y = lerp_angle(character.rotation.y, target_yaw, 1.0 - exp(-turn_speed * delta))

	if dist <= attack_range and not _attacking and Time.get_ticks_msec() >= _next_attack_msec:
		_attack(player)

func _attack(player: BaseCharacter) -> void:
	_attacking = true
	_next_attack_msec = Time.get_ticks_msec() + int(attack_interval * 1000.0)
	if _wobble and _wobble.is_valid():
		_wobble.kill()

	# Lean back (telegraph), lunge forward, then recover.
	if visual:
		var t := create_tween()
		t.tween_property(visual, "rotation_degrees:x", 15.0, 0.35) \
			.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
		t.tween_property(visual, "rotation_degrees:x", -30.0, 0.12) \
			.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
		await t.finished
	else:
		await get_tree().create_timer(0.45).timeout

	# Only lands if still standing and the player is still in reach.
	if not _down and is_instance_valid(player) \
			and character.global_position.distance_to(player.global_position) <= attack_range + 0.3 \
			and player.combatComponent and player.statComponent:
		print("%s strikes %s!" % [character.Name, player.Name])
		player.combatComponent.take_damage(player.statComponent.health, attack_damage)

	if visual and not _down:
		var back := create_tween()
		back.tween_property(visual, "rotation_degrees:x", 0.0, 0.3) \
			.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
		await back.finished
	_attacking = false
