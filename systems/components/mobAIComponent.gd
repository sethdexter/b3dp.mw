class_name MobAIComponent
extends Node

## Simple mob brain for a BaseCharacter (CharacterBody3D):
##   IDLE   -> stands around for a bit
##   WANDER -> strolls to a random point near home
##   CHASE  -> spotted the player (or got hit): runs at them and attacks in range
##   RETURN -> lost the player / dragged too far from home: walks back
## Movement is direct steering (no navmesh yet), so it can get snagged on walls;
## when stuck it just picks a new spot.

enum State { IDLE, WANDER, CHASE, RETURN }

@export var character: BaseCharacter
## Node animated for walking bob and attacks (pivot at the feet).
@export var visual: Node3D
## Optional MobModel (or any node with set_move_speed(speed)) to drive walk animation.
@export var animator: Node

@export_group("Wandering")
@export var wanders := true
@export var wander_radius: float = 5.0
@export var wander_speed: float = 1.2
@export var idle_time_min: float = 1.5
@export var idle_time_max: float = 4.0

@export_group("Aggro")
@export var aggressive := true
## Notices the player within this distance...
@export var aggro_range: float = 8.0
## ...only if it has line of sight.
@export var needs_line_of_sight := true
## Getting hit always makes it chase.
@export var aggro_on_hit := true
## Gives up when the player gets this far away.
@export var lose_aggro_range: float = 14.0
## Gives up when dragged this far from home.
@export var leash_range: float = 18.0
@export var chase_speed: float = 3.0

@export_group("Attack")
@export var attack_range: float = 1.8
@export var attack_damage: int = 2
## Seconds between swings.
@export var attack_interval: float = 1.6
## Lean-back warning before the hit lands (dodge window).
@export var telegraph_time: float = 0.35

@export_group("Movement feel")
@export var acceleration: float = 8.0
@export var turn_speed: float = 6.0
## Side-to-side sway while walking (degrees).
@export var walk_bob_degrees: float = 4.0

var state: State = State.IDLE
var is_attacking := false

var _home: Vector3
var _target_point: Vector3
var _state_time := 0.0
var _idle_duration := 2.0
var _next_attack_msec := 0
var _attack_tween: Tween
var _bob_time := 0.0
var _last_health := -1
var _last_pos: Vector3
var _stuck_time := 0.0

func _ready() -> void:
	if not character:
		character = get_parent() as BaseCharacter
	_home = character.global_position
	_last_pos = _home
	_enter(State.IDLE)
	if character.statComponent and character.statComponent.health:
		_last_health = character.statComponent.health.currentValue
		character.statComponent.health.value_changed.connect(_on_health_changed)

func _on_health_changed(current: int, _max_val: int) -> void:
	if aggro_on_hit and _last_health >= 0 and current < _last_health and not character.is_dead:
		if _find_player():
			_enter(State.CHASE)
	_last_health = current

# --- state machine ----------------------------------------------------------

func _enter(new_state: State) -> void:
	state = new_state
	_state_time = 0.0
	_stuck_time = 0.0
	match state:
		State.IDLE:
			_idle_duration = randf_range(idle_time_min, idle_time_max)
		State.WANDER:
			var angle := randf() * TAU
			var r := sqrt(randf()) * wander_radius
			_target_point = _home + Vector3(cos(angle) * r, 0.0, sin(angle) * r)

func _physics_process(delta: float) -> void:
	if not character:
		return
	if character.is_dead:
		# Collision is off while down/dead, so don't move at all (would fall through the floor).
		_cancel_attack()
		character.velocity = Vector3.ZERO
		return

	_apply_gravity(delta)

	_state_time += delta
	var player := _find_player()
	var desired := Vector3.ZERO
	var speed := 0.0

	match state:
		State.IDLE:
			if _try_aggro(player):
				return
			if wanders and _state_time >= _idle_duration:
				_enter(State.WANDER)

		State.WANDER:
			if _try_aggro(player):
				return
			var to_target := _flat(_target_point - character.global_position)
			if to_target.length() < 0.4 or _state_time > 8.0 or _is_stuck(delta):
				_enter(State.IDLE)
			else:
				desired = to_target.normalized()
				speed = wander_speed

		State.CHASE:
			if player == null or player.is_dead \
					or _flat(player.global_position - character.global_position).length() > lose_aggro_range \
					or _flat(character.global_position - _home).length() > leash_range:
				_enter(State.RETURN)
			else:
				var to_player := _flat(player.global_position - character.global_position)
				var dist := to_player.length()
				_face(to_player, delta)
				if is_attacking:
					pass # stand still while swinging
				elif dist > attack_range * 0.85:
					desired = to_player.normalized()
					speed = chase_speed
				elif Time.get_ticks_msec() >= _next_attack_msec:
					_attack(player)

		State.RETURN:
			var to_home := _flat(_home - character.global_position)
			if to_home.length() < 0.5 or _is_stuck(delta):
				_enter(State.IDLE)
			else:
				desired = to_home.normalized()
				speed = wander_speed * 1.5
				# Can re-aggro once it's back near home.
				if to_home.length() < wander_radius and _try_aggro(player):
					return

	if desired != Vector3.ZERO and state != State.CHASE:
		_face(desired, delta)
	_steer(desired, speed, delta)
	character.move_and_slide()
	_walk_bob(speed, delta)

	if character.global_position.y < -50.0:
		character.global_position = _home
		character.velocity = Vector3.ZERO

