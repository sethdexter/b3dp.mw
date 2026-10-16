extends Node
## What the people of the island want, and what they do about it. The Camps node owns this (child "minds",
## made at runtime) and calls think() on each person's record now and then, near you or not.
##
## Every person has:
##   needs     0-100, 100 = satisfied: food, light, safety, coin, belonging, faith. They drain over time and
##             are topped up by where they are (a fire gives light and belonging, a camp shares food...)
##   traits    0-1, rolled once: greed, courage, piety, cruelty, despair
##   memories  a few things that happened to them: lost_kin (where), fed_by_player, player_killed_kin
## and picks an action by need x trait (the most urgent wins). Some actions turn them into encounters:
##   beg        starving and timid                -> leaves camp, slumps somewhere: a Starved encounter
##   extort     broke and greedy (bandit, or cruel) -> sets up a Toll on the road
##   mourn      lost kin, pious                   -> kneels where it happened: a Mourner
##   pilgrimage faith gone, pious                 -> walks to the bell, joining any Pilgrims nearby
##   wander     no fire / no company left         -> a lone Wanderer looking for a camp (settles at one)
##   turn       a starving, cruel drifter turns bandit (alone in the dark: an Ambush)
##   reform     a fed, gentle bandit becomes a drifter wanderer
##   hunt       someone whose kin you killed, with cruelty and courage, comes after you with others like them
## Camps remember you too (rep): feeding, jobs and trade raise it; killing their people drops it, and a camp
## that hates you attacks on sight. A drifter camp whose people are all gone goes cold (a Cold Fire).

@export_group("Needs drain (per minute)")
@export_range(0.0, 20.0, 0.1) var food_drain := 2.0
@export_range(0.0, 20.0, 0.1) var light_drain := 4.0
@export_range(0.0, 20.0, 0.1) var safety_drain := 0.5
@export_range(0.0, 20.0, 0.1) var coin_drain := 1.0
@export_range(0.0, 20.0, 0.1) var belonging_drain := 3.0
@export_range(0.0, 20.0, 0.1) var faith_drain := 0.6
@export_group("Camp supplies")
## A camp starts with this much food in store, plus this much per person (one point = one point of someone's
## food need). Members eat from it; when it runs out they go hungry.
@export_range(0.0, 2000.0, 10.0) var start_supplies := 300.0
@export_range(0.0, 1000.0, 10.0) var supplies_per_person := 150.0
## Food the camp gathers per minute (foraging, hunting), shared into the store.
@export_range(0.0, 50.0, 0.5) var forage := 3.0
## People start with needs somewhere in this range (0-100).
@export var start_needs := Vector2(65.0, 100.0)
## A lone person at a fire still gets this much belonging per minute (the fire is company of a sort).
@export_range(0.0, 20.0, 0.5) var alone_belonging := 2.5
@export_group("Needs refill (per minute)")
## At a lit camp: food (shared out), light and company. Bandit camps also live off their takings (coin).
@export_range(0.0, 50.0, 0.5) var camp_food := 2.5
@export_range(0.0, 50.0, 0.5) var camp_light := 20.0
@export_range(0.0, 50.0, 0.5) var camp_belonging := 8.0
@export_range(0.0, 50.0, 0.5) var bandit_coin := 1.5
## Safety comes back slowly while nothing bad happens.
@export_range(0.0, 50.0, 0.5) var safety_recover := 1.5

@export_group("Thinking")
## Seconds between each person's decisions (spread out, cheap). They act at most this often.
@export_range(5.0, 600.0, 5.0, "suffix:s") var think_every := 30.0
## After changing what they do, someone sticks with it at least this long.
@export_range(10.0, 3600.0, 10.0, "suffix:s") var settle_time := 300.0
## A need below this is "desperate" and can push someone to act.
@export_range(0.0, 50.0, 1.0) var desperate := 15.0
## Trait needed for the trait-gated actions (0-1).
@export_range(0.0, 1.0, 0.05) var trait_bar := 0.6
## How long a fresh loss makes someone want to mourn.
@export_range(10.0, 3600.0, 10.0, "suffix:s") var grief_time := 600.0
## Chance each think that a person acts on a decision (keeps the island from changing all at once).
@export_range(0.0, 1.0, 0.05) var act_chance := 0.35

@export_group("Reputation")
@export_range(-100, 100) var rep_fed := 15
@export_range(-100, 100) var rep_job := 10
@export_range(-100, 100) var rep_trade := 1
@export_range(-100, 100) var rep_killed := -40
## A camp at or below this attacks you on sight.
@export_range(-100, 0) var hate_at := -40
## A drifter camp empty this long goes cold.
@export_range(10.0, 1800.0, 10.0, "suffix:s") var cold_after := 120.0

