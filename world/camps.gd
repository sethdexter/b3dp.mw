@tool
extends Node3D
## Every camp and person on the island, tracked as plain data so thousands cost almost nothing.
## Only people near the player exist as real nodes; the rest are records that move along cheaply
## (a slice of them per frame). Group AI works on the records, so it runs whether you're there or not:
##   - bands of drifters pack up now and then and roam (on the navmesh near the player) until they spot a fire, then go to it
##   - hit one member of a camp and the rest of the camp joins in
##   - bandit bands raid nearby drifter / goblin / orc camps (fought out for real near the player, by dice rolls
##     elsewhere), or send out war bands that roam the roads and hit whatever camp they come across
## Camp kinds: drifter, bandit, goblin, orc. Goblin and orc camps are hostile and stay put.
## Between the camps, wilderness encounters with no fire (their own sparser grid, see the Encounters sliders):
##   wanderer = a lone drifter walking the dark, pack = goblins roaming nowhere to nowhere, ambush = bandits
##   waiting in the dark, remains = an abandoned stash with a loot sack, cairn = a torch someone left burning
##   (a little island of light to catch your breath in). Remains remember being looted.
## More bleak ones (hanged, cold fire, mourner, pilgrims, false light, starved, toll, bell) and the ash storm
## live in world/encounters.gd (child node "encounters", made at runtime; its sliders are on that script).
## What people want and do (needs, traits, memories, reputation) is world/minds.gd (child "minds"); groups
## meeting each other (fights, sharing, merging, looting...) is world/meetings.gd (child "meetings").
## Food and water: springs and ash fungus on the encounter grid, a water barrel at every drifter camp.
## Camp spots are fixed per cell of the map (same every run), in clearings away from tree roots.

## Editor: re-place the preview campfires after changing settings.
@export_tool_button("Rebuild preview") var rebuild_button := _editor_preview
## Editor preview: camps within this of the editor camera show their real fire and clutter (the rest just a label).
@export_range(50.0, 3000.0, 10.0, "suffix:m") var editor_preview_radius := 400.0
@export var terrain: Terrain3D
## Camps are kept clear of these trees' roots.
@export var trees: Node3D
@export var drifter_scene: PackedScene = preload("res://characters/folk/drifter.tscn")
@export var bandit_scene: PackedScene = preload("res://characters/folk/bandit.tscn")
@export var goblin_scene: PackedScene = preload("res://characters/mobs/goblin.tscn")
@export var orc_scene: PackedScene = preload("res://characters/mobs/orc.tscn")
@export var fire_scene: PackedScene = preload("res://world/props/campfire.tscn")
@export_group("Camps", "")
## One camp at most per square cell this size (metres). Bigger = camps further apart (and fewer of them).
@export_range(100, 2000, 10, "suffix:m") var cell_size := 800
## Chance each land cell actually has a camp.
@export_range(0.0, 1.0, 0.01) var camp_chance := 0.4
## Chance a camp is bandits / goblins / orcs. Whatever's left over is drifters.
@export_range(0.0, 1.0, 0.01) var bandit_chance := 0.6
@export_range(0.0, 1.0, 0.01) var goblin_chance := 0.15
@export_range(0.0, 1.0, 0.01) var orc_chance := 0.08
## People per camp when the island is made (rolled per camp), by kind.
@export_range(1, 8) var people_min := 1
@export_range(1, 8) var people_max := 4
@export_range(1, 12) var bandits_min := 3
@export_range(1, 12) var bandits_max := 6
@export_range(1, 12) var goblins_min := 2
@export_range(1, 12) var goblins_max := 5
@export_range(1, 12) var orcs_min := 1
@export_range(1, 12) var orcs_max := 2
## How far from the fire people stand / hang around.
@export_range(1.0, 15.0, 0.5, "suffix:m") var sit_radius_min := 3.0
@export_range(1.0, 15.0, 0.5, "suffix:m") var sit_radius_max := 5.0
## Clear ground needed around a camp spot (beyond the big trees' roots).
@export_range(0.0, 20.0, 0.5, "suffix:m") var clearing := 5.0

@export_group("Distances", "")
## Campfires are built this far out; a roaming band notices a fire from this far too.
@export_range(50, 3000, 10, "suffix:m") var fire_radius := 1000
## People become real characters within this...
@export_range(30.0, 500.0, 5.0, "suffix:m") var spawn_radius := 120.0
## ...and go back to being records past this (keep it above spawn_radius so they don't flicker).
@export_range(40.0, 600.0, 5.0, "suffix:m") var despawn_radius := 200.0

@export_group("Simulation", "")
## Records updated per frame: the whole island is swept every (count / this) frames. Higher = smoother far
## movement and quicker spawning, at more CPU per frame.
@export_range(10, 2000, 10) var records_per_frame := 150
## How fast far-away (record) people walk. Near you the AI's own speeds apply.
@export_range(0.2, 5.0, 0.1, "suffix:m/s") var walk_speed := 1.1
## Seconds between a camp thinking about moving on (drifters) or raiding (bandits): random in (min, max).
@export var migrate_every := Vector2(90, 300)

