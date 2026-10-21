extends Node
## Fate: rare things that happen to any group on the island (a camp, a band on the road, a den), loaded or not.
## The Camps node owns this (child "fate", made at runtime). Every fate_every seconds one group is picked at random
## and, at fate_chance, something befalls it, by weight from what fits it. Nothing comes from nothing: a cache found
## is the old world's, a sickness takes health, a snuffed fire loses its own wood.
##   grey cough  one of them sickens; it spreads in the group, wears health; an ashwife shortens it
##   lightless   the Lightless pass in the dark: a camp's fire is half snuffed, its people shaken
##   foul water  the spring nearest them goes foul: empty, and slow to come back
##   old cache   travellers turn up a sealed stash of the old world: scrap, coin, cloth, resin
##   ill omen    a statue facing away from the light, a bird that won't fly: faith drains, despair deepens
##   scattered   a herd near them bolts far off into the dark

var camps: Node # the Camps node

## Seconds between rolls, and the chance a roll finds anything (one group per roll: on any one group, very rare).
@export_range(10.0, 3600.0, 10.0, "suffix:s") var fate_every := 120.0
@export_range(0.0, 1.0, 0.01) var fate_chance := 0.25
## Weights of each kind of fate (0 = never).
@export var weights := {"grey_cough": 3.0, "lightless": 2.0, "foul_water": 2.0, "old_cache": 2.0, "ill_omen": 3.0, "scattered": 2.0}
## The grey cough: how long it lasts (s), health lost per minute while it does, chance per check it spreads to
## each other one in the group, and how much faster it passes with an ashwife at their fire.
@export var cough_time := Vector2(1200, 2400)
@export_range(0.0, 10.0, 0.1) var cough_drain := 0.8
@export_range(0.0, 1.0, 0.01) var cough_spread := 0.05
@export_range(1.0, 5.0, 0.1) var ashwife_cure := 2.0
## What an old cache can hold (item -> most of it), and how far a herd bolts.
@export var cache_loot := {"scrap_metal": 2, "coin": 6, "cloth": 2, "resin": 2}
@export_range(50.0, 3000.0, 50.0, "suffix:m") var scatter_distance := 600.0

var _t := 0.0

func _process(delta: float) -> void:
	_t += delta * SimClock.speed
	if _t < fate_every:
		return
	_t = 0.0
	if randf() > fate_chance or camps.camps.is_empty():
		return
	var groups: Array = camps.camps.filter(func(c): return not camps._alive(c.members).is_empty())
	if groups.is_empty():
		return
	befall(groups.pick_random())

## Something happens to group c (whatever fits it, by weight). Returns what, or "".
func befall(c) -> String:
	var people: Array = camps._alive(c.members)
	var monster: bool = c.kind in ["goblin", "orc"]
	var fits := {}
	for k in weights:
		var ok: bool = {"grey_cough": not monster, "lightless": c.wild == "" and not c.roaming and not monster and c.job.has("fire_fuel"),
			"foul_water": true, "old_cache": c.roaming and not monster, "ill_omen": not monster, "scattered": true}[k]
		if ok and weights[k] > 0.0:
			fits[k] = weights[k]
	var roll: float = randf() * fits.values().reduce(func(a, b): return a + b, 0.0)
	for k in fits:
		roll -= fits[k]
		if roll <= 0.0:
			if call("_" + k, c, people):
				return k
			return ""
	return ""

func _grey_cough(_c, people: Array) -> bool:
	var f = people.pick_random()
	if f.job.has("sick_until"):
		return false
	f.job["sick_until"] = SimClock.now + randf_range(cough_time.x, cough_time.y)
	camps.note(f, "took the grey cough")
	return true

## Called by minds each think for someone with the cough: it wears them, may spread, and passes in time.
func cough(f, minutes: float) -> void:
	var c = f.camp
	var cure: float = ashwife_cure if camps.camplife and camps.camplife.has_role(c, "ashwife") else 1.0
	f.job.sick_until -= minutes * 60.0 * (cure - 1.0) # an ashwife's care: it passes sooner
	if SimClock.now > f.job.sick_until:
		f.job.erase("sick_until")
		camps.note(f, "shook off the grey cough", false)
		return
	f.hp = maxf(0.0, f.hp - cough_drain * minutes)
	for o in camps._alive(c.members):
		if o != f and not o.job.has("sick_until") and randf() < cough_spread:
			o.job["sick_until"] = SimClock.now + randf_range(cough_time.x, cough_time.y)
			camps.note(o, "caught the grey cough from %s" % f.name, false)

func _lightless(c, people: Array) -> bool:
	c.job.fire_fuel *= 0.5 # its own wood, smothered
	for f in people:
		f.needs.safety = maxf(0.0, f.needs.safety - 40.0)
		f.traits.despair = minf(1.0, f.traits.despair + 0.05)
		if camps.minds:
			camps.minds.shake(f, "saw the fire half dead, and knew what had passed")
	camps.note(people[0], "woke to the fire half dead: the Lightless passed in the night")
	return true

func _foul_water(c, people: Array) -> bool:
	var best = null
	for o in camps.camps:
		if o.wild == "spring" and camps._dist(o.pos, c.pos) < 1500.0 and (best == null or camps._dist(o.pos, c.pos) < camps._dist(best.pos, c.pos)):
			best = o
	if best == null or not camps.camplife:
		return false
	camps.camplife.has_stock(best) # (makes sure its stock is set up)
	best.job.stock = 0
	best.job.at = SimClock.now + 1800.0 # and it's slow to come back
	camps.note(people[0], "heard the spring nearby has gone foul")
	return true

func _old_cache(_c, people: Array) -> bool:
	var f = people.pick_random()
	var got := []
	for id in cache_loot:
		var n := randi_range(0, cache_loot[id])
		if n > 0:
			camps.camplife.add(f.inv, id, n)
			got.append(id)
	if got.is_empty():
		return false
	camps.note(f, "turned up a sealed stash of the old world")
	return true

func _ill_omen(_c, people: Array) -> bool:
	for f in people:
		f.needs.faith = maxf(0.0, f.needs.faith - 30.0)
		f.traits.despair = minf(1.0, f.traits.despair + 0.05)
	camps.note(people[0], ["passed a statue turned away from the light", "saw a black bird that would not fly", "heard their own name called from the dark"].pick_random())
	return true

func _scattered(c, people: Array) -> bool:
	for h in camps.camps:
		if h.wild == "herd" and camps._dist(h.pos, c.pos) < 800.0:
			var a := randf() * TAU
			var to: Vector3 = camps._ground(h.pos + Vector3(cos(a), 0, sin(a)) * scatter_distance)
			if is_nan(to.y):
				return false
			h.pos = to
			camps.note(people[0], "heard a herd of greyhorns bolt off into the dark")
			return true
	return false
