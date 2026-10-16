extends StaticBody3D
## Somewhere to eat or drink: a spring, a camp's water barrel, a patch of ash fungus. Look at it and press E.
##   drink > 0   quenches your thirst on the spot, and tops up Water Skins in your pack (up to fill_to)
##   item != ""  hands you that item (e.g. ash_cap) instead / as well
## Each use takes from `stock`, which slowly grows back. The state lives in `record` (the Camps record of
## the spot) when there is one, so it survives you walking away.

@export var label := "Spring"
## Thirst quenched per use (0-100 scale; 0 = not a drink).
@export_range(0.0, 100.0, 1.0) var drink := 40.0
## Water skins it can fill per use, and the most you'll be topped up to.
@export_range(0, 5) var fill := 1
@export_range(0, 10) var fill_to := 3
## Item handed over per use ("" = none) and how many.
@export var item := ""
@export_range(0, 5) var item_count := 1
## Uses before it's dry / picked clean, and seconds for one use to come back.
@export_range(1, 20) var stock := 4
@export_range(5.0, 3600.0, 5.0, "suffix:s") var regrow := 120.0
@export var empty_line := "Nothing left. Come back later."

var record = null # a Camps record (Camp) whose `job` keeps the stock

func _state() -> Dictionary:
	var s: Dictionary = record.job if record else get_meta("state", {})
	if not s.has("stock"):
		s["stock"] = stock
		s["at"] = SimClock.now
	var now := SimClock.now
	var back := int((now - s.at) / regrow)
	if back > 0:
		s.stock = mini(stock, s.stock + back)
		s.at += back * regrow
	if not record:
		set_meta("state", s)
	return s

func show_prompt() -> void:
	Talker.notify("%s  [E]" % label, 1.5)

func hide_prompt() -> void:
	pass

func interact(player: Node) -> void:
	var s := _state()
	if s.stock <= 0:
		Talker.notify(empty_line)
		return
	s.stock -= 1
	var said: Array[String] = []
	var needs: NeedsComponent = player.get_node_or_null("needs")
	if drink > 0.0 and needs:
		needs.drink(drink)
		said.append("You drink")
	var inv: InventoryComponent = player.inventoryComponent
	var db = get_node("/root/item_list")
	if fill > 0 and inv:
		var skin: Item = db.get_item_instance("water_skin")
		var room := clampi(fill_to - inv.count_item(skin), 0, fill)
		if room > 0:
			inv.add_item(skin, room)
			said.append("fill %d water skin%s" % [room, "" if room == 1 else "s"])
	if item != "" and inv:
		var it: Item = db.get_item_instance(item)
		inv.add_item(it, item_count)
		said.append("take %d %s" % [item_count, it.Name])
	var line := " and ".join(said)
	Talker.notify(line.left(1).to_upper() + line.substr(1) + ".")
