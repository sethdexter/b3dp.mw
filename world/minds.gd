extends Node
## What the people of the island want, and what they do about it. The Camps node owns this (child "minds", made at runtime) and calls think() on each person's record now and then, near you or not.
## Every person has:
##   needs:  0-100, 100 = satisfied: food, water, light, safety, coin, belonging, faith. They drain over time and are topped up by where they are (a fire gives light and belonging, a camp shares food...) traits  0-1, rolled once: greed, courage, piety, cruelty, despair
## memories  a few things that happened to them: lost_kin (where), fed_by_player, player_killed_kin
## and picks an action by need x trait (the most urgent wins). Some actions change their state (what the world sees them as):
##   beg        starving and timid                -> leaves camp, slumps somewhere: a Starved encounter
##   extort     broke and greedy (bandit, or cruel) -> sets up a Toll on the road
##   mourn      lost kin, pious                   -> kneels where it happened: a Mourner
##   pilgrimage faith gone, pious                 -> walks to the bell, joining any Pilgrims nearby
##   wander     no fire / no company left         -> a lone Wanderer looking for a camp (settles at one)
##   turn       a starving, cruel drifter turns bandit (alone in the dark: an Ambush)
##   reform     a fed, gentle bandit becomes a drifter wanderer
##   hunt       someone whose kin you killed, with cruelty and courage, comes after you with others like them
##   collapse   food or water at 0                -> drops where they are (a Starved encounter). Fed by you or a
##              passing drifter, they get back up; otherwise hunger, thirst and the dark take their health
##   (everyone has health: the dark and starving wear it down at the same rates as yours; rest by a fire heals)
## Camps remember you too (rep): feeding, jobs and trade raise it; killing their people drops it, and a camp
## that hates you attacks on sight. A drifter camp whose people are all gone goes cold (a Cold Fire).

@export_group("Needs drain (per minute)")
@export_range(0.0, 20.0, 0.1) var food_drain := 2.0
@export_range(0.0, 20.0, 0.1) var water_drain := 3.0
@export_range(0.0, 20.0, 0.1) var light_drain := 4.0
@export_range(0.0, 20.0, 0.1) var safety_drain := 0.5
@export_range(0.0, 20.0, 0.1) var coin_drain := 1.0
@export_range(0.0, 20.0, 0.1) var belonging_drain := 3.0
@export_range(0.0, 20.0, 0.1) var faith_drain := 0.6
@export_group("Starting out")
## People start with needs somewhere in this range (0-100). Food and water only come back by eating and
## drinking real items (camplife.gd); what they start carrying and what their camp has stored is set there.
@export var start_needs := Vector2(65.0, 100.0)
## Someone just pulled out of the dark starts with food, water and light in this range (belonging at half).
@export var lost_needs := Vector2(40.0, 70.0)
## A lone person at a fire still gets this much belonging per minute (the fire is company of a sort).
@export_range(0.0, 20.0, 0.5) var alone_belonging := 3.5
@export_group("Needs refill (per minute)")
## At a lit camp: light and company. Bandit camps also live off their takings (coin).
@export_range(0.0, 50.0, 0.5) var camp_light := 20.0
@export_range(0.0, 50.0, 0.5) var camp_belonging := 8.0
## Coin need: each coin they hold (or their share of their camp's) is worth this much of it (0-100).
@export_range(0.0, 50.0, 0.5) var coin_worth := 12.0
## Safety comes back slowly while nothing bad happens.
@export_range(0.0, 50.0, 0.5) var safety_recover := 1.5
## Health a character gets back per minute resting by a fire (out of 100). The dark takes it the way it takes
## yours (your DarknessComponent's dread_time and health_drain).
@export_range(0.0, 50.0, 0.5) var rest_heal := 3.0

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
## A hungry toll-taker or ambusher walks back to a bandit fire within this (none = they starve where they wait).
@export_range(100.0, 10000.0, 100.0, "suffix:m") var road_home_range := 3000.0
## ...and they set off once food or water drops below this, so they make it before they collapse.
@export_range(0.0, 100.0, 1.0) var road_give_up := 50.0
## Chance each think that a person acts on a decision (keeps the island from changing all at once).
@export_range(0.0, 1.0, 0.05) var act_chance := 0.35


