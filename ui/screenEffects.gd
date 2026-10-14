class_name ScreenEffects
extends CanvasLayer

## No HUD bars: health is shown through the screen itself.
##   - red/dark vignette closes in as health drops
##   - colour drains out at low health
##   - red flash when damaged
##   - heartbeat pulse below `heartbeat_threshold`
##   - colour drains as magicka is spent
##   - view blurs and edges darken with slow breathing as stamina runs out
##   - fade_to() fades to/from black (death, respawn)

@export var character: BaseCharacter
## Health fraction below which the heartbeat pulse starts.
@export_range(0.0, 1.0) var heartbeat_threshold: float = 0.35
## How fast the vignette catches up to the real health value.
@export var smoothing: float = 4.0
## How fast the hit flash fades (per second).
@export var flash_decay: float = 2.5

@onready var overlay: ColorRect = $Overlay
@onready var mat: ShaderMaterial = overlay.material

var _target_loss := 0.0
var _loss := 0.0
var _flash := 0.0
var _last_health := -1
var _time := 0.0
var _target_magicka_loss := 0.0
var _magicka_loss := 0.0
var _target_stamina_loss := 0.0
var _stamina_loss := 0.0
var _fade := 0.0
var _fade_tween: Tween

func _ready() -> void:
	if not character:
		character = get_parent() as BaseCharacter
	if not character or not character.statComponent or not character.statComponent.health:
		push_error("ScreenEffects: needs a BaseCharacter parent with statComponent.health.")
		return
	var health: Stat = character.statComponent.health
	health.value_changed.connect(_on_health_changed)
	_on_health_changed(health.currentValue, health.get_max_value())
	_loss = _target_loss

	var magicka: Stat = character.statComponent.magicka
	if magicka:
		magicka.value_changed.connect(_on_magicka_changed)
		_on_magicka_changed(magicka.currentValue, magicka.get_max_value())
		_magicka_loss = _target_magicka_loss

	var stamina: Stat = character.statComponent.stamina
	if stamina:
		stamina.value_changed.connect(_on_stamina_changed)
		_on_stamina_changed(stamina.currentValue, stamina.get_max_value())
		_stamina_loss = _target_stamina_loss

func _on_stamina_changed(current: int, max_val: int) -> void:
	_target_stamina_loss = 1.0 - clampf(float(current) / maxi(1, max_val), 0.0, 1.0)

## Fade the screen to black (1) or back (0). Await the returned tween to wait for it.
func fade_to(target: float, duration: float) -> Tween:
	if _fade_tween and _fade_tween.is_valid():
		_fade_tween.kill()
	_fade_tween = create_tween()
	_fade_tween.tween_property(self, "_fade", clampf(target, 0.0, 1.0), duration)
	return _fade_tween

func _on_magicka_changed(current: int, max_val: int) -> void:
	_target_magicka_loss = 1.0 - clampf(float(current) / maxi(1, max_val), 0.0, 1.0)

func _on_health_changed(current: int, max_val: int) -> void:
	_target_loss = 1.0 - clampf(float(current) / maxi(1, max_val), 0.0, 1.0)
	if _last_health >= 0 and current < _last_health:
		# Bigger hits flash harder.
		var dmg_frac: float = float(_last_health - current) / maxi(1, max_val)
		_flash = maxf(_flash, clampf(dmg_frac * 4.0, 0.35, 1.0))
	_last_health = current

func _process(delta: float) -> void:
	if not mat:
		return
	_time += delta
	_loss = lerpf(_loss, _target_loss, 1.0 - exp(-smoothing * delta))
	_flash = maxf(0.0, _flash - flash_decay * delta)
	_magicka_loss = lerpf(_magicka_loss, _target_magicka_loss, 1.0 - exp(-smoothing * delta))
	_stamina_loss = lerpf(_stamina_loss, _target_stamina_loss, 1.0 - exp(-smoothing * delta))
	# Slow, heavy breathing (~20 breaths/min).
	var breath := 0.5 + 0.5 * sin(_time * TAU * 0.33)

	# Heartbeat: faster and stronger the closer to death.
	var pulse := 0.0
	var health_frac := 1.0 - _loss
	if health_frac < heartbeat_threshold:
		var danger := 1.0 - health_frac / heartbeat_threshold
		var bpm := lerpf(70.0, 140.0, danger)
		var beat := pow(maxf(0.0, sin(_time * TAU * bpm / 60.0)), 8.0)
		pulse = beat * danger

	mat.set_shader_parameter("health_loss", _loss)
	mat.set_shader_parameter("flash", _flash)
	mat.set_shader_parameter("pulse", pulse)
	mat.set_shader_parameter("magicka_loss", _magicka_loss)
	mat.set_shader_parameter("stamina_loss", _stamina_loss)
	mat.set_shader_parameter("breath", breath)
	mat.set_shader_parameter("fade", _fade)
