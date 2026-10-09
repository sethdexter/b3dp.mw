extends Resource
class_name Item

@export var itemScene: PackedScene

@export var Name: 			 String
@export var id: 		 	 String

@export var weight: 		 int
@export var maxStackCount:   int
@export var isUnique:		 bool
@export var equippableSlots:  Array[String]

@export var isEquipped     :  bool
@export var isEquippable   := false
@export var isConsumable   := false
@export var isPickupable   := false
@export var itemDesription := "defualt item despription."

@export_group("Held (first person)")
## Scene shown in hand when equipped. Falls back to itemScene.
@export var heldScene: PackedScene
@export var heldPosition := Vector3.ZERO
## Degrees.
@export var heldRotation := Vector3.ZERO
@export var heldScale    := Vector3.ONE

@export_group("Equipped effects")
## Damage reduction added while equipped.
@export var armorRating: int = 0
## Skill this armour trains and scales with: "light_armor", "heavy_armor", or "" for none.
@export var armorSkill: String = ""
## Attribute bonuses while equipped, e.g. { "strength": 2, "vigor": -1 }
@export var attributeModifiers: Dictionary[String, int] = {}

@export_group("Consumable")
## Points restored when used (needs isConsumable).
@export var restoreHealth: int = 0
@export var restoreMagicka: int = 0
@export var restoreStamina: int = 0

# --- Instancing ---------------------------------------------------------------
## The original .tres this item was copied from (null = this IS the original).
## Not exported, so it isn't saved; set by make_instance().
var template: Item = null

## The source item whose shared data (held params, etc.) should be used.
func get_template() -> Item:
	return template if template else self

## Per-instance copy that still points back at the original .tres.
## Use this instead of duplicate() for item instances.
func make_instance() -> Item:
	var copy: Item = duplicate()
	copy.template = get_template()
	return copy

# Held params always read from the original, so editing the .tres affects every copy.
func get_held_scene() -> PackedScene:
	var t := get_template()
	return t.heldScene if t.heldScene else t.itemScene

func get_held_position() -> Vector3:
	return get_template().heldPosition

func get_held_rotation() -> Vector3:
	return get_template().heldRotation

func get_held_scale() -> Vector3:
	return get_template().heldScale

# Equipped effects also read from the original .tres.
func get_armor_rating() -> int:
	return get_template().armorRating

func get_attribute_modifiers() -> Dictionary[String, int]:
	return get_template().attributeModifiers

func get_armor_skill() -> String:
	return get_template().armorSkill

## { "health": n, "magicka": n, "stamina": n } for non-zero restores (from the original .tres).
func get_restores() -> Dictionary[String, int]:
	var t := get_template()
	var out: Dictionary[String, int] = {}
	if t.restoreHealth != 0: out["health"] = t.restoreHealth
	if t.restoreMagicka != 0: out["magicka"] = t.restoreMagicka
	if t.restoreStamina != 0: out["stamina"] = t.restoreStamina
	return out
