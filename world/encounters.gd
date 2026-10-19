extends Node
## The bleak encounters, kept out of camps.gd. The Camps node owns this (child "encounters"), rolls the
## encounters onto its grid and hands each tick / spawn / talk to the functions here. All the knobs are below.
##
##   hanged     a body hanging from a gibbet, its pack at its feet. Empty the pack and, now and then, something follows.
##   coldfire   a dead camp: cold fire, bodies around it. Bring a lit torch to relight it: it becomes a camp
##              (drifters can settle it) and your respawn point.
##   mourner    kneels at a grave, won't speak. Leave food: a rumour. Hurt them: your torches burn faster for a while.
##   pilgrims   a silent line of hooded walkers heading for the nearest bell shrine. Speak to one: they all turn.
##   falselight looks like a cairn torch. Get close and it goes out, and something is standing where it was.
##   starved    too weak to stand, begs for food. Feed them for coin; walk on and they're dead when you come back.
##   toll       a bandit with a torch on the road wants coin. Pay and pass. Don't, and his friends come out of the dark.
##   bell       a sunken shrine in the low wet ground; you hear its bell from far off. A key waits on the altar.
## Plus the ash storm: every so often the ash thickens and darkens, torches burn faster and goblins hunt you.

@export_group("Hanged")
## Empty the hanged one's pack and goblins come after you: this many, from the nearest goblins within hunt_range.
@export var stalkers := Vector2i(2, 3)
## Chance that emptying the pack brings them at all (you or anyone).
@export_range(0.0, 1.0, 0.01) var hanged_hunt_chance := 0.15
@export_range(100.0, 5000.0, 50.0, "suffix:m") var hunt_range := 1200.0
## How long hunters track you before they lose interest and go back to their den.
@export_range(10.0, 3600.0, 5.0, "suffix:s") var stalk_time := 600.0
@export var watched_line := "You feel watched."

@export_group("Cold fire")
@export_range(1.0, 10.0, 0.5, "suffix:m") var relight_distance := 5.0
@export var relit_line := "The fire takes. You can rest here."

@export_group("Mourner")
@export_range(0.0, 1200.0, 10.0, "suffix:s") var curse_time := 300.0
## Torches burn this many times faster while cursed.
@export_range(1.0, 5.0, 0.1) var curse_burn := 2.0
@export var mourner_lines: PackedStringArray = ["She was all I had left to bury.", "The marsh keeps what it takes. Listen for the bell.", "Don't walk the dunes at night. The sand remembers feet."]
@export var curse_line := "A curse settles on you. Your flames gutter."

@export_group("Pilgrims")
## Fraction of normal walking speed: they shuffle.
@export_range(0.1, 1.0, 0.05) var pilgrim_pace := 0.5
## Pilgrims this close to the bell have arrived: they ring it and go looking for a fire to settle at.
@export_range(5.0, 200.0, 5.0, "suffix:m") var pilgrim_arrive := 30.0
@export var pilgrims_turn_line := "They all turn to look at you."

@export_group("False light")
@export_range(1.0, 20.0, 0.5, "suffix:m") var trap_distance := 7.0
@export var false_light_line := "The light goes out. Something was holding it."

@export_group("Starved")
@export_range(0, 200) var starved_reward := 15
@export var starved_beg := "Please. Anything. I haven't eaten since the ash came."
@export var starved_thanks := "Bless you. Take this, it's all I have."

@export_group("Toll")
@export_range(0, 200) var toll_cost := 20
@export var toll_demand := "%d coin, and you walk on."
@export var toll_paid := "Go on, then. Quickly."
@export var toll_refused := "Then you don't walk on."
## Get this close without paying and it's a fight.
@export_range(1.0, 10.0, 0.5, "suffix:m") var toll_too_close := 3.0

@export_group("Bell")
@export_range(0, 5) var bell_shrines := 2
## You hear the bell from this far.
@export_range(50.0, 2000.0, 10.0, "suffix:m") var bell_range := 700.0
@export_range(2.0, 60.0, 1.0, "suffix:s") var bell_every := 12.0

