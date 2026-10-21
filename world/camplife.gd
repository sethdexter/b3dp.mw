extends Node
## How people actually get by: with real items. The Camps node owns this (child "camplife", made at runtime).
##
## Stuff
##   - every person carries a pack (Folk.inv: item id -> count) of the same items you use: water skins, bread,
##     ash caps, raw meat, torches, coin
##   - every drifter / bandit camp has a water barrel (Camp.barrel) and a supply crate (Camp.crate). Near you
##     they're real containers you can open (world/props/campStoreSync.gd keeps them in sync with the records)
##   - eating and drinking means taking an item (from your pack, else your camp's crate / barrel) and using it:
##     its NourishEffect (food / water) is what it does for them, the same as for you
## Chores (camp people, when the barrel / crate run low)
##   - water: walk to the nearest spring, fill skins (as many as they can carry), bring them back, put them in
##     the barrel
##   - forage: walk to ash fungus (picking what the patch has) or to the nearest herd of game to hunt (raw meat),
##     bring it back to the crate. Springs and fungus run dry and come back slowly (Sources); herds breed (camps.gd)
##   - supply: a camp with plenty sends someone to carry food to a hungry drifter camp nearby
##   - evacuate: a camp with nothing left packs up what it has and walks to a better camp, joining it
##   - wood: cut small trees at a copse (logs, kindling, tinder); sap: cut resin from a sap node on a giant tree
##   - trade: take the camp's coin to a neighbouring camp with surplus and buy what's short
## Each chore takes torches for the trip from the crate (no torch, no chore); the fittest goes, or whoever holds
## the role for it (drawer: wood and sap, waterbearer: water).
## Fire: the camp's fire burns its fuel (Camp.job.fire_fuel, one log = wood_burn); its people feed it from the
## crate. Logs on it = its size: light reach, how many it keeps (capacity), and its tier (bonfire / hearth / pyre,
## which also needs people in the roles: firekeeper, drawer, waterbearer, wickbearer, storyteller, ashwife).
## Torches are made from logs and resin. Lighting a fire takes a spark, tinder, kindling and logs, and can fail.
## Out of wood = the fire goes out, and the camp leaves as a band.
## Travellers (wanderers, pilgrims, anyone on the road) carry their own skins, food and torches: one torch burns
## at a time; low on torches they head for a fire (their own kind's camp or a cairn) to relight and to ask for
## what the camp can spare; thirsty they make for a spring and fill up; hungry, for fungus.
## The same plans run on the records far away and are walked by real characters near you.

@export_range(2.0, 120.0, 1.0, "suffix:s") var plan_every := 15.0
@export_group("Eating and drinking")
## People eat / drink once the need is below these (0-100).
@export_range(0.0, 100.0, 1.0) var eat_below := 55.0
@export_range(0.0, 100.0, 1.0) var drink_below := 60.0
## How much one person carries at most of water skins / food items.
@export_range(1, 20) var carry_skins := 4
@export_range(1, 20) var carry_food := 4
@export_group("Starting stuff")
## What each person starts with in their pack, and what each camp's barrel / crate starts with per person.
@export var pack_start := {"water_skin": 1, "bread": 1}
## Nothing extra from nowhere: anyone setting out takes what they can from their camp (tend_torch).
@export var traveller_extra := {}
## Setting out from a camp, each takes this much from its stores if it's there (and the group a torch or two).
@export var road_share := {"water_skin": 1, "bread": 1, "tinder": 1, "kindling": 1}
@export_range(0, 5) var road_torches := 1
@export_range(0, 20) var barrel_per_person := 2
@export var crate_per_person := {"bread": 1, "ash_cap": 1, "torch": 2, "ash_wood": 1, "tinder": 1, "kindling": 1}
## And the goods a camp starts with, whatever its size (random in each range): what you see set out on its
## barrels and crates is what's here.
@export var goods_start := {"coin": Vector2i(2, 14), "ash_wine": Vector2i(0, 2), "health_potion": Vector2i(0, 1), "flint": Vector2i(0, 1),
	"bone_knife": Vector2i(0, 1), "staff": Vector2i(0, 2), "black_iron_sword": Vector2i(0, 0)}
