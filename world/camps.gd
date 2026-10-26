@tool
extends Node3D
## Every camp and person on the island, tracked as plain data so thousands cost almost nothing.
## Only people near the player exist as real nodes; the rest are records that move along cheaply
## (a slice of them per frame). Group AI works on the records, so it runs whether you're there or not:
##   - bands of drifters pack up now and then and roam (on the navmesh near the player) until they spot a fire, then go to it
##   - hit one member of a camp and the rest of the camp joins in
##   - bandit bands raid nearby drifter / goblin / orc camps (fought out for real near the player, by dice rolls
##     elsewhere), or send out war bands that roam the roads and hit whatever camp they come across
## Camp kinds: drifter, bandit, goblin, orc. Goblin and orc dens are hostile.
## Everyone is a character, and every character starts at a fire. What they're doing (living at a fire, wandering,
## mourning, on pilgrimage, taking tolls, lying in ambush, collapsed, hunting you, a war band, a goblin pack, an orc
## holding a false light, heading home) is just the state of the group they're in (Camp.wild), and they get into
## and out of each state by their needs, nature and circumstances (minds.gd, here, encounters.gd). Nobody is
## placed or removed by hand: new characters are pulled out of the dark toward lit fires and cairns (New
## characters sliders), monsters come back to their dens, and the dead stay dead.
## The world only places places (their own sparser grid, see the Places sliders): remains = an abandoned stash with
## a loot sack, cairn = a torch someone left burning (a little island of light, and it pulls lost souls in),
## hanged, cold fire, springs, ash fungus; plus bells and salt (world/encounters.gd, child node "encounters",
## which also runs the ash storm and the bleak states' rules).
## What people want and do (needs, traits, memories, reputation) is world/minds.gd (child "minds"); groups
## meeting each other (fights, sharing, merging, looting...) is world/meetings.gd (child "meetings").
## Food, water, wood: springs and ash fungus on the encounter grid, herds of greyhorns (game), copses of small trees
## (the only wood that cuts) and sap nodes on the giant trees (the only resin) are records too, with stocks that
## regrow; near you they're real things. Fires burn real wood and grow by tiers (camplife.gd).
## Real items: packs, camp barrels and crates, eating, drinking and chores are world/camplife.gd (child "camplife").
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
@export_range(0.0, 1.0, 0.01) var camp_chance := 0.48
## Chance a camp is bandits / goblins / orcs. Whatever's left over is drifters.
@export_range(0.0, 1.0, 0.01) var bandit_chance := 0.6
@export_range(0.0, 1.0, 0.01) var goblin_chance := 0.15
@export_range(0.0, 1.0, 0.01) var orc_chance := 0.08
## People per camp when the island is made (rolled per camp), by kind.
## Testing: the start scene's campfire becomes a drifter camp with start_people around it.
@export var start_camp := true
@export_range(0, 12) var start_people := 6
var _start_pos := Vector3(NAN, NAN, NAN)
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
## A wanderer looking for a home finds a cold fire's ring of ash this close, relights it and settles there.
@export_range(0.0, 2000.0, 10.0, "suffix:m") var coldfire_spot := 600.0
## Wanderers with a lit torch who've found no fire for this long make their own camp (not within fire_gap of another).
@export_range(30.0, 7200.0, 10.0, "suffix:s") var found_after := 240.0
@export_range(50.0, 3000.0, 10.0, "suffix:m") var fire_gap := 500.0
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
## A character near you snagged on something this long (making no headway toward where the sim sends them)
## steps past it, so loaded and unloaded people end up in the same places.
@export_range(1.0, 120.0, 1.0, "suffix:s") var unstick_after := 6.0
## Seconds between a camp thinking about moving on (drifters) or raiding (bandits): random in (min, max).
@export var migrate_every := Vector2(90, 300)
## When a drifter camp moves on, this many stay behind to keep the fire alive (0 = everyone leaves, the fire dies).
@export_range(0, 5) var keepers := 1

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
@export_range(0.0, 1.0, 0.01) var war_band_chance := 0.35
## ...made of this share of the camp (the rest stay home).
@export_range(0.1, 1.0, 0.05) var war_band_share := 0.5
## Bandits only raid camps within this (a war band raids whatever comes within fire_radius).
@export_range(100.0, 3000.0, 10.0, "suffix:m") var migrate_range := 850.0
## A raid is called off after this long.
@export_range(30.0, 1200.0, 10.0, "suffix:s") var raid_time_limit := 300.0
## The raid starts once a raider is this close to the target fire.
@export_range(5.0, 100.0, 1.0, "suffix:m") var raid_arrive := 20.0
## Far away (dice rolls): chance per camp tick that someone falls...
@export_range(0.0, 1.0, 0.01) var raid_kill_chance := 0.2
## A hungry den (less than a meal each in its larder) sends a pack to raid the nearest camp with meat in its crate
## at this chance per think.
@export_range(0.0, 1.0, 0.01) var den_raid_chance := 0.3
## Raiders carry off up to this many of each thing they want (coin: all of it).
@export_range(1, 20) var plunder_carry := 4
## ...and the chance it's a defender rather than a bandit.
@export_range(0.0, 1.0, 0.01) var bandit_win_chance := 0.6

## A war band heads home after this long out, or sooner once its water runs low.
@export_range(60.0, 3600.0, 10.0, "suffix:s") var war_band_time := 900.0
@export_range(0.0, 100.0, 1.0) var war_band_thirst := 50.0

@export_group("Monsters", "")
## When a goblin den acts, chance it sends out a hunting pack of this size (someone always stays home)...
@export_range(0.0, 1.0, 0.01) var pack_out_chance := 0.5
@export var pack_size := Vector2i(2, 3)
## In an ash storm dens send packs out this many times as often.
@export_range(1.0, 10.0, 0.5) var storm_packs := 3.0
## ...that roams this long (random in range) before going back.
@export var pack_roam_time := Vector2(300, 900)
## When an orc den acts, chance one goes out into the dark this far (random in range) to hold up a torch and wait:
## a false light. It waits this long for something to come to it, then goes home.
@export_range(0.0, 1.0, 0.01) var lure_chance := 0.35
@export var lure_distance := Vector2(250, 600)
@export_range(60.0, 3600.0, 10.0, "suffix:s") var lure_time := 900.0
## A den short of its full size grows by one when its larder holds this much raw meat (eaten up in the
## making), at most once per den_regrow. A den starts with den_start_meat per monster.
@export_range(1, 50) var breed_meat := 6
@export_range(30.0, 3600.0, 10.0, "suffix:s") var den_regrow := 400.0
@export_range(0, 20) var den_start_meat := 3
## A hungry pack smells game this far off and goes for it; with a kill it heads home to the den.
@export_range(50.0, 3000.0, 10.0, "suffix:m") var smell_range := 800.0

@export_group("Copses", "")
## Clumps of small dead trees: the only wood that cuts. This many on the island, of this many trees each; a felled
## tree grows back after copse_regrow (one at a time).
@export_range(0, 2000) var copses := 260
@export var copse_trees := Vector2i(3, 7)
## Sap nodes: where sap bleeds out of a giant tree's bark (the only place resin comes from; cut it with a knife).
## Up to this many, one per giant tree (giants = at least sap_giant times the base tree size). Stock: camplife SOURCES.
@export_range(0, 2000) var sap_nodes := 400
## Smoulders: old stumps still burning deep inside, a faint glow in the dark. Standing in it the dark holds off
## (your dread and theirs stops growing) but nothing is mended: no rest, no healing. A reprieve, that's all.
@export_range(0, 2000) var smoulders := 150
@export_range(1.0, 30.0, 0.5, "suffix:m") var smoulder_radius := 6.0
@export var sap_giant := 1.4
@export_range(60.0, 36000.0, 60.0, "suffix:s") var copse_regrow := 900.0
## Small trees are this size against the big ones' base size (random in range).
@export var sapling_scale := Vector2(0.9, 1.5)

@export_group("Game", "")
## Herds of game roam the dark: the meat everyone hunts. This many at the start, of this many head each.
@export_range(0, 300) var herds := 45
@export var herd_size := Vector2i(3, 7)
## Each herd breeds toward herd_cap: births per minute = herd_growth x head x (1 - head / herd_cap). A full herd
## splits in two, up to herds_max herds on the island. Hunted to nothing, a herd is gone.
@export_range(1, 50) var herd_cap := 12
@export_range(0.0, 1.0, 0.005) var herd_growth := 0.03
@export_range(1, 1000) var herds_max := 90
## A herd drifts this far (random in range) every minute or so.
@export var herd_drift := Vector2(15, 50)
## Near you a herd is real greyhorns (up to this many bodies; the rest of the herd is out of sight). They bolt
## from you once you're this close.
@export var greyhorn_scene: PackedScene = preload("res://characters/game/greyhorn.tscn")
@export_range(1, 30) var herd_show_max := 8
@export_range(2.0, 60.0, 1.0, "suffix:m") var flee_range := 18.0

