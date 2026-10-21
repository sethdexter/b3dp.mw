class_name DarknessComponent
extends Node
## The dark is dangerous. You're "in the light" near a lit campfire (group "campfire") or a burning torch
## (group "light_source", including the one in your hand). Out of it:
##   - after grace_time, stamina drains (and it won't refill)
##   - after dread_time, health drains too
##   - monsters notice you from further off (MobAIComponent.dark_aggro_multiplier)
## You're told when the dark closes in and when you reach light again. No bars, as with everything else.

@export var character: BaseCharacter

@export_group("Light")
## How far a campfire's light reaches.
@export_range(1.0, 40.0, 0.5, "suffix:m") var fire_light_radius := 14.0
## How far a burning torch's light reaches (yours or one lying in the world).
@export_range(1.0, 30.0, 0.5, "suffix:m") var torch_light_radius := 8.0
## Seconds between light checks (cheap either way; lower = snappier messages).
@export_range(0.05, 2.0, 0.05, "suffix:s") var check_every := 0.25

@export_group("In the dark")
## Seconds in the dark before it starts to cost you.
@export_range(0.0, 120.0, 1.0, "suffix:s") var grace_time := 8.0
## Stamina lost per second once the grace time is over.
@export_range(0.0, 20.0, 0.1, "suffix:/s") var stamina_drain := 1.5
## Seconds in the dark before health starts to go as well.
@export_range(0.0, 600.0, 5.0, "suffix:s") var dread_time := 60.0
## Health lost per second after dread_time.
@export_range(0.0, 5.0, 0.05, "suffix:/s") var health_drain := 0.25
## Seconds in the dark before you're told about it (stepping just past a fire's edge says nothing).
@export_range(0.0, 60.0, 0.5, "suffix:s") var warn_after := 5.0
@export var enter_dark_line := "Tenebrae. The dark closes around you."
@export var dread_line := "Something in the dark is wearing you down."
@export var enter_light_line := "Lux. You breathe again."

## True once you've been out of the light for warn_after seconds (read by monsters).
var in_dark := false
## True the moment you step out of the light.
var out_of_light := false
## Seconds spent in the dark this time.
var dark_time := 0.0

var _check := 0.0
var _drain_acc := 0.0

func _ready() -> void:
	if not character:
		character = get_parent() as BaseCharacter

func _process(delta: float) -> void:
	if not character or character.is_dead:
		return
	_check -= delta
	if _check <= 0.0:
		_check = check_every
		var dark := not _lit()
		_reprieve = dark and _in_reprieve()
		if dark != out_of_light:
			out_of_light = dark
			if not dark and in_dark:
				Talker.notify(enter_light_line) # only if you were told it was dark
			in_dark = false
			dark_time = 0.0
	if not out_of_light:
		_rest(delta)
		return
	if _reprieve:
		return # by a smoulder: the dark holds off, but you don't heal and it picks up where it left off
	var before := dark_time
	dark_time += delta
	if before < warn_after and dark_time >= warn_after:
		in_dark = true # the dark only takes hold now: monsters see you better from here on
		Talker.notify(enter_dark_line)
	if before < dread_time and dark_time >= dread_time:
		Talker.notify(dread_line)
	var stats := character.statComponent
	if stats and dark_time > grace_time:
		stats.spend_stamina(stamina_drain * delta) # spending also holds off stamina regen
		if dark_time > dread_time and stats.health:
			_drain_acc += health_drain * delta
			if _drain_acc >= 1.0:
				var points := int(_drain_acc)
				_drain_acc -= points
				stats.health.change_current(-points)

var _heal_acc := 0.0

## By a fire you heal slowly, as everyone does (Minds > rest_heal: health per minute out of 100).
func _rest(delta: float) -> void:
	var stats := character.statComponent
	var camps = get_tree().get_first_node_in_group("camps")
	var minds = camps.get_node_or_null("minds") if camps else null
	if not stats or not stats.health or not minds or not _at_fire():
		return
	_heal_acc += minds.rest_heal / 100.0 * stats.health.get_max_value() / 60.0 * delta
	if _heal_acc >= 1.0:
		var points := int(_heal_acc)
		_heal_acc -= points
		stats.health.change_current(points)

func _at_fire() -> bool:
	for fire: Node3D in get_tree().get_nodes_in_group("campfire"):
		if fire.global_position.distance_to(character.global_position) < fire.get_meta("light_radius", fire_light_radius):
			return true
	return false

var _reprieve := false

## Near a "reprieve" light (a smoulder): its meta light_radius.
func _in_reprieve() -> bool:
	var at := character.global_position
	for n: Node3D in get_tree().get_nodes_in_group("reprieve"):
		if n.global_position.distance_to(at) < n.get_meta("light_radius", 5.0):
			return true
	return false

func _lit() -> bool:
	var at := character.global_position
	for fire: Node3D in get_tree().get_nodes_in_group("campfire"):
		if fire.global_position.distance_to(at) < fire.get_meta("light_radius", fire_light_radius): # bigger fires reach further
			return true
	for torch: Node3D in get_tree().get_nodes_in_group("light_source"):
		var flame := torch.get_node_or_null("fire_effect") as Node3D
		if flame and flame.visible and torch.global_position.distance_to(at) < torch_light_radius:
			return true
	return false