@export_group("Ash storm")
## Seconds between storms (random in range) and how long one lasts.
@export var storm_every := Vector2(300, 700)
@export var storm_length := Vector2(60, 150)
## Fog this many times thicker, and the light this much dimmer, at the storm's height.
@export_range(1.0, 20.0, 0.5) var storm_fog := 5.0
@export_range(0.0, 1.0, 0.05) var storm_light := 0.35
## Torches burn this many times faster in a storm.
@export_range(1.0, 5.0, 0.1) var storm_burn := 2.0
## Goblins that come hunting you in each storm.
@export var storm_hunters := Vector2i(2, 4)
@export var storm_start_line := "The ash thickens and the light dies. Your torch gutters."
@export var storm_end_line := "The ash settles."

var camps: Node # the Camps node
var _next_storm := 0.0
var _storm_end := 0.0
var _storm := 0.0 # 0..1 how far in the storm is
var _storming := false
var _env: Environment
var _base_fog := 0.0
var _base_fog_color: Color
var _sun: DirectionalLight3D
var _base_sun := 0.0
var _ash: GPUParticles3D

const SPOTS := ["hanged", "coldfire", "falselight", "bell", "starved_dead", "spring", "fungus", "salt"]

func _ready() -> void:
	camps = get_parent()
	_next_storm = randf_range(storm_every.x, storm_every.y)

# --- generation ------------------------------------------------------------

@export_group("Salt")
## Salt-crusted rocks along the shore (the only place to get salt, for curing hides).
@export_range(0, 200) var salt_spots := 30

## Salt crusts go right at the waterline, all round the island.
func make_salt(rng: RandomNumberGenerator) -> void:
	var made := 0
	for attempt in 3000:
		if made >= salt_spots:
			return
		var p: Vector3 = camps._ground(Vector3(rng.randf_range(-5000, 5000), 0, rng.randf_range(-5000, 5000)))
		if is_nan(p.y) or p.y < camps.SEA_LEVEL + 0.2 or p.y > camps.SEA_LEVEL + 2.0:
			continue
		var c = camps.new_camp()
		c.pos = p
		c.wild = "salt"
		c.next_move = INF
		camps.camps.append(c)
		made += 1

## Bell shrines go in the low wet ground just above the sea (the marsh).
func make_bells(rng: RandomNumberGenerator) -> void:
	var made := 0
	for attempt in 400:
		if made >= bell_shrines:
			return
		var p: Vector3 = camps._ground(Vector3(rng.randf_range(-4500, 4500), 0, rng.randf_range(-4500, 4500)))
		if is_nan(p.y) or p.y < camps.SEA_LEVEL + 1.5 or p.y > camps.SEA_LEVEL + 6.0:
			continue
		var c = camps.new_camp()
		c.pos = p
		c.wild = "bell"
		c.next_move = INF
		camps.camps.append(c)
		made += 1

# --- per camp tick ---------------------------------------------------------

## Spots with no people (or not yet): build near, free far, and spring their trap / trigger.
func tick_spot(c, at: Vector3, now: float) -> void:
	var reach: float = bell_range if c.wild == "bell" else (camps.fire_radius if c.wild == "falselight" else camps.spawn_radius)
	var d: float = camps._dist(c.pos, at)
	if d < reach and not is_instance_valid(c.fire):
		c.fire = Node3D.new()
		c.fire.top_level = true
		c.fire.position = c.pos
		c.fire.set_meta("record", c) # lets food / water sources keep their stock on the record
		camps.add_child(c.fire)
		_build(c)
	elif d > reach * 1.2 and is_instance_valid(c.fire):
		c.fire.queue_free()
	if c.wild == "falselight" and (camps._alive(c.members).is_empty() or now > c.job.get("until", INF)):
		if is_instance_valid(c.fire): # nothing came (or the holder's dead): the light goes out
			c.fire.queue_free()
		if camps._alive(c.members).is_empty():
			camps.camps.erase(c)
		else:
			camps._go_home(c, now)
		return
	if not is_instance_valid(c.fire):
		return
	match c.wild:
		"hanged":
			if not c.looted and _sack_empty(c):
				c.looted = true
				_stalk(c, at, now)
		"coldfire":
			if _lit_torch_near(c.pos, relight_distance):
				_relight(c)
		"falselight":
			if d < trap_distance:
				spring_light(c, now, null)
				var f = camps._alive(c.members)[0]
				f.pos = c.pos
				f.home = c.pos
				camps._spawn(f)
				var ai: MobAIComponent = camps._ai(f)
				if ai:
					ai._asleep = false
					ai._enter(MobAIComponent.State.CHASE)
				Talker.notify(false_light_line)

