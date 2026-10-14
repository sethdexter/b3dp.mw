class_name FlameSpitProjectile
extends Area3D

## Builds up from nothing in front of the caster, then shoots forward (-Z) with rising acceleration,
## damages the first BaseCharacter it hits, and fades out at the end of its range.

@export var damage: int = 6
## Seconds the light/flames linger after impact.
@export var burnout_time: float = 0.6
## Seconds it grows from nothing in front of the caster before it flies.
@export var charge_time: float = 0.5
## Metres it flies before fading out (overrides the spell's max_range).
@export var fly_range: float = 10.0
## Seconds to cover fly_range. Speeds up, then slows to a stop at the end (ease in-out).
@export var fly_time: float = 0.6
## Last fraction of the flight spent fading out.
@export_range(0.0, 1.0) var fade_portion: float = 0.4
## Size it swells to by the end of the flight.
@export var end_scale: float = 2.5
## Last fraction of the flight spent swelling (while it slows down).
@export_range(0.0, 1.0) var grow_portion: float = 0.5

@onready var flames: GPUParticles3D = $flames
@onready var light: OmniLight3D = $light

var caster: Node = null
var spell: Spell = null
var _done := false
var _anchor: Node3D # follows this (the cast origin) while charging
var _anchor_offset := Vector3.ZERO
var _t := 0.0
var _start := Transform3D()
var _lights: Dictionary[OmniLight3D, float] = {} # light -> full range

func _ready() -> void:
	body_entered.connect(_on_body_entered)
	monitoring = false # can't hit anything until it flies
	scale = Vector3.ONE * 0.01
	for l: OmniLight3D in find_children("*", "OmniLight3D"):
		_lights[l] = l.omni_range # flicker scripts own light_energy, so grow/fade the range instead
		l.omni_range = 0.0

## Call right after adding to the tree. anchor/offset keep it in front of the caster while it charges.
func launch(from: Transform3D, p_caster: Node, p_spell: Spell = null, anchor: Node3D = null, offset := Vector3.ZERO) -> void:
	global_transform = from
	_anchor = anchor
	_anchor_offset = offset
	caster = p_caster
	spell = p_spell
	if spell:
		damage = spell.damage
		# Scale by the caster's skill + attribute.
		var combat = caster.get("combatComponent") if caster else null
		if combat:
			damage = combat.scaled_damage(spell.damage, spell.skill, spell.attribute)

func _physics_process(delta: float) -> void:
	if _done:
		return
	_t += delta
	if _t < charge_time:
		var k := smoothstep(0.0, 1.0, _t / charge_time)
		if is_instance_valid(_anchor):
			var b := _anchor.global_basis.orthonormalized()
			global_transform = Transform3D(b, _anchor.global_position + b.x * _anchor_offset.x + b.y * _anchor_offset.y - b.z * _anchor_offset.z)
		_set_size(k)
		return
	if not monitoring:
		monitoring = true
		_start = global_transform
	var f := clampf((_t - charge_time) / fly_time, 0.0, 1.0)
	var d := 4.0 * f * f * f if f < 0.5 else 1.0 - pow(2.0 - 2.0 * f, 3.0) * 0.5 # ease in-out cubic
	global_position = _start.origin - _start.basis.z * fly_range * d
	var fade := smoothstep(1.0 - fade_portion, 1.0, f)
	if fade > 0.0 and flames.emitting:
		for p: GPUParticles3D in find_children("*", "GPUParticles3D"):
			p.emitting = false # existing flames die out while it swells
	scale = Vector3.ONE * lerpf(1.0, end_scale, smoothstep(1.0 - grow_portion, 1.0, f))
	for l in _lights:
		l.omni_range = _lights[l] * (1.0 - fade)
	if f >= 1.0:
		_burn_out()

func _set_size(k: float) -> void:
	scale = Vector3.ONE * maxf(k, 0.01)
	for l in _lights:
		l.omni_range = _lights[l] * k

func _on_body_entered(body: Node3D) -> void:
	if _done or body == caster:
		return
	if body is BaseCharacter and body.combatComponent and body.statComponent:
		body.combatComponent.take_damage(body.statComponent.health, damage)
		var combat = caster.get("combatComponent") if caster else null
		if combat and spell:
			combat.train_skill(spell.skill, combat.xp_per_hit)
	_burn_out()

func _burn_out() -> void:
	if _done:
		return
	_done = true
	set_deferred("monitoring", false)
	flames.emitting = false
	var tween := create_tween()
	for l in _lights:
		tween.parallel().tween_property(l, "omni_range", 0.0, burnout_time)
	# Let the last particles finish before freeing.
	await get_tree().create_timer(maxf(burnout_time, flames.lifetime)).timeout
	queue_free()
