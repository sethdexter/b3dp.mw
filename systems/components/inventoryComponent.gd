extends Node
class_name InventoryComponent

signal inventory_updated

@export var currentCharacter: Node3D
@export var maxInventoryWeight := 100
var currentInventoryWeight := 0.0
var isEncubmered := false

#this dictionary handles the inventory items and stack count dict[item, stackcount]
var inventory: Dictionary[Item, int] = {}

func add_item(item: Item, amount: int):
	if item == null:
		print("item is null")
		return

	if item.isUnique:
		item = item.duplicate(true)
		inventory[item] = 1
		currentInventoryWeight += item.weight
		print("picked up a unique %s." % item.Name)
		
	elif item.isUnique == false:
		if inventory.has(item):
			inventory[item] += amount
		else:
			inventory[item] = amount
		currentInventoryWeight += item.weight * amount
		print("picked up %s x%d." % [item.Name, amount])
	
	isEncubmered = currentInventoryWeight > maxInventoryWeight
	
	print(inventory[item])
	print("picked up a %s." % item.Name)
	inventory_updated.emit()

func remove_item(item: Item, amount: int):
	if not inventory.has(item):
		return
	inventory[item] -= amount
	currentInventoryWeight -= item.weight * amount
	if inventory[item] <= 0:
		inventory.erase(item)
		
	isEncubmered = currentInventoryWeight > maxInventoryWeight
	inventory_updated.emit()

func check_inventory():
	if len(inventory) == 0:
		print(get_parent().get_parent().name, " is empty.")
		pass
	for i in inventory:
		print("%s x %s" % [i.Name, inventory[i]])
	inventory_updated.emit()

func _process(_delta):
	return

func _ready():
	return
