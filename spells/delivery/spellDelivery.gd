class_name SpellDelivery
extends Resource

## How a spell's effects reach their target. Subclasses override deliver().
## Paying and cooldown are already handled by SpellCasterComponent when this runs.

func deliver(_caster: SpellCasterComponent, _spell: Spell) -> void:
	pass