@export_group("Chores")
## A camp fetches water when its barrel has fewer than this many skins per person, and forages below this
## much food per person (in items).
@export_range(0, 20) var water_low := 3
@export_range(0, 20) var food_low := 3
## At most this share of the camp out foraging at once.
@export_range(0.0, 1.0, 0.05) var forager_share := 0.75
@export_range(50.0, 3000.0, 10.0, "suffix:m") var forage_range := 300.0
@export_range(50.0, 3000.0, 10.0, "suffix:m") var spring_range := 900.0
## Seconds spent gathering / filling (what they get is what the place has: see Sources and Hunting).
@export var gather_time := Vector2(40, 90)
## A camp with more than surplus food items per person sends some to a drifter camp with less than needy.
@export_range(0, 50) var surplus := 8
@export_range(0, 50) var needy := 1
@export_range(100.0, 5000.0, 50.0, "suffix:m") var aid_range := 1500.0
@export_range(100.0, 5000.0, 50.0, "suffix:m") var evacuate_range := 2000.0
@export_group("Travellers")
## While their torch is lit, travellers' light need refills this fast (per minute), like being at a fire.
@export_range(0.0, 50.0, 0.5) var torch_light := 15.0
## Travellers who come to a fire (or a cairn's light) sit and rest this long (seconds, random in range) before going on.
@export var rest_time := Vector2(180, 420)
@export_range(50.0, 3000.0, 10.0, "suffix:m") var seek_range := 900.0
## A camp of their own kind gives a traveller up to this many items of food / water, if it has more than
## floor per person.
@export_range(0, 10) var gift := 2
@export_range(0, 20) var gift_floor := 3
## Blackflesh (cut from goblins and orcs) is eaten only when starving: each time it costs this much light (the
## dark sits heavier on them, safety too at half) and this much despair, for good.
@export_range(0.0, 100.0, 1.0) var blackflesh_dark := 25.0
@export_range(0.0, 1.0, 0.01) var blackflesh_despair := 0.1
@export_group("Wood and fire")
## A camp's fire burns its wood: one log keeps it going this long, and its people put another on once it's down to
## fire_feed_below (from their crate). Out of wood, it dies: a cold fire, and they go looking for another.
@export_range(30.0, 3600.0, 10.0, "suffix:s") var wood_burn := 1200.0
@export_range(0.0, 3600.0, 10.0, "suffix:s") var fire_feed_below := 300.0
## The more wood on a fire, the bigger it burns (light reaches further) and the more people it keeps: each log's worth
## on it keeps people_per_log, up to max_fire_logs on at once. Its people keep it as big as their numbers need.
@export_range(1, 10) var people_per_log := 2
@export_range(1, 20) var max_fire_logs := 9
## A firekeeper keeps this many logs more on than the camp needs (room for newcomers: how a fire grows a tier).
@export_range(0, 5) var keeper_spare := 1
## Fire tiers by logs on it: a bonfire below hearth_logs, a hearth below pyre_logs, then a pyre.
@export_range(1, 20) var hearth_logs := 4
@export_range(1, 20) var pyre_logs := 7
## An ash storm makes a fire burn this much faster at its height (a small push; raids only hurt a fire through what they take and who they kill).
@export_range(1.0, 3.0, 0.05) var storm_fire_burn := 1.25
## Lighting a fire takes a spark (a flame, or a flint and striker), tinder to catch it, kindling to feed it, then two
## logs. It catches at light_chance (times storm_light at an ash storm's height); a failed go burns the tinder.
@export_range(0.0, 1.0, 0.05) var light_chance := 0.8
## Logs a fire takes to light (they're its first fuel).
@export_range(1, 10) var light_logs := 3
@export_range(0.0, 1.0, 0.05) var storm_light := 0.4
## A fire that burned at least ember_burn before it went out leaves embers for ember_time: kindling and logs on them
## and it takes, no tinder or spark needed, every time.
@export_range(0.0, 7200.0, 60.0, "suffix:s") var ember_burn := 1800.0
@export_range(0.0, 3600.0, 30.0, "suffix:s") var ember_time := 600.0
## Each small tree cut also gives this much kindling and tinder (twigs, bark and moss).
@export_range(0, 10) var kindling_per_tree := 2
@export_range(0, 10) var tinder_per_tree := 1
## How long a camp's fire has to run on when the island starts (random in range).
@export var fire_start := Vector2(900, 1800)
## A camp sends someone for wood when its crate holds fewer logs than this per person, to the nearest copse in range.
@export_range(0, 20) var wood_low := 2
@export_range(50.0, 3000.0, 10.0, "suffix:m") var copse_range := 700.0
## Nobody remembers where to find something the camp needs: someone walks out up to this far to look.
## Something not where they remembered: they cast about search_radius around, up to search_tries times.
@export_range(50.0, 3000.0, 10.0, "suffix:m") var explore_range := 500.0
@export_range(5.0, 200.0, 5.0, "suffix:m") var search_radius := 30.0
@export_range(0, 10) var search_tries := 3
## Cutting a small tree: seconds by hand / with a hatchet (you), wood it gives (+ more with a hatchet), and how far
## the noise carries (hostiles come).
@export_range(0.5, 60.0, 0.5, "suffix:s") var chop_hand_time := 8.0
@export_range(0.5, 60.0, 0.5, "suffix:s") var chop_axe_time := 3.0
@export_range(1, 10) var wood_per_tree := 2
## Logs one person carries back from a wood trip (they cut trees until they have this many, or the copse is bare).
@export_range(1, 40) var wood_carry := 8
## A camp makes a torch out of a log at its fire when it has fewer than this many per person (keeping the last
## logs for the fire). shortcut: one log makes a torch until crafting gives torches a real recipe.
@export_range(0, 10) var torches_low := 2
## Torches split from one log.
@export_range(1, 10) var torches_per_log := 3
## Making torches takes sap (resin): a log's worth of torches takes this much. Sap also renews a spent torch
## (one resin instead of a burnt stub). It only comes from sap nodes on the giant trees: a drawer goes to cut it
## (sap_per_trip at most) when the crate has fewer than sap_low.
@export_range(0, 10) var sap_per_log := 1
@export_range(0, 10) var sap_per_trip := 2
@export_range(0, 20) var sap_low := 2
@export_range(0, 10) var axe_bonus := 1
@export_range(0.0, 200.0, 1.0, "suffix:m") var chop_noise := 35.0
@export_group("Roles")
## Who a camp's people are to it, given out in this order as it has people for them (the best suited first). A fire
## is a hearth only with a firekeeper and a storyteller, and a pyre only with every role filled (and the wood for it).
const ROLES := ["firekeeper", "drawer", "waterbearer", "wickbearer", "storyteller", "ashwife"]
## Healing at the fire is this many times faster with an ashwife (or ashman) tending the hurt.
@export_range(1.0, 5.0, 0.1) var ashwife_heal := 2.0
## At a hearth or a pyre a storyteller gives this much belonging per minute, and wears despair down by story_ease a minute.
@export_range(0.0, 20.0, 0.5) var story_belonging := 4.0
@export_range(0.0, 0.05, 0.0005) var story_ease := 0.002
## When a lost soul is pulled to a fire with a storyteller, chance another follows them in (bigger fires pull more too).
@export_range(0.0, 1.0, 0.01) var story_extra := 0.1
## A role you hold: do its work at least this often (sim seconds) or lose it.
@export_range(60.0, 36000.0, 60.0, "suffix:s") var duty_time := 1800.0
## A camp's bad feeling about you heals by 1 every rep_heal_every; a cinder-thief is forgiven after forgive_after.
@export_range(10.0, 3600.0, 10.0, "suffix:s") var rep_heal_every := 120.0
@export_range(60.0, 72000.0, 60.0, "suffix:s") var forgive_after := 10800.0
@export_group("Trade")
## Characters buy from each other at the prices you pay a trader: an item's value x this (same as the shops'
## sell_markup), the coin going into the seller's stores. A camp only sells what it has beyond this much per person.
@export_range(1.0, 5.0, 0.05) var npc_markup := 1.5
@export_range(0, 20) var sell_floor := 2
## A camp short of water or food with coin to spend sends someone to buy from a neighbour of its own kind with
## plenty (within aid_range), taking up to this much coin.
@export_range(0, 200) var trade_purse := 30
@export_group("Sources")
## Springs, fungus and salt run out and come back slowly; the barer a place is picked, the slower: a picked-bare
## one comes back this many times slower than a nearly full one. Same stock for you and everyone else.
@export_range(0.0, 20.0, 0.5) var bare_slow := 3.0
@export_group("Hunting")
## Hunters go after the nearest herd of game within this, kill this many (random in range, never more than the
## herd has) and bring back this much raw meat per kill. No herd near: nobody goes hunting.
@export_range(50.0, 5000.0, 10.0, "suffix:m") var hunt_range := 1000.0
@export var hunt_kills := Vector2i(2, 4)
@export_range(1, 10) var meat_per_kill := 3
@export_group("")

## Places that run out: [most uses, seconds for one use to come back when nearly full, what one use gives].
const SOURCES := {"spring": [6, 90.0, 2], "fungus": [3, 300.0, 2], "salt": [3, 900.0, 1], "sap": [3, 1800.0, 1]}

## Grows a place's stock back: one use at a time, each slower the emptier it is. s = {stock, at}.
static func regrow(s: Dictionary, most: int, every: float, slow: float, now: float) -> void:
	if not s.has("stock"):
		s["stock"] = most
		s["at"] = now
		return
	while s.stock < most:
		var wait: float = every * (1.0 + slow * (1.0 - float(s.stock) / most))
		if now - s.at < wait:
			return
		s.at += wait
		s.stock += 1
	s.at = now # full: the clock starts again from the next use

## Whether a place has anything to give right now (anything that isn't a source does).
func has_stock(spot) -> bool:
	var cfg = SOURCES.get(spot.wild)
	if cfg == null:
		return not spot.wild in ["herd", "copse"] or spot.job.get("count", 0) > 0
	regrow(spot.job, cfg[0], cfg[1], bare_slow, SimClock.now)
	return spot.job.stock > 0

