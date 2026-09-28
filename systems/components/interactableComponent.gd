class_name InteractableComponent
extends Node

@export var player: BaseCharacter
#@export var itemName: String = ""
@export var itemId: String = ""
@export var isPickupable: bool = false

signal interacted(player)

@onready var interactionPrompt: Label = get_node_or_null("prompt") as Label

func _ready() -> void:
	hide_prompt()

func show_prompt() -> void:
	if interactionPrompt:
		interactionPrompt.visible = true
		print("Prompt shown and forced visible for: ", name)

func hide_prompt() -> void:
	if interactionPrompt:
		interactionPrompt.visible = false

func interact(player: Node) -> void:
	if not player:
		return
	emit_signal("interacted", player)
	
	if isPickupable and itemId != "":
		var item_instance := item_list.get_item_instance(itemId)
		if item_instance and player.has_method("receive_item") and player.receive_item(item_instance, 1):
			get_parent().queue_free()
	else:
		var container = get_node_or_null("containerComponent") as ContainerComponent
		if container:
			container.interact(player)
		else:
			push_warning("No container component found on %s" % name)