@export_group("Roaming bands", "")
## Each waypoint is this far on from the last (random in range).
@export_range(5.0, 200.0, 1.0, "suffix:m") var waypoint_min := 40.0
@export_range(5.0, 200.0, 1.0, "suffix:m") var waypoint_max := 80.0
## How much the heading wanders at each waypoint (radians either way). 0 = dead straight, 3 = random walk.
@export_range(0.0, 3.14, 0.05) var heading_wobble := 0.8
## A band this close to its waypoint picks the next one.
@export_range(1.0, 30.0, 0.5, "suffix:m") var waypoint_reached := 8.0
## Stuck this long on one waypoint: turn 90 degrees and try another way.
@export_range(10.0, 600.0, 5.0, "suffix:s") var waypoint_give_up := 90.0

@export_group("Raids", "")
## When a bandit camp acts, chance it sends out a roaming war band (rather than raiding one camp directly)...
@export_range(0.0, 1.0, 0.01) var war_band_chance := 0.6
## ...made of this share of the camp (the rest stay home).
@export_range(0.1, 1.0, 0.05) var war_band_share := 0.5
## Bandits only raid camps within this (a war band raids whatever comes within fire_radius).
@export_range(100.0, 3000.0, 10.0, "suffix:m") var migrate_range := 850.0
## A raid is called off after this long.
@export_range(30.0, 1200.0, 10.0, "suffix:s") var raid_time_limit := 300.0
## The raid starts once a raider is this close to the target fire.
@export_range(5.0, 100.0, 1.0, "suffix:m") var raid_arrive := 20.0
## Far away (dice rolls): chance per camp tick that someone falls...
@export_range(0.0, 1.0, 0.01) var raid_kill_chance := 0.3
## ...and the chance it's a defender rather than a bandit.
@export_range(0.0, 1.0, 0.01) var bandit_win_chance := 0.6

@export_group("Encounters", "")
## One encounter at most per cell this size; they're placed in the dark between camps.
@export_range(50, 2000, 10, "suffix:m") var encounter_cell := 300
## Chance each land cell has an encounter.
@export_range(0.0, 1.0, 0.01) var encounter_chance := 0.35
## None closer than this to a camp fire (so the dark between camps stays dark).
@export_range(0.0, 1000.0, 10.0, "suffix:m") var encounter_camp_gap := 250.0
## Relative weights of each kind (they don't need to add up to anything).
@export_range(0.0, 10.0, 0.1) var wanderer_weight := 3.0
@export_range(0.0, 10.0, 0.1) var pack_weight := 2.0
@export_range(0.0, 10.0, 0.1) var ambush_weight := 1.0
@export_range(0.0, 10.0, 0.1) var remains_weight := 3.0
@export_range(0.0, 10.0, 0.1) var cairn_weight := 1.5
@export_range(0.0, 10.0, 0.1) var hanged_weight := 1.5
@export_range(0.0, 10.0, 0.1) var coldfire_weight := 1.0
@export_range(0.0, 10.0, 0.1) var mourner_weight := 1.0
@export_range(0.0, 10.0, 0.1) var pilgrims_weight := 0.7
@export_range(0.0, 10.0, 0.1) var falselight_weight := 1.0
@export_range(0.0, 10.0, 0.1) var starved_weight := 1.0
@export_range(0.0, 10.0, 0.1) var toll_weight := 1.0
## Food and water sources between the camps.
@export_range(0.0, 10.0, 0.1) var spring_weight := 2.0
@export_range(0.0, 10.0, 0.1) var fungus_weight := 2.5
## Goblins in a pack / bandits in an ambush (random in range).
@export var pack_size := Vector2i(2, 3)
@export var ambush_size := Vector2i(2, 4)
## What a remains' loot sack can hold, and how many things (random in range).
@export var remains_loot: PackedStringArray = ["bread", "water_skin", "dried_meat", "torch", "health_potion", "stamina_potion", "coin", "coin", "rusty_sword", "leather_cap"]
@export var remains_items := Vector2i(1, 3)
## Coins per "coin" entry rolled for a remains' sack.
@export var remains_coins := Vector2i(3, 15)

@export_group("Clutter", "")
## Chance a camp gets a second set piece.
@export_range(0.0, 1.0, 0.01) var second_piece_chance := 0.5
## Set pieces sit this far from the fire (random in range).
@export_range(3.0, 30.0, 0.5, "suffix:m") var clutter_radius_min := 6.5
@export_range(3.0, 30.0, 0.5, "suffix:m") var clutter_radius_max := 9.0
## Loot in a bandit chest (random in range).
@export_range(0, 10) var chest_items_min := 1
@export_range(0, 10) var chest_items_max := 3
## Coins in a bandit chest (random in range).
@export_range(0, 500) var chest_coins_min := 10
@export_range(0, 500) var chest_coins_max := 40
## Chance the table in a set piece is a barrel (else a crate).
@export_range(0.0, 1.0, 0.01) var barrel_chance := 0.7
## Things on the table top (random in range; at most 5 kinds).
@export_range(0, 5) var top_items_min := 2
@export_range(0, 5) var top_items_max := 4
## Up to this many crates beside the table, and the chance each has another stacked on it.
@export_range(0, 4) var crates_max := 2
@export_range(0.0, 1.0, 0.01) var stack_chance := 0.45
## Up to this many staffs / swords leaned on things (at most 3 kinds).
@export_range(0, 3) var leaners_max := 2
## Up to this many odds and ends dropped on the ground nearby.
@export_range(0, 10) var floor_items_max := 3
## How much a barrel/crate follows the slope it sits on: 1 = fully, 0 = always upright.
@export_range(0.0, 1.0, 0.05) var slope_follow := 0.7
@export_group("")