@export_group("New characters", "")
## Lit fires and cairns pull lost souls out of the dark. The island tends toward this many human characters: the
## closer it is, the rarer new ones are; over it, nobody new comes.
@export_range(0, 2000) var souls_target := 220
## Seconds between chances of someone being pulled in.
@export_range(5.0, 600.0, 5.0, "suffix:s") var pull_every := 30.0
## They come up out of the dark this far from the light that pulls them (random in range), never near you.
## Keep it short: the dark wears them down on the way in as it would you.
@export var pull_distance := Vector2(30, 70)
## A body left lying where someone died far from you is gone after this long.
@export_range(60.0, 36000.0, 60.0, "suffix:s") var body_decay := 3600.0
## Share of new souls a bandit fire pulls in (they come as bandits); the rest go to drifter fires and cairns.
@export_range(0.0, 1.0, 0.05) var pull_bandit_share := 0.3

@export_group("Places", "")
## One place at most per cell this size; they're put in the dark between camps.
@export_range(50, 2000, 10, "suffix:m") var encounter_cell := 300
## Chance each land cell has a place.
@export_range(0.0, 1.0, 0.01) var encounter_chance := 0.42
## None closer than this to a camp fire (so the dark between camps stays dark).
@export_range(0.0, 1000.0, 10.0, "suffix:m") var encounter_camp_gap := 250.0
## Relative weights of each kind (they don't need to add up to anything).
@export_range(0.0, 10.0, 0.1) var remains_weight := 3.0
@export_range(0.0, 10.0, 0.1) var cairn_weight := 1.5
@export_range(0.0, 10.0, 0.1) var hanged_weight := 1.5
@export_range(0.0, 10.0, 0.1) var coldfire_weight := 1.0
## Food and water sources between the camps.
@export_range(0.0, 10.0, 0.1) var spring_weight := 2.0
@export_range(0.0, 10.0, 0.1) var fungus_weight := 2.5
## What a remains' loot sack can hold, and how many things (random in range).
@export var remains_loot: PackedStringArray = ["bread", "water_skin", "dried_meat", "torch", "health_potion", "stamina_potion", "coin", "coin", "rusty_sword", "leather_cap",
	"scrap_metal", "scrap_metal", "cloth", "bone", "sinew", "bone_knife"]
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
	var den: Camp # the camp a band belongs to and goes back to (war bands, packs, hunters, false lights)
	var heading := 0.0
	var waypoint_since := 0.0
	var rep := 0 # how this camp feels about the player (-100..100, see minds.gd)
	var empty_since := 0.0
	var barrel := {} # camplife.gd: water skins in the camp's barrel (item id -> count)
	var crate := {} # camplife.gd: food and goods in the camp's crate
	var stocked := false

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
	var task := {} # camplife.gd: a chore they're out doing (forage / water / supply / evacuate)
	var inv := {} # camplife.gd: what they carry (item id -> count)
	var history := [] # what they've been doing lately: [{t, text}] (shown on the watch camera)
	var packed := false
	var hp := 100.0 # health, 0-100 (near you their body's health tracks it too)
	var dark_s := 0.0 # seconds out of the light this time
	var skills := {} # camplife.gd gather(): woodcraft / foraging / hunting levels (1-100), raised by doing it
	var mp := 100.0 # magicka, 0-100 (their small magics cost it, as yours do; minds.gd refills it)
	var known := [] # minds.gd: places they remember, [place, where they think it is] (a little off, sometimes)

var camps: Array[Camp] = []
var _by_cell := {} # Vector2i -> Camp, for finding camps near a spot
var folk: Array[Folk] = []
var _player: Node3D
var _folk_i := 0
var _camp_i := 0
var _rng := RandomNumberGenerator.new()
var enc: Node # world/encounters.gd (runtime only)
var minds: Node # world/minds.gd (runtime only)
var camplife: Node # world/camplife.gd (runtime only)
var save: Node # world/saveGame.gd (runtime only)
## Everything noted on anyone lately, newest last: [{t, who, text}] (the watch camera's world log).
var world_log := []
const PERSON_LOG := 12
const WORLD_LOG := 40

## Notes something a person did, for their own log and (unless it's everyday stuff) the world log.
func note(f, text: String, worldwide := true) -> void:
	var e := {"t": SimClock.now, "text": text}
	f.history.append(e)
	if f.history.size() > PERSON_LOG:
		f.history.pop_front()
	if not worldwide:
		return
	world_log.append({"t": e.t, "who": f.name if f.name != "" else "someone", "text": text, "pos": f.pos, "ms": Time.get_ticks_msec()})
	if world_log.size() > WORLD_LOG:
		world_log.pop_front()

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
	camplife = load("res://world/camplife.gd").new()
	camplife.name = "camplife"
	add_child(camplife)
	var meetings: Node = load("res://world/meetings.gd").new()
	meetings.name = "meetings"
	add_child(meetings)
	fate = load("res://world/fate.gd").new() # rare things that befall any group
	fate.name = "fate"
	fate.camps = self
	add_child(fate)
	if start_camp: # the start scene's own campfire (nearest the middle) gives way to a real drifter camp there
		for n: Node3D in get_tree().get_nodes_in_group("campfire"):
			if n.owner and (is_nan(_start_pos.x) or n.global_position.length() < _start_pos.length()):
				_start_pos = n.global_position
				n.queue_free()
	_generate()
	save = load("res://world/saveGame.gd").new() # F5 save, F9 load, Shift+F9 a fresh island; autosaves and saves on quit
	save.name = "save"
	add_child(save)
	if not save.load_world(): # a saved island replaces the fresh one
		var names := RandomNumberGenerator.new()
		names.seed = 4242
		for f in folk: # every person gets a name of their own up front (monsters stay "Goblin" / "Orc")
			if not f.camp.kind in ["goblin", "orc"]:
				f.name = minds._unique_name(names, f.camp.kind == "bandit")
	print("Camps: %d camps, %d people (%d ms)" % [camps.size(), folk.size(), Time.get_ticks_msec() - t])
	var layer := CanvasLayer.new() # overhead debug map of the whole simulation (press M)
	var map: Control = preload("res://ui/simMap.gd").new()
	map.camps = self
	layer.add_child(map)
	layer.add_child(preload("res://ui/craftMenu.gd").new()) # C: crafting
	layer.add_child(preload("res://ui/controlsPanel.gd").new()) # F1: the controls
	add_child(layer)

func _generate() -> void:
	camps.clear()
	folk.clear()
	_by_cell.clear()
	var n := int(HALF_MAP * 2.0 / cell_size)
	for z in n:
		for x in n:
			_make_camp(Vector2i(x - n / 2, z - n / 2))
	if not is_nan(_start_pos.x):
		var s := Camp.new()
		s.pos = _ground(_start_pos)
		s.kind = "drifter"
		s.next_move = INF # it stays put
		camps.append(s)
		var rng := RandomNumberGenerator.new()
		rng.seed = 77
		for i in start_people:
			var f := Folk.new()
			f.camp = s
			f.home = _around(s.pos, rng)
			f.pos = f.home
			s.members.append(f)
			folk.append(f)
	var m := int(HALF_MAP * 2.0 / encounter_cell)
	for z in m:
		for x in m:
			_make_encounter(Vector2i(x - m / 2, z - m / 2))
	if enc:
		var rng := RandomNumberGenerator.new()
		rng.seed = 991
		enc.make_bells(rng)
		enc.make_old_world(rng)
		enc.make_salt(rng)
	var wood := RandomNumberGenerator.new()
	wood.seed = 2718
	var placed := 0
	for attempt in copses * 20:
		if placed >= copses:
			break
		var p := _ground(Vector3(wood.randf_range(-HALF_MAP, HALF_MAP), 0, wood.randf_range(-HALF_MAP, HALF_MAP)))
		if is_nan(p.y) or p.y < SEA_LEVEL + 1.5 or p.y > MAX_HEIGHT:
			continue
		var k := Camp.new()
		k.wild = "copse"
		k.pos = p
		k.next_move = INF
		var trees_n := wood.randi_range(copse_trees.x, maxi(copse_trees.x, copse_trees.y))
		k.job = {"count": trees_n, "max": trees_n}
		camps.append(k)
		placed += 1
	var ember := RandomNumberGenerator.new()
	ember.seed = 5150
	var lit := 0
	for attempt in smoulders * 20:
		if lit >= smoulders:
			break
		var sp := _ground(Vector3(ember.randf_range(-HALF_MAP, HALF_MAP), 0, ember.randf_range(-HALF_MAP, HALF_MAP)))
		if is_nan(sp.y) or sp.y < SEA_LEVEL + 1.5 or sp.y > MAX_HEIGHT:
			continue
		var sm := Camp.new()
		sm.wild = "smoulder"
		sm.pos = sp
		sm.next_move = INF
		camps.append(sm)
		lit += 1
	if trees and trees.is_node_ready():
		_make_sap()
	elif trees:
		trees.ready.connect(_make_sap, CONNECT_ONE_SHOT)
	var game := RandomNumberGenerator.new()
	game.seed = 4711
	var made := 0
	for attempt in herds * 20:
		if made >= herds:
			break
		var p := _ground(Vector3(game.randf_range(-HALF_MAP, HALF_MAP), 0, game.randf_range(-HALF_MAP, HALF_MAP)))
		if is_nan(p.y) or p.y < SEA_LEVEL + 1.5 or p.y > MAX_HEIGHT or camps.any(func(c: Camp): return c.wild == "" and _dist(c.pos, p) < encounter_camp_gap):
			continue
		_new_herd(p, game.randi_range(herd_size.x, maxi(herd_size.x, herd_size.y)))
		made += 1

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
	var weights := {"remains": remains_weight, "cairn": cairn_weight, "hanged": hanged_weight, "coldfire": coldfire_weight,
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
	c.next_move = INF # places never move or raid
	camps.append(c)

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
		remains_stock(c)
		var piece: Node3D = CLUTTER.build(rng, {"top_max": 2, "crates_max": 1, "leaners_max": 1, "floor_max": 4, "have": c.crate.keys()})
		c.fire.add_child(piece)
		for part in piece.get_children():
			if part is Node3D and (part.scene_file_path.contains("barrel") or part.scene_file_path.contains("crate")):
				_settle(part)
				_solid(part)
		_make_real(piece, c) # what's left lying about is what's really there: in the crates, or set out
	elif d > reach * 1.2 and is_instance_valid(c.fire):
		c.fire.queue_free()
	c.looted = c.stocked and c.crate.is_empty() and c.barrel.is_empty()

## What an abandoned stash holds, rolled once (same every run) the first time anyone comes to it, you or not.
func remains_stock(c: Camp) -> void:
	if c.stocked:
		return
	c.stocked = true
	var rng := RandomNumberGenerator.new()
	rng.seed = hash(Vector2i(roundi(c.pos.x), roundi(c.pos.z)))
	for k in rng.randi_range(remains_items.x, maxi(remains_items.x, remains_items.y)):
		var id: String = remains_loot[rng.randi() % remains_loot.size()]
		c.crate[id] = c.crate.get(id, 0) + (rng.randi_range(remains_coins.x, maxi(remains_coins.x, remains_coins.y)) if id == "coin" else 1)

## Turns a set piece real (in the game; in the editor it stays models): every barrel and crate in it becomes a
## container holding its share of the camp's barrel (water) or crate (food and goods), and every small thing on
## or around them (bottles, coins, daggers, staffs, swords) a pickup that shows only while the camp has one.
const DISPLAY := preload("res://world/props/campDisplay.gd")
func _make_real(piece: Node3D, c: Camp) -> void:
	if Engine.is_editor_hint():
		return
	for n: Node in piece.find_children("*", "Node3D", true, false):
		if n.has_meta("item"):
			var d: StaticBody3D = DISPLAY.new()
			d.record = c
			d.id = n.get_meta("item")
			d.take = 5 if d.id == "coin" else 1
			n.add_child(d)
		elif n is Node3D and (n.scene_file_path.contains("barrel") or n.scene_file_path.contains("crate")):
			var body: StaticBody3D = null
			for k in n.get_children():
				if k is StaticBody3D:
					body = k
			if not body:
				continue
			var chest: Node = CHEST.instantiate() # borrow a chest's container (and its UI) for this barrel or crate
			var inter: Node = chest.get_node("interactableComponent")
			chest.remove_child(inter)
			chest.free()
			var cont := inter.find_child("containerComponent", true, false)
			var nothing: Dictionary[String, int] = {}
			cont.starting_items = nothing
			var which := "barrel" if n.scene_file_path.contains("barrel") else "crate"
			(inter.get_node("prompt") as Label).text = "Water barrel" if which == "barrel" else "Supplies"
			body.add_child(inter)
			var sync: Node = load("res://world/props/campStoreSync.gd").new()
			sync.record = c
			sync.which = which
			body.add_child(sync)

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
	"scrap_metal", "scrap_metal", "bone_knife", "hatchet", "resin", "salt", "cloth",
	"bread", "dried_meat", "water_skin", "ash_wine", "ash_wine"]

