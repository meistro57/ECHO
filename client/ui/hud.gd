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
@onready var task_status_label: Label = $MarginContainer/Panel/MarginContainer/VBoxContainer/TaskStatusLabel
@onready var speech_status_label: Label = $MarginContainer/Panel/MarginContainer/VBoxContainer/SpeechStatusLabel
@onready var memory_status_label: Label = $MarginContainer/Panel/MarginContainer/VBoxContainer/MemoryStatusLabel
@onready var memory_detail_label: Label = $MarginContainer/Panel/MarginContainer/VBoxContainer/MemoryDetailLabel
@onready var memory_file_label: Label = $MarginContainer/Panel/MarginContainer/VBoxContainer/MemoryFileLabel
@onready var memory_records_list: ItemList = $MarginContainer/Panel/MarginContainer/VBoxContainer/MemoryRecordsList
@onready var delete_memory_button: Button = $MarginContainer/Panel/MarginContainer/VBoxContainer/MemoryButtons/DeleteMemoryButton
@onready var clear_memory_button: Button = $MarginContainer/Panel/MarginContainer/VBoxContainer/MemoryButtons/ClearMemoryButton
@onready var event_log_label: Label = $MarginContainer/Panel/MarginContainer/VBoxContainer/EventLogLabel
@onready var ai_status_label: Label = $MarginContainer/Panel/MarginContainer/VBoxContainer/AIStatusLabel
@onready var ai_detail_label: Label = $MarginContainer/Panel/MarginContainer/VBoxContainer/AIDetailLabel
@onready var margin_container: MarginContainer = $MarginContainer

@onready var subtitle_panel: PanelContainer = $SubtitlePanel
@onready var subtitle_label: Label = $SubtitlePanel/MarginContainer/SubtitleLabel
@onready var command_entry_container: PanelContainer = $CommandEntryContainer
@onready var command_line_edit: LineEdit = $CommandEntryContainer/MarginContainer/HBoxContainer/CommandLineEdit

var _apc_node: APCController
var _ai_service: AIService
var _conv_ctrl: ConversationController
var _mem_service: MemoryService

var is_command_entry_open: bool = false
var clear_memory_confirm_armed: bool = false
var clear_memory_confirm_timer: float = 0.0
var last_selected_memory_id: String = ""
var memory_refresh_timer: float = 0.0

func _ready() -> void:
	if phase_label:
		phase_label.text = "Phase 9: Explicit Persistent Memory & Experience Recall"

	if command_entry_container:
		command_entry_container.visible = false

	if command_line_edit:
		command_line_edit.text_submitted.connect(_on_command_submitted)

	if delete_memory_button and not delete_memory_button.pressed.is_connected(_on_delete_memory_pressed):
		delete_memory_button.pressed.connect(_on_delete_memory_pressed)
	if clear_memory_button and not clear_memory_button.pressed.is_connected(_on_clear_memory_pressed):
		clear_memory_button.pressed.connect(_on_clear_memory_pressed)
	if memory_records_list and not memory_records_list.item_selected.is_connected(_on_memory_item_selected):
		memory_records_list.item_selected.connect(_on_memory_item_selected)

func _process(delta: float) -> void:
	if Input.is_action_just_pressed("toggle_debug"):
		if margin_container:
			margin_container.visible = not margin_container.visible

	if _conv_ctrl == null:
		var convs: Array[Node] = get_tree().get_nodes_in_group("conversation_controller")
		if convs.size() > 0 and convs[0] is ConversationController:
			_conv_ctrl = convs[0] as ConversationController

	if Input.is_action_just_pressed("open_text_command") and not is_command_entry_open:
		open_command_entry()
	elif is_command_entry_open and Input.is_action_just_pressed("release_mouse"):
		close_command_entry()

	if _ai_service == null:
		var services: Array[Node] = get_tree().get_nodes_in_group("ai_service")
		if services.size() > 0 and services[0] is AIService:
			_ai_service = services[0] as AIService

	if Input.is_action_just_pressed("test_ai_connection") and _ai_service:
		_ai_service.run_connectivity_test()

	if _apc_node == null:
		var apcs: Array[Node] = get_tree().get_nodes_in_group("apc")
		if apcs.size() > 0 and apcs[0] is APCController:
			_apc_node = apcs[0] as APCController

	if Input.is_action_just_pressed("toggle_brain_mode") and _apc_node:
		_apc_node.toggle_brain_mode()

	if _mem_service == null:
		var mems: Array[Node] = get_tree().get_nodes_in_group("memory_service")
		if mems.size() > 0 and mems[0] is MemoryService:
			_mem_service = mems[0] as MemoryService

	if Input.is_action_just_pressed("clear_memory_debug"):
		_request_clear_memory_with_confirmation()

	if clear_memory_confirm_armed:
		clear_memory_confirm_timer -= delta
		if clear_memory_confirm_timer <= 0.0:
			clear_memory_confirm_armed = false
			if clear_memory_button:
				clear_memory_button.text = "Clear All (Confirm)"

	_update_subtitles_and_speech()
	_update_memory_section(delta)
	_update_apc_debug_labels()
	_update_ai_labels()

