extends RefCounted
## What can be made, from what, with what, and where. The same recipes for you (ui/craftMenu.gd) and for the
## camps (world/camplife.gd). Nothing from nothing: every input is used up; a tool wears one use.
##   needs  item id -> count used up      tool  a Tools kind the maker must carry ("" = hands)
##   makes  item id -> count made         at    "" anywhere, "fire" within a campfire's light

const RECIPES := {
	"torch": {"needs": {"ash_wood": 1, "cloth": 1, "resin": 1}, "makes": {"torch": 1}, "tool": "", "at": ""},
	"kindling": {"needs": {"ash_wood": 1}, "makes": {"kindling": 3}, "tool": "knife", "at": ""},
	"flint": {"needs": {"scrap_metal": 1, "bone": 1}, "makes": {"flint": 1}, "tool": "", "at": ""},
	"bone_knife": {"needs": {"bone": 1, "sinew": 1}, "makes": {"bone_knife": 1}, "tool": "", "at": ""},
	"hatchet": {"needs": {"scrap_metal": 1, "ash_wood": 1, "sinew": 1}, "makes": {"hatchet": 1}, "tool": "", "at": "fire"},
	"staff": {"needs": {"ash_wood": 2}, "makes": {"staff": 1}, "tool": "knife", "at": ""},
	"dried_meat": {"needs": {"raw_meat": 1, "salt": 1}, "makes": {"dried_meat": 2}, "tool": "", "at": "fire"},
	"water_skin": {"needs": {"hide": 1, "sinew": 1}, "makes": {"water_skin": 1}, "tool": "knife", "at": ""},
	"travel_cloak": {"needs": {"hide": 2, "cloth": 1}, "makes": {"travel_cloak": 1}, "tool": "knife", "at": ""},
	"leather_cap": {"needs": {"hide": 1, "sinew": 1}, "makes": {"leather_cap": 1}, "tool": "knife", "at": ""},
	"leather_cuirass": {"needs": {"hide": 3, "sinew": 2}, "makes": {"leather_cuirass": 1}, "tool": "knife", "at": "fire"},
	"health_potion": {"needs": {"ash_cap": 2, "resin": 1}, "makes": {"health_potion": 1}, "tool": "", "at": "fire"},
}

## What's missing to make id from this stock (item id -> count), or "" if it can be made.
static func missing(id: String, have: Dictionary, tools: Array, at_fire: bool) -> String:
	var r: Dictionary = RECIPES[id]
	var short := []
	for k in r.needs:
		if have.get(k, 0) < r.needs[k]:
			short.append("%d %s" % [r.needs[k] - have.get(k, 0), k.replace("_", " ")])
	if r.tool != "" and not r.tool in tools:
		short.append("a " + r.tool)
	if r.at == "fire" and not at_fire:
		short.append("a fire")
	return ", ".join(short)

## A pack as item id -> count (and the tool kinds in it), for missing().
static func stock_of(inv: InventoryComponent) -> Array:
	var have := {}
	var tools := []
	for it: Item in inv.inventory:
		var id := _id_of(it)
		have[id] = have.get(id, 0) + inv.inventory[it]
		if it.get("tool") and it.tool != "":
			tools.append(it.tool)
	return [have, tools]

## Makes id out of your pack (check missing() first).
static func make(id: String, inv: InventoryComponent, db: Node) -> void:
	var r: Dictionary = RECIPES[id]
	for k in r.needs:
		var it: Item = db.get_item_instance(k)
		var left: int = r.needs[k]
		for key: Item in inv.inventory.keys():
			if left > 0 and InventoryComponent.is_same_item(key, it):
				left -= inv.remove_item(key, left)
	if r.tool != "":
		Tools.use(inv, r.tool)
	for k in r.makes:
		inv.add_item(db.get_item_instance(k), r.makes[k])

static func _id_of(it: Item) -> String:
	var db = Engine.get_main_loop().root.get_node_or_null("item_list")
	if db:
		var path := it.get_template().resource_path
		for k in db.item_list:
			if db.item_list[k].resource_path == path:
				return k
	return ""
