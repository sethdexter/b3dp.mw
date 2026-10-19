extends Node
## Keeps a camp's barrel or crate (a container you can open, its parent) in step with the camp's record
## (Camp.barrel / Camp.crate, item id -> count), which is what the simulation uses. While you have it open,
## whatever you take or put is written back to the record; otherwise it shows what the camp's people left in it.
## A camp with several barrels (or crates) splits the store between them: each holds its share, and together
## they hold exactly what the camp has.

var record = null # the Camp
var which := "crate" # "barrel", "crate", or "pack" (record is then a person: their own pack, a trader on the road)
## First time only: copy what's already in the container into the record (a bandit chest's loot).
var absorb := false
## Shows the whole store rather than a share of it (a trader's wares: everything their camp has to sell).
var whole := false

var _container: ContainerComponent
var _t := 0.0
var _shown := {} # this container's share of the store as last shown (id -> count)
static var _ids := {} # item resource path -> item_list id
static var _groups := {} # [record, which] -> the syncs sharing that store

func _enter_tree() -> void:
	if not whole:
		_group().append(self)

func _exit_tree() -> void:
	_group().erase(self)

func _group() -> Array:
	var k := [record, which]
	if not _groups.has(k):
		_groups[k] = []
	return _groups[k]

## This container's share of n of something: the store split as evenly as it goes, in group order.
func _share(n: int) -> int:
	if whole:
		return n
	var g := _group()
	var i := g.find(self)
	var k := maxi(1, g.size())
	return n * (i + 1) / k - n * i / k

func _ready() -> void:
	_container = get_parent() as ContainerComponent if get_parent() is ContainerComponent else get_parent().find_child("containerComponent", true, false) as ContainerComponent
	if absorb:
		_write_back()
	else:
		_refresh()

func _stash() -> Dictionary:
	return record.inv if which == "pack" else (record.barrel if which == "barrel" else record.crate)

func _process(delta: float) -> void:
	_t += delta
	if _t < 0.5 or not record or not _container or not _container.storage:
		return
	_t = 0.0
	if _container.is_open:
		_write_back() # you're rummaging: what's in the container is the truth
	else:
		_refresh() # the camp's people have been using it: show what's there now

## Container contents -> the record: the store changes by however this container's share changed.
func _write_back() -> void:
	if not _container or not _container.storage:
		return
	var d := _stash()
	var now := {}
	for it: Item in _container.storage.inventory:
		var id := _id_of(it)
		if id != "":
			now[id] = now.get(id, 0) + _container.storage.inventory[it]
	for id in now.keys() + _shown.keys():
		var change: int = now.get(id, 0) - _shown.get(id, 0)
		if change != 0:
			d[id] = maxi(0, d.get(id, 0) + change)
			if d[id] == 0:
				d.erase(id)
	_shown = now

## The record -> container contents (only if they differ, so nothing flickers).
func _refresh() -> void:
	if not record or not _container or not _container.storage:
		return
	var want := {}
	for id in _stash():
		var n := _share(_stash()[id])
		if n > 0:
			want[id] = n
	if want == _shown:
		return
	_container.storage.inventory.clear()
	var db = get_node("/root/item_list")
	for id in want:
		var it: Item = db.get_item_instance(id)
		if it:
			_container.storage.add_item(it, want[id])
	_shown = want

func _id_of(it: Item) -> String:
	if _ids.is_empty():
		var db = get_node("/root/item_list")
		for key in db.item_list:
			_ids[db.item_list[key].resource_path] = key
	return _ids.get(it.get_template().resource_path, "")
