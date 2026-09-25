extends Node
class_name ContainerInteractableComponent

@export var currentCharacter: Node3D
@export var interactionPromt: Label

var isCurrentlyInteractable: bool
var isPickupable: bool

func get_prompt():
	return 

func interact():
	if isCurrentlyInteractable:
		push_warning("Interact not implemented!")

func pickup():
	if isPickupable:
		push_warning("Pick-up not implemented!")
