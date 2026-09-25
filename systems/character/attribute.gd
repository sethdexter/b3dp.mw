extends Resource
class_name Attribute

signal value_changed # Vital for reactivity

@export var Name: String
@export var baseValue: int = 10

var additiveModifiers: Dictionary[String, int] = {}
var multiplicativeModifiers: Dictionary[String, float] = {}

func get_value() -> int:
	var value : float = baseValue
	for v in additiveModifiers.values():
		value += v
	for m in multiplicativeModifiers.values():
		value *= m
	return max(1, int(value))

func add_modifier(source_id: String, add: int = 0, mult: float = 1.0):
	if add != 0: additiveModifiers[source_id] = add
	if mult != 1.0: multiplicativeModifiers[source_id] = mult
	value_changed.emit() # Notify listeners

func remove_modifier(source_id: String):
	additiveModifiers.erase(source_id)
	multiplicativeModifiers.erase(source_id)
	value_changed.emit()