func _update_subtitles_and_speech() -> void:
	if _conv_ctrl == null:
		return
	var human_text: String = _conv_ctrl.latest_human_transcript
	var apc_text: String = _conv_ctrl.latest_apc_response_text
	var state_text: String = _conv_ctrl.get_state_string()

	if subtitle_label and subtitle_panel:
		if not human_text.is_empty() or not apc_text.is_empty():
			subtitle_panel.visible = true
			subtitle_label.text = "Human: \"%s\"\nAPC: \"%s\"" % [human_text, apc_text]
		else:
			subtitle_panel.visible = false

	if speech_status_label:
		speech_status_label.text = "Conv State: %s | PTT: %s | STT: %s | TTS: %s" % [
			state_text,
			"RECORDING" if _conv_ctrl.ptt_active else "IDLE",
			_conv_ctrl.speech_service.get_stt_provider_name() if _conv_ctrl.speech_service else "mock",
			_conv_ctrl.speech_service.get_tts_provider_name() if _conv_ctrl.speech_service else "mock"
		]

func _update_memory_section(delta: float) -> void:
	if _mem_service == null:
		return

	var mem_enabled: String = "YES" if _mem_service.memory_enabled else "NO"
	var record_count: int = _mem_service.get_total_record_count()
	var last_type: String = _mem_service.last_stored_type
	var last_query_count: int = _mem_service.last_query_count
	var last_error: String = _mem_service.last_memory_error
	if memory_status_label:
		memory_status_label.text = "Memory Enabled: %s | Records: %d | Last Type: %s | Last Query: %d | Err: %s" % [
			mem_enabled, record_count, last_type, last_query_count, last_error
		]

	var last_summary: String = _mem_service.last_stored_summary
	if last_summary.length() > 80:
		last_summary = last_summary.substr(0, 77) + "..."
	if memory_detail_label:
		memory_detail_label.text = "Session: %s | Last Summary: %s" % [_mem_service.current_session_id, last_summary]
	if memory_file_label:
		memory_file_label.text = "Memory File: %s" % _mem_service.get_storage_path()

	memory_refresh_timer -= delta
	if memory_refresh_timer > 0.0:
		return
	memory_refresh_timer = 0.75
	_refresh_memory_list()

func _refresh_memory_list() -> void:
	if _mem_service == null or memory_records_list == null:
		return
	var records: Array = _mem_service.get_all_records()
	memory_records_list.clear()
	for rec in records:
		var display: String = "[%s] %s" % [rec.memory_type, rec.summary]
		if display.length() > 120:
			display = display.substr(0, 117) + "..."
		memory_records_list.add_item(display)
		var idx: int = memory_records_list.item_count - 1
		memory_records_list.set_item_metadata(idx, rec.memory_id)
		if rec.memory_id == last_selected_memory_id:
			memory_records_list.select(idx)

func _on_memory_item_selected(index: int) -> void:
	if memory_records_list == null:
		return
	last_selected_memory_id = String(memory_records_list.get_item_metadata(index))

func _on_delete_memory_pressed() -> void:
	if _mem_service == null or last_selected_memory_id.is_empty():
		return
	_mem_service.forget_by_id(last_selected_memory_id)
	last_selected_memory_id = ""
	_refresh_memory_list()

func _on_clear_memory_pressed() -> void:
	_request_clear_memory_with_confirmation()

func _request_clear_memory_with_confirmation() -> void:
	if _mem_service == null:
		return
	if not clear_memory_confirm_armed:
		clear_memory_confirm_armed = true
		clear_memory_confirm_timer = 3.0
		if clear_memory_button:
			clear_memory_button.text = "Press Again to Confirm"
		return
	clear_memory_confirm_armed = false
	clear_memory_confirm_timer = 0.0
	_mem_service.clear_all_memories()
	if clear_memory_button:
		clear_memory_button.text = "Clear All (Confirm)"
	_refresh_memory_list()

