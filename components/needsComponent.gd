class_name NeedsComponent
extends Node
## Hunger and thirst. Both run from 100 (fed / watered) down to 0 (starving / parched) over time, faster while
## you sprint. There are no bars: you're told in words as you cross each stage ("Your stomach growls."), and
## going without starts to cost you:
##   - below the "weak" level, stamina refills slower
##   - at 0 you slowly lose health until you eat or drink
## Eat and drink with food/drink items (NourishEffect on the item). Put this node on any BaseCharacter;
## only the player gets messages.

## Who this belongs to (defaults to the parent).
@export var character: BaseCharacter

@export_group("Hunger", "hunger_")
## Starting fullness (0-100).
@export_range(0.0, 100.0, 1.0) var hunger_start := 100.0
## Real minutes to go from full to starving if you do nothing but stand around.
@export_range(1.0, 240.0, 1.0, "suffix:min") var hunger_minutes := 15.0
## Health lost per second while starving (at 0).
@export_range(0.0, 5.0, 0.05, "suffix:/s") var hunger_damage := 0.3

@export_group("Thirst", "thirst_")
@export_range(0.0, 100.0, 1.0) var thirst_start := 100.0
## Thirst runs out faster than hunger by default.
@export_range(1.0, 240.0, 1.0, "suffix:min") var thirst_minutes := 10.0
## Health lost per second while parched (at 0).
@export_range(0.0, 5.0, 0.05, "suffix:/s") var thirst_damage := 0.3

@export_group("Effects")
## Both drain this many times faster while sprinting.
@export_range(1.0, 5.0, 0.1) var sprint_multiplier := 1.5
## Below this you're "weak": stamina refills at weak_stamina_regen of its normal rate.
@export_range(0.0, 100.0, 1.0) var weak_below := 20.0
@export_range(0.0, 1.0, 0.05) var weak_stamina_regen := 0.4
## Message stages: crossing one of these (going down) prints its line. Matched to *_lines by order.
@export var stages: PackedFloat32Array = [60.0, 30.0, 10.0, 0.0]
@export var hunger_lines: PackedStringArray = ["You could eat.", "Your stomach growls.", "You're weak with hunger.", "You are starving."]
@export var thirst_lines: PackedStringArray = ["Your mouth is dry.", "You're thirsty.", "Your head pounds with thirst.", "You are parched."]

## 0-100. Read these for UI or AI; change them with eat() / drink().
var hunger := 100.0
var thirst := 100.0

signal needs_changed(hunger: float, thirst: float)

var _base_regen := -1.0
var _damage_acc := 0.0

func _ready() -> void:
	if not character:
		character = get_parent() as BaseCharacter
	hunger = hunger_start
	thirst = thirst_start
	_same_rates.call_deferred() # once the island's sim is up

## You get hungry and thirsty as fast as everyone else on the island (Minds > Needs drain).
func _same_rates() -> void:
	var camps = get_tree().get_first_node_in_group("camps")
	var minds = camps.get_node_or_null("minds") if camps else null
	if minds:
		hunger_minutes = 100.0 / maxf(0.01, minds.food_drain)
		thirst_minutes = 100.0 / maxf(0.01, minds.water_drain)

func eat(amount: float) -> void:
	hunger = clampf(hunger + amount, 0.0, 100.0)
	needs_changed.emit(hunger, thirst)

func drink(amount: float) -> void:
	thirst = clampf(thirst + amount, 0.0, 100.0)
	needs_changed.emit(hunger, thirst)

func _process(delta: float) -> void:
	if not character or character.is_dead:
		return
	var rate := delta * (sprint_multiplier if _sprinting() else 1.0)
	var h := hunger
	var t := thirst
	hunger = maxf(hunger - rate * 100.0 / (hunger_minutes * 60.0), 0.0)
	thirst = maxf(thirst - rate * 100.0 / (thirst_minutes * 60.0), 0.0)
	_announce(h, hunger, hunger_lines)
	_announce(t, thirst, thirst_lines)
	needs_changed.emit(hunger, thirst)
	_apply_effects(delta)

func _sprinting() -> bool:
	var c = character.controllerComponent
	return c != null and c.has_method("_is_sprinting") and c._is_sprinting()

## Weak = slower stamina; empty = health drains (whole points, as the fractions add up).
func _apply_effects(delta: float) -> void:
	var stats := character.statComponent
	if not stats:
		return
	if _base_regen < 0.0:
		_base_regen = stats.stamina_regen
	stats.stamina_regen = _base_regen * (weak_stamina_regen if minf(hunger, thirst) < weak_below else 1.0)
	_damage_acc += ((hunger_damage if hunger <= 0.0 else 0.0) + (thirst_damage if thirst <= 0.0 else 0.0)) * delta
	if _damage_acc >= 1.0 and stats.health:
		var points := int(_damage_acc)
		_damage_acc -= points
		stats.health.change_current(-points)

## Prints a stage's line the moment `now` drops past it.
func _announce(before: float, now: float, lines: PackedStringArray) -> void:
	if not character.controllerComponent: # only the player hears about it
		return
	for i in mini(stages.size(), lines.size()):
		if before > stages[i] and now <= stages[i]:
			Talker.notify(lines[i])
