extends StaticBody3D
## A camp's thing set out where you can see it (a bottle on the barrel, coins on the crate, a staff leaned on it):
## a real item from the camp's own stores (Camp.crate), not set dressing. Look at it and press E to take it,
## and it's gone from the camp's stores. It shows only while the camp still has one; when the camp's people use
## it up (or you take the last), it's gone from the table too. Built by world/camps.gd on top of the model it shows.

var record = null # the Camp whose crate this comes out of
var id := "" # item id it shows
## How many one take hands over (a coin pile: a handful; anything else: one).
var take := 1

var _model: Node3D
var _t := 0.0
static var _groups := {} # [record, id] -> the displays showing that item (so two knives show only if there are two)

func _enter_tree() -> void:
	_group().append(self)

func _exit_tree() -> void:
	_group().erase(self)

func _group() -> Array:
	var k := [record, id]
	if not _groups.has(k):
		_groups[k] = []
	return _groups[k]

func _ready() -> void:
	_model = get_parent() as Node3D
	collision_layer = 1
	var box := AABB()
	for m: MeshInstance3D in _model.find_children("*", "MeshInstance3D", true, false):
		var a: AABB = _model.global_transform.affine_inverse() * m.global_transform * m.get_aabb()
		box = a if box.size == Vector3.ZERO else box.merge(a)
	var shape := CollisionShape3D.new()
	var bs := BoxShape3D.new()
	bs.size = box.size.max(Vector3.ONE * 0.15)
	shape.shape = bs
	shape.position = box.get_center()
	add_child(shape)
	_show()

func _stash() -> Dictionary:
	return record.crate if record else {}

func _process(delta: float) -> void:
	_t += delta
	if _t > 0.5:
		_t = 0.0
		_show()

func _show() -> void:
	var there: bool = _stash().get(id, 0) > (_group().find(self) if take == 1 else 0) # one shown per one they have
	_model.visible = there
	collision_layer = 1 if there else 0

func show_prompt() -> void:
	var it: Item = get_node("/root/item_list").get_item_instance(id)
	if it:
		Talker.notify("Take %s  [E]" % it.Name, 1.5)

func hide_prompt() -> void:
	pass

func interact(player: Node) -> void:
	var have: int = _stash().get(id, 0)
	if have <= 0 or not player or not player.inventoryComponent:
		return
	var n := mini(take, have)
	var it: Item = get_node("/root/item_list").get_item_instance(id)
	player.inventoryComponent.add_item(it, n)
	_stash()[id] = have - n
	if _stash()[id] <= 0:
		_stash().erase(id)
	Talker.notify("You take %s%s." % [it.Name.to_lower(), " x%d" % n if n > 1 else ""])
	var camps = get_tree().get_first_node_in_group("camps")
	if camps and camps.minds:
		camps.minds.stolen(record, global_position)
	_show()
