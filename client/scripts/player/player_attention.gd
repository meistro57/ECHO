class_name PlayerAttention
extends Node3D

@export var max_aim_distance: float = 15.0
@export var recent_memory_duration: float = 3.0

var aim_target_id: String = ""
var aim_target_distance: float = 0.0
var is_target_visible: bool = false
var recent_target_id: String = ""

var _player: CharacterBody3D
var _camera: Camera3D
var _recent_timer: float = 0.0

func _ready() -> void:
	_player = get_parent() as CharacterBody3D
	if _player:
		_camera = _player.get_node_or_null("Camera3D") as Camera3D

func _physics_process(delta: float) -> void:
	if _recent_timer > 0.0:
		_recent_timer -= delta
		if _recent_timer <= 0.0:
			recent_target_id = ""

	_update_aim_raycast()

func get_attention_snapshot() -> Dictionary:
	return {
		"aim_target_id": aim_target_id,
		"aim_target_distance": aim_target_distance,
		"is_target_visible": is_target_visible,
		"recent_target_id": recent_target_id
	}

func _update_aim_raycast() -> void:
	if _camera == null or _player == null:
		return

	var space_state: PhysicsDirectSpaceState3D = _player.get_world_3d().direct_space_state
	if space_state == null:
		return

	var from_pos: Vector3 = _camera.global_position
	var forward: Vector3 = -_camera.global_transform.basis.z.normalized()
	var to_pos: Vector3 = from_pos + forward * max_aim_distance

	var query: PhysicsRayQueryParameters3D = PhysicsRayQueryParameters3D.create(from_pos, to_pos)
	query.exclude = [_player.get_rid()]

	var ray_res: Dictionary = space_state.intersect_ray(query)

	if not ray_res.is_empty():
		var collider: Object = ray_res.get("collider")
		if collider is Node:
			var node: Node = collider as Node
			var target_id: String = ""
			if node.get("object_id") != null:
				target_id = String(node.get("object_id"))
			elif node.get("entity_id") != null:
				target_id = String(node.get("entity_id"))

			if not target_id.is_empty():
				aim_target_id = target_id
				aim_target_distance = from_pos.distance_to(ray_res.get("position", from_pos))
				is_target_visible = true
				recent_target_id = target_id
				_recent_timer = recent_memory_duration
				return

	aim_target_id = ""
	aim_target_distance = 0.0
	is_target_visible = false
