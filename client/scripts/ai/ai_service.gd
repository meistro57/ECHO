class_name AIService
extends Node

signal request_started(request_id: String)
signal request_completed(response: AIResponse)
signal request_failed(response: AIResponse)
signal provider_changed(provider_name: String)

@onready var _http_request: HTTPRequest = $HTTPRequest

var ai_enabled: bool = false
var provider_type: String = "openrouter"
var timeout_seconds: float = 20.0

var active_provider: AIProvider
var current_status: String = "IDLE"
var last_response: AIResponse
var current_request: AIRequest
var is_request_in_flight: bool = false

func _ready() -> void:
	# Parse environment configuration
	var env_enabled: String = OS.get_environment("ECHO_AI_ENABLED").to_lower().strip_edges()
	ai_enabled = (env_enabled == "true" or env_enabled == "1")

	var env_prov: String = OS.get_environment("ECHO_AI_PROVIDER").to_lower().strip_edges()
	if not env_prov.is_empty():
		provider_type = env_prov

	var env_timeout: String = OS.get_environment("ECHO_AI_TIMEOUT_SECONDS").strip_edges()
	if not env_timeout.is_empty() and env_timeout.is_valid_float():
		timeout_seconds = env_timeout.to_float()

	if _http_request == null:
		_http_request = HTTPRequest.new()
		_http_request.name = "HTTPRequest"
		add_child(_http_request)

	_http_request.timeout = timeout_seconds
	if not _http_request.request_completed.is_connected(_on_http_request_completed):
		_http_request.request_completed.connect(_on_http_request_completed)

	_setup_provider(provider_type)

func set_provider(prov_name: String) -> void:
	provider_type = prov_name.to_lower().strip_edges()
	_setup_provider(provider_type)
	provider_changed.emit(get_provider_name())

func _setup_provider(prov_name: String) -> void:
	match prov_name:
		"openrouter":
			active_provider = OpenRouterProvider.new()
		"deepseek":
			active_provider = DeepSeekProvider.new()
		"disabled", _:
			active_provider = null
	current_status = "IDLE"

func is_ai_enabled() -> bool:
	return ai_enabled

func is_provider_configured() -> bool:
	if active_provider == null:
		return false
	return active_provider.is_configured()

func get_provider_name() -> String:
	if active_provider:
		return active_provider.get_provider_name()
	return "disabled" if provider_type == "disabled" else "none"

func get_model_name() -> String:
	if active_provider:
		return active_provider.get_model()
	return "None"

func run_connectivity_test() -> void:
	if is_request_in_flight:
		print("[AIService] Request already in flight. Ignoring duplicate test call.")
		return

	if not ai_enabled:
		var err_res: AIResponse = AIResponse.new()
		err_res.success = false
		err_res.error_code = "AI_DISABLED"
		err_res.error_message = "AI service is disabled (ECHO_AI_ENABLED=false)"
		last_response = err_res
		current_status = "ERROR"
		request_failed.emit(err_res)
		return

	if active_provider == null or not active_provider.is_configured():
		var err_res: AIResponse = AIResponse.new()
		err_res.provider = get_provider_name()
		err_res.model = get_model_name()
		err_res.success = false
		err_res.error_code = "NOT_CONFIGURED"
		err_res.error_message = "Provider '%s' is not configured (missing API Key)" % get_provider_name()
		last_response = err_res
		current_status = "ERROR"
		request_failed.emit(err_res)
		return

	var messages: Array[Dictionary] = [
		{
			"role": "system",
			"content": "You are the connectivity test for ECHO. Reply with exactly ECHO_ONLINE."
		},
		{
			"role": "user",
			"content": "Return the required test response."
		}
	]

	current_request = AIRequest.new(get_provider_name(), get_model_name(), messages, timeout_seconds)
	
	var endpoint_url: String = active_provider.get_endpoint_url()
	var headers: PackedStringArray = active_provider.build_headers()
	var body_json: String = active_provider.build_request_body(current_request)

	current_status = "REQUESTING"
	is_request_in_flight = true
	request_started.emit(current_request.request_id)

	# Log request start silently without authorization headers or secret keys
	print("[AIService] Starting connectivity request %s to provider '%s' (model '%s')" % [
		current_request.request_id, current_request.provider, current_request.model
	])

	var err: Error = _http_request.request(endpoint_url, headers, HTTPClient.METHOD_POST, body_json)
	if err != OK:
		is_request_in_flight = false
		var err_res: AIResponse = AIResponse.new()
		err_res.provider = get_provider_name()
		err_res.model = get_model_name()
		err_res.request_id = current_request.request_id
		err_res.success = false
		err_res.error_code = "REQUEST_FAILED"
		err_res.error_message = "HTTPRequest failed to initiate (Error code %d)" % err
		last_response = err_res
		current_status = "ERROR"
		request_failed.emit(err_res)