const SEA_LEVEL := -10.0
const KIND_COLORS := {"drifter": Color(1.0, 0.55, 0.1), "bandit": Color(0.9, 0.15, 0.1), "goblin": Color(0.35, 0.8, 0.25), "orc": Color(0.6, 0.3, 0.85)}
const MAX_HEIGHT := 200.0 # no camps up on the mountains
const HALF_MAP := 5000.0

class Camp:
	var pos: Vector3
	var bandit := false
	var kind := "drifter" # drifter / bandit / goblin / orc
	var wild := "" # an encounter with no fire: wanderer / pack / ambush / remains / cairn ("" = a real camp)
	var looted := false # remains: the sack was emptied (toll: you paid)
	var job := {} # scratch state for an encounter (toll warning, ...)
	var members: Array = [] # of Folk
	var fire: Node3D
	var next_move := 0.0
	var raid: Camp # bandits: the camp they're attacking
	var raid_since := 0.0
	var roaming := false # a band on the move: pos is its next waypoint, no fire
	var from: Camp # the camp a roaming band left (it won't settle straight back there)
	var heading := 0.0
	var waypoint_since := 0.0
	var rep := 0 # how this camp feels about the player (-100..100, see minds.gd)
	var empty_since := 0.0
	var supplies := -1.0 # minds.gd: the camp's food store (-1 = not stocked yet)

class Folk:
	var name := "" # picked by the talker on first spawn, then kept
	var camp: Camp
	var pos: Vector3
	var home: Vector3 # where it's walking to / hangs around
	var node: BaseCharacter
	var dead := false
	var ticked := 0.0
	var job := {} # a favour they've offered the player (see Talker)
	var asked := false # they've already rolled for a job
	var needs := {} # minds.gd: food, light, safety, coin, belonging, faith (0-100)
	var traits := {} # minds.gd: greed, courage, piety, cruelty, despair (0-1)
	var memories := [] # minds.gd: [{what, at, pos}]
	var think_t := 0.0
	var locked_until := 0.0

var camps: Array[Camp] = []
var _by_cell := {} # Vector2i -> Camp, for finding camps near a spot
var folk: Array[Folk] = []
var _player: Node3D
var _folk_i := 0
var _camp_i := 0
var _rng := RandomNumberGenerator.new()
var enc: Node # world/encounters.gd (runtime only)
var minds: Node # world/minds.gd (runtime only)

func new_camp() -> Camp:
	return Camp.new()

func new_folk() -> Folk:
	return Folk.new()

func _ready() -> void:
	add_to_group("camps")
	if Engine.is_editor_hint():
		_editor_preview()
		return
	if not terrain or not terrain.data:
		return
	var t := Time.get_ticks_msec()
	enc = load("res://world/encounters.gd").new()
	enc.name = "encounters"
	add_child(enc)
	minds = load("res://world/minds.gd").new()
	minds.name = "minds"
	add_child(minds)
	var clock: Node = load("res://world/simClock.gd").new() # the sim's own clock, and [ ] to change its speed
	clock.name = "clock"
	add_child(clock)
	var meetings: Node = load("res://world/meetings.gd").new()
	meetings.name = "meetings"
	add_child(meetings)
	_generate()
	print("Camps: %d camps, %d people (%d ms)" % [camps.size(), folk.size(), Time.get_ticks_msec() - t])
	var layer := CanvasLayer.new() # overhead debug map of the whole simulation (press M)
	var map: Control = preload("res://ui/simMap.gd").new()
	map.camps = self
	layer.add_child(map)
	add_child(layer)

func _generate() -> void:
	camps.clear()
	folk.clear()
	_by_cell.clear()
	var n := int(HALF_MAP * 2.0 / cell_size)
	for z in n:
		for x in n:
			_make_camp(Vector2i(x - n / 2, z - n / 2))
	var m := int(HALF_MAP * 2.0 / encounter_cell)
	for z in m:
		for x in m:
			_make_encounter(Vector2i(x - m / 2, z - m / 2))
	if enc:
		var rng := RandomNumberGenerator.new()
		rng.seed = 991
		enc.make_bells(rng)

