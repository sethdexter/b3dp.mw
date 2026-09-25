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
		
	if inventory.size() >= max_capacity and not inventory.has(item):
		return
		
	if item.isUnique:
		item = item.duplicate(true)
		inventory[item] = 1
	elif inventory.has(item):
		inventory[item] += amount
	else:
		inventory[item] = amount
		
	inventory_updated.emit()
	update_ui_list()
	print(inventory)

func remove_item(item: Item, amount: int) -> void:
	if not inventory.has(item):
		return
		
	inventory[item] -= amount
	if inventory[item] <= 0:
		inventory.erase(item)
		
	inventory_updated.emit()
	update_ui_list()
	print(inventory)

func interact(player: Node = null) -> void:
	if player:
		active_player = player
		
	if container_panel:
		container_panel.visible = not container_panel.visible
		print("Container UI visibility toggled to: ", container_panel.visible)
		if container_panel.visible:
			selected_index = 0
			update_ui_list()
"""
"""
func update_ui_list() -> void:
	if not item_list_container:
		return
		
	for child in item_list_container.get_children():

		child.queue_free()

	if inventory.is_empty():
		var empty_lbl = Label.new()
		empty_lbl.text = "Container is empty"
		item_list_container.add_child(empty_lbl)
		return

	var index = 0
	for item in inventory:
		var lbl = Label.new()
		var count = inventory[item]
		
		if count > 1:
			lbl.text = "%s x %d" % [item.Name, count]
		else:
			lbl.text = "%s" % [item.Name]
			
		if index == selected_index:
			lbl.modulate = Color(1.2, 1.2, 0.4) # Highlight selected
		else:
			lbl.modulate = Color(1, 1, 1)
			
		item_list_container.add_child(lbl)
		index += 1

func navigate_selection(direction: int) -> void:
	if inventory.is_empty():
		return
	var max_idx = inventory.size() - 1
	selected_index = selected_index + direction
	if selected_index > max_idx:
		selected_index = 0
	elif selected_index < 0:
		selected_index = max_idx
	update_ui_list()

func take_selected_item() -> void:
	if inventory.is_empty():
		return
		
	var items = inventory.keys()
	if selected_index >= items.size():
		selected_index = items.size() - 1
		
	var target_item = items[selected_index]
	
	if active_player and "inventoryComponent" in active_player and active_player.inventoryComponent:
		active_player.inventoryComponent.add_item(target_item, 1)
	
	remove_item(target_item, 1)
	
	if selected_index >= inventory.size() and selected_index > 0:
		selected_index -= 1
	update_ui_list()
 """
