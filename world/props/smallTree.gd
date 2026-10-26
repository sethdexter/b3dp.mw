extends StaticBody3D
## One of a copse's small dead trees (world/camps.gd builds them near you; far off a copse is just a count).
## Look at it and press E to cut it down for ash wood: slow by hand, quicker with a hatchet ("axe", which wears).
## It's loud: hostiles nearby come to see. Felled, it's gone from the copse (copses grow back slowly).
## The big dead trees are another matter: their wood has turned hard as iron (world/props/treeHarvest.gd).

var record = null # the copse (a Camps record, job.count = trees standing)

func show_prompt() -> void:
	Talker.notify("Small dead tree  [E] cut it down", 1.5)

func hide_prompt() -> void:
	pass

func interact(player: Node) -> void:
	var camps = get_tree().get_first_node_in_group("camps")
	if not record or not camps or record.job.get("count", 0) <= 0 or has_meta("busy"):
		return
	var life = camps.camplife
	var inv: InventoryComponent = player.inventoryComponent
	var axe := Tools.find(inv, "axe") != null
	var secs: float = life.chop_axe_time if axe else life.chop_hand_time
	set_meta("busy", true)
	var from: Vector3 = player.global_position
	Talker.notify("You hack at the trunk%s..." % (" with the hatchet" if axe else " with your bare hands"), secs)
	for f in camps.folk: # the noise carries: hostiles near enough come to see
		if not f.dead and is_instance_valid(f.node) and f.camp.kind in ["goblin", "orc", "bandit"] and f.node.global_position.distance_to(from) < life.chop_noise:
			var ai: MobAIComponent = f.node.get_node_or_null("mobAI")
			if ai and ai.aggressive:
				ai._enter(MobAIComponent.State.CHASE)
	await get_tree().create_timer(secs, false).timeout
	remove_meta("busy")
	if not is_instance_valid(player) or player.global_position.distance_to(from) > 3.0 or player.is_dead or record.job.get("count", 0) <= 0:
		Talker.notify("You leave it.")
		return
	if axe:
		Tools.use(inv, "axe")
	var wood: int = life.gather(life.wood_per_tree + (life.axe_bonus if axe else 0), life.player_skill(player, "woodcraft"))
	var db: Node = get_node("/root/item_list")
	inv.add_item(db.get_item_instance("ash_wood"), wood)
	inv.add_item(db.get_item_instance("kindling"), life.kindling_per_tree)
	inv.add_item(db.get_item_instance("tinder"), life.tinder_per_tree)
	record.job.count -= 1
	Talker.notify("It comes down. You get %d ash wood, %d kindling and %d tinder." % [wood, life.kindling_per_tree, life.tinder_per_tree])
	queue_free()
