extends Node
class_name EquipmentComponent

signal equipment_changed(slot: String, item: Item)
## Fired after equipped effects (armour / attribute modifiers) change.
signal effects_changed

@export var currentCharacter:   Node3D
@export var characterCollision: CollisionShape3D

var rightHandPosition: Vector3
var leftHandPosition:  Vector3

var equipment: Dictionary[String, Item] = {
	"right_hand" : null,
	"left_hand"  : null,
	"head"       : null,
	"chest"      : null,
	"feet"       : null,
	"back"       : null,
}

## Equips into the first free slot listed in item.equippableSlots.
## If all its slots are taken, swaps out whatever is in the first one.
func equip_item(item: Item) -> bool:
	if item == null:
		return false
	if not item.isEquippable:
		push_warning("Item '%s' is not equippable" % item.Name)
		return false
	if get_slot_of(item) != "":
		return true

	var valid_slots: Array[String] = []
	for slot in item.equippableSlots:
		if equipment.has(slot):
			valid_slots.append(slot)
	if valid_slots.is_empty():
		push_warning("'%s' has no valid equippableSlots set" % item.Name)
		return false

	var target := valid_slots[0]
	for slot in valid_slots:
		if equipment[slot] == null:
			target = slot
			break

	if equipment[target] != null:
		unequip_item(equipment[target])

	equipment[target] = item
	item.isEquipped = true
	_apply_effects(target, item)
	equipment_changed.emit(target, item)
	print("Equipped %s to %s" % [item.Name, target])
	return true

func unequip_item(targetItem: Item) -> bool:
	var slot := get_slot_of(targetItem)
	if slot == "":
		return false
	equipment[slot] = null
	targetItem.isEquipped = false
	_remove_effects(slot, targetItem)
	equipment_changed.emit(slot, null)
	print("Unequipped %s from %s" % [targetItem.Name, slot])
	return true

## Slot name this exact item (stack) is equipped in, or "".
func get_slot_of(item: Item) -> String:
	for slot in equipment:
		if equipment[slot] == item:
			return slot
	return ""

func get_equipped(slot: String) -> Item:
	return equipment.get(slot)

## Weapon in the right hand, or null.
func get_weapon() -> WeaponItem:
	return equipment.get("right_hand") as WeaponItem

## Sum of armour from everything equipped.
func get_total_armor() -> int:
	var total := 0
	for slot in equipment:
		var item: Item = equipment[slot]
		if item:
			total += item.get_armor_rating()
	return total

## Equipped items that give armour.
func get_armor_pieces() -> Array[Item]:
	var pieces: Array[Item] = []
	for slot in equipment:
		var item: Item = equipment[slot]
		if item and item.get_armor_rating() > 0:
			pieces.append(item)
	return pieces

# --- equipped effects -------------------------------------------------------

func _source_id(slot: String) -> String:
	return "equip_%s" % slot

func _attributes() -> AttributesComponent:
	if currentCharacter and "attributeComponent" in currentCharacter:
		return currentCharacter.attributeComponent
	return null

func _apply_effects(slot: String, item: Item) -> void:
	var attrs := _attributes()
	if attrs:
		var mods := item.get_attribute_modifiers()
		for attr_name in mods:
			var attr := attrs.get_attribute(attr_name)
			if attr:
				attr.add_modifier(_source_id(slot), mods[attr_name])
			else:
				push_warning("%s: unknown attribute '%s'" % [item.Name, attr_name])
	effects_changed.emit()

func _remove_effects(slot: String, item: Item) -> void:
	var attrs := _attributes()
	if attrs:
		for attr_name in item.get_attribute_modifiers():
			var attr := attrs.get_attribute(attr_name)
			if attr:
				attr.remove_modifier(_source_id(slot))
	effects_changed.emit()

func show_equipment():
	for slot in equipment:
		var item: Item = equipment[slot]
		print("%s: %s" % [slot, item.Name if item else "-"])
