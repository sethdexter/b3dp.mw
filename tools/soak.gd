extends SceneTree
## Soak test: fast-forwards the island with you far away and prints the state every 20 sim minutes. Run headless:
##   godot --headless --path . -s res://tools/soak.gd
func _initialize():
	var save := ProjectSettings.globalize_path("user://island.save")
	if FileAccess.file_exists(save): # always a fresh island; your own save is put back at the end
		DirAccess.rename_absolute(save, save + ".soak_backup")
	var lvl = load("res://levels/test_level.tscn").instantiate()
	root.add_child(lvl); current_scene = lvl
	for i in 30: await process_frame
	var camps = lvl.get_node("Camps"); var life = camps.camplife
	var player = get_first_node_in_group("player")
	player.global_position = Vector3(4800, 80, 4800) # out of the way: pure sim
	var clock = camps.get_node("clock")
	var ev := InputEventKey.new(); ev.keycode = KEY_BRACKETRIGHT; ev.pressed = true
	clock.max_speed = 32
	for i in 5: clock._unhandled_input(ev)
	var chores_seen := {}
	var goals_seen := {}
	print("START camps ", camps.camps.filter(func(c): return c.wild == "").size(), " encounters ", camps.camps.filter(func(c): return c.wild != "").size(), " people ", camps.folk.size())
	for step in 18:
		var became := {}
		var t0 := Time.get_ticks_msec()
		var frames := 0
		while clock.get_script().now < (step + 1) * 1200.0:
			await process_frame
			frames += 1
			if frames % 120 == 0:
				for f in camps.folk:
					if not f.dead and not f.task.is_empty():
						chores_seen[f.task.type] = chores_seen.get(f.task.type, 0) + 1
				for b in camps.camps:
					if b.roaming and b.job.get("goal"):
						var g = b.job.goal.wild if b.job.goal.wild != "" else b.job.goal.kind + " camp"
						goals_seen[g] = goals_seen.get(g, 0) + 1
		var real_ms := Time.get_ticks_msec() - t0
		var alive = camps.folk.filter(func(f): return not f.dead)
		var by = {}
		for f in alive:
			var k = f.camp.kind + ("" if f.camp.wild == "" else "/" + f.camp.wild)
			by[k] = by.get(k, 0) + 1
		var stores = camps.camps.filter(func(c): return c.wild == "" and not c.roaming and c.kind in ["drifter", "bandit"] and c.stocked)
		var water := 0; var food := 0; var empty := 0
		for c in stores:
			water += c.barrel.get("water_skin", 0); food += life.count_food(c.crate)
			if camps._alive(c.members).is_empty(): empty += 1
		var collapsed = alive.filter(func(f): return f.camp.wild == "starved").size()
		print("T+%dmin alive %d (drifters %d bandits %d monsters %d) collapsed %d | camp stores water %d food %d, empty camps %d/%d | cold fires %d | raids now %d | %.0f fps" % [
			(step + 1) * 20, alive.size(), alive.filter(func(f): return f.camp.kind == "drifter").size(), alive.filter(func(f): return f.camp.kind == "bandit").size(),
			alive.filter(func(f): return f.camp.kind in ["goblin", "orc"]).size(), collapsed, water, food, empty, stores.size(),
			camps.camps.filter(func(c): return c.wild == "coldfire").size(), camps.camps.filter(func(c): return c.raid != null).size(), frames * 1000.0 / maxf(1.0, real_ms)])
		var deadby = {}
		for f in camps.folk:
			if f.dead and not f.has_meta("counted"):
				f.set_meta("counted", true)
				var k = f.camp.kind + "/" + (f.camp.wild if f.camp.wild != "" else ("band" if f.camp.roaming else "camp")) + ("/raid" if f.camp.raid else "") + ("/PULLED" if not f.history.is_empty() and f.history[0].text.begins_with("was pulled") else "") + ("/" + (f.history[-2].text.left(28) if f.history.size() > 1 else ""))
				deadby[k] = deadby.get(k, 0) + 1
		print("  died this window: ", deadby)
		var trades := 0
		for f in camps.folk:
			for e in f.history:
				if e.text.begins_with("bought") and e.t > step * 1200.0:
					trades += 1
		var coin := 0
		for c in camps.camps:
			coin += c.crate.get("coin", 0)
		print("  trades this window %d | coin in camp crates %d" % [trades, coin])
		var lit_n := 0
		var wood := 0
		var trees := 0
		var outs := 0
		for c in camps.camps:
			if c.wild == "" and not c.roaming and c.kind in ["drifter", "bandit"]:
				lit_n += 1
				wood += c.crate.get("ash_wood", 0)
			if c.wild == "copse":
				trees += c.job.get("count", 0)
			if c.job.get("went_out", false):
				outs += 1
		print("  fires lit %d (wood in crates %d) | fires gone out %d | small trees standing %d" % [lit_n, wood, outs, trees])
		print("  NPC spells cast so far: ", camps.camplife.casts)
		print("  sap nodes %d | resin in crates %d | tiers %s" % [camps.camps.filter(func(c): return c.wild == "sap").size(), camps.camps.reduce(func(t, c): return t + c.crate.get("resin", 0), 0), str(camps.camps.filter(func(c): return c.wild == "" and not c.roaming and c.kind in ["drifter", "bandit"]).map(func(c): return camps.camplife.fire_tier(c)))])
		var hs = camps.camps.filter(func(c): return c.wild == "herd")
		var head := 0
		for h in hs: head += h.job.count
		var springs = camps.camps.filter(func(c): return c.wild == "spring" and c.job.has("stock"))
		var dry = springs.filter(func(c): return c.job.stock <= 0).size()
		var larder := 0
		for c in camps.camps:
			if c.kind in ["goblin", "orc"] and c.wild == "" : larder += c.crate.get("raw_meat", 0)
		print("  herds %d (%d head) | springs used %d, dry %d | den larders %d meat" % [hs.size(), head, springs.size(), dry, larder])
		print("  groups: ", by, "  | characters ever: ", camps.folk.size(), "  dens/camps: ", camps.camps.filter(func(c): return c.wild == "" and not c.roaming).size())
		var lit = camps.camps.filter(func(c): return c.wild == "" and not c.roaming and c.kind == "drifter")
		print("  drifter fires %d (peopled %d) cold %d" % [lit.size(), lit.filter(func(c): return not camps._alive(c.members).is_empty()).size(), camps.camps.filter(func(c): return c.wild == "coldfire").size()])
	print("CHORES seen ", chores_seen)
	print("TRAVELLER GOALS seen ", goals_seen)
	var lines = {}
	for e in camps.world_log: lines[e.text.left(30)] = lines.get(e.text.left(30), 0) + 1
	print("WORLD LOG mix (last 40) ", lines)
	print("MEETINGS log ", camps.get_node("meetings").log_lines)
	print("CAMPLIFE log ", life.log_lines)
	var dead = camps.folk.filter(func(f): return f.dead)
	print("DEAD ", dead.size(), " (", dead.filter(func(f): return f.camp.kind in ["goblin", "orc"]).size(), " monsters)")
	var names = {}
	for f in camps.folk: if f.name != "" and not f.camp.kind in ["goblin", "orc"]: names[f.name] = names.get(f.name, 0) + 1
	print("NAMES unique ", names.values().all(func(v): return v == 1), " (", names.size(), ")")
	# sweep cost
	var t := Time.get_ticks_usec()
	for i in 50: camps._process(0.016)
	print("SWEEP %.2f ms/frame" % ((Time.get_ticks_usec() - t) / 50.0 / 1000.0))
	lvl.queue_free() # the test island: don't let it autosave over yours
	await process_frame
	DirAccess.remove_absolute(save)
	if FileAccess.file_exists(save + ".soak_backup"):
		DirAccess.rename_absolute(save + ".soak_backup", save)
	quit()
