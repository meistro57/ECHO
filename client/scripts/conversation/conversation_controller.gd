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

	# Handle Push-To-Talk input
	if Input.is_action_just_pressed("push_to_talk"):
		_on_ptt_pressed()
	elif Input.is_action_just_released("push_to_talk"):
		_on_ptt_released()

	# Handle Cancel key (F6)
	if Input.is_action_just_pressed("cancel_current_request"):
		cancel_active_conversation_or_task()

func _on_ptt_pressed() -> void:
	if current_state == State.RESPONDING:
		# Interruption handling: stop current speech immediately
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

	var perception_snap: Dictionary = apc_node.get_perception_snapshot() if apc_node else {}
	var attention_snap: Dictionary = player_node.get("get_attention_snapshot").call() if player_node and player_node.has_method("get_attention_snapshot") else {}
	var held_obj: PortableObject = apc_node.interaction_controller.get_held_object() if apc_node and apc_node.interaction_controller else null

	var ground_res: CommandGrounder.GroundingResult = CommandGrounder.ground_command(
		text, perception_snap, attention_snap, held_obj, pending_clarification_target
	)
	last_grounding_result = ground_res

	if ground_res.is_cancel:
		cancel_active_conversation_or_task()
		var resp: String = ResponseCoordinator.select_response_text(ground_res)
		_trigger_apc_response(resp)
		return

	if ground_res.needs_clarification:
		_set_state(State.AWAITING_CLARIFICATION)
		pending_clarification_target = "ambiguous_box"
		clarification_timer = clarification_timeout_seconds
		var resp: String = ResponseCoordinator.select_response_text(ground_res)
		_trigger_apc_response(resp)
		return

	if ground_res.success:
		pending_clarification_target = ""
		_set_state(State.EXECUTING)

		if ground_res.task_request != null and apc_node and apc_node.task_controller:
			apc_node.task_controller.start_task(ground_res.task_request)

		var resp: String = ResponseCoordinator.select_response_text(ground_res)
		_trigger_apc_response(resp)
	else:
		_set_state(State.ERROR)
		_trigger_apc_response("I couldn't complete that.")

func _trigger_apc_response(resp_text: String) -> void:
	latest_apc_response_text = resp_text
	apc_response_generated.emit(resp_text)

	if speech_service and speech_service.tts_enabled:
		speech_service.synthesize(resp_text)

	_set_state(State.RESPONDING)

	# Auto-restore IDLE after display duration
	get_tree().create_timer(3.0).timeout.connect(func():
		if current_state == State.RESPONDING:
			_set_state(State.IDLE)
	)

func cancel_active_conversation_or_task() -> void:
	if audio_capture:
		audio_capture.cancel_recording()
	if apc_node and apc_node.task_controller:
		apc_node.task_controller.cancel_task()
	pending_clarification_target = ""
	_stop_apc_speech()
	_set_state(State.IDLE)

func _stop_apc_speech() -> void:
	latest_apc_response_text = ""

func _set_state(new_state: State) -> void:
	current_state = new_state
	conversation_state_changed.emit(new_state)

func get_state_string() -> String:
	match current_state:
		State.IDLE: return "IDLE"
		State.RECORDING: return "RECORDING"
		State.TRANSCRIBING: return "TRANSCRIBING"
		State.INTERPRETING: return "INTERPRETING"
		State.AWAITING_CLARIFICATION: return "AWAITING_CLARIFICATION"
		State.EXECUTING: return "EXECUTING"
		State.RESPONDING: return "RESPONDING"
		State.ERROR: return "ERROR"
	return "IDLE"
