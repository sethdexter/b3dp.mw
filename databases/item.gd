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
