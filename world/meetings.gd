extends Node
## When encounters run into each other. The Camps node owns this (child "meetings", made at runtime). Every few
## seconds it buckets every camp, band and encounter on the island into a coarse grid and lets neighbours within
## meet_range react to each other. Far from you this all happens on the records; near you the fights are real.
##
##   hostile meets people   goblin packs, bandit ambushes / tolls / war bands / stalkers attack anyone not their own
##                          kind (drifters, pilgrims, the starved, mourners, other monsters' camps...): a raid
##   starved meets drifters someone shares their food: the starved one is fed (and gets back on their feet)
##   wanderer meets wanderer they walk on together (bands merge)
##   pilgrims meet wanderer a pious wanderer joins the line
##   wanderer meets cold fire they relight it and settle: it becomes a drifter camp again
##   anyone meets remains    drifters and bandits loot the sack (food, coin): it's empty when you get there
##   anyone meets a body / a dropped sack  they take what it holds
##   anyone meets a spring / ash fungus  they eat and drink there (see the Sources sliders on encounters)

## Seconds between checks (the whole island each time; cheap).
@export_range(0.5, 30.0, 0.5, "suffix:s") var meet_every := 3.0
## How close two groups must be to notice each other.
@export_range(5.0, 300.0, 5.0, "suffix:m") var meet_range := 40.0
## Chance per check that a hostile group in range goes for its neighbour.
@export_range(0.0, 1.0, 0.05) var attack_chance := 0.5
## Chance per check that friendly groups in range do their thing (share, merge, join).
@export_range(0.0, 1.0, 0.05) var friendly_chance := 0.4
## Piety a wanderer needs to join pilgrims.
@export_range(0.0, 1.0, 0.05) var join_piety := 0.5
## Food / coin a looter gets from remains (needs are 0-100).
@export_range(0.0, 100.0, 1.0) var loot_food := 40.0
@export_range(0.0, 100.0, 1.0) var loot_coin := 30.0

var camps: Node
var _t := 0.0
## What happened lately, newest last (read by the M map).
var log_lines: Array[String] = []

const PEOPLE_WILDS := ["", "wanderer", "pilgrims", "starved", "mourner", "toll", "ambush", "pack", "stalker", "homeward", "lurer"]

func _ready() -> void:
	camps = get_parent()

func _process(delta: float) -> void:
	_t += delta
	if _t < meet_every:
		return
	_t = 0.0
	var now := SimClock.now
	var grid := {}
	for c in camps.camps:
		var at := _where(c) # bucket by where the people are, not a band's next waypoint
		var key := Vector2i(floori(at.x / meet_range), floori(at.z / meet_range))
		if not grid.has(key):
			grid[key] = []
		grid[key].append(c)
	for key: Vector2i in grid:
		for c in grid[key]:
			for dz in range(-1, 2):
				for dx in range(-1, 2):
					for o in grid.get(key + Vector2i(dx, dz), []):
						if o != c and camps._dist(_where(c), _where(o)) < meet_range:
							_meet(c, o, now)

## Where a group actually is: a band's waypoint can be ahead of its people, so use its lead.
func _where(c) -> Vector3:
	if c.roaming:
		var alive: Array = camps._alive(c.members)
		if not alive.is_empty():
			return alive[0].pos
	return c.pos

func _alive(c) -> Array:
	return camps._alive(c.members)

func _hostile(c) -> bool:
	if c.wild == "falselight": # it waits for whatever comes close (encounters.gd springs it)
		return false
	return c.kind in ["goblin", "orc"] or (c.kind == "bandit" and c.wild in ["", "ambush", "toll", "pack", "stalker"] and (c.wild != "toll" or c.job.has("fight")))

func _peopled(c) -> bool:
	return c.wild in PEOPLE_WILDS and not _alive(c).is_empty()