@export_group("Monsters")
## Goblins and orcs get hungry too (per minute), eat raw meat once below monster_eat_below (what they carry, else
## their den's larder) and starve to death at 0.
@export_range(0.0, 20.0, 0.1) var monster_food_drain := 1.0
@export_range(0.0, 100.0, 1.0) var monster_eat_below := 50.0

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
	"water": ["Water. Please. Anything.", "My tongue's like ash."],
	"light": ["The fire's dying. When it goes, so do we.", "I can't stand the dark much longer."],
	"safety": ["They came in the night. They'll come again.", "Keep your voice down. Something's close."],
	"coin": ["Not a coin to my name.", "Everything costs. Even the ash."],
	"belonging": ["Everyone I walked with is gone.", "It's been a long time since anyone sat with me."],
	"faith": ["The bell's calling. Can't you hear it?", "Nothing means anything out here. Nothing."],
}
@export var hated_line := "You. Murderer. Get away from our fire."
@export var grateful_line := "You fed me once. I don't forget."

var camps: Node

const NEEDS := ["food", "water", "light", "safety", "coin", "belonging", "faith"]
const TRAITS := ["greed", "courage", "piety", "cruelty", "despair"]
## Names are built from these parts, and no two people on the island share one (see _unique_name).
const FIRST := ["Ulvo", "Mott", "Aldric", "Pell", "Wick", "Hask", "Ember", "Ysolt", "Morrow", "Cinder", "Tobin", "Rook",
	"Fen", "Orrin", "Wenna", "Hester", "Calloway", "Brannoc", "Edda", "Silt", "Garrow", "Isel", "Jory", "Kestrel", "Lisbet",
	"Maud", "Nemo", "Odo", "Prisk", "Quill", "Rhun", "Sabeth", "Thane", "Ulla", "Varro", "Wyn", "Yarrow", "Zell", "Agna",
	"Bertil", "Cotter", "Dagny", "Elm", "Fitch", "Gisla", "Hob", "Ilse", "Jessop", "Kell", "Lorne", "Merrit", "Nell", "Oswin",
	"Petra", "Rafe", "Sorrel", "Tamsin", "Urien", "Vesper", "Wat", "Aud", "Brin", "Corwen", "Dacey", "Eskil", "Fallon"]
const EPITHET := ["the Unburnt", "Ninefingers", "of No Hearth", "the Pale", "Coldhands", "Ashmouth", "the Quiet", "Lame",
	"the Lantern", "Salt-Widow", "Half-Blind", "of the Dunes", "of the Marsh", "Greyback", "the Ninth Son", "Emberkeeper",
	"the Mute", "Two-Graves", "Longwalk", "the Hollow", "Bellhearer", "Sootcheek", "of the Bell", "Thornfoot", "the Forgotten",
	"Wickless", "the Elder", "the Young", "Dustborn", "Brightless", "the Counted", "of Low Rock", "Saltlicker", "the Tall",
	"Shortbread", "Firewatch", "the Lucky", "the Unlucky", "Oneboot", "of the Cairns", "Rootbinder", "the Kind", "Ashwalker"]
const BANDIT_EPITHET := ["Cutthroat", "Red Hood", "the Knife", "Scab", "Black", "Mange", "Blister", "the Tallyman",
	"Gutter", "Rotgut", "Twelve-Teeth", "Snare", "the Crow", "Bonepicker", "Hangfire", "the Toll", "Slitpurse", "Cinderjaw"]

var _used_names := {}

