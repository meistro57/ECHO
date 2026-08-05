class_name AIResponse
extends RefCounted

var success: bool = false
var provider: String = ""
var model: String = ""
var content: String = ""
var finish_reason: String = ""
var request_id: String = ""
var latency_ms: float = 0.0
var prompt_tokens: int = 0
var completion_tokens: int = 0
var total_tokens: int = 0
var http_status: int = 0
var error_code: String = ""
var error_message: String = ""
var raw_response_available: bool = false

func get_summary_string() -> String:
	if success:
		return "ONLINE [%.0fms | Status %d | Tokens %d]" % [latency_ms, http_status, total_tokens]
	else:
		return "ERROR [%s | Status %d]" % [error_message, http_status]