## Takes up to `uses` uses from a spring / fungus patch / salt crust; returns how many it had.
func take(spot, uses: int) -> int:
	var cfg = SOURCES.get(spot.wild) if spot else null
	if cfg == null:
		return 0
	regrow(spot.job, cfg[0], cfg[1], bare_slow, SimClock.now)
	var k: int = mini(uses, spot.job.stock)
	spot.job.stock -= k
	return k

## Fills f's water skins at a spring, as far as it has water. Returns skins filled.
func fill_skins(f, spring) -> int:
	var room: int = maxi(0, carry_skins - f.inv.get("water_skin", 0))
	var got: int = mini(room, take(spring, ceili(room / float(SOURCES.spring[2]))) * SOURCES.spring[2])
	add(f.inv, "water_skin", got)
	return got

## Picks ash caps at a patch, as far as it has any. Returns caps picked.
func pick_caps(f, patch, uses := 2) -> int:
	var got: int = take(patch, uses) * SOURCES.fungus[2]
	add(f.inv, "ash_cap", got)
	return got

var camps: Node
var _t := 0.0
var npc_torch_time := 600.0 # one torch's burn: read off the torch scene in _ready, the same as yours
## Bandits burn pitch-soaked brands: their torches last this many times as long.
@export_range(1.0, 3.0, 0.05) var bandit_torch := 1.3

## How long one of this group's torches burns.
func torch_time(c) -> float:
	return npc_torch_time * (bandit_torch if c.kind == "bandit" else 1.0)
var torch_lights := 4 # and how many times one torch can be lit
var log_lines: Array[String] = [] # shown with the meetings log on the M map
var _nourish := {} # item id -> Vector2(food, water) from its NourishEffect

func _ready() -> void:
	camps = get_parent()
	var t: Node = load("res://items/scenes/torch.tscn").instantiate()
	npc_torch_time = t.burn_time
	torch_lights = t.max_lights
	t.free()

# --- items ------------------------------------------------------------------------------------------------

## What eating / drinking one of these does: Vector2(food, water), read off the item's NourishEffect.
func nourish(id: String) -> Vector2:
	if not _nourish.has(id):
		var v := Vector2.ZERO
		var db = get_node_or_null("/root/item_list")
		var it: Item = db.get_item_instance(id) if db else null
		if it:
			for e in it.get_effects():
				if e is NourishEffect:
					v += Vector2(e.food, e.water)
		_nourish[id] = v
	return _nourish[id]

static func add(d: Dictionary, id: String, n: int) -> void:
	if n == 0:
		return
	d[id] = d.get(id, 0) + n
	if d[id] <= 0:
		d.erase(id)

## Moves up to n of id from one stash to another; returns how many moved.
static func move(from: Dictionary, to: Dictionary, id: String, n: int) -> int:
	var k := mini(n, from.get(id, 0))
	add(from, id, -k)
	add(to, id, k)
	return k

## Food items in d (blackflesh doesn't count: nobody plans on eating it).
func count_food(d: Dictionary) -> int:
	var n := 0
	for id in d:
		if nourish(id).x > 0.0 and id != "blackflesh":
			n += d[id]
	return n

## The item in d that does the most for this need (x = food, y = water), or "". Blackflesh only if starving.
func _best(d: Dictionary, water: bool, starving := false) -> String:
	var best := ""
	var score := 0.0
	for id in d:
		if id == "blackflesh" and not starving:
			continue
		var v := nourish(id)
		var s: float = v.y if water else v.x
		if s > score:
			score = s
			best = id
	return best

## What a character pays for one of these: its value x npc_markup, like you at a trader.
func price(id: String) -> int:
	var db = get_node_or_null("/root/item_list")
	var it: Item = db.get_item_instance(id) if db else null
	return maxi(1, ceili((it.value if it else 1) * npc_markup))

## buyer buys up to n of id out of `from` (a camp's barrel or crate, keeping `floor` back), paying with coin from
## their pack into `till` (the seller's crate). Returns how many they bought.
func buy(buyer, from: Dictionary, till: Dictionary, id: String, n: int, floor: int) -> int:
	var cost := price(id)
	var got := 0
	while got < n and from.get(id, 0) > floor and buyer.inv.get("coin", 0) >= cost:
		move(from, buyer.inv, id, 1)
		move(buyer.inv, till, "coin", cost)
		got += 1
	return got

## Gives a new person their pack, and a camp its barrel and crate (the first time they're seen).
func stock(c) -> void:
	if c.stocked:
		return
	c.stocked = true
	var people: Array = camps._alive(c.members)
	for f in people:
		_pack(f, c.roaming or c.wild != "")
	if c.wild == "" and not c.roaming and c.kind in ["drifter", "bandit"]:
		add(c.barrel, "water_skin", barrel_per_person * maxi(1, people.size()))
		for id in crate_per_person:
			add(c.crate, id, crate_per_person[id] * maxi(1, people.size()))
		for id in goods_start:
			var r: Vector2i = goods_start[id]
			add(c.crate, id, randi_range(r.x, maxi(r.x, r.y)))

func _pack(f, travelling: bool) -> void:
	if f.packed:
		return
	f.packed = true
	for id in pack_start:
		add(f.inv, id, pack_start[id])
	if travelling:
		for id in traveller_extra:
			add(f.inv, id, traveller_extra[id])

## Eat and drink what they have (pack first, then their own camp's stores if they're at the fire).
## Called by minds.gd every time someone thinks.
func self_care(f) -> void:
	var c = f.camp
	_pack(f, c.roaming or c.wild != "")
	var at_fire: bool = c.wild == "" and not c.roaming and camps._dist(f.pos, c.pos) < 30.0
	if f.needs.get("water", 100.0) < drink_below:
		if not _consume(f, f.inv, true, "their pack") and at_fire:
			_consume(f, c.barrel, true, "the camp barrel")
	if f.needs.get("food", 100.0) < eat_below:
		if not _consume(f, f.inv, false, "their pack") and at_fire:
			_consume(f, c.crate, false, "the camp crate")

func _consume(f, d: Dictionary, water: bool, from := "") -> bool:
	var starving: bool = not water and camps.minds and f.needs.get("food", 100.0) < camps.minds.desperate
	var id := _best(d, water, starving)
	if id == "":
		return false
	add(d, id, -1)
	var v := nourish(id)
	f.needs.food = clampf(f.needs.get("food", 0.0) + v.x, 0.0, 100.0)
	f.needs.water = clampf(f.needs.get("water", 0.0) + v.y, 0.0, 100.0)
	if id == "blackflesh": # it keeps them alive, and takes something: the dark sits heavier on them after
		f.needs.light = maxf(0.0, f.needs.get("light", 0.0) - blackflesh_dark)
		f.needs.safety = maxf(0.0, f.needs.get("safety", 0.0) - blackflesh_dark * 0.5)
		if f.traits.has("despair"):
			f.traits.despair = minf(1.0, f.traits.despair + blackflesh_despair)
		camps.note(f, "starving, ate blackflesh. Something of the dark stays in them")
	else:
		camps.note(f, "%s %s from %s" % ["drank" if water else "ate", _name(id), from], false)
	return true

# --- camp chores -------------------------------------------------------------------------------------------