## Encounters with people: the extra rules on top of normal camp behaviour.
func tick_people(c, at: Vector3, now: float) -> void:
	match c.wild:
		"toll":
			if c.looted or c.members.is_empty(): # paid, or the toll-taker is gone
				return
			var toll = c.members[0]
			if toll.dead or not toll.node:
				return
			var d: float = camps._dist(toll.pos, at)
			if c.job.is_empty() and d < 12.0:
				c.job = {"warned": now}
				Talker.notify("%s:\n\"%s\"" % [toll.name, toll_demand % toll_cost])
			elif not c.job.is_empty() and not c.job.has("fight") and (d < toll_too_close or now - c.job.warned > 25.0):
				_toll_fight(c, toll.name)

## Band steering for roaming encounters. Returns true if it handled the band.
func steer_band(b, now: float) -> bool:
	var lead = camps._alive(b.members)[0]
	if b.wild == "stalker":
		var p: Node3D = camps._player
		if now > b.raid_since + stalk_time or not is_instance_valid(p):
			camps._go_home(b, now) # lost interest: back to the den
			return true
		if now - b.waypoint_since > 3.0: # keep homing in on you
			b.waypoint_since = now
			b.pos = p.global_position
			for f in camps._alive(b.members):
				camps._send(f, b.pos + Vector3(randf_range(-4, 4), 0, randf_range(-4, 4)))
		return true
	if b.wild == "pilgrims":
		var bell = _nearest_bell(lead.pos)
		if bell and camps._dist(lead.pos, bell.pos) < pilgrim_arrive: # the bell is rung: the walk is over
			for f in camps._alive(b.members):
				f.needs.faith = 100.0
			b.wild = "wanderer" # now they look for a fire to live at
			camps.note(lead, "reached the bell and rang it. Now to find a fire")
			return false
		if bell and camps._dist(lead.pos, b.pos) < camps.waypoint_reached:
			var dir: Vector3 = (bell.pos - lead.pos)
			b.heading = atan2(dir.z, dir.x) # straight for the bell, step by step
		return false # normal waypoint walking from here
	return false

# --- spawning a person -------------------------------------------------------

func on_spawn(f, person: BaseCharacter) -> void:
	var c = f.camp
	var talker := person.get_node_or_null("talker")
	var ai: MobAIComponent = person.get_node_or_null("mobAI")
	match c.wild:
		"mourner", "starved":
			ai.wanders = false
			person.get_node("visual").scale.y = 0.6 if c.wild == "mourner" else 0.4 # kneeling / slumped
			if talker:
				talker.role = c.wild
				talker.gives_jobs = false
			if c.wild == "mourner":
				_grave(c, person)
				f.job["hp"] = person.statComponent.health.currentValue
				person.statComponent.health.value_changed.connect(func(cur: int, _m: int): _maybe_curse(f, cur))
		"pilgrims":
			ai.wander_speed *= pilgrim_pace
			if talker:
				talker.role = "pilgrim"
				talker.gives_jobs = false
				if talker.container:
					talker.container.queue_free() # pilgrims don't trade
		"toll":
			ai.aggressive = false
			ai.wanders = false
			if f == c.members[0]:
				if talker:
					talker.role = "toll"
				var torch: Node3D = load("res://items/scenes/torch.tscn").instantiate()
				torch.position = Vector3(0.7, 1.4, -0.3)
				person.get_node("visual").add_child(torch)
			else:
				person.visible = true # friends wait in the dark further off (their homes are spread wide)
		"stalker":
			ai.aggressive = true

