class_name ConversationController
extends Node

enum State {
	IDLE,
	RECORDING,
	TRANSCRIBING,
	INTERPRETING,
	AWAITING_CLARIFICATION,
	EXECUTING,
	RESPONDING,
	ERROR
}

var current_state: State = State.IDLE
var latest_human_transcript: String = ""
var latest_apc_response_text: String = ""
var active_turn_id: String = ""
var pending_clarification_target: String = ""
var last_grounding_result: CommandGrounder.GroundingResult
var ptt_active: bool = false
var clarification_timer: float = 0.0

var pending_memory_confirmation_action: String = ""
var pending_memory_confirmation_text: String = ""
var pending_forget_candidates: Array = []

@export var clarification_timeout_seconds: float = 15.0

var audio_capture: AudioCaptureService
var speech_service: SpeechService
var apc_node: APCController
var player_node: Node3D

signal conversation_state_changed(new_state: State)
signal transcript_received(text: String)
signal apc_response_generated(text: String)

func _ready() -> void:
	add_to_group("conversation_controller")
	call_deferred("_connect_nodes")

func _connect_nodes() -> void:
	audio_capture = get_node_or_null("AudioCaptureService") as AudioCaptureService
	if audio_capture == null:
		audio_capture = AudioCaptureService.new()
		audio_capture.name = "AudioCaptureService"
		add_child(audio_capture)

	var speech_nodes: Array[Node] = get_tree().get_nodes_in_group("speech_service")
	if speech_nodes.size() > 0:
		speech_service = speech_nodes[0] as SpeechService

	var apcs: Array[Node] = get_tree().get_nodes_in_group("apc")
	if apcs.size() > 0 and apcs[0] is APCController:
		apc_node = apcs[0] as APCController

	var players: Array[Node] = get_tree().get_nodes_in_group("human_player")
	if players.size() > 0 and players[0] is Node3D:
		player_node = players[0] as Node3D

func _process(delta: float) -> void:
	if clarification_timer > 0.0:
		clarification_timer -= delta
		if clarification_timer <= 0.0:
			pending_clarification_target = ""

	if Input.is_action_just_pressed("push_to_talk"):
		_on_ptt_pressed()
	elif Input.is_action_just_released("push_to_talk"):
		_on_ptt_released()

	if Input.is_action_just_pressed("cancel_current_request"):
		cancel_active_conversation_or_task()

func _on_ptt_pressed() -> void:
	if current_state == State.RESPONDING:
		_stop_apc_speech()

	ptt_active = true
	_set_state(State.RECORDING)
	if audio_capture:
		audio_capture.start_recording()

func _on_ptt_released() -> void:
	if not ptt_active:
		return
	ptt_active = false
	if audio_capture:
		var buf: AudioBuffer = audio_capture.stop_recording()
		if buf != null and not buf.is_empty():
			_set_state(State.TRANSCRIBING)
			_process_audio_buffer(buf)
		else:
			_set_state(State.IDLE)

func process_text_command(typed_text: String) -> void:
	latest_human_transcript = typed_text
	transcript_received.emit(typed_text)
	_set_state(State.INTERPRETING)
	_interpret_and_execute(typed_text)

func _process_audio_buffer(buf: AudioBuffer) -> void:
	if speech_service == null:
		var speech_nodes: Array[Node] = get_tree().get_nodes_in_group("speech_service")
		if speech_nodes.size() > 0:
			speech_service = speech_nodes[0] as SpeechService

	var res: SpeechResponse
	if speech_service:
		res = speech_service.transcribe(buf)
	else:
		var mock: MockSTTProvider = MockSTTProvider.new()
		res = mock.transcribe(buf)

	if res.success and not res.transcript.is_empty():
		latest_human_transcript = res.transcript
		transcript_received.emit(res.transcript)
		_set_state(State.INTERPRETING)
		_interpret_and_execute(res.transcript)
	else:
		_set_state(State.ERROR)
		_trigger_apc_response("I couldn't hear that clearly.")

