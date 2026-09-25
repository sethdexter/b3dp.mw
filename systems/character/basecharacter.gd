extends CharacterBody3D
class_name BaseCharacter

var test_stuff = Test.new()
var effects = Effect.new()

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

func _init():
	pass

func _ready():
	print("--- DEBUG START: %s ---" % Name)

	# 1. Setup Test Items
	var itemSword: WeaponItem = load("res://databases/item_database/black_iron_sword.tres")
	
	if inventoryComponent:
		inventoryComponent.add_item(itemSword, 1)
		inventoryComponent.check_inventory()
	
	# 2. Testing Combat Logic
	# Note: CombatComponent now looks up the stat internally or takes the Stat object
	if combatComponent and statComponent:
		# Testing Heal
		combatComponent.heal(self, statComponent.health, 5)
		
		# Testing Attack (Self-damage test)
		# We pass 'self' as the target, and the 'stat' we want to hit
		combatComponent.attack(self, itemSword, "pierceDamage")
		combatComponent.attack(self, itemSword, "slashDamage")

	# 3. Verify Values
	# Using 'get_value()' for Attributes (calculates mods)
	# Using 'currentValue' for Stats (the pool)
	print("Strength Level: ", attributeComponent.strength.get_value())
	print("Current Health: ", statComponent.health.currentValue)
	print("Max Health: ", statComponent.health.get_max_value())
	
	if skillComponent:
		skillComponent.list_skills()
	
	print("--- Character %s Initialized ---" % Name)
	
	print("character initialized...")

func _process(_delta):
	test_stuff.timer(10000)
	pass
