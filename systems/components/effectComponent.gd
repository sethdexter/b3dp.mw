extends Node
class_name EffectComponent

signal effects_changed

var active_effects: Array[Effect] = []

func add_effect(effect: Effect) -> void:
	if not effect:
		return
	active_effects.append(effect)
	effects_changed.emit()

func remove_effect(effect: Effect) -> void:
	if active_effects.erase(effect):
		effects_changed.emit()
