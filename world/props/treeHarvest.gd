extends StaticBody3D
## The dead trees' trunk colliders (DeadTrees makes this body). The old trees' wood has turned hard as iron: nothing
## comes off them. Wood is cut from the small trees (copses); resin only from the sap nodes some giants bleed
## (world/props/sapNode.gd).

var trees: Node3D # the DeadTrees node (its _trunks lookup)

func show_prompt() -> void:
	Talker.notify("Old dead tree, hard as iron", 1.5)

func hide_prompt() -> void:
	pass

func interact(_player: Node) -> void:
	Talker.notify("The old wood has gone hard as iron. Nothing you have will bite it. The small trees cut, and some giants bleed sap.")
