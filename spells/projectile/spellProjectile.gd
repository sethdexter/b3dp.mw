class_name SpellProjectile
extends Area3D

## Generic spell projectile: the scene supplies the look, the spell's ProjectileDelivery supplies the motion.
## Builds up from nothing in front of the caster, then flies forward (-Z), speeding up then slowing,
## applies the spell's effects to the first BaseCharacter it hits, and fades out at the end of its range.

## Seconds the light/flames linger after impact.
@export var burnout_time: float = 0.6

@onready var flames: GPUParticles3D = $flames

var caster: Node = null
var spell: Spell = null
var _delivery: ProjectileDelivery
var _done := false
var _anchor: Node3D # follows this (the cast origin) while charging
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

## Call right after adding to the tree. anchor keeps it at the delivery's spawn point while it charges.
func launch(from: Transform3D, p_caster: Node, p_spell: Spell, anchor: Node3D = null) -> void:
	assert(p_spell and p_spell.delivery is ProjectileDelivery, "SpellProjectile needs a spell with a ProjectileDelivery")
	global_transform = from
	_anchor = anchor
	caster = p_caster
	spell = p_spell
	_delivery = spell.delivery

func _physics_process(delta: float) -> void:
	if _done or not _delivery:
		return
	_t += delta
	var p := _delivery.pose(_t)
	if _t < _delivery.charge_time:
		if is_instance_valid(_anchor):
			global_transform = Transform3D(_anchor.global_basis.orthonormalized(), _anchor.global_transform * p[0])
		scale = Vector3.ONE * p[1]
		for l in _lights:
			l.omni_range = _lights[l] * p[1]
		return
	if not monitoring:
		monitoring = true
		_start = Transform3D(global_basis.orthonormalized(), global_position)
	var f: float = p[2]
	global_position = _start * (p[0] - _delivery.spawn_point()) # flight is measured from where the charge ended
	scale = Vector3.ONE * p[1]
	var fade := smoothstep(1.0 - _delivery.fade_portion, 1.0, f)
	if fade > 0.0 and flames.emitting:
		for particles: GPUParticles3D in find_children("*", "GPUParticles3D"):
			particles.emitting = false # existing flames die out while it swells
	for l in _lights:
		l.omni_range = _lights[l] * (1.0 - fade)
	if f >= 1.0:
		_burn_out()

func _on_body_entered(body: Node3D) -> void:
	if _done or body == caster:
		return
	if body is BaseCharacter:
		spell.apply_to(body, caster)
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