func _dress(c: Camp, fire: Node3D) -> void:
	if camplife and not Engine.is_editor_hint():
		camplife.stock(c) # so what's set out is what they have
	var rng := RandomNumberGenerator.new()
	rng.seed = hash(Vector2i(roundi(c.pos.x), roundi(c.pos.z)))
	var kinds: Array[String] = ["clutter"]
	if rng.randf() < second_piece_chance:
		kinds.append("clutter")
	if c.bandit:
		kinds.append("chest")
	if c.kind == "drifter" or c.kind == "bandit":
		kinds.append("barrel") # the camp's water, a real container
	if c.kind == "drifter":
		kinds.append("crate") # its food and goods (a bandit camp's chest is theirs)
	var a0 := rng.randf() * TAU
	for i in kinds.size():
		var a := a0 + TAU * i / kinds.size() + rng.randf_range(-0.3, 0.3)
		var spot := Node3D.new()
		var footprint := 0.8 if kinds[i] == "chest" else 2.0
		spot.position = _flat_spot(c.pos + Vector3(cos(a), 0, sin(a)) * rng.randf_range(clutter_radius_min, clutter_radius_max), footprint) - c.pos
		spot.rotation.y = a + PI * 0.5 + rng.randf_range(-0.4, 0.4) # side-on to the fire, like it was set down there
		fire.add_child(spot)
		if kinds[i] == "barrel" or kinds[i] == "crate":
			if camplife:
				camplife.stock(c)
			spot.add_child(_store(c, kinds[i]))
			continue
		var n: Node3D = CHEST.instantiate() if kinds[i] == "chest" else CLUTTER.build(rng, {"barrel_chance": barrel_chance, "top_min": top_items_min,
			"top_max": top_items_max, "crates_max": crates_max, "stack_chance": stack_chance,
			"leaners_max": leaners_max, "floor_max": floor_items_max, "have": [] if Engine.is_editor_hint() else c.crate.keys()})
		spot.add_child(n)
		for part in n.get_children():
			if part is Node3D and (part.scene_file_path.contains("barrel") or part.scene_file_path.contains("crate")):
				_settle(part)
				_solid(part)
				for top: Node in part.get_children():
					if top.scene_file_path.contains("crate"):
						_solid(top) # stacked crate
		if kinds[i] == "clutter":
			_make_real(n, c)
		if kinds[i] == "chest":
			var db = get_node_or_null("/root/item_list")
			var inv = n.find_child("inventoryComponent", true, false)
			if db and inv and not Engine.is_editor_hint():
				inv.inventory.clear() # the chest scene comes stocked for the start scene; bandits keep their own
				for k in rng.randi_range(chest_items_min, chest_items_max):
					inv.add_item(db.get_item_instance(BANDIT_LOOT[rng.randi() % BANDIT_LOOT.size()]), 1)
				inv.add_item(db.get_item_instance("coin"), rng.randi_range(chest_coins_min, maxi(chest_coins_min, chest_coins_max)))
			if camplife and not Engine.is_editor_hint(): # the bandits' chest is their crate too: the sim keeps it, you see it
				camplife.stock(c)
				var sync: Node = load("res://world/props/campStoreSync.gd").new()
				sync.record = c
				sync.which = "crate"
				sync.absorb = not c.job.has("chest_filled") # its first loot roll becomes theirs; after that the record rules
				c.job["chest_filled"] = true
				n.add_child(sync)

