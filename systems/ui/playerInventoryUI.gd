class_name PlayerInventoryUI
extends CanvasLayer

## Player inventory panel (bottom-right). Owns all inventory/container input.
##   Tab          = open / close inventory (closes an open container too)
##   Mouse wheel  = move selection in the focused list
##   RMB          = switch focus between chest and player lists (when a chest is open)
##   LMB          = chest focused:  take one     | player focused + chest open: store one
##                  player focused, no chest: equip / unequip
##   Shift + LMB  = take / store the whole stack
##   LMB on a consumable (no chest open) = use it
##   Q            = drop the selected item in front of you (Shift + Q = whole stack)

enum Side { PLAYER, CONTAINER }

@export var character: BaseCharacter
## Scene spawned when dropping an item. Loaded on first drop if left empty
## (not preloaded: preloading it creates a load cycle via InteractableComponent).
@export var dropped_item_scene: PackedScene
const DROPPED_ITEM_PATH := "res://systems/items/droppedItem.tscn"

@onready var player_view: ItemListView = $PlayerPanel
@onready var weight_label: Label = get_node_or_null("PlayerPanel/Weight")

var is_open := false
var container: ContainerComponent = null
var focus_side := Side.PLAYER
var _opened_by_container := false

func _ready() -> void:
	if not character:
		character = get_parent() as BaseCharacter
	if not character or not character.inventoryComponent:
		push_error("PlayerInventoryUI: needs a BaseCharacter parent with an inventoryComponent.")
		return
	player_view.bind(character.inventoryComponent, character.equipmentComponent)
	character.inventoryComponent.inventory_updated.connect(_update_weight)
	player_view.hide_view()
	if weight_label:
		weight_label.visible = false

# --- open / close -----------------------------------------------------------

func toggle() -> void:
	if is_open:
		close()
	else:
		open()

func open() -> void:
	is_open = true
	player_view.show_view()
	if weight_label:
		weight_label.visible = true
	_update_weight()
	_update_focus()

func close() -> void:
	var c := container
	container = null
	_opened_by_container = false
	if c:
		c.close() # its detach_container() call is ignored since container is already null
	is_open = false
	focus_side = Side.PLAYER
	player_view.hide_view()
	if weight_label:
		weight_label.visible = false

## Called by ContainerComponent.open()
func attach_container(c: ContainerComponent) -> void:
	container = c
	_opened_by_container = not is_open
	if not is_open:
		open()
	focus_side = Side.CONTAINER
	_update_focus()

## Called by ContainerComponent.close()
func detach_container(c: ContainerComponent) -> void:
	if container != c:
		return
	container = null
	focus_side = Side.PLAYER
	if _opened_by_container:
		close()
	else:
		_update_focus()

func _update_focus() -> void:
	player_view.focused = focus_side == Side.PLAYER or container == null
	if container and container.view:
		container.view.focused = focus_side == Side.CONTAINER

func _focused_view() -> ItemListView:
	if focus_side == Side.CONTAINER and container:
		return container.view
	return player_view

# --- input ------------------------------------------------------------------

func _is_toggle_event(event: InputEvent) -> bool:
	if InputMap.has_action("inventory") and event.is_action_pressed("inventory"):
		return true
	return event is InputEventKey and event.pressed and not event.is_echo() and event.keycode == KEY_TAB

func _unhandled_input(event: InputEvent) -> void:
	if character and character.is_dead:
		return
	if _is_toggle_event(event):
		toggle()
		get_viewport().set_input_as_handled()
		return
	if not is_open:
		return
	if _is_drop_event(event):
		_drop_selected(event.shift_pressed)
		get_viewport().set_input_as_handled()
		return
	if event is InputEventMouseButton and event.pressed:
		match event.button_index:
			MOUSE_BUTTON_WHEEL_DOWN:
				_focused_view().move_selection(1)
			MOUSE_BUTTON_WHEEL_UP:
				_focused_view().move_selection(-1)
			MOUSE_BUTTON_RIGHT:
				if container:
					focus_side = Side.PLAYER if focus_side == Side.CONTAINER else Side.CONTAINER
					_update_focus()
			MOUSE_BUTTON_LEFT:
				_activate(event.shift_pressed)
			_:
				return
		get_viewport().set_input_as_handled()

# --- actions ----------------------------------------------------------------

func _activate(whole_stack: bool) -> void:
	var view := _focused_view()
	var item := view.get_selected_item()
	if item == null:
		return
	var amount := view.get_selected_count() if whole_stack else 1

	if focus_side == Side.CONTAINER and container:
		_transfer(container.storage, character.inventoryComponent, item, amount)
	elif container:
		_transfer(character.inventoryComponent, container.storage, item, amount)
	elif item.isConsumable:
		_use_item(item)
	else:
		_toggle_equip(item)

func _transfer(from: InventoryComponent, to: InventoryComponent, item: Item, amount: int) -> void:
	var equip := character.equipmentComponent
	# Moving a whole equipped stack out of the player -> unequip it first.
	if equip and from == character.inventoryComponent and amount >= from.inventory.get(item, 0):
		if equip.get_slot_of(item) != "":
			equip.unequip_item(item)
	var moved := from.remove_item(item, amount)
	if moved > 0:
		to.add_item(item, moved)

func _toggle_equip(item: Item) -> void:
	var equip := character.equipmentComponent
	if not equip:
		return
	if equip.get_slot_of(item) != "":
		equip.unequip_item(item)
	elif item.isEquippable:
		equip.equip_item(item)

func _use_item(item: Item) -> void:
	var stats := character.statComponent
	if not stats:
		return
	var restores := item.get_restores()
	for stat_name in restores:
		var stat: Stat = stats.get(stat_name)
		if stat:
			stat.change_current(restores[stat_name])
	print("Used %s." % item.Name)
	character.inventoryComponent.remove_item(item, 1)

func _is_drop_event(event: InputEvent) -> bool:
	if InputMap.has_action("drop") and event.is_action_pressed("drop"):
		return true
	return event is InputEventKey and event.pressed and not event.is_echo() and event.keycode == KEY_Q

## Drops the selected item(s) from the player's list into the world.
func _drop_selected(whole_stack: bool) -> void:
	if focus_side == Side.CONTAINER and container:
		return
	var item := player_view.get_selected_item()
	if dropped_item_scene == null:
		dropped_item_scene = load(DROPPED_ITEM_PATH)
	if item == null or dropped_item_scene == null:
		return
	var inv := character.inventoryComponent
	var amount: int = inv.inventory.get(item, 0) if whole_stack else 1
	var equip := character.equipmentComponent
	if equip and amount >= inv.inventory.get(item, 0) and equip.get_slot_of(item) != "":
		equip.unequip_item(item)
	var removed := inv.remove_item(item, amount)
	if removed <= 0:
		return

	var dropped := dropped_item_scene.instantiate()
	get_tree().current_scene.add_child(dropped)
	var cam := get_viewport().get_camera_3d()
	var basis := cam.global_basis if cam else character.global_basis
	var origin := (cam.global_position if cam else character.global_position) - basis.z * 1.0 - basis.y * 0.3
	dropped.setup(item, removed, origin, -basis.z)

func _update_weight() -> void:
	if not weight_label:
		return
	var inv := character.inventoryComponent
	weight_label.text = "Weight %d / %d%s" % [
		int(inv.currentInventoryWeight), inv.maxInventoryWeight,
		"  (encumbered)" if inv.isEncubmered else ""]