## A name nobody else on the island has: "Fen the Quiet", "Black Garrow", "Isel of the Marsh"...
func _unique_name(rng: RandomNumberGenerator, bandit: bool) -> String:
	for attempt in 40:
		var first: String = FIRST[rng.randi() % FIRST.size()]
		var name: String
		if bandit:
			var e: String = BANDIT_EPITHET[rng.randi() % BANDIT_EPITHET.size()]
			name = ("%s %s" % [e, first]) if rng.randf() < 0.6 else ("%s %s" % [first, e])
		else:
			var e: String = EPITHET[rng.randi() % EPITHET.size()]
			name = ("%s %s" % [first, e]) if not e.begins_with("Lame") else "Lame %s" % first
		if not _used_names.has(name):
			_used_names[name] = true
			return name
	var n := 2 # every combination's taken: number them
	var base: String = FIRST[rng.randi() % FIRST.size()]
	while _used_names.has("%s the %s" % [base, _ordinal(n)]):
		n += 1
	var last := "%s the %s" % [base, _ordinal(n)]
	_used_names[last] = true
	return last

func _ordinal(n: int) -> String:
	return ["Second", "Third", "Fourth", "Fifth", "Sixth", "Seventh", "Eighth", "Ninth"][n - 2] if n < 10 else "%dth" % n

func _ready() -> void:
	camps = get_parent()

## Fills in needs and traits the first time a person is thought about (bandits rolled harder).
## lost = just pulled out of the dark: cold, alone and hungry.
func birth(f, lost := false) -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = hash([f.home.x, f.home.z, f.camp.kind])
	if lost:
		rng.randomize()
	for n in NEEDS:
		f.needs[n] = rng.randf_range(start_needs.x, start_needs.y)
	if lost:
		f.needs.belonging = rng.randf_range(lost_needs.x * 0.5, lost_needs.y * 0.5)
		for n in ["food", "water", "light"]:
			f.needs[n] = rng.randf_range(lost_needs.x, lost_needs.y)
	for t in TRAITS:
		f.traits[t] = rng.randf()
	if f.name == "": # everyone has a name, met or not (the talker keeps it when they get a body)
		f.name = _unique_name(rng, f.camp.kind == "bandit")
	if f.camp.kind == "bandit":
		f.traits.greed = maxf(f.traits.greed, rng.randf_range(0.5, 1.0))
		f.traits.cruelty = maxf(f.traits.cruelty, rng.randf_range(0.4, 1.0))

func _now() -> float:
	return SimClock.now

## Called for every living person record as the Camps sweep reaches them.
func think(f, now: float) -> void:
	if f.camp.kind == "goblin" or f.camp.kind == "orc":
		_monster_think(f, now) # monsters only hunger
		return
	if f.needs.is_empty():
		birth(f)
		f.think_t = now + randf() * think_every
	if now < f.think_t:
		return
	var minutes: float = (now - f.think_t + think_every) / 60.0
	f.think_t = now + think_every
	_drain_and_refill(f, minutes)
	if _dark_wears(f, minutes) or _starve_wears(f, minutes):
		return # the dark, or hunger and thirst, took them
	if camps.camplife:
		camps.camplife.self_care(f) # eat and drink real items: from their pack, else their camp's crate / barrel
	var c = f.camp
	if minf(f.needs.food, f.needs.water) < road_give_up and _give_up_road(f, now):
		return
	if c.wild != "starved" and minf(f.needs.food, f.needs.water) <= 0.0:
		_become(f, "starved", f.camp.kind, false, now) # collapses where they stand
		return
	if c.wild in ["mourner", "toll", "ambush"] and f.dark_s > 0.0: # their light's out: back toward a fire, now
		if not (c.kind == "bandit" and _give_up_road(f, now)):
			_become(f, "wanderer", c.kind, true, now)
		return
	if now < f.locked_until or randf() > act_chance:
		return
	var last_one: bool = c.wild == "" and camps._alive(c.members).size() == 1 and f.needs.food >= desperate # letting a fire die is murder
	if c.wild == "" and not c.roaming and not last_one and (_take_torch(f) or f.needs.food < desperate):
		_decide_in_camp(f, now) # nobody walks away from a fire into the dark without a torch (unless starving)
	elif c.wild == "wanderer" and c.job.get("settles", false):
		pass # a mind-made wanderer: camps' band logic settles it at the first drifter fire it sees
	elif c.wild == "starved" and f.job.has("fed"):
		_become(f, "wanderer", f.camp.kind, true, now) # back on their feet
	elif c.wild == "mourner" and (_memory(f, "lost_kin") == null or now - _memory(f, "lost_kin").at > grief_time):
		_become(f, "wanderer", f.camp.kind, true, now) # grief worn down: goes looking for a fire
	elif c.kind == "bandit" and c.wild in ["", "toll", "ambush"] and f.needs.food > 70.0 and f.needs.coin > 60.0 and f.traits.cruelty < 0.3:
		_become(f, "wanderer", "drifter", true, now) # reform

