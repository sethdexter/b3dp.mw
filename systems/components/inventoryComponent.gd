extends Node
class_name InventoryComponent

signal inventory_updated

@export var currentCharacter: Node3D
@export var maxInventoryWeight := 100
var currentInventoryWeight := 0.0
var isEncubmered := false

## Each key is one stack: dict[item_resource, stack_count].
## Stacks respect Item.maxStackCount. Overflow creates a new stack
## (keyed by a duplicate of the item resource, since dict keys must be unique).
##   maxStackCount <= 0 -> unlimited stack
##   maxStackCount == 1 or isUnique -> every item is its own stack
var inventory: Dictionary[Item, int] = {}

## Max items in one stack of this item.
static func get_stack_cap(item: Item) -> int:
	if item.isUnique or item.maxStackCount == 1:
		return 1
	if item.maxStackCount <= 0:
		return 2147483647
	return item.maxStackCount

## True if two item resources represent the same item type.
static func is_same_item(a: Item, b: Item) -> bool:
	if a == b:
		return true
	if a.id != "" and b.id != "":
		return a.id == b.id
	return a.Name == b.Name

## Adds `amount` of `item`, topping up existing stacks first, then opening new ones.
func add_item(item: Item, amount: int = 1) -> void:
	if item == null:
		push_warning("InventoryComponent.add_item: item is null")
		return
	if amount <= 0:
		return

	var cap := get_stack_cap(item)
	var remaining := amount

	# 1. Top up existing, non-full stacks of the same item.
	if cap > 1:
		for key in inventory:
			if remaining <= 0:
				break
			if is_same_item(key, item) and inventory[key] < cap:
				var added: int = min(cap - inventory[key], remaining)
				inventory[key] += added
				remaining -= added

	# 2. Open new stacks for whatever is left.
	while remaining > 0:
		var added: int = min(cap, remaining)
		# Reuse the passed resource as a key if free; otherwise make a new one.
		var key: Item = item if not inventory.has(item) else item.make_instance()
		inventory[key] = added
		remaining -= added

	currentInventoryWeight += item.weight * amount
	isEncubmered = currentInventoryWeight > maxInventoryWeight
	print("%s picked up %s x%d." % [_owner_name(), item.Name, amount])
	inventory_updated.emit()

## Removes up to `amount` from that specific stack. Returns how many were removed.
func remove_item(item: Item, amount: int = 1) -> int:
	if not inventory.has(item) or amount <= 0:
		return 0
	var removed: int = min(amount, inventory[item])
	inventory[item] -= removed
	if inventory[item] <= 0:
		inventory.erase(item)

	currentInventoryWeight -= item.weight * removed
	isEncubmered = currentInventoryWeight > maxInventoryWeight
	inventory_updated.emit()
	return removed

## Total count of an item type across all stacks.
func count_item(item: Item) -> int:
	var total := 0
	for key in inventory:
		if is_same_item(key, item):
			total += inventory[key]
	return total

func check_inventory():
	if inventory.is_empty():
		print(_owner_name(), " is empty.")
	for i in inventory:
		print("%s x %s" % [i.Name, inventory[i]])
	inventory_updated.emit()

func _owner_name() -> String:
	return currentCharacter.name if currentCharacter else get_parent().name
