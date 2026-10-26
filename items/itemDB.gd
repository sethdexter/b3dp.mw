extends Node
class_name ItemDB

# --- Individual item variables (direct references) ---
var torch: Item = preload("res://items/data/torch.tres")
var black_iron_sword: Item = preload("res://items/data/black_iron_sword.tres")
var rusty_sword: Item = preload("res://items/data/rusty_sword.tres")
var leather_cap: Item = preload("res://items/data/leather_cap.tres")
var leather_cuirass: Item = preload("res://items/data/leather_cuirass.tres")
var iron_boots: Item = preload("res://items/data/iron_boots.tres")
var travel_cloak: Item = preload("res://items/data/travel_cloak.tres")
var health_potion: Item = preload("res://items/data/health_potion.tres")
var magicka_potion: Item = preload("res://items/data/magicka_potion.tres")
var stamina_potion: Item = preload("res://items/data/stamina_potion.tres")
var bread: Item = preload("res://items/data/bread.tres")
var coin: Item = preload("res://items/data/coin.tres")
var ash_cap: Item = preload("res://items/data/ash_cap.tres")
var raw_meat: Item = preload("res://items/data/raw_meat.tres")
var ash_wood: Item = preload("res://items/data/ash_wood.tres")
var bone: Item = preload("res://items/data/bone.tres")
var sinew: Item = preload("res://items/data/sinew.tres")
var hide: Item = preload("res://items/data/hide.tres")
var resin: Item = preload("res://items/data/resin.tres")
var tinder: Item = preload("res://items/data/tinder.tres")
var kindling: Item = preload("res://items/data/kindling.tres")
var flint: Item = preload("res://items/data/flint.tres")
var old_oil: Item = preload("res://items/data/old_oil.tres")
var script_fragment: Item = preload("res://items/data/script_fragment.tres")
var scrap_metal: Item = preload("res://items/data/scrap_metal.tres")
var cloth: Item = preload("res://items/data/cloth.tres")
var salt: Item = preload("res://items/data/salt.tres")
var spores: Item = preload("res://items/data/spores.tres")
var goblin_carcass: Item = preload("res://items/data/goblin_carcass.tres")
var orc_carcass: Item = preload("res://items/data/orc_carcass.tres")
var bone_knife: Item = preload("res://items/data/bone_knife.tres")
var hatchet: Item = preload("res://items/data/hatchet.tres")
var sunken_key: Item = preload("res://items/data/sunken_key.tres")
var dried_meat: Item = preload("res://items/data/dried_meat.tres")
var water_skin: Item = preload("res://items/data/water_skin.tres")
var ash_wine: Item = preload("res://items/data/ash_wine.tres")
var blackflesh: Item = preload("res://items/data/blackflesh.tres")
var greyhorn_carcass: Item = preload("res://items/data/greyhorn_carcass.tres")
var staff: Item = preload("res://items/data/staff.tres")


# --- Optional dictionary for lookup by ID ---
var item_list: Dictionary[String, Item] = {
	"torch": torch,
	"black_iron_sword": black_iron_sword,
	"rusty_sword": rusty_sword,
	"leather_cap": leather_cap,
	"leather_cuirass": leather_cuirass,
	"iron_boots": iron_boots,
	"travel_cloak": travel_cloak,
	"health_potion": health_potion,
	"magicka_potion": magicka_potion,
	"stamina_potion": stamina_potion,
	"bread": bread,
	"coin": coin,
	"ash_cap": ash_cap,
	"raw_meat": raw_meat,
	"ash_wood": ash_wood,
	"bone": bone,
	"sinew": sinew,
	"hide": hide,
	"resin": resin,
	"tinder": tinder,
	"kindling": kindling,
	"flint": flint,
	"old_oil": old_oil,
	"script_fragment": script_fragment,
	"scrap_metal": scrap_metal,
	"cloth": cloth,
	"salt": salt,
	"spores": spores,
	"goblin_carcass": goblin_carcass,
	"orc_carcass": orc_carcass,
	"bone_knife": bone_knife,
	"hatchet": hatchet,
	"sunken_key": sunken_key,
	"dried_meat": dried_meat,
	"water_skin": water_skin,
	"ash_wine": ash_wine,
	"blackflesh": blackflesh,
	"greyhorn_carcass": greyhorn_carcass,
	"staff": staff,
}

func _init():
	# If needed, this ensures dictionary is initialized on load
	if item_list.is_empty():
		item_list = {}

# --- Fetch an item instance safely ---
# Returns:
#   - shared reference for stackable items (max_stack > 1)
#   - duplicated instance for unique items (max_stack == 1)
func get_item_instance(item_id: String) -> Item:
	if not item_list.has(item_id):
		push_error("Item ID '%s' not found in ItemDB!" % item_id)
		return null

	var item = item_list[item_id]
	# Duplicate if unique
	if item.maxStackCount == 1:
		return item.make_instance()
	return item
