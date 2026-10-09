extends Resource
class_name Spell

## Data for a castable spell. Create one .tres per spell (see databases/spell_database).

@export var Name: String = "Spell"
@export_multiline var description: String = ""
## Skill that scales this spell and gains XP when it hits.
@export var skill: String = "destruction"
## Attribute that scales damage (10 = no change).
@export var attribute: String = "intelligence"

@export_group("Cost")
@export var cost_magicka: int = 3
@export var cost_stamina: int = 0
@export var cost_health: int = 0
## Seconds before it can be cast again.
@export var cooldown: float = 0.6

@export_group("Projectile")
## Scene spawned on cast (e.g. FireballProjectile).
@export var projectile: PackedScene
@export var damage: int = 6
@export var speed: float = 18.0
@export var max_range: float = 40.0
