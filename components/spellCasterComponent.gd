@tool
class_name SpellCasterComponent
extends Node

## Casts `current_spell` on the "cast" action (right mouse button): checks the cooldown, pays the cost,
## then hands over to the spell's delivery (projectile, self or touch), which applies the spell's effects.
## Pays magicka from the character's StatsComponent. Ignored while the inventory is open.
## Editor preview group: shows the current spell's projectile at the spawn point and plays the cast (never saved, editor only).

@export var character: BaseCharacter
## Spells fire from here, along its -Z (the camera).
@export var cast_origin: Node3D
@export var current_spell: Spell
## Spells you know (Z cycles). Empty = every spell in res://spells/data.
@export var known_spells: Array[Spell] = []

@export_group("Editor preview")
## Seconds into the cast: build-up in front of the camera, then the flight.
@export_range(0.0, 1.0, 0.01, "suffix:s") var preview_timeline := 0.0
## Loop the cast automatically.
@export var preview_play := false
## 1 = game speed, 4 = four times slower.
@export_range(1.0, 10.0, 0.5) var preview_slow_motion := 1.0
@export var show_preview := false:
	set(v):
		show_preview = v
		_clear_preview()

var _ready_at_msec := 0
var _ghost: Node3D # editor preview projectile, never saved

func _ready() -> void:
	if not character:
		character = get_parent() as BaseCharacter
	if known_spells.is_empty() and not Engine.is_editor_hint():
		for f in DirAccess.get_files_at("res://spells/data"):
			var s = load("res://spells/data/" + f.trim_suffix(".remap"))
			if s is Spell:
				known_spells.append(s)
	if current_spell == null and not known_spells.is_empty():
		current_spell = known_spells[0]

func _unhandled_input(event: InputEvent) -> void:
	if Engine.is_editor_hint():
		return
	if event is InputEventKey and event.pressed and not event.echo and event.keycode == KEY_Z and not known_spells.is_empty():
		current_spell = known_spells[posmod(known_spells.find(current_spell) + 1, known_spells.size())]
		var needs := ", ".join(current_spell.reagents.keys().map(func(k): return "%d %s" % [current_spell.reagents[k], k.replace("_", " ")]))
		Talker.notify("Spell: %s (%d magicka%s)" % [current_spell.Name, current_spell.cost_magicka, (", " + needs) if needs != "" else ""], 2.5)
		return
	if InputMap.has_action("cast") and event.is_action_pressed("cast"):
		if _inventory_open() or character.is_dead:
			return
		cast(current_spell)

func cast(spell: Spell) -> bool:
	if spell == null or spell.delivery == null or cast_origin == null:
		return false
	if Time.get_ticks_msec() < _ready_at_msec:
		return false
	var stats := character.statComponent
	if not stats:
		return false

	if not _can_pay(stats, spell):
		print("Not enough magicka for %s." % spell.Name)
		return false
	var inv: InventoryComponent = character.get("inventoryComponent")
	var db := get_node_or_null("/root/item_list")
	for id in spell.reagents: # the reagents: no casting without them
		if not inv or not db or inv.count_item(db.get_item_instance(id)) < spell.reagents[id]:
			Talker.notify("%s needs %d %s." % [spell.Name, spell.reagents[id], id.replace("_", " ")])
			return false
	for id in spell.reagents:
		var it: Item = db.get_item_instance(id)
		var left: int = spell.reagents[id]
		for key: Item in inv.inventory.keys():
			if left > 0 and InventoryComponent.is_same_item(key, it):
				left -= inv.remove_item(key, left)
	_pay(stats, spell)
	_ready_at_msec = Time.get_ticks_msec() + int(spell.cooldown * 1000.0)

	spell.delivery.deliver(self, spell)
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

# ---------- editor preview ----------

func _validate_property(property: Dictionary) -> void:
	if property.name == "preview_timeline":
		property.hint_string = "0,%s,0.01,suffix:s" % _preview_duration() # slider ends when the flight does

func _preview_delivery() -> ProjectileDelivery:
	return current_spell.delivery as ProjectileDelivery if current_spell else null

func _preview_duration() -> float:
	var d := _preview_delivery()
	return d.charge_time + d.fly_time if d else 1.0

func _process(delta: float) -> void:
	if not Engine.is_editor_hint():
		set_process(false)
		return
	var delivery := _preview_delivery() # only projectile spells have something to show
	if not show_preview or not cast_origin or not delivery or not delivery.projectile:
		_clear_preview()
		return
	if not is_instance_valid(_ghost):
		_ghost = delivery.projectile.instantiate() as Node3D
		cast_origin.add_child(_ghost) # no owner, so it's never written into the scene
		notify_property_list_changed()
	var d := _preview_duration()
	if preview_play:
		preview_timeline = fmod(preview_timeline + delta / preview_slow_motion, d + 0.4) # brief pause before looping
	var p := delivery.pose(minf(preview_timeline, d))
	_ghost.position = p[0]
	_ghost.scale = Vector3.ONE * p[1]

func _clear_preview() -> void:
	if is_instance_valid(_ghost):
		_ghost.queue_free()
	_ghost = null

func _exit_tree() -> void:
	_clear_preview()
