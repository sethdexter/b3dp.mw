extends Node
class_name EquipmentComponent

@export var currentCharacter:   Node3D
@export var characterCollision: CollisionShape3D

signal equipment_changed

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

	if not item.isEquippable:
		push_warning("Item '%s' is not equippable" % item.Name)
		return false

	for slot in item.equippableSlots:
		if not equipment.has(slot):
			continue

		if equipment[slot] != null:
			push_warning("Slot '%s' is already occupied" % slot)
			continue

		equipment[slot] = item
		item.isEquipped = true
		equipment_changed.emit()
		print("Equipped %s to %s" % [item.Name, slot])
		return true

	push_warning("No valid equipment slot found for %s" % item.Name)
	return false

func unequip_item(target_item: Item) -> bool:
	if target_item == null:
		return false

	for slot in equipment:
		if equipment[slot] != target_item:
			continue

		equipment[slot] = null
		target_item.isEquipped = false
		equipment_changed.emit()
		print("Unequipped %s from %s" % [target_item.Name, slot])
		return true

	return false

func show_equipment():
	for slot in equipment:
		var item: Item = equipment[slot]
		if item == null:
			continue
		print("%s: %s" % [slot, item.Name])

func _process(_delta):
	pass