func _make_encounter(cell: Vector2i) -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = hash(Vector3i(cell.x, cell.y, 77)) # its own dice, apart from the camps'
	if rng.randf() > encounter_chance:
		return
	var pos := _ground(Vector3((cell.x + rng.randf()) * encounter_cell, 0, (cell.y + rng.randf()) * encounter_cell))
	if is_nan(pos.y) or pos.y < SEA_LEVEL + 1.5 or pos.y > MAX_HEIGHT:
		return
	for c in camps:
		if c.wild == "" and _dist(c.pos, pos) < encounter_camp_gap:
			return
	var weights := {"wanderer": wanderer_weight, "pack": pack_weight, "ambush": ambush_weight, "remains": remains_weight, "cairn": cairn_weight,
		"hanged": hanged_weight, "coldfire": coldfire_weight, "mourner": mourner_weight, "pilgrims": pilgrims_weight,
		"falselight": falselight_weight, "starved": starved_weight, "toll": toll_weight,
		"spring": spring_weight, "fungus": fungus_weight}
	var total := 0.0
	for k in weights:
		total += weights[k]
	if total <= 0.0:
		return
	var roll := rng.randf() * total
	var wild := ""
	for k in weights:
		roll -= weights[k]
		if roll <= 0.0:
			wild = k
			break
	var c := Camp.new()
	c.pos = pos
	c.wild = wild
	c.next_move = INF # encounters never move camp or raid
	c.kind = {"wanderer": "drifter", "pack": "goblin", "ambush": "bandit"}.get(wild, "drifter")
	c.bandit = c.kind == "bandit"
	camps.append(c)
	var count: int = {"wanderer": 1, "pack": rng.randi_range(pack_size.x, maxi(pack_size.x, pack_size.y)),
		"ambush": rng.randi_range(ambush_size.x, maxi(ambush_size.x, ambush_size.y))}.get(wild, 0)
	var roams := wild == "wanderer" or wild == "pack"
	if enc and count == 0:
		var who: Array = enc.people_for(wild, rng)
		c.kind = who[0]
		c.bandit = c.kind == "bandit"
		count = who[1]
		roams = who[2]
	for i in count:
		var f := Folk.new()
		f.camp = c
		f.home = _around(pos, rng)
		if wild == "toll" and i > 0: # the toll man's friends wait out in the dark
			f.home = pos + Vector3(cos(i * 2.1), 0, sin(i * 2.1)) * rng.randf_range(14.0, 20.0)
		f.pos = f.home
		c.members.append(f)
		folk.append(f)
	if roams:
		c.roaming = true # walks the dark forever, never settles
		c.heading = rng.randf() * TAU

## Remains and cairns: no people, just things on the ground, built when you're near and freed when you leave.
func _tick_spot(c: Camp, at: Vector3) -> void:
	var reach: float = fire_radius if c.wild == "cairn" else spawn_radius # a cairn's torch is seen from afar
	var d := _dist(c.pos, at)
	if d < reach and not is_instance_valid(c.fire):
		c.fire = Node3D.new()
		c.fire.top_level = true
		c.fire.position = c.pos
		add_child(c.fire)
		var rng := RandomNumberGenerator.new()
		rng.seed = hash(Vector2i(roundi(c.pos.x), roundi(c.pos.z)))
		if c.wild == "cairn":
			var torch: Node3D = load("res://items/scenes/torch.tscn").instantiate()
			torch.position = Vector3.UP * 0.55
			torch.rotation_degrees.x = rng.randf_range(-10, 10)
			c.fire.add_child(torch)
			return
		var piece: Node3D = CLUTTER.build(rng, {"top_max": 2, "crates_max": 1, "leaners_max": 1, "floor_max": 4})
		c.fire.add_child(piece)
		for part in piece.get_children():
			if part is Node3D and (part.scene_file_path.contains("barrel") or part.scene_file_path.contains("crate")):
				_settle(part)
				_solid(part)
		if not c.looted:
			var loot: Dictionary[String, int] = {}
			for k in rng.randi_range(remains_items.x, maxi(remains_items.x, remains_items.y)):
				var id: String = remains_loot[rng.randi() % remains_loot.size()]
				loot[id] = loot.get(id, 0) + (rng.randi_range(remains_coins.x, maxi(remains_coins.x, remains_coins.y)) if id == "coin" else 1)
			var sack: Node3D = load("res://items/scenes/lootSack.tscn").instantiate()
			sack.get_node("interactableComponent/containerComponent").starting_items = loot
			sack.position = _ground(c.pos + Vector3(2.2, 0, 0)) - c.pos
			sack.name = "sack"
			c.fire.add_child(sack)
	elif d > reach * 1.2 and is_instance_valid(c.fire):
		var sack := c.fire.get_node_or_null("sack")
		var inv = sack.find_child("inventoryComponent", true, false) if sack else null
		c.looted = c.looted or sack == null or (inv != null and inv.inventory.is_empty())
		c.fire.queue_free()

## Editor only: every camp's fire with a label, so you can see where they'll be. Not saved (no owner).
func _editor_preview() -> void:
	for child in get_children():
		child.queue_free()
	if not terrain or not terrain.data:
		return
	_generate()
	_preview_at = Vector3.INF # the next editor tick builds whatever's near the camera

var _preview_at := Vector3.INF

## Editor only: like the game, camps near the editor camera get their real fire and clutter, far ones are freed.
## Every camp still gets a floating label so you can see where they all are.
func _editor_tick() -> void:
	var ei = Engine.get_singleton("EditorInterface") # not referenced by name: this script also runs in the game
	var vp = ei.get_editor_viewport_3d(0) if ei else null
	var cam: Camera3D = vp.get_camera_3d() if vp else null
	if not cam or cam.global_position.distance_to(_preview_at) < 20.0:
		return
	_preview_near(cam.global_position)

func _preview_near(at: Vector3) -> void:
	_preview_at = at
	for c in camps:
		if c.wild != "":
			if not is_instance_valid(c.fire): # encounters: just a marker and a label
				c.fire = _marker(c.pos, c.wild.capitalize(), Color(0.8, 0.8, 0.85), false)
			continue
		var near := _dist(c.pos, _preview_at) < editor_preview_radius
		if not is_instance_valid(c.fire): # holds the label always, the fire and clutter only when near
			c.fire = _marker(c.pos, "%s camp (%d)" % [c.kind.capitalize(), c.members.size()], KIND_COLORS[c.kind], true)
		var real := c.fire.get_node_or_null("real")
		if near and not real:
			real = fire_scene.instantiate()
			real.name = "real"
			c.fire.add_child(real)
			if c.kind == "drifter" or c.kind == "bandit":
				_dress(c, real)
		elif not near and real:
			real.queue_free()

