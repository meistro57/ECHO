class_name AIProvider
extends RefCounted

func get_provider_name() -> String:
	return "generic"

func is_configured() -> bool:
	return false

func get_model() -> String:
	return ""

func get_endpoint_url() -> String:
	return ""

func build_headers() -> PackedStringArray:
	return PackedStringArray()

func build_request_body(request: AIRequest) -> String:
	var payload: Dictionary = {
		"model": get_model(),
		"messages": request.messages if request else [],
		"temperature": request.temperature if request else 0.0,
		"max_tokens": request.max_tokens if request else 100,
		"stream": false
	}
	return JSON.stringify(payload)

func parse_response(http_status: int, response_body: PackedByteArray, request: AIRequest) -> AIResponse:
	var res: AIResponse = AIResponse.new()
	res.provider = get_provider_name()
	res.model = get_model()
	res.request_id = request.request_id if request else ""
	res.http_status = http_status
	
	if request:
		var end_time: float = Time.get_ticks_msec() / 1000.0
		res.latency_ms = (end_time - request.timestamp_started) * 1000.0

	if http_status != 200:
		res.success = false
		res.error_code = "HTTP_%d" % http_status
		res.error_message = _sanitize_http_error(http_status, response_body)
		return res

	var body_text: String = response_body.get_string_from_utf8().trim_suffix("\n").strip_edges()
	if body_text.is_empty():
		res.success = false
		res.error_code = "EMPTY_RESPONSE"
		res.error_message = "Received empty body from provider"
		return res

	var json: JSON = JSON.new()
	var parse_err: Error = json.parse(body_text)
	if parse_err != OK:
		res.success = false
		res.error_code = "MALFORMED_JSON"
		res.error_message = "Failed to parse JSON response: %s" % json.get_error_message()
		return res

	var data: Variant = json.get_data()
	if not (data is Dictionary):
		res.success = false
		res.error_code = "INVALID_PAYLOAD"
		res.error_message = "Unexpected JSON root type"
		return res

	var dict_data: Dictionary = data as Dictionary
	res.raw_response_available = true

	# Check for top-level API error dict
	if dict_data.has("error"):
		var err_val: Variant = dict_data["error"]
		res.success = false
		res.error_code = "PROVIDER_ERROR"
		if err_val is Dictionary:
			res.error_message = String(err_val.get("message", "API error"))
		else:
			res.error_message = String(err_val)
		return res

	if not dict_data.has("choices") or not (dict_data["choices"] is Array) or (dict_data["choices"] as Array).is_empty():
		res.success = false
		res.error_code = "MISSING_CHOICES"
		res.error_message = "Response missing 'choices' array"
		return res

	var choices: Array = dict_data["choices"] as Array
	var first_choice: Variant = choices[0]
	if not (first_choice is Dictionary):
		res.success = false
		res.error_code = "INVALID_CHOICE"
		res.error_message = "Choice element is not a dictionary"
		return res

	var choice_dict: Dictionary = first_choice as Dictionary
	res.finish_reason = String(choice_dict.get("finish_reason", "stop"))

	if choice_dict.has("message") and choice_dict["message"] is Dictionary:
		var msg_dict: Dictionary = choice_dict["message"] as Dictionary
		res.content = String(msg_dict.get("content", "")).strip_edges()
	else:
		res.content = ""

	if res.content.is_empty():
		res.success = false
		res.error_code = "EMPTY_CONTENT"
		res.error_message = "Assistant content is empty"
		return res

	# Token usage parsing
	if dict_data.has("usage") and dict_data["usage"] is Dictionary:
		var usage_dict: Dictionary = dict_data["usage"] as Dictionary
		res.prompt_tokens = int(usage_dict.get("prompt_tokens", 0))
		res.completion_tokens = int(usage_dict.get("completion_tokens", 0))
		res.total_tokens = int(usage_dict.get("total_tokens", 0))

	res.success = true
	return res

func _sanitize_http_error(status: int, body: PackedByteArray) -> String:
	match status:
		400: return "Bad Request (400)"
		401: return "Unauthorized (401) - Check API Key"
		402: return "Payment Required / Insufficient Credits (402)"
		403: return "Forbidden (403)"
		404: return "Endpoint Not Found (404)"
		408: return "Request Timeout (408)"
		429: return "Rate Limit Exceeded (429)"
		500, 502, 503, 504: return "Server Error (%d)" % status
	
	var text: String = body.get_string_from_utf8()
	if text.length() > 60:
		text = text.substr(0, 60) + "..."
	return "HTTP Error %d: %s" % [status, text]
