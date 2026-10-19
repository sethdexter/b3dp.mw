extends Node
## Saves and loads the whole simulation, and you. The Camps node owns this (child "save", made at runtime).
##   F5           save now
##   F9           load the last save (the level reloads and picks it up)
##   Shift+F9     a fresh island: the save is deleted and the level reloads from scratch
## It also saves every autosave_every seconds and when you quit, and the island loads from the save on start if
## there is one. Saved: the sim clock, every camp / place / group and every character record (all their state:
## needs, packs, stores, tasks, memories, health...), the trees you've cut, the storm, names; and you: where you
## are, health, stamina, hunger, thirst, your pack (with each torch's fuel and each tool's wear) and what you wear.
## Bodies, fires and props near you aren't saved: they're rebuilt from the records, as always.

const PATH := "user://island.save"
const VERSION := 1

## Seconds of real time between autosaves (0 = never).
@export_range(0.0, 3600.0, 10.0, "suffix:s") var autosave_every := 300.0

var camps: Node
var _t := 0.0
var _player_data := {} # loaded, applied once you exist

func _ready() -> void:
	camps = get_parent()
	get_tree().auto_accept_quit = false # save on the way out (see _notification)

func has_save() -> bool:
	return FileAccess.file_exists(PATH)

func _process(delta: float) -> void:
	if autosave_every <= 0.0:
		return
	_t += delta / maxf(1.0, Engine.time_scale) # real seconds, whatever the sim speed
	if _t > autosave_every:
		_t = 0.0
		save()

func _notification(what: int) -> void:
	if what == NOTIFICATION_WM_CLOSE_REQUEST:
		save()
		get_tree().quit()

func _unhandled_input(event: InputEvent) -> void:
	if not (event is InputEventKey and event.pressed and not event.echo):
		return
	if event.keycode == KEY_F5:
		save()
		Talker.notify("Saved.", 1.5)
	elif event.keycode == KEY_F9 and event.shift_pressed:
		if has_save():
			DirAccess.remove_absolute(ProjectSettings.globalize_path(PATH))
		_reload()
	elif event.keycode == KEY_F9 and has_save():
		_reload()

func _reload() -> void:
	Engine.time_scale = 1.0
	get_tree().reload_current_scene()

# --- saving --------------------------------------------------------------------------------------------------

func save() -> void:
	var cid := {} # Camp -> index, Folk -> index (references are saved as indices)
	var fid := {}
	for i in camps.camps.size():
		cid[camps.camps[i]] = i
	for i in camps.folk.size():
		fid[camps.folk[i]] = i
	var cs := []
	for c in camps.camps:
		cs.append({"pos": c.pos, "bandit": c.bandit, "kind": c.kind, "wild": c.wild, "looted": c.looted,
			"job": _out(c.job, cid, fid), "members": _out(c.members, cid, fid), "next_move": c.next_move,
			"raid": _out(c.raid, cid, fid), "raid_since": c.raid_since, "roaming": c.roaming, "from": _out(c.from, cid, fid),
			"den": _out(c.den, cid, fid), "heading": c.heading, "waypoint_since": c.waypoint_since, "rep": c.rep,
			"empty_since": c.empty_since, "barrel": c.barrel, "crate": c.crate, "stocked": c.stocked})
	var fs := []
	for f in camps.folk:
		fs.append({"name": f.name, "camp": _out(f.camp, cid, fid), "pos": f.pos, "home": f.home, "dead": f.dead,
			"ticked": f.ticked, "job": _out(f.job, cid, fid), "asked": f.asked, "needs": f.needs, "traits": f.traits,
			"memories": _out(f.memories, cid, fid), "think_t": f.think_t, "locked_until": f.locked_until,
			"task": _out(f.task, cid, fid), "inv": f.inv, "history": f.history, "packed": f.packed, "hp": f.hp, "dark_s": f.dark_s})
	var data := {"version": VERSION, "now": SimClock.now, "camps": cs, "folk": fs, "world_log": camps.world_log,
		"next_pull": camps._next_pull, "trees": camps.trees.harvested if camps.trees else {},
		"storm": [camps.enc._next_storm, camps.enc._storm_end, camps.enc._storming, camps.enc._cursed_until] if camps.enc else [],
		"player": _player_out()}
	var file := FileAccess.open(PATH, FileAccess.WRITE)
	if file:
		file.store_var(data)

## Camps and characters inside any value become {"_c": i} / {"_f": i}; nodes are dropped.
func _out(v, cid: Dictionary, fid: Dictionary):
	if v is Object:
		if cid.has(v):
			return {"_c": cid[v]}
		if fid.has(v):
			return {"_f": fid[v]}
		return null
	if v is Dictionary:
		var d := {}
		for k in v:
			d[k] = _out(v[k], cid, fid)
		return d
	if v is Array:
		return v.map(func(x): return _out(x, cid, fid))
	return v

func _player_out() -> Dictionary:
	var p: Node = get_tree().get_first_node_in_group("player")
	if not p:
		return {}
	var d := {"pos": p.global_position, "yaw": p.global_rotation.y, "items": []}
	var s = p.get("statComponent")
	if s:
		d["stats"] = [s.health.currentValue, s.stamina.currentValue, s.magicka.currentValue if s.get("magicka") else 0]
	var needs := p.get_node_or_null("needs")
	if needs:
		d["needs"] = [needs.hunger, needs.thirst]
	var respawn := p.find_children("*", "RespawnComponent", true, false)
	if not respawn.is_empty():
		d["respawn"] = respawn[0]._spawn_transform
	var inv: InventoryComponent = p.inventoryComponent
	var equip = p.get("equipmentComponent")
	for it: Item in inv.inventory:
		var id := _id_of(it)
		if id == "":
			continue
		var meta := {}
		for k in ["wear", "fuel", "lights"]:
			if it.has_meta(k):
				meta[k] = it.get_meta(k)
		d.items.append({"id": id, "n": inv.inventory[it], "meta": meta, "worn": equip != null and equip.get_slot_of(it) != ""})
	return d