@export_group("Talk")
## Chance a person talks about their worst need instead of a stock line.
@export_range(0.0, 1.0, 0.05) var need_talk_chance := 0.5
@export var need_lines := {
	"food": ["I haven't eaten in days.", "If you've bread, I'll listen to anything you say."],
	"light": ["The fire's dying. When it goes, so do we.", "I can't stand the dark much longer."],
	"safety": ["They came in the night. They'll come again.", "Keep your voice down. Something's close."],
	"coin": ["Not a coin to my name.", "Everything costs. Even the ash."],
	"belonging": ["Everyone I walked with is gone.", "It's been a long time since anyone sat with me."],
	"faith": ["The bell's calling. Can't you hear it?", "Nothing means anything out here. Nothing."],
}
@export var hated_line := "You. Murderer. Get away from our fire."
@export var grateful_line := "You fed me once. I don't forget."

var camps: Node

const NEEDS := ["food", "light", "safety", "coin", "belonging", "faith"]
const TRAITS := ["greed", "courage", "piety", "cruelty", "despair"]

func _ready() -> void:
	camps = get_parent()

## Fills in needs and traits the first time a person is thought about (bandits rolled harder).
func birth(f) -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = hash([f.home.x, f.home.z, f.camp.kind])
	for n in NEEDS:
		f.needs[n] = rng.randf_range(start_needs.x, start_needs.y)
	for t in TRAITS:
		f.traits[t] = rng.randf()
	if f.camp.kind == "bandit":
		f.traits.greed = maxf(f.traits.greed, rng.randf_range(0.5, 1.0))
		f.traits.cruelty = maxf(f.traits.cruelty, rng.randf_range(0.4, 1.0))

func _now() -> float:
	return SimClock.now

## Called for every living person record as the Camps sweep reaches them.
func think(f, now: float) -> void:
	if f.camp.kind == "goblin" or f.camp.kind == "orc":
		return # monsters don't have this kind of mind
	if f.needs.is_empty():
		birth(f)
		f.think_t = now + randf() * think_every
	if now < f.think_t:
		return
	var minutes: float = (now - f.think_t + think_every) / 60.0
	f.think_t = now + think_every
	_drain_and_refill(f, minutes)
	if now < f.locked_until or randf() > act_chance:
		return
	var c = f.camp
	if c.wild == "" and not c.roaming:
		_decide_in_camp(f, now)
	elif c.wild == "wanderer" and c.job.get("settles", false):
		pass # a mind-made wanderer: camps' band logic settles it at the first drifter fire it sees
	elif c.wild == "starved" and f.job.has("fed"):
		_become(f, "wanderer", "drifter", true, now) # back on their feet
	elif c.kind == "bandit" and c.wild in ["", "toll", "ambush"] and f.needs.food > 70.0 and f.needs.coin > 60.0 and f.traits.cruelty < 0.3:
		_become(f, "wanderer", "drifter", true, now) # reform

func _drain_and_refill(f, minutes: float) -> void:
	var c = f.camp
	var at_fire: bool = c.wild == "" and not c.roaming and c.kind in ["drifter", "bandit"]
	var company: int = camps._alive(c.members).size() - 1
	var d := {"food": food_drain, "light": light_drain, "safety": safety_drain, "coin": coin_drain,
		"belonging": belonging_drain, "faith": faith_drain}
	for n in NEEDS:
		f.needs[n] = clampf(f.needs[n] - d[n] * minutes, 0.0, 100.0)
	if at_fire:
		if c.supplies < 0.0:
			c.supplies = start_supplies + supplies_per_person * (company + 1)
		c.supplies += forage * minutes / maxf(1.0, company + 1) # each member's share of the day's gathering
		var eat := minf(minf(camp_food * minutes, 100.0 - f.needs.food), c.supplies) # from the store, while it lasts
		f.needs.food += eat
		c.supplies -= eat
		f.needs.light = minf(100.0, f.needs.light + camp_light * minutes)
		f.needs.belonging = minf(100.0, f.needs.belonging + (camp_belonging if company > 0 else alone_belonging) * minutes)
		if c.kind == "bandit":
			f.needs.coin = minf(100.0, f.needs.coin + bandit_coin * minutes)
	if c.raid == null:
		f.needs.safety = minf(100.0, f.needs.safety + safety_recover * minutes)
	if c.wild == "pilgrims":
		f.needs.faith = minf(100.0, f.needs.faith + 4.0 * minutes) # walking to the bell keeps them going

## The most urgent thing a camp member could do, if anything. Ordered roughly by how strong the pull is.
func _decide_in_camp(f, now: float) -> void:
	var n: Dictionary = f.needs
	var t: Dictionary = f.traits
	var grief = _memory(f, "lost_kin")
	var hate = _memory(f, "player_killed_kin")
	if hate and t.cruelty > 0.5 and t.courage > 0.5:
		_hunt(f, now)
	elif grief and now - grief.at < grief_time and t.piety > trait_bar:
		_become(f, "mourner", "drifter", false, now, grief.pos)
	elif f.camp.kind == "drifter" and n.food < desperate and t.cruelty > trait_bar and t.despair > 0.5:
		_become(f, "toll" if t.greed > t.cruelty else "ambush", "bandit", false, now) # turns bandit
	elif n.food < desperate and t.courage < 0.4:
		_become(f, "starved", "drifter", false, now)
	elif n.coin < desperate and t.greed > trait_bar and (f.camp.kind == "bandit" or t.cruelty > 0.5):
		_become(f, "toll", "bandit", false, now)
	elif n.faith < desperate * 1.5 and t.piety > trait_bar:
		_pilgrimage(f, now)
	elif n.belonging < desperate or n.light < desperate:
		_become(f, "wanderer", "drifter", true, now)

