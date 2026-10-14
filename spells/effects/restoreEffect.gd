class_name RestoreEffect
extends SpellEffect

## Gives back points of health, magicka or stamina.

@export_enum("health", "magicka", "stamina") var stat: String = "health"
@export var amount: int = 8

func apply(target: BaseCharacter, _source: Node, _spell: Spell) -> void:
	var stats = target.statComponent if target else null
	var s: Stat = stats.get(stat) if stats else null
	if s:
		s.change_current(amount)

func describe() -> String:
	return "Restores %d %s" % [amount, stat.capitalize()]
