class_name TestRoom
extends Node3D

@onready var nav_region: NavigationRegion3D = $NavigationRegion3D

func _ready() -> void:
	if nav_region and nav_region.navigation_mesh:
		nav_region.navigation_mesh.cell_height = 0.25
		nav_region.navigation_mesh.agent_height = 1.75
		nav_region.navigation_mesh.geometry_parsed_geometry_type = NavigationMesh.PARSED_GEOMETRY_STATIC_COLLIDERS
		nav_region.bake_navigation_mesh()
