extends Attribute
class_name Skill

@export var major_skill_tag: bool

# We use the parent's baseValue as the "Skill Level"
func _init(
	p_name: String = "Skill", 
	p_is_major: bool = false, 
	p_initial_level: int = 1
):
	# Set parent Attribute properties
	Name = p_name
	baseValue = p_initial_level
	major_skill_tag = p_is_major

# Skills might have specific logic, like a 'Level Up'
func level_up(amount: int = 1):
	baseValue += amount
	# emit_changed() is the native Resource signal
	emit_changed() 
	# value_changed is your custom signal from Attribute.gd
	value_changed.emit()
