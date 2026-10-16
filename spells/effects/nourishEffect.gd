class_name NourishEffect
extends SpellEffect

## Food and drink: fills the target's hunger and/or thirst (needs a NeedsComponent named "needs").

## Points of hunger filled (0-100 scale).
@export_range(0.0, 100.0, 1.0) var food := 0.0
## Points of thirst quenched (0-100 scale).
@export_range(0.0, 100.0, 1.0) var water := 0.0

func apply(target: BaseCharacter, _source: Node, _spell: Spell) -> void:
	var needs: NeedsComponent = target.get_node_or_null("needs") if target else null
	if needs:
		needs.eat(food)
		needs.drink(water)

func describe() -> String:
	var parts := []
	if food > 0.0:
		parts.append("Feeds %d" % food)
	if water > 0.0:
		parts.append("Quenches %d" % water)
	return ", ".join(parts)