## A talker with a role says this instead of their usual lines ("" = fall back to normal talk).
func talk(role: String, person: BaseCharacter, player: Node) -> String:
	var f = person.get_meta("folk") if person.has_meta("folk") else null
	match role:
		"mourner":
			if _take_food(player):
				_fed(f)
				return mourner_lines[randi() % mourner_lines.size()]
			return "..."
		"starved":
			if f and f.job.has("fed"):
				return "I'll live. For a while."
			if _take_food(player):
				if f:
					f.job["fed"] = true
					_fed(f)
				var give: int = mini(starved_reward, f.inv.get("coin", 0) if f else 0) # all they have, up to the reward
				if give > 0:
					camps.camplife.add(f.inv, "coin", -give)
					player.inventoryComponent.add_item(camps.get_node("/root/item_list").get_item_instance("coin"), give)
				return starved_thanks
			return starved_beg
		"pilgrim":
			if f:
				for o in camps._alive(f.camp.members):
					var ai: MobAIComponent = camps._ai(o)
					if ai and o.node:
						ai._enter(MobAIComponent.State.IDLE)
						var to: Vector3 = (player.global_position - o.node.global_position)
						o.node.rotation.y = atan2(-to.x, -to.z)
			return pilgrims_turn_line
		"toll":
			var c = f.camp if f else null
			if c and c.looted:
				return toll_paid
			if c and _pay(player, toll_cost):
				c.looted = true # paid up
				if f:
					camps.camplife.add(f.inv, "coin", toll_cost) # into the toll-taker's pack
				return toll_paid
			if c:
				_toll_fight(c, person.Name)
			return toll_refused
	return ""

# --- ash storm --------------------------------------------------------------

func _process(delta: float) -> void:
	if Engine.is_editor_hint() or not camps:
		return
	var now := SimClock.now
	if not _env:
		var scene := get_tree().current_scene
		var we := scene.get_node_or_null("WorldEnvironment") as WorldEnvironment if scene else null
		if not we or not we.environment:
			return
		_env = we.environment
		_base_fog = _env.fog_density
		_base_fog_color = _env.fog_light_color
		_sun = scene.get_node_or_null("skylight") as DirectionalLight3D
		_base_sun = _sun.light_energy if _sun else 0.0
		_ash = scene.find_child("AshFall", true, false) as GPUParticles3D
	if not _storming and now > _next_storm: # a storm begins
		_storming = true
		_storm_end = now + randf_range(storm_length.x, storm_length.y)
		Talker.notify(storm_start_line)
		_hunt(now)
	elif _storming and now > _storm_end: # it ends
		_storming = false
		_next_storm = now + randf_range(storm_every.x, storm_every.y)
		Talker.notify(storm_end_line)
	_storm = move_toward(_storm, 1.0 if _storming else 0.0, delta / 8.0) # 8 s to roll in / out
	_env.fog_density = _base_fog * lerpf(1.0, storm_fog, _storm)
	_env.fog_light_color = _base_fog_color.lerp(Color(0.03, 0.025, 0.025), _storm) # the ash goes black
	if _sun:
		_sun.light_energy = _base_sun * lerpf(1.0, storm_light, _storm)
	if _ash:
		_ash.amount_ratio = lerpf(0.47, 1.0, _storm)
	TorchBurn.burn_rate = lerpf(1.0, storm_burn, _storm) * (curse_burn if now < _cursed_until else 1.0)

var _cursed_until := 0.0

