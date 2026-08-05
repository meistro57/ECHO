class_name CarriedObjectSocket
extends Node3D

var held_object: PortableObject = null

func attach_object(obj: PortableObject) -> void:
	if obj == null:
		return

	held_object = obj
	obj.set_held(true, "apc")

	# Reparent to carry socket preserving node identity
	if obj.get_parent():
		obj.get_parent().remove_child(obj)
	add_child(obj)

	obj.transform = Transform3D.IDENTITY

	# Disable collision while held so it doesn't bump into APC
	for child in obj.get_children():
		if child is CollisionShape3D:
			(child as CollisionShape3D).disabled = true

func detach_object(new_parent: Node, global_pos: Vector3) -> PortableObject:
	if held_object == null:
		return null

	var obj: PortableObject = held_object
	held_object = null
	obj.set_held(false, "")

	remove_child(obj)
	if new_parent:
		new_parent.add_child(obj)

	obj.global_position = global_pos

	# Re-enable collision shapes
	for child in obj.get_children():
		if child is CollisionShape3D:
			(child as CollisionShape3D).disabled = false

	return obj

func is_holding_object() -> bool:
	return held_object != null
