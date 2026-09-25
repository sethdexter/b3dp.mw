extends Node
class_name EquipmentComponent

@export var currentCharacter:   Node3D
@export var characterCollision: CollisionShape3D

var rightHandPosition: Vector3
var leftHandPosition:  Vector3

var equipment: Dictionary                 

func _ready():
	equipment = {
		"right_hand" : null,
		"left_hand"  : null,
		"head"       : null,
		"chest"      : null,
		"feet"       : null,
		"back"       : null,
		}

func equip_item(item: Item) -> bool:
	if item == null:
		return false

	if not item.equippable:
		push_warning("Item '%s' is not equippable" % item.name)
		return false

	for slot in item.equip_slots:
		if not equipment.has(slot):
			continue

		if equipment[slot] != null:
			push_warning("Slot '%s' is already occupied" % slot)
			continue

		equipment[slot] = item
		print("Equipped %s to %s" % [item.name, slot])
		return true

	push_warning("No valid equipment slot found for %s" % item.name)
	return false

func unequip_item(targetItem: Item):
	targetItem.isEquipped = false
	print(" you have unequipped %s." % targetItem)
	pass

func show_equipment():
	#pass
	for i in equipment:
		if !equipment[i].has_property("Name"):
			break
		else:
			print(equipment[i].Name)
		#print(i)

func _process(_delta):
	pass
