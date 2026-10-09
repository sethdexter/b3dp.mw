extends Node
class_name CombatComponent

@export var currentCharacter: Node3D
@export var armor_rating: int = 0

func _ready():
	print("Combat component initialized for: ", currentCharacter.name)

# Takes damage and applies armor mitigation
func take_damage(target_stat: Stat, raw_damage: int):
	# Simple armor math: Damage - Armor (Minimum 1 damage)
	var final_damage = max(1, raw_damage - armor_rating)
	
	# We use change_current with a negative value for damage
	target_stat.change_current(-final_damage)
	
	print("%s took %d damage (%d mitigated). Remaining: %d" % [
		currentCharacter.name, 
		final_damage, 
		raw_damage - final_damage, 
		target_stat.currentValue
	])

func heal_damage(target_stat: Stat, amount: int):
	target_stat.change_current(amount)
	print("%s healed for %d. Current: %d" % [
		currentCharacter.name, 
		amount, 
		target_stat.currentValue
	])

# We only need 3 parameters here
func attack(target_character: BaseCharacter, weapon: WeaponItem, attack_type: String):
	if weapon == null:
		print("No weapon equipped!")
		return
	
	# 1. Get damage value from the weapon resource
	var damage_value = weapon.attackTypes[attack_type]
	
	# 2. Find the health stat on the target automatically
	var target_health = target_character.statComponent.health
	
	print("%s attacks %s for %d %s damage!" % [currentCharacter.Name, target_character.Name, damage_value, attack_type])
	
	# 3. Apply the damage via the target's combat component
	target_character.combatComponent.take_damage(target_health, damage_value)
	
# Inside CombatComponent.gd

func heal(target_character: BaseCharacter, target_stat: Stat, amount: int):
	if target_character == null or target_stat == null:
		print("Heal failed: Target or Stat is null")
		return
	
	var f_string = "%s heals %s for %d!..." % [currentCharacter.Name, target_character.Name, amount]
	print(f_string)
	
	# We call the target's combatComponent to handle the actual resource change
	# This ensures the logic (and any local mitigation/buffs) stays with the receiver
	target_character.combatComponent.heal_damage(target_stat, amount)

func heal_target(target_character: BaseCharacter, amount: int):
	print("%s casts heal on %s!" % [currentCharacter.name, target_character.name])
	var target_health = target_character.statComponent.health
	target_character.combatComponent.heal_damage(target_health, amount)
