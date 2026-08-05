class_name HUD
extends Control

@onready var phase_label: Label = $MarginContainer/Panel/MarginContainer/VBoxContainer/PhaseLabel
@onready var state_label: Label = $MarginContainer/Panel/MarginContainer/VBoxContainer/APCStateLabel
@onready var brain_label: Label = $MarginContainer/Panel/MarginContainer/VBoxContainer/BrainLabel
@onready var distance_label: Label = $MarginContainer/Panel/MarginContainer/VBoxContainer/DistanceLabel
@onready var velocity_label: Label = $MarginContainer/Panel/MarginContainer/VBoxContainer/VelocityLabel
@onready var real_vel_label: Label = $MarginContainer/Panel/MarginContainer/VBoxContainer/RealVelocityLabel
@onready var on_floor_label: Label = $MarginContainer/Panel/MarginContainer/VBoxContainer/OnFloorLabel
@onready var collisions_label: Label = $MarginContainer/Panel/MarginContainer/VBoxContainer/CollisionsLabel
@onready var nav_finished_label: Label = $MarginContainer/Panel/MarginContainer/VBoxContainer/NavFinishedLabel
@onready var player_perc_label: Label = $MarginContainer/Panel/MarginContainer/VBoxContainer/PlayerPercLabel
@onready var redbox_perc_label: Label = $MarginContainer/Panel/MarginContainer/VBoxContainer/RedboxPercLabel
@onready var event_log_label: Label = $MarginContainer/Panel/MarginContainer/VBoxContainer/EventLogLabel
@onready var ai_status_label: Label = $MarginContainer/Panel/MarginContainer/VBoxContainer/AIStatusLabel
@onready var ai_detail_label: Label = $MarginContainer/Panel/MarginContainer/VBoxContainer/AIDetailLabel
@onready var margin_container: MarginContainer = $MarginContainer

var _apc_node: APCController
var _ai_service: AIService

func _ready() -> void:
	if phase_label:
		phase_label.text = "Phase 5: Provider-Neutral AI Connectivity Layer"

func _process(_delta: float) -> void:
	if Input.is_action_just_pressed("toggle_debug"):
		if margin_container:
			margin_container.visible = not margin_container.visible

	if _ai_service == null:
		var services: Array[Node] = get_tree().get_nodes_in_group("ai_service")
		if services.size() > 0 and services[0] is AIService:
			_ai_service = services[0] as AIService
		else:
			var found: Node = get_tree().root.find_child("AIService", true, false)
			if found is AIService:
				_ai_service = found as AIService

	if Input.is_action_just_pressed("test_ai_connection"):
		if _ai_service:
			_ai_service.run_connectivity_test()

	if _apc_node == null:
		var apcs: Array[Node] = get_tree().get_nodes_in_group("apc")
		if apcs.size() > 0 and apcs[0] is APCController:
			_apc_node = apcs[0] as APCController

	if _apc_node:
		var decision_str: String = _apc_node.get_brain_decision_string()
		var exec_str: String = _apc_node.get_execution_status_string()

		if state_label:
			state_label.text = "APC Action: " + decision_str
		if brain_label:
			brain_label.text = "Brain Decision: %s | Exec: %s" % [decision_str, exec_str]
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

		# Update Perception Debug Labels
		if _apc_node.has_method("get_perception_snapshot"):
			var snapshot: Dictionary = _apc_node.get_perception_snapshot()
			var ts_str: String = "%.1fs" % float(snapshot.get("timestamp", 0.0))

			if snapshot.has("human_player"):
				var p_data: Dictionary = snapshot["human_player"]
				if p_data.size() > 0 and player_perc_label:
					var p_vis: String = "YES" if p_data.get("visible", false) else "NO"
					var p_dist: float = float(p_data.get("distance", 0.0))
					var p_fov: String = "YES" if p_data.get("inside_fov", false) else "NO"
					var p_los: String = "YES" if p_data.get("line_of_sight", false) else "NO"
					var p_sec: Variant = p_data.get("seconds_since_last_seen", null)
					var p_sec_str: String = "%.1fs" % float(p_sec) if p_sec != null else "N/A"
					player_perc_label.text = "Player Vis: %s | Dist: %.1fm | FOV: %s | LOS: %s | LastSeen: %s (TS: %s)" % [p_vis, p_dist, p_fov, p_los, p_sec_str, ts_str]

			if snapshot.has("nearby_objects"):
				var objs: Array = snapshot["nearby_objects"]
				for obj in objs:
					if obj is Dictionary and obj.get("id") == "red_box":
						if redbox_perc_label:
							var r_vis: String = "YES" if obj.get("visible", false) else "NO"
							var r_dist: float = float(obj.get("distance", 0.0))
							var r_fov: String = "YES" if obj.get("inside_fov", false) else "NO"
							var r_los: String = "YES" if obj.get("line_of_sight", false) else "NO"
							var r_sec: Variant = obj.get("seconds_since_last_seen", null)
							var r_sec_str: String = "%.1fs" % float(r_sec) if r_sec != null else "N/A"
							redbox_perc_label.text = "Red Box Vis: %s | Dist: %.1fm | FOV: %s | LOS: %s | LastSeen: %s" % [r_vis, r_dist, r_fov, r_los, r_sec_str]

		# Update Event Log Label
		if event_log_label and _apc_node.has_method("get_event_log"):
			var log_entries: Array[String] = _apc_node.get_event_log()
			var display_entries: Array[String] = []
			var limit: int = min(4, log_entries.size()) # Show top 4 entries in HUD UI panel
			for i in range(limit):
				display_entries.append(log_entries[i])
			event_log_label.text = "Event Log:\n" + ("\n".join(display_entries) if display_entries.size() > 0 else "None")

	# Update AI Connectivity Debug Labels
	if _ai_service:
		var enabled_str: String = "YES" if _ai_service.is_ai_enabled() else "NO"
		var prov_str: String = _ai_service.get_provider_name().capitalize()
		var cfg_str: String = "YES" if _ai_service.is_provider_configured() else "NO"
		var model_str: String = _ai_service.get_model_name()
		var status_str: String = _ai_service.current_status

		if ai_status_label:
			ai_status_label.text = "AI Enabled: %s | Provider: %s | Configured: %s | Model: %s | Status: %s" % [
				enabled_str, prov_str, cfg_str, model_str, status_str
			]

		if ai_detail_label:
			if _ai_service.last_response != null:
				var res: AIResponse = _ai_service.last_response
				var lat_str: String = "%.0fms" % res.latency_ms
				var stat_code: int = res.http_status
				var tok_str: String = "%d (P:%d, C:%d)" % [res.total_tokens, res.prompt_tokens, res.completion_tokens]
				var err_str: String = res.error_message if not res.error_message.is_empty() else "None"
				ai_detail_label.text = "Last Latency: %s | HTTP Code: %d | Tokens: %s | Error: %s" % [
					lat_str, stat_code, tok_str, err_str
				]
			else:
				ai_detail_label.text = "Last Latency: N/A | HTTP Code: N/A | Tokens: N/A | Error: None"
