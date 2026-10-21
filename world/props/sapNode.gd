extends StaticBody3D
## Where sap bleeds out of a giant tree's bark (world/camps.gd puts one on each giant near you; far off it's just a
## record with a stock, camplife SOURCES "sap"). Look at it and press E with a knife to cut the resin free. It's the
## only place resin comes from, for you and for the camps' drawers alike; cut dry, it bleeds again slowly.

var record = null # the sap node (a Camps record)
var _t := 0.0
var _mat := StandardMaterial3D.new()

func _ready() -> void:
	_mat.albedo_color = Color(0.75, 0.42, 0.08)
	_mat.emission_enabled = true
	_mat.emission = Color(0.9, 0.5, 0.1)
	_mat.roughness = 0.2
	for m in get_children():
		if m is MeshInstance3D:
			m.material_override = _mat

func _process(delta: float) -> void:
	_t += delta
	if _t < 1.0 or not record:
		return
	_t = 0.0
	var camps = get_tree().get_first_node_in_group("camps")
	_mat.emission_energy_multiplier = 0.6 if camps and camps.camplife.has_stock(record) else 0.0 # dull once cut dry

func show_prompt() -> void:
	Talker.notify("Sap bleeding from the bark  [E] cut the resin free (knife)", 1.5)

func hide_prompt() -> void:
	pass

func interact(player: Node) -> void:
	var camps = get_tree().get_first_node_in_group("camps")
	if not record or not camps or not player.inventoryComponent:
		return
	var inv: InventoryComponent = player.inventoryComponent
	if not Tools.find(inv, "knife"):
		Talker.notify("You need a blade to cut it free.")
		return
	if camps.camplife.take(record, 1) == 0:
		Talker.notify("It's been cut dry. It'll bleed again, in time.")
		return
	Tools.use(inv, "knife")
	inv.add_item(get_node("/root/item_list").get_item_instance("resin"), 1)
	Talker.notify("You cut out a lump of resin.")
