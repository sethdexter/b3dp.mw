extends StaticBody3D
## The old world's ruins (world/encounters.gd builds them; their state is on the record's job):
##   lamptower  a dead lamp-tower. Pour in old_oil (two jars) with a flame at hand and it burns again: a great light
##              for you and everyone (the island's people count it as a fire's light), for good.
##   hall       a sealed hall, its door sunk in the earth. The Sunken Key from a bell shrine opens it: inside, what
##              the old world left (old oil, scrap, script fragments).

var record = null # the place's Camps record

const TOWER_LINES := ["The old oil catches. Far above, the lamp wakes, and the dark draws back further than you have ever seen.",
	"Light pours down the tower's sides. Somewhere, someone will see it and walk toward it."]

func _encounters():
	var camps = get_tree().get_first_node_in_group("camps")
	return camps.enc if camps else null

func show_prompt() -> void:
	if not record:
		return
	if record.wild == "lamptower":
		Talker.notify("A lamp-tower of the old world, burning again" if record.job.get("lit", false) else "A dead lamp-tower  [E] pour in old oil and light it (2 old oil, a flame)", 1.5)
	else:
		Talker.notify("A sealed hall of the old world, opened" if record.job.get("open", false) else "A sealed hall, its door sunk in the earth  [E] the Sunken Key", 1.5)

func hide_prompt() -> void:
	pass

func interact(player: Node) -> void:
	var enc = _encounters()
	var inv: InventoryComponent = player.get("inventoryComponent")
	if not record or not enc or not inv:
		return
	if record.wild == "lamptower" and not record.job.get("lit", false):
		var flame: bool = enc._lit_torch_near(global_position, 8.0) or Tools.find(inv, "spark") != null
		if enc._count(inv, "old_oil") < 2 or not flame:
			Talker.notify("It wants two jars of old oil, and a flame to light it.")
			return
		enc._spend(inv, "old_oil", 2)
		if not enc._lit_torch_near(global_position, 8.0):
			Tools.use(inv, "spark")
		record.job["lit"] = true
		Talker.notify(TOWER_LINES.pick_random(), 8.0)
		enc.camps.world_log.append({"t": SimClock.now, "who": "You", "text": "relit a lamp-tower of the old world", "pos": record.pos, "ms": Time.get_ticks_msec()})
		enc.rebuild(record)
	elif record.wild == "hall" and not record.job.get("open", false):
		if enc._count(inv, "sunken_key") < 1:
			Talker.notify("The door is sealed. There's a keyhole, green with age.")
			return
		enc._spend(inv, "sunken_key", 1)
		record.job["open"] = true
		Talker.notify("The key turns. The door grinds inward, and the hall breathes out air older than the dark.", 8.0)
		enc.rebuild(record)
