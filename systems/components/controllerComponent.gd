class_name ControllerComponent
extends Node

## Self-contained movement, camera, and interaction controller for a CharacterBody3D.

@export_category("References")
@export var character: CharacterBody3D
@export var camera_node: Node3D

@export_category("Interaction Settings")
@export var interaction_raycast: RayCast3D
var current_interactable = null

@export_category("Camera Settings")
@export var mouse_sensitivity: float = 0.003
@export var min_pitch: float = -89.0
@export var max_pitch: float = 89.0

@export_category("Movement Settings")
## Speed while walk mode is toggled on ("toggle_walk", Caps Lock).
@export var walk_speed: float = 2.0
## Default speed.
@export var run_speed: float = 3.8
## Hold "walk_run_modifier" (Shift) to sprint.
@export var sprint_speed: float = 6.2
@export var acceleration: float = 35.0
@export var deceleration: float = 40.0

@export_category("Dash")
## Short burst in the move direction ("dash", Alt).
## Peak speed, reached halfway through the dash.
@export var dash_speed: float = 8.0
@export var dash_duration: float = 0.4
## Shape of the ease in/out: 1 = smooth sine, <1 = wider plateau at peak, >1 = sharper spike.
@export var dash_ease: float = 1.0
@export var dash_cooldown: float = dash_duration
@export var allow_air_dash := false

@export_category("Stamina")
## Stamina per second while sprinting and moving.
@export var sprint_stamina_per_sec: float = 4
## Stamina per dash. Can't dash without enough.
@export var dash_stamina_cost: float = 3

@export_category("Slope Settings")
@export_range(45.0, 89.0) var max_slope_angle: float = 88.0
@export var min_slope_speed_scale: float = 0.15

@export_category("Jump & Gravity")
@export var jump_velocity: float = 7.0
@export var gravity_multiplier: float = 2.2
@export var fall_gravity_multiplier: float = 3.2
@export var variable_jump_cut: float = 0.5

var input_dir: Vector2 = Vector2.ZERO
var is_walking := false
var _dash_time_left := 0.0
var _dash_dir := Vector3.ZERO
var _dash_start_speed := 0.0
var _dash_ready_msec := 0

func _ready() -> void:
	if not character:
		character = get_parent() as CharacterBody3D

	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED

	if character:
		character.floor_max_angle = deg_to_rad(max_slope_angle)
		character.floor_stop_on_slope = true
		character.floor_constant_speed = true

	if not interaction_raycast:
		push_error("ControllerComponent: interaction_raycast not assigned in the Inspector.")

func _is_dead() -> bool:
	return character != null and character.get("is_dead") == true

func _stats() -> StatsComponent:
	return character.get("statComponent") if character else null

func _unhandled_input(event: InputEvent) -> void:
	if _is_dead():
		return
	# Mouse look
	if event is InputEventMouseMotion and Input.mouse_mode == Input.MOUSE_MODE_CAPTURED:
		handle_camera_rotation(event.relative)

	# Jump input press
	var is_jump_press := (InputMap.has_action("jump") and event.is_action_pressed("jump")) or event.is_action_pressed("ui_accept")
	if is_jump_press:
		apply_jump()

	# Variable jump height cut on release
	var is_jump_release := (InputMap.has_action("jump") and event.is_action_released("jump")) or event.is_action_released("ui_accept")
	if is_jump_release and character:
		if character.velocity.y > 0:
			character.velocity.y *= variable_jump_cut

	# Walk/run toggle
	if InputMap.has_action("toggle_walk") and event.is_action_pressed("toggle_walk"):
		is_walking = not is_walking

	# Dash
	if InputMap.has_action("dash") and event.is_action_pressed("dash"):
		start_dash()

	# Interaction trigger ('E' key or "interact" action) - the ONLY place interact() is called.
	var is_interact_press: bool = (InputMap.has_action("interact") and event.is_action_pressed("interact")) or (event is InputEventKey and event.pressed and not event.is_echo() and event.keycode == KEY_E)
	if is_interact_press and current_interactable:
		current_interactable.interact(character)
		get_viewport().set_input_as_handled()

func _physics_process(delta: float) -> void:
	if not character:
		return

	handle_movement(delta)
	apply_gravity(delta)
	character.move_and_slide()
	handle_interaction()

func handle_camera_rotation(relative_motion: Vector2) -> void:
	if not character or not camera_node:
		return

	character.rotate_y(-relative_motion.x * mouse_sensitivity)
	camera_node.rotate_x(-relative_motion.y * mouse_sensitivity)
	var current_rotation := camera_node.rotation_degrees
	current_rotation.x = clamp(current_rotation.x, min_pitch, max_pitch)
	camera_node.rotation_degrees = current_rotation