## Editor marker: a dot and a label that stay the same size on screen at any distance (fixed_size), drawn
## through terrain. `big` = camps (bigger, higher), else encounters.
func _marker(pos: Vector3, text: String, col: Color, big: bool) -> Node3D:
	var m := Node3D.new()
	m.top_level = true
	m.position = pos
	add_child(m)
	for part in [["●", 0.0, 0.0015 if big else 0.001], [text, 1.0, 0.0007 if big else 0.0005]]: # the dot, then the name above it
		var label := Label3D.new()
		label.text = part[0]
		label.modulate = col
		label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
		label.no_depth_test = true
		label.fixed_size = true
		label.pixel_size = part[2]
		label.outline_size = 6
		label.position = Vector3.UP * (2.0 + part[1] * (6.0 if big else 3.0))
		label.offset = Vector2(0, 0)
		m.add_child(label)
	return m

## Camp clutter: one or two random set pieces in the start scene's style (see campClutter.gd), and for bandits a
## chest of loot. Same layout every visit (seeded by the camp's spot). Children of the fire, so they come and go with it.
const CLUTTER := preload("res://world/props/campClutter.gd")
const CHEST := preload("res://items/scenes/chest.tscn")
const BANDIT_LOOT := ["rusty_sword", "health_potion", "stamina_potion", "leather_cap", "iron_boots", "torch",
	"bread", "dried_meat", "water_skin", "ash_wine", "ash_wine"]

func _dress(c: Camp, fire: Node3D) -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = hash(Vector2i(roundi(c.pos.x), roundi(c.pos.z)))
	var kinds: Array[String] = ["clutter"]
	if rng.randf() < second_piece_chance:
		kinds.append("clutter")
	if c.bandit:
		kinds.append("chest")
	elif c.kind == "drifter":
		kinds.append("water") # a barrel of water anyone can drink from
	var a0 := rng.randf() * TAU
	for i in kinds.size():
		var a := a0 + TAU * i / kinds.size() + rng.randf_range(-0.3, 0.3)
		var spot := Node3D.new()
		var footprint := 0.8 if kinds[i] == "chest" else 2.0
		spot.position = _flat_spot(c.pos + Vector3(cos(a), 0, sin(a)) * rng.randf_range(clutter_radius_min, clutter_radius_max), footprint) - c.pos
		spot.rotation.y = a + PI * 0.5 + rng.randf_range(-0.4, 0.4) # side-on to the fire, like it was set down there
		fire.add_child(spot)
		if kinds[i] == "water":
			var barrel: Node3D = load("res://world/props/waterBarrel.tscn").instantiate()
			barrel.set("record", c)
			spot.add_child(barrel)
			_settle(barrel.get_node("barrel"))
			continue
		var n: Node3D = CHEST.instantiate() if kinds[i] == "chest" else CLUTTER.build(rng, {"barrel_chance": barrel_chance, "top_min": top_items_min,
			"top_max": top_items_max, "crates_max": crates_max, "stack_chance": stack_chance,
			"leaners_max": leaners_max, "floor_max": floor_items_max})
		spot.add_child(n)
		for part in n.get_children():
			if part is Node3D and (part.scene_file_path.contains("barrel") or part.scene_file_path.contains("crate")):
				_settle(part)
				_solid(part)
				for top: Node in part.get_children():
					if top.scene_file_path.contains("crate"):
						_solid(top) # stacked crate
		if kinds[i] == "chest":
			var db = get_node_or_null("/root/item_list")
			var inv = n.find_child("inventoryComponent", true, false)
			if db and inv and not Engine.is_editor_hint():
				inv.inventory.clear() # the chest scene comes stocked for the start scene; bandits keep their own
				for k in rng.randi_range(chest_items_min, chest_items_max):
					inv.add_item(db.get_item_instance(BANDIT_LOOT[rng.randi() % BANDIT_LOOT.size()]), 1)
				inv.add_item(db.get_item_instance("coin"), rng.randi_range(chest_coins_min, maxi(chest_coins_min, chest_coins_max)))

## Sits a ground-level barrel/crate (2 m, centred pivot) on the real ground under it, tilted to the slope.
func _settle(n: Node3D) -> void:
	var g := n.global_transform
	var flat := Basis(Vector3.UP, g.basis.get_euler().y)
	var c := _ground(g.origin)
	var dx := _ground(g.origin + flat.x * 0.9) - _ground(g.origin - flat.x * 0.9)
	var dz := _ground(g.origin + flat.z * 0.9) - _ground(g.origin - flat.z * 0.9)
	if is_nan(c.y) or is_nan(dx.y) or is_nan(dz.y):
		return
	var up := dz.cross(dx).normalized()
	if up.y < 0.0:
		up = -up
	up = Vector3.UP.slerp(up, slope_follow) # under 1: a bit less than the full slope, so it sits in the dirt a touch
	n.global_transform = Transform3D(Basis(Quaternion(Vector3.UP, up)) * g.basis, c + up * 1.0)

## p raised to the highest ground within r of it, so a set piece on a slope doesn't sink into the hill.
func _flat_spot(p: Vector3, r: float) -> Vector3:
	var top := _ground(p).y
	for k in 8:
		var h := _ground(p + Vector3(cos(k * TAU / 8), 0, sin(k * TAU / 8)) * r).y
		if not is_nan(h):
			top = maxf(top, h)
	return Vector3(p.x, top, p.z)

