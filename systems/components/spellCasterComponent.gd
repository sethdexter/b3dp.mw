class_name SpellCasterComponent
extends Node

## Casts `current_spell` on the "fireball" action (right mouse button).
## Pays magicka from the character's StatsComponent. Ignored while the inventory is open.

@export var character: BaseCharacter
## Spells fire from here, along its -Z (the camera).
@export var cast_origin: Node3D
@export var current_spell: Spell
## Spawn offset in front of the camera (x = right, y = up, z = forward).
@export var spawn_offset := Vector3(-0.15, -0.15, 0.8)

var _ready_at_msec := 0

func _ready() -> void:
	if not character:
		character = get_parent() as BaseCharacter

func _unhandled_input(event: InputEvent) -> void:
	if InputMap.has_action("fireball") and event.is_action_pressed("fireball"):
		if _inventory_open() or character.is_dead:
			return
		cast(current_spell)

func cast(spell: Spell) -> bool:
	if spell == null or spell.projectile == null or cast_origin == null:
		return false
	if Time.get_ticks_msec() < _ready_at_msec:
		return false
	var stats := character.statComponent
	if not stats:
		return false

	if not _can_pay(stats, spell):
		print("Not enough magicka for %s." % spell.Name)
		return false
	_pay(stats, spell)
	_ready_at_msec = Time.get_ticks_msec() + int(spell.cooldown * 1000.0)

	var projectile := spell.projectile.instantiate() as Node3D
	get_tree().current_scene.add_child(projectile)

	var basis := cast_origin.global_basis
	var origin := cast_origin.global_position \
		+ basis.x * spawn_offset.x + basis.y * spawn_offset.y - basis.z * spawn_offset.z
	var from := Transform3D(basis.orthonormalized(), origin)
	if projectile.has_method("launch"):
		projectile.launch(from, character, spell)
	else:
		projectile.global_transform = from
	return true

func _can_pay(stats: StatsComponent, spell: Spell) -> bool:
	if spell.cost_magicka > 0 and (stats.magicka == null or stats.magicka.currentValue < spell.cost_magicka):
		return false
	if spell.cost_stamina > 0 and (stats.stamina == null or stats.stamina.currentValue < spell.cost_stamina):
		return false
	if spell.cost_health > 0 and stats.health.currentValue <= spell.cost_health:
		return false
	return true

func _pay(stats: StatsComponent, spell: Spell) -> void:
	if spell.cost_magicka > 0: stats.magicka.change_current(-spell.cost_magicka)
	if spell.cost_stamina > 0: stats.spend_stamina(spell.cost_stamina)
	if spell.cost_health > 0:  stats.health.change_current(-spell.cost_health)

func _inventory_open() -> bool:
	for child in character.get_children():
		if child is PlayerInventoryUI:
			return child.is_open
	return false
