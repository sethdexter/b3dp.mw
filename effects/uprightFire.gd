extends Node3D
## Keeps the flames pointing straight up however the torch, log or fireball holding them is turned.

func _process(_delta: float) -> void:
	global_basis = Basis.from_scale(global_basis.get_scale()) # drop the parent's rotation, keep its size
