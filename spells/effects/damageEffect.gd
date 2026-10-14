class_name DamageEffect
extends SpellEffect

## Hurts the target. From a spell, scaled by the caster's spell skill and attribute.

@export var amount: int = 6
# shortcut: no resistances yet, so element is only a label; add per-element resistance when needed.
@export_enum("fire", "frost", "shock", "poison") var element: String = "fire"

func apply(target: BaseCharacter, source: Node, spell: Spell) -> void:
	if not target or not target.combatComponent or not target.statComponent:
		return
	var dmg := amount
	var combat = source.get("combatComponent") if source else null
	if combat and spell:
		dmg = combat.scaled_damage(amount, spell.skill, spell.attribute)
	target.combatComponent.take_damage(target.statComponent.health, dmg)

func describe() -> String:
	return "%d %s damage" % [amount, element.capitalize()]