## c acts on o (each pair is seen both ways, so only c's side of things happens here).
func _meet(c, o, now: float) -> void:
	if _alive(c).is_empty():
		return
	# Fights: a hostile group not already busy goes for anyone who isn't its own kind.
	if _hostile(c) and c.raid == null and _peopled(o) and o.kind != c.kind and o.wild != "falselight":
		if randf() < attack_chance and (c.wild != "" or c.roaming): # real camps raid on their own schedule
			c.raid = o
			c.raid_since = now
			for f in _alive(c):
				camps._send(f, _where(o))
			_log("%s attacked %s" % [_label(c), _label(o)])
			_note(c, "attacked a %s" % _label(o))
			_note(o, "was attacked by a %s" % _label(c))
		return
	if c.kind != "drifter" and c.kind != "bandit":
		return
	if c.wild != "falselight" and o.wild == "falselight" and camps.enc and not _alive(o).is_empty() and _peopled(c):
		camps.enc.spring_light(o, now, c) # they went to the light, like you might
		_log("A false light took some travellers")
		_note(c, "went to a light in the dark, and something was holding it")
		return
	if c.wild == "toll" and not c.job.has("fight") and o.kind == "drifter" and o.roaming and _peopled(o) and c.job.get("last_paid") != o: # travellers on the road, not camps
		_toll(c, o)
		return
	if o.wild == "hanged" and not o.looted and is_instance_valid(o.fire) and o.fire.get_node_or_null("sack"):
		o.fire.get_node("sack").queue_free() # near you: the sack they empty is the one you'd have found
	match o.wild:
		"hanged":
			if not o.looted and camps.enc: # they empty the dead man's pack, and something follows them
				o.looted = true
				var takers: Array = _alive(c)
				if not o.stocked: # never opened: what the dead man carried, rolled the same as you'd find it
					var rng := RandomNumberGenerator.new()
					rng.seed = hash(Vector2i(roundi(o.pos.x), roundi(o.pos.z)))
					o.stocked = true
					for n in rng.randi_range(camps.remains_items.x, maxi(camps.remains_items.x, camps.remains_items.y)):
						var id: String = camps.remains_loot[rng.randi() % camps.remains_loot.size()]
						o.crate[id] = o.crate.get(id, 0) + 1
				var k := 0
				for id in o.crate.keys():
					camps.camplife.move(o.crate, takers[k % takers.size()].inv, id, o.crate[id])
					k += 1
				var b = camps.enc._hunters(o.pos, randi_range(camps.enc.stalkers.x, maxi(camps.enc.stalkers.x, camps.enc.stalkers.y)), now) if randf() < camps.enc.hanged_hunt_chance else null
				if b:
					b.wild = "pack"
					b.job["until"] = now + camps.enc.stalk_time
					b.raid = c
					b.raid_since = now
				_note(c, "emptied a hanged man's pack")
		"sack":
			var takers: Array = _alive(c)
			var k := 0
			for id in o.crate.keys(): # they find it and take it, shared between them
				camps.camplife.move(o.crate, takers[k % takers.size()].inv, id, o.crate[id])
				k += 1
			_note(c, "picked up what someone left lying")
		"starved_dead": # a body by the road: they go through what it carried
			var from: Dictionary = o.crate if o.stocked else o.job.get("loot", {})
			if not o.looted and not from.is_empty():
				var takers: Array = _alive(c)
				var k := 0
				for id in from.keys():
					camps.camplife.move(from, takers[k % takers.size()].inv, id, from[id])
					k += 1
				o.looted = true
				_note(c, "went through a dead body's things")
		"remains":
			if not o.looted:
				camps.remains_stock(o)
				var looters: Array = _alive(c)
				var i := 0
				for id in o.crate.keys() + o.barrel.keys(): # they take what's really there, shared between them
					var from: Dictionary = o.crate if o.crate.has(id) else o.barrel
					camps.camplife.move(from, looters[i % looters.size()].inv, id, from[id])
					i += 1
				o.looted = true
				_log("%s picked over some remains" % _label(c))
				_note(c, "picked over some remains")
		"coldfire":
			if c.wild == "wanderer" and c.roaming and camps.can_light(c):
				if not camps._light(o, c, now):
					return
				if is_instance_valid(o.fire):
					o.fire.queue_free()
				o.wild = "" # lit again: a drifter camp
				o.kind = "drifter"
				o.bandit = false
				for f in _alive(c):
					f.camp = o
					camps._send(f, o.pos)
				o.members.append_array(_alive(c))
				c.members.clear()
				_log("A wanderer relit a cold fire")
				_note(o, "relit a cold fire and settled there")
		"spring", "fungus":
			for f in _alive(c):
				var life = camps.camplife
				if life and o.wild == "spring": # fill their skins, if it has water
					life.fill_skins(f, o)
				elif life and f.inv.get("ash_cap", 0) < 2: # pick a few caps, if there are any
					life.pick_caps(f, o, 1)
	if randf() > friendly_chance or c.kind != "drifter" or o.kind != "drifter" or not _peopled(o):
		return
	if o.wild == "starved" and c.wild != "starved":
		for s in _alive(o):
			var giver = _alive(c).filter(func(g): return camps.camplife and camps.camplife.count_food(g.inv) > 0 and randf() < camps.minds._t(g, "kindness")) # the kind share
			if not s.job.has("fed") and not giver.is_empty(): # someone with food to spare hands it over
				var life = camps.camplife
				var id: String = life._best(giver[0].inv, false)
				life.move(giver[0].inv, s.inv, id, 1)
				life.self_care(s)
				s.job["fed"] = true
				s.needs.water = maxf(s.needs.water, 60.0)
				s.needs.light = maxf(s.needs.light, 60.0) # walked to their fire with them
				_log("Someone shared food with a starving stranger")
				camps.note(giver[0], "gave food to a starving stranger")
				camps.note(s, "was given food by a passing stranger")
	elif c.wild == "wanderer" and o.wild == "wanderer" and c.roaming and o.roaming and camps.camps.find(c) < camps.camps.find(o):
		for f in _alive(o): # o's people walk on with c
			f.camp = c
		c.members.append_array(_alive(o))
		o.members.clear()
		_log("Two wanderers walked on together")
	elif c.wild == "wanderer" and o.wild == "pilgrims":
		for f in _alive(c):
			if not f.traits.is_empty() and f.traits.piety >= join_piety:
				c.members.erase(f)
				o.members.append(f)
				f.camp = o
				_log("A wanderer joined the pilgrims")

