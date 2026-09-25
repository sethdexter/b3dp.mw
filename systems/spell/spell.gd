extends Resource
class_name Spell

var name: String = "default_spell_name"
var description: String = "defualt_description."

var is_passive: bool

var cost_health: int; var cost_stamina: int; var cost_magicka: int

var is_on_cooldown: bool
var cooldown_timer: float

##each effects requires a declared effectobject to have a unique timer
var example_effect: Effect = Effect.new()

var effects_component = {"effect" : example_effect}

# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	
	is_on_cooldown = false
	print(effects_component["effect"])
	pass
