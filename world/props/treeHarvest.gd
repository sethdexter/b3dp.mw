extends StaticBody3D
## The dead trees' trunk colliders (DeadTrees makes this body). Look at a trunk and press E to break off
## branches for ash wood. It's slow, it's loud (hostiles nearby come to see what the noise is), and each tree only
## has so much dead wood on it. A hatchet ("axe") is faster and gets more. With a knife you may also scrape resin
## off the giant trees.

## Seconds to work a branch loose by hand, and with a hatchet.
@export var hand_time := 4.0
@export var axe_time := 1.5
## Branches a tree has before it's stripped (bigger trees have more), and wood per go (hand, hatchet).
@export var branches_per_tree := 2
@export var wood_by_hand := 1
@export var wood_by_axe := 2
## Hostiles within this many metres hear you and come looking.
@export var noise_radius := 35.0
## Trees at least this many times the base tree size count as giants, with resin on them; chance per go.
@export var giant_scale := 1.4
@export var resin_chance := 0.35

var trees: Node3D # the DeadTrees node (its _trunks lookup)
var _busy := false

func show_prompt() -> void:
	Talker.notify("Dead tree  [E] break off branches", 1.5)

func hide_prompt() -> void:
	pass

func interact(player: Node) -> void:
	if _busy or not trees:
		return
	var t = _nearest_trunk(player.global_position)
	if t == null:
		return
	var key := Vector2i(roundi(t.x), roundi(t.z))
	var big: bool = t.w >= giant_scale * trees.tree_scale
	var left: int = trees.harvested.get(key, branches_per_tree + (2 if big else 0))
	if left <= 0:
		Talker.notify("Nothing left on this one you can break off.")
		return
	var inv: InventoryComponent = player.inventoryComponent
	var axe := Tools.find(inv, "axe") != null
	_busy = true
	var from: Vector3 = player.global_position
	Talker.notify("You work at the dead wood%s..." % (" with the hatchet" if axe else " with your hands"), axe_time if axe else hand_time)
	_noise(from)
	await get_tree().create_timer(axe_time if axe else hand_time, false).timeout
	_busy = false
	if not is_instance_valid(player) or player.global_position.distance_to(from) > 3.0 or player.is_dead:
		Talker.notify("You leave it.")
		return
	if axe:
		Tools.use(inv, "axe")
	var db = get_node("/root/item_list")
	var wood := wood_by_axe if axe else wood_by_hand
	inv.add_item(db.get_item_instance("ash_wood"), wood)
	trees.harvested[key] = left - 1
	var got := "%d ash wood" % wood
	if big and randf() < resin_chance and Tools.find(inv, "knife"):
		Tools.use(inv, "knife")
		inv.add_item(db.get_item_instance("resin"), 1)
		got += " and a lump of resin"
	Talker.notify("You get %s.%s" % [got, "" if left - 1 > 0 else " The tree's stripped bare."])

## The trunk (x, y, z, scale) closest to where you're standing, within reach.
func _nearest_trunk(at: Vector3):
	var best = null
	var best_d := 7.0
	var cell := Vector2i(floori(at.x / trees.COLLIDE_CELL), floori(at.z / trees.COLLIDE_CELL))
	for dz in range(-1, 2):
		for dx in range(-1, 2):
			for t: Vector4 in trees._trunks.get(cell + Vector2i(dx, dz), []):
				var d := Vector2(t.x - at.x, t.z - at.z).length() - t.w * 0.5 # measure from the bark, roughly
				if d < best_d:
					best_d = d
					best = t
	return best

## Chopping is loud: anything hostile nearby comes to see.
func _noise(at: Vector3) -> void:
	var camps = get_tree().get_first_node_in_group("camps")
	if not camps:
		return
	for f in camps.folk:
		if f.dead or not is_instance_valid(f.node) or f.node.global_position.distance_to(at) > noise_radius:
			continue
		if f.camp.kind in ["goblin", "orc", "bandit"]:
			var ai: MobAIComponent = f.node.get_node_or_null("mobAI")
			if ai and ai.aggressive:
				ai._enter(MobAIComponent.State.CHASE)