func handle_movement(delta: float) -> void:
	# Dashing overrides normal movement for a moment.
	if _dash_time_left > 0.0:
		_dash_time_left = maxf(0.0, _dash_time_left - delta)
		# Ease in to dash_speed and back out again (sine bell over the dash).
		var t := 1.0 - _dash_time_left / dash_duration
		var base := lerpf(_dash_start_speed, get_current_speed(), t)
		var bell := pow(sin(t * PI), dash_ease)
		var speed := lerpf(base, dash_speed, bell)
		character.velocity.x = _dash_dir.x * speed
		character.velocity.z = _dash_dir.z * speed
		return

	if character.is_on_floor():
		var effective_speed := get_current_speed() * _slope_speed_scale()
		var transform_dir := Vector3.ZERO if _is_dead() else get_move_direction()

		# Sprinting drains stamina while actually moving.
		if transform_dir != Vector3.ZERO and _is_sprinting():
			var stats := _stats()
			if stats:
				stats.spend_stamina(sprint_stamina_per_sec * delta)

		if transform_dir != Vector3.ZERO:
			var target_vel := transform_dir * effective_speed
			var rate := 1.0 - exp(-acceleration * delta)
			character.velocity.x = lerp(character.velocity.x, target_vel.x, rate)
			character.velocity.z = lerp(character.velocity.z, target_vel.z, rate)
		else:
			var rate := 1.0 - exp(-deceleration * delta)
			character.velocity.x = lerp(character.velocity.x, 0.0, rate)
			character.velocity.z = lerp(character.velocity.z, 0.0, rate)

## Walk (toggled), run (default) or sprint (hold modifier).
func get_current_speed() -> float:
	if _is_sprinting():
		return sprint_speed
	return walk_speed if is_walking else run_speed

## Sprint key held and stamina left.
func _is_sprinting() -> bool:
	var sprint_held := (InputMap.has_action("walk_run_modifier") and Input.is_action_pressed("walk_run_modifier")) \
		or (InputMap.has_action("sprint") and Input.is_action_pressed("sprint"))
	if not sprint_held:
		return false
	var stats := _stats()
	return stats == null or stats.has_stamina()

func _slope_speed_scale() -> float:
	var slope_factor := character.get_floor_normal().dot(Vector3.UP)
	return remap(clamp(slope_factor, 0.0, 1.0), 0.0, 1.0, min_slope_speed_scale, 1.0)

## World-space move direction from WASD, flattened to the ground plane.
func get_move_direction() -> Vector3:
	if InputMap.has_action("move_left"):
		input_dir = Input.get_vector("move_left", "move_right", "move_forward", "move_back")
	else:
		input_dir = Input.get_vector("ui_left", "ui_right", "ui_up", "ui_down")

	var basis_source: Basis = camera_node.global_transform.basis if camera_node else character.global_transform.basis
	var forward := basis_source.z
	forward.y = 0
	forward = forward.normalized()
	var right := basis_source.x
	right.y = 0
	right = right.normalized()
	return (right * input_dir.x + forward * input_dir.y).normalized()

## Quick burst in the current move direction (forward if standing still).
func start_dash() -> void:
	if not character or _dash_time_left > 0.0:
		return
	if Time.get_ticks_msec() < _dash_ready_msec:
		return
	if not character.is_on_floor() and not allow_air_dash:
		return
	var stats := _stats()
	if stats and not stats.has_stamina(dash_stamina_cost):
		return
	if stats:
		stats.spend_stamina(dash_stamina_cost)
	var dir := get_move_direction()
	if dir == Vector3.ZERO:
		var basis_source: Basis = camera_node.global_transform.basis if camera_node else character.global_transform.basis
		dir = -basis_source.z
		dir.y = 0
		dir = dir.normalized()
	_dash_dir = dir
	_dash_start_speed = Vector2(character.velocity.x, character.velocity.z).length()
	_dash_time_left = dash_duration
	_dash_ready_msec = Time.get_ticks_msec() + int(dash_cooldown * 1000.0)

## Finds an InteractableComponent on the collider, regardless of the node's name.
func _find_interactable(collider: Node):
	if collider == null:
		return null
	for child in collider.get_children():
		if child is InteractableComponent:
			return child
	if collider.has_method("interact"):
		return collider
	return null

## Only tracks what the player is looking at and shows/hides prompts.
## Pressing interact is handled in _unhandled_input.
func handle_interaction() -> void:
	if not interaction_raycast:
		return

	interaction_raycast.force_raycast_update()
	var found_interactable = null
	if interaction_raycast.is_colliding():
		found_interactable = _find_interactable(interaction_raycast.get_collider())

	if found_interactable != current_interactable:
		if is_instance_valid(current_interactable) and current_interactable.has_method("hide_prompt"):
			current_interactable.hide_prompt()

		current_interactable = found_interactable

		if current_interactable and current_interactable.has_method("show_prompt"):
			current_interactable.show_prompt()

func apply_gravity(delta: float) -> void:
	if not character.is_on_floor():
		var grav := project_gravity()
		var mult := gravity_multiplier if character.velocity.y > 0 else fall_gravity_multiplier
		character.velocity.y -= grav * mult * delta

func apply_jump() -> void:
	if character and character.is_on_floor():
		character.velocity.y = jump_velocity

func project_gravity() -> float:
	return ProjectSettings.get_setting("physics/3d/default_gravity")
