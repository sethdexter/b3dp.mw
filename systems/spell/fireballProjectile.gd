class_name FireballProjectile
extends Area3D

## Flies straight forward (-Z), damages the first BaseCharacter it hits, then burns out.

@export var speed: float = 18.0
@export var max_range: float = 40.0
@export var damage: int = 6
## Seconds the light/flames linger after impact.
@export var burnout_time: float = 0.6

@onready var flames: GPUParticles3D = $flames
@onready var light: OmniLight3D = $light

var caster: Node = null
var spell: Spell = null
var _travelled := 0.0
var _done := false

func _ready() -> void:
	body_entered.connect(_on_body_entered)

## Call right after adding to the tree.
func launch(from: Transform3D, p_caster: Node, p_spell: Spell = null) -> void:
	global_transform = from
	caster = p_caster
	spell = p_spell
	if spell:
		damage = spell.damage
		speed = spell.speed
		max_range = spell.max_range
		# Scale by the caster's skill + attribute.
		var combat = caster.get("combatComponent") if caster else null
		if combat:
			damage = combat.scaled_damage(spell.damage, spell.skill, spell.attribute)

func _physics_process(delta: float) -> void:
	if _done:
		return
	var step := speed * delta
	global_position += -global_basis.z * step
	_travelled += step
	if _travelled >= max_range:
		_burn_out()

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
	tween.tween_property(light, "light_energy", 0.0, burnout_time)
	# Let the last particles finish before freeing.
	await get_tree().create_timer(maxf(burnout_time, flames.lifetime)).timeout
	queue_free()
