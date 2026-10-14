class_name SpellEffect
extends Resource

## What a spell or potion does to whoever it lands on. Subclasses override apply() and describe().
## A Spell or a consumable Item holds a list of these.

## source = who cast or drank it (may be the target itself); spell = the spell it came from, null for potions.
func apply(_target: BaseCharacter, _source: Node, _spell: Spell) -> void:
	pass

## Short text for item and spell info, e.g. "Restores 8 Health".
func describe() -> String:
	return ""