func _interpret_and_execute(text: String) -> void:
	active_turn_id = "turn_%d" % int(Time.get_ticks_msec())

	if _handle_pending_memory_confirmation(text):
		return

	var memory_services: Array[Node] = get_tree().get_nodes_in_group("memory_service")
	var memory_service: MemoryService = memory_services[0] as MemoryService if memory_services.size() > 0 else null

	var perception_snap: Dictionary = apc_node.get_perception_snapshot() if apc_node else {}
	var attention_snap: Dictionary = {}
	if player_node and player_node.has_method("get_attention_snapshot"):
		attention_snap = player_node.call("get_attention_snapshot")
	var held_obj: PortableObject = apc_node.interaction_controller.get_held_object() if apc_node and apc_node.interaction_controller else null

	var ground_res: CommandGrounder.GroundingResult = CommandGrounder.ground_command(
		text,
		perception_snap,
		attention_snap,
		held_obj,
		pending_clarification_target
	)
	last_grounding_result = ground_res

	if _handle_memory_intent(ground_res, memory_service):
		return

	if ground_res.is_cancel:
		cancel_active_conversation_or_task()
		_trigger_apc_response(ResponseCoordinator.select_response_text(ground_res))
		return

	if ground_res.needs_clarification:
		_set_state(State.AWAITING_CLARIFICATION)
		pending_clarification_target = "ambiguous_box"
		clarification_timer = clarification_timeout_seconds
		_trigger_apc_response(ResponseCoordinator.select_response_text(ground_res))
		return

	if ground_res.success:
		pending_clarification_target = ""
		_set_state(State.EXECUTING)
		if ground_res.task_request != null and apc_node and apc_node.task_controller:
			apc_node.task_controller.start_task(ground_res.task_request)
		_trigger_apc_response(ResponseCoordinator.select_response_text(ground_res))
		return

	_set_state(State.ERROR)
	_trigger_apc_response("I couldn't complete that.")

func _handle_memory_intent(ground_res: CommandGrounder.GroundingResult, memory_service: MemoryService) -> bool:
	if not ground_res.is_memory_query and not ground_res.is_memory_store_command and not ground_res.is_memory_forget_command and not ground_res.is_memory_clear_all_command:
		return false

	if memory_service == null or not memory_service.memory_enabled:
		_trigger_apc_response("Memory is currently disabled.")
		return true

	if ground_res.is_memory_query:
		var answer: Dictionary = memory_service.build_memory_answer(latest_human_transcript)
		var response_text: String = String(answer.get("text", "I don't have a stored memory of that."))
		var records: Array = answer.get("records", [])
		if records.size() > 0:
			pending_forget_candidates = records
		_trigger_apc_response(response_text)
		return true

	if ground_res.is_memory_store_command:
		if ground_res.needs_confirmation:
			pending_memory_confirmation_action = "store"
			pending_memory_confirmation_text = latest_human_transcript
			_trigger_apc_response("Please confirm memory storage by saying yes or no.")
			return true
		var stored = memory_service.record_player_statement(ground_res.memory_fact_text)
		if stored == null:
			_trigger_apc_response("I could not store that memory.")
		else:
			_trigger_apc_response("I will remember that.")
		return true

	if ground_res.is_memory_forget_command:
		var term: String = ground_res.memory_query_term.strip_edges()
		if term.is_empty() and pending_forget_candidates.size() == 1:
			var remembered = pending_forget_candidates[0]
			if memory_service.forget_by_id(remembered.memory_id):
				_trigger_apc_response("I forgot that memory.")
			else:
				_trigger_apc_response("I could not forget that memory.")
			return true

		if term.is_empty():
			_trigger_apc_response("Please tell me exactly what to forget.")
			return true

		var candidates: Array = memory_service.find_forget_candidates(term)
		if candidates.is_empty():
			_trigger_apc_response("I don't have a stored memory matching that.")
			return true

		if candidates.size() > 1:
			pending_forget_candidates = candidates
			_trigger_apc_response("I found multiple memories. Please be more specific.")
			return true

		var target = candidates[0]
		if memory_service.forget_by_id(target.memory_id):
			_trigger_apc_response("I forgot that memory.")
		else:
			_trigger_apc_response("I could not forget that memory.")
		return true

	if ground_res.is_memory_clear_all_command:
		pending_memory_confirmation_action = "clear_all"
		pending_memory_confirmation_text = ""
		_trigger_apc_response("Clear all memory requires confirmation. Say yes or no.")
		return true

	return false

