extends Resource
class_name Stat

## Emitted whenever current or max value changes (use for UI bars).
## NOTE: don't use Resource's built-in `changed` signal for this - it takes no arguments.
signal value_changed(current: int, max_val: int)
signal depleted # This is what the StatsComponent will listen to

@export var name: String
var majorAttribute: Attribute
var minorAttribute: Attribute

var currentValue: int

# Default args so the engine can instantiate/duplicate this Resource.
func _init(p_Name: String = "Stat", p_major: Attribute = null, p_minor: Attribute = null):
	name = p_Name
	majorAttribute = p_major
	minorAttribute = p_minor

	# Safety: Ensure attributes exist before connecting
	if majorAttribute: majorAttribute.value_changed.connect(_on_attribute_updated)
	if minorAttribute: minorAttribute.value_changed.connect(_on_attribute_updated)

	currentValue = get_max_value()

func _on_attribute_updated():
	clamp_current()
	value_changed.emit(currentValue, get_max_value())

func get_max_value() -> int:
	if not majorAttribute or not minorAttribute: return 1
	var base = (majorAttribute.get_value() * 0.8) + (minorAttribute.get_value() * 0.2)
	return max(1, int(base))

func change_current(delta: int):
	var was_alive := currentValue > 0
	currentValue = clamp(currentValue + delta, 0, get_max_value())

	# Emit general change for UI
	value_changed.emit(currentValue, get_max_value())

	# Emit death/depletion signal once, on the transition to 0
	if was_alive and currentValue <= 0:
		depleted.emit()

func clamp_current():
	currentValue = clamp(currentValue, 0, get_max_value())
