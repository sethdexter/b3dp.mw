extends Node3D

func _ready() -> void:
	# Bake mob pathfinding from the static level geometry (group "navmesh").
	$NavigationRegion3D.bake_navigation_mesh()
