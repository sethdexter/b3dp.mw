class_name ItemListView
extends VBoxContainer

## Renders an InventoryComponent as a bottom-up text list with a details line.
## Shared by the chest (bottom-left) and the player inventory (bottom-right).
## Expected children: "Items" (VBoxContainer) and "Details" (Label).
## Set this VBoxContainer's alignment to End so longer lists grow upward.

@export var align_right := false
## Rows shown at once; longer lists scroll with the selection.
@export var max_visible_rows: int = 14
@export var row_font_size: int = 14
@export var row_color: Color = Color(0.92, 0.87, 0.74) # parchment white
@export var selected_color: Color = Color(1.0, 0.95, 0.6)
@export var highlight_color: Color = Color(0.55, 0.45, 0.3, 0.45)
## How much the highlight fades when this list doesn't have focus.
@export_range(0.0, 1.0) var unfocused_alpha: float = 0.35

const SLOT_TAGS := {
	"right_hand": "R", "left_hand": "L", "head": "H",
	"chest": "C", "feet": "F", "back": "B",
}

@onready var rows_box: VBoxContainer = $Items
@onready var details_label: Label = $Details

var inventory: InventoryComponent
var equipment: EquipmentComponent
var selected_index := 0
var first_visible := 0
var focused := true: set = set_focused

var _style_selected := StyleBoxFlat.new()
var _style_selected_dim := StyleBoxFlat.new()
var _style_none := StyleBoxEmpty.new()

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	for s: StyleBox in [_style_selected, _style_selected_dim, _style_none]:
		s.content_margin_left = 3
		s.content_margin_right = 3
	_style_selected.bg_color = highlight_color
	_style_selected_dim.bg_color = Color(highlight_color, highlight_color.a * unfocused_alpha)
	if align_right and details_label:
		details_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	visible = false

## Point the view at an inventory (and optionally equipment, for [R]/[L] tags).
func bind(inv: InventoryComponent, equip: EquipmentComponent = null) -> void:
	if inventory and inventory.inventory_updated.is_connected(refresh):
		inventory.inventory_updated.disconnect(refresh)
	if equipment and equipment.equipment_changed.is_connected(_on_equipment_changed):
		equipment.equipment_changed.disconnect(_on_equipment_changed)
	inventory = inv
	equipment = equip
	if inventory:
		inventory.inventory_updated.connect(refresh)
	if equipment:
		equipment.equipment_changed.connect(_on_equipment_changed)

func show_view() -> void:
	visible = true
	selected_index = 0
	first_visible = 0
	refresh()

func hide_view() -> void:
	visible = false

func set_focused(value: bool) -> void:
	focused = value
	if is_node_ready():
		refresh()

func move_selection(dir: int) -> void:
	if not inventory:
		return
	var count := inventory.inventory.size()
	if count == 0:
		return
	selected_index = wrapi(selected_index + dir, 0, count)
	refresh()

func get_selected_item() -> Item:
	if not inventory:
		return null
	var items := inventory.inventory.keys()
	if selected_index < 0 or selected_index >= items.size():
		return null
	return items[selected_index]

func get_selected_count() -> int:
	var item := get_selected_item()
	return inventory.inventory[item] if item else 0

# --- drawing ----------------------------------------------------------------

func _on_equipment_changed(_slot: String, _item: Item) -> void:
	refresh()

func refresh() -> void:
	if not visible or not rows_box or not inventory:
		return
	for child in rows_box.get_children():
		rows_box.remove_child(child) # remove now, so old rows don't linger a frame
		child.queue_free()

	var items := inventory.inventory.keys()
	if items.is_empty():
		selected_index = 0
		var empty_row := _make_row("(empty)", false)
		empty_row.modulate.a = 0.6
		rows_box.add_child(empty_row)
		_update_details()
		return

	selected_index = clampi(selected_index, 0, items.size() - 1)

	# Keep the selection inside the visible window.
	var rows := mini(max_visible_rows, items.size())
	if selected_index < first_visible:
		first_visible = selected_index
	elif selected_index >= first_visible + rows:
		first_visible = selected_index - rows + 1
	first_visible = clampi(first_visible, 0, items.size() - rows)

	for i in range(first_visible, first_visible + rows):
		var item: Item = items[i]
		rows_box.add_child(_make_row(_row_text(item, inventory.inventory[item]), i == selected_index))

	_update_details()

func _row_text(item: Item, count: int) -> String:
	var text := item.Name
	if count > 1:
		text += "  x%d" % count
	if equipment:
		var slot := equipment.get_slot_of(item)
		if slot != "":
			text += "  [%s]" % SLOT_TAGS.get(slot, slot)
	return text

func _make_row(text: String, selected: bool) -> Label:
	var row := Label.new()
	row.text = text
	# Shrink to text width so the highlight only covers the string.
	row.size_flags_horizontal = Control.SIZE_SHRINK_END if align_right else Control.SIZE_SHRINK_BEGIN
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	if details_label:
		row.add_theme_font_override("font", details_label.get_theme_font("font"))
	row.add_theme_font_size_override("font_size", row_font_size)

	var style: StyleBox = _style_none
	var color := row_color
	if selected:
		style = _style_selected if focused else _style_selected_dim
		color = selected_color if focused else row_color.lerp(selected_color, 0.3)
	row.add_theme_color_override("font_color", color)
	row.add_theme_stylebox_override("normal", style)
	return row

func _update_details() -> void:
	if not details_label:
		return
	var item := get_selected_item()
	if item == null:
		details_label.text = ""
		return
	var lines: PackedStringArray = []
	lines.append(item.itemDesription)
	var info := "Weight: %d" % item.weight
	if item is WeaponItem:
		var dmg: Dictionary = item.attackTypes
		info += "   Slash %d / Pierce %d / Blunt %d" % [
			dmg.get("slashDamage", 0), dmg.get("pierceDamage", 0), dmg.get("bludgeiningDamage", 0)]
	lines.append(info)
	details_label.text = "\n".join(lines)