func cancel_request() -> void:
	if is_request_in_flight and _http_request:
		_http_request.cancel_request()
		is_request_in_flight = false
		var cancel_res: AIResponse = AIResponse.new()
		cancel_res.provider = get_provider_name()
		cancel_res.model = get_model_name()
		if current_request:
			cancel_res.request_id = current_request.request_id
		cancel_res.success = false
		cancel_res.error_code = "CANCELLED"
		cancel_res.error_message = "Request was cancelled"
		last_response = cancel_res
		current_status = "ERROR"
		request_failed.emit(cancel_res)

func _on_http_request_completed(result: int, response_code: int, _headers: PackedStringArray, body: PackedByteArray) -> void:
	is_request_in_flight = false

	if active_provider == null or current_request == null:
		return

	# Handle network transport failures (e.g. RESULT_CANT_CONNECT, RESULT_TIMEOUT)
	if result != HTTPRequest.RESULT_SUCCESS:
		var err_res: AIResponse = AIResponse.new()
		err_res.provider = current_request.provider
		err_res.model = current_request.model
		err_res.request_id = current_request.request_id
		err_res.http_status = response_code
		err_res.success = false
		
		match result:
			HTTPRequest.RESULT_TIMEOUT:
				err_res.error_code = "TIMEOUT"
				err_res.error_message = "Request timed out after %.0fs" % timeout_seconds
			HTTPRequest.RESULT_CANT_CONNECT:
				err_res.error_code = "CONNECTION_FAILED"
				err_res.error_message = "Failed to connect to provider endpoint"
			HTTPRequest.RESULT_CANT_RESOLVE:
				err_res.error_code = "DNS_FAILURE"
				err_res.error_message = "Failed to resolve hostname"
			_:
				err_res.error_code = "TRANSPORT_ERROR"
				err_res.error_message = "Transport error (Result code %d)" % result

		last_response = err_res
		current_status = "ERROR"
		print("[AIService] Request %s failed: %s" % [err_res.request_id, err_res.error_message])
		request_failed.emit(err_res)
		return

	# Parse HTTP response
	var response: AIResponse = active_provider.parse_response(response_code, body, current_request)
	
	# Verify connectivity test result content
	if response.success:
		if response.content == "ECHO_ONLINE":
			current_status = "ONLINE"
			print("[AIService] Request %s succeeded! Status: ONLINE (Latency: %.0fms, Tokens: %d)" % [
				response.request_id, response.latency_ms, response.total_tokens
			])
			last_response = response
			request_completed.emit(response)
		else:
			response.success = false
			response.error_code = "CONTENT_MISMATCH"
			response.error_message = "Expected 'ECHO_ONLINE', received: '%s'" % response.content
			current_status = "ERROR"
			print("[AIService] Request %s content mismatch: %s" % [response.request_id, response.error_message])
			last_response = response
			request_failed.emit(response)
	else:
		current_status = "ERROR"
		print("[AIService] Request %s failed: %s" % [response.request_id, response.error_message])
		last_response = response
		request_failed.emit(response)
