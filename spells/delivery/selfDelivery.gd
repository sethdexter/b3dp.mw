class_name SelfDelivery
extends SpellDelivery

## The effects land on the caster straight away (heals, buffs).

func deliver(caster: SpellCasterComponent, spell: Spell) -> void:
	spell.apply_to(caster.character, caster.character)
