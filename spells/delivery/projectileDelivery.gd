class_name ProjectileDelivery
extends SpellDelivery

## Spawns a projectile that builds up in front of the caster, flies off and applies the effects to what it hits.
## The projectile scene is only the look; all its motion comes from here.

## Scene spawned on cast (its look; it runs SpellProjectile).
@export var projectile: PackedScene
## Where it appears, from the caster's cast origin (x = right, y = up, z = forward).
@export var spawn_offset := Vector3(-0.15, -0.15, 0.8)
## Seconds it grows from nothing at the spawn point, following the caster, before it flies.
@export var charge_time: float = 0.5
## Metres it flies before fading out.
@export var fly_range: float = 10.0
## Seconds to cover fly_range. Speeds up, then slows to a stop at the end (ease in-out).
@export var fly_time: float = 0.6
## Last fraction of the flight spent fading out.
@export_range(0.0, 1.0) var fade_portion: float = 0.4
## Size it swells to by the end of the flight.
@export var end_scale: float = 2.5
## Last fraction of the flight spent swelling (while it slows down).
@export_range(0.0, 1.0) var grow_portion: float = 0.5

func deliver(caster: SpellCasterComponent, spell: Spell) -> void:
	if not projectile:
		return
	var p := projectile.instantiate() as SpellProjectile
	caster.get_tree().current_scene.add_child(p)
	var o := caster.cast_origin
	var from := Transform3D(o.global_basis.orthonormalized(), o.global_transform * spawn_point())
	p.launch(from, caster.character, spell, o)

## spawn_offset in the cast origin's own space (-Z is forward there).
func spawn_point() -> Vector3:
	return Vector3(spawn_offset.x, spawn_offset.y, -spawn_offset.z)

## Where the projectile is t seconds after the cast, relative to the cast origin, how big it is, and how far
## through the flight (0-1). Used by SpellProjectile and the editor preview so both always match.
func pose(t: float) -> Array:
	if t < charge_time:
		return [spawn_point(), maxf(smoothstep(0.0, 1.0, t / charge_time), 0.01), 0.0]
	var f := clampf((t - charge_time) / fly_time, 0.0, 1.0)
	var e := 4.0 * f * f * f if f < 0.5 else 1.0 - pow(2.0 - 2.0 * f, 3.0) * 0.5 # ease in-out cubic
	var size := lerpf(1.0, end_scale, smoothstep(1.0 - grow_portion, 1.0, f))
	return [spawn_point() + Vector3(0, 0, -fly_range * e), size, f]
