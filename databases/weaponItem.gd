extends Item

class_name WeaponItem

@export var attackTypes = {
		"slashDamage": 0,
		"pierceDamage": 0,
		"bludgeiningDamage": 0,
		}

@export var range = 1
@export var attackSpeed = 0.4
@export var governingSkill: String
## Picks the attack animations in MeleeComponent.swings ("sword", "axe"...).
@export var category := "sword"
