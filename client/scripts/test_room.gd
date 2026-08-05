class_name TestRoom
extends Node3D

@onready var nav_region: NavigationRegion3D = $NavigationRegion3D

func _ready() -> void:
	if nav_region and nav_region.navigation_mesh:
		nav_region.navigation_mesh.cell_size = 0.25
		nav_region.navigation_mesh.cell_height = 0.25
		nav_region.navigation_mesh.agent_height = 1.75
		nav_region.navigation_mesh.agent_radius = 0.5
		nav_region.navigation_mesh.agent_max_climb = 0.25
		nav_region.navigation_mesh.geometry_parsed_geometry_type = NavigationMesh.PARSED_GEOMETRY_STATIC_COLLIDERS
		nav_region.navigation_mesh.geometry_source_geometry_mode = NavigationMesh.SOURCE_GEOMETRY_ROOT_NODE_CHILDREN
		
		# Enable visible navigation debug mesh in Godot
		NavigationServer3D.set_debug_enabled(true)
		
		# Trigger bake and await completion
		nav_region.bake_navigation_mesh()
		if nav_region.is_baking():
			await nav_region.bake_finished
			print("[TestRoom] NavigationMesh bake finished. Polygon count: ", nav_region.navigation_mesh.get_polygon_count())
