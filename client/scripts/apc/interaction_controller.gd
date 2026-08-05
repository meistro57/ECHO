class_name InteractionController
extends Node3D

@export var interaction_range: float = 1.5
@export var giving_distance: float = 2.0

var _apc: CharacterBody3D
var _carry_socket: CarriedObjectSocket
var _last_interaction_result: ActionTypes.ActionResult

func _ready() -> void:
	_apc = get_parent() as CharacterBody3D
	if _apc:
		_carry_socket = _apc.get_node_or_null("CarrySocket") as CarriedObjectSocket

func request_pick_up(target_id: String) -> ActionTypes.ActionResult:
	var start_time: float = Time.get_ticks_msec() / 1000.0
	var res: ActionTypes.ActionResult = ActionTypes.ActionResult.new(false, "FAILED", "", start_time, start_time)
	_last_interaction_result = res

	if _apc == null:
		res.message = "APC reference missing"
		return res

	if _carry_socket == null:
		_carry_socket = _apc.get_node_or_null("CarrySocket") as CarriedObjectSocket

	if _carry_socket == null:
		res.message = "CarrySocket missing"
		return res

	if _carry_socket.is_holding_object():
		res.message = "APC is already carrying an object (%s)" % _carry_socket.held_object.object_id
		return res

	if target_id.is_empty():
		res.message = "Target ID is empty"
		return res

	# Find target object in scene tree
	var target_obj: PortableObject = _find_portable_object(target_id)
	if target_obj == null:
		res.message = "Target object '%s' not found in scene tree" % target_id
		return res

	if not target_obj.is_portable:
		res.message = "Object '%s' is not portable" % target_id
		return res

	if target_obj.is_held:
		res.message = "Object '%s' is already held by '%s'" % [target_id, target_obj.current_holder_id]
		return res

	# Distance validation
	var dist: float = _apc.global_position.distance_to(target_obj.global_position)
	if dist > interaction_range:
		res.message = "Target '%s' is outside interaction range (%.2fm > %.2fm)" % [target_id, dist, interaction_range]
		return res

	# Execute pickup
	_carry_socket.attach_object(target_obj)
	res.success = true
	res.status = "COMPLETED"
	res.message = "Picked up object '%s'" % target_id
	res.time_completed = Time.get_ticks_msec() / 1000.0
	return res

func request_drop() -> ActionTypes.ActionResult:
	var start_time: float = Time.get_ticks_msec() / 1000.0
	var res: ActionTypes.ActionResult = ActionTypes.ActionResult.new(false, "FAILED", "", start_time, start_time)
	_last_interaction_result = res

	if _apc == null or _carry_socket == null or not _carry_socket.is_holding_object():
		res.message = "No object held to drop"
		return res

	var forward_dir: Vector3 = -_apc.global_transform.basis.z.normalized()
	var drop_target_xz: Vector3 = _apc.global_position + forward_dir * 1.0

	# Find safe floor Y position via raycast
	var drop_pos: Vector3 = _find_safe_drop_position(drop_target_xz)
	
	var room_parent: Node = _apc.get_parent()
	var dropped_obj: PortableObject = _carry_socket.detach_object(room_parent, drop_pos)

	if dropped_obj:
		res.success = true
		res.status = "COMPLETED"
		res.message = "Dropped object '%s' safely at (%.1f, %.1f, %.1f)" % [dropped_obj.object_id, drop_pos.x, drop_pos.y, drop_pos.z]
	else:
		res.message = "Failed to detach object"

	res.time_completed = Time.get_ticks_msec() / 1000.0
	return res

func request_give_to_player() -> ActionTypes.ActionResult:
	var start_time: float = Time.get_ticks_msec() / 1000.0
	var res: ActionTypes.ActionResult = ActionTypes.ActionResult.new(false, "FAILED", "", start_time, start_time)
	_last_interaction_result = res

	if _apc == null or _carry_socket == null or not _carry_socket.is_holding_object():
		res.message = "No object held to give"
		return res

	var players: Array[Node] = get_tree().get_nodes_in_group("human_player")
	if players.size() == 0 or not (players[0] is Node3D):
		res.message = "Human player not found"
		return res

	var player_node: Node3D = players[0] as Node3D
	var dist_to_player: float = _apc.global_position.distance_to(player_node.global_position)

	if dist_to_player > giving_distance:
		res.message = "APC is outside giving distance to player (%.2fm > %.2fm)" % [dist_to_player, giving_distance]
		return res

	# Place object safely between APC and player
	var give_pos: Vector3 = (_apc.global_position + player_node.global_position) * 0.5
	give_pos.y = 0.5 # Floor surface height for RedBox center

	var room_parent: Node = _apc.get_parent()
	var given_obj: PortableObject = _carry_socket.detach_object(room_parent, give_pos)

	if given_obj:
		res.success = true
		res.status = "COMPLETED"
		res.message = "Gave object '%s' to player" % given_obj.object_id
	else:
		res.message = "Failed to detach object for transfer"

	res.time_completed = Time.get_ticks_msec() / 1000.0
	return res

func get_held_object() -> PortableObject:
	if _carry_socket:
		return _carry_socket.held_object
	return null

func get_last_result() -> ActionTypes.ActionResult:
	return _last_interaction_result

func _find_portable_object(obj_id: String) -> PortableObject:
	var perceivables: Array[Node] = get_tree().get_nodes_in_group("perceivable")
	for node in perceivables:
		if node is PortableObject:
			var p_obj: PortableObject = node as PortableObject
			if p_obj.object_id == obj_id or p_obj.entity_id == obj_id:
				return p_obj
	return null

func _find_safe_drop_position(target_xz: Vector3) -> Vector3:
	var drop_y: float = 0.5 # Floor height default
	if _apc:
		var space_state: PhysicsDirectSpaceState3D = _apc.get_world_3d().direct_space_state
		if space_state:
			var ray_from: Vector3 = Vector3(target_xz.x, _apc.global_position.y + 1.0, target_xz.z)
			var ray_to: Vector3 = Vector3(target_xz.x, _apc.global_position.y - 2.0, target_xz.z)
			var query: PhysicsRayQueryParameters3D = PhysicsRayQueryParameters3D.create(ray_from, ray_to)
			query.exclude = [_apc.get_rid()]
			var ray_res: Dictionary = space_state.intersect_ray(query)
			if not ray_res.is_empty():
				var hit_pos: Vector3 = ray_res.get("position", Vector3.ZERO)
				drop_y = hit_pos.y + 0.4 # Offset box half-height
	return Vector3(target_xz.x, drop_y, target_xz.z)
