class_name MobAIComponent
extends Node

## Simple mob brain for a BaseCharacter (CharacterBody3D):
##   IDLE   -> stands around for a bit
##   WANDER -> strolls to a random point near home
##   CHASE  -> spotted the player (or got hit): runs at them and attacks in range
##   RETURN -> lost the player / dragged too far from home: walks back
## Movement follows the navmesh via its own NavigationAgent3D (straight line if the
## level has no navmesh); when stuck it just picks a new spot.

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
## Notices you this many times further off while you're in the dark (player's DarknessComponent).
@export_range(1.0, 4.0, 0.05) var dark_aggro_multiplier := 1.6
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
## Set by group AI to fight someone other than the player; falls back to the player once it's dead.
var foe: BaseCharacter
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
var _nav := NavigationAgent3D.new()

func _ready() -> void:
	if not character:
		character = get_parent() as BaseCharacter
	character.add_child.call_deferred(_nav)
	_home = character.global_position
	_last_pos = _home
	_enter(State.IDLE)
	if character.statComponent and character.statComponent.health:
		_last_health = character.statComponent.health.currentValue
		character.statComponent.health.value_changed.connect(_on_health_changed)

func _on_health_changed(current: int, _max_val: int) -> void:
	if aggro_on_hit and not sim_hurt and _last_health >= 0 and current < _last_health and not character.is_dead:
		if not is_instance_valid(foe): # hurt with no fight on: it was you
			_angry = true
		if _find_player() or is_instance_valid(foe):
			_enter(State.CHASE)
	_last_health = current

# --- state machine ----------------------------------------------------------

func _enter(new_state: State) -> void:
	state = new_state
	_state_time = 0.0
	_stuck_time = 0.0
	_detour = Vector3.INF
	_detours = 0
	match state:
		State.IDLE:
			_idle_duration = randf_range(idle_time_min, idle_time_max)
		State.WANDER:
			var angle := randf() * TAU
			var r := lerpf(0.5, 1.0, sqrt(randf())) * wander_radius # a real stroll: a near point ends at once and they sit straight back down
			_target_point = _home + Vector3(cos(angle) * r, 0.0, sin(angle) * r)

## Beyond this from the player it holds still: terrain and tree colliders only exist near the player.
const SLEEP_RANGE := 50.0
var _asleep := false

## Drops it onto whatever is under it now, so it doesn't wake up inside tree roots that weren't there before.
func _settle() -> void:
	var from := character.global_position + Vector3.UP * 12.0
	var q := PhysicsRayQueryParameters3D.create(from, from + Vector3.DOWN * 30.0)
	q.exclude = [character.get_rid()]
	var hit := character.get_world_3d().direct_space_state.intersect_ray(q)
	if hit:
		character.global_position = hit.position + Vector3.UP * 0.05
	character.velocity = Vector3.ZERO

func _physics_process(delta: float) -> void:
	if not character:
		return
	var p := _find_player()
	if p and _flat(p.global_position - character.global_position).length() > SLEEP_RANGE:
		character.velocity = Vector3.ZERO
		_asleep = true
		return
	if _asleep:
		_asleep = false
		_settle()
	if character.is_dead:
		# Collision is off while down/dead, so don't move at all (would fall through the floor).
		_cancel_attack()
		character.velocity = Vector3.ZERO
		return

	_apply_gravity(delta)
	if Time.get_ticks_msec() < hold_until_ms and state != State.CHASE: # being talked to: stand and face you (a blow or a foe breaks it: CHASE)
		var you := _find_player()
		if you:
			_face(_flat(you.global_position - character.global_position), delta)
		character.velocity = Vector3(0.0, character.velocity.y, 0.0)
		character.move_and_slide()
		_walk_bob(0.0, delta)
		return

	_state_time += delta
	var player := foe if is_instance_valid(foe) and not foe.is_dead else _find_player()
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
				desired = _path_dir(_target_point, to_target)
				speed = wander_speed

		State.CHASE:
			if not is_instance_valid(foe) and not aggressive and not _angry: # their fight's over, and you never hit them
				_enter(State.RETURN)
			elif player == null or player.is_dead \
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
					desired = _path_dir(player.global_position, to_player)
					speed = chase_speed
				elif Time.get_ticks_msec() >= _next_attack_msec:
					_attack(player)

		State.RETURN:
			if sim_speed > 0.0: # one of the sim's characters: the body only shows the record's walk
				_puppet(delta)
				return
			var to_home := _flat(_home - character.global_position)
			var goal: Vector3 = _detour if _detour.is_finite() else _home
			var to_goal := _flat(goal - character.global_position)
			if _detour.is_finite() and to_goal.length() < 0.6:
				_detour = Vector3.INF # round it: on for home
			elif to_home.length() < 0.5:
				_enter(State.IDLE)
			elif _is_stuck(delta): # snagged (a trunk, a rock, each other): step aside, left then right, wider each time
				_detours += 1
				_stuck_time = 0.0
				if _detours > 6:
					_enter(State.IDLE) # give up; the sim's unstick puts them past it
				else:
					var side := to_home.normalized().cross(Vector3.UP) * (1.0 if _detours % 2 == 1 else -1.0)
					_detour = character.global_position + side * (1.5 + _detours) + to_home.normalized()
			else:
				desired = _path_dir(goal, to_goal)
				speed = sim_speed if sim_speed > 0.0 else wander_speed * 1.5 # a character walks at the sim's pace
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
	var dark: Node = player.get_node_or_null("darkness")
	var reach := aggro_range * (dark_aggro_multiplier if dark and dark.get("in_dark") else 1.0)
	if Time.get_ticks_msec() < player.get_meta("shrouded_until", 0): # Shroud (Nox): the dark hides you
		reach *= player.get_meta("shroud_reach", 0.25)
	if _flat(player.global_position - character.global_position).length() > reach:
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
	var target := _round_trees(dir) * speed
	var rate := 1.0 - exp(-acceleration * delta)
	character.velocity.x = lerpf(character.velocity.x, target.x, rate)
	character.velocity.z = lerpf(character.velocity.z, target.z, rate)