func _process(delta: float) -> void:
	_t += delta
	if _t < plan_every:
		return
	_t = 0.0
	var now: float = SimClock.now
	for c in camps.camps:
		if c.wild == "" and not c.roaming and c.kind in ["drifter", "bandit"]:
			_tend_fire(c, now)
			if c.wild == "": # (its fire may just have died)
				_plan(c, now)
				_duties(c, now)
				if camps.minds:
					camps.minds.share(camps._alive(c.members)) # what they've seen, told round the fire
		if c.rep < 0 and now > c.job.get("rep_heal_at", 0.0): # bad blood fades, slowly
			c.job["rep_heal_at"] = now + rep_heal_every
			c.rep += 1
		if c.job.has("cinder_thief") and c.job.cinder_thief is float and now - c.job.cinder_thief > forgive_after:
			c.job.erase("cinder_thief") # long enough, and they let it go

## Logs' worth of wood on a camp's fire right now (its size).
func fire_logs(c) -> float:
	return clampf(c.job.get("fire_fuel", 0.0) / wood_burn, 0.0, log_cap(c))

## The most logs' worth a fire can be, by who keeps it: the wood alone doesn't make a hearth or a pyre.
func log_cap(c) -> int:
	if ROLES.all(func(r): return has_role(c, r)):
		return max_fire_logs
	return pyre_logs - 1 if has_role(c, "firekeeper") and has_role(c, "storyteller") else hearth_logs - 1

func has_role(c, role: String) -> bool:
	var f = c.job.get("roles", {}).get(role)
	if f is String: # "player": you hold it while you're one of them
		return c.job.get("player_member", false)
	return f != null and not f.dead and f.camp == c

## How many a camp has, you included if you've joined it.
func headcount(c) -> int:
	return camps._alive(c.members).size() + (1 if c.job.get("player_member", false) else 0)

## Fills the camp's roles from its people (keeps who already has one while they're alive and here).
func roles(c) -> Dictionary:
	var r: Dictionary = c.job.get("roles", {})
	for k in r.keys():
		if not has_role(c, k):
			r.erase(k)
	var free: Array = camps._alive(c.members).filter(func(f): return not r.values().has(f))
	for role in ROLES:
		if r.has(role) or free.is_empty():
			continue
		free.sort_custom(func(a, b): return _suits(a, role) < _suits(b, role))
		r[role] = free.pop_back()
		camps.note(r[role], "became the camp's " + role, false)
	c.job["roles"] = r
	return r

func _suits(f, role: String) -> float:
	match role:
		"firekeeper": return f.traits.courage
		"storyteller": return f.traits.piety
		"ashwife": return 1.0 - f.traits.cruelty
	return _fit(f)

## Your role at the camp you've joined, or "".
func player_role(c) -> String:
	for r in c.job.get("roles", {}):
		if c.job.roles[r] is String and c.job.get("player_member", false):
			return r
	return ""

## A role you hold is work you owe: the firekeeper and storyteller have to be at the fire, the others bring in what
## their role is for (credit()). Let it go long enough and they give the role to someone who'll do it.
func _duties(c, now: float) -> void:
	var r := player_role(c)
	if r == "":
		return
	var p: Node3D = camps._player
	if r in ["firekeeper", "storyteller"] and p and camps._dist(p.global_position, c.pos) < 30.0:
		c.job["duty_at"] = now
	if now - c.job.get("duty_at", now) > duty_time:
		c.job.roles.erase(r)
		c.job.erase("duty_at")
		if camps.minds:
			camps.minds.rep(c, -5)
		Talker.notify("The %s gave your place as %s to someone who'd do it." % [fire_name(c).to_lower(), r])

## You put something in your camp's stores: if it's what your role is for, that's your work done.
func credit(c, id: String) -> void:
	var r := player_role(c)
	var ok: bool = {"drawer": id in ["ash_wood", "resin", "kindling", "tinder"], "waterbearer": id == "water_skin",
		"wickbearer": id == "torch", "ashwife": nourish(id).x > 0.0 or id == "health_potion"}.get(r, false)
	if ok:
		c.job["duty_at"] = SimClock.now

## The idle one holding this role if there is one, else the fittest idle.
func _pick(idle: Array, c, role: String):
	var f = c.job.get("roles", {}).get(role)
	if f != null and idle.has(f):
		idle.erase(f)
		return f
	return idle.pop_back()

## How many people the fire keeps (light and warmth for).
func capacity(c) -> int:
	return people_per_log * maxi(1, ceili(fire_logs(c)))

## How big it burns against a one-log fire: its light reaches this many times as far.
## A cold fire still has embers in it (see ember_burn).
func embers(c) -> bool:
	var out: float = c.job.get("out_at", -INF)
	return SimClock.now - out < ember_time and out - c.job.get("lit_at", -INF) >= ember_burn

## Whether a fire being lit catches this go.
func catches(c) -> bool:
	return embers(c) or randf() < light_chance * (lerpf(1.0, storm_light, camps.enc._storm) if camps.enc else 1.0)

func fire_tier(c) -> String:
	var l: float = fire_logs(c)
	return "pyre" if l >= pyre_logs else "hearth" if l >= hearth_logs else "bonfire"

## A camp's fire by name: its people's kind and its tier ("Drifter hearth").
func fire_name(c) -> String:
	return "%s %s" % [c.kind.capitalize(), fire_tier(c)]

func fire_scale(c) -> float:
	return 0.7 + 0.15 * maxf(1.0, fire_logs(c))

## A camp's fire burns down; whoever's at the fire puts a log on from the crate when it's low. No wood left, it
## dies (Camps.fire_out: a cold fire, and its people set out to find another).
func _tend_fire(c, now: float) -> void:
	var j: Dictionary = c.job
	if not j.has("fire_fuel"):
		stock(c)
		j["fire_fuel"] = maxf(randf_range(fire_start.x, fire_start.y), wood_burn * ceili(float(camps._alive(c.members).size()) / people_per_log)) # big enough for who's there
		j["fire_at"] = now
	j.fire_fuel -= (now - j.get("fire_at", now)) * (lerpf(1.0, storm_fire_burn, camps.enc._storm) if camps.enc else 1.0)
	j.fire_at = now
	var tending: bool = camps._alive(c.members).any(func(f): return camps._dist(f.pos, c.pos) < 30.0)
	var n: int = maxi(1, camps._alive(c.members).size())
	var want: float = fire_feed_below # nobody keeping it: it's fed when it's low, no more
	if has_role(c, "firekeeper"):
		want = maxf(want, wood_burn * clampi(ceili(float(n) / people_per_log) + keeper_spare, 1, log_cap(c))) # big enough for all of them, and room to grow
	while tending and j.fire_fuel < want and c.crate.get("ash_wood", 0) > 0:
		add(c.crate, "ash_wood", -1)
		j.fire_fuel += wood_burn
	var owned: int = c.crate.get("torch", 0) + camps._alive(c.members).reduce(func(t, f): return t + f.inv.get("torch", 0), 0)
	if tending and owned < torches_low * n and c.crate.get("ash_wood", 0) > 0 and c.crate.get("resin", 0) >= sap_per_log: # torches from a log and sap, for the road
		add(c.crate, "ash_wood", -1)
		add(c.crate, "resin", -sap_per_log)
		add(c.crate, "torch", torches_per_log if has_role(c, "wickbearer") else 1) # a wickbearer gets the most out of a log
	if j.fire_fuel <= 0.0:
		camps.fire_out(c, now)

