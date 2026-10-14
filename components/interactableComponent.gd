class_name InteractableComponent
extends Node

## Attach as a child of any physics body the player's interaction raycast can hit.
## Optional children: a Label named "prompt", and a ContainerComponent.

@export var itemId: String = ""
@export var isPickupable: bool = false

## Set at runtime for dropped items: this exact item instance is picked up.
var item: Item = null
var amount: int = 1

signal interacted(player)

@onready var interactionPrompt: Label = _find_prompt()
@onready var container: ContainerComponent = _find_container()

func _ready() -> void:
	hide_prompt()

## Uses a Label named "prompt", else the first Label child.
func _find_prompt() -> Label:
	var named := get_node_or_null("prompt") as Label
	if named:
		return named
	for child in get_children():
		if child is Label:
			return child
	return null

func _find_container() -> ContainerComponent:
	for child in get_children():
		if child is ContainerComponent:
			return child
	return null

func show_prompt() -> void:
	if interactionPrompt:
		interactionPrompt.visible = true

func hide_prompt() -> void:
	if interactionPrompt:
		interactionPrompt.visible = false
	# Looking away closes an open container.
	if container:
		container.close()

func interact(player: Node) -> void:
	if not player:
		return
	interacted.emit(player)

	if item != null:
		if "inventoryComponent" in player and player.inventoryComponent:
			player.inventoryComponent.add_item(item, amount)
			get_parent().queue_free()
	elif isPickupable and itemId != "":
		var item_instance: Item = item_list.get_item_instance(itemId)
		if item_instance and "inventoryComponent" in player and player.inventoryComponent:
			player.inventoryComponent.add_item(item_instance, 1)
			get_parent().queue_free()
	elif container:
		container.interact(player)
	else:
		push_warning("%s: nothing to do on interact (not pickupable, no ContainerComponent child)." % get_parent().name)