# --- turning someone into an encounter ------------------------------------------

## Moves f out of its camp into a new one-person encounter of this wild kind at `at` (default: where they are).
## Their character (if near you) is respawned so it takes on the new role.
func _become(f, wild: String, kind: String, roams: bool, now: float, at = null) -> void:
	var old = f.camp
	old.members.erase(f)
	var c = camps.new_camp()
	c.pos = at if at != null else f.pos
	c.wild = wild
	c.kind = kind
	c.bandit = kind == "bandit"
	c.next_move = INF
	c.roaming = roams
	c.heading = randf() * TAU
	c.from = old
	if wild == "wanderer":
		c.job["settles"] = true # unlike the island's born wanderers, these are looking for a new fire
	c.members.append(f)
	f.camp = c
	f.home = c.pos
	f.locked_until = now + settle_time
	camps.camps.append(c)
	if is_instance_valid(f.node):
		f.node.queue_free() # comes back in its new role on the next sweep
	f.node = null

func _pilgrimage(f, now: float) -> void:
	for b in camps.camps:
		if b.wild == "pilgrims" and b.roaming and camps._dist(b.pos, f.pos) < 400.0:
			f.camp.members.erase(f) # join the line
			b.members.append(f)
			f.camp = b
			f.locked_until = now + settle_time
			if is_instance_valid(f.node):
				f.node.queue_free()
			f.node = null
			return
	_become(f, "pilgrims", "drifter", true, now)

## Gathers this person and anyone in their camp who shares the grudge into a band that hunts you.
func _hunt(f, now: float) -> void:
	var c = f.camp
	var band: Array = camps._alive(c.members).filter(func(o): return o == f or (_memory(o, "player_killed_kin") and o.traits.courage > 0.4))
	_become(f, "stalker", c.kind, true, now)
	var b = f.camp
	b.raid_since = now
	for o in band:
		if o != f:
			c.members.erase(o)
			b.members.append(o)
			o.camp = b
			o.locked_until = now + settle_time
			if is_instance_valid(o.node):
				o.node.queue_free()
			o.node = null
	if camps._player:
		b.pos = camps._player.global_position

# --- memories and reputation ------------------------------------------------------

func remember(f, what: String, pos := Vector3.ZERO) -> void:
	f.memories.append({"what": what, "at": _now(), "pos": pos})
	if f.memories.size() > 6:
		f.memories.pop_front()

func _memory(f, what: String):
	for i in range(f.memories.size() - 1, -1, -1):
		if f.memories[i].what == what:
			return f.memories[i]
	return null

## Someone died: everyone in their camp grieves (and is shaken). by_player = you did it.
func on_death(f, by_player: bool) -> void:
	var c = f.camp
	for o in camps._alive(c.members):
		if o == f:
			continue
		remember(o, "lost_kin", f.pos)
		if not o.needs.is_empty():
			o.needs.safety = maxf(0.0, o.needs.safety - 40.0)
		if by_player:
			remember(o, "player_killed_kin", f.pos)
	if by_player:
		rep(c, rep_killed)

func rep(c, amount: int) -> void:
	if c:
		c.rep = clampi(c.rep + amount, -100, 100)

func hates(c) -> bool:
	return c != null and c.rep <= hate_at

## Cold fires: a drifter camp with nobody left for a while goes out.
func check_cold(c, now: float) -> void:
	if c.wild != "" or c.roaming or c.kind != "drifter":
		return
	if camps._alive(c.members).is_empty():
		if c.empty_since <= 0.0:
			c.empty_since = now
		elif now - c.empty_since > cold_after:
			if is_instance_valid(c.fire):
				c.fire.queue_free()
			c.wild = "coldfire"
	else:
		c.empty_since = 0.0

## A line about how they're doing, or "" to let the talker use its usual lines.
func mood_line(f) -> String:
	if f == null or f.needs.is_empty():
		return ""
	if hates(f.camp):
		return hated_line
	if _memory(f, "fed_by_player") and randf() < 0.3:
		return grateful_line
	if randf() > need_talk_chance:
		return ""
	var worst := ""
	for n in NEEDS:
		if worst == "" or f.needs[n] < f.needs[worst]:
			worst = n
	if f.needs[worst] > 50.0:
		return "" # nothing much troubling them
	var lines: Array = need_lines.get(worst, [])
	return lines[randi() % lines.size()] if not lines.is_empty() else ""
