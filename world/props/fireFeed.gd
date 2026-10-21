extends StaticBody3D
## Put on a camp's campfire (world/camps.gd sets it as the fire's script): the fire burns the camp's fuel
## (Camp.job.fire_fuel, seconds), and you can feed it. Look at it and press E with ash wood in your pack to put
## a log on. Its people feed it from their own stores (world/camplife.gd); let it go out and it's a cold fire.

var record = null # the Camp
var _t := 0.0
var _base := {} # flame node -> its scale; the light's energies

## The fire burns as big as the wood on it: flames and light grow with it (and so does how far its light reaches
## for you and everyone: meta "light_radius", read by DarknessComponent and minds.gd).
func _process(delta: float) -> void:
	_t += delta
	if _t < 0.5 or not record:
		return
	_t = 0.0
	var camps = get_tree().get_first_node_in_group("camps")
	if not camps or not camps.camplife:
		return
	var s: float = camps.camplife.fire_scale(record)
	for n in get_children():
		if n is Node3D and n.name.begins_with("flames"):
			if not _base.has(n):
				_base[n] = n.scale
			n.scale = _base[n] * s
	var light := get_node_or_null("firelight")
	if light:
		if not _base.has("light"):
			_base["light"] = [light.min_energy, light.max_energy]
		light.min_energy = _base.light[0] * s * s # brighter faster than it grows
		light.max_energy = _base.light[1] * s * s
	set_meta("light_radius", 14.0 * s)

func show_prompt() -> void:
	if record:
		var mins: float = record.job.get("fire_fuel", 0.0) / 60.0
		var life = get_tree().get_first_node_in_group("camps").camplife
		Talker.notify("%s, %s, keeps %d  [E] feed it a log" % [life.fire_name(record), "burning low" if mins < 5.0 else "%.0f min of wood on it" % mins, life.capacity(record)], 1.5)

func hide_prompt() -> void:
	pass

func interact(player: Node) -> void:
	var camps = get_tree().get_first_node_in_group("camps")
	if not record or not camps or not player.inventoryComponent:
		return
	var inv: InventoryComponent = player.inventoryComponent
	var wood: Item = get_node("/root/item_list").get_item_instance("ash_wood")
	if inv.count_item(wood) <= 0:
		Talker.notify("You've no wood to give it.")
		return
	if record.job.get("fire_fuel", 0.0) >= camps.camplife.max_fire_logs * camps.camplife.wood_burn:
		Talker.notify("It can't take any more.")
		return
	for key: Item in inv.inventory.keys():
		if InventoryComponent.is_same_item(key, wood):
			inv.remove_item(key, 1)
			break
	record.job["fire_fuel"] = record.job.get("fire_fuel", 0.0) + camps.camplife.wood_burn
	if camps.minds:
		camps.minds.rep(record, camps.minds.rep_trade) # strangers bring fuel: they remember it
	Talker.notify("You put a log on the fire.")