## A camp's barrel or crate: a chest (container + UI) wearing a barrel or crate model, kept in sync with the
## camp's record by world/props/campStore.gd.
func _store(c: Camp, which: String, chest: Node3D = null) -> Node3D:
	var n: Node3D = chest if chest else CHEST.instantiate()
	var cont := n.find_child("containerComponent", true, false)
	if cont and not chest:
		var nothing: Dictionary[String, int] = {}
		cont.starting_items = nothing # the chest scene comes stocked for the start scene
	if not chest:
		var looks := n.get_node_or_null("meshInstance3D")
		if looks:
			looks.visible = false
		var model: Node3D = load("res://assets/models/%s.glb" % ("barrel" if which == "barrel" else "crate")).instantiate()
		model.position = Vector3.UP * (0.6 if which == "barrel" else 0.5)
		model.scale = Vector3.ONE * (0.6 if which == "barrel" else 0.5)
		n.add_child(model)
	var prompt := n.find_child("prompt", true, false) as Label
	if prompt:
		prompt.text = "Water barrel" if which == "barrel" else "Supplies"
	var sync: Node = load("res://world/props/campStoreSync.gd").new()
	sync.record = c
	sync.which = which
	n.add_child(sync)
	return n

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
	if now > _next_pull:
		_next_pull = now + pull_every
		_pull(at, now)

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
				if not by_player and foe.has_meta("folk"):
					_feed(foe.get_meta("folk"), f) # a real fight near you feeds the winner just like one far off
			f.dead = true # killed: stays gone (its corpse cleans itself up)
			f.node = null
			if minds:
				minds.on_death(f, by_player)
			return
		_hp_from_body(f) # hurt near you stays hurt
		_pose(f)
		var held := _ai(f)
		if held and held._asleep: # loaded but too far to move itself: it walks the sim's walk, so it never stalls
			var step := _walk(f.pos, f.home, dt)
			if step.length() > 0.01:
				f.node.global_position = _ground(f.pos + step) + Vector3.UP * 0.1
		elif held and held.state != MobAIComponent.State.CHASE and _dist(f.pos, f.home) > held.wander_radius * 2.0:
			# Awake but away from where the sim says they're going: head there, and if they're snagged on
			# something for a while, they find a way round (step along the sim's walk).
			if held.state != MobAIComponent.State.RETURN:
				held._home = f.home
				held._enter(MobAIComponent.State.RETURN)
			var d := _dist(f.pos, f.home)
			var best: float = f.node.get_meta("best_d", INF)
			if d < best - 1.0:
				f.node.set_meta("best_d", d)
				f.node.set_meta("best_t", now)
			elif now - f.node.get_meta("best_t", now) > unstick_after:
				f.node.global_position = _ground(f.pos + Vector3(f.home.x - f.pos.x, 0, f.home.z - f.pos.z).limit_length(4.0)) + Vector3.UP * 0.1
				f.node.set_meta("best_t", now)
		f.pos = f.node.global_position
		if minds:
			minds.think(f, now) # needs run near you too, not just off-screen
			if f.node == null or f.dead:
				return
			_hp_to_body(f) # the dark or hunger hurt them: so does the body
		if camplife and not f.task.is_empty():
			camplife.step(f, now) # chores are walked out for real near you
		if _dist(f.pos, at) > despawn_radius:
			f.home = _ai(f).get("_home")
			f.node.queue_free()
			f.node = null
		return
	if minds:
		minds.think(f, now)
		if f.node == null and f.dead:
			return
	if camplife and not f.task.is_empty():
		camplife.step(f, now)
	f.pos += _walk(f.pos, f.home, dt) # off-screen: walk home the same way a body would (round the trees)
	if _dist(f.pos, at) < spawn_radius and f.camp.wild != "falselight": # the false light's holder is unseen until it springs
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
	if f.name.is_empty(): # someone new since the start (a monster, or the sim made them): give them a name
		f.name = minds._unique_name(_rng, f.camp.kind == "bandit") if minds and not f.camp.kind in ["goblin", "orc"] else person.Name
	person.Name = f.name
	person.set_meta("folk", f) # lets their Talker keep jobs on the record
	_hp_to_body(f)
	var wares: Node = person.get_node_or_null("talker/wares")
	if wares: # a trader sells what they really have: their camp's crate, or their pack on the road
		var nothing: Dictionary[String, int] = {}
		wares.starting_items = nothing
		wares.get_node("inventoryComponent").inventory.clear()
		var sync: Node = load("res://world/props/campStoreSync.gd").new()
		sync.record = f.camp if f.camp.wild == "" and not f.camp.roaming else f
		sync.which = "crate" if f.camp.wild == "" and not f.camp.roaming else "pack"
		sync.whole = true
		wares.add_child(sync)
	var dummy := person.get_node_or_null("dummy")
	if dummy:
		var carried: Dictionary[String, int] = {}
		if f.camp.kind in ["goblin", "orc"]:
			carried[f.camp.kind + "_carcass"] = 1 # their body
		for id in f.inv: # what they really carry is what they drop
			carried[id] = carried.get(id, 0) + f.inv[id]
		dummy.loot = carried
		dummy.exact_loot = true
	f.node = person
	if enc and f.camp.wild != "":
		enc.on_spawn(f, person)
	person.get_node("mobAI").sim_speed = walk_speed # walks at the record's pace
	if f.camp.job.get("player_member", false):
		person.get_node("mobAI").aggressive = false # you're one of them
	if minds and minds.hates(f.camp):
		person.get_node("mobAI").aggressive = true # they remember what you did

func _ai(f: Folk) -> MobAIComponent:
	return f.node.get_node("mobAI") if f.node and is_instance_valid(f.node) and not f.node.is_dead else null

func _tick_camp(c: Camp, at: Vector3, now: float) -> void:
	if c.wild == "herd":
		_tick_herd(c, at, now)
		return
	if c.wild == "copse":
		_tick_copse(c, at, now)
		return
	if c.wild == "sap":
		_tick_sap(c, at)
		return
	if c.wild == "smoulder":
		_tick_smoulder(c, at)
		return
	if minds:
		minds.check_cold(c, now)
	if c.wild == "sack":
		_tick_sack(c, at)
		return
	if c.wild == "starved_dead" and now - c.job.get("since", now) > body_decay:
		if is_instance_valid(c.fire):
			c.fire.queue_free()
		camps.erase(c) # the ash takes it
		return
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
		if c.kind == "drifter" or c.kind == "bandit": # their fire burns their wood, and you can feed it
			c.fire.set_script(FIRE_FEED)
			c.fire.record = c
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
		if c.members.is_empty():
			return
		if c.kind == "goblin" or c.kind == "orc":
			_den_acts(c, now)
			return
		# Nobody sets out for anywhere their light won't get them (a torch's worth of walking: _reach()).
		if not c.bandit:
			var to := _camp_near(c.pos, _reach(c), c, minf(coldfire_spot, _reach(c)))
			if to and c.members.size() > keepers: # someone always stays to keep the fire; the rest move on
				_send_band(c, c.members.slice(keepers), now)
				var band: Camp = camps[-1]
				band.job["settle_at"] = to
				band.pos = to.pos
				for f: Folk in band.members:
					_send(f, to.pos)
			return
		var prey := _prey_near(c.pos, _reach(c), c)
		var short: bool = camplife and (camplife.count_food(c.crate) < c.members.size() or c.barrel.get("water_skin", 0) < c.members.size())
		if prey and _rng.randf() < war_band_chance * (2.0 if short else 1.0) and c.members.size() >= 2: # short of food or water: they go and take it
			_send_band(c, c.members.slice(0, maxi(1, roundi(c.members.size() * war_band_share))), now)
			var band: Camp = camps[-1]
			band.raid = prey
			band.raid_since = now
			for f: Folk in band.members:
				_send(f, prey.pos)
			return
		var dest := _pick_camp(c)
		if dest and _dist(dest.pos, c.pos) < _reach(c) and not _alive(dest.members).is_empty():
			for f: Folk in c.members:
				_send(f, dest.pos)
			c.raid = dest
			c.raid_since = now

## Raiders carry off what's worth it to their kind, as much as each can carry (plunder_carry of each thing):
## bandits coin, food, water, wood, torches and resin; goblins and orcs meat. It goes home with them (their camp or
## den's stores, _tick_homeward).
func _plunder(target: Camp, raiders: Array) -> void:
	var monster: bool = raiders[0].camp.kind in ["goblin", "orc"]
	var wants: Array = ["raw_meat", "dried_meat", "blackflesh"] if monster else ["coin", "water_skin", "ash_wood", "torch", "resin"]
	for r: Folk in raiders:
		for id in wants:
			var from: Dictionary = target.barrel if id == "water_skin" else target.crate
			camplife.move(from, r.inv, id, mini(from.get(id, 0), 999 if id == "coin" else plunder_carry))
		if not monster:
			for k in plunder_carry: # and food, the best first
				var id: String = camplife._best(target.crate, false)
				if id == "":
					break
				camplife.move(target.crate, r.inv, id, 1)

## How far anyone sets out from a fire: what the torches they take for the road light them for (camplife
## road_torches, a bandit's brands burn longer), with some to spare. (One torch's worth was shorter than the
## distance between most camps: bandits never found anyone to raid and nobody moved.)
func _reach(c: Camp = null) -> float:
	if not camplife:
		return float(fire_radius)
	return (camplife.torch_time(c) if c else camplife.npc_torch_time) * walk_speed * 0.8 * maxi(1, camplife.road_torches)

## Splits `who` off camp c into a band that roams. Drifter bands settle at the first drifter fire they see;
## bandit war bands raid whatever camp they come across and keep roaming.
func _send_band(c: Camp, who: Array, now: float) -> void:
	var band := Camp.new()
	band.roaming = true
	band.kind = c.kind
	band.bandit = c.bandit
	band.from = c
	band.den = c
	band.job["out_since"] = now
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
	if camplife and b.kind in ["drifter", "bandit"]:
		camplife.tend_torch(b, alive, now) # their light burns whatever they're doing
		if b.raid == null and camplife.need_light(b, alive, now):
			return # light first, whatever they were about
	if b.wild == "homeward":
		var parched: bool = camplife and minf(camplife._avg(alive, "water"), camplife._avg(alive, "food")) < 30.0
		if (parched or b.job.has("goal")) and b.raid == null and camplife.steer(b, now):
			return # on the way, if it's bad, they go for water or food first
		_tick_homeward(b, alive, now)
		return
	if b.wild == "lurer": # an orc walking out to hold a false light
		if _dist(lead.pos, b.pos) < waypoint_reached or now - b.waypoint_since > waypoint_give_up:
			b.wild = "falselight"
			b.roaming = false
			b.pos = lead.pos
			b.job["until"] = now + lure_time
		return
	if b.wild == "pack" and _pack_hunts(b, alive, now):
		return
	if b.wild == "pack" and now > b.job.get("until", INF):
		_go_home(b, now)
		return
	# A drifter band on the move, or a wanderer, settles at the first fire it finds (and can leave again: minds.gd).
	if (b.kind == "drifter" and b.wild in ["", "wanderer"] or b.kind == "bandit" and b.wild == "wanderer") and b.raid == null:
		var home: Camp = b.job.get("settle_at") if b.job.get("settle_at") in camps else _camp_near(lead.pos, minf(fire_radius, _reach()), b.from, minf(coldfire_spot, _reach()) if can_light(b) else 0.0, b.kind)
		if home and _dist(lead.pos, home.pos) > 15.0: # seen it: walk there together (with their torch) before joining
			if b.job.get("settle_at") != home or now - b.waypoint_since > waypoint_give_up:
				b.job["settle_at"] = home
				b.pos = home.pos
				b.waypoint_since = now
				for f: Folk in alive:
					_send(f, home.pos)
			if camplife and minf(camplife._avg(alive, "water"), camplife._avg(alive, "food")) < 30.0 and camplife.steer(b, now):
				pass # parched on the way: water or food first
			return
		if home:
			if not _relight(home, lead):
				return
			for f: Folk in alive:
				f.camp = home
				_send(f, home.pos)
			home.members.append_array(alive)
			camps.erase(b)
			return
		if not b.job.has("wander_since"):
			b.job["wander_since"] = now
		elif now - b.job.wander_since > found_after and can_light(b) and _room_for_fire(lead.pos):
			_found_camp(b, alive, now) # no fire anywhere near: they make one with the torch they carry
			return
	if camplife and b.raid == null and camplife.steer(b, now):
		return # travellers going for a fire, water or food (torches, survival: camplife.gd)
	if b.wild != "": # lone wanderers and goblin packs just keep walking
		if enc and enc.steer_band(b, now):
			return
		if _dist(lead.pos, b.pos) < waypoint_reached or now - b.waypoint_since > waypoint_give_up:
			_next_waypoint(b, now)
		return
	if b.bandit:
		if b.den and (now - b.job.get("out_since", now) > war_band_time or camplife and camplife._avg(alive, "water") < war_band_thirst):
			_go_home(b, now) # out too long, or the water's running out
			return
		var prey := _prey_near(lead.pos, fire_radius, b.from)
		if prey:
			for f: Folk in alive:
				_send(f, prey.pos)
			b.raid = prey
			b.raid_since = now
		elif _dist(lead.pos, b.pos) < waypoint_reached or now - b.waypoint_since > waypoint_give_up:
			_next_waypoint(b, now)
		return
	if _dist(lead.pos, b.pos) < waypoint_reached or now - b.waypoint_since > waypoint_give_up:
		_next_waypoint(b, now)

