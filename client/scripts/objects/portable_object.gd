class_name PortableObject
extends StaticBody3D

@export var object_id: String = "red_box"
@export var display_name: String = "Red Box"
@export var category: String = "portable_object"
@export var is_portable: bool = true
@export var is_held: bool = false
@export var current_holder_id: String = ""

var entity_id: String:
	get: return object_id
	set(val): object_id = val

func _ready() -> void:
	add_to_group("perceivable")
	add_to_group("portable_object")

func set_held(held: bool, holder_id: String = "") -> void:
	is_held = held
	current_holder_id = holder_id if held else ""
