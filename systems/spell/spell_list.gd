extends Resource
class_name SpellList

@export var spells: Array[Spell] = []

func get_spell(spell_id: String) -> Spell:
	for spell in spells:
		if spell and spell.id == spell_id:
			return spell
	return null
