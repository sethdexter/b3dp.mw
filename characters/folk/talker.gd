class_name Talker
extends InteractableComponent
## Lets the player talk to a person: look at them and press E. The first press greets, each press after
## tells another rumour. Lines show in a box at the bottom of the screen and fade on their own.
## Also gives the person a random name from `names` on spawn.
## Traders: if there's a ContainerComponent under this node (marked `shop`), it opens as their wares while you talk.
## Jobs: people who `gives_jobs` may offer a favour (bring them items, or clear a bandit camp) on the second talk;
## talk to them again once it's done to get paid. The job is kept on their Camps record, so it survives them
## going out of range.

@export var names: PackedStringArray = ["Ulvo the Unburnt", "Sister Mott", "Grey Aldric", "Pell Ninefingers",
	"Old Wick", "Hask of No Hearth", "Brother Ember", "Ysolt the Pale", "Morrow-Jan", "the Salt Widow"]
@export var greetings: PackedStringArray = [
	"Sit, if you like. The fire doesn't ask who you are.",
	"Another walker. The ash brings us all the same way.",
	"Don't step on my shadow. It's the only one I have left.",
	"You smell of the road. Good. The road is honest.",
	"Ah. You're real. I wasn't sure, from a distance."]
@export var rumours: PackedStringArray = [
	"The goblins aren't hunting you. They're hungry. There's a difference, but not much of one.",
	"Something under the dunes hums at night. Put your ear to the sand if you don't believe me.",
	"The trees here didn't die. They're waiting.",
	"There was a town where the marsh is now. Some nights you can still hear the bell.",
	"Never follow a light in the fog. The fog has its own fires.",
	"Bandits camp out past the rocks. They'd skin you for the boots.",
	"I traded my name to a man in a red hood. Got a good knife for it, too.",
	"The snow on the mountains never melts. Nothing up there is warm enough.",
	"Eat the shoots in the desert and you'll dream of the sea. Eat too many and you won't wake."]

@export_group("Jobs")
@export var gives_jobs := false
## Chance, when you talk again, that they have a job for you (rolled once per person).
@export_range(0.0, 1.0, 0.05) var job_chance := 0.6
## Chance a job is a bandit bounty (if there's a bandit camp in range) rather than a fetch.
@export_range(0.0, 1.0, 0.05) var bounty_chance := 0.5
## Fetch jobs ask for one of these item ids, this many of them (random in range).
@export var fetch_items: PackedStringArray = ["bread", "water_skin", "dried_meat", "torch", "health_potion"]
@export_range(1, 10) var fetch_min := 1
@export_range(1, 10) var fetch_max := 3
## Pay in coins: fetch = per item asked, bounty = flat.
@export_range(0, 200) var fetch_pay_each := 8
@export_range(0, 500) var bounty_pay := 60
## Bounties only target bandit camps within this.
@export_range(100.0, 5000.0, 50.0, "suffix:m") var bounty_range := 1500.0
## Lines (the %d / %s get filled in: count, item name, direction, pay).
@export var fetch_offer := "I need %d %s. Bring them and there's %d coin in it."
@export var bounty_offer := "Bandits keep a fire to the %s. Put them in the ground and I'll pay %d coin."
@export var job_reminder := "Still waiting on what we agreed."
@export var job_thanks := "That's done, then. Here. %d coin, as promised."
@export_group("")

## Set by world/encounters.gd for special people (mourner, starved, pilgrim, toll): they talk their own way.
var role := ""
var _talks := 0
static var _box: Label
static var _fade: Tween

func _ready() -> void:
	super()
	var person := get_parent() as BaseCharacter
	if person and not names.is_empty():
		person.Name = names[randi() % names.size()]

func interact(player: Node) -> void:
	var person := get_parent() as BaseCharacter
	if not player or not person or person.is_dead:
		return
	interacted.emit(player)
	if container and not container.is_open:
		container.open(player) # a trader's wares, next to your pack
	var line := ""
	var camps = get_tree().get_first_node_in_group("camps")
	if role != "" and camps and camps.enc:
		line = camps.enc.talk(role, person, player)
	var folk = person.get_meta("folk") if person.has_meta("folk") else null
	if line.is_empty() and camps and camps.minds and folk and camps.minds.hates(folk.camp):
		line = camps.minds.hated_line
	if line.is_empty() and _talks > 0 and gives_jobs:
		line = _job_talk(person, player)
	if line.is_empty() and _talks > 0 and camps and camps.minds:
		line = camps.minds.mood_line(folk)
	if line.is_empty():
		var pool := greetings if _talks == 0 or rumours.is_empty() else rumours
		line = pool[randi() % pool.size()]
	_say(person.Name, line)
	_talks += 1