func _hunt(now: float) -> void:
	var p: Node3D = camps._player
	if not is_instance_valid(p):
		return
	_hunters(p.global_position, randi_range(storm_hunters.x, maxi(storm_hunters.x, storm_hunters.y)), now)

# --- helpers ------------------------------------------------------------------

## A false light springs: the light goes out and the orc that held it hunts (you, or `prey`: a group that came to
## it), then goes home. Same whoever walks into it.
func spring_light(c, now: float, prey) -> void:
	if is_instance_valid(c.fire):
		c.fire.queue_free()
	c.wild = "pack"
	c.roaming = true
	c.job["until"] = now + stalk_time
	if prey:
		c.raid = prey
		c.raid_since = now
		for f in camps._alive(c.members):
			camps._send(f, prey.pos)

## Up to `count` goblins from the nearest den or pack within hunt_range come after you (a den keeps one home).
## Nobody near enough: nobody comes. Returns the hunting band, or null.
func _hunters(at: Vector3, count: int, now: float):
	var src = null
	for c in camps.camps:
		if c.kind == "goblin" and c.wild in ["", "pack"] and camps._alive(c.members).size() > (1 if c.wild == "" else 0) and camps._dist(c.pos, at) < hunt_range:
			if src == null or camps._dist(c.pos, at) < camps._dist(src.pos, at):
				src = c
	if src == null:
		return null
	var alive: Array = camps._alive(src.members)
	var who: Array = alive.slice(0, mini(count, alive.size() - (1 if src.wild == "" else 0)))
	var b = camps.new_camp()
	b.wild = "stalker"
	b.kind = "goblin"
	b.roaming = true
	b.next_move = INF
	b.den = src if src.wild == "" else src.den
	b.pos = who[0].pos
	b.raid_since = now
	for f in who:
		src.members.erase(f)
		f.camp = b
		b.members.append(f)
	camps.camps.append(b)
	return b

func _stalk(c, at: Vector3, now: float) -> void:
	if randf() < hanged_hunt_chance and _hunters(at, randi_range(stalkers.x, maxi(stalkers.x, stalkers.y)), now):
		Talker.notify(watched_line)

