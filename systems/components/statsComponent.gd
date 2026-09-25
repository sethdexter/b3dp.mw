extends Node
class_name StatsComponent

@export var currentCharacter: Node3D

var health: Stat
var stamina: Stat
var magicka: Stat

signal s_has_died

func _ready():
	# 1. Safety Check: Ensure the character and attributes exist
	if not currentCharacter or not currentCharacter.attributeComponent:
		push_error("StatsComponent: currentCharacter or attributeComponent missing!")
		return

	var attrs = currentCharacter.attributeComponent

	# 2. Initialize Stats (Matching your _init: Name, Major, Minor)
	health = Stat.new("Health", attrs.strength, attrs.vigor)
	#stamina = Stat.new("Stamina", attrs.vigor, attrs.agility)
	#magicka = Stat.new("Magicka", attrs.intelligence, attrs.wisdom)

	# 3. Connect to the health signal to handle death
	# Assuming you added the 'depleted' or 'changed' signal to the Stat Resource
	health.depleted.connect(_on_health_depleted)

	print("Stats component initialized for: ", currentCharacter.name)

func _on_health_depleted():
	has_died()

func has_died():
	s_has_died.emit()
	print("%s has died..." % currentCharacter.name)