## Offers, checks or pays out this person's job. Returns what they say ("" = nothing job-related to say).
func _job_talk(person: BaseCharacter, player: Node) -> String:
	var folk = person.get_meta("folk") if person.has_meta("folk") else null # their Camps record
	var camps = get_tree().get_first_node_in_group("camps")
	if folk == null or camps == null:
		return ""
	if folk.job.has("type"): # an older save kept the favour loose in job: gather it up
		folk.job["favour"] = {}
		for k in ["type", "camp", "item", "count", "pay"]:
			if folk.job.has(k):
				folk.job.favour[k] = folk.job[k]
				folk.job.erase(k)
	var job: Dictionary = folk.job.get("favour", {}) # (folk.job also holds the sim's own state: the favour is one key)
	var db = get_node("/root/item_list")
	if job.is_empty():
		if folk.asked:
			return ""
		folk.asked = true # one roll per person
		if randf() > job_chance:
			return ""
		var target = camps.bandit_camp_near(person.global_position, bounty_range)
		if target and randf() < bounty_chance:
			folk.job["favour"] = {"type": "bounty", "camp": target, "pay": bounty_pay}
			return bounty_offer % [_compass(target.pos - person.global_position), bounty_pay]
		var id: String = fetch_items[randi() % fetch_items.size()]
		var item: Item = db.get_item_instance(id)
		var n := randi_range(fetch_min, maxi(fetch_min, fetch_max))
		folk.job["favour"] = {"type": "fetch", "item": id, "count": n, "pay": n * fetch_pay_each}
		return fetch_offer % [n, item.Name, n * fetch_pay_each]
	var inv: InventoryComponent = player.inventoryComponent
	var done := false
	if job.type == "bounty":
		done = job.camp == null or job.camp.members.all(func(f): return f.dead) # (a camp gone since: it's done)
	elif inv:
		var want: Item = db.get_item_instance(job.item)
		if inv.count_item(want) >= job.count:
			var left: int = job.count
			for key: Item in inv.inventory.keys():
				if left > 0 and InventoryComponent.is_same_item(key, want):
					left -= inv.remove_item(key, left)
			done = true
	if not done:
		return job_reminder
	var paid := 0
	for stash in [folk.inv, folk.camp.crate]: # out of their pack, then their camp's crate
		var n: int = mini(job.pay - paid, stash.get("coin", 0))
		stash["coin"] = stash.get("coin", 0) - n
		if stash["coin"] <= 0:
			stash.erase("coin")
		paid += n
	if inv and paid > 0:
		inv.add_item(db.get_item_instance("coin"), paid)
	folk.job.erase("favour")
	if paid < job.pay:
		return "It's done. Here's %d coin. It's all we have." % paid
	if camps.minds:
		camps.minds.rep(folk.camp, camps.minds.rep_job)
	return job_thanks % job.pay

static func _compass(d: Vector3) -> String:
	var names := ["north", "north-east", "east", "south-east", "south", "south-west", "west", "north-west"]
	return names[posmod(roundi(atan2(d.x, -d.z) / (TAU / 8.0)), 8)]

func _say(who: String, line: String) -> void:
	notify("%s:\n\"%s\"" % [who, line], 3.0 + line.length() * 0.05)

## Shows a line of text at the bottom of the screen that fades on its own (talk, hunger messages...).
static func notify(text: String, seconds := 4.0) -> void:
	if not is_instance_valid(_box):
		var layer := CanvasLayer.new()
		_box = Label.new()
		_box.set_anchors_and_offsets_preset(Control.PRESET_CENTER_BOTTOM)
		_box.offset_top = -150; _box.offset_bottom = -70; _box.offset_left = -360; _box.offset_right = 360
		_box.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		_box.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		_box.add_theme_font_override("font", load("res://assets/fonts/MononokiNerdFont-Regular.ttf"))
		_box.add_theme_color_override("font_color", Color(0.85, 0.78, 0.62))
		_box.add_theme_color_override("font_outline_color", Color.BLACK)
		_box.add_theme_constant_override("outline_size", 6)
		layer.add_child(_box)
		(Engine.get_main_loop() as SceneTree).root.add_child(layer)
	_box.text = text
	_box.modulate.a = 1.0
	if _fade:
		_fade.kill() # a new line restarts the fade
	_fade = _box.create_tween()
	_fade.tween_interval(seconds)
	_fade.tween_property(_box, "modulate:a", 0.0, 1.0)