func _build(c) -> void:
	var L: Dictionary = preload("res://world/camplife.gd").SOURCES # stock / regrow / per use, shared with the sim
	var root: Node3D = c.fire
	var rng := RandomNumberGenerator.new()
	rng.seed = hash(Vector2i(roundi(c.pos.x), roundi(c.pos.z)))
	match c.wild:
		"hanged":
			_box(root, Vector3(0.3, 6.0, 0.3), Vector3(0, 3.0, 0), Color(0.18, 0.12, 0.08)) # post
			_box(root, Vector3(2.6, 0.25, 0.25), Vector3(1.2, 5.9, 0), Color(0.18, 0.12, 0.08)) # beam
			_box(root, Vector3(0.05, 1.2, 0.05), Vector3(2.2, 5.2, 0), Color(0.3, 0.27, 0.2)) # rope
			var body := _figure(root, Vector3(2.2, 1.5, 0), Color(0.22, 0.2, 0.18))
			var sway := body.create_tween().set_loops()
			sway.tween_property(body, "rotation_degrees:z", 4.0, 2.5).set_trans(Tween.TRANS_SINE)
			sway.tween_property(body, "rotation_degrees:z", -4.0, 2.5).set_trans(Tween.TRANS_SINE)
			if not c.looted:
				_sack(c, Vector3(2.6, 0, 0.6), rng)
		"coldfire":
			var fire: Node3D = camps.fire_scene.instantiate()
			fire.remove_from_group("campfire") # cold: no light, no relighting your torch here
			for n in fire.find_children("*", "", true, false):
				if n is GPUParticles3D or n is Light3D:
					n.visible = false
					n.set_process(false)
			root.add_child(fire)
			for i in rng.randi_range(2, 3):
				var a := rng.randf() * TAU
				var body := _figure(root, Vector3(cos(a), 0.35, sin(a)) * 3.5, Color(0.2, 0.18, 0.16))
				body.rotation = Vector3(PI * 0.5, rng.randf() * TAU, 0) # lying where they fell
		"falselight":
			var torch: Node3D = load("res://items/scenes/torch.tscn").instantiate()
			torch.position = Vector3.UP * 0.55
			root.add_child(torch)
		"starved_dead":
			var body := _figure(root, Vector3(0, 0.35, 0), Color(0.2, 0.18, 0.16))
			body.rotation.x = PI * 0.5
			if not c.looted and c.job.has("loot"):
				if not c.job.loot.is_empty():
					_sack(c, Vector3(1.2, 0, 0), rng, c.job.loot) # what they died carrying
			elif not c.looted:
				_sack(c, Vector3(1.2, 0, 0), rng)
		"spring": # a black pool ringed with stones; drink, fill your skins
			var pool := _box(root, Vector3(3.2, 0.05, 2.4), Vector3(0, 0.03, 0), Color(0.03, 0.05, 0.07))
			(pool.material_override as StandardMaterial3D).roughness = 0.05
			for i in 6:
				var a := TAU * i / 6.0 + rng.randf_range(-0.3, 0.3)
				_box(root, Vector3(0.5, rng.randf_range(0.2, 0.5), 0.4), Vector3(cos(a) * 1.9, 0.15, sin(a) * 1.5), Color(0.15, 0.15, 0.15)).rotation.y = a
			_source(root, "Spring", Vector3(3.2, 0.6, 2.4), {"drink": 45.0, "fill": L.spring[2], "stock": L.spring[0], "regrow": L.spring[1]})
		"salt": # pale crusted rocks at the waterline
			for i in rng.randi_range(4, 7):
				var a := rng.randf() * TAU
				_box(root, Vector3(rng.randf_range(0.6, 1.4), rng.randf_range(0.3, 0.8), rng.randf_range(0.6, 1.2)),
					Vector3(cos(a), 0.2, sin(a)) * rng.randf_range(0.5, 2.0), Color(0.78, 0.76, 0.72)).rotation.y = rng.randf() * TAU
			_source(root, "Salt crust", Vector3(4.0, 0.8, 4.0), {"drink": 0.0, "fill": 0, "item": "salt", "item_count": L.salt[2], "stock": L.salt[0], "regrow": L.salt[1]})
		"fungus": # pale ash caps growing in a ring
			for i in rng.randi_range(6, 10):
				var a := rng.randf() * TAU
				var r := rng.randf_range(0.3, 1.6)
				var h := rng.randf_range(0.15, 0.45)
				_box(root, Vector3(0.06, h, 0.06), Vector3(cos(a) * r, h * 0.5, sin(a) * r), Color(0.6, 0.58, 0.52))
				_box(root, Vector3(0.3, 0.08, 0.3), Vector3(cos(a) * r, h, sin(a) * r), Color(0.75, 0.72, 0.66))
			_source(root, "Ash fungus", Vector3(3.4, 0.5, 3.4), {"drink": 0.0, "fill": 0, "item": "ash_cap", "item_count": L.fungus[2], "stock": L.fungus[0], "regrow": L.fungus[1], "extra_item": "spores", "extra_chance": 0.3})
		"bell":
			for i in 7: # a ring of standing stones
				var a := TAU * i / 7.0
				_box(root, Vector3(0.9, rng.randf_range(2.5, 4.5), 0.6), Vector3(cos(a), 1.2, sin(a)) * 6.0, Color(0.12, 0.13, 0.14)).rotation = Vector3(rng.randf_range(-0.15, 0.15), -a, rng.randf_range(-0.15, 0.15))
			_box(root, Vector3(2.0, 1.0, 1.2), Vector3(0, 0.5, 0), Color(0.15, 0.15, 0.16)) # altar
			if not c.looted:
				_sack(c, Vector3(0, 1.0, 0), rng, {"sunken_key": 1})
			var bell := AudioStreamPlayer3D.new()
			bell.stream = _bell_sound()
			bell.max_distance = bell_range
			bell.unit_size = 60.0
			bell.position = Vector3.UP * 3.0
			root.add_child(bell)
			var t := Timer.new()
			t.wait_time = bell_every
			t.autostart = true
			t.timeout.connect(bell.play)
			bell.add_child(t)
			bell.play.call_deferred()

