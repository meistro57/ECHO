class_name SpeechToTextProvider
extends RefCounted

func get_provider_name() -> String:
	return "base_stt"

func is_configured() -> bool:
	return false

func transcribe(_buffer: AudioBuffer) -> SpeechResponse:
	return SpeechResponse.new(false, get_provider_name(), "")

func cancel() -> void:
	pass
