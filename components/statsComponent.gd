extends Node
class_name StatsComponent

@export var currentCharacter: Node3D
## Magicka regained per second.
@export var magicka_regen: float = 0.5
## Stamina regained per second.
@export var stamina_regen: float = 3.0
## Seconds after spending stamina before it starts to refill.
@export var stamina_regen_delay: float = 0.8

var health: Stat
var stamina: Stat
var magicka: Stat

signal s_has_died

func _ready():
	# 1. Safety Check: Ensure the character and attributes exist
	if not currentCharacter or not currentCharacter.attributeComponent:
		push_error("StatsComponent: currentCharacter or attributeComponent missing!")
		return

	var attrs = currentCharacter.attributeComponent

	# 2. Initialize Stats (Matching your _init: Name, Major, Minor)
	health = Stat.new("Health", attrs.strength, attrs.vigor)
	stamina = Stat.new("Stamina", attrs.vigor, attrs.agility)
	magicka = Stat.new("Magicka", attrs.intelligence, attrs.wisdom)

	# 3. Connect to the health signal to handle death
	# Assuming you added the 'depleted' or 'changed' signal to the Stat Resource
	health.depleted.connect(_on_health_depleted)

	print("Stats component initialized for: ", currentCharacter.name)

var _magicka_regen_acc := 0.0
var _stamina_regen_acc := 0.0
var _stamina_debt := 0.0
var _stamina_used_msec := 0

func _process(delta: float) -> void:
	_magicka_regen_acc = _regen(magicka, magicka_regen * delta, _magicka_regen_acc)
	if Time.get_ticks_msec() - _stamina_used_msec >= int(stamina_regen_delay * 1000.0):
		_stamina_regen_acc = _regen(stamina, stamina_regen * delta, _stamina_regen_acc)
	else:
		_stamina_regen_acc = 0.0

## Adds whole points to a stat as the fractional accumulator fills. Returns the new accumulator.
func _regen(stat: Stat, amount: float, acc: float) -> float:
	if stat == null or stat.currentValue >= stat.get_max_value():
		return 0.0
	acc += amount
	if acc >= 1.0:
		var points := int(acc)
		acc -= points
		stat.change_current(points)
	return acc

## True if at least `amount` stamina is available (amount 0 = "not empty").
func has_stamina(amount: float = 0.0) -> bool:
	if stamina == null:
		return true
	if amount <= 0.0:
		return stamina.currentValue > 0
	return stamina.currentValue >= ceili(amount)

## Spend stamina; fractional amounts (e.g. per-frame sprint drain) are accumulated.
func spend_stamina(amount: float) -> void:
	if stamina == null or amount <= 0.0:
		return
	_stamina_used_msec = Time.get_ticks_msec()
	_stamina_debt += amount
	if _stamina_debt >= 1.0:
		var points := int(_stamina_debt)
		_stamina_debt -= points
		stamina.change_current(-points)

## Refill health, magicka and stamina (respawn, rest...).
func restore_all() -> void:
	for stat: Stat in [health, magicka, stamina]:
		if stat:
			stat.change_current(stat.get_max_value())
	_stamina_debt = 0.0

func _on_health_depleted():
	has_died()

func has_died():
	s_has_died.emit()
	print("%s has died..." % currentCharacter.name)
