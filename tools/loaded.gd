extends SceneTree
## Loaded test: puts you at the start camp and lets the island run near you at normal speed, so characters have
## bodies. Reports script errors (in the log), how far bodies drift from their records, and who's stuck.
##   godot --headless --path . -s res://tools/loaded.gd
func _initialize():
	var save := ProjectSettings.globalize_path("user://island.save")
	if FileAccess.file_exists(save): DirAccess.rename_absolute(save, save + ".soak_backup")
	var lvl = load("res://levels/test_level.tscn").instantiate()
	root.add_child(lvl); current_scene = lvl
	for i in 30: await process_frame
	var camps = lvl.get_node("Camps")
	var start = camps.camps.filter(func(c): return c.wild == "" and c.next_move == INF)
	var player = get_first_node_in_group("player")
	player.global_position = (start[0].pos if not start.is_empty() else Vector3.ZERO) + Vector3(6, 2, 0)
	var worst := 0.0
	var moved := {}
	var stuck := 0
	for step in 6: # 6 x 10 s
		var before := {}
		for f in camps.folk:
			if is_instance_valid(f.node): before[f] = f.node.global_position
		for i in 600: await process_frame
		var bodies := 0
		for f in camps.folk:
			if f.dead or not is_instance_valid(f.node): continue
			bodies += 1
			var d: float = camps._dist(f.node.global_position, f.pos)
			worst = maxf(worst, d)
			if before.has(f):
				var m: float = camps._dist(f.node.global_position, before[f])
				var ai = f.node.get_node_or_null("mobAI")
				if ai and ai.state == ai.State.RETURN and m < 0.5 and Time.get_ticks_msec() > ai.hold_until_ms:
					stuck += 1 # walking somewhere, but not getting anywhere
					print("  stuck: %s (%s) %.0f m from where it is going, task %s" % [f.name, f.camp.wild, camps._dist(f.pos, f.home), f.task.get("type", "-")])
				moved[f] = moved.get(f, 0.0) + m
		print("t=%ds bodies %d  worst body/record gap %.1f m  stuck so far %d" % [(step + 1) * 10, bodies, worst, stuck])
	var tasks := {}
	for f in camps.folk:
		if is_instance_valid(f.node) and not f.task.is_empty(): tasks[f.task.type] = tasks.get(f.task.type, 0) + 1
	print("loaded chores: ", tasks)
	lvl.queue_free(); await process_frame
	DirAccess.remove_absolute(save)
	if FileAccess.file_exists(save + ".soak_backup"): DirAccess.rename_absolute(save + ".soak_backup", save)
	quit()
