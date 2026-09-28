extends Node

@onready var character: BaseCharacter = $Character
@onready var enemy: Enemy = $Enemy

func _ready() -> void:
	var item_sword: WeaponItem = preload("res://databases/item_database/black_iron_sword.tres")

	character.inventoryComponent.add_item(item_sword, 1)
	character.inventoryComponent.check_inventory()

	character.combatComponent.heal(character, character.statComponent.health, 5)
	character.combatComponent.attack(character, item_sword, "pierceDamage")
	character.combatComponent.attack(character, item_sword, "slashDamage")
	character.combatComponent.attack(enemy, item_sword, "slashDamage")

	print("Strength Level: ", character.attributeComponent.strength.get_value())
	print("Current Health: ", character.statComponent.health.currentValue)
	print("Max Health: ", character.statComponent.health.get_max_value())
	character.skillComponent.list_skills()
	print("Enemy Health: ", enemy.statComponent.health.currentValue)
	print("Character system test complete.")
	get_tree().quit()
