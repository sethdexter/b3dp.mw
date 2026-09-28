extends Resource
class_name Spell

@export var id: String
@export var display_name: String = "Unnamed Spell"
@export_multiline var description: String

@export var is_passive: bool = false

@export var cost_health: int = 0
@export var cost_stamina: int = 0
@export var cost_magicka: int = 0

@export var cooldown_seconds: float = 0.0
@export var effects: Array[Effect] = []

func get_effect(effect_id: String) -> Effect:
	for effect in effects:
		if effect and effect.id == effect_id:
			return effect
	return null