func _update_apc_debug_labels() -> void:
	if _apc_node == null:
		return
	var decision_str: String = _apc_node.get_brain_decision_string()
	var mode_str: String = _apc_node.get_brain_mode_string()

	var fallback_str: String = "NO"
	var ai_status_str: String = "IDLE"
	var val_err: String = "None"
	var acc_act: String = "None"
	var rej_act: String = "None"
	if _apc_node.brain and _apc_node.brain.ai_brain:
		var ai_brain: AIBrain = _apc_node.brain.ai_brain
		fallback_str = "YES" if ai_brain.fallback_active else "NO"
		ai_status_str = ai_brain.decision_status
		val_err = ai_brain.last_validation_error
		acc_act = ai_brain.last_accepted_action_name
		rej_act = ai_brain.last_rejected_action_name

	if state_label:
		state_label.text = "APC Action: " + decision_str
	if brain_label:
		brain_label.text = "Brain Mode: %s | AI Status: %s | Fallback: %s | Accepted: %s | Rejected: %s | Err: %s" % [
			mode_str, ai_status_str, fallback_str, acc_act, rej_act, val_err
		]
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

	if task_status_label:
		var held_obj_str: String = "None"
		if _apc_node.interaction_controller and _apc_node.interaction_controller.get_held_object():
			var held_obj: PortableObject = _apc_node.interaction_controller.get_held_object()
			held_obj_str = "%s (%s)" % [held_obj.display_name, held_obj.object_id]
		var task_status: String = "IDLE"
		var task_step: String = "None"
		var task_error: String = "None"
		if _apc_node.task_controller:
			task_status = _apc_node.task_controller.get_task_status_string()
			task_step = _apc_node.task_controller.get_current_step_string()
			task_error = _apc_node.task_controller.last_task_error
		task_status_label.text = "Held Object: %s | Task Status: %s | Step: %s | Task Err: %s" % [
			held_obj_str, task_status, task_step, task_error
		]

	if _apc_node.has_method("get_perception_snapshot"):
		var snapshot: Dictionary = _apc_node.get_perception_snapshot()
		if snapshot.has("human_player") and player_perc_label:
			var player_data: Dictionary = snapshot["human_player"]
			var player_vis: String = "YES" if player_data.get("visible", false) else "NO"
			var player_dist: float = float(player_data.get("distance", 0.0))
			player_perc_label.text = "Player Vis: %s | Dist: %.1fm" % [player_vis, player_dist]
		if snapshot.has("nearby_objects") and redbox_perc_label:
			var objects: Array = snapshot["nearby_objects"]
			for obj in objects:
				if obj is Dictionary and obj.get("id") == "red_box":
					var red_vis: String = "YES" if obj.get("visible", false) else "NO"
					var red_dist: float = float(obj.get("distance", 0.0))
					redbox_perc_label.text = "Red Box Vis: %s | Dist: %.1fm" % [red_vis, red_dist]
					break

	if event_log_label and _apc_node.has_method("get_event_log"):
		var log_entries: Array[String] = _apc_node.get_event_log()
		var display_entries: Array[String] = []
		for i in range(min(4, log_entries.size())):
			display_entries.append(log_entries[i])
		event_log_label.text = "Event Log:\n" + ("\n".join(display_entries) if display_entries.size() > 0 else "None")

func _update_ai_labels() -> void:
	if _ai_service == null:
		return
	if ai_status_label:
		ai_status_label.text = "AI Enabled: %s | Provider: %s | Configured: %s | Model: %s | Status: %s" % [
			"YES" if _ai_service.is_ai_enabled() else "NO",
			_ai_service.get_provider_name().capitalize(),
			"YES" if _ai_service.is_provider_configured() else "NO",
			_ai_service.get_model_name(),
			_ai_service.current_status
		]
	if ai_detail_label:
		if _ai_service.last_response != null:
			var res: AIResponse = _ai_service.last_response
			ai_detail_label.text = "Last Latency: %.0fms | HTTP Code: %d | Tokens: %d | Error: %s" % [
				res.latency_ms,
				res.http_status,
				res.total_tokens,
				res.error_message if not res.error_message.is_empty() else "None"
			]
		else:
			ai_detail_label.text = "Last Latency: N/A | HTTP Code: N/A | Tokens: N/A | Error: None"

func open_command_entry() -> void:
	is_command_entry_open = true
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	if command_entry_container:
		command_entry_container.visible = true
	if command_line_edit:
		command_line_edit.clear()
		command_line_edit.grab_focus()

func close_command_entry() -> void:
	is_command_entry_open = false
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	if command_entry_container:
		command_entry_container.visible = false

func _on_command_submitted(new_text: String) -> void:
	var trimmed: String = new_text.strip_edges()
	close_command_entry()
	if not trimmed.is_empty() and _conv_ctrl:
		_conv_ctrl.process_text_command(trimmed)