## Box collider around a model so you bump into it (and mobs path around it).
func _solid(n: Node3D) -> void:
	var box := AABB()
	for m: MeshInstance3D in n.find_children("*", "MeshInstance3D", true, false):
		var a: AABB = n.global_transform.affine_inverse() * m.global_transform * m.get_aabb()
		box = a if box.size == Vector3.ZERO else box.merge(a)
	var body := StaticBody3D.new()
	body.add_to_group("navmesh")
	var shape := CollisionShape3D.new()
	var bs := BoxShape3D.new()
	bs.size = box.size
	shape.shape = bs
	shape.position = box.get_center()
	body.add_child(shape)
	n.add_child(body)

func _make_camp(cell: Vector2i) -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = hash(cell) # same camp in the same spot every time
	if rng.randf() > camp_chance:
		return
	var pos := Vector3(0, NAN, 0)
	for attempt in 16: # a clearing big enough for the fire and the people around it
		pos = _ground(Vector3((cell.x + rng.randf_range(0.2, 0.8)) * cell_size, 0, (cell.y + rng.randf_range(0.2, 0.8)) * cell_size))
		if is_nan(pos.y) or pos.y < SEA_LEVEL + 1.5 or pos.y > MAX_HEIGHT:
			return # sea or mountain cell
		if not (trees and trees.tree_near(pos, clearing)):
			break
		pos.y = NAN
	if is_nan(pos.y):
		return
	var c := Camp.new()
	c.pos = pos
	var roll := rng.randf()
	c.kind = "bandit" if roll < bandit_chance else ("goblin" if roll < bandit_chance + goblin_chance else
		("orc" if roll < bandit_chance + goblin_chance + orc_chance else "drifter"))
	c.bandit = c.kind == "bandit"
	c.next_move = rng.randf_range(migrate_every.x, migrate_every.y)
	camps.append(c)
	_by_cell[cell] = c
	var size: Vector2i = {"drifter": Vector2i(people_min, people_max), "bandit": Vector2i(bandits_min, bandits_max),
		"goblin": Vector2i(goblins_min, goblins_max), "orc": Vector2i(orcs_min, orcs_max)}[c.kind]
	for i in rng.randi_range(size.x, maxi(size.x, size.y)):
		var f := Folk.new()
		f.camp = c
		f.home = _around(c.pos, rng)
		f.pos = f.home
		c.members.append(f)
		folk.append(f)

func _around(p: Vector3, rng: RandomNumberGenerator) -> Vector3:
	var a := rng.randf() * TAU
	return p + Vector3(cos(a), 0, sin(a)) * rng.randf_range(sit_radius_min, sit_radius_max)

func _process(_delta: float) -> void:
	if Engine.is_editor_hint():
		_editor_tick()
		return
	if camps.is_empty():
		return
	if not is_instance_valid(_player):
		_player = get_tree().get_first_node_in_group("player")
		if not _player:
			return
	var now := SimClock.now
	var at := _player.global_position
	for i in mini(records_per_frame, folk.size()):
		_folk_i = (_folk_i + 1) % folk.size()
		_tick_folk(folk[_folk_i], at, now)
	for i in mini(records_per_frame / 4, camps.size()):
		_camp_i = (_camp_i + 1) % camps.size()
		_tick_camp(camps[_camp_i], at, now)

func _tick_folk(f: Folk, at: Vector3, now: float) -> void:
	if f.dead:
		return
	var dt := now - f.ticked if f.ticked > 0.0 else 0.0
	f.ticked = now
	if f.node:
		if not is_instance_valid(f.node) or f.node.is_dead:
			var by_player := true # killed while not fighting another NPC: it was you
			if is_instance_valid(f.node):
				var foe = f.node.get_node("mobAI").get("foe")
				by_player = not is_instance_valid(foe)
			f.dead = true # killed: stays gone (its corpse cleans itself up)
			f.node = null
			if minds:
				minds.on_death(f, by_player)
			return
		f.pos = f.node.global_position
		if _dist(f.pos, at) > despawn_radius:
			f.home = _ai(f).get("_home")
			f.node.queue_free()
			f.node = null
		return
	if minds:
		minds.think(f, now)
		if f.node == null and f.dead:
			return
	var to := Vector3(f.home.x - f.pos.x, 0, f.home.z - f.pos.z) # off-screen: just walk straight home
	f.pos += to.limit_length(walk_speed * dt)
	if _dist(f.pos, at) < spawn_radius:
		_spawn(f)

func _spawn(f: Folk) -> void:
	var scene: PackedScene = {"drifter": drifter_scene, "bandit": bandit_scene, "goblin": goblin_scene, "orc": orc_scene}[f.camp.kind]
	var person: BaseCharacter = scene.instantiate()
	person.top_level = true
	person.position = _ground(f.pos) + Vector3.UP * 0.1
	person.rotation.y = randf() * TAU
	person.get_node("mobAI")._asleep = true # settles onto the ground once it's near the player
	add_child(person)
	person.get_node("mobAI")._home = f.home
	if f.name.is_empty():
		f.name = person.Name
	person.Name = f.name
	person.set_meta("folk", f) # lets their Talker keep jobs on the record
	f.node = person
	if enc and f.camp.wild != "":
		enc.on_spawn(f, person)
	if minds and minds.hates(f.camp):
		person.get_node("mobAI").aggressive = true # they remember what you did

