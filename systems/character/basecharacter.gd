extends CharacterBody3D
class_name BaseCharacter

@export var char_id:	  int
@export var Name: 		  String
#@export var vicinityArea: Area2D

@export var attributeComponent:  AttributesComponent
@export var statComponent:       StatsComponent
@export var skillComponent:      SkillsComponent
@export var combatComponent:     CombatComponent
@export var inventoryComponent:  InventoryComponent
@export var equipmentComponent:  EquipmentComponent
@export var controllerComponent: ControllerComponent

## Items given on spawn: { "item_id": amount } (needs an inventoryComponent).
@export var starting_items: Dictionary[String, int] = {}
## Runs the old self-heal / self-attack test on start. Off by default.
@export var run_debug_tests := false

## Set while dead; movement, attacks, spells and inventory ignore input.
var is_dead := false

func _ready():
	# Lets NPCs find the player without hard-coded paths.
	if controllerComponent:
		add_to_group("player")

	if inventoryComponent:
		for id in starting_items:
			var item: Item = item_list.get_item_instance(id)
			if item:
				inventoryComponent.add_item(item, starting_items[id])

	if run_debug_tests:
		_debug_tests()

	print("--- Character %s Initialized ---" % Name)

func _debug_tests() -> void:
	print("--- DEBUG START: %s ---" % Name)
	var itemSword: WeaponItem = load("res://databases/item_database/black_iron_sword.tres")
	if inventoryComponent:
		inventoryComponent.add_item(itemSword, 1)
		inventoryComponent.check_inventory()
	if combatComponent and statComponent:
		combatComponent.heal(self, statComponent.health, 5)
		combatComponent.attack(self, itemSword, "pierceDamage")
		combatComponent.attack(self, itemSword, "slashDamage")
	if attributeComponent:
		print("Strength Level: ", attributeComponent.strength.get_value())
	if statComponent:
		print("Current Health: ", statComponent.health.currentValue)
		print("Max Health: ", statComponent.health.get_max_value())
	if skillComponent:
		skillComponent.list_skills()
