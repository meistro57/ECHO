class_name APCController
extends CharacterBody3D

@export var target: Node3D

@onready var nav_agent: NavigationAgent3D = $NavigationAgent3D
@onready var perception: APCPerception = $Perception
@onready var brain: APCBrain = $Brain
@onready var action_controller: ActionController = $ActionController
@onready var interaction_controller: InteractionController = $InteractionController
@onready var task_controller: TaskController = $TaskController
@onready var carry_socket: CarriedObjectSocket = $CarrySocket

var navigation_ready: bool = false
var _gravity: float = ProjectSettings.get_setting("physics/3d/default_gravity", 9.8)
var _last_slide_collision_count: int = 0
var _current_action_request: ActionTypes.ActionRequest
var _explicit_action_request: ActionTypes.ActionRequest = null
var _explicit_action_expiry_ms: int = 0
const EXPLICIT_ACTION_DURATION_MS: int = 8000

signal state_changed(new_state: String)

func _ready() -> void:
	add_to_group("apc")
	if nav_agent:
		nav_agent.path_desired_distance = 1.0
		nav_agent.target_desired_distance = 0.5

	if brain and brain.ai_brain:
		if not brain.ai_brain.ai_task_accepted.is_connected(_on_ai_task_accepted):
			brain.ai_brain.ai_task_accepted.connect(_on_ai_task_accepted)

	call_deferred("_wait_for_navigation_ready")

func _wait_for_navigation_ready() -> void:
	await get_tree().physics_frame
	if nav_agent == null:
		return
	var map_rid: RID = nav_agent.get_navigation_map()

	while NavigationServer3D.map_get_iteration_id(map_rid) == 0:
		await get_tree().physics_frame

	# Await extra physics frames for NavigationServer region geometry linking
	await get_tree().physics_frame
	await get_tree().physics_frame

	navigation_ready = true

func _physics_process(delta: float) -> void:
	# 1. Apply gravity
	if not is_on_floor():
		velocity.y -= _gravity * delta

	# 2. Resolve player target
	if target == null:
		var players: Array[Node] = get_tree().get_nodes_in_group("human_player")
		if players.size() > 0:
			target = players[0] as Node3D

	# Handle F5 debug trigger for deterministic bring task
	if Input.is_action_just_pressed("test_bring_red_box"):
		start_bring_red_box_task()

	# 3. Wait for navigation readiness
	if not navigation_ready or target == null:
		velocity.x = move_toward(velocity.x, 0.0, 3.5 * delta * 5.0)
		velocity.z = move_toward(velocity.z, 0.0, 3.5 * delta * 5.0)
		move_and_slide()
		_last_slide_collision_count = get_slide_collision_count()
		return

	# 4. Pipeline Step 1: Perception
	var snapshot: Dictionary = {}
	if perception:
		snapshot = perception.get_perception_snapshot()

	var player_visible: bool = false
	if snapshot.has("human_player"):
		player_visible = bool(snapshot["human_player"].get("visible", false))

	# 5. Check Active Task Controller
	if task_controller and task_controller.is_running_task:
		var task_action_req: ActionTypes.ActionRequest = task_controller.process_task_tick(delta, target)
		if task_action_req != null:
			_current_action_request = task_action_req
			if action_controller:
				action_controller.execute_action_request(_current_action_request, delta, player_visible, target)
	else:
		# 6. Explicit user action takes priority over autonomous brain decisions
		if _explicit_action_request != null and Time.get_ticks_msec() <= _explicit_action_expiry_ms:
			_handle_explicit_action(delta, player_visible, target)
		else:
			_explicit_action_request = null
			# 6. Pipeline Step 2: Brain Decision
			var current_action_enum: ActionTypes.Action = ActionTypes.Action.NONE
			if _current_action_request != null:
				current_action_enum = _current_action_request.action

			if brain:
				_current_action_request = brain.decide_action_with_delta(delta, snapshot, get_state_string(), current_action_enum)

			# 7. Pipeline Step 3 & 4: Action Execution via ActionController
			if action_controller and _current_action_request != null:
				action_controller.execute_action_request(_current_action_request, delta, player_visible, target)

	# 8. Physical movement
	move_and_slide()
	_last_slide_collision_count = get_slide_collision_count()

func start_bring_red_box_task() -> void:
	if task_controller:
		var task_req: TaskRequest = TaskRequest.new("BRING_OBJECT_TO_PLAYER", "red_box", "human_debug")
		task_controller.start_task(task_req)
		print("[APCController] Started deterministic task: BRING_OBJECT_TO_PLAYER (red_box)")

func execute_user_action(request: ActionTypes.ActionRequest) -> void:
	if request == null:
		return
	_explicit_action_request = request
	_explicit_action_expiry_ms = Time.get_ticks_msec() + EXPLICIT_ACTION_DURATION_MS

func _handle_explicit_action(delta: float, player_visible: bool, player_node: Node3D) -> void:
	if _explicit_action_request == null:
		return

	match _explicit_action_request.action:
		ActionTypes.Action.PICK_UP_OBJECT:
			if interaction_controller:
				interaction_controller.request_pick_up(_explicit_action_request.target_id)
			_explicit_action_request = null
		ActionTypes.Action.DROP_HELD_OBJECT:
			if interaction_controller:
				interaction_controller.request_drop()
			_explicit_action_request = null
		ActionTypes.Action.GIVE_OBJECT_TO_PLAYER:
			if interaction_controller:
				interaction_controller.request_give_to_player()
			_explicit_action_request = null
		_:
			if action_controller:
				action_controller.execute_action_request(_explicit_action_request, delta, player_visible, player_node)

func _on_ai_task_accepted(task_req: TaskRequest) -> void:
	if task_controller:
		task_controller.start_task(task_req)
		print("[APCController] Started AI-requested task: ", task_req.task_type)

func get_state_string() -> String:
	if task_controller and task_controller.is_running_task:
		return "TASK: " + task_controller.get_current_step_string()
	if _current_action_request != null:
		return ActionTypes.get_action_name(_current_action_request.action)
	return "IDLE"

func get_last_slide_collision_count() -> int:
	return _last_slide_collision_count

func get_perception_snapshot() -> Dictionary:
	if perception:
		return perception.get_perception_snapshot()
	return {}

func get_brain_decision_string() -> String:
	if task_controller and task_controller.is_running_task:
		return "TASK: " + task_controller.get_current_step_string()
	if _current_action_request != null:
		return ActionTypes.get_action_name(_current_action_request.action)
	return "IDLE"

func get_execution_status_string() -> String:
	if task_controller and task_controller.is_running_task:
		return task_controller.get_task_status_string()
	if action_controller:
		return action_controller.current_execution_status
	return "IDLE"

func get_event_log() -> Array[String]:
	if action_controller:
		return action_controller.get_event_log()
	return []

func get_brain_mode_string() -> String:
	if brain:
		return brain.get_mode_string()
	return "DETERMINISTIC"

func toggle_brain_mode() -> String:
	if brain:
		return brain.toggle_brain_mode()
	return "DETERMINISTIC"