## An interactable food / water source (world/props/source.gd) covering `size`, keeping its stock on the spot's record.
func _source(parent: Node3D, label: String, size: Vector3, opts: Dictionary) -> void:
	var src: StaticBody3D = load("res://world/props/source.gd").new()
	src.label = label
	for k in opts:
		src.set(k, opts[k])
	var shape := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = size
	shape.shape = box
	shape.position = Vector3.UP * size.y * 0.5
	src.add_child(shape)
	src.collision_layer = 1
	var spot = parent.get_meta("record") if parent.has_meta("record") else null
	src.record = spot
	parent.add_child(src)

func _box(parent: Node3D, size: Vector3, at: Vector3, col: Color) -> MeshInstance3D:
	var m := MeshInstance3D.new()
	var mesh := BoxMesh.new()
	mesh.size = size
	m.mesh = mesh
	var mat := StandardMaterial3D.new()
	mat.albedo_color = col
	mat.roughness = 1.0
	m.material_override = mat
	m.position = at
	parent.add_child(m)
	return m

func _figure(parent: Node3D, at: Vector3, col: Color) -> Node3D:
	var fig: Node3D = load("res://characters/folk/folkFigure.gd").new()
	fig.set("carries", 0)
	fig.set("cloak_color", col)
	fig.set("eye_color", Color(0.05, 0.05, 0.05))
	fig.set("color_variance", 0.0)
	fig.position = at
	parent.add_child(fig)
	return fig

func _sack(c, at: Vector3, rng: RandomNumberGenerator, loot: Dictionary = {}) -> void:
	if loot.is_empty():
		for k in rng.randi_range(camps.remains_items.x, maxi(camps.remains_items.x, camps.remains_items.y)):
			var id: String = camps.remains_loot[rng.randi() % camps.remains_loot.size()]
			loot[id] = loot.get(id, 0) + (rng.randi_range(camps.remains_coins.x, camps.remains_coins.y) if id == "coin" else 1)
	if not c.stocked: # what's in it is the place's own store from now on: take from it and it stays taken
		c.stocked = true
		for k in loot:
			c.crate[k] = c.crate.get(k, 0) + loot[k]
	var sack: Node3D = load("res://items/scenes/lootSack.tscn").instantiate()
	var nothing: Dictionary[String, int] = {}
	sack.get_node("interactableComponent/containerComponent").starting_items = nothing
	sack.position = at
	sack.name = "sack"
	var sync: Node = load("res://world/props/campStoreSync.gd").new()
	sync.record = c
	sync.which = "crate"
	sack.add_child(sync)
	c.fire.add_child(sack)

func _sack_empty(c) -> bool:
	return c.stocked and c.crate.is_empty()

func _grave(c, person: Node3D) -> void:
	if is_instance_valid(c.fire):
		return
	c.fire = Node3D.new() # the grave: a mound and a cross, freed with the record's spot like a fire
	c.fire.top_level = true
	c.fire.position = c.pos
	camps.add_child(c.fire)
	_box(c.fire, Vector3(1.2, 0.4, 2.2), Vector3(0, 0.2, 0), Color(0.12, 0.1, 0.08))
	_box(c.fire, Vector3(0.15, 1.6, 0.15), Vector3(0, 0.8, -1.2), Color(0.2, 0.15, 0.1))
	_box(c.fire, Vector3(0.8, 0.15, 0.15), Vector3(0, 1.2, -1.2), Color(0.2, 0.15, 0.1))
	person.global_position = c.pos + Vector3(0, 0.1, 1.6)