func _id_of(it: Item) -> String:
	var db = get_node("/root/item_list")
	for key in db.item_list:
		if db.item_list[key].resource_path == it.get_template().resource_path:
			return key
	return ""

# --- loading -------------------------------------------------------------------------------------------------

## Replaces the freshly generated island with the saved one. Called by Camps before anything is built.
## False = no save (or a bad one): keep the fresh island.
func load_world() -> bool:
	if not has_save():
		return false
	var file := FileAccess.open(PATH, FileAccess.READ)
	var data = file.get_var() if file else null
	if not data is Dictionary or data.get("version", 0) != VERSION:
		return false
	var cs: Array = []
	var fs: Array = []
	for i in data.camps.size():
		cs.append(camps.new_camp())
	for i in data.folk.size():
		fs.append(camps.new_folk())
	for i in cs.size():
		var c = cs[i]
		var d: Dictionary = data.camps[i]
		for k in ["pos", "bandit", "kind", "wild", "looted", "next_move", "raid_since", "roaming", "heading",
				"waypoint_since", "rep", "empty_since", "stocked"]:
			c.set(k, d[k])
		c.job = _in(d.job, cs, fs)
		c.members = _in(d.members, cs, fs)
		c.raid = _in(d.raid, cs, fs)
		c.from = _in(d.from, cs, fs)
		c.den = _in(d.den, cs, fs)
		c.barrel = d.barrel
		c.crate = d.crate
	for i in fs.size():
		var f = fs[i]
		var d: Dictionary = data.folk[i]
		for k in ["name", "pos", "home", "dead", "ticked", "asked", "think_t", "locked_until", "packed", "hp", "dark_s"]:
			f.set(k, d[k])
		f.camp = _in(d.camp, cs, fs)
		f.job = _in(d.job, cs, fs)
		f.needs = d.needs
		f.traits = d.traits
		f.memories = _in(d.memories, cs, fs)
		f.task = _in(d.task, cs, fs)
		f.inv = d.inv
		f.history = d.history
	camps.camps.clear()
	for c in cs:
		camps.camps.append(c)
	camps.folk.clear()
	for f in fs:
		camps.folk.append(f)
	camps.world_log = data.world_log
	camps._next_pull = data.next_pull
	camps._herd_n = cs.filter(func(c): return c.wild == "herd").size()
	if camps.trees:
		camps.trees.harvested = data.trees
	if camps.enc and data.storm.size() == 4:
		camps.enc._next_storm = data.storm[0]
		camps.enc._storm_end = data.storm[1]
		camps.enc._storming = data.storm[2]
		camps.enc._cursed_until = data.storm[3]
	if camps.minds:
		for f in fs:
			if f.name != "":
				camps.minds._used_names[f.name] = true
	SimClock.now = data.now
	_player_data = data.player
	_apply_player.call_deferred()
	return true

func _in(v, cs: Array, fs: Array):
	if v is Dictionary:
		if v.size() == 1 and v.has("_c"):
			return cs[v._c]
		if v.size() == 1 and v.has("_f"):
			return fs[v._f]
		var d := {}
		for k in v:
			d[k] = _in(v[k], cs, fs)
		return d
	if v is Array:
		return v.map(func(x): return _in(x, cs, fs))
	return v

## You, as you were: where, how hurt, how hungry, what you carry and wear.
func _apply_player() -> void:
	var p: Node = get_tree().get_first_node_in_group("player")
	if not p or _player_data.is_empty():
		return
	p.global_position = _player_data.pos
	p.global_rotation.y = _player_data.yaw
	var inv: InventoryComponent = p.inventoryComponent
	var equip = p.get("equipmentComponent")
	if equip:
		for slot in equip.equipment.keys():
			if equip.equipment[slot]:
				equip.unequip_item(equip.equipment[slot])
	inv.inventory.clear()
	var db = get_node("/root/item_list")
	for e in _player_data.items:
		var it: Item = db.get_item_instance(e.id)
		if not it:
			continue
		for k in e.meta:
			it.set_meta(k, e.meta[k])
		inv.add_item(it, e.n)
		if e.worn and equip:
			for key: Item in inv.inventory: # the instance the pack actually holds
				if InventoryComponent.is_same_item(key, it):
					equip.equip_item(key)
					break
	inv.inventory_updated.emit()
	var s = p.get("statComponent")
	if s and _player_data.has("stats"):
		var vals: Array = _player_data.stats
		for i in 3:
			var st: Stat = [s.health, s.stamina, s.get("magicka")][i]
			if st:
				st.change_current(int(vals[i]) - st.currentValue)
	var needs := p.get_node_or_null("needs")
	if needs and _player_data.has("needs"):
		needs.hunger = _player_data.needs[0]
		needs.thirst = _player_data.needs[1]
	var respawn := p.find_children("*", "RespawnComponent", true, false)
	if not respawn.is_empty() and _player_data.has("respawn"):
		respawn[0]._spawn_transform = _player_data.respawn