func _monster_think(f, now: float) -> void:
	if f.needs.is_empty():
		f.needs = {"food": randf_range(start_needs.x, start_needs.y)}
		f.think_t = now + randf() * think_every
	if now < f.think_t:
		return
	var minutes: float = (now - f.think_t + think_every) / 60.0
	f.think_t = now + think_every
	f.needs.food = maxf(0.0, f.needs.food - monster_food_drain * minutes)
	var life = camps.camplife
	var c = f.camp
	if life and f.needs.food < monster_eat_below:
		var at_den: bool = c.wild == "" and not c.roaming and camps._dist(f.pos, c.pos) < 30.0
		var from = f.inv if f.inv.get("raw_meat", 0) > 0 else (c.crate if at_den and c.crate.get("raw_meat", 0) > 0 else null)
		if from != null:
			life.add(from, "raw_meat", -1)
			f.needs.food = minf(100.0, f.needs.food + life.nourish("raw_meat").x)
	if f.needs.food <= 0.0: # starved
		f.dead = true
		if is_instance_valid(f.node) and f.node.statComponent:
			f.node.statComponent.health.change_current(-100000) # the record is already dead, so nobody's blamed
		f.node = null

## The dark wears everyone down the same way: out of the light (no fire close, no torch or brand burning) for
## longer than your DarknessComponent's dread_time, health drains at its rate (as a share of your health, so a
## character goes as fast as you would). Resting by a fire heals slowly. True = it killed them.
func _dark_wears(f, minutes: float) -> bool:
	var c = f.camp
	var dk: Node = camps._player.get_node_or_null("darkness") if is_instance_valid(camps._player) else null
	var fire_r: float = dk.fire_light_radius if dk else 14.0
	var at_fire: bool = c.wild == "" and not c.roaming and c.kind in ["drifter", "bandit"] and camps._dist(f.pos, c.pos) < fire_r
	var torch: bool = (c.roaming and c.job.get("fuel", 0.0) > 0.0) or f.task.get("brand", 0.0) > SimClock.now or c.job.get("lit_until", 0.0) > SimClock.now or c.raid != null # raiders carry brands from their fire
	if not at_fire and not torch and f.dark_s > 0.0: # a cairn's torch lights them as it would you
		var tr: float = dk.torch_light_radius if dk else 8.0
		for o in camps.camps:
			if o.wild == "cairn" and camps._dist(o.pos, f.pos) < tr:
				torch = true
				break
	if at_fire or torch:
		f.dark_s = 0.0
		if at_fire:
			f.hp = minf(100.0, f.hp + rest_heal * minutes)
		return false
	var before: float = f.dark_s
	f.dark_s += minutes * 60.0
	var dread: float = dk.dread_time if dk else 60.0
	var over: float = maxf(0.0, f.dark_s - maxf(before, dread))
	var hp_max: float = float(camps._player.statComponent.health.get_max_value()) if dk and camps._player.statComponent else 100.0
	f.hp -= over * (dk.health_drain if dk else 0.25) / hp_max * 100.0
	if f.hp > 0.0:
		return false
	camps.note(f, "the dark wore them down until there was nothing left")
	_die(f)
	return true

