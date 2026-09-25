extends Item

var attackTypes = {
		"slashDamage": 0,
		"pierceDamage": 0,
		"bludgeningDamage": 0,
		}

var range: float
var attackSpeed: float

var isEquippped = false
var governingSkill: Skill

var modifierList: Array

# Called when the node enters the scene tree for the first time.
func _init(p_Name   		= "default_item_name",
		   p_itemId 		= "0000",
		   p_stackCount 	= 1,
		   p_maxStackCount  = 1,
		   p_weight 		= 1):                            
		
		Name 		  = p_Name
		itemId 		  = p_itemId
		maxStackCount = p_maxStackCount 
		weight        = p_weight
		
		isEquippable   = true
		equippableSlot = "equipment_slot"
		itemDesription = "description."
		
