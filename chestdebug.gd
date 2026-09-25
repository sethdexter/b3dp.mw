extends StaticBody3D
'''
'func debug():
	print("=== CHEST DEBUG INFO ===")
	print("Name: ", name)
	print("Children: ")
	for child in get_children():
		print("  - ", child.name, " (", child.get_class(), ")")
	
	# Check if InteractableComponent exists
	if has_node("InteractableComponent"):
		print("✓ InteractableComponent found")
	else:
		print("✗ No InteractableComponent found")
'''

func _ready():
	self.name = "chest"
	return
#	debug()
	