## Wanderers who've found no fire make their own: a new drifter camp where they stand, stocked with what they
## carry (they keep one of each for themselves).
func _found_camp(b: Camp, alive: Array, now: float) -> void:
	var c := Camp.new()
	c.kind = b.kind
	c.bandit = b.bandit
	c.pos = _ground(alive[0].pos)
	if not _light(c, b, now):
		return
	c.next_move = now + _rng.randf_range(migrate_every.x, migrate_every.y)
	c.stocked = true
	camps.append(c)
	for f: Folk in alive:
		f.camp = c
		_send(f, c.pos)
		if camplife:
			for id in f.inv.keys():
				if id == "water_skin":
					camplife.move(f.inv, c.barrel, id, f.inv[id] - 1)
				elif camplife.nourish(id).x > 0.0:
					camplife.move(f.inv, c.crate, id, f.inv[id] - 1)
	c.members.append_array(alive)
	camps.erase(b)
	note(alive[0], "found no fire, so they made one and stayed")

## Somewhere a new fire can go: on land, low enough, and not crowding another fire or place.
func _room_for_fire(p: Vector3) -> bool:
	var g := _ground(p)
	if is_nan(g.y) or g.y < SEA_LEVEL + 1.5 or g.y > MAX_HEIGHT:
		return false
	for c in camps:
		if not c.roaming and (c.wild == "" or c.wild == "coldfire") and _dist(c.pos, p) < fire_gap:
			return false
	if camplife: # nobody makes a fire where there's no water to be had
		for c in camps:
			if c.wild == "spring" and _dist(c.pos, p) < camplife.spring_range:
				return true
		return false
	return true

const FIRE_FEED := preload("res://world/props/fireFeed.gd")
const SMALL_TREE := preload("res://world/props/smallTree.gd")
const SAP_NODE := preload("res://world/props/sapNode.gd")
var fate: Node # world/fate.gd
var _sapling_meshes: Array[Mesh] = []

## One sap node on each giant tree (up to sap_nodes), on the trunk's south face.
func _make_sap() -> void:
	if camps.any(func(c): return c.wild == "sap"):
		return # a loaded island has its own
	var made := 0
	for cell in trees._trunks:
		for t: Vector4 in trees._trunks[cell]:
			if made >= sap_nodes:
				return
			if t.w >= sap_giant * trees.tree_scale:
				var k := Camp.new()
				k.wild = "sap"
				k.pos = Vector3(t.x, t.y, t.z)
				k.next_move = INF
				k.job = {"r": t.w}
				camps.append(k)
				made += 1

## Near you a sap node is a real thing on the bark (world/props/sapNode.gd).
func _tick_sap(c: Camp, at: Vector3) -> void:
	if _dist(c.pos, at) > spawn_radius:
		if is_instance_valid(c.fire):
			c.fire.queue_free()
		return
	if is_instance_valid(c.fire):
		return
	var body: StaticBody3D = SAP_NODE.new()
	body.record = c
	body.top_level = true
	body.position = c.pos + Vector3(0, 1.5, c.job.get("r", 1.0) * 0.55) # on the bark, chest high
	var mesh := MeshInstance3D.new()
	var ball := SphereMesh.new()
	ball.radius = 0.18
	ball.height = 0.3
	mesh.mesh = ball
	body.add_child(mesh)
	var shape := CollisionShape3D.new()
	var s := SphereShape3D.new()
	s.radius = 0.3
	shape.shape = s
	body.add_child(shape)
	add_child(body)
	c.fire = body

## Near you a smoulder is a charred stump with a low glow: an unshadowed light (cheap), and the "reprieve" group
## (DarknessComponent: its light_radius holds the dark off).
func _tick_smoulder(c: Camp, at: Vector3) -> void:
	if _dist(c.pos, at) > spawn_radius:
		if is_instance_valid(c.fire):
			c.fire.queue_free()
		return
	if is_instance_valid(c.fire):
		return
	var n := Node3D.new()
	n.top_level = true
	n.position = c.pos
	n.add_to_group("reprieve")
	n.set_meta("light_radius", smoulder_radius)
	var stump := MeshInstance3D.new()
	var cyl := CylinderMesh.new()
	cyl.top_radius = 0.35
	cyl.bottom_radius = 0.55
	cyl.height = 0.7
	cyl.radial_segments = 6
	stump.mesh = cyl
	stump.position.y = 0.3
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color(0.06, 0.04, 0.03)
	mat.emission_enabled = true
	mat.emission = Color(0.9, 0.3, 0.05)
	mat.emission_energy_multiplier = 0.4 # embers in the cracks
	stump.material_override = mat
	n.add_child(stump)
	var glow := OmniLight3D.new()
	glow.light_color = Color(1.0, 0.45, 0.15)
	glow.light_energy = 1.2
	glow.omni_range = smoulder_radius * 1.5
	glow.shadow_enabled = false
	glow.position.y = 0.8
	glow.distance_fade_enabled = true # far ones cost nothing
	glow.distance_fade_begin = 60.0
	glow.distance_fade_length = 20.0
	n.add_child(glow)
	add_child(n)
	c.fire = n

## A copse: its felled trees grow back one at a time; near you its standing trees are real (cut them for wood).
func _tick_copse(c: Camp, at: Vector3, now: float) -> void:
	var j := c.job
	if j.count < j.max:
		if not j.has("grow_at"):
			j["grow_at"] = now + copse_regrow
		elif now > j.grow_at:
			j.count += 1
			j.erase("grow_at")
	var d := _dist(c.pos, at)
	if d < spawn_radius and trees and trees.bark_mat:
		if is_instance_valid(c.fire) and c.fire.get_child_count() != j.count:
			c.fire.queue_free() # trees cut or grown since: build it again
			c.fire = null
		if not is_instance_valid(c.fire):
			c.fire = Node3D.new()
			c.fire.top_level = true
			c.fire.position = c.pos
			add_child(c.fire)
			if _sapling_meshes.is_empty():
				for v in 4:
					_sapling_meshes.append(trees.make_tree(9100 + v))
			var rng := RandomNumberGenerator.new()
			rng.seed = hash(Vector2i(roundi(c.pos.x), roundi(c.pos.z)))
			for i in j.max:
				var a := rng.randf() * TAU
				var spot := _ground(c.pos + Vector3(cos(a), 0, sin(a)) * rng.randf_range(2.0, 12.0))
				var sc := rng.randf_range(sapling_scale.x, sapling_scale.y)
				var yaw := rng.randf() * TAU
				if i >= j.count:
					continue # felled
				var body: StaticBody3D = SMALL_TREE.new()
				body.record = c
				body.position = spot - c.pos
				body.rotation.y = yaw
				var mesh := MeshInstance3D.new()
				mesh.mesh = _sapling_meshes[i % _sapling_meshes.size()]
				mesh.material_override = trees.bark_mat
				mesh.scale = Vector3.ONE * sc
				body.add_child(mesh)
				var shape := CollisionShape3D.new()
				var cap := CapsuleShape3D.new()
				cap.radius = 0.35 * sc
				cap.height = 3.5 * sc
				shape.shape = cap
				shape.position = Vector3.UP * cap.height * 0.5
				body.add_child(shape)
				c.fire.add_child(body)
	elif d > spawn_radius * 1.2 and is_instance_valid(c.fire):
		c.fire.queue_free()

## A camp's fire has gone out (no wood): it's a cold fire now, and its people take up their things and go looking for
## another fire (they'll relight this one if they come back with wood and a flame).
func fire_out(c: Camp, now: float) -> void:
	if is_instance_valid(c.fire):
		c.fire.queue_free()
	c.wild = "coldfire"
	c.job["went_out"] = true
	c.job["out_at"] = now
	c.job.erase("fire_fuel")
	var alive := _alive(c.members)
	if alive.is_empty():
		return
	note(alive[0], "let the fire die. They gathered what they could carry and left to find another")
	_send_band(c, alive, now)

