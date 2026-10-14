extends Node
class_name AttributesComponent

@export var currentCharacter: Node3D

@export_group("Starting attributes")
## Base values applied on ready (health = strength*0.8 + vigor*0.2, etc).
@export var base_strength: int = 10
@export var base_vigor: int = 10
@export var base_agility: int = 10
@export var base_intelligence: int = 10
@export var base_wisdom: int = 10

var strength: 		Attribute = Attribute.new();
var vigor:    		Attribute = Attribute.new();
var agility:  		Attribute = Attribute.new();
var intelligence:  Attribute = Attribute.new();
var wisdom:    	Attribute = Attribute.new();

## Look up an attribute by name ("strength", "Vigor"...). Null if unknown.
func get_attribute(attr_name: String) -> Attribute:
	var value = get(attr_name.to_lower())
	return value if value is Attribute else null

func _init() -> void:
	pass

func _ready() -> void:
	# Runs before StatsComponent._ready (attributes node comes first), so stats see these.
	strength.baseValue = base_strength
	vigor.baseValue = base_vigor
	agility.baseValue = base_agility
	intelligence.baseValue = base_intelligence
	wisdom.baseValue = base_wisdom
	if (strength && vigor):
		print("attributes component initialized...")
	pass

func _process(_delta) -> void:
	pass
