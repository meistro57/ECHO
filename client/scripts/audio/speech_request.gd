class_name SpeechRequest
extends RefCounted

var request_id: String = ""
var request_type: String = "STT" # STT or TTS
var provider_name: String = "mock"
var text_payload: String = ""
var audio_buffer: AudioBuffer = null
var timeout_seconds: float = 30.0

func _init(p_type: String = "STT", p_provider: String = "mock") -> void:
	request_id = "req_%d_%d" % [int(Time.get_ticks_msec()), randi() % 1000]
	request_type = p_type
	provider_name = p_provider
