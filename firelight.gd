extends OmniLight3D

@export var min_energy: float = 0.4
@export var max_energy: float = 1.35
@export var flicker_speed: float = 0.8

var noise := FastNoiseLite.new()
var time_passed: float = 0.0
var update_timer: float = 0.0
const UPDATE_INTERVAL: float = 0.05  # Updates 20 times per second instead of every frame

func _ready() -> void:
	noise.noise_type = FastNoiseLite.TYPE_SIMPLEX
	noise.frequency = 0.8
	time_passed = randf_range(0.0, 1000.0)
	flicker_speed += randf_range(-0.15, 0.15)

func _process(delta: float) -> void:
	update_timer += delta
	if update_timer < UPDATE_INTERVAL:
		return
		
	# Account for the elapsed time step in our calculations
	time_passed += update_timer * flicker_speed
	update_timer = 0.0  # Reset timer
	
	var raw_noise = (noise.get_noise_1d(time_passed) + 1.0) * 0.5
	var shaped_noise = pow(raw_noise, 3.5)
	
	light_energy = lerp(min_energy, max_energy, shaped_noise)
	
	var warm_orange = Color(1.0, 0.65, 0.2)
	var deep_amber = Color(1.0, 0.45, 0.1)
	light_color = deep_amber.lerp(warm_orange, shaped_noise)