## Starving or parched (food or water at 0) costs health at your NeedsComponent's rate, as a share of your
## health. True = it killed them.
func _starve_wears(f, minutes: float) -> bool:
	var p = camps._player if is_instance_valid(camps._player) else null
	var nc: Node = p.get_node_or_null("needs") if p else null
	var per_s: float = ((nc.hunger_damage if nc else 0.3) if f.needs.food <= 0.0 else 0.0) + ((nc.thirst_damage if nc else 0.3) if f.needs.water <= 0.0 else 0.0)
	if per_s <= 0.0:
		return false
	var hp_max: float = float(p.statComponent.health.get_max_value()) if p and p.statComponent else 10.0
	f.hp -= per_s * minutes * 60.0 / hp_max * 100.0
	if f.hp > 0.0:
		return false
	camps.note(f, "died of %s" % ("thirst" if f.needs.water <= 0.0 else "hunger"))
	_die(f)
	return true

## Someone's dead with no fight in it (dark, hunger): their body falls, and where nobody saw it, it's left lying
## with their pack for someone to find.
func _die(f) -> void:
	f.dead = true
	var c = f.camp
	if c.wild != "" and camps._alive(c.members).is_empty(): # nobody left in that state: it's over
		if is_instance_valid(c.fire):
			c.fire.queue_free()
		camps.camps.erase(c)
	if is_instance_valid(f.node) and f.node.statComponent:
		f.node.statComponent.health.change_current(-100000) # the record is already dead, so nobody's blamed
	else:
		camps.leave_body(f)
	f.node = null
	on_death(f, false)

## A torch to go with: their own, or one from the camp's crate. False = none (so they stay by the fire).
func _take_torch(f) -> bool:
	if f.inv.get("torch", 0) > 0:
		return true
	if f.camp.crate.get("torch", 0) > 0 and camps.camplife:
		camps.camplife.move(f.camp.crate, f.inv, "torch", 1)
		return true
	return false

## Average food need of a group (100 if they've no needs yet).
func _avg_food(people: Array) -> float:
	var s := 0.0
	for f in people:
		s += f.needs.get("food", 100.0)
	return s / maxi(1, people.size())

func _drain_and_refill(f, minutes: float) -> void:
	var c = f.camp
	var at_fire: bool = c.wild == "" and not c.roaming and c.kind in ["drifter", "bandit"] and camps._dist(f.pos, c.pos) < 30.0 # out foraging = not at the fire
	var company: int = camps._alive(c.members).size() - 1
	var d := {"food": food_drain, "water": water_drain, "light": light_drain, "safety": safety_drain, "coin": coin_drain,
		"belonging": belonging_drain, "faith": faith_drain}
	for n in NEEDS:
		f.needs[n] = clampf(f.needs[n] - d[n] * minutes, 0.0, 100.0)
	if at_fire:
		f.needs.light = minf(100.0, f.needs.light + camp_light * minutes)
		f.needs.belonging = minf(100.0, f.needs.belonging + (camp_belonging if company > 0 else alone_belonging) * minutes)

	if camps.camplife and ((c.roaming and c.job.get("fuel", 0.0) > 0.0) or f.task.get("brand", 0.0) > SimClock.now): # a lit torch / brand
		f.needs.light = minf(100.0, f.needs.light + camps.camplife.torch_light * minutes)
	if c.raid == null:
		f.needs.safety = minf(100.0, f.needs.safety + safety_recover * minutes)
	var coins: float = f.inv.get("coin", 0) + (float(c.crate.get("coin", 0)) / maxi(1, company + 1) if at_fire else 0.0)
	f.needs.coin = minf(100.0, coins * coin_worth) # how well off they feel is the coin they hold (and their camp's share)
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
		_become(f, "mourner", f.camp.kind, false, now, grief.pos)
	elif f.camp.kind == "drifter" and n.food < desperate and t.cruelty > trait_bar and t.despair > 0.5:
		_become(f, "toll" if t.greed > t.cruelty else "ambush", "bandit", false, now) # turns bandit
	elif n.food < desperate and t.courage < 0.4:
		_become(f, "starved", f.camp.kind, false, now)
	elif n.coin < desperate and t.greed > trait_bar and (f.camp.kind == "bandit" or t.cruelty > 0.5):
		_become(f, "toll", "bandit", false, now)
	elif n.faith < desperate * 1.5 and t.piety > trait_bar:
		_pilgrimage(f, now)
	elif n.belonging < desperate or n.light < desperate:
		_become(f, "wanderer", f.camp.kind, true, now)