## Ash wood among a group's packs.
func _wood_in(people: Array) -> int:
	var n := 0
	for f in people:
		n += f.inv.get("ash_wood", 0)
	return n

## A group can light a fire if they've a spark (a torch burning, or a flint), tinder, kindling and light_logs logs.
func can_light(b: Camp) -> bool:
	var p := _alive(b.members)
	var has := func(id): return p.any(func(f): return f.inv.get(id, 0) > 0)
	return (b.job.get("fuel", 0.0) > 0.0 or has.call("flint")) and _wood_in(p) >= 1 and has.call("tinder") and has.call("kindling")

## Lights a fire at `home` with the group's flame and two of their logs.
## Their spark, tinder, kindling and up to light_logs logs (one will do: a small fire to start). False = it didn't catch (the tinder's spent) or they lack the makings.
func _light(home: Camp, b: Camp, now: float) -> bool:
	if not camplife:
		return true
	var embers: bool = camplife.embers(home)
	if not embers and not can_light(b):
		return false
	var spend := func(id: String, k: int):
		for f in _alive(b.members):
			var m: int = mini(k, f.inv.get(id, 0))
			camplife.add(f.inv, id, -m)
			k -= m
	if not embers:
		spend.call("tinder", 1)
	if not camplife.catches(home):
		note(_alive(b.members)[0], "struck and blew on the tinder, but the fire wouldn't take", false)
		return false
	spend.call("kindling", 1)
	home.job["lit_at"] = now
	home.job.erase("out_at")
	var need: int = camplife.light_logs
	for f in _alive(b.members):
		var k: int = mini(need, f.inv.get("ash_wood", 0))
		if k > 0 and camplife:
			camplife.add(f.inv, "ash_wood", -k)
			need -= k
	home.job["fire_fuel"] = (camplife.light_logs - need) * camplife.wood_burn # what they had on hand
	home.job["fire_at"] = now
	home.job.erase("went_out")
	return true

## A goblin den sends out a hunting pack, an orc den sends one out to hold a false light. Short of its full size,
## a den grows by one now and then.
func _den_acts(c: Camp, now: float) -> void:
	var n := c.members.size()
	var full: int = goblins_max if c.kind == "goblin" else orcs_max
	if not c.stocked:
		c.stocked = true
		c.crate["raw_meat"] = n * den_start_meat
	var meat: int = c.crate.get("raw_meat", 0)
	if n < full and meat >= breed_meat and now - c.job.get("grew", 0.0) > den_regrow:
		c.job["grew"] = now
		c.crate["raw_meat"] = meat - breed_meat # fed well enough to bring up another
		var f := Folk.new()
		f.camp = c
		f.home = _around(c.pos, _rng)
		f.pos = f.home
		c.members.append(f)
		folk.append(f)
	var hungry := meat < n # less than a meal each in the larder: they go hunting
	if hungry and n >= 2 and _rng.randf() < den_raid_chance:
		var mark: Camp = null # a camp of people with meat in its crate, within the pack's range
		for o in camps:
			if o.wild == "" and not o.roaming and o.kind in ["drifter", "bandit"] and o.stocked and _dist(o.pos, c.pos) < fire_radius * 3.0 \
					and o.crate.get("raw_meat", 0) + o.crate.get("dried_meat", 0) >= 2 and not _alive(o.members).is_empty() \
					and (mark == null or _dist(o.pos, c.pos) < _dist(mark.pos, c.pos)):
				mark = o
		if mark:
			_send_band(c, c.members.slice(0, maxi(2, mini(n - 1, pack_size.y))), now)
			var b: Camp = camps[-1]
			b.wild = "pack"
			b.job["until"] = now + pack_roam_time.y
			b.raid = mark
			b.raid_since = now
			for f: Folk in b.members:
				_send(f, mark.pos)
			return
	var storm: float = storm_packs if enc and enc._storming else 1.0 # the ash storm brings them out
	if (c.kind == "goblin" or hungry) and n >= (1 if hungry else 2) and _rng.randf() < pack_out_chance * (2.0 if hungry else 1.0) * storm:
		var k := maxi(1, mini(n - (0 if hungry and n == 1 else 1), _rng.randi_range(pack_size.x, maxi(pack_size.x, pack_size.y))))
		_send_band(c, c.members.slice(0, k), now)
		var b: Camp = camps[-1]
		b.wild = "pack"
		b.job["until"] = now + _rng.randf_range(pack_roam_time.x, pack_roam_time.y)
	elif c.kind == "orc" and _rng.randf() < lure_chance and not camps.any(func(o: Camp): return o.den == c and o.wild in ["lurer", "falselight"]):
		_send_band(c, c.members.slice(0, 1), now)
		var b: Camp = camps[-1]
		b.wild = "lurer"
		var a := _rng.randf() * TAU
		var p := _ground(c.pos + Vector3(cos(a), 0, sin(a)) * _rng.randf_range(lure_distance.x, lure_distance.y))
		if is_nan(p.y) or p.y < SEA_LEVEL + 1.5:
			p = c.pos
		b.pos = p
		for f: Folk in b.members:
			_send(f, p)
		b.waypoint_since = now

## A hungry pack goes for the nearest herd it can smell; at it, they kill what they can and take the meat home.
## True = this handled the pack's move.
func _pack_hunts(b: Camp, alive: Array, now: float) -> bool:
	if b.job.get("fed", false) or not minds or minds._avg_food(alive) > minds.monster_eat_below + 20.0:
		return false
	var herd: Camp = b.job.get("prey") if b.job.get("prey") in camps else null
	if not herd:
		for c in camps:
			if c.wild == "herd" and _dist(c.pos, alive[0].pos) < smell_range and (not herd or _dist(c.pos, alive[0].pos) < _dist(herd.pos, alive[0].pos)):
				herd = c
		if not herd and minds: # nothing on the wind: a herd they remember
			var k: Array = minds.recall(alive, "herd", alive[0].pos, smell_range * 4.0)
			if not k.is_empty():
				herd = k[0]
		if not herd:
			return false
		b.job["prey"] = herd
	if _dist(alive[0].pos, herd.pos) > 15.0:
		if now - b.waypoint_since > 10.0: # keep after it, it moves
			b.waypoint_since = now
			b.pos = herd.pos
			for f: Folk in alive:
				_send(f, herd.pos)
		return true
	var kills: int = mini(herd.job.get("count", 0), alive.size())
	herd.job.count -= kills
	if camplife:
		for i in kills:
			camplife.add(alive[i % alive.size()].inv, "raw_meat", camplife.meat_per_kill)
	b.job["fed"] = true
	b.job.erase("prey")
	_go_home(b, now) # back to the den with it
	return true

## A herd of game: breeds toward herd_cap, splits when full, drifts about, and is gone when hunted out.
func _new_herd(p: Vector3, head: int) -> Camp:
	var h := Camp.new()
	h.wild = "herd"
	h.kind = "game"
	h.pos = p
	h.next_move = INF
	h.job = {"count": head, "t": SimClock.now, "acc": 0.0, "move": 0.0}
	camps.append(h)
	_herd_n += 1
	return h

var _herd_n := 0 # herds on the island (kept count: cheaper than counting)
var _herd_bodies := {} # herd Camp -> Array of greyhorn bodies, for herds near you

## Near you a herd is real: greyhorn bodies grazing round it, bolting from you or any hunter or pack that comes close. One you kill is one fewer in the
## herd (its carcass is yours); one the sim's hunters take falls down where it stands (the meat is theirs).
## The herd's spot follows its bodies while they're out.
func _herd_bodies_tick(h: Camp, at: Vector3) -> void:
	var near: bool = _dist(h.pos, at) < spawn_radius and h.job.count > 0
	var bodies: Array = _herd_bodies.get(h, [])
	if not near:
		if _herd_bodies.has(h):
			for b in bodies:
				if is_instance_valid(b) and not b.is_dead:
					b.queue_free()
			_herd_bodies.erase(h)
		return
	var alive: Array = []
	for b in bodies:
		if not is_instance_valid(b):
			continue
		if b.is_dead:
			if not b.has_meta("counted"):
				b.set_meta("counted", true)
				if not b.has_meta("sim_kill"):
					h.job.count = maxi(0, h.job.count - 1) # killed for real (you, or anyone)
			continue
		alive.append(b)
	var want: int = mini(h.job.count, herd_show_max)
	while alive.size() < want:
		var b: BaseCharacter = greyhorn_scene.instantiate()
		b.top_level = true
		b.position = _ground(_around(h.pos, _rng) + Vector3(_rng.randf_range(-6, 6), 0, _rng.randf_range(-6, 6))) + Vector3.UP * 0.1
		b.rotation.y = _rng.randf() * TAU
		b.get_node("mobAI")._asleep = true
		add_child(b)
		b.get_node("mobAI")._home = b.position
		alive.append(b)
	while alive.size() > want: # the sim's hunters took some: they drop where they stand
		var b: BaseCharacter = alive.pop_back()
		b.set_meta("sim_kill", true)
		var nothing: Dictionary[String, int] = {}
		b.get_node("dummy").loot = nothing # its meat is already in the hunter's pack
		b.statComponent.health.change_current(-100000)
	var threats: Array[Vector3] = [at] # you, and anyone else near enough to have a body (hunters, packs)
	for f in folk:
		if f.node and is_instance_valid(f.node) and not f.dead and _dist(f.pos, h.pos) < flee_range * 3.0:
			threats.append(f.pos)
	var mid := Vector3.ZERO
	for b in alive:
		mid += b.global_position
		var ai: MobAIComponent = b.get_node("mobAI")
		var from := Vector3(INF, 0, 0)
		for t in threats:
			var d := Vector3(b.global_position.x - t.x, 0, b.global_position.z - t.z)
			if d.length() < from.length():
				from = d
		if from.length() < flee_range and ai.state != MobAIComponent.State.RETURN:
			ai._home = _ground(b.global_position + from.normalized() * flee_range * 1.5)
			ai._enter(MobAIComponent.State.RETURN) # bolt
	if not alive.is_empty():
		h.pos = mid / alive.size()
	_herd_bodies[h] = alive + bodies.filter(func(b): return is_instance_valid(b) and b.is_dead)