func _ai(f: Folk) -> MobAIComponent:
	return f.node.get_node("mobAI") if f.node and is_instance_valid(f.node) and not f.node.is_dead else null

func _tick_camp(c: Camp, at: Vector3, now: float) -> void:
	if minds:
		minds.check_cold(c, now)
	if c.wild == "remains" or c.wild == "cairn":
		_tick_spot(c, at)
		return
	if enc and c.wild in enc.SPOTS:
		enc.tick_spot(c, at, now)
		return
	if enc and c.wild != "":
		enc.tick_people(c, at, now)
	if c.roaming:
		if c.raid:
			_tick_raid(c, now) # a war band mid-raid
		else:
			_tick_band(c, now)
		return
	var d := _dist(c.pos, at)
	if c.wild == "" and d < fire_radius and not is_instance_valid(c.fire):
		c.fire = fire_scene.instantiate()
		c.fire.top_level = true
		c.fire.position = c.pos
		add_child(c.fire)
		if c.kind == "drifter" or c.kind == "bandit":
			_dress(c, c.fire) # goblins and orcs don't keep barrels
	elif d > fire_radius * 1.2 and is_instance_valid(c.fire):
		c.fire.queue_free()
	if c.raid:
		_tick_raid(c, now)
		return
	# Group: one member fighting pulls in the rest of the camp.
	# Only camps near the player have members as nodes.
	var fighting := d < despawn_radius and c.members.any(func(f: Folk): return _ai(f) and _ai(f).state == MobAIComponent.State.CHASE)
	if fighting:
		for f: Folk in c.members:
			var ai := _ai(f)
			if ai and ai.state != MobAIComponent.State.CHASE:
				ai._enter(MobAIComponent.State.CHASE)
	# Group: drifter bands move on to another camp together; bandit bands go raiding one.
	elif now > c.next_move:
		c.next_move = now + randf_range(migrate_every.x, migrate_every.y)
		c.members = _alive(c.members)
		if c.members.is_empty() or c.kind == "goblin" or c.kind == "orc":
			return # monsters hold their ground
		if not c.bandit:
			_send_band(c, c.members, now)
			return
		if _rng.randf() < war_band_chance and c.members.size() >= 2:
			_send_band(c, c.members.slice(0, maxi(1, roundi(c.members.size() * war_band_share))), now)
			return
		var dest := _pick_camp(c)
		if dest and not _alive(dest.members).is_empty():
			for f: Folk in c.members:
				_send(f, dest.pos)
			c.raid = dest
			c.raid_since = now

## Splits `who` off camp c into a band that roams. Drifter bands settle at the first drifter fire they see;
## bandit war bands raid whatever camp they come across and keep roaming.
func _send_band(c: Camp, who: Array, now: float) -> void:
	var band := Camp.new()
	band.roaming = true
	band.kind = c.kind
	band.bandit = c.bandit
	band.from = c
	band.pos = c.pos
	band.heading = _rng.randf() * TAU
	band.members = who
	c.members = c.members.filter(func(f: Folk): return not f in who)
	for f: Folk in who:
		f.camp = band
	camps.append(band)
	_next_waypoint(band, now)

## A band on the move: walk waypoint to waypoint, roughly keeping a heading, until a fire comes into view.
func _tick_band(b: Camp, now: float) -> void:
	var alive := _alive(b.members)
	if alive.is_empty():
		camps.erase(b)
		return
	var lead: Folk = alive[0]
	if b.wild == "wanderer" and b.job.get("settles", false): # a wanderer who lost their camp looks for a new fire
		var home := _camp_near(lead.pos, fire_radius, b.from)
		if home:
			for f: Folk in alive:
				f.camp = home
				_send(f, home.pos)
			home.members.append_array(alive)
			camps.erase(b)
			return
	if b.wild != "": # lone wanderers and goblin packs just keep walking
		if enc and enc.steer_band(b, now):
			return
		if _dist(lead.pos, b.pos) < waypoint_reached or now - b.waypoint_since > waypoint_give_up:
			_next_waypoint(b, now)
		return
	if b.bandit:
		var prey := _prey_near(lead.pos, fire_radius, b.from)
		if prey:
			for f: Folk in alive:
				_send(f, prey.pos)
			b.raid = prey
			b.raid_since = now
		elif _dist(lead.pos, b.pos) < waypoint_reached or now - b.waypoint_since > waypoint_give_up:
			_next_waypoint(b, now)
		return
	var dest := _camp_near(lead.pos, fire_radius, b.from)
	if dest:
		for f: Folk in alive:
			f.camp = dest
			_send(f, dest.pos)
		dest.members.append_array(alive)
		camps.erase(b)
	elif _dist(lead.pos, b.pos) < waypoint_reached or now - b.waypoint_since > waypoint_give_up:
		_next_waypoint(b, now)

