class_name TouchDelivery
extends SpellDelivery

## The effects land on the first character straight ahead within reach of the cast origin.

@export var reach: float = 2.0

func deliver(caster: SpellCasterComponent, spell: Spell) -> void:
	var o := caster.cast_origin
	var q := PhysicsRayQueryParameters3D.create(o.global_position, o.global_position - o.global_basis.z * reach)
	q.exclude = [caster.character.get_rid()]
	var hit := o.get_world_3d().direct_space_state.intersect_ray(q)
	var target := hit.get("collider") as BaseCharacter
	if target:
		spell.apply_to(target, caster.character)
