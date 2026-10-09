extends Attribute
class_name Skill

## Skill level = Attribute.baseValue. Skills level up through use (add_xp).

signal leveled_up(new_level: int)
signal xp_changed(xp: float, xp_needed: float)

@export var major_skill_tag: bool
## XP needed for the next level = xp_base + level * xp_per_level.
@export var xp_base: float = 3.0
@export var xp_per_level: float = 2.0

var xp: float = 0.0

func _init(
	p_name: String = "Skill",
	p_is_major: bool = false,
	p_initial_level: int = 1
):
	Name = p_name
	baseValue = p_initial_level
	major_skill_tag = p_is_major

func get_level() -> int:
	return baseValue

func xp_needed() -> float:
	return xp_base + baseValue * xp_per_level

## Gain experience from use. Major skills level faster.
func add_xp(amount: float) -> void:
	if major_skill_tag:
		amount *= 1.5
	xp += amount
	while xp >= xp_needed():
		xp -= xp_needed()
		level_up()
	xp_changed.emit(xp, xp_needed())

func level_up(amount: int = 1):
	baseValue += amount
	print("Your %s skill increased to %d." % [Name, baseValue])
	emit_changed()
	value_changed.emit()
	leveled_up.emit(baseValue)
