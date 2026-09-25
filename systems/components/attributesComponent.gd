extends Node
class_name AttributesComponent

@export var currentCharacter: Node3D

@export_group("Attributes")
var strength: 		Attribute = Attribute.new();
var vigor:    		Attribute = Attribute.new();
#var agility:  		Attribute = Attribute.new();
#var intelligence:  Attribute = Attribute.new();
#var wisdom:    	Attribute = Attribute.new();

func _init() -> void:
	pass

func _ready() -> void:
	if (strength && vigor):
		print("attributes component initialized...")
	pass

func _process(_delta) -> void:
	pass
