class_name ContainerComponent
extends Node

signal inventory_updated

#potentially redesign this 
#

@export var max_capacity: int = 20
var inventory: Dictionary[Item, int] = {}
#var active_player: Node = null
#var selected_index: int = 0

# Directly reference the UI nodes you built in the scene tree
#@onready var container_panel: PanelContainer = find_parent("chest2").get_node("CanvasLayer/ContainerPanel")
#@onready var item_list_container: VBoxContainer = find_parent("chest2").get_node("CanvasLayer/ContainerPanel/ScrollContainer/ItemListContainer")

func _ready() -> void:
	#add_item(item_list.get_item_instance("torch"), 1)
	print(inventory)
	#add_item(item_list.get_item_instance("gold"), 2)
	#add_item(item_list.get_item_instance("sword"), 1)
"""
func _unhandled_input(event: InputEvent) -> void:
	if not container_panel or not container_panel.visible:
		return
		
	if event is InputEventMouseButton and event.pressed:
		if event.button_index == MOUSE_BUTTON_WHEEL_DOWN:
			navigate_selection(1)
			get_viewport().set_input_as_handled()
		elif event.button_index == MOUSE_BUTTON_WHEEL_UP:
			navigate_selection(-1)
			get_viewport().set_input_as_handled()
		elif event.button_index == MOUSE_BUTTON_LEFT:
			take_selected_item()
			get_viewport().set_input_as_handled()

func add_item(item: Item, amount: int) -> void:
	if item == null:
		return
		
	class_name ContainerComponent
	extends Node

	signal inventory_updated
	signal opened
	signal emptied

	@export var max_capacity: int = 20
	@export var item_ids: Array[String] = []

	var inventory: Dictionary[Item, int] = {}
	var is_opened: bool = false

	func _ready() -> void:
		for item_id in item_ids:
			var item_instance := item_list.get_item_instance(item_id)
			if item_instance:
				add_item(item_instance, 1)

	func add_item(item: Item, amount: int) -> bool:
		if item == null or amount <= 0:
			return false
		if inventory.size() >= max_capacity and not inventory.has(item):
			return false

		if item.isUnique:
			item = item.duplicate(true)
			inventory[item] = 1
		elif inventory.has(item):
			inventory[item] += amount
		else:
			inventory[item] = amount

		inventory_updated.emit()
		return true

	func interact(actor: Node) -> void:
		if is_opened or not actor or not actor.has_method("receive_item"):
			return

		for item in inventory.keys():
			if not actor.receive_item(item, inventory[item]):
				return

		is_opened = true
		opened.emit()
		inventory.clear()
		inventory_updated.emit()
		emptied.emit()
		empty_lbl.text = "Container is empty"
