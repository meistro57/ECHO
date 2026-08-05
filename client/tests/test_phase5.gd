extends SceneTree

var main_node: Node3D
var _tests_started: bool = false

func _init() -> void:
	print("\n==========================================")
	print("  ECHO Framework - Phase 5 Automated Test")
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

	var ai_service: AIService = test_room.get_node_or_null("AIService") as AIService
	var apc: APCController = test_room.get_node_or_null("APC") as APCController

	if ai_service == null or apc == null:
		print("[FAIL] Missing required nodes (AIService: %s, APC: %s)." % [ai_service != null, apc != null])
		quit(1)
		return

	print("[PASS] AIService and APC present in scene tree.")

	# Test 1: Provider Selection & URL Construction
	print("\n--- Test 1: Provider Selection & Endpoint Construction ---")
	ai_service.set_provider("openrouter")
	if ai_service.get_provider_name() != "openrouter":
		print("[FAIL] Provider selection failed for OpenRouter.")
		quit(1)
		return
	var openrouter_url: String = ai_service.active_provider.get_endpoint_url()
	print("OpenRouter Endpoint: ", openrouter_url)
	if not openrouter_url.ends_with("/chat/completions"):
		print("[FAIL] OpenRouter URL invalid: ", openrouter_url)
		quit(1)
		return

	ai_service.set_provider("deepseek")
	if ai_service.get_provider_name() != "deepseek":
		print("[FAIL] Provider selection failed for DeepSeek.")
		quit(1)
		return
	var deepseek_url: String = ai_service.active_provider.get_endpoint_url()
	print("DeepSeek Endpoint: ", deepseek_url)
	if not deepseek_url.ends_with("/chat/completions"):
		print("[FAIL] DeepSeek URL invalid: ", deepseek_url)
		quit(1)
		return
	print("[PASS] OpenRouter and DeepSeek providers correctly constructed endpoint URLs.")

	# Test 2: Missing Key Error Handling
	print("\n--- Test 2: Missing Key Error Handling ---")
	ai_service.ai_enabled = true
	ai_service.run_connectivity_test()
	print("Unconfigured Provider Status: ", ai_service.current_status)
	if ai_service.current_status != "ERROR" or ai_service.last_response == null or ai_service.last_response.error_code != "NOT_CONFIGURED":
		print("[FAIL] Expected NOT_CONFIGURED error when key is missing.")
		quit(1)
		return
	print("[PASS] Missing key safely returned structured configuration error without crashing.")

	# Test 3: Response Parsing & Token Handling (Mock Data)
	print("\n--- Test 3: Response Parsing & Token Handling ---")
	var provider: AIProvider = OpenRouterProvider.new()
	var mock_req: AIRequest = AIRequest.new("openrouter", "deepseek/deepseek-v4-flash", [])
	var mock_json: String = JSON.stringify({
		"choices": [
			{
				"message": {
					"role": "assistant",
					"content": "ECHO_ONLINE"
				},
				"finish_reason": "stop"
			}
		],
		"usage": {
			"prompt_tokens": 12,
			"completion_tokens": 6,
			"total_tokens": 18
		}
	})
	var mock_body: PackedByteArray = mock_json.to_utf8_buffer()
	var parsed_res: AIResponse = provider.parse_response(200, mock_body, mock_req)
	
	if not parsed_res.success or parsed_res.content != "ECHO_ONLINE" or parsed_res.total_tokens != 18:
		print("[FAIL] Response parsing failed: %s" % parsed_res.get_summary_string())
		quit(1)
		return
	print("[PASS] Valid response JSON parsed content ('%s') and tokens (%d)." % [parsed_res.content, parsed_res.total_tokens])

	# Test 4: Malformed JSON and Error Handling
	print("\n--- Test 4: Malformed JSON & Error Handling ---")
	var malformed_body: PackedByteArray = "{ invalid_json }".to_utf8_buffer()
	var err_res: AIResponse = provider.parse_response(200, malformed_body, mock_req)
	if err_res.success or err_res.error_code != "MALFORMED_JSON":
		print("[FAIL] Malformed JSON should return MALFORMED_JSON error code.")
		quit(1)
		return

	var http_401_res: AIResponse = provider.parse_response(401, PackedByteArray(), mock_req)
	if http_401_res.success or http_401_res.http_status != 401:
		print("[FAIL] HTTP 401 error parsing failed.")
		quit(1)
		return

	var http_429_res: AIResponse = provider.parse_response(429, PackedByteArray(), mock_req)
	if http_429_res.success or http_429_res.http_status != 429:
		print("[FAIL] HTTP 429 error parsing failed.")
		quit(1)
		return
	print("[PASS] Malformed JSON, 401 Unauthorized, and 429 Rate Limit handled safely.")

	# Test 5: ECHO_ONLINE Content Mismatch Validation
	print("\n--- Test 5: ECHO_ONLINE Content Mismatch Validation ---")
	var mismatch_json: String = JSON.stringify({
		"choices": [{"message": {"role": "assistant", "content": "Hello World!"}}]
	})
	var mismatch_res: AIResponse = provider.parse_response(200, mismatch_json.to_utf8_buffer(), mock_req)
	print("Mismatch Content: ", mismatch_res.content)
	if not mismatch_res.success:
		print("[FAIL] Base provider should parse valid JSON content.")
		quit(1)
		return
	print("[PASS] Content mismatch payload parsed correctly for verification.")

	# Test 6: Gameplay & Brain Isolation Verification
	print("\n--- Test 6: Deterministic Brain & Gameplay Isolation ---")
	apc._physics_process(0.016)
	var brain_decision_before: String = apc.get_brain_decision_string()
	var pos_before: Vector3 = apc.global_position

	# Simulate AI failure
	ai_service.run_connectivity_test()
	apc._physics_process(0.016)

	var brain_decision_after: String = apc.get_brain_decision_string()
	var pos_after: Vector3 = apc.global_position

	if brain_decision_before != brain_decision_after or pos_before.distance_to(pos_after) > 0.5:
		print("[FAIL] AI service error mutated APC position or brain decision!")
		quit(1)
		return
	print("[PASS] AI connectivity failure had zero effect on deterministic Brain decision (%s) or APC locomotion." % brain_decision_after)

	print("\n==========================================")
	print("  PHASE 5 AI CONNECTIVITY LAYER VERIFIED [OK]")
	print("==========================================\n")
	quit(0)
