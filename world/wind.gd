extends Node
## One wind for the whole island. Fire flames, embers and smoke lean with it (their particle gravity) and the
## grass leans and sways the same way (global shader parameter "wind"). Gusts come and go on their own.
## Put one in the level; tweak it while the game runs and everything follows.

## Direction the wind blows TOWARD, in degrees around the up axis (0 = +X / east, 90 = +Z / south).
@export_range(0.0, 360.0, 1.0, "suffix:deg") var direction := 30.0
## Steady wind strength. 0 = dead calm.
@export_range(0.0, 3.0, 0.05) var strength := 0.6
## Gusts add up to this much on top, rising and falling every gust_period seconds or so.
@export_range(0.0, 3.0, 0.05) var gust := 0.5
@export_range(1.0, 60.0, 0.5, "suffix:s") var gust_period := 9.0
## How hard each thing is pushed sideways per unit of wind (they still rise as before).
@export_range(0.0, 5.0, 0.05) var flame_push := 0.6
@export_range(0.0, 5.0, 0.05) var ember_push := 1.2
@export_range(0.0, 5.0, 0.05) var smoke_push := 0.9
## How far grass tips lean with the wind (metres per unit of wind).
@export_range(0.0, 2.0, 0.05) var grass_lean := 0.25

var _mats: Array = [] # [ParticleProcessMaterial, push, upward gravity it had]
var _t := 0.0

func _ready() -> void:
	# The scenes share their process materials, so pushing these once moves every fire on the island.
	var fire: Node = load("res://effects/torchFire.tscn").instantiate()
	_grab(fire.get_node_or_null("flames"), "flame_push")
	_grab(fire.get_node_or_null("embers"), "ember_push")
	fire.free()
	var smoke: Node = load("res://effects/smoke.tscn").instantiate()
	_grab(smoke, "smoke_push")
	smoke.free()

func _grab(p: Node, push: String) -> void:
	if p is GPUParticles3D and p.process_material is ParticleProcessMaterial:
		var m: ParticleProcessMaterial = p.process_material
		_mats.append([m, push, m.gravity.y])

func _process(delta: float) -> void:
	_t += delta
	var gusting := 0.5 + 0.5 * sin(_t * TAU / gust_period) * sin(_t * TAU / (gust_period * 2.7)) # uneven swells
	var w := (strength + gust * gusting) * Vector2.from_angle(deg_to_rad(direction))
	for e: Array in _mats:
		var m: ParticleProcessMaterial = e[0]
		var push: float = get(e[1])
		m.gravity = Vector3(w.x * push, e[2], w.y * push)
	RenderingServer.global_shader_parameter_set("wind", w * grass_lean)