## A toll-taker stops travellers on the road: they pay if they can (the coin goes to the toll-taker), else it's a fight.
func _toll(c, o) -> void:
	var cost: int = camps.enc.toll_cost if camps.enc else 20
	for f in _alive(o):
		if f.inv.get("coin", 0) >= cost:
			camps.camplife.move(f.inv, _alive(c)[0].inv, "coin", cost)
			c.job["last_paid"] = o
			_log("Travellers paid a toll")
			_note(o, "paid %d coin to a toll-taker" % cost)
			return
	c.job["fight"] = true # nobody can pay: they don't walk on
	_log("Travellers couldn't pay the toll")
	_note(o, "couldn't pay the toll")

## A looter takes a bit of food and coin from the remains into their pack.
func _loot(f) -> void:
	var life = camps.camplife
	if not life:
		return
	life.add(f.inv, ["bread", "ash_cap", "dried_meat"].pick_random(), randi_range(1, 2))
	life.add(f.inv, "coin", randi_range(3, 15))

func _label(c) -> String:
	if c.wild == "":
		return camps.camplife.fire_name(c) if camps.camplife else "%s camp" % c.kind
	return "%s %s" % [c.kind, c.wild] if c.wild in ["pack", "ambush", "toll", "stalker"] else c.wild

## Puts a line in the log of everyone in group c (for the watch camera).
func _note(c, text: String) -> void:
	for f in _alive(c):
		camps.note(f, text)

func _log(line: String) -> void:
	log_lines.append(line)
	if log_lines.size() > 8:
		log_lines.pop_front()