## A character's health lives on the record (0-100); its body near you shows the same.
func _hp_from_body(f: Folk) -> void:
	if is_instance_valid(f.node) and f.node.statComponent and f.node.statComponent.health:
		var h: Stat = f.node.statComponent.health
		f.hp = 100.0 * h.currentValue / maxf(1.0, h.get_max_value())

func _hp_to_body(f: Folk) -> void:
	if is_instance_valid(f.node) and f.node.statComponent and f.node.statComponent.health and not f.node.is_dead:
		var h: Stat = f.node.statComponent.health
		var want := maxi(1, roundi(h.get_max_value() * f.hp / 100.0))
		if want != h.currentValue:
			var ai := _ai(f)
			if ai:
				ai.sim_hurt = true # the dark or hunger, not a blow: nobody to turn on
			h.change_current(want - h.currentValue)
			if ai:
				ai.sim_hurt = false

## Something left lying in the world (a corpse's things, what you drop): a place holding those items, there for
## anyone to find (you, or anyone passing) until it's emptied.
func drop_sack(pos: Vector3, items: Dictionary) -> void:
	if items.is_empty():
		return
	var s := Camp.new()
	s.wild = "sack"
	s.pos = pos
	s.next_move = INF
	s.stocked = true
	for id in items:
		s.crate[id] = s.crate.get(id, 0) + items[id]
	camps.append(s)

func _tick_sack(s: Camp, at: Vector3) -> void:
	if s.crate.is_empty():
		if is_instance_valid(s.fire):
			s.fire.queue_free()
		camps.erase(s) # emptied
		return
	var d := _dist(s.pos, at)
	if d < spawn_radius and not is_instance_valid(s.fire):
		var sack: Node3D = load("res://items/scenes/lootSack.tscn").instantiate()
		var nothing: Dictionary[String, int] = {}
		sack.get_node("interactableComponent/containerComponent").starting_items = nothing
		sack.top_level = true
		sack.position = s.pos
		var sync: Node = load("res://world/props/campStoreSync.gd").new()
		sync.record = s
		sync.which = "crate"
		sack.add_child(sync)
		add_child(sack)
		s.fire = sack
	elif d > spawn_radius * 1.2 and is_instance_valid(s.fire):
		s.fire.queue_free()

## Someone died where nobody saw: their body is left lying where they fell, with what they carried, for anyone
## to find (it's a place now, like remains; it's gone after body_decay).
func leave_body(f: Folk) -> void:
	if f.camp.kind in ["goblin", "orc"]:
		return
	var b := Camp.new()
	b.wild = "starved_dead"
	b.kind = f.camp.kind
	b.pos = _ground(f.pos)
	b.next_move = INF
	b.job = {"loot": f.inv.duplicate(), "since": SimClock.now}
	f.inv.clear()
	camps.append(b)

## Someone killed someone: what the dead are to the living. Monsters feed on whoever they kill; people who kill a
## monster can cut blackflesh from it (eaten only when starving: camplife.gd); nobody eats their own kind.
func _feed(killer: Folk, victim: Folk) -> void:
	if not killer or not camplife:
		return
	var monster := func(f: Folk) -> bool: return f.camp.kind in ["goblin", "orc"]
	if monster.call(killer) and not monster.call(victim):
		for o: Folk in _alive(killer.camp.members):
			if o.needs.has("food"):
				o.needs.food = minf(100.0, o.needs.food + 40.0) # they feed where it fell
	elif monster.call(victim) and not monster.call(killer):
		camplife.add(killer.inv, "blackflesh", 2)

func _tick_herd(h: Camp, at: Vector3, now: float) -> void:
	var j := h.job
	_herd_bodies_tick(h, at)
	if j.count <= 0:
		camps.erase(h)
		_herd_n -= 1
		_herd_bodies.erase(h)
		return
	var minutes: float = (now - j.t) / 60.0
	j.t = now
	j.acc += herd_growth * j.count * (1.0 - float(j.count) / herd_cap) * minutes
	while j.acc >= 1.0:
		j.acc -= 1.0
		j.count += 1
	if j.count >= herd_cap and _herd_n < herds_max:
		var half: int = j.count / 2
		j.count -= half
		var a := _rng.randf() * TAU
		var p := _ground(h.pos + Vector3(cos(a), 0, sin(a)) * 150.0)
		if not is_nan(p.y) and p.y > SEA_LEVEL + 1.5 and p.y < MAX_HEIGHT:
			_new_herd(p, half)
		else:
			j.count += half
	if now > j.move and not _herd_bodies.has(h): # near you the bodies move it (see _herd_bodies_tick)
		j.move = now + _rng.randf_range(45.0, 90.0)
		var a := _rng.randf() * TAU
		var p := _ground(h.pos + Vector3(cos(a), 0, sin(a)) * _rng.randf_range(herd_drift.x, herd_drift.y))
		if not is_nan(p.y) and p.y > SEA_LEVEL + 1.5 and p.y < MAX_HEIGHT:
			h.pos = p

## Sends a band back to its den. No den left (gone, wiped out, gone cold)? Monsters and bandits take the nearest
## camp of their own kind, or make a new one where they stand; drifters go wandering to find a fire.
func _go_home(b: Camp, now: float) -> void:
	var alive := _alive(b.members)
	var at: Vector3 = alive[0].pos if not alive.is_empty() else b.pos
	var human: bool = not b.kind in ["goblin", "orc"]
	# People only head for a home their light will get them to (monsters are of the dark and go anywhere).
	var reach: float = b.job.get("fuel", 0.0) * walk_speed * 0.9 if human else fire_radius * 3.0
	var home: Camp = b.den if b.den and b.den.wild == "" and not b.den.roaming and b.den.kind == b.kind and _dist(b.den.pos, at) < reach else null
	if not home:
		for c in camps:
			if c.wild == "" and not c.roaming and c.kind == b.kind and _dist(c.pos, at) < minf(reach, fire_radius * 3.0) and (not home or _dist(c.pos, at) < _dist(home.pos, at)):
				home = c
	b.raid = null
	if not home and human and b.job.get("fuel", 0.0) <= 0.0:
		b.wild = "wanderer" # no light to make a fire with: they wander and look for one
		b.roaming = true
		return
	if not home: # make a new den / fire right here
		home = Camp.new()
		home.kind = b.kind
		home.bandit = b.bandit
		home.pos = _ground(_alive(b.members)[0].pos)
		home.next_move = now + _rng.randf_range(migrate_every.x, migrate_every.y)
		camps.append(home)
		if not alive.is_empty() and not b.kind in ["goblin", "orc"]:
			note(alive[0], "made a new camp where they stood")
	b.den = home
	b.wild = "homeward"
	b.roaming = true
	b.pos = home.pos
	for f: Folk in alive:
		_send(f, home.pos)
	if not alive.is_empty() and not b.kind in ["goblin", "orc"]:
		note(alive[0], "headed home")

func _tick_homeward(b: Camp, alive: Array, now: float) -> void:
	var home := b.den
	if not home or home.wild != "" or home.kind != b.kind:
		_go_home(b, now) # home's gone in the meantime: find another
		return
	if not alive.any(func(f: Folk): return _dist(f.pos, home.pos) < 15.0):
		if now - b.waypoint_since > waypoint_give_up:
			b.waypoint_since = now
			for f: Folk in alive:
				_send(f, home.pos)
		return
	for f: Folk in alive:
		f.camp = home
		_send(f, home.pos)
		if camplife: # what they brought goes into the stores (keeping one of each)
			for id in f.inv.keys():
				if id == "water_skin":
					camplife.move(f.inv, home.barrel, id, f.inv[id] - 1)
				elif camplife.nourish(id).x > 0.0:
					camplife.move(f.inv, home.crate, id, f.inv[id] - (0 if home.kind in ["goblin", "orc"] else 1))
	home.members.append_array(alive)
	camps.erase(b)

var _next_pull := 0.0

