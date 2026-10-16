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

const PEOPLE_WILDS := ["", "wanderer", "pilgrims", "starved", "mourner", "toll", "ambush", "pack", "stalker", "falselight_sprung"]

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
		return
	if c.kind != "drifter" and c.kind != "bandit":
		return
	match o.wild:
		"remains":
			if not o.looted:
				o.looted = true
				for f in _alive(c):
					_feed(f, loot_food, loot_coin)
				_log("%s picked over some remains" % _label(c))
		"coldfire":
			if c.wild == "wanderer" and c.roaming:
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
		"spring", "fungus":
			for f in _alive(c):
				_feed(f, 30.0 if o.wild == "fungus" else 10.0, 0.0)
	if randf() > friendly_chance or c.kind != "drifter" or o.kind != "drifter" or not _peopled(o):
		return
	if o.wild == "starved" and c.wild != "starved":
		for s in _alive(o):
			if not s.job.has("fed"):
				s.job["fed"] = true
				_feed(s, 60.0, 0.0)
				_log("Someone shared food with a starving stranger")
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

func _feed(f, food: float, coin: float) -> void:
	if f.needs.is_empty():
		return
	f.needs.food = minf(100.0, f.needs.food + food)
	f.needs.coin = minf(100.0, f.needs.coin + coin)

func _label(c) -> String:
	if c.wild == "":
		return "%s camp" % c.kind
	return "%s %s" % [c.kind, c.wild] if c.wild in ["pack", "ambush", "toll", "stalker"] else c.wild

func _log(line: String) -> void:
	log_lines.append(line)
	if log_lines.size() > 8:
		log_lines.pop_front()
