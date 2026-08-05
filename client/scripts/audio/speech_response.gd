class_name SpeechResponse
extends RefCounted

var success: bool = false
var provider: String = ""
var transcript: String = ""
var audio_stream: AudioStream = null
var latency_ms: float = 0.0
var request_id: String = ""
var confidence: float = 1.0
var http_status: int = 200
var error_code: String = ""
var error_message: String = ""

func _init(p_success: bool = false, p_provider: String = "", p_transcript: String = "") -> void:
	success = p_success
	provider = p_provider
	transcript = p_transcript
