class_name HUD
extends Control

@onready var phase_label: Label = $MarginContainer/Panel/MarginContainer/VBoxContainer/PhaseLabel
@onready var state_label: Label = $MarginContainer/Panel/MarginContainer/VBoxContainer/APCStateLabel
@onready var distance_label: Label = $MarginContainer/Panel/MarginContainer/VBoxContainer/DistanceLabel
@onready var velocity_label: Label = $MarginContainer/Panel/MarginContainer/VBoxContainer/VelocityLabel
@onready var real_vel_label: Label = $MarginContainer/Panel/MarginContainer/VBoxContainer/RealVelocityLabel
@onready var on_floor_label: Label = $MarginContainer/Panel/MarginContainer/VBoxContainer/OnFloorLabel
@onready var collisions_label: Label = $MarginContainer/Panel/MarginContainer/VBoxContainer/CollisionsLabel
@onready var nav_finished_label: Label = $MarginContainer/Panel/MarginContainer/VBoxContainer/NavFinishedLabel
@onready var margin_container: MarginContainer = $MarginContainer

var _apc_node: APCController

func _ready() -> void:
	if phase_label:
		phase_label.text = "Phase 2: APC Locomotion & Following"

func _process(_delta: float) -> void:
	if Input.is_action_just_pressed("toggle_debug"):
		if margin_container:
			margin_container.visible = not margin_container.visible

	if _apc_node == null:
		var apcs: Array[Node] = get_tree().get_nodes_in_group("apc")
		if apcs.size() > 0 and apcs[0] is APCController:
			_apc_node = apcs[0] as APCController

	if _apc_node:
		if state_label:
			state_label.text = "APC State: " + _apc_node.get_state_string()
		if distance_label and _apc_node.target:
			var dist: float = _apc_node.global_position.distance_to(_apc_node.target.global_position)
			distance_label.text = "Distance: %.2fm" % dist
		if velocity_label:
			var vel: Vector3 = _apc_node.velocity
			velocity_label.text = "Cmd Velocity: (%.1f, %.1f, %.1f) [%.1fm/s]" % [vel.x, vel.y, vel.z, Vector2(vel.x, vel.z).length()]
		if real_vel_label:
			var rvel: Vector3 = _apc_node.get_real_velocity()
			real_vel_label.text = "Real Velocity: (%.1f, %.1f, %.1f) [%.1fm/s]" % [rvel.x, rvel.y, rvel.z, Vector2(rvel.x, rvel.z).length()]
		if on_floor_label:
			on_floor_label.text = "Is On Floor: %s" % ("YES" if _apc_node.is_on_floor() else "NO")
		if collisions_label:
			collisions_label.text = "Slide Collisions: %d" % _apc_node.get_last_slide_collision_count()
		if nav_finished_label and _apc_node.nav_agent:
			nav_finished_label.text = "Nav Finished: %s" % ("YES" if _apc_node.nav_agent.is_navigation_finished() else "NO")
