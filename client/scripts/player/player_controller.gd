class_name PlayerController
extends CharacterBody3D

@export var move_speed: float = 5.0
@export var jump_velocity: float = 4.5
@export var mouse_sensitivity: float = 0.003

@onready var camera_pivot: Node3D = $CameraPivot
@onready var camera: Camera3D = $CameraPivot/Camera3D

var gravity: float = ProjectSettings.get_setting("physics/3d/default_gravity", 9.8)
var is_mouse_captured: bool = true

var _attention_node: PlayerAttention

func _ready() -> void:
	add_to_group("human_player")
	set_mouse_capture(true)
	
	_attention_node = get_node_or_null("PlayerAttention") as PlayerAttention
	if _attention_node == null:
		_attention_node = PlayerAttention.new()
		_attention_node.name = "PlayerAttention"
		add_child(_attention_node)

func get_attention_snapshot() -> Dictionary:
	if _attention_node:
		return _attention_node.get_attention_snapshot()
	return {}

func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("release_mouse"):
		set_mouse_capture(not is_mouse_captured)
	elif event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		if not is_mouse_captured:
			set_mouse_capture(true)
			
	if is_mouse_captured and event is InputEventMouseMotion:
		rotate_y(-event.relative.x * mouse_sensitivity)
		if camera_pivot:
			camera_pivot.rotate_x(-event.relative.y * mouse_sensitivity)
			camera_pivot.rotation.x = clamp(camera_pivot.rotation.x, deg_to_rad(-89.0), deg_to_rad(89.0))

func set_mouse_capture(capture: bool) -> void:
	is_mouse_captured = capture
	if capture:
		Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	else:
		Input.mouse_mode = Input.MOUSE_MODE_VISIBLE

func _physics_process(delta: float) -> void:
	if not is_on_floor():
		velocity.y -= gravity * delta

	if is_mouse_captured and Input.is_action_just_pressed("jump") and is_on_floor():
		velocity.y = jump_velocity

	var input_dir := Vector2.ZERO
	if is_mouse_captured:
		input_dir = Input.get_vector("move_left", "move_right", "move_forward", "move_backward")
		
	var direction := (transform.basis * Vector3(input_dir.x, 0, input_dir.y)).normalized()
	if direction != Vector3.ZERO:
		velocity.x = direction.x * move_speed
		velocity.z = direction.z * move_speed
	else:
		velocity.x = move_toward(velocity.x, 0, move_speed)
		velocity.z = move_toward(velocity.z, 0, move_speed)

	move_and_slide()
