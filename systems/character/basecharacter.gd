extends CharacterBody3D
class_name BaseCharacter

@export var char_id:	  int
@export var Name: 		  String

@export var attributeComponent:  AttributesComponent
@export var statComponent:       StatsComponent
@export var skillComponent:      SkillsComponent
@export var combatComponent:     CombatComponent
@export var inventoryComponent:  InventoryComponent
@export var equipmentComponent:  EquipmentComponent
@export var controllerComponent: ControllerComponent

func receive_item(item: Item, amount: int) -> bool:
	if not inventoryComponent:
		return false
	return inventoryComponent.add_item(item, amount)

func receive_damage(raw_damage: int) -> bool:
	if not combatComponent or not statComponent or not statComponent.health:
		return false
	combatComponent.take_damage(statComponent.health, raw_damage)
	return true

func receive_healing(amount: int) -> bool:
	if not combatComponent or not statComponent or not statComponent.health:
		return false
	combatComponent.heal_damage(statComponent.health, amount)
	return true
