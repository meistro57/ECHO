extends SceneTree

var main_node: Node3D
var _tests_started: bool = false

func _init() -> void:
	print("\n==========================================")
	print("  ECHO Framework - Phase 8 Automated Test")
	print("==========================================\n")

	var main_scene = load("res://scenes/main.tscn")
	if main_scene == null:
		print("[FAIL] Could not load res://scenes/main.tscn")
		quit(1)
		return

	main_node = main_scene.instantiate() as Node3D
	root.add_child(main_node)

func _process(_delta: float) -> bool:
	if not _tests_started:
		_tests_started = true
		run_tests()
	return false

func run_tests() -> void:
	await physics_frame
	await physics_frame
	await physics_frame

	var test_room = main_node.get_node_or_null("TestRoom")
	if test_room == null:
		print("[FAIL] TestRoom node missing.")
		quit(1)
		return

	var apc: APCController = test_room.get_node_or_null("APC") as APCController
	var player: Node3D = test_room.get_node_or_null("Player") as Node3D
	var red_box: PortableObject = test_room.find_child("RedBox", true, false) as PortableObject
	var speech_service: SpeechService = test_room.get_node_or_null("SpeechService") as SpeechService
	var conv_ctrl: ConversationController = test_room.get_node_or_null("ConversationController") as ConversationController

	if apc == null or player == null or red_box == null or speech_service == null or conv_ctrl == null:
		print("[FAIL] Missing Phase 8 required nodes (APC: %s, Player: %s, RedBox: %s, Speech: %s, Conv: %s)." % [
			apc != null, player != null, red_box != null, speech_service != null, conv_ctrl != null
		])
		quit(1)
		return

	print("[PASS] APC, Player, RedBox, SpeechService, and ConversationController present in scene.")

	# Test 1 & 2: Push-To-Talk State Transitions & Empty Audio Rejection
	print("\n--- Test 1 & 2: Push-To-Talk Transitions & Empty Audio Rejection ---")
	conv_ctrl._on_ptt_pressed()
	if conv_ctrl.get_state_string() != "RECORDING":
		print("[FAIL] PTT press should set state to RECORDING.")
		quit(1)
		return

	conv_ctrl._on_ptt_released() # Empty audio buffer -> IDLE
	if conv_ctrl.get_state_string() != "IDLE":
		print("[FAIL] Empty audio buffer should safely return state to IDLE.")
		quit(1)
		return
	print("[PASS] Push-to-talk recording and empty audio rejection verified.")

	# Test 3, 4, 5: Command Grounding (Follow, Bring Red Box, Wait)
	print("\n--- Test 3, 4, 5: Command Grounding ---")
	# 3a: "follow me"
	var g_follow: CommandGrounder.GroundingResult = CommandGrounder.ground_command("follow me", {}, {})
	if not g_follow.success or g_follow.action_request.action != ActionTypes.Action.FOLLOW_PLAYER:
		print("[FAIL] Grounding 'follow me' failed.")
		quit(1)
		return
	print("[PASS] 'follow me' correctly grounded to FOLLOW_PLAYER.")

	# 3b: "bring me the red box"
	var g_bring: CommandGrounder.GroundingResult = CommandGrounder.ground_command("bring me the red box", {}, {})
	if not g_bring.success or g_bring.task_request == null or g_bring.task_request.task_type != "BRING_OBJECT_TO_PLAYER":
		print("[FAIL] Grounding 'bring me the red box' failed.")
		quit(1)
		return
	print("[PASS] 'bring me the red box' correctly grounded to BRING_OBJECT_TO_PLAYER task.")

	# 3c: "wait"
	var g_wait: CommandGrounder.GroundingResult = CommandGrounder.ground_command("wait", {}, {})
	if not g_wait.success or g_wait.action_request.action != ActionTypes.Action.WAIT:
		print("[FAIL] Grounding 'wait' failed.")
		quit(1)
		return
	print("[PASS] 'wait' correctly grounded to WAIT.")

	# Test 6: "drop it" with Held Object Context
	print("\n--- Test 6: 'drop it' with Held Object Context ---")
	var g_drop_empty: CommandGrounder.GroundingResult = CommandGrounder.ground_command("drop it", {}, {}, null)
	if g_drop_empty.success:
		print("[FAIL] 'drop it' without held object should have failed!")
		quit(1)
		return
	print("Drop without held object error: ", g_drop_empty.error_message)

	var g_drop_held: CommandGrounder.GroundingResult = CommandGrounder.ground_command("drop it", {}, {}, red_box)
	if not g_drop_held.success or g_drop_held.action_request.action != ActionTypes.Action.DROP_HELD_OBJECT:
		print("[FAIL] 'drop it' with held object failed.")
		quit(1)
		return
	print("[PASS] 'drop it' correctly grounded to DROP_HELD_OBJECT when holding object.")

	# Test 7 & 8: Reference Grounding & Ambiguous Clarification
	print("\n--- Test 7 & 8: Reference Grounding & Ambiguous Clarification ---")
	# 8a: Aim target grounding ("bring me that")
	var att_snap_aim: Dictionary = { "aim_target_id": "red_box" }
	var g_aim: CommandGrounder.GroundingResult = CommandGrounder.ground_command("bring me that", {}, att_snap_aim)
	if not g_aim.success or g_aim.task_request == null or g_aim.task_request.target_id != "red_box":
		print("[FAIL] Reference grounding 'bring me that' with aim target failed.")
		quit(1)
		return
	print("[PASS] 'bring me that' correctly resolved using player attention gaze raycast.")

	# 8b: Ambiguous reference ("bring me the box" with multiple objects)
	var perc_snap_multi: Dictionary = {
		"nearby_objects": [
			{ "id": "red_box_1" },
			{ "id": "red_box_2" }
		]
	}
	var g_ambig: CommandGrounder.GroundingResult = CommandGrounder.ground_command("bring me the box", perc_snap_multi, {})
	if not g_ambig.needs_clarification or g_ambig.clarification_prompt.is_empty():
		print("[FAIL] Ambiguous reference should request clarification!")
		quit(1)
		return
	print("Clarification Prompt: ", g_ambig.clarification_prompt)
	print("[PASS] Ambiguous reference correctly triggered one-turn clarification.")

	# Test 9: Unknown Command Rejection
	print("\n--- Test 9: Unknown Command Rejection ---")
	var g_unknown: CommandGrounder.GroundingResult = CommandGrounder.ground_command("sing a song", {}, {})
	if g_unknown.success:
		print("[FAIL] Unknown command 'sing a song' should have been rejected!")
		quit(1)
		return
	print("Unknown command error: ", g_unknown.error_message)
	print("[PASS] Unknown command rejected safely.")

	# Test 10: Mock STT & TTS Providers
	print("\n--- Test 10: Mock STT & TTS Provider Execution ---")
	var mock_stt: MockSTTProvider = MockSTTProvider.new()
	var mock_buf: AudioBuffer = AudioBuffer.new(PackedFloat32Array([0.1, -0.1, 0.2]), 16000, 1)
	var stt_res: SpeechResponse = mock_stt.transcribe(mock_buf)
	if not stt_res.success or stt_res.transcript.is_empty():
		print("[FAIL] Mock STT provider transcription failed.")
		quit(1)
		return
	print("Mock STT Transcript: ", stt_res.transcript)

	var mock_tts: MockTTSProvider = MockTTSProvider.new()
	var tts_res: SpeechResponse = mock_tts.synthesize("I'll bring it to you.")
	if not tts_res.success:
		print("[FAIL] Mock TTS provider synthesis failed.")
		quit(1)
		return
	print("Mock TTS Latency: ", tts_res.latency_ms, "ms")
	print("[PASS] Mock STT and TTS provider pipelines verified.")

	# Test 11: Task Cancellation via Voice / Key
	print("\n--- Test 11: Task Cancellation via Voice / Key ---")
	conv_ctrl.process_text_command("bring me the red box")
	if not apc.task_controller.is_running_task:
		print("[FAIL] Task did not start from text command.")
		quit(1)
		return
	conv_ctrl.cancel_active_conversation_or_task()
	if apc.task_controller.is_running_task or conv_ctrl.get_state_string() != "IDLE":
		print("[FAIL] Task cancellation failed.")
		quit(1)
		return
	print("[PASS] Task cancellation via voice/key verified.")

	# Test 12: Explicit instructions physically executed
	print("\n--- Test 12: Physical Instruction Execution ---")
	# Place APC near player so the autonomous brain would LOOK, not FOLLOW
	apc.global_position = player.global_position + Vector3(3, 0, 0)
	await physics_frame
	await physics_frame
	var pos_before_follow: Vector3 = apc.global_position
	conv_ctrl.process_text_command("follow me")
	await physics_frame
	var moved_follow: bool = false
	for i in range(90):
		await physics_frame
		if apc.global_position.distance_to(pos_before_follow) > 0.25:
			moved_follow = true
			break
	if not moved_follow:
		print("[FAIL] 'follow me' did not physically move the APC.")
		quit(1)
		return
	print("[PASS] 'follow me' physically moved the APC.")

	conv_ctrl.process_text_command("wait")
	await physics_frame
	# allow deceleration from full follow speed, then verify the APC comes to rest
	for i in range(60):
		await physics_frame
	var rest_check_start: Vector3 = apc.global_position
	for i in range(20):
		await physics_frame
	var drift: float = apc.global_position.distance_to(rest_check_start)
	if drift > 0.1:
		print("[FAIL] 'wait' did not stop the APC (still drifting %.2fm)." % drift)
		quit(1)
		return
	print("[PASS] 'wait' physically stopped the APC.")

	print("\n==========================================")
	print("  PHASE 8 MULTIMODAL SPEECH VERIFIED [OK]")
	print("==========================================\n")
	quit(0)