func _plan(c, now: float) -> void:
	var people: Array = camps._alive(c.members)
	if people.is_empty():
		return
	stock(c)
	var n := people.size()
	roles(c)
	var idle := people.filter(func(f): return f.task.is_empty() and c.job.roles.get("firekeeper") != f and not (camps.minds and camps.minds.state(f, "shaken"))) # the firekeeper never leaves the fire; the shaken won't go out
	idle.sort_custom(func(a, b): return _fit(a) < _fit(b)) # pop_back() sends the fittest out first
	var water: int = c.barrel.get("water_skin", 0)
	var food: int = count_food(c.crate)
	var busy := n - idle.size()
	# Nothing to eat or drink and nobody out getting any, or no water left and no spring to fetch it from: pack up and go.
	var dry: bool = water < n and _nearest(c.pos, "spring", spring_range) == null
	if (dry or water == 0 and food == 0) and busy == 0 and people.all(func(f): return count_food(f.inv) == 0 or dry):
		var to = _best_camp(c, minf(evacuate_range, camps._reach()))
		if to:
			for f in people:
				_give(f, {"type": "evacuate", "dest": to, "to": to.pos, "phase": "out"})
			_log("A %s gave up and left for another fire" % fire_name(c))
			return
	if idle.is_empty():
		return
	var unknown := false # something's short and nobody remembers where to get it
	if water < water_low * n and not people.any(func(p): return p.task.get("type", "") == "water"):
		var k := _recall(c, "spring", spring_range)
		if not k.is_empty():
			_give(_pick(idle, c, "waterbearer"), {"type": "water", "to": camps._ground(k[1]), "phase": "out", "spot": k[0]})
		else:
			unknown = true
	var out := people.filter(func(f): return f.task.get("type", "") == "forage").size()
	if not idle.is_empty() and food < food_low * n and out < maxi(1, int(n * forager_share)):
		var k := _recall(c, "fungus", forage_range)
		if k.is_empty():
			k = _recall(c, "herd", hunt_range)
		if not k.is_empty(): # nothing they know to pick and no game they know of: nobody goes
			var patch = k[0] if k[0].wild == "fungus" else null
			_give(idle.pop_back(), {"type": "forage", "to": camps._ground(k[1]), "phase": "out", "spot": patch, "herd": null if patch else k[0]})
		else:
			unknown = true
	var cutters: int = people.filter(func(p): return p.task.get("type", "") == "wood").size()
	if not idle.is_empty() and c.crate.get("ash_wood", 0) < wood_low * n and cutters < (2 if c.crate.get("ash_wood", 0) < n else 1): # very low: two go
		var k := _recall(c, "copse", copse_range)
		if not k.is_empty():
			_give(_pick(idle, c, "drawer"), {"type": "wood", "to": camps._ground(k[1]), "phase": "out", "spot": k[0]})
		else:
			unknown = true
	if not idle.is_empty() and c.crate.get("resin", 0) < sap_low and not people.any(func(p): return p.task.get("type", "") == "sap"):
		var k := _recall(c, "sap", copse_range)
		if not k.is_empty():
			_give(_pick(idle, c, "drawer"), {"type": "sap", "to": camps._ground(k[1]), "phase": "out", "spot": k[0]})
		else:
			unknown = true
	if unknown and not idle.is_empty() and not people.any(func(p): return p.task.get("type", "") == "explore"):
		var a := randf() * TAU # they need something nobody knows where to find: someone goes looking
		var to: Vector3 = camps._ground(c.pos + Vector3(cos(a), 0, sin(a)) * randf_range(explore_range * 0.4, explore_range))
		if not is_nan(to.y):
			idle.sort_custom(func(x, y): return camps.minds._t(x, "curiosity") < camps.minds._t(y, "curiosity"))
			_give(idle.pop_back(), {"type": "explore", "to": to, "phase": "out"}) # the most curious goes
	var coin: int = c.crate.get("coin", 0)
	if not idle.is_empty() and coin > 0 and not people.any(func(p): return p.task.get("type", "") == "trade"):
		var want := "water" if water < water_low * n else ("food" if food < food_low * n else "")
		var seller = _seller(c, want) if want != "" else null
		if seller:
			var f = idle.pop_back()
			move(c.crate, f.inv, "coin", mini(coin, trade_purse))
			_give(f, {"type": "trade", "dest": seller, "to": seller.pos, "phase": "out", "want": want})
	if not idle.is_empty() and c.kind == "drifter" and food > surplus * n:
		var hungry = _needy_camp(c)
		if hungry:
			idle.sort_custom(func(x, y): return camps.minds._t(x, "kindness") < camps.minds._t(y, "kindness"))
			var f = idle.pop_back() # the kindest carries it
			for id in c.crate.keys():
				if count_food(f.inv) >= carry_food * 2:
					break
				if nourish(id).x > 0.0:
					move(c.crate, f.inv, id, carry_food * 2 - count_food(f.inv))
			_give(f, {"type": "supply", "dest": hungry, "to": hungry.pos, "phase": "out"})
			_log("A drifter camp sent food to a hungry neighbour")

## The nearest place of this kind the camp's people remember (with something in it): [place, where they think], or [].
func _recall(c, wild: String, r: float) -> Array:
	return camps.minds.recall(camps._alive(c.members), wild, c.pos, r, has_stock) if camps.minds else []

## How fit someone is to go out: their lowest of food and water.
func _fit(f) -> float:
	return minf(f.needs.get("food", 100.0), f.needs.get("water", 100.0))

func _give(f, task: Dictionary) -> void:
	task["since"] = SimClock.now
	# They take torches for the trip there and back (their own, then the camp's), light the first at the fire and
	# each next from the last as it gutters, as you would. Every lighting wears the torches down like yours: one is
	# spent for every torch_lights lightings (the camp's wear count). No torches: they don't go.
	var trip: float = camps._dist(f.pos, task.to) * 2.0 / camps.walk_speed + gather_time.y
	var c = f.camp
	var need: int = ceili(trip * 1.2 / torch_time(c))
	var carry: int = mini(need, 2) # two in hand is enough to keep lighting one from the other
	move(c.crate, f.inv, "torch", maxi(0, carry - f.inv.get("torch", 0)))
	var lights: int = need if f.inv.get("torch", 0) >= mini(need, 2) else f.inv.get("torch", 0)
	if lights == 0 and task.type != "evacuate":
		return
	c.job["torch_wear"] = c.job.get("torch_wear", 0) + lights
	while c.job.torch_wear >= torch_lights and f.inv.get("torch", 0) > 0:
		c.job.torch_wear -= torch_lights
		if c.crate.get("resin", 0) > 0:
			add(c.crate, "resin", -1) # sap worked into the wick instead
		else:
			add(f.inv, "torch", -1) # burnt down to a stub
	task["lit_until"] = SimClock.now + lights * torch_time(c)
	f.task = task
	camps._send(f, task.to)
	var where := "%.0f m away" % camps._dist(f.pos, task.to)
	camps.note(f, {"water": "set off to fetch water from a spring " + where,
		"forage": ("set off to pick ash fungus " if task.get("spot") else "set off to hunt in the dark ") + where,
		"supply": "set off carrying food to a hungry camp " + where,
		"evacuate": "packed up and left for another camp " + where,
		"trade": "set off with the camp's coin to buy from a neighbouring camp " + where,
		"wood": "set off to cut wood at a copse " + where, "sap": "set off to cut sap from a giant tree " + where,
		"explore": "set off into the dark to look for what the camp needs " + where}.get(task.type, task.type))

