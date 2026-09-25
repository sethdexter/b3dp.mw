extends Resource
class_name Stat

#signal statChanged(current: int, max_val: int)
signal depleted # This is what the StatsComponent will listen to

@export var name: String
var majorAttribute: Attribute
var minorAttribute: Attribute

var currentValue: int

func _init(p_Name: String, p_major: Attribute, p_minor: Attribute):
	name = p_Name
	majorAttribute = p_major
	minorAttribute = p_minor
	
	# Safety: Ensure attributes exist before connecting
	if majorAttribute: majorAttribute.value_changed.connect(_on_attribute_updated)
	if minorAttribute: minorAttribute.value_changed.connect(_on_attribute_updated)

	currentValue = get_max_value()

func _on_attribute_updated():
	clamp_current()
	changed.emit(currentValue, get_max_value())

func get_max_value() -> int:
	if not majorAttribute or not minorAttribute: return 1
	var base = (majorAttribute.get_value() * 0.8) + (minorAttribute.get_value() * 0.2)
	return max(1, int(base))

func change_current(delta: int):
	currentValue = clamp(currentValue + delta, 0, get_max_value())
	
	# Emit general change for UI
	changed.emit(currentValue, get_max_value())
	
	# Emit death/depletion signal
	if currentValue <= 0:
		depleted.emit()

func clamp_current():
	currentValue = clamp(currentValue, 0, get_max_value())
