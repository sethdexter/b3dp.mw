extends Node
class_name ItemDB

# --- Individual item variables (direct references) ---
var torch: Item = preload("res://databases/item_database/torch.tres")
var black_iron_sword: Item = preload("res://databases/item_database/black_iron_sword.tres")
var rusty_sword: Item = preload("res://databases/item_database/rusty_sword.tres")
var leather_cap: Item = preload("res://databases/item_database/leather_cap.tres")
var leather_cuirass: Item = preload("res://databases/item_database/leather_cuirass.tres")
var iron_boots: Item = preload("res://databases/item_database/iron_boots.tres")
var travel_cloak: Item = preload("res://databases/item_database/travel_cloak.tres")
var health_potion: Item = preload("res://databases/item_database/health_potion.tres")
var magicka_potion: Item = preload("res://databases/item_database/magicka_potion.tres")
var stamina_potion: Item = preload("res://databases/item_database/stamina_potion.tres")


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
