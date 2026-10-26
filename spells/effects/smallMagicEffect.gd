class_name SmallMagicEffect
extends SpellEffect

## The small magics (reagents are paid by SpellCasterComponent from the Spell's `reagents`):
##   kindle  a cold fire within reach takes (with kindling and logs; no spark, no tinder, no failed strike);
##           else your held torch takes a flame
##   mend    health comes back a little at a time
##   dew     a water skin fills from the air
##   ward    a small glow goes with you: the dark holds off (a carried smoulder: no healing) for a while
##   sense   you feel where the nearest spring, fungus, sap, copse and herd lie

@export_enum("kindle", "mend", "dew", "ward", "sense", "shroud", "drain") var kind := "kindle"
## mend: health per tick, ticks, seconds between. ward: seconds, reach. sense: how far.
@export var mend_amount := 2
@export var mend_ticks := 10
@export var mend_every := 1.0
@export var ward_time := 120.0
@export var ward_radius := 6.0
@export var sense_range := 300.0

## Seconds of dread a Nox spell puts on you (DarknessComponent dark_time), as if you'd stood that long in the dark.
@export var nox_dread := 15.0

func apply(target: BaseCharacter, _source: Node, spell: Spell) -> void:
	if not target:
		return
	if spell and spell.skill == "nox": # the dark's power: it takes some of your light
		var dk = target.get_node_or_null("darkness")
		if dk:
			dk.dark_time += nox_dread
	call("_" + kind, target)

func _camps(t: Node):
	return t.get_tree().get_first_node_in_group("camps")

func _kindle(t: BaseCharacter) -> void:
	var camps = _camps(t)
	var inv: InventoryComponent = t.get("inventoryComponent")
	if camps and camps.enc and inv:
		for c in camps.camps:
			if c.wild == "coldfire" and camps._dist(c.pos, t.global_position) < camps.enc.relight_distance:
				var missing: Array[String] = camps.enc._makings(inv, true, true) # (as if embers: only kindling and logs)
				if not missing.is_empty():
					Talker.notify("The flame wants something to eat: " + ", ".join(missing) + ".")
					return
				var life = camps.camplife
				camps.enc._spend(inv, "kindling", 1)
				camps.enc._spend(inv, "ash_wood", life.light_logs)
				c.job["fire_fuel"] = life.light_logs * life.wood_burn
				c.job["fire_at"] = SimClock.now
				c.job["lit_at"] = SimClock.now
				c.job.erase("out_at")
				c.job.erase("went_out")
				camps.enc._relight(c)
				return
	for torch: Node3D in t.get_tree().get_nodes_in_group("light_source"): # your torch, in hand
		if torch.has_meta("item") and t.is_ancestor_of(torch):
			var it: Item = torch.get_meta("item")
			it.set_meta("fuel", torch.get("burn_time"))
			Talker.notify("The torch takes the flame.")
			return
	Talker.notify("Nothing here to kindle.")

func _mend(t: BaseCharacter) -> void:
	Talker.notify("Warmth gathers in the wound.")
	for i in mend_ticks:
		await t.get_tree().create_timer(mend_every, false).timeout
		if not is_instance_valid(t) or t.is_dead:
			return
		t.statComponent.health.change_current(mend_amount)

func _dew(t: BaseCharacter) -> void:
	var inv: InventoryComponent = t.get("inventoryComponent")
	if inv:
		inv.add_item(t.get_node("/root/item_list").get_item_instance("water_skin"), 1)
		Talker.notify("Cold beads gather out of the ash-air and fill a skin.")

func _ward(t: BaseCharacter) -> void:
	var n := Node3D.new()
	n.add_to_group("reprieve") # DarknessComponent: the dark holds off, nothing heals
	n.set_meta("light_radius", ward_radius)
	var glow := OmniLight3D.new()
	glow.light_color = Color(0.85, 0.6, 0.3)
	glow.light_energy = 0.8
	glow.omni_range = ward_radius
	glow.shadow_enabled = false
	glow.position.y = 2.0
	n.add_child(glow)
	t.add_child(n)
	Talker.notify("A faint glow settles round you.")
	await t.get_tree().create_timer(ward_time, false).timeout
	if is_instance_valid(n):
		n.queue_free()
		Talker.notify("The glow round you fades.")

func _sense(t: BaseCharacter) -> void:
	var camps = _camps(t)
	if not camps:
		return
	var lines := []
	for wild in ["spring", "fungus", "sap", "copse", "herd"]:
		var best = null
		for c in camps.camps:
			if c.wild == wild and camps._dist(c.pos, t.global_position) < sense_range and (best == null or camps._dist(c.pos, t.global_position) < camps._dist(best.pos, t.global_position)):
				best = c
		if best:
			lines.append("%s %s, %d m" % [{"spring": "Water", "fungus": "Ash caps", "sap": "Sap", "copse": "Small trees", "herd": "Greyhorns"}[wild],
				Talker._compass(best.pos - t.global_position), roundi(camps._dist(best.pos, t.global_position))])
			camps.world_log.append({"t": SimClock.now, "who": "You", "text": "sensed %s" % wild, "pos": best.pos, "ms": Time.get_ticks_msec()}) # a pulse on the map
	Talker.notify("You feel the land around you:\n" + ("\n".join(lines) if not lines.is_empty() else "Nothing near."), 8.0)

## shroud: the dark hides you; things that hunt you notice you only this close (a share of their usual reach).
@export var shroud_time := 60.0
@export var shroud_reach := 0.25
## drain: health taken from whoever's in front of you within reach, and given to you.
@export var drain_amount := 12
@export var drain_range := 4.0

func _shroud(t: BaseCharacter) -> void:
	t.set_meta("shrouded_until", Time.get_ticks_msec() + int(shroud_time * 1000.0))
	t.set_meta("shroud_reach", shroud_reach)
	Talker.notify("The dark folds over you.")

func _drain(t: BaseCharacter) -> void:
	var fwd: Vector3 = -t.global_basis.z
	var cam := t.get_viewport().get_camera_3d()
	if cam:
		fwd = -cam.global_basis.z
	var best: BaseCharacter = null
	for n in t.get_tree().current_scene.find_children("*", "CharacterBody3D", true, false): # (only on a cast)
		var o := n as BaseCharacter
		if o == null or o == t or o.is_dead or not o.statComponent:
			continue
		var to := o.global_position - t.global_position
		if to.length() < drain_range and to.normalized().dot(fwd) > 0.5 and (best == null or to.length() < (best.global_position - t.global_position).length()):
			best = o
	if best == null:
		Talker.notify("There's nothing within reach to drain.")
		return
	best.statComponent.health.change_current(-drain_amount)
	t.statComponent.health.change_current(drain_amount)
	Talker.notify("You pull the warmth out of %s." % best.Name)

func describe() -> String:
	return {"kindle": "Lights a cold fire or your torch", "mend": "Restores %d Health over %d s" % [mend_amount * mend_ticks, int(mend_ticks * mend_every)],
		"dew": "Fills a water skin", "ward": "Holds off the dark for %d s" % int(ward_time), "sense": "Senses springs, fungus, sap, trees and herds",
		"shroud": "Hunters barely notice you for %d s" % int(shroud_time), "drain": "Takes %d Health from a foe, gives it to you" % drain_amount}[kind]
