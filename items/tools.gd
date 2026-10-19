class_name Tools
## Tools wear out. An item counts as a tool of a kind ("knife", "axe"...) through its `tool` field, and has
## `durability` uses before it breaks; how many are left is kept on that item instance (meta "wear").
## Gathering and crafting ask for a kind and the best one in your pack gets used.

## The tool of this kind in the inventory with the most uses left, or null.
static func find(inv: InventoryComponent, kind: String) -> Item:
	if not inv or kind == "":
		return null
	var best: Item = null
	for it: Item in inv.inventory:
		if it.get_tool() == kind and (best == null or uses_left(it) > uses_left(best)):
			best = it
	return best

static func uses_left(it: Item) -> int:
	var d := it.get_durability()
	return 1 << 30 if d <= 0 else it.get_meta("wear", d)

## Uses one of a tool of this kind from the inventory (wearing it down, maybe breaking it). False = you have none.
static func use(inv: InventoryComponent, kind: String) -> bool:
	var it := find(inv, kind)
	if not it:
		return false
	if it.get_durability() > 0:
		var left := uses_left(it) - 1
		it.set_meta("wear", left)
		if left <= 0:
			inv.remove_item(it, 1)
			Talker.notify("Your %s breaks." % it.Name.to_lower())
		elif left <= 3:
			Talker.notify("Your %s is nearly worn through (%d use%s left)." % [it.Name.to_lower(), left, "" if left == 1 else "s"])
	return true

## Breaks an item in the pack down into what it's made of (its `salvage`), if you have the tool it needs.
## Returns what happened, for a message.
static func break_down(inv: InventoryComponent, it: Item, db) -> String:
	var parts := it.get_salvage()
	if parts.is_empty():
		return "You can't get anything useful out of the %s." % it.Name.to_lower()
	var need := it.get_salvage_tool()
	if need != "" and not find(inv, need):
		return "You need a %s to break down the %s." % [need, it.Name.to_lower()]
	if it.isEquipped:
		return "Take the %s off first." % it.Name.to_lower()
	if need != "":
		use(inv, need)
	inv.remove_item(it, 1)
	var got: Array[String] = []
	for id in parts:
		var part: Item = db.get_item_instance(id)
		if part:
			inv.add_item(part, parts[id])
			got.append("%d %s" % [parts[id], part.Name.to_lower()])
	return "You break down the %s: %s." % [it.Name.to_lower(), ", ".join(got)]
