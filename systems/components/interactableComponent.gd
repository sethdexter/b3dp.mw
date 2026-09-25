class_name InteractableComponent
extends Node

@export var player: BaseCharacter
#@export var itemName: String = ""
@export var itemId: String = ""
@export var isPickupable: bool = false

signal interacted(player)

@onready var interactionPrompt: Label = $Label

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
		if typeof(item_list) != TYPE_NIL:
			var item_instance = item_list.get_item_instance(itemId)
			if item_instance and "inventoryComponent" in player and player.inventoryComponent:
				player.inventoryComponent.add_item(item_instance, 1)
				get_parent().queue_free()
	else:
		# Handle the child container node
		if has_node("containerInventory"):
			$containerInventory.interact()
		else:
			print("No ContainerInventory child found on this component!")
