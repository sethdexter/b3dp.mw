class_name ContainerComponent
extends Node

## Storage for chests etc. Uses a child InventoryComponent as the actual storage
## and an ItemListView ("ContainerPanel") for display.
## Input (scroll / take / store) is handled by the player's PlayerInventoryUI.

signal opened
signal closed

## Items placed in the container at start: { "item_id": amount }
@export var starting_items: Dictionary[String, int] = {
	"torch": 5,
	"black_iron_sword": 1,
	"rusty_sword": 1,
}

@onready var storage: InventoryComponent = _find_storage()
@onready var view: ItemListView = find_child("ContainerPanel", true, false)

var is_open := false
var player_ui: PlayerInventoryUI = null

func _ready() -> void:
	if not storage:
		push_error("ContainerComponent needs an InventoryComponent child.")
		return
	for id in starting_items:
		var item: Item = item_list.get_item_instance(id)
		if item:
			storage.add_item(item, starting_items[id]) # stack splitting handled by InventoryComponent
	if view:
		view.bind(storage)
		view.hide_view()

func _find_storage() -> InventoryComponent:
	for child in get_children():
		if child is InventoryComponent:
			return child
	return null

func interact(player: Node = null) -> void:
	if is_open:
		close()
	else:
		open(player)

func open(player: Node) -> void:
	player_ui = _find_player_ui(player)
	if not player_ui:
		push_warning("ContainerComponent: player has no PlayerInventoryUI child.")
		return
	is_open = true
	if view:
		view.show_view()
	player_ui.attach_container(self)
	opened.emit()

func close() -> void:
	if not is_open:
		return
	is_open = false
	if view:
		view.hide_view()
	var ui := player_ui
	player_ui = null
	if ui:
		ui.detach_container(self)
	closed.emit()

func _find_player_ui(player: Node) -> PlayerInventoryUI:
	if player == null:
		return null
	for child in player.get_children():
		if child is PlayerInventoryUI:
			return child
	return null