## The dead trees aren't in the navmesh: bend dir round any trunk in the way, by the same rule the sim's records
## walk by (DeadTrees.round_trees), so a body near you and its record far off take the same way round.
func _round_trees(dir: Vector3) -> Vector3:
	if dir.length() < 0.01:
		return dir
	if _trees == null:
		var camps := get_tree().get_first_node_in_group("camps")
		_trees = camps.get("trees") if camps else null
		if _trees == null:
			return dir
	return _trees.round_trees(character.global_position, dir)

var _trees = null # the DeadTrees node (its _trunks lookup)
## Set by Camps for its characters: walking somewhere (RETURN) is the record's walk, shown. The same step as the
## record takes far off (Camps._walk: walk_speed, round the trees), on the ground, no physics, so loaded is only a look.
## (Fights near you are the one thing a body does for itself: CHASE / attack.)
var sim_speed := 0.0
## Talker sets this while you talk to them (or trade): they hold still and face you until then, unless a fight starts.
var hold_until_ms := 0
## Set by Camps while it syncs record health to the body (the dark, hunger): a hurt that isn't a blow.
var sim_hurt := false
var _angry := false # you hurt it: it comes for you even though it isn't aggressive

func _puppet(delta: float) -> void:
	var to_home := _flat(_home - character.global_position)
	if to_home.length() < 0.3:
		character.velocity = Vector3.ZERO
		_enter(State.IDLE)
		return
	var camps := get_tree().get_first_node_in_group("camps")
	if not camps:
		return
	var step: Vector3 = camps._walk(character.global_position, _home, delta)
	var p: Vector3 = camps._ground(character.global_position + step)
	if not is_nan(p.y):
		character.global_position = p + Vector3.UP * 0.1
	character.velocity = step / maxf(delta, 0.001) # for the walk animation only
	_face(step, delta)
	_walk_bob(sim_speed, delta)
var _detour := Vector3.INF # a step aside round something it snagged on (RETURN)
var _detours := 0

## Direction to the next navmesh path point toward target; straight line if no navmesh yet.
func _path_dir(target: Vector3, straight: Vector3) -> Vector3:
	if not _nav.is_inside_tree() or NavigationServer3D.map_get_iteration_id(_nav.get_navigation_map()) == 0:
		return straight.normalized()
	if _nav.target_position.distance_to(target) > 0.5:
		_nav.target_position = target
	if _nav.is_navigation_finished():
		return straight.normalized()
	var dir := _flat(_nav.get_next_path_position() - character.global_position)
	return dir.normalized() if dir.length() > 0.01 else straight.normalized()

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
	if moving and not (animator and animator.has_method("has_clip") and animator.has_clip("walk")): # a real walk clip needs no fake sway
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

	# Only lands if still standing and the player is still in reach. Swings at other characters are for show:
	# who wins a fight between characters is settled by the sim (world/camps.gd), loaded or not.
	if player.is_in_group("player") and not character.is_dead and is_instance_valid(player) and not player.is_dead \
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
