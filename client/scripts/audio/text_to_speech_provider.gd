class_name TextToSpeechProvider
extends RefCounted

func get_provider_name() -> String:
	return "base_tts"

func is_configured() -> bool:
	return false

func synthesize(_text: String) -> SpeechResponse:
	return SpeechResponse.new(false, get_provider_name(), "")

func cancel() -> void:
	pass