func _try_aggro(player: BaseCharacter) -> bool:
	if not aggressive or player == null or player.is_dead:
		return false
	if _flat(player.global_position - character.global_position).length() > aggro_range:
		return false
	if needs_line_of_sight and not _can_see(player):
		return false
	_enter(State.CHASE)
	return true

# --- movement ---------------------------------------------------------------

func _apply_gravity(delta: float) -> void:
	if not character.is_on_floor():
		character.velocity.y -= ProjectSettings.get_setting("physics/3d/default_gravity") * delta
	else:
		character.velocity.y = 0.0

func _steer(dir: Vector3, speed: float, delta: float) -> void:
	var target := dir * speed
	var rate := 1.0 - exp(-acceleration * delta)
	character.velocity.x = lerpf(character.velocity.x, target.x, rate)
	character.velocity.z = lerpf(character.velocity.z, target.z, rate)

func _face(dir: Vector3, delta: float) -> void:
	if dir.length() < 0.01:
		return
	var target_yaw := atan2(-dir.x, -dir.z)
	character.rotation.y = lerp_angle(character.rotation.y, target_yaw, 1.0 - exp(-turn_speed * delta))

## True if it has barely moved for a while despite trying (snagged on something).
func _is_stuck(delta: float) -> bool:
	var moved := _flat(character.global_position - _last_pos).length()
	_last_pos = character.global_position
	if moved < 0.2 * wander_speed * delta:
		_stuck_time += delta
	else:
		_stuck_time = 0.0
	return _stuck_time > 1.0

func _walk_bob(speed: float, delta: float) -> void:
	if animator and animator.has_method("set_move_speed"):
		animator.set_move_speed(_flat(character.velocity).length())
	if not visual:
		return
	var moving := _flat(character.velocity).length() > 0.2 and not is_attacking
	if moving:
		_bob_time += delta * (4.0 + speed * 2.0)
		visual.rotation_degrees.z = sin(_bob_time) * walk_bob_degrees
	else:
		visual.rotation_degrees.z = lerpf(visual.rotation_degrees.z, 0.0, 1.0 - exp(-10.0 * delta))

func _flat(v: Vector3) -> Vector3:
	return Vector3(v.x, 0.0, v.z)

# --- senses -----------------------------------------------------------------

func _find_player() -> BaseCharacter:
	var players := get_tree().get_nodes_in_group("player")
	return players[0] as BaseCharacter if not players.is_empty() else null

func _can_see(player: BaseCharacter) -> bool:
	var from := character.global_position + Vector3.UP * 1.5
	var to := player.global_position + Vector3.UP * 1.0
	var query := PhysicsRayQueryParameters3D.create(from, to)
	query.exclude = [character.get_rid()]
	var hit := character.get_world_3d().direct_space_state.intersect_ray(query)
	return hit.is_empty() or hit.collider == player

# --- attack -----------------------------------------------------------------

func _attack(player: BaseCharacter) -> void:
	is_attacking = true
	_next_attack_msec = Time.get_ticks_msec() + int(attack_interval * 1000.0)

	# Real attack clip if the model has one; otherwise fake it with a lean/lunge.
	var animated: bool = animator != null and animator.has_method("play_attack") and animator.play_attack()
	if animated:
		await get_tree().create_timer(telegraph_time + 0.12).timeout
	elif visual:
		_attack_tween = create_tween()
		_attack_tween.tween_property(visual, "rotation_degrees:x", 15.0, telegraph_time) \
			.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
		_attack_tween.tween_property(visual, "rotation_degrees:x", -30.0, 0.12) \
			.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
		await _attack_tween.finished
	else:
		await get_tree().create_timer(telegraph_time + 0.12).timeout
	if not is_attacking:
		return # cancelled (knocked down)

	# Only lands if still standing and the player is still in reach.
	if not character.is_dead and is_instance_valid(player) and not player.is_dead \
			and character.global_position.distance_to(player.global_position) <= attack_range + 0.3 \
			and player.combatComponent and player.statComponent:
		print("%s strikes %s!" % [character.Name, player.Name])
		player.combatComponent.take_damage(player.statComponent.health, attack_damage)

	if visual and not character.is_dead and not animated:
		_attack_tween = create_tween()
		_attack_tween.tween_property(visual, "rotation_degrees:x", 0.0, 0.3) \
			.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
		await _attack_tween.finished
	is_attacking = false

func _cancel_attack() -> void:
	if _attack_tween and _attack_tween.is_valid():
		_attack_tween.kill()
		# A killed tween never emits finished, so release the coroutine's flag here.
	is_attacking = false
