class_name SimClock
extends Node
## The world simulation's clock (camps, minds, meetings, encounters, sources all read SimClock.now), plus a
## testing fast-forward: press ] to double the speed (up to max_speed), [ to halve it back down to 1x.
## While sped up you're immortal (health can't drop) so you can watch the island change without dying.
## The Camps node makes one of these at runtime.

@export_range(2, 64) var max_speed := 16
## Physics steps allowed per frame grow with the speed so things still move properly when it's high.
@export_range(1, 32) var physics_steps_per_x := 2

## Seconds of simulated time since the level started (runs faster when sped up).
static var now := 0.0
static var speed := 1

var _player: Node

func _ready() -> void:
	now = 0.0
	_set_speed(1)

func _process(delta: float) -> void:
	now += delta # delta is already scaled by Engine.time_scale

func _unhandled_input(event: InputEvent) -> void:
	if not (event is InputEventKey and event.pressed and not event.echo):
		return
	if event.keycode == KEY_BRACKETRIGHT:
		_set_speed(mini(speed * 2, max_speed))
	elif event.keycode == KEY_BRACKETLEFT:
		_set_speed(maxi(speed / 2, 1))

func _set_speed(s: int) -> void:
	speed = s
	Engine.time_scale = s
	Engine.max_physics_steps_per_frame = maxi(8, s * physics_steps_per_x)
	if not is_instance_valid(_player):
		_player = get_tree().get_first_node_in_group("player")
	var stats = _player.get("statComponent") if _player else null
	if stats and stats.health:
		stats.health.locked = s > 1 # immortal while fast-forwarding
	if is_inside_tree() and s > 0 and get_tree().get_frame() > 0:
		Talker.notify("Simulation speed x%d%s" % [s, "  (you can't die)" if s > 1 else ""], 2.0)