## Moves a person's chore along. Called for every person on one as the Camps sweep reaches them (loaded or not).
func step(f, now: float) -> void:
	var t: Dictionary = f.task
	var c = f.camp
	if c.wild != "" or c.roaming: # they've become something else (wanderer, mourner...): drop the chore
		f.task = {}
		return
	if now - t.since > 1200.0 and t.phase != "back": # couldn't get there: come home
		_home(f, c)
		return
	var herd = t.get("herd")
	var sight: float = camps.minds.sight_range if camps.minds else 40.0
	if t.phase in ["out", "work"] and herd and herd in camps.camps and camps._dist(f.pos, herd.pos) < sight * 2.0 and camps._dist(t.to, herd.pos) > 20.0: # game in sight moves: follow it
		t.to = herd.pos
		camps._send(f, herd.pos)
	var spot = t.get("spot")
	if t.phase == "out" and spot and camps._dist(f.pos, spot.pos) < sight and camps._dist(t.to, spot.pos) > 4.0: # there it is
		if camps.minds:
			camps.minds.learn(f, spot, true)
		t.to = camps._ground(spot.pos)
		camps._send(f, t.to)
	var d: float = camps._dist(f.pos, t.to)
	match t.phase:
		"out":
			if d < 8.0:
				var aim = spot if spot else t.get("herd")
				if t.type in ["forage", "water", "wood", "sap"] and aim and camps._dist(f.pos, aim.pos) > sight: # not where they remembered
					t["searched"] = t.get("searched", 0) + 1
					if t.searched > search_tries or not aim in camps.camps:
						if camps.minds:
							camps.minds.forget([f], aim)
						camps.note(f, "couldn't find it where they remembered, and gave up")
						_home(f, c)
					else:
						var a := randf() * TAU
						t.to = camps._ground(t.to + Vector3(cos(a), 0, sin(a)) * search_radius)
						camps._send(f, t.to)
					return
				match t.type:
					"explore":
						if camps.minds:
							camps.minds.look(f)
						camps.note(f, "looked around in the dark and turned for home")
						_home(f, c)
					"forage", "water", "wood", "sap":
						t.phase = "work"
						t["until"] = now + randf_range(gather_time.x, gather_time.y)
						camps.note(f, {"water": "filling skins at the spring", "wood": "cutting a small tree", "sap": "cutting sap out of the bark"}.get(t.type, "picking fungus" if t.get("spot") else "hunting"))
					"trade": # buy what their camp needs with the coin they brought; the coin stays with the seller
						var dest = t.dest
						var m: int = maxi(1, camps._alive(dest.members).size())
						var got := 0
						if t.want == "water":
							got = buy(f, dest.barrel, dest.crate, "water_skin", carry_skins, sell_floor * m)
						else:
							for k in carry_food * 2:
								var id := _best(dest.crate, false)
								if id == "" or buy(f, dest.crate, dest.crate, id, 1, sell_floor * m) == 0:
									break
								got += 1
						camps.note(f, "bought %d %s from a neighbouring camp" % [got, "water skins" if t.want == "water" else "food"])
						if got > 0:
							_log("A camp bought %s from a neighbour" % t.want)
						_home(f, c)
					"supply":
						for id in f.inv.keys():
							if nourish(id).x > 0.0:
								move(f.inv, t.dest.crate, id, f.inv[id] - (1 if id == _best(f.inv, false) else 0)) # keep one for the road
						camps.note(f, "handed food over to the hungry camp")
						_home(f, c)
					"evacuate":
						var dest = t.dest
						c.members.erase(f)
						dest.members.append(f)
						f.camp = dest
						for id in f.inv.keys(): # what they carried goes into the new camp's stores
							if id == "water_skin":
								move(f.inv, dest.barrel, id, f.inv[id] - 1)
							elif nourish(id).x > 0.0:
								move(f.inv, dest.crate, id, f.inv[id] - 1)
						f.task = {}
						camps._send(f, dest.pos)
						camps.note(f, "joined a new camp")
		"work":
			if now > t.until:
				var got := 0
				if t.type == "water":
					got = fill_skins(f, t.spot)
				elif t.type == "wood":
					got = chop(f, t.spot)
				elif t.type == "sap":
					got = take(t.spot, sap_per_trip) # shortcut: an NPC needs no knife for it
					add(f.inv, "resin", got)
				elif t.get("spot"):
					got = pick_caps(f, t.spot, randi_range(1, 2))
				else:
					got = hunt(f, t.get("herd"))
				if got == 0:
					camps.note(f, {"water": "found the spring dry", "forage": "found nothing to take", "wood": "found the copse cut bare", "sap": "found the sap cut dry"}.get(t.type, "came away with nothing"))
				camps.note(f, "heading home with %s" % (_pack_text(f.inv) if not f.inv.is_empty() else "nothing"))
				_home(f, c)
		"back":
			if camps._dist(f.pos, c.pos) < 10.0:
				camps.note(f, "back at camp, stowing what they brought")
				for id in f.inv.keys(): # unload into the stores, keeping one of each for themselves
					if id == "water_skin":
						move(f.inv, c.barrel, id, f.inv[id] - 1)
					elif nourish(id).x > 0.0:
						move(f.inv, c.crate, id, f.inv[id] - 1)
					elif id in ["ash_wood", "torch", "tinder", "kindling", "resin"]:
						move(f.inv, c.crate, id, f.inv[id]) # wood for the fire; torches back in the crate
					elif id == "coin" and t.type == "trade":
						move(f.inv, c.crate, id, f.inv[id]) # the change goes back in the crate
				f.task = {}
				camps._send(f, c.pos)

## Cuts down one of a copse's small trees (if any are left standing): ash wood into f's pack, more with a
## hatchet. Returns wood taken.
func chop(f, copse) -> int:
	var wood := 0
	while copse and copse in camps.camps and copse.job.get("count", 0) > 0 and wood < wood_carry: # as many as they can carry home
		copse.job.count -= 1
		wood += wood_per_tree + (axe_bonus if f.inv.get("hatchet", 0) > 0 else 0) # shortcut: an NPC's hatchet doesn't wear yet
	add(f.inv, "ash_wood", wood)
	add(f.inv, "kindling", wood / wood_per_tree * kindling_per_tree)
	add(f.inv, "tinder", wood / wood_per_tree * tinder_per_tree)
	return wood

