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
## And sometimes this as well ("" = never), with this chance.
@export var extra_item := ""
@export_range(0.0, 1.0, 0.05) var extra_chance := 0.0
## Uses before it's dry / picked clean, and seconds for one use to come back.
@export_range(1, 20) var stock := 4
@export_range(5.0, 3600.0, 5.0, "suffix:s") var regrow := 120.0
@export var empty_line := "Nothing left. Come back later."

var record = null # a Camps record (Camp) whose `job` keeps the stock

const LIFE := preload("res://world/camplife.gd")

func _state() -> Dictionary:
	var s: Dictionary = record.job if record else get_meta("state", {})
	var camps = get_tree().get_first_node_in_group("camps")
	var slow: float = camps.camplife.bare_slow if camps and camps.camplife else 0.0
	LIFE.regrow(s, stock, regrow, slow, SimClock.now) # the same regrowth the island's people see
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
	if extra_item != "" and inv and randf() < extra_chance:
		var ex: Item = db.get_item_instance(extra_item)
		inv.add_item(ex, 1)
		said.append("scrape off some %s" % ex.Name.to_lower())
	var line := " and ".join(said)
	Talker.notify(line.left(1).to_upper() + line.substr(1) + ".")
