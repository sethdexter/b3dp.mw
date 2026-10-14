extends GPUParticles3D
## Breathes the smoke density: amount_ratio swings smoothly between min_ratio and max_ratio.

@export_range(0.0, 1.0, 0.01) var min_ratio := 0.3
@export_range(0.0, 1.0, 0.01) var max_ratio := 0.5
## Seconds for one swing from min to max and back.
@export_range(0.1, 10.0, 0.1, "suffix:s") var period := 1.0

var _t := randf() * 10.0 # desync multiple smokes

func _process(delta: float) -> void:
	_t += delta
	amount_ratio = lerpf(min_ratio, max_ratio, 0.5 + 0.5 * sin(_t * TAU / period))