## Kills from a herd (if it's still about) into f's pack as raw meat. Returns meat taken.
func hunt(f, herd) -> int:
	if herd == null or not herd in camps.camps or camps._dist(herd.pos, f.pos) > 250.0:
		return 0
	var kills: int = mini(herd.job.get("count", 0), randi_range(hunt_kills.x, maxi(hunt_kills.x, hunt_kills.y)))
	herd.job.count -= kills
	add(f.inv, "raw_meat", kills * meat_per_kill)
	return kills * meat_per_kill

func _home(f, c) -> void:
	f.task.phase = "back"
	f.task.to = c.pos
	camps._send(f, c.pos)

## Nearest place of this kind within r. Springs / fungus / salt that are picked bare don't count, and nor do herds.
func _nearest(pos: Vector3, wild: String, r: float):
	var best = null
	for c in camps.camps:
		if c.wild == wild and camps._dist(c.pos, pos) < r and (best == null or camps._dist(c.pos, pos) < camps._dist(best.pos, pos)) and has_stock(c):
			best = c
	return best

## The nearest camp of c's kind, within a torch's reach, with plenty of what's wanted to sell. null if none.
func _seller(c, want: String):
	var best = null
	for o in camps.camps:
		if o == c or o.wild != "" or o.roaming or o.kind != c.kind or camps._dist(o.pos, c.pos) > aid_range: # a chore: they carry torches for the trip
			continue
		var m: int = maxi(1, camps._alive(o.members).size())
		var has: int = o.barrel.get("water_skin", 0) if want == "water" else count_food(o.crate)
		if o.stocked and has > ((water_low if want == "water" else food_low) + sell_floor) * m and (best == null or camps._dist(o.pos, c.pos) < camps._dist(best.pos, c.pos)):
			best = o
	return best

## The best-stocked drifter camp in range (for evacuating to).
func _best_camp(from, r: float):
	var best = null
	var best_score := -INF
	for c in camps.camps:
		if c == from or c.wild != "" or c.roaming or c.kind != "drifter" or camps._dist(c.pos, from.pos) > r:
			continue
		stock(c)
		var score: float = float(c.barrel.get("water_skin", 0) + count_food(c.crate)) / maxi(1, camps._alive(c.members).size()) - camps._dist(c.pos, from.pos) * 0.002
		if score > best_score:
			best_score = score
			best = c
	return best

func _needy_camp(from):
	for c in camps.camps:
		if c != from and c.wild == "" and not c.roaming and c.kind == "drifter" and camps._dist(c.pos, from.pos) < aid_range:
			stock(c)
			var n: int = camps._alive(c.members).size()
			if n > 0 and count_food(c.crate) < needy * n:
				return c
	return null

## An item's name for the logs.
func _name(id: String) -> String:
	var db = get_node_or_null("/root/item_list")
	var it: Item = db.get_item_instance(id) if db else null
	return it.Name.to_lower() if it else id

func _pack_text(d: Dictionary) -> String:
	return ", ".join(d.keys().map(func(k): return "%d %s" % [d[k], _name(k)]))

func _log(line: String) -> void:
	log_lines.append(line)
	if log_lines.size() > 4:
		log_lines.pop_front()

# --- travellers ------------------------------------------------------------------------------------------------

## Called from the Camps band tick for roaming human groups. True = this function set where they're going.
func steer(b, now: float) -> bool:
	if b.kind != "drifter" and b.kind != "bandit":
		return false
	var alive: Array = camps._alive(b.members)
	if alive.is_empty():
		return false
	var j: Dictionary = b.job
	if now < j.get("rest_until", 0.0): # resting at a fire: they sit a while, torch snuffed, before going on
		if not j.get("dark", false):
			j.fuel = maxf(j.fuel, torch_time(b))
		return true
	tend_torch(b, alive, now)
	if camps.minds and now > j.get("told_at", 0.0):
		j["told_at"] = now + 30.0
		camps.minds.share(alive) # on the road they tell each other what they've seen
	var lead = alive[0]
	var goal = j.get("goal")
	var sight: float = camps.minds.sight_range if camps.minds else 40.0
	if goal:
		if camps._dist(lead.pos, goal.pos) < sight and camps._dist(j.get("goal_at", goal.pos), goal.pos) > 5.0: # there it is
			j["goal_at"] = goal.pos
			b.pos = goal.pos
			for f in alive:
				camps._send(f, goal.pos)
		elif camps._dist(lead.pos, j.get("goal_at", goal.pos)) < 8.0 and camps._dist(lead.pos, goal.pos) >= 10.0: # not where they remembered
			if camps.minds:
				camps.minds.forget(alive, goal)
			camps.note(lead, "found nothing where they remembered it")
			j.erase("goal")
			return false
		if camps._dist(lead.pos, goal.pos) < 10.0:
			_arrive(b, alive, goal)
			j.erase("goal")
			j["last"] = goal
			j["last_at"] = now
			return false
		if now - j.get("goal_since", now) > 600.0:
			j.erase("goal")
		return true
	var skins := 0
	var food := 0
	for f in alive:
		skins += f.inv.get("water_skin", 0)
		food += count_food(f.inv)
	var thirsty: float = _avg(alive, "water")
	var target = null
	var aim := {} # where they think it is
	var known := func(wild: String, r: float):
		var k: Array = camps.minds.recall(alive, wild, lead.pos, r, has_stock) if camps.minds else []
		if k.is_empty():
			return null
		aim["at"] = k[1]
		return k[0]
	var lit_reach: float = j.fuel * camps.walk_speed * 0.45 # out there and back to a fire before the torch dies
	if skins == 0 and thirsty < drink_below * 0.5:
		target = known.call("spring", minf(seek_range * 1.5, lit_reach)) # dying of thirst beats everything
	if target == null and j.fuel < torch_time(b) * 0.35: # light running low (or out): a fire to light it at
		target = _fire_for(b, lead.pos)
	if target == null and skins < alive.size():
		target = known.call("spring", minf(seek_range, lit_reach))
	if target == null and food < alive.size():
		target = known.call("fungus", minf(seek_range, lit_reach))
		if target == null:
			target = _fire_for(b, lead.pos, true) # a camp might spare something (a cairn won't)
	if target != null and target == j.get("last") and now - j.get("last_at", -INF) < 300.0:
		target = null # just been there: don't pace back and forth over the same spot
	if target == null:
		return false
	j["goal"] = target
	j["goal_since"] = now
	var to: Vector3 = aim.get("at", target.pos) if target.wild in ["spring", "fungus"] else target.pos # fires they see from afar
	j["goal_at"] = to
	b.pos = to
	for f in alive:
		camps._send(f, to)
	camps.note(lead, "heading for %s %.0f m away" % [{"spring": "a spring", "fungus": "ash fungus", "cairn": "a cairn's light"}.get(target.wild, "a " + fire_name(target).to_lower()), camps._dist(lead.pos, target.pos)])
	return true

