extends Node
class_name StatHandlerComponent

@export var currentCharacter: Node3D

var health: Stat
var stamina: Stat
var magicka: Stat

signal s_has_died

func _ready():
	# Ensure the character has the attributes first
	var attrs = currentCharacter.get_node("AttributeComponent") 
	
	# Initialize Stats by passing the Attribute Objects
	health  = Stat.new("Health", attrs.strength, attrs.vigor)
	stamina = Stat.new("Stamina", attrs.vigor, attrs.agility)
	magicka = Stat.new("Magicka", attrs.intelligence, attrs.wisdom)

	# Connect the health depletion to our death signal
	health.depleted.connect(_on_health_depleted)
	
	# Connect to changes to update UI (Assuming you have a UI setup)
	health.changed.connect(_update_health_bar)

func _on_health_depleted():
	s_has_died.emit()
	print(currentCharacter.name, " has died!")

func _update_health_bar(cur, m_val):
	# Example: Signal out to a UI Manager
	pass
