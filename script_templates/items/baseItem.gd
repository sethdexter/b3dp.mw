extends Resource

@export var itemScene: PackedScene

var Name: 			 String
var itemId: 		 String
var maxStackCount:   int
var weight: 		 int
var isEquippable   = false
var isEquipped     = false
var equippableSlot = false
var isConsumable   = false
var itemDesription = "defualt item despription."

func _init(p_Name   		= "default_item_name",
		   p_itemId 		= "0000",
		   p_stackCount 	= 1,
		   p_maxStackCount  = 99,
		   p_weight 		= 1):

		Name 		  = p_Name
		itemId 		  = p_itemId
		maxStackCount = p_maxStackCount 
		weight        = p_weight

# Called when the node enters the scene tree for the first time.
func _ready():
	pass # Replace with function body.

# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(_delta):
	pass
