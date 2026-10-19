class_name TorchBurn
extends StaticBody3D
## A held torch starts unlit: stand at a campfire (group "campfire") to light it. It burns down and goes out,
## and can be relit max_lights times in all; when the last flame dies the torch is used up and the next one
## in the stack comes up, unlit. Torches lying in the world burn forever.
## State (fuel, lights used) is kept on the Item, so it survives unequipping. The stack shares one Item:
## the state belongs to the torch in your hand, the rest of the stack are fresh spares.

## Seconds a full torch lasts. Everyone's torches burn this long (world/camplife.gd reads it for the island's people).
@export var burn_time := 600.0
## The last part of its life it gutters: flame and light shrink toward nothing.
@export_range(0.0, 1.0) var gutter_portion := 0.25
## Lightings per torch (the first light counts), then it's spent.
@export var max_lights := 4
@export var relight_distance := 4.5 # the held torch sits ~2 m out from the body at this scale

## Every held torch burns this many times faster (ash storms, curses: set by world/encounters.gd).
static var burn_rate := 1.0

@onready var _fire: Node3D = $fire_effect
@onready var _light: OmniLight3D = $firelight
@onready var _fire_scale := _fire.scale
@onready var _min_energy: float = _light.min_energy
@onready var _max_energy: float = _light.max_energy

func _process(delta: float) -> void:
	if not has_meta("item"): # set by HeldItemsComponent: only the hand copy burns
		return
	var item: Item = get_meta("item")
	var fuel: float = item.get_meta("fuel", 0.0)
	var lights: int = item.get_meta("lights", 0)
	if fuel <= 0.0 and lights < max_lights and _at_campfire():
		fuel = burn_time
		lights += 1
	elif fuel > 0.0:
		fuel = maxf(fuel - delta * burn_rate, 0.0)
		if fuel <= 0.0 and lights >= max_lights:
			_use_up(item)
			return
	item.set_meta("fuel", fuel)
	item.set_meta("lights", lights)
	var f := clampf(fuel / (burn_time * gutter_portion), 0.0, 1.0)
	_fire.visible = fuel > 0.0
	_light.visible = fuel > 0.0
	_fire.scale = _fire_scale * lerpf(0.3, 1.0, f)
	_light.min_energy = _min_energy * f
	_light.max_energy = _max_energy * f

func _at_campfire() -> bool:
	for fire in get_tree().get_nodes_in_group("campfire"):
		var d: Vector3 = fire.global_position - global_position
		if Vector2(d.x, d.z).length() < relight_distance:
			return true
	return false

## Burnt to a stub: drop it from the stack; the next spare (if any) takes its place, fresh and unlit.
func _use_up(item: Item) -> void:
	item.set_meta("fuel", 0.0)
	item.set_meta("lights", 0)
	var player: Node = get_tree().get_first_node_in_group("player") # shortcut: assumes the player holds it
	print("The torch crumbles to ash.")
	if player and player.inventoryComponent:
		player.inventoryComponent.remove_item(item, 1)
		if not player.inventoryComponent.inventory.has(item) and player.equipmentComponent:
			player.equipmentComponent.unequip_item(item) # last one gone