## A group on the move burns its torch (one at a time, like yours: lit only at a fire, relit up to torch_lights
## times, then it's a stub and gone). A group setting out from a fire lights one there if anyone has a torch.
## Called every band tick, whatever else they're doing.
func tend_torch(b, alive: Array, now: float) -> void:
	stock(b)
	for f in alive:
		_pack(f, true)
	var j: Dictionary = b.job
	if not j.has("fuel"):
		j["fuel"] = 0.0
		j["burnt_at"] = now
		var src = b.from if b.from else b.den
		if src and src.wild == "" and camps._dist(alive[0].pos, src.pos) < 30.0:
			for f in alive: # what they take for the road, out of the camp's stores
				for id in road_share:
					move(src.barrel if id == "water_skin" else src.crate, f.inv, id, road_share[id])
			if not alive.any(func(f): return f.inv.get("torch", 0) > 0):
				move(src.crate, alive[0].inv, "torch", road_torches)
			if alive.any(func(f): return f.inv.get("torch", 0) > 0):
				j.fuel = torch_time(b) # lit from the fire they're leaving
				j["lights"] = 1
	var burn: float = lerpf(1.0, camps.enc.storm_burn, camps.enc._storm) if camps.enc else 1.0 # an ash storm eats torches, theirs as well as yours
	j.fuel = maxf(0.0, j.fuel - (now - j.burnt_at) * burn)
	j.burnt_at = now
	if j.fuel <= 0.0 and alive.reduce(func(a, f): return a + f.inv.get("torch", 0), 0) >= 2: # light the next from the last of the flame, as you do
		j.fuel = torch_time(b)
		j["lights"] = j.get("lights", 0) + 1 # one more lighting on their torches
		j["dark"] = false
	if j.fuel <= 0.0 and not j.get("dark", false): # the torch is out; like yours it only lights again at a fire
		j["dark"] = true
		if j.get("lights", 0) >= torch_lights: # burnt to a stub
			for f in alive:
				if f.inv.get("torch", 0) > 0:
					add(f.inv, "torch", -1)
					break
			j["lights"] = 0
		camps.note(alive[0], "their torch has gone out")
	_show_torch(alive, j.fuel > 0.0)

## Like you would, a group turns for the nearest fire (their own kind's camp, or a cairn) while their light can
## still get them there. True = that's where they're going now.
func need_light(b, alive: Array, now: float) -> bool:
	var j: Dictionary = b.job
	var goal = j.get("goal")
	if goal and goal.wild in ["", "cairn"]:
		return steer(b, now) # already on the way to a fire: walk it, light up on arrival
	if j.get("settle_at") in camps.camps:
		return false # already walking to the fire they'll live at
	var torchless: bool = not alive.any(func(f): return f.inv.get("torch", 0) > 0)
	var fire = _fire_for(b, alive[0].pos, torchless) # no torch to light: a cairn's no use, only a camp
	if fire == null:
		return false
	var d: float = camps._dist(alive[0].pos, fire.pos)
	if j.get("fuel", 0.0) > d / camps.walk_speed * 1.3 + 60.0:
		return false
	j["goal"] = fire
	j["goal_since"] = now
	b.pos = fire.pos
	for f in alive:
		camps._send(f, fire.pos)
	camps.note(alive[0], "turned for the light of a fire %.0f m away before their torch gives out" % d)
	return true

func _avg(people: Array, need: String) -> float:
	var s := 0.0
	for f in people:
		s += f.needs.get(need, 100.0)
	return s / maxi(1, people.size())

## The nearest lit fire this group would go to: a camp of their own kind, or (unless camps_only) a cairn torch.
func _fire_for(b, pos: Vector3, camps_only := false):
	var best = null
	for c in camps.camps:
		var ok: bool = (c.wild == "cairn" and not camps_only) or (c.wild == "" and not c.roaming and c.kind == b.kind and not camps._alive(c.members).is_empty())
		if ok and camps._dist(c.pos, pos) < camps.fire_radius and (best == null or camps._dist(c.pos, pos) < camps._dist(best.pos, pos)):
			best = c
	return best

func _arrive(b, alive: Array, at) -> void:
	var j: Dictionary = b.job
	if at.wild in ["", "cairn"]:
		j["rest_until"] = SimClock.now + randf_range(rest_time.x, rest_time.y)
	camps.note(alive[0], {"spring": "filled skins at the spring", "fungus": "picked ash caps", "cairn": "came to a cairn's light"}.get(at.wild, "rested at a " + fire_name(at).to_lower()))
	match at.wild:
		"spring":
			for f in alive:
				if take(at, 1) > 0: # a drink each, then skins, while it lasts
					f.needs.water = 100.0
				fill_skins(f, at)
		"fungus":
			for f in alive:
				pick_caps(f, at, randi_range(1, 2))
		"cairn", "":
			if at.wild == "" and not alive.any(func(f): return f.inv.get("torch", 0) > 0):
				move(at.crate, alive[0].inv, "torch", 1) # a camp of their own kind spares a torch, if it has one
			if alive.any(func(f): return f.inv.get("torch", 0) > 0): # lit at the fire, like yours (no torch, no light)
				j.fuel = torch_time(b)
				j["lights"] = j.get("lights", 0) + 1
				j["dark"] = false
			if at.wild == "": # a camp of their own kind spares what it can
				stock(at)
				var n: int = maxi(1, camps._alive(at.members).size())
				for f in alive:
					f.needs.light = 100.0
					if at.barrel.get("water_skin", 0) > gift_floor * n:
						move(at.barrel, f.inv, "water_skin", gift)
					for k in gift:
						if count_food(at.crate) > gift_floor * n:
							var id := _best(at.crate, false)
							move(at.crate, f.inv, id, 1)
				_log("Travellers rested at a " + fire_name(at).to_lower())
				var bought := 0 # what they're still short of, they buy, as you would
				for f in alive:
					if f.inv.get("water_skin", 0) < 1:
						bought += buy(f, at.barrel, at.crate, "water_skin", 1, sell_floor * n)
					if count_food(f.inv) < 1:
						var id := _best(at.crate, false)
						if id != "":
							bought += buy(f, at.crate, at.crate, id, 1, sell_floor * n)
				if not alive.any(func(f): return f.inv.get("torch", 0) > 0):
					for f in alive:
						if buy(f, at.crate, at.crate, "torch", 1, 0) > 0:
							bought += 1
							break
				if bought > 0:
					camps.note(alive[0], "bought %d thing%s at the fire" % [bought, "" if bought == 1 else "s"])
					_log("Travellers traded at a " + fire_name(at).to_lower())

## The group's lead carries the torch when they're near you (lit or not, as the group's fuel says).
func _show_torch(alive: Array, lit: bool) -> void:
	var lead = alive[0]
	if not is_instance_valid(lead.node):
		return
	var vis: Node = lead.node.get_node_or_null("visual")
	if not vis:
		return
	var torch: Node3D = vis.get_node_or_null("road_torch")
	if not torch:
		torch = load("res://items/scenes/torch.tscn").instantiate()
		torch.name = "road_torch"
		torch.position = Vector3(-0.7, 1.4, -0.3)
		torch.collision_layer = 0 # carried: nothing to bump into or pick up
		torch.collision_mask = 0
		var pickup := torch.get_node_or_null("InteractableComponent")
		if pickup:
			pickup.free()
		vis.add_child(torch)
	for part_name in ["fire_effect", "firelight"]:
		var part := torch.get_node_or_null(part_name) as Node3D
		if part:
			part.visible = lit
