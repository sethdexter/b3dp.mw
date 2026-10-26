extends Resource
class_name Spell

## One castable spell: what it costs, how it reaches the target (delivery) and what it does there (effects).
## Create one .tres per spell (see databases/spell_database).

@export var Name: String = "Spell"
@export_multiline var description: String = ""
## Skill that scales this spell and gains XP when it lands.
@export var skill: String = "lux" # its school: lux or nox (SkillsComponent)
## Attribute that scales damage (10 = no change).
@export var attribute: String = "intelligence"

@export_group("Cost")
@export var cost_magicka: int = 3
@export var cost_stamina: int = 0
@export var cost_health: int = 0
## Items used up by the casting (item id -> count). Every magic costs something real (see world/minds.gd lore).
@export var reagents: Dictionary = {}
## Seconds before it can be cast again.
@export var cooldown: float = 0.6

## How the effects get there: ProjectileDelivery, SelfDelivery or TouchDelivery.
@export var delivery: SpellDelivery
## What happens to whoever it lands on, in order.
@export var effects: Array[SpellEffect] = []

## Runs every effect on the target and trains the caster's spell skill.
func apply_to(target: BaseCharacter, caster: Node) -> void:
	for e in effects:
		if e:
			e.apply(target, caster, self)
	var combat = caster.get("combatComponent") if caster else null
	if combat:
		combat.train_skill(skill, combat.xp_per_hit)
