class_name InteractionComponent
extends Node

@export var actor: Node
@export var interaction_raycast: RayCast3D

var current_interactable: Node

func _ready() -> void:
	if not actor:
		actor = get_parent()

func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("interact") and current_interactable:
		current_interactable.interact(actor)

func _physics_process(_delta: float) -> void:
	if not interaction_raycast:
		return

	interaction_raycast.force_raycast_update()
	var found_interactable: Node

	if interaction_raycast.is_colliding():
		var collider := interaction_raycast.get_collider() as Node
		if collider:
			for child in collider.get_children():
				if child is InteractableComponent:
					found_interactable = child
					break
			elif collider.has_method("interact"):
				found_interactable = collider

	if found_interactable == current_interactable:
		return

	if current_interactable and current_interactable.has_method("hide_prompt"):
		current_interactable.hide_prompt()

	current_interactable = found_interactable

	if current_interactable and current_interactable.has_method("show_prompt"):
		current_interactable.show_prompt()