func _handle_pending_memory_confirmation(raw_text: String) -> bool:
	if pending_memory_confirmation_action.is_empty():
		return false
	var normalized: String = raw_text.to_lower().strip_edges()
	var is_yes: bool = normalized == "yes" or normalized == "confirm" or normalized == "do it"
	var is_no: bool = normalized == "no" or normalized == "cancel"
	if not is_yes and not is_no:
		_trigger_apc_response("Please answer yes or no.")
		return true

	var memory_services: Array[Node] = get_tree().get_nodes_in_group("memory_service")
	var memory_service: MemoryService = memory_services[0] as MemoryService if memory_services.size() > 0 else null
	if memory_service == null:
		pending_memory_confirmation_action = ""
		pending_memory_confirmation_text = ""
		_trigger_apc_response("Memory service is unavailable.")
		return true

	if is_no:
		pending_memory_confirmation_action = ""
		pending_memory_confirmation_text = ""
		_trigger_apc_response("Okay, I won't change memory.")
		return true

	if pending_memory_confirmation_action == "store":
		var stored = memory_service.record_player_statement(pending_memory_confirmation_text)
		pending_memory_confirmation_action = ""
		pending_memory_confirmation_text = ""
		if stored == null:
			_trigger_apc_response("I could not store that memory.")
		else:
			_trigger_apc_response("I will remember that.")
		return true

	if pending_memory_confirmation_action == "clear_all":
		pending_memory_confirmation_action = ""
		pending_memory_confirmation_text = ""
		if memory_service.clear_all_memories():
			_trigger_apc_response("All stored memory has been cleared.")
		else:
			_trigger_apc_response("I could not clear memory.")
		return true

	pending_memory_confirmation_action = ""
	pending_memory_confirmation_text = ""
	return false

func _trigger_apc_response(resp_text: String) -> void:
	latest_apc_response_text = resp_text
	apc_response_generated.emit(resp_text)
	if speech_service and speech_service.tts_enabled:
		speech_service.synthesize(resp_text)
	_set_state(State.RESPONDING)
	get_tree().create_timer(3.0).timeout.connect(func() -> void:
		if current_state == State.RESPONDING:
			_set_state(State.IDLE)
	)

func cancel_active_conversation_or_task() -> void:
	if audio_capture:
		audio_capture.cancel_recording()
	if apc_node and apc_node.task_controller:
		apc_node.task_controller.cancel_task()
	pending_clarification_target = ""
	pending_memory_confirmation_action = ""
	pending_memory_confirmation_text = ""
	pending_forget_candidates.clear()
	_stop_apc_speech()
	_set_state(State.IDLE)

func _stop_apc_speech() -> void:
	latest_apc_response_text = ""

func _set_state(new_state: State) -> void:
	current_state = new_state
	conversation_state_changed.emit(new_state)

func get_state_string() -> String:
	match current_state:
		State.IDLE:
			return "IDLE"
		State.RECORDING:
			return "RECORDING"
		State.TRANSCRIBING:
			return "TRANSCRIBING"
		State.INTERPRETING:
			return "INTERPRETING"
		State.AWAITING_CLARIFICATION:
			return "AWAITING_CLARIFICATION"
		State.EXECUTING:
			return "EXECUTING"
		State.RESPONDING:
			return "RESPONDING"
		State.ERROR:
			return "ERROR"
	return "IDLE"