## Lit fires and cairns pull a lost soul out of the dark now and then: the fuller the island, the rarer.
## They come up out of the dark a way off (never near you), with nearly nothing, and walk toward the light.
func _pull(at: Vector3, now: float, to: Camp = null) -> void:
	var humans := 0
	for f in folk:
		if not f.dead and not f.camp.kind in ["goblin", "orc"]:
			humans += 1
	if humans >= souls_target or _rng.randf() > 1.0 - float(humans) / maxf(1.0, souls_target):
		return
	var bandit := _rng.randf() < pull_bandit_share
	var lights: Array[Camp] = []
	for pass_bandit in ([true, false] if bandit else [false]): # no bandit fire burning: a drifter fire pulls them instead
		bandit = pass_bandit
		for c in camps:
			var lit: bool = c.wild == "" and not c.roaming and c.kind == ("bandit" if bandit else "drifter") and not _alive(c.members).is_empty()
			if lit:
				lights.append(c)
		if not lights.is_empty():
			break
	if lights.is_empty(): # no fire anywhere: the cairns' lights pull instead
		for c in camps:
			if c.wild == "cairn":
				lights.append(c)
		bandit = false
	if lights.is_empty():
		return
	var light: Camp = lights[_rng.randi() % lights.size()]
	if camplife and light.wild == "": # bigger fires, and fires with a storyteller, pull more
		var w := lights.map(func(l): return camplife.fire_scale(l)) # bigger fires pull more
		var roll: float = _rng.randf() * w.reduce(func(a, b): return a + b, 0.0)
		for i in lights.size():
			roll -= w[i]
			if roll <= 0.0:
				light = lights[i]
				break
	if to:
		light = to
		bandit = to.kind == "bandit"
	var p := Vector3(NAN, NAN, NAN)
	for attempt in 6:
		var a := _rng.randf() * TAU
		p = _ground(light.pos + Vector3(cos(a), 0, sin(a)) * _rng.randf_range(pull_distance.x, pull_distance.y))
		if not is_nan(p.y) and p.y > SEA_LEVEL + 1.5 and p.y < MAX_HEIGHT and _dist(p, at) > despawn_radius:
			break
		p.y = NAN
	if is_nan(p.y):
		return
	var f := Folk.new()
	f.pos = p
	f.packed = true # nothing but the clothes they stand in, and maybe a skin
	if _rng.randf() < 0.5:
		f.inv["water_skin"] = 1
	folk.append(f)
	var b := Camp.new()
	b.kind = "bandit" if bandit else "drifter"
	b.bandit = bandit
	b.wild = "" if bandit else "wanderer"
	b.roaming = true
	b.job["settles"] = true
	b.members.append(f)
	f.camp = b
	if minds:
		minds.birth(f, true) # needs, nature and a name of their own
		f.think_t = now + randf() * minds.think_every
	if bandit: # a bandit fire takes them in: they walk to it and join
		b.den = light
		b.wild = "homeward"
	b.pos = light.pos
	b.heading = atan2(light.pos.z - p.z, light.pos.x - p.x)
	b.waypoint_since = now
	camps.append(b)
	_send(f, light.pos)
	note(f, "was pulled out of the dark toward a %s" % ("cairn's light" if light.wild == "cairn" else "fire"))
	if to == null and camplife and camplife.has_role(light, "storyteller") and _rng.randf() < camplife.story_extra:
		_pull(at, now, light) # the stories carry: another follows

## A group settles at `home`: if it's a cold fire, nobody's, they light it again and make it theirs.
func _relight(home: Camp, lead: Folk) -> bool:
	if home.wild != "coldfire":
		note(lead, "found a fire and settled there")
		return true
	if not _light(home, lead.camp, SimClock.now):
		lead.camp.job.erase("settle_at") # it didn't take: they look again
		return false
	if is_instance_valid(home.fire):
		home.fire.queue_free()
	home.wild = ""
	home.kind = lead.camp.kind # whoever lights it makes it theirs
	home.bandit = home.kind == "bandit"
	home.empty_since = 0.0
	home.next_move = SimClock.now + randf_range(migrate_every.x, migrate_every.y)
	note(lead, "relit a cold fire and settled there")
	return true

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

## Nearest drifter camp to pos within r (not `skip`); with `cold` > 0, cold fires within that count too.
func _camp_near(pos: Vector3, r: float, skip: Camp, cold := 0.0, kind := "drifter") -> Camp:
	var best: Camp = null
	for c: Camp in camps: # all of them: cold fires from encounters aren't in the cell grid
		var room: bool = not camplife or not c.kind in ["drifter", "bandit"] or _alive(c.members).size() < camplife.capacity(c) # a fire that can keep one more
		var ok := c != skip and not c.roaming and ((c.kind == kind and c.wild == "" and _dist(c.pos, pos) < r and room) or (c.wild == "coldfire" and _dist(c.pos, pos) < cold))
		if ok and (not best or _dist(c.pos, pos) < _dist(best.pos, pos)):
			best = c
	return best

func _tick_raid(c: Camp, now: float) -> void:
	var raiders := _alive(c.members)
	var defenders := _alive(c.raid.members)
	if not raiders.is_empty() and defenders.is_empty() and camplife and c.raid.stocked:
		_plunder(c.raid, raiders) # nobody left to stop them: they strip the camp of what they can carry
		note(raiders[0], "stripped a %s of its stores" % (camplife.fire_name(c.raid).to_lower() if c.raid.wild == "" else c.raid.wild))
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
		c.job.erase("fight") # a toll-taker's fight is over: back to asking
		if c.roaming and c.den and c.wild == "pack" and not raiders.is_empty():
			c.job["fed"] = true # a pack that's raided takes the meat home (see _pack_hunts)
			_go_home(c, now)
			return
		if c.roaming and c.den and c.wild == "":
			_go_home(c, now) # a war band takes what it got back to its fire
		return
	if not raiders.any(func(f: Folk): return defenders.any(func(d: Folk): return _dist(f.pos, d.pos) < raid_arrive)):
		for f: Folk in raiders: # still on the way: keep heading for them (they may be walking)
			_send(f, defenders[0].pos)
		return
	# The same rules near you or not: someone falls now and then; bandits are the better fighters. Near you the
	# bodies act the fight out (their swings at each other do no harm) and the one the sim kills drops.
	if _rng.randf() < raid_kill_chance:
		var won := _rng.randf() < bandit_win_chance
		var victim: Folk = (defenders if won else raiders).pick_random()
		victim.dead = true
		_feed((raiders if won else defenders).pick_random(), victim)
		if won and camplife and c.raid.stocked: # one of them grabs what they can carry while the fighting goes on
			_plunder(c.raid, [raiders.pick_random()])
		if is_instance_valid(victim.node) and victim.node.statComponent:
			victim.node.statComponent.health.change_current(-100000)
		else:
			leave_body(victim)
		victim.node = null
		if minds:
			minds.on_death(victim, false)
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
## How a body looks doing what its record is doing (only the look): working at a chore, sitting by its fire, and
## its role in its name.
func _pose(f: Folk) -> void:
	var vis := f.node.get_node_or_null("visual") as Node3D
	var ai := _ai(f)
	if not vis or not ai or ai.state == MobAIComponent.State.CHASE or f.camp.wild in ["mourner", "starved"]:
		return
	if not vis.has_meta("base_y"):
		vis.set_meta("base_y", vis.position.y)
	var by: float = vis.get_meta("base_y")
	vis.position.y = by
	vis.rotation_degrees.x = 0.0
	var fig := vis.get_node_or_null("figure")
	if fig and "pose" in fig: # the jointed figure poses itself (raggedFigure.gd)
		if f.task.get("phase", "") == "work" and f.task.get("type", "") in ["wood", "sap", "forage", "water"]:
			fig.pose = "work" # chopping, cutting, picking, filling
		elif ai.state == MobAIComponent.State.IDLE and f.camp.wild == "" and not f.camp.roaming and _dist(f.pos, f.camp.pos) < 10.0:
			var to := f.camp.pos - f.node.global_position # and face it
			if Vector2(to.x, to.z).length() < 2.5:
				ai._idle_duration = 0.0 # too close to the flames: move off and rest elsewhere
			var sitter: bool = absi(hash(f.name)) % 3 != 0 and f.camp.job.get("roles", {}).get("firekeeper") != f # two in three sit; the firekeeper stays on its feet
			fig.pose = "sit" if sitter and ai._idle_duration > 15.0 else "" # long rests sit by the fire, short ones stand
			if Time.get_ticks_msec() >= ai.hold_until_ms: # not while you're talking to them
				f.node.rotation.y = lerp_angle(f.node.rotation.y, atan2(-to.x, -to.z), 0.05)
		else:
			fig.pose = ""
	var title := f.name
	for r in f.camp.job.get("roles", {}):
		if f.camp.job.roles[r] == f:
			title = "%s, %s" % [f.name, r]
	if f.node.Name != title:
		f.node.Name = title

## One walking step (flat) from p toward `to` at walk_speed, bent round trees (DeadTrees.round_trees): the one way
## anyone gets anywhere, record or body.
func _walk(p: Vector3, to: Vector3, dt: float) -> Vector3:
	var d := Vector3(to.x - p.x, 0, to.z - p.z)
	var n := minf(d.length(), walk_speed * dt)
	if n < 0.01:
		return Vector3.ZERO
	var dir := d.normalized()
	if trees and d.length() > 1.0:
		dir = trees.round_trees(p, dir)
	return dir * n

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
	var best_score := -INF
	for c in camps:
		if c != skip and not c.bandit and not c.roaming and c.wild == "" and _dist(c.pos, pos) < r and not _alive(c.members).is_empty():
			var food: int = camplife.count_food(c.crate) if camplife else 0
			var score: float = c.crate.get("coin", 0) * 20.0 + food * 10.0 + c.barrel.get("water_skin", 0) * 10.0 - _dist(c.pos, pos) # word of a well-stocked camp gets about
			if score > best_score:
				best_score = score
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