func _maybe_curse(f, current: int) -> void:
	if not f.job.has("hp"):
		f.job["hp"] = current
		return
	if current < f.job.hp and SimClock.now > _cursed_until:
		_cursed_until = SimClock.now + curse_time
		Talker.notify(curse_line)
	f.job["hp"] = current

func _lit_torch_near(at: Vector3, r: float) -> bool:
	for t: Node3D in get_tree().get_nodes_in_group("light_source"):
		var flame := t.get_node_or_null("fire_effect") as Node3D
		if t.has_meta("item") and flame and flame.visible and t.global_position.distance_to(at) < r:
			return true # a torch in someone's hand, burning
	return false

func _relight(c) -> void:
	c.fire.queue_free()
	c.wild = "" # a real drifter camp now: its fire lights up next tick, drifters can settle here
	c.kind = "drifter"
	var p: Node3D = camps._player
	var respawn := p.find_children("*", "RespawnComponent", true, false) if p else []
	if not respawn.is_empty():
		respawn[0]._spawn_transform = Transform3D(Basis(), c.pos + Vector3(0, 1, 4))
	Talker.notify(relit_line)

func _toll_fight(c, who: String) -> void:
	c.job["fight"] = true
	Talker.notify("%s:\n\"%s\"" % [who, toll_refused])
	for f in camps._alive(c.members):
		var ai: MobAIComponent = camps._ai(f)
		if ai:
			ai.aggressive = true
			ai._enter(MobAIComponent.State.CHASE)

## Someone you fed remembers it, and so does their camp.
func _fed(f) -> void:
	var m = camps.minds
	if f and m:
		m.remember(f, "fed_by_player")
		m.rep(f.camp, m.rep_fed)
		if not f.needs.is_empty():
			f.needs.food = 100.0
			f.needs.water = 100.0
			f.needs.light = maxf(f.needs.light, 60.0) # you got them back on their feet: enough to reach a fire

func _take_food(player: Node) -> bool:
	var inv: InventoryComponent = player.inventoryComponent
	for key: Item in inv.inventory.keys():
		for e in key.get_effects():
			if e is NourishEffect and e.food > 0.0:
				inv.remove_item(key, 1)
				return true
	return false

func _pay(player: Node, cost: int) -> bool:
	var inv: InventoryComponent = player.inventoryComponent
	var coin: Item = camps.get_node("/root/item_list").get_item_instance("coin")
	if inv.count_item(coin) < cost:
		return false
	var left := cost
	for key: Item in inv.inventory.keys():
		if left > 0 and InventoryComponent.is_same_item(key, coin):
			left -= inv.remove_item(key, left)
	return true

func _nearest_bell(pos: Vector3):
	var best = null
	for c in camps.camps:
		if c.wild == "bell" and (best == null or camps._dist(c.pos, pos) < camps._dist(best.pos, pos)):
			best = c
	return best

## A struck bell: a few inharmonic partials with a long decay, made once.
static var _bell: AudioStreamWAV
static func _bell_sound() -> AudioStreamWAV:
	if _bell:
		return _bell
	var rate := 22050
	var data := PackedByteArray()
	data.resize(rate * 5 * 2)
	for i in rate * 5:
		var t := float(i) / rate
		var s := 0.0
		for p: Vector2 in [Vector2(220.0, 1.0), Vector2(440.0 * 1.19, 0.5), Vector2(220.0 * 2.76, 0.35), Vector2(220.0 * 5.4, 0.15)]:
			s += sin(TAU * p.x * t) * p.y * exp(-t * (0.6 + p.x / 900.0))
		data.encode_s16(i * 2, int(clampf(s * 0.35, -1.0, 1.0) * 32767.0))
	_bell = AudioStreamWAV.new()
	_bell.format = AudioStreamWAV.FORMAT_16_BITS
	_bell.mix_rate = rate
	_bell.data = data
	return _bell