# --- turning someone into an encounter ------------------------------------------

## Moves f out of its camp into a new one-person encounter of this wild kind at `at` (default: where they are).
## Their character (if near you) is respawned so it takes on the new role.
func _become(f, wild: String, kind: String, roams: bool, now: float, at = null) -> void:
	camps.note(f, {"starved": "collapsed: too hungry or thirsty to go on", "toll": "turned to robbing travellers on the road",
		"ambush": "turned bandit and went to lie in wait", "mourner": "went to kneel where their kin died",
		"wanderer": "left to wander, looking for a fire", "pilgrims": "set off for the bell", "stalker": "set out to hunt you"}.get(wild, "became " + wild))
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
	if wild == "starved": # collapsed or begging: hunger, thirst and the dark wear them down unless someone helps
		f.job.erase("fed") # fed before doesn't save them this time
	if not roams and wild in ["mourner", "toll", "ambush"] and camps.camplife: # they'll sit out in the dark: they light what torches they have
		var n: int = f.inv.get("torch", 0)
		if n > 0:
			camps.camplife.add(f.inv, "torch", -n)
			c.job["lit_until"] = now + n * camps.camplife.npc_torch_time * camps.camplife.torch_lights
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

## Hungry or thirsty on the road with no camp to eat from: bandits on the road (tolls, ambushes) walk back to a bandit
## fire and join it; pilgrims give up the walk and go looking for a fire. True = they did.
func _give_up_road(f, now: float) -> bool:
	var c = f.camp
	if c.wild == "pilgrims":
		_become(f, "wanderer", f.camp.kind, true, now)
		return true
	if not c.wild in ["toll", "ambush"]:
		return false
	var home = null
	for o in camps.camps:
		if o.bandit and o.wild == "" and not o.roaming and camps._dist(o.pos, f.pos) < road_home_range and (home == null or camps._dist(o.pos, f.pos) < camps._dist(home.pos, f.pos)):
			home = o
	if home == null:
		return false
	camps.note(f, "gave up the road, starving, and went back to a bandit fire")
	c.members.erase(f)
	home.members.append(f)
	f.camp = home
	f.locked_until = now + settle_time
	camps._send(f, home.pos)
	if is_instance_valid(f.node):
		f.node.queue_free()
	f.node = null
	return true

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
	_become(f, "pilgrims", f.camp.kind, true, now)

## Gathers this person and anyone in their camp who shares the grudge into a band that hunts you.
func _hunt(f, now: float) -> void:
	var c = f.camp
	var band: Array = camps._alive(c.members).filter(func(o): return o == f or (_memory(o, "player_killed_kin") and o.traits.courage > 0.4))
	_become(f, "stalker", c.kind, true, now)
	var b = f.camp
	b.den = c # when it's over they go back
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
		if not o.camp.kind in ["goblin", "orc"]:
			camps.note(o, "lost %s" % (f.name if f.name != "" else "one of their own"))
		if o.needs.has("safety"): # monsters only have hunger
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
