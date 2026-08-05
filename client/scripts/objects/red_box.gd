class_name RedBox
extends StaticBody3D

@export var entity_id: String = "red_box"
@export var display_name: String = "Red Box"
@export var category: String = "portable_object"

func _ready() -> void:
	add_to_group("perceivable")
	add_to_group("portable_object")