func _next_waypoint(b: Camp, now: float) -> void:
	var lead: Folk = _alive(b.members)[0]
	b.heading += _rng.randf_range(-heading_wobble, heading_wobble) + (PI * 0.5 if now - b.waypoint_since > waypoint_give_up else 0.0) # stuck: turn away
	var p := lead.pos + Vector3(cos(b.heading), 0, sin(b.heading)) * _rng.randf_range(waypoint_min, waypoint_max)
	var map := get_world_3d().navigation_map
	if lead.node and NavigationServer3D.map_get_iteration_id(map) > 0:
		p = NavigationServer3D.map_get_closest_point(map, p) # near the player: only somewhere they can actually walk
	p = _ground(p)
	b.waypoint_since = now
	if is_nan(p.y) or p.y < SEA_LEVEL + 1.5 or p.y > MAX_HEIGHT:
		b.heading += PI # sea or mountain ahead: turn back, try again next tick
		return
	b.pos = p
	for f: Folk in _alive(b.members):
		_send(f, p)

## Nearest drifter camp to pos within r (not `skip`).
func _camp_near(pos: Vector3, r: float, skip: Camp) -> Camp:
	var n := ceili(r / cell_size)
	var cell := Vector2i(floori(pos.x / cell_size), floori(pos.z / cell_size))
	var best: Camp = null
	for z in range(-n, n + 1):
		for x in range(-n, n + 1):
			var c: Camp = _by_cell.get(cell + Vector2i(x, z))
			if c and c != skip and c.kind == "drifter" and c.wild == "" and _dist(c.pos, pos) < r and (not best or _dist(c.pos, pos) < _dist(best.pos, pos)):
				best = c
	return best

func _tick_raid(c: Camp, now: float) -> void:
	var raiders := _alive(c.members)
	var defenders := _alive(c.raid.members)
	if raiders.is_empty() or defenders.is_empty() or now - c.raid_since > raid_time_limit:
		for f: Folk in raiders + defenders: # over: everyone stops fighting, raiders head home
			if _ai(f):
				_ai(f).foe = null
		for f: Folk in raiders:
			_send(f, c.pos)
		c.members = raiders
		c.raid.members = defenders
		if c.roaming:
			c.from = c.raid # a war band moves on rather than hitting the same camp again
		c.raid = null
		return
	if not raiders.any(func(f: Folk): return defenders.any(func(d: Folk): return _dist(f.pos, d.pos) < raid_arrive)):
		for f: Folk in raiders: # still on the way: keep heading for them (they may be walking)
			_send(f, defenders[0].pos)
		return
	if not (raiders + defenders).any(func(f: Folk): return f.node):
		# Off-screen: someone falls now and then; bandits are the better fighters.
		if _rng.randf() < raid_kill_chance:
			var victim: Folk = (defenders if _rng.randf() < bandit_win_chance else raiders).pick_random()
			victim.dead = true
			if minds:
				minds.on_death(victim, false)
		return
	for f: Folk in raiders:
		_set_foe(f, defenders)
	for f: Folk in defenders:
		_set_foe(f, raiders)

## Points f's character at the nearest living enemy (keeps its current one while that's still up).
func _set_foe(f: Folk, enemies: Array) -> void:
	var ai := _ai(f)
	if not ai:
		return
	if not (is_instance_valid(ai.foe) and not ai.foe.is_dead):
		ai.foe = null
		var best := INF
		for e: Folk in enemies:
			if e.node and is_instance_valid(e.node) and not e.node.is_dead and _dist(e.pos, f.pos) < best:
				best = _dist(e.pos, f.pos)
				ai.foe = e.node
	if ai.foe and ai.state != MobAIComponent.State.CHASE:
		ai._enter(MobAIComponent.State.CHASE)

## Walks f (record and character) to a new spot near pos.
func _send(f: Folk, pos: Vector3) -> void:
	f.home = _around(pos, _rng)
	var ai := _ai(f)
	if ai:
		ai._home = f.home
		ai._enter(MobAIComponent.State.RETURN)

func _alive(members: Array) -> Array:
	return members.filter(func(f: Folk): return not f.dead)

## Nearest bandit camp with anyone left in it, within r of pos (for bounty jobs). null if none.
func bandit_camp_near(pos: Vector3, r: float) -> Camp:
	var best: Camp = null
	for c in camps:
		if c.bandit and not c.roaming and c.wild == "" and _dist(c.pos, pos) < r and not _alive(c.members).is_empty():
			if not best or _dist(c.pos, pos) < _dist(best.pos, pos):
				best = c
	return best

## Nearest camp with people in it (not bandits, not `skip`) within r: a war band's next target.
func _prey_near(pos: Vector3, r: float, skip: Camp) -> Camp:
	var best: Camp = null
	for c in camps:
		if c != skip and not c.bandit and not c.roaming and c.wild == "" and _dist(c.pos, pos) < r and not _alive(c.members).is_empty():
			if not best or _dist(c.pos, pos) < _dist(best.pos, pos):
				best = c
	return best

func _pick_camp(from: Camp) -> Camp:
	var r := int(migrate_range / cell_size)
	var home := Vector2i(floori(from.pos.x / cell_size), floori(from.pos.z / cell_size))
	var options: Array[Camp] = []
	for z in range(-r, r + 1):
		for x in range(-r, r + 1):
			var c: Camp = _by_cell.get(home + Vector2i(x, z))
			if c and c != from and not c.bandit:
				options.append(c)
	return options.pick_random() if not options.is_empty() else null

func _ground(p: Vector3) -> Vector3:
	p.y = terrain.data.get_height(p)
	return p

func _dist(a: Vector3, b: Vector3) -> float:
	return Vector2(a.x - b.x, a.z - b.z).length()
