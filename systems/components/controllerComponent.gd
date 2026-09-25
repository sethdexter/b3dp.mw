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
@export var walk_speed: float = 3.8
@export var sprint_speed: float = 6.2
@export var acceleration: float = 35.0
@export var deceleration: float = 40.0

@export_category("Slope Settings")
@export_range(45.0, 89.0) var max_slope_angle: float = 88.0
@export var min_slope_speed_scale: float = 0.15

@export_category("Jump & Gravity")
@export var jump_velocity: float = 7.0
@export var gravity_multiplier: float = 2.2
@export var fall_gravity_multiplier: float = 3.2
@export var variable_jump_cut: float = 0.5

var input_dir: Vector2 = Vector2.ZERO

func _ready() -> void:
	if not character:
		character = get_parent() as CharacterBody3D
		
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	
	if character:
		character.floor_max_angle = deg_to_rad(max_slope_angle)
		character.floor_stop_on_slope = true
		character.floor_constant_speed = true

func _unhandled_input(event: InputEvent) -> void:
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

# Interaction trigger ('E' key or "interact" action)
	var is_interact_press: bool = (InputMap.has_action("interact") and event.is_action_pressed("interact")) or (event is InputEventKey and event.pressed and not event.is_echo() and event.keycode == KEY_E)
	if is_interact_press and current_interactable:
		current_interactable.interact(character)

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
	if character.is_on_floor():
		var sprint_action_active := InputMap.has_action("sprint") and Input.is_action_pressed("sprint")
		var is_sprinting := sprint_action_active or Input.is_key_pressed(KEY_SHIFT)
		var base_speed := sprint_speed if is_sprinting else walk_speed

		var floor_normal := character.get_floor_normal()
		var slope_factor := floor_normal.dot(Vector3.UP)
		var slope_speed_scale := remap(clamp(slope_factor, 0.0, 1.0), 0.0, 1.0, min_slope_speed_scale, 1.0)
		var effective_speed := base_speed * slope_speed_scale

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
		
		var transform_dir := (right * input_dir.x + forward * input_dir.y).normalized()

		if transform_dir != Vector3.ZERO:
			var target_vel := transform_dir * effective_speed
			var rate := 1.0 - exp(-acceleration * delta)
			character.velocity.x = lerp(character.velocity.x, target_vel.x, rate)
			character.velocity.z = lerp(character.velocity.z, target_vel.z, rate)
		else:
			var rate := 1.0 - exp(-deceleration * delta)
			character.velocity.x = lerp(character.velocity.x, 0.0, rate)
			character.velocity.z = lerp(character.velocity.z, 0.0, rate)


func handle_interaction() -> void:
	if not interaction_raycast:
		print("ERROR: Interaction RayCast3D reference is missing in the Player Inspector!")
		return

	interaction_raycast.force_raycast_update()
	var found_interactable = null

	if interaction_raycast.is_colliding():
		var collider = interaction_raycast.get_collider()
		print("Raycast hit: ", collider.name if collider else "Nothing")
		
		if collider:
			if collider.has_node("InteractableComponent"):
				found_interactable = collider.get_node("InteractableComponent")

			elif collider.has_method("interact"):
				found_interactable = collider

	# Handle switching between interactables
	if found_interactable != current_interactable:
		if current_interactable and current_interactable.has_method("hide_prompt"):
			current_interactable.hide_prompt()
		
		current_interactable = found_interactable
		
		if current_interactable and current_interactable.has_method("show_prompt"):
			current_interactable.show_prompt()
			print("Prompt shown for: ", current_interactable.name)

	# Trigger input action (e.g., pressing 'E')
	if current_interactable and Input.is_action_just_pressed("interact"):
		current_interactable.interact(self)

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